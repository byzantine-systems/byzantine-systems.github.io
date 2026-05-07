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

  use files <- result.try(
    simplifile.read_directory(org_dir)
    |> result.map_error(simplifile_error("read " <> org_dir, _)),
  )

  files
  |> list.filter(string.ends_with(_, ".org"))
  |> list.try_each(convert_one)
}

fn convert_one(file: String) -> Result(Nil, String) {
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

      shellout.command(
        run: "pandoc",
        with: ["-s", input, "-t", "gfm", "-o", output],
        in: ".",
        opt: [],
      )
      |> result.map(fn(_) { Nil })
      |> result.map_error(fn(err) {
        let #(code, message) = err
        "pandoc exit " <> string.inspect(code) <> ": " <> message
      })
    }
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
