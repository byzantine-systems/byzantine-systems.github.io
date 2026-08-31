import blog
import blogatto/dev
import blogatto/error
import convert
import gleam/erlang/process
import gleam/io

pub fn main() {
  let result =
    blog.config()
    |> dev.new
    |> dev.before_build(fn() { async_convert() })
    |> dev.build_command("gleam run")
    |> dev.start

  case result {
    Ok(Nil) -> io.println("Dev server stopped.")
    Error(err) -> io.println("Dev server error: " <> error.describe_error(err))
  }
}

fn async_convert() -> Result(Nil, String) {
  let subject = process.new_subject()
  process.spawn_unlinked(fn() { process.send(subject, convert.run()) })
  case process.receive(subject, within: 60_000) {
    Ok(result) -> result
    Error(Nil) -> Error("convert timed out after 60s")
  }
}
