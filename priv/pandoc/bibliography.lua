--- Give the citeproc reference list a heading, and keep it in one piece.
---
--- Runs after `--citeproc` (which is why the flag precedes `--lua-filter` in
--- `convert.gleam`), so the generated `Div#refs` already exists by the time
--- this filter sees the document.
---
--- Two things happen here. The obvious one is the `Bibliography` heading,
--- emitted at level 1 so it sits as a peer of the post's own top-level
--- sections. The less obvious one is that the heading and the reference list
--- are written out as a *single* raw HTML block, for the same reason
--- `verse.lua` does it: pandoc would otherwise emit the nested `<div>`s as
--- separate HTML blocks, and blogatto wraps every HTML block in a `<div>` of
--- its own — closing the reference list before the entries it should contain,
--- which left the rendered bibliography unnested.

local heading_text = "Bibliography"
local heading_level = 1

--- Collapse blank lines, which would otherwise end the HTML block early: a
--- CommonMark HTML block runs until the first blank line. Whitespace between
--- block-level tags is insignificant, so this is safe to do wholesale.
local function to_single_block(html)
  local previous
  repeat
    previous = html
    html = html:gsub("\n%s*\n", "\n")
  until html == previous
  return (html:gsub("%s*$", ""))
end

function Div(el)
  if el.identifier ~= "refs" then
    return nil
  end

  local heading = pandoc.Header(
    heading_level,
    pandoc.Str(heading_text),
    pandoc.Attr("bibliography")
  )
  local html = pandoc.write(pandoc.Pandoc({ heading, el }), "html")

  return pandoc.RawBlock("html", to_single_block(html))
end
