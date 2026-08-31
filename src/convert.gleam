import gleam/erlang/application
import gleam/io
import gleam/list
import gleam/result
import gleam/string
import shellout
import simplifile

// Source directories
const org_dir = "org"

const org_posts_dir = "org/posts"

// Output directories
const blog_pages_dir = "blog/pages"

const blog_posts_dir = "blog/posts"

pub fn main() {
  let assert Ok(_) = run()
  Nil
}

pub fn run() -> Result(Nil, String) {
  use _ <- result.try(
    simplifile.create_directory_all(blog_pages_dir)
    |> result.map_error(simplifile_error("create " <> blog_pages_dir, _)),
  )

  use _ <- result.try(
    simplifile.create_directory_all(blog_posts_dir)
    |> result.map_error(simplifile_error("create " <> blog_posts_dir, _)),
  )

  let assert Ok(priv_dir) = application.priv_directory("blog")

  let bib_dir = priv_dir <> "/bibtex"

  // Post-processing pandoc can't do on its own; see each filter for why. They
  // run after `--citeproc` below, so the bibliography filter sees a document
  // that already has its reference list.
  let lua_filters =
    ["verse.lua", "bibliography.lua", "images.lua"]
    |> list.map(fn(f) { "--lua-filter=" <> priv_dir <> "/pandoc/" <> f })

  // Builds a list of each *.bib file in the bibtex directory
  let bib_args =
    simplifile.read_directory(bib_dir)
    |> result.unwrap([])
    |> list.filter(string.ends_with(_, ".bib"))
    |> list.map(fn(f) { "--bibliography=" <> bib_dir <> "/" <> f })

  let pandoc_args = list.append(bib_args, lua_filters)

  // Convert pages: org/*.org → blog/pages/<slug>/index.md
  use org_files <- result.try(
    simplifile.read_directory(org_dir)
    |> result.map_error(simplifile_error("read " <> org_dir, _)),
  )

  use _ <- result.try(
    org_files
    |> list.filter(string.ends_with(_, ".org"))
    |> list.try_each(fn(file) {
      let slug = string.replace(file, ".org", "")
      let input = org_dir <> "/" <> file
      let output_dir = blog_pages_dir <> "/" <> slug
      convert_file(input, output_dir, pandoc_args)
    }),
  )

  // Convert posts: org/posts/*.org → blog/posts/<slug>/index.md
  use post_files <- result.try(
    simplifile.read_directory(org_posts_dir)
    |> result.map_error(simplifile_error("read " <> org_posts_dir, _)),
  )

  post_files
  |> list.filter(string.ends_with(_, ".org"))
  |> list.try_each(fn(file) {
    let slug = string.replace(file, ".org", "")
    let input = org_posts_dir <> "/" <> file
    let output_dir = blog_posts_dir <> "/" <> slug
    convert_file(input, output_dir, pandoc_args)
  })
}

fn convert_file(
  input: String,
  output_dir: String,
  pandoc_args: List(String),
) -> Result(Nil, String) {
  let output = output_dir <> "/index.md"

  case is_up_to_date(input, output) {
    True -> Ok(Nil)
    False -> {
      use _ <- result.try(
        simplifile.create_directory_all(output_dir)
        |> result.map_error(simplifile_error("create " <> output_dir, _)),
      )

      io.println("Converting: " <> input <> " -> " <> output)

      let args =
        list.flatten([
          ["-s", input, "-t", "gfm", "--citeproc"],
          pandoc_args,
          ["-M", "link-citations=true"],
          ["-o", output],
        ])

      use _ <- result.try(
        shellout.command(run: "pandoc", with: args, in: ".", opt: [])
        |> result.map(fn(_) { Nil })
        |> result.map_error(fn(err) {
          let #(code, message) = err
          "pandoc exit " <> string.inspect(code) <> ": " <> message
        }),
      )

      use content <- result.try(
        simplifile.read(output)
        |> result.map_error(simplifile_error("read " <> output, _)),
      )

      simplifile.write(output, fix_bibliography_yaml(content))
      |> result.map_error(simplifile_error("write " <> output, _))
    }
  }
}

// Pandoc serialises multi-value bibliography metadata as a YAML block sequence:
//
//   bibliography:
//   - /path/a.bib
//   - /path/b.bib
//
// Blogatto's YAML parser requires an inline flow sequence:
//
//   bibliography: [ /path/a.bib, /path/b.bib ]
//
// This function post-processes the generated markdown to perform that
// rewrite, leaving all other content unchanged.
fn fix_bibliography_yaml(content: String) -> String {
  string.split(content, "\n")
  |> do_fix_bib(BeforeFrontmatter, [])
  |> list.reverse
  |> string.join("\n")
}

type FmState {
  BeforeFrontmatter
  InFrontmatter
  CollectingBib(List(String))
  InBody
}

fn do_fix_bib(
  lines: List(String),
  state: FmState,
  acc: List(String),
) -> List(String) {
  case lines {
    [] ->
      case state {
        CollectingBib(items) -> [bib_inline(list.reverse(items)), ..acc]
        _ -> acc
      }
    [line, ..rest] ->
      case state {
        BeforeFrontmatter ->
          case string.trim(line) == "---" {
            True -> do_fix_bib(rest, InFrontmatter, [line, ..acc])
            False -> do_fix_bib(rest, InBody, [line, ..acc])
          }

        InFrontmatter -> {
          let trimmed = string.trim(line)
          case trimmed {
            "---" | "..." -> do_fix_bib(rest, InBody, [line, ..acc])
            _ ->
              case is_bare_bib_key(trimmed) {
                True -> do_fix_bib(rest, CollectingBib([]), acc)
                False -> do_fix_bib(rest, InFrontmatter, [line, ..acc])
              }
          }
        }

        CollectingBib(items) -> {
          let trimmed = string.trim(line)
          case string.starts_with(trimmed, "- ") {
            True ->
              do_fix_bib(
                rest,
                CollectingBib([string.drop_start(trimmed, 2), ..items]),
                acc,
              )
            False -> {
              // Flush the collected items as an inline array, then handle
              // the current line according to where we are.
              let flushed = [line, bib_inline(list.reverse(items)), ..acc]
              case trimmed {
                "---" | "..." -> do_fix_bib(rest, InBody, flushed)
                _ -> do_fix_bib(rest, InFrontmatter, flushed)
              }
            }
          }
        }

        InBody -> do_fix_bib(rest, InBody, [line, ..acc])
      }
  }
}

fn is_bare_bib_key(line: String) -> Bool {
  case string.split_once(line, ":") {
    Ok(#("bibliography", rest)) -> string.is_empty(string.trim(rest))
    _ -> False
  }
}

fn bib_inline(items: List(String)) -> String {
  case items {
    [] -> "bibliography:"
    _ -> "bibliography: [ " <> string.join(items, ", ") <> " ]"
  }
}

fn is_up_to_date(source: String, target: String) -> Bool {
  case simplifile.file_info(source), simplifile.file_info(target) {
    Ok(s), Ok(t) -> t.mtime_seconds >= s.mtime_seconds
    _, _ -> False
  }
}

fn simplifile_error(action: String, err: simplifile.FileError) -> String {
  action <> ": " <> string.inspect(err)
}
