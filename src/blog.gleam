import blog/layout
import blogatto
import blogatto/config
import blogatto/config/feed/rss as rss_cfg
import blogatto/config/post as post_cfg
import blogatto/config/post/code
import lustre/element
import mork
import simplifile

fn read_page(path: String) -> element.Element(msg) {
  let assert Ok(content) = simplifile.read(path)
  let html =
    mork.configure()
    |> mork.strip_frontmatter(True)
    |> mork.parse_with_options(content)
    |> mork.to_html()
  element.unsafe_raw_html("", "div", [], html)
}

pub fn config() -> config.Config(msg) {
  let home_content = read_page("./blog/pages/home/index.md")
  let projects_content = read_page("./blog/pages/projects/index.md")

  let posts =
    post_cfg.default()
    |> post_cfg.path("./blog/posts")
    |> post_cfg.template(layout.post_page)
    |> post_cfg.syntax_highlighting(code.default())

  let feed =
    rss_cfg.new("Byzantine Systems", layout.site_url, layout.site_description)
    |> rss_cfg.language("en-us")

  config.new(layout.site_url)
  |> config.output_dir("./dist")
  |> config.static_dir("./static")
  |> config.post(posts)
  |> config.rss_feed(feed)
  |> config.route("/", fn(_) { layout.home_page(home_content) })
  |> config.route("/posts", layout.posts_page)
  |> config.route("/projects", fn(_) { layout.projects_page(projects_content) })
}

pub fn main() {
  let assert Ok(Nil) = blogatto.build(config())
  Nil
}
