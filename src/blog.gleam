import blog/layout
import blogatto
import blogatto/config
import blogatto/config/feed/rss as rss_cfg
import blogatto/config/post as post_cfg
import blogatto/config/post/code

pub fn config() -> config.Config(msg) {
  let posts =
    post_cfg.default()
    |> post_cfg.path("./blog")
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
  |> config.route("/", layout.home_page)
  |> config.route("/posts", layout.posts_page)
  |> config.route("/projects", layout.projects_page)
}

pub fn main() {
  let assert Ok(Nil) = blogatto.build(config())
  Nil
}
