import gleam/erlang/application
import gleam/io
import gleam/list
import gleam/result
import gleam/string
import shellout
import simplifile

const org_dir = "org"

const blog_dir = "blog"

pub fn main() {
  let assert Ok(_) = run()
  Nil
}

pub fn run() -> Result(Nil, String) {
  use _ <- result.try(
    simplifile.create_directory_all(blog_dir)
    |> result.map_error(simplifile_error("create " <> blog_dir, _)),
  )

  let assert Ok(bib_dir) =
    application.priv_directory("blog")
    |> result.map(fn(priv) { priv <> "/bibtex" })

  // Builds a list of each *.bib file in the bibtex directory
  let bib_args =
    simplifile.read_directory(bib_dir)
    |> result.unwrap([])
    |> list.filter(string.ends_with(_, ".bib"))
    |> list.map(fn(f) { "--bibliography=" <> bib_dir <> "/" <> f })

  use files <- result.try(
    simplifile.read_directory(org_dir)
    |> result.map_error(simplifile_error("read " <> org_dir, _)),
  )

  files
  |> list.filter(string.ends_with(_, ".org"))
  |> list.try_each(fn(file) { convert_one(file, bib_args) })
}

fn convert_one(file: String, bib_args: List(String)) -> Result(Nil, String) {
  let slug = string.replace(file, ".org", "")
  let input = org_dir <> "/" <> file
  let output_dir = blog_dir <> "/" <> slug
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
          bib_args,
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
