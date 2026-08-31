--- Preserve Org-mode verse blocks through the GFM writer.
---
--- Pandoc reads `#+begin_verse ... #+end_verse` as a `LineBlock`, but the GFM
--- writer has no line-block syntax, so it degrades verses into an ordinary
--- paragraph with hard line breaks — indistinguishable from prose once mork
--- turns the markdown into HTML.
---
--- This filter renders the verse to HTML itself and emits it as a single raw
--- block tagged with `class="verse"`, which `static/css/style.css` styles.
--- Quote blocks need no such help: they survive as markdown blockquotes and
--- reach the page as `<blockquote>`.
---
--- The HTML is emitted as *one* block with no blank lines inside it, because
--- both rendering paths require it: CommonMark ends an HTML block at the first
--- blank line, and blogatto wraps every HTML block in a `<div>` of its own, so
--- a verse split across several blocks would have its opening `<div>` closed
--- before the lines it is meant to contain.

function LineBlock(el)
  local inlines = {}

  for i, line in ipairs(el.content) do
    if i > 1 then
      table.insert(inlines, pandoc.LineBreak())
    end
    for _, inline in ipairs(line) do
      table.insert(inlines, inline)
    end
  end

  local html = pandoc.write(pandoc.Pandoc({ pandoc.Para(inlines) }), "html")
  -- Drop the writer's trailing newline: it would split the raw block in two.
  html = html:gsub("%s*$", "")

  return pandoc.RawBlock("html", '<div class="verse">' .. html .. "</div>")
end
