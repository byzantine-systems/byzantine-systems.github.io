import blogatto/post.{type Post}
import gleam/int
import gleam/list
import gleam/time/calendar
import gleam/time/timestamp
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html

pub const site_url = "https://byzantine-systems.github.io"

pub const site_description = "'There's no need to build a labyrinth when the entire universe is one.'"

/// Runs in `<head>`, before the first paint, so a stored theme choice does not
/// flash the system theme first. With no stored choice the attribute stays
/// unset and the `prefers-color-scheme` media query decides.
///
/// It also marks the document as script-enabled: the theme switch is useless
/// without JavaScript, so the stylesheet keeps it hidden until this runs.
const theme_init_js = "(function () {
  try {
    var t = localStorage.getItem('theme');
    if (t === 'light' || t === 'dark') document.documentElement.dataset.theme = t;
  } catch (e) {}
  document.documentElement.classList.add('has-js');
})();"

/// Runs at the end of `<body>`, once the switch exists. Cycles the theme
/// system → light → dark → system, persisting anything other than 'system'.
///
/// The switch is icon-only, so each glyph carries a name for the tooltip and
/// the accessible label. The glyphs read as a fill level — empty circle for
/// light, filled for dark, half-filled for whatever the system says — which
/// keeps them in the same monochrome geometric family as the other nav items.
const theme_switch_js = "(function () {
  var order = ['system', 'light', 'dark'];
  var glyphs = { system: '◐', light: '○', dark: '●' };
  var names = { system: 'Auto', light: 'Light', dark: 'Dark' };
  var button = document.getElementById('theme-switch');
  if (!button) return;

  function stored() {
    try {
      var t = localStorage.getItem('theme');
      if (t === 'light' || t === 'dark') return t;
    } catch (e) {}
    return 'system';
  }

  function apply(theme) {
    if (theme === 'system') {
      delete document.documentElement.dataset.theme;
    } else {
      document.documentElement.dataset.theme = theme;
    }
    button.textContent = glyphs[theme];
    button.setAttribute('title', 'Colour theme: ' + names[theme]);
    button.setAttribute('aria-label', 'Colour theme: ' + names[theme] + '. Activate to change.');
    try {
      if (theme === 'system') {
        localStorage.removeItem('theme');
      } else {
        localStorage.setItem('theme', theme);
      }
    } catch (e) {}
  }

  apply(stored());

  button.addEventListener('click', function () {
    apply(order[(order.indexOf(stored()) + 1) % order.length]);
  });
})();"

fn to_link(text: String, link: String) {
  html.a(
    [
      attribute.href(link),
    ],
    [
      html.text(text),
    ],
  )
}

pub fn home_page(content: Element(msg)) -> Element(msg) {
  layout("Byzantine Systems", [content])
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

pub fn projects_page(content: Element(msg)) -> Element(msg) {
  layout("Projects", [content])
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

pub fn navbar() {
  html.nav([attribute.class("site-nav")], [
    html.ul([], [
      html.li([], [to_link("≡ Home", "/")]),
      html.li([], [to_link("□ Posts", "/posts/")]),
      html.li([], [to_link("◇ Projects", "/projects/")]),
      html.li([], [to_link("RSS", "/rss.xml")]),
      theme_switch(),
    ]),
  ])
}

/// The theme switch. Rendered with the 'system' label because that is the
/// default; `theme_switch_js` relabels it from the stored choice on load.
fn theme_switch() -> Element(msg) {
  html.li([attribute.class("theme-switch")], [
    html.button(
      [
        attribute.id("theme-switch"),
        attribute.type_("button"),
        attribute.title("Colour theme: Auto"),
        attribute.aria_label("Colour theme: Auto. Activate to change."),
      ],
      [html.text("◐")],
    ),
  ])
}

pub fn footer() -> Element(msg) {
  let emacs = to_link("GNU/Emacs", "https://www.gnu.org/software/emacs/")
  let orgmode = to_link("Orgmode", "https://orgmode.org/")
  let nix = to_link("Nix", "https://nixos.org/")
  let gleam = to_link("Gleam", "https://gleam.run/")
  let blogatto = to_link("Blogatto", "https://blogat.to/")
  let source_link =
    to_link(
      "here",
      "https://github.com/byzantine-systems/byzantine-systems.github.io",
    )
  html.footer([], [
    html.p([], [
      html.text("Built with "),
      emacs,
      html.text(", "),
      orgmode,
      html.text(", "),
      nix,
      html.text(" and "),
      gleam,
      html.text(". Generated with "),
      blogatto,
      html.text(", source code available "),
      source_link,
      html.text("."),
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
      // This links to the CSS file copied from your static folder
      html.link([attribute.rel("stylesheet"), attribute.href("/css/style.css")]),
      html.script([], theme_init_js),
    ]),
    html.body([], [
      navbar(),
      html.header([], [
        html.h1([], [html.text("Byzantine Systems")]),
      ]),
      html.main([], content),
      footer(),
      html.script([], theme_switch_js),
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
  pad2(day) <> " " <> month_short(month) <> " " <> int.to_string(year)
}

fn pad2(n: Int) -> String {
  case n < 10 {
    True -> "0" <> int.to_string(n)
    False -> int.to_string(n)
  }
}

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
