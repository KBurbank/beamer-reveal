-- Convert Beamer commands directly to Reveal.js fragments
-- This filter runs FIRST, before LaTeX parsing

-- Helper to extract content from braces
local function extract_braced(text)
  local content = text:match("^{(.-)}$") or text:match("^{(.-)}")
  return content
end

-- Helper to parse fragment index like <1>, <2->, etc.
local function parse_index(idx_str)
  if not idx_str then return nil, false end
  local has_dash = idx_str:match("%-$") ~= nil
  local clean_idx = idx_str:gsub("%-$", "")
  return clean_idx, has_dash
end

-- Convert Beamer fragment to Pandoc Span with attributes
-- Keep content as RawInline so latex-macros can process it later
local function beamer_to_span(beamer_type, index, content, has_dash)
  local classes = {"fragment"}
  
  if beamer_type == "only" then
    if has_dash then
      table.insert(classes, "fade-out")
    else
      table.insert(classes, "current-visible")
    end
  elseif beamer_type == "fadeout" then
    table.insert(classes, "fade-out")
  end
  
  local attributes = {}
  if index then
    attributes["data-fragment-index"] = index
  end
  
  local attr = pandoc.Attr("", classes, attributes)
  -- Keep content as raw tex so it can be processed by latex-macros
  return pandoc.Span({pandoc.RawInline("tex", content)}, attr)
end

-- Process RawInline elements (but NOT \pause - that's handled at Para level)
function RawInline(elem)
  if not (elem.format == "tex" or elem.format == "latex") then
    return nil
  end
  
  local text = elem.text
  
  -- Don't handle \pause here - it's handled at the Para level to split paragraphs
  
  -- Handle \only<n>{content}
  local idx, content = text:match("^\\only<(%d+%-?)>%s*{(.+)}$")
  if idx and content then
    local clean_idx, has_dash = parse_index(idx)
    return beamer_to_span("only", clean_idx, content, has_dash)
  end
  
  -- Handle \onslide<n>{content}
  idx, content = text:match("^\\onslide<(%d+%-?)>%s*{(.+)}$")
  if idx and content then
    io.stderr:write("  --> MATCHED! idx=[" .. idx .. "] content=[" .. content .. "]\n")
    local clean_idx, has_dash = parse_index(idx)
    return beamer_to_span("fadein", clean_idx, content, has_dash)
  else
    if text:match("^\\onslide") then
      io.stderr:write("  --> NO MATCH for pattern. Trying simpler match...\n")
      -- Try without the end anchor
      idx, content = text:match("^\\onslide<(%d+%-?)>%s*{(.+)}")
      if idx and content then
        io.stderr:write("  --> SIMPLER PATTERN MATCHED! idx=[" .. idx .. "] content=[" .. content .. "]\n")
      end
    end
  end
  
  -- Handle \hid<n>{content} (fadeout)
  idx, content = text:match("^\\hid<(%d+%-?)>%s*{(.+)}$")
  if idx and content then
    local clean_idx, has_dash = parse_index(idx)
    return beamer_to_span("fadeout", clean_idx, content, has_dash)
  end
  
  return nil
end

-- Process paragraphs to handle \pause that splits them
function Para(para)
  -- Check if paragraph contains \pause
  local has_pause = false
  for i = 1, #para.content do
    local elem = para.content[i]
    if elem.t == "RawInline" and (elem.format == "tex" or elem.format == "latex") then
      if elem.text:match("^\\pause") then
        has_pause = true
        break
      end
    end
  end
  
  if not has_pause then
    return nil
  end
  
  -- Split paragraph at \pause positions
  local result_blocks = {}
  local current_inlines = {}
  
  for i = 1, #para.content do
    local elem = para.content[i]
    if elem.t == "RawInline" and (elem.format == "tex" or elem.format == "latex") then
      -- Check if this starts with \pause
      local remainder = elem.text:match("^\\pause(.*)$")
      if remainder then
        -- Save current accumulated inlines as a Para (if not empty)
        if #current_inlines > 0 then
          table.insert(result_blocks, pandoc.Para(current_inlines))
          current_inlines = {}
        end
        -- Insert pause Para
        table.insert(result_blocks, pandoc.Para({
          pandoc.Str("."), pandoc.Space(),
          pandoc.Str("."), pandoc.Space(),
          pandoc.Str(".")
        }))
        -- If there's more LaTeX after \pause, keep it as a RawInline
        if remainder ~= "" then
          table.insert(current_inlines, pandoc.RawInline(elem.format, remainder))
        end
      else
        table.insert(current_inlines, elem)
      end
    else
      table.insert(current_inlines, elem)
    end
  end
  
  -- Add any remaining inlines
  if #current_inlines > 0 then
    table.insert(result_blocks, pandoc.Para(current_inlines))
  end
  
  return result_blocks
end

-- Process RawBlock elements
function RawBlock(elem)
  if not (elem.format == "tex" or elem.format == "latex") then
    return nil
  end
  
  local text = elem.text
  
  -- Handle \pause as a block (even if followed by other LaTeX)
  local remainder = text:match("^\\pause(.*)$")
  if remainder then
    local blocks = {}
    -- Add pause Para
    table.insert(blocks, pandoc.Para({
      pandoc.Str("."), pandoc.Space(),
      pandoc.Str("."), pandoc.Space(),
      pandoc.Str(".")
    }))
    -- If there's more LaTeX after \pause, keep it as a RawBlock
    if remainder ~= "" and not remainder:match("^%s*$") then
      table.insert(blocks, pandoc.RawBlock(elem.format, remainder))
    end
    return blocks
  end
  
  return nil
end

-- Return element-level filters only (no Pandoc function)
-- Beamer commands are now protected by latex-macros so they stay as raw LaTeX
return {
  { Para = Para },
  { Plain = Para },  -- Plain elements work the same as Para for our purposes
  { RawInline = RawInline },
  { RawBlock = RawBlock }
}
