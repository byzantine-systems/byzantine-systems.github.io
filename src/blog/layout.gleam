import blogatto/post.{type Post}
import gleam/list
import gleam/time/calendar
import gleam/time/timestamp
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html

pub const site_url = "https://byzantine-systems.github.io"

pub const site_description = "Notes on Gleam, Erlang, distributed systems, and other byzantine matters."

pub fn home_page(_posts: List(Post(msg))) -> Element(msg) {
  layout("Byzantine Systems", [
    html.p([], [
      html.text("Welcome. Browse the "),
      html.a([attribute.href("/posts/")], [html.text("posts")]),
      html.text(" or "),
      html.a([attribute.href("/projects/")], [html.text("projects")]),
      html.text("."),
    ]),
  ])
}

pub fn posts_page(posts: List(Post(msg))) -> Element(msg) {
  let sorted = list.sort(posts, fn(a, b) { timestamp.compare(b.date, a.date) })

  layout("Posts", [
    html.h2([], [html.text("Posts")]),
    case sorted {
      [] -> html.p([], [html.text("No posts yet.")])
      _ -> html.ul([], list.map(sorted, post_link))
    },
  ])
}

pub fn projects_page(_posts: List(Post(msg))) -> Element(msg) {
  layout("Projects", [
    html.h2([], [html.text("Projects")]),
    html.p([], [html.text("Projects coming soon.")]),
  ])
}

pub fn post_page(p: Post(msg), _all_posts: List(Post(msg))) -> Element(msg) {
  layout(p.title, [
    html.article([], [
      html.h2([], [html.text(p.title)]),
      html.p([], [html.small([], [html.text(format_date(p.date))])]),
      html.p([], [html.em([], [html.text(p.description)])]),
      html.div([], p.contents),
    ]),
  ])
}

fn layout(page_title: String, content: List(Element(msg))) -> Element(msg) {
  html.html([attribute.attribute("lang", "en")], [
    html.head([], [
      html.meta([attribute.attribute("charset", "UTF-8")]),
      html.meta([
        attribute.name("viewport"),
        attribute.attribute("content", "width=device-width, initial-scale=1.0"),
      ]),
      html.title([], page_title),
      html.meta([
        attribute.name("description"),
        attribute.attribute("content", site_description),
      ]),
      html.link([
        attribute.attribute("rel", "alternate"),
        attribute.attribute("type", "application/rss+xml"),
        attribute.attribute("title", "Byzantine Systems RSS"),
        attribute.href("/rss.xml"),
      ]),
      html.style(
        [],
        "nav.site-nav { display: flex; justify-content: center; gap: 1.5rem; padding: 1rem 0; }",
      ),
    ]),
    html.body([], [
      html.nav([attribute.class("site-nav")], [
        html.a([attribute.href("/")], [html.text("Home")]),
        html.a([attribute.href("/posts/")], [html.text("Posts")]),
        html.a([attribute.href("/projects/")], [html.text("Projects")]),
        html.a([attribute.href("/rss.xml")], [html.text("RSS")]),
      ]),
      html.header([], [
        html.h1([], [html.text("Byzantine Systems")]),
        html.p([], [html.text(site_description)]),
      ]),
      html.main([], content),
    ]),
  ])
}

fn post_link(p: Post(msg)) -> Element(msg) {
  html.li([], [
    html.a([attribute.href("/" <> p.slug <> "/")], [html.text(p.title)]),
    html.text(" ⊢ " <> format_date(p.date)),
    html.br([]),
    html.small([], [html.text(p.description)]),
  ])
}

fn format_date(ts: timestamp.Timestamp) -> String {
  let #(date, _) = timestamp.to_calendar(ts, calendar.utc_offset)
  let calendar.Date(year:, month:, day:) = date
  pad2(day) <> " " <> month_short(month) <> " " <> int_to_string(year)
}

fn pad2(n: Int) -> String {
  case n < 10 {
    True -> "0" <> int_to_string(n)
    False -> int_to_string(n)
  }
}

@external(erlang, "erlang", "integer_to_binary")
fn int_to_string(n: Int) -> String

fn month_short(m: calendar.Month) -> String {
  case m {
    calendar.January -> "Jan"
    calendar.February -> "Feb"
    calendar.March -> "Mar"
    calendar.April -> "Apr"
    calendar.May -> "May"
    calendar.June -> "Jun"
    calendar.July -> "Jul"
    calendar.August -> "Aug"
    calendar.September -> "Sep"
    calendar.October -> "Oct"
    calendar.November -> "Nov"
    calendar.December -> "Dec"
  }
}
