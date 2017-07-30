-- (WIP) Pandoc Remarkup Writer
--
-- Invoke with: pandoc -t remarkup.lua
--
-- Note:  you need not have lua installed on your system to use this
-- custom writer.  However, if you do have lua installed, you can
-- use it to test changes to the script.  'lua remarkup.lua' will
-- produce informative error messages if your code contains
-- syntax errors.

local hex_to_char = function(x)
  return string.char(tonumber(x, 16))
end

local url_unescape = function(url)
  return url:gsub("%%(%x%x)", hex_to_char)
end

local function escape(s, in_attribute)
   return s
end

-- Helper function to convert an attributes table into
-- a string that can be put into HTML tags.
local function attributes(attr)
  local attr_table = {}
  for x,y in pairs(attr) do
    if y and y ~= "" then
      table.insert(attr_table, ' ' .. x .. '="' .. escape(y,true) .. '"')
    end
  end
  return table.concat(attr_table)
end

-- Run cmd on a temporary file containing inp and return result.
local function pipe(cmd, inp)
  local tmp = os.tmpname()
  local tmph = io.open(tmp, "w")
  tmph:write(inp)
  tmph:close()
  local outh = io.popen(cmd .. " " .. tmp,"r")
  local result = outh:read("*all")
  outh:close()
  os.remove(tmp)
  return result
end

-- Table to store footnotes, so they can be included at the end.
local notes = {}

-- Blocksep is used to separate block elements.
function Blocksep()
  return "\n\n"
end

-- This function is called once for the whole document. Parameters:
-- body is a string, metadata is a table, variables is a table.
-- This gives you a fragment.  You could use the metadata table to
-- fill variables in a custom lua template.  Or, pass `--template=...`
-- to pandoc, and pandoc will add do the template processing as
-- usual.
function Doc(body, metadata, variables)
   return body
  -- local buffer = {}
  -- local function add(s)
  --   table.insert(buffer, s)
  -- end
  -- add(body)
  -- if #notes > 0 then
  --   add('\n')
  --   for _,note in pairs(notes) do
  --     add(note)
  --   end
  -- end
  -- return table.concat(buffer,'\n')
end

-- The functions that follow render corresponding pandoc elements.
-- s is always a string, attr is always a table of attributes, and
-- items is always an array of strings (the items in a list).
-- Comments indicate the types of other variables.

function Str(s)
  return escape(s)
end

function Space()
  return " "
end

function LineBreak()
  return "\n"
end

function SoftBreak()
  return " "
end

function Emph(s)
  return "//" .. s .. "//"
end

function Strong(s)
  return "**" .. s .. "**"
end

function Subscript(s)
  return "_" .. s .. ""
end

function Superscript(s)
  return "^" .. s .. ""
end

function SmallCaps(s)
  return s
end

function Strikeout(s)
  return '~~' .. s .. '~~'
end

function Link(s, src, tit)
   if s == nil or s == '' then
      return "[[" .. url_unescape(src) .. "]]"
   else
      return "[[" .. url_unescape(src) .. "|" .. s .. "]]"
   end
end

function Image(s, src, tit)
   return "IMAGE: " .. Link(s, src, tit)
end

function RawInline(lang, s, attr)
   return "`" .. s .. "`"
end

function Code(s, attr)
  return "`" .. s .. "`"
end

function InlineMath(s)
  return "`" .. s .. "`"
end

function DisplayMath(s)
  return "`" .. s .. "`"
end

function Note(s)
  local num = #notes + 1
  -- insert the back reference right before the final closing tag.
  s = string.gsub(s,
          '(.*)</', '%1 <a href="#fnref' .. num ..  '">&#8617;</a></')
  -- add a list item with the note to the note table.
  table.insert(notes, '<li id="fn' .. num .. '">' .. s .. '</li>')
  -- return the footnote reference, linked to the note.
  return '<a id="fnref' .. num .. '" href="#fn' .. num ..
            '"><sup>' .. num .. '</sup></a>'
end

function Span(s, attr)
   return s
end

function Cite(s, cs)
   return s
end

function Plain(s)
  return s
end

function Para(s)
  return s
end

-- lev is an integer, the header level.
function Header(lev, s, attr)
   local marker = string.rep("=", lev)
   return "" .. marker .. " " .. s .. " " .. marker
end

function BlockQuote(s)
   local new_s = string.gsub(s, "\n", "\n> ")
   return "> " .. new_s
end

function HorizontalRule()
   return string.rep("-", 5)
end

function RawBlock(lang, s, attr)
   return "```lang=" .. lang .. "\n" .. s .. "\n```"
end

function CodeBlock(s, attr)
   return "```\n" .. s .. "\n```"
end

function BulletList(items)
  local buffer = {}
  for _, item in pairs(items) do
    table.insert(buffer, "* " .. item)
  end
  return table.concat(buffer, "\n")
end

function OrderedList(items)
  local buffer = {}
  for _, item in pairs(items) do
    table.insert(buffer, "# " .. item)
  end
  return table.concat(buffer, "\n")
end

-- Revisit association list STackValue instance.
function DefinitionList(items)
  local buffer = {}
  for _,item in pairs(items) do
    for k, v in pairs(item) do
      table.insert(buffer,"<dt>" .. k .. "</dt>\n<dd>" ..
                        table.concat(v,"</dd>\n<dd>") .. "</dd>")
    end
  end
  return "<dl>\n" .. table.concat(buffer, "\n") .. "\n</dl>"
end

-- Convert pandoc alignment to something HTML can use.
-- align is AlignLeft, AlignRight, AlignCenter, or AlignDefault.
function html_align(align)
  if align == 'AlignLeft' then
    return 'left'
  elseif align == 'AlignRight' then
    return 'right'
  elseif align == 'AlignCenter' then
    return 'center'
  else
    return 'left'
  end
end

-- Caption is a string, aligns is an array of strings,
-- widths is an array of floats, headers is an array of
-- strings, rows is an array of arrays of strings.
function Table(caption, aligns, widths, headers, rows)
  local buffer = {}
  local function add(s)
    table.insert(buffer, s)
  end
  add("<table>")
  if caption ~= "" then
    add("<caption>" .. caption .. "</caption>")
  end
  local header_row = {}
  local empty_header = true
  for i, h in pairs(headers) do
    table.insert(header_row,'<th>' .. h .. '</th>')
    empty_header = empty_header and h == ""
  end
  if empty_header then
    head = ""
  else
    add('<tr>')
    for _,h in pairs(header_row) do
      add(h)
    end
    add('</tr>')
  end
  for _, row in pairs(rows) do
    add('<tr>')
    for i,c in pairs(row) do
      add('<td>' .. c .. '</td>')
    end
    add('</tr>')
  end
  add('</table>')
  if caption ~= "" then
    add("//" .. caption .. "//")
  end
  return table.concat(buffer,'\n')
end

function Div(s, attr)
  return "<div" .. attributes(attr) .. ">\n" .. s .. "</div>"
end 

-- The following code will produce runtime warnings when you haven't defined
-- all of the functions you need for the custom writer, so it's useful
-- to include when you're working on a writer.
local meta = {}
meta.__index =
  function(_, key)
    io.stderr:write(string.format("WARNING: Undefined function '%s'\n",key))
    return function() return "" end
  end
setmetatable(_G, meta)
