import blog
import blogatto/dev
import blogatto/error
import convert
import gleam/io

pub fn main() {
  let result =
    blog.config()
    |> dev.new
    |> dev.before_build(convert.run)
    |> dev.build_command("gleam run")
    |> dev.start

  case result {
    Ok(Nil) -> io.println("Dev server stopped.")
    Error(err) -> io.println("Dev server error: " <> error.describe_error(err))
  }
}
