--
-- Pandoc Lua filter: turn Div/Span classes into LaTeX commands/environments
-- generic filter to convert structured Markdown into arbitrary LaTeX commands and environments.
--
-- The filter only modifies Div and Span.
-- All other elements (Para, Header, etc.) are passed through to Pandoc's native writer.
-- Handles nesting, optional arguments, and multiple mandatory arguments.
-- Handles Div and Span, mapping classes to LaTeX commands,

-- Convert attributes (arg1/opt1 etc.) into LaTeX syntax
local function attributes_to_latex(attr)
	local opts, args = {}, {}

	local i = 1
	while attr["opt" .. i] do
		table.insert(opts, attr["opt" .. i])
		i = i + 1
	end

	i = 1
	while attr["arg" .. i] do
		table.insert(args, "{" .. attr["arg" .. i] .. "}")
		i = i + 1
	end

	local opt_str = (#opts > 0) and ("[" .. table.concat(opts, ",") .. "]") or ""
	return opt_str .. table.concat(args)
end

-- Render blocks → LaTeX string
local function blocks_to_latex(blocks)
	if blocks and #blocks > 0 then
		return pandoc.write(pandoc.Pandoc(blocks), "latex"):gsub("\n*$", "")
	end
	return ""
end

-- Render inlines → LaTeX string
local function inlines_to_latex(inlines)
	if inlines and #inlines > 0 then
		return pandoc.write(pandoc.Pandoc(pandoc.Plain(inlines)), "latex"):gsub("\n*$", "")
	end
	return ""
end

local function process_element(el, content_renderer, raw_constructor)
	if not FORMAT:match("^latex") then
		return nil
	end

	for _, class in ipairs(el.classes) do
		if class:match("^latex%.") then
			local args = attributes_to_latex(el.attributes)

			-- Environment: .latex.env.NAME
			local env = class:match("^latex%.env%.(.+)")
			if env then
				local content = content_renderer(el.content)
				local latex_content = "\\begin{" .. env .. "}" .. content .. "\\end{" .. env .. "}"
				-- ===================================================================
				-- ADD THIS LINE TO ESCAPE DOLLAR SIGNS FOR THE TEMPLATE ENGINE
				latex_content = latex_content:gsub("%$", "\\$")
				-- ===================================================================
				return raw_constructor("latex", latex_content)
			end

			-- Command: .latex.NAME
			local cmd = class:match("^latex%.(.+)")
			if cmd then
				local latex_content -- To hold the final generated string

				if cmd == "lstinline" then
					local raw_content = pandoc.utils.stringify(el.content)
					latex_content = "\\" .. cmd .. "|" .. raw_content .. "|"
				else
					local content = content_renderer(el.content)
					if content ~= "" then
						latex_content = "\\" .. cmd .. args .. "{" .. content .. "}"
					else
						latex_content = "\\" .. cmd .. args
					end
				end
				-- ===================================================================
				-- ADD THIS LINE TO ESCAPE DOLLAR SIGNS FOR THE TEMPLATE ENGINE
				latex_content = latex_content:gsub("%$", "\\$")
				-- ===================================================================
				return raw_constructor("latex", latex_content)
			end
		end
	end
	return nil
end

-- Div handler
function Div(div)
	return process_element(div, blocks_to_latex, pandoc.RawBlock) or div
end

-- Span handler
function Span(span)
	return process_element(span, inlines_to_latex, pandoc.RawInline) or span
end

return {
	Div = Div,
	Span = Span,
}
