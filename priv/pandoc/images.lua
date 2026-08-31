--- Rewrite Org-relative image paths into site-absolute URLs.
---
--- Org files link to generated images the way Emacs needs them — relative to
--- the `.org` file itself, so `C-c C-x C-v` previews them inline and Babel's
--- `:file` header writes them where the link points:
---
---     #+BEGIN_SRC dot :file ../../static/img/posts/00/flow.png
---     [[file:../../static/img/posts/00/flow.png]]
---
--- That path is wrong twice over in the built site. It is relative to
--- `org/posts/`, not to the post's URL, and blogatto copies the *contents* of
--- `static/` to the output root, so the `static/` segment does not exist in
--- any URL. The image above ships as `/img/posts/00/flow.png`.
---
--- This filter resolves each local image path against the directory of the
--- Org file being converted, and if the result lands inside `static/`, emits
--- the site-absolute URL that blogatto will actually serve it from. Remote
--- and already-absolute sources are left alone.

local static_root = "static"

local function segments(path)
  local parts = {}
  for segment in path:gmatch("[^/]+") do
    parts[#parts + 1] = segment
  end
  return parts
end

--- Directory of the file being converted, as path segments.
local function input_dir()
  local input = (PANDOC_STATE.input_files or {})[1]
  if not input then
    return {}
  end
  local parts = segments(input)
  table.remove(parts) -- drop the filename
  return parts
end

--- Resolve `src` against `base`, collapsing `.` and `..`.
local function resolve(base, src)
  local parts = {}
  for _, segment in ipairs(base) do
    parts[#parts + 1] = segment
  end
  for _, segment in ipairs(segments(src)) do
    if segment == ".." then
      table.remove(parts)
    elseif segment ~= "." then
      parts[#parts + 1] = segment
    end
  end
  return parts
end

local function is_external(src)
  -- A URL scheme, a protocol-relative URL, or an already-absolute path.
  return src:match("^%a[%w+.-]*:") ~= nil or src:match("^//") ~= nil
    or src:sub(1, 1) == "/"
end

local function exists(path)
  local file = io.open(path, "r")
  if file then
    file:close()
    return true
  end
  return false
end

function Image(el)
  if is_external(el.src) then
    return nil
  end

  local path = resolve(input_dir(), el.src)

  if path[1] ~= static_root then
    io.stderr:write(
      "images.lua: " .. el.src .. " resolves outside " .. static_root
        .. "/, leaving it untouched\n"
    )
    return nil
  end

  if not exists(table.concat(path, "/")) then
    io.stderr:write("images.lua: missing image " .. table.concat(path, "/") .. "\n")
  end

  -- Drop the `static` segment: blogatto copies that directory's contents to
  -- the site root, so it never appears in a URL.
  table.remove(path, 1)
  el.src = "/" .. table.concat(path, "/")

  return el
end
