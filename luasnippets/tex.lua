---@diagnostic disable: undefined-global
-- Converted from the attached UltiSnips tex.snippets file for LuaSnip.
--
-- The repository's existing snippets/tex.snippets remains loaded through the
-- SnipMate loader. This file adds the advanced context, regex, autosnippet,
-- Python/SymPy, and Wolfram behavior that SnipMate cannot represent.

local ls = require("luasnip")
local s = ls.snippet
local t = ls.text_node
local i = ls.insert_node
local f = ls.function_node
local parse = ls.parser.parse_snippet

 local function in_mathzone()
  local ok, value = pcall(vim.fn["vimtex#syntax#in_mathzone"])
  return ok and value == 1
end

local function in_textzone()
  return not in_mathzone()
end

local function line_begin(line_to_cursor, matched_trigger)
  local prefix_length = #line_to_cursor - #matched_trigger
  if prefix_length < 0 then
    return false
  end
  local prefix = line_to_cursor:sub(1, prefix_length)
  return prefix:match("^%s*$") ~= nil
end

local function all_conditions(...)
  local predicates = { ... }
  return function(...)
    local args = { ... }
    for _, predicate in ipairs(predicates) do
      if not predicate(unpack(args)) then
        return false
      end
    end
    return true
  end
end

local function append(target, snippet)
  target[#target + 1] = snippet
end

local function parsed(context, body)
  return parse(context, body, { trim_empty = false, dedent = false })
end

local regular = {}
local autosnippets = {}

-- The six source snippets whose trigger literally contains "trigger" are
-- retained but hidden from completion. Set this to true only when debugging
-- regex behavior.
local ENABLE_DEBUG_TRIGGER_EXAMPLES = false

local greek_symbols = {
  ["@a"] = "\\alpha", ["@p"] = "\\phi", ["@P"] = "\\Phi",
  ["@b"] = "\\beta", ["@g"] = "\\gamma", ["@G"] = "\\Gamma",
  ["@d"] = "\\delta", ["@D"] = "\\Delta", ["@e"] = "\\epsilon",
  [":e"] = "\\varepsilon", ["@z"] = "\\zeta", ["@t"] = "\\theta",
  ["@T"] = "\\Theta", [":t"] = "\\vartheta", ["@i"] = "\\iota",
  ["@k"] = "\\kappa", ["@l"] = "\\lambda", ["@L"] = "\\Lambda",
  ["@s"] = "\\sigma", ["@S"] = "\\Sigma", ["@u"] = "\\upsilon",
  ["@U"] = "\\Upsilon", ["@o"] = "\\omega", ["@O"] = "\\Omega",
  ["ome"] = "\\omega", ["Ome"] = "\\Omega",
}

local function parenthesized_fraction_prefix(_, snip)
  local trigger = snip.trigger or ""
  if trigger:sub(-1) ~= "/" then
    return trigger
  end

  local stripped = trigger:sub(1, -2)
  local depth = 0
  local opening = nil
  for position = #stripped, 1, -1 do
    local character = stripped:sub(position, position)
    if character == ")" then
      depth = depth + 1
    elseif character == "(" then
      depth = depth - 1
      if depth == 0 then
        opening = position
        break
      end
    end
  end

  if not opening then
    return trigger
  end

  local prefix = stripped:sub(1, opening - 1)
  local numerator = stripped:sub(opening + 1, -2)
  return prefix .. "\\frac{" .. numerator .. "}"
end

local function greek_from_capture(_, snip)
  local trigger = (snip.captures and snip.captures[1]) or ""
  return greek_symbols[trigger] or trigger
end

local function sympy_to_latex(_, snip)
  local expression = (snip.captures and snip.captures[1]) or ""
  if vim.fn.executable("python3") ~= 1 then
    return "[python3 not found]"
  end

  local program = [[
import sys
try:
    from sympy import *
    x, y, z, t = symbols("x y z t")
    k, m, n = symbols("k m n", integer=True)
    f, g, h = symbols("f g h", cls=Function)
    raw = sys.argv[1]
    raw = raw.replace("\\\\", "").replace("^", "**").replace("{", "(").replace("}", ")")
    print(latex(eval(raw)))
except Exception as error:
    print("[sympy error: " + str(error) + "]")
]]

  local result = vim.system({ "python3", "-c", program, expression }, { text = true }):wait()
  if result.code ~= 0 then
    local message = vim.trim(result.stderr or "")
    return "[sympy error" .. (message ~= "" and ": " .. message or "") .. "]"
  end
  return vim.trim(result.stdout or "")
end

local function wolfram_to_latex(_, snip)
  local expression = (snip.captures and snip.captures[1]) or ""
  if vim.fn.executable("wolframscript") ~= 1 then
    return "[wolframscript not found]"
  end

  local code = "ToString[" .. expression .. ", TeXForm]"
  local result = vim.system({ "wolframscript", "-code", code }, { text = true }):wait()
  if result.code ~= 0 then
    local message = vim.trim(result.stderr or "")
    return "[wolframscript error" .. (message ~= "" and ": " .. message or "") .. "]"
  end
  return vim.trim(result.stdout or "")
end

-- -------------------------------------------------------------------------
-- 2. General text mode and environments
-- -------------------------------------------------------------------------
append(autosnippets, parsed(
    {
      trig = [=[dcl]=],
      name = [=[documentclass{}]=],
      dscr = [=[documentclass{}]=],
      priority = 2000,
      condition = all_conditions(in_textzone, line_begin),
      show_condition = in_textzone
    },
    [=[\documentclass{${1:class}} ${0}]=]
  ))
append(regular, parsed(
    {
      trig = [=[tmplt]=],
      name = [=[Template]=],
      dscr = [=[Template]=],
      priority = 2000,
      condition = in_textzone,
      show_condition = in_textzone
    },
    [=[\documentclass{${1:article}}

\usepackage{import}
\usepackage{pdfpages}
\usepackage{transparent}
\usepackage{xcolor}
$2
\newcommand{\incfig}[2][1]{%\def\svgwidth{#1\columnwidth}
\import{./figures/}{#2.pdf_tex}}
$3
\pdfsuppresswarningpagegroup=1	
\begin{document}
$0
\end{document}]=]
  ))
append(regular, parsed(
    {
      trig = [=[env]=],
      name = [=[New LaTeX environment]=],
      dscr = [=[New LaTeX environment]=],
      priority = 2000,
      condition = all_conditions(in_textzone, line_begin),
      show_condition = in_textzone
    },
    [=[\begin{$1}
    $2
\end{$1}
$0]=]
  ))
append(autosnippets, parsed(
    {
      trig = [=[eq]=],
      name = [=[equation environment]=],
      dscr = [=[equation environment]=],
      wordTrig = false,
      priority = 2000,
      condition = in_textzone,
      show_condition = in_textzone
    },
    [=[\begin{equation}
	${0:${TM_SELECTED_TEXT}}
\end{equation}]=]
  ))
append(autosnippets, parsed(
    {
      trig = [=[eql]=],
      name = [=[labelled equation environment]=],
      dscr = [=[labelled equation environment]=],
      wordTrig = false,
      priority = 2000,
      condition = in_textzone,
      show_condition = in_textzone
    },
    [=[\begin{equation}
	\label{eq:${2}}
	${0:${TM_SELECTED_TEXT}}
\end{equation}	]=]
  ))
append(autosnippets, parsed(
    {
      trig = [=[eq*]=],
      name = [=[unnumbered equation environment]=],
      dscr = [=[unnumbered equation environment]=],
      wordTrig = false,
      priority = 2000,
      condition = in_textzone,
      show_condition = in_textzone
    },
    [=[\begin{equation*}
	${0:${TM_SELECTED_TEXT}}
\end{equation*}]=]
  ))
append(autosnippets, parsed(
    {
      trig = [=[cas]=],
      name = [=[cases environment]=],
      dscr = [=[cases environment]=],
      wordTrig = false,
      priority = 2000,
      condition = in_textzone,
      show_condition = in_textzone
    },
    [=[\begin{cases}
	${1:equation}, &\text{ if }${2:case}\\
	${0:${TM_SELECTED_TEXT}}
\end{cases}]=]
  ))
append(autosnippets, parsed(
    {
      trig = [=[sec]=],
      name = [=[\section]=],
      dscr = [=[\section]=],
      wordTrig = false,
      priority = 2000,
      condition = in_textzone,
      show_condition = in_textzone
    },
    [=[\section{${1:section name}}%
\label{sec:${2:$1}}
${0}]=]
  ))
append(autosnippets, parsed(
    {
      trig = [=[sec*]=],
      name = [=[\section*]=],
      dscr = [=[\section*]=],
      wordTrig = false,
      priority = 2000,
      condition = in_textzone,
      show_condition = in_textzone
    },
    [=[\section*{${1:section name}}%
\label{sec:${2:$1}}
${0}]=]
  ))
append(autosnippets, parsed(
    {
      trig = [=[sub]=],
      name = [=[\subsection]=],
      dscr = [=[\subsection]=],
      wordTrig = false,
      priority = 2000,
      condition = in_textzone,
      show_condition = in_textzone
    },
    [=[\subsection{${1:subsection name}}%
\label{sub:${2:$1}}
${0}]=]
  ))
append(autosnippets, parsed(
    {
      trig = [=[sub*]=],
      name = [=[\subsection*]=],
      dscr = [=[\subsection*]=],
      wordTrig = false,
      priority = 2000,
      condition = in_textzone,
      show_condition = in_textzone
    },
    [=[\subsection*{${1:subsection name}}%
\label{sub:${2:$1}}
${0}]=]
  ))
append(regular, parsed(
    {
      trig = [=[dmo]=],
      name = [=[\DeclareMathOperator]=],
      dscr = [=[\DeclareMathOperator]=],
      priority = 2000,
      condition = all_conditions(in_textzone, line_begin),
      show_condition = in_textzone
    },
    [=[\DeclareMathOperator{${1}}{${2}}$0]=]
  ))
append(autosnippets, parsed(
    {
      trig = [=[makt]=],
      name = [=[maketitle]=],
      dscr = [=[maketitle]=],
      priority = 2000,
      condition = all_conditions(in_textzone, line_begin),
      show_condition = in_textzone
    },
    [=[\maketitle]=]
  ))
append(regular, parsed(
    {
      trig = [=[hr]=],
      name = [=[The hyperref package's \href{}{} command (for url links)]=],
      dscr = [=[The hyperref package's \href{}{} command (for url links)]=],
      priority = 2000,
      condition = in_textzone,
      show_condition = in_textzone
    },
    [=[\href{${1:url}}{${2:display name}}$0]=]
  ))
append(regular, parsed(
    {
      trig = [=[tt]=],
      name = [=[The \texttt{} command for typewriter-style font]=],
      dscr = [=[The \texttt{} command for typewriter-style font]=],
      priority = 2000,
      condition = in_textzone,
      show_condition = in_textzone
    },
    [=[\texttt{$1}$0]=]
  ))
append(regular, parsed(
    {
      trig = [=[tii]=],
      name = [=[The \textit{} command for italic font]=],
      dscr = [=[The \textit{} command for italic font]=],
      priority = 2000,
      condition = in_textzone,
      show_condition = in_textzone
    },
    [=[\textit{${1:${TM_SELECTED_TEXT}}}$0]=]
  ))

-- -------------------------------------------------------------------------
-- 3. Math entry triggers and environments
-- -------------------------------------------------------------------------
append(autosnippets, parsed(
    {
      trig = [=[(^|[^a-zA-Z])mk]=],
      name = [=[Inline LaTeX math]=],
      dscr = [=[Inline LaTeX math]=],
      trigEngine = "ecma",
      wordTrig = false,
      priority = 2000,
      condition = in_textzone,
      show_condition = in_textzone
    },
    [=[${LS_CAPTURE_1}\$ ${1:${TM_SELECTED_TEXT}} \$$0]=]
  ))
append(autosnippets, parsed(
    {
      trig = [=[(^|[^a-zA-Z])mb]=],
      name = [=[Display LaTeX math]=],
      dscr = [=[Display LaTeX math]=],
      trigEngine = "ecma",
      wordTrig = false,
      priority = 2000,
      condition = in_textzone,
      show_condition = in_textzone
    },
    [=[${LS_CAPTURE_1}$$
${1:${TM_SELECTED_TEXT}}
$$$0]=]
  ))
append(autosnippets, parsed(
    {
      trig = [=[([pbBvV]mat)]=],
      name = [=[Matrix environments]=],
      dscr = [=[Matrix environments]=],
      trigEngine = "ecma",
      wordTrig = false,
      priority = 2000,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[\begin{${LS_CAPTURE_1}rix}
    $1
\end{${LS_CAPTURE_1}rix}$0]=]
  ))
append(autosnippets, parsed(
    {
      trig = [=[(matrix|cases|align|array)]=],
      name = [=[Misc environments]=],
      dscr = [=[Misc environments]=],
      trigEngine = "ecma",
      wordTrig = false,
      priority = 2000,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[\begin{${LS_CAPTURE_1}}
    $1
\end{${LS_CAPTURE_1}}$0]=]
  ))

-- -------------------------------------------------------------------------
-- 4. Basic math, fractions, and indices
-- -------------------------------------------------------------------------
append(autosnippets, parsed(
    {
      trig = [=[//]=],
      name = [=[Fraction]=],
      dscr = [=[Fraction]=],
      wordTrig = false,
      priority = 2000,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[\frac{$1}{$2}$0]=]
  ))
append(regular, parsed(
    {
      trig = [=[ff]=],
      name = [=[This \frac{}{} snippet expands only a LaTeX math context]=],
      dscr = [=[This \frac{}{} snippet expands only a LaTeX math context]=],
      priority = 2000,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[\frac{$1}{$2}$0]=]
  ))
append(autosnippets, parsed(
    {
      trig = [=[(^|[^a-zA-Z])ff]=],
      name = [=[\frac{}{}]=],
      dscr = [=[\frac{}{}]=],
      trigEngine = "ecma",
      wordTrig = false,
      priority = 2000,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[${LS_CAPTURE_1}\frac{${1:${TM_SELECTED_TEXT}}}{$2}$0]=]
  ))
append(autosnippets, parsed(
    {
      trig = [=[((\d+)|(\d*)(\\)?([A-Za-z]+)((\^|_)(\{\d+\}|\d))*)/]=],
      name = [=[Fraction]=],
      dscr = [=[Fraction]=],
      trigEngine = "ecma",
      wordTrig = false,
      priority = 2000,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[\\frac{${LS_CAPTURE_1}}{$1}$0]=]
  ))
append(autosnippets, s(
    {
      trig = [=[^.*\)/]=],
      name = [=[() Fraction]=],
      dscr = [=[() Fraction]=],
      trigEngine = "ecma",
      wordTrig = false,
      priority = 3000,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    {
      f(parenthesized_fraction_prefix, {}),
      t("{"),
      i(1),
      t("}"),
      i(0),
    }
  ))
append(autosnippets, parsed(
    {
      trig = [=[sq]=],
      name = [=[Square root]=],
      dscr = [=[Square root]=],
      wordTrig = false,
      priority = 3000,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[\sqrt{${1:${TM_SELECTED_TEXT}}}$0]=]
  ))
append(autosnippets, parsed(
    {
      trig = [=[sr]=],
      name = [=[Square]=],
      dscr = [=[Square]=],
      wordTrig = false,
      priority = 3000,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[^{2}]=]
  ))
append(autosnippets, parsed(
    {
      trig = [=[cb]=],
      name = [=[Cube]=],
      dscr = [=[Cube]=],
      wordTrig = false,
      priority = 3000,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[^{3}]=]
  ))
append(autosnippets, parsed(
    {
      trig = [=[invs]=],
      name = [=[Inverse]=],
      dscr = [=[Inverse]=],
      wordTrig = false,
      priority = 3000,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[^{-1}]=]
  ))
append(autosnippets, parsed(
    {
      trig = [=[tp]=],
      name = [=[Transpose]=],
      dscr = [=[Transpose]=],
      wordTrig = false,
      priority = 3000,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[^{\intercal}]=]
  ))
append(autosnippets, parsed(
    {
      trig = [=[rd]=],
      name = [=[Superscript]=],
      dscr = [=[Superscript]=],
      wordTrig = false,
      priority = 3000,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[^{${1:${TM_SELECTED_TEXT}}}$0]=]
  ))
append(autosnippets, parsed(
    {
      trig = [=[_]=],
      name = [=[Subscript]=],
      dscr = [=[Subscript]=],
      wordTrig = false,
      priority = 3000,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[_{${1:${TM_SELECTED_TEXT}}}$0]=]
  ))
append(autosnippets, parsed(
    {
      trig = [=[sb]=],
      name = [=[Underscore subscript]=],
      dscr = [=[Underscore subscript]=],
      wordTrig = false,
      priority = 3000,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[_{${1:${TM_SELECTED_TEXT}}}$0]=]
  ))
append(autosnippets, parsed(
    {
      trig = [=[([a-zA-Z]|[\}\)\]\|'])00]=],
      name = [=[Automatic 0 subscript]=],
      dscr = [=[Automatic 0 subscript]=],
      trigEngine = "ecma",
      wordTrig = false,
      priority = 3000,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[${LS_CAPTURE_1}_{0}]=]
  ))
append(autosnippets, parsed(
    {
      trig = [=[(^|[^a-zA-Z])ee]=],
      name = [=[e^{} supercript]=],
      dscr = [=[e^{} supercript]=],
      trigEngine = "ecma",
      wordTrig = false,
      priority = 3000,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[${LS_CAPTURE_1}e^{${1:${TM_SELECTED_TEXT}}}$0]=]
  ))

-- -------------------------------------------------------------------------
-- 5. Automatic subscripts
-- -------------------------------------------------------------------------
append(autosnippets, parsed(
    {
      trig = [=[([a-zA-Z])(\d)]=],
      name = [=[Auto letter subscript]=],
      dscr = [=[Auto letter subscript]=],
      trigEngine = "ecma",
      wordTrig = false,
      priority = 3000,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[${LS_CAPTURE_1}_{${LS_CAPTURE_2}}]=]
  ))
append(autosnippets, parsed(
    {
      trig = [=[xnn]=],
      name = [=[x_n]=],
      dscr = [=[x_n]=],
      wordTrig = false,
      priority = 3000,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[x_{n}]=]
  ))
append(autosnippets, parsed(
    {
      trig = [=[\xii]=],
      name = [=[x_i]=],
      dscr = [=[x_i]=],
      wordTrig = false,
      priority = 2001,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[x_{i}]=]
  ))
append(autosnippets, parsed(
    {
      trig = [=[xjj]=],
      name = [=[x_j]=],
      dscr = [=[x_j]=],
      wordTrig = false,
      priority = 2001,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[x_{j}]=]
  ))
append(autosnippets, parsed(
    {
      trig = [=[xn1]=],
      name = [=[x_n+1]=],
      dscr = [=[x_n+1]=],
      wordTrig = false,
      priority = 2001,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[x_{n+1}]=]
  ))
append(autosnippets, parsed(
    {
      trig = [=[ynn]=],
      name = [=[y_n]=],
      dscr = [=[y_n]=],
      wordTrig = false,
      priority = 2001,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[y_{n}]=]
  ))
append(autosnippets, parsed(
    {
      trig = [=[yii]=],
      name = [=[y_i]=],
      dscr = [=[y_i]=],
      wordTrig = false,
      priority = 2001,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[y_{i}]=]
  ))
append(autosnippets, parsed(
    {
      trig = [=[yjj]=],
      name = [=[y_j]=],
      dscr = [=[y_j]=],
      wordTrig = false,
      priority = 2001,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[y_{j}]=]
  ))

-- -------------------------------------------------------------------------
-- 6. Fonts and text in math
-- -------------------------------------------------------------------------
append(autosnippets, parsed(
    {
      trig = [=[bf]=],
      name = [=[Bold font]=],
      dscr = [=[Bold font]=],
      wordTrig = false,
      priority = 2001,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[\mathbf{${1:${TM_SELECTED_TEXT}}}$0]=]
  ))
append(autosnippets, parsed(
    {
      trig = [=[rm]=],
      name = [=[Roman font]=],
      dscr = [=[Roman font]=],
      wordTrig = false,
      priority = 2001,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[\mathrm{${1:${TM_SELECTED_TEXT}}}$0]=]
  ))
append(autosnippets, parsed(
    {
      trig = [=[bb]=],
      name = [=[Blackboard bold]=],
      dscr = [=[Blackboard bold]=],
      wordTrig = false,
      priority = 2001,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[\mathbb{${1:${TM_SELECTED_TEXT}}}$0]=]
  ))
append(autosnippets, parsed(
    {
      trig = [=[cal]=],
      name = [=[Calligraphy font]=],
      dscr = [=[Calligraphy font]=],
      wordTrig = false,
      priority = 2001,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[\mathcal{${1:${TM_SELECTED_TEXT}}}$0]=]
  ))
append(autosnippets, parsed(
    {
      trig = [=[sts]=],
      name = [=[Subscript text]=],
      dscr = [=[Subscript text]=],
      wordTrig = false,
      priority = 2001,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[_{\text{${1:${TM_SELECTED_TEXT}}}}$0]=]
  ))
append(autosnippets, parsed(
    {
      trig = [=[([a-zA-Z0-9_})\]|])sd]=],
      name = [=[Subscript with upright text]=],
      dscr = [=[Subscript with upright text]=],
      trigEngine = "ecma",
      wordTrig = false,
      priority = 2001,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[${LS_CAPTURE_1}_{\mathrm{${1:${TM_SELECTED_TEXT}}}}$0]=]
  ))

-- -------------------------------------------------------------------------
-- 7. Postfix modifiers and standalone operations
-- -------------------------------------------------------------------------
append(autosnippets, parsed(
    {
      trig = [=[\\wide(tilde|hat|bar|vec)]=],
      name = [=[Wide operations]=],
      dscr = [=[Wide operations]=],
      trigEngine = "ecma",
      wordTrig = false,
      priority = 2100,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[\wide${LS_CAPTURE_1}{${1:${TM_SELECTED_TEXT}}}$0]=]
  ))
append(autosnippets, parsed(
    {
      trig = [=[([a-zA-Z])hat]=],
      name = [=[hat postfix]=],
      dscr = [=[hat postfix]=],
      trigEngine = "ecma",
      wordTrig = false,
      priority = 2010,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[\hat{${LS_CAPTURE_1}$1}$0]=]
  ))
append(autosnippets, parsed(
    {
      trig = [=[([a-zA-Z])bar]=],
      name = [=[bar postfix]=],
      dscr = [=[bar postfix]=],
      trigEngine = "ecma",
      wordTrig = false,
      priority = 2010,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[\bar{${LS_CAPTURE_1}$1}$0]=]
  ))
append(autosnippets, parsed(
    {
      trig = [=[([a-zA-Z])tilde]=],
      name = [=[tilde postfix]=],
      dscr = [=[tilde postfix]=],
      trigEngine = "ecma",
      wordTrig = false,
      priority = 2010,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[\tilde{${LS_CAPTURE_1}$1}$0]=]
  ))
append(autosnippets, parsed(
    {
      trig = [=[([a-zA-Z])und]=],
      name = [=[underline postfix]=],
      dscr = [=[underline postfix]=],
      trigEngine = "ecma",
      wordTrig = false,
      priority = 2010,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[\underline{${LS_CAPTURE_1}$1}$0]=]
  ))
append(autosnippets, parsed(
    {
      trig = [=[([a-zA-Z])vec]=],
      name = [=[vec postfix]=],
      dscr = [=[vec postfix]=],
      trigEngine = "ecma",
      wordTrig = false,
      priority = 2010,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[\vec{${LS_CAPTURE_1}$1}$0]=]
  ))
append(autosnippets, parsed(
    {
      trig = [=[\\([a-zA-Z]+)([.,]{2})]=],
      name = [=[boldsymbol Greek postfix]=],
      dscr = [=[boldsymbol Greek postfix]=],
      trigEngine = "ecma",
      wordTrig = false,
      priority = 2010,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[\boldsymbol{\\${LS_CAPTURE_1}$1}$0]=]
  ))
append(autosnippets, parsed(
    {
      trig = [=[([a-zA-Z])ddot]=],
      name = [=[ddot postfix]=],
      dscr = [=[ddot postfix]=],
      trigEngine = "ecma",
      wordTrig = false,
      priority = 2001,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[\ddot{${LS_CAPTURE_1}}]=]
  ))
append(autosnippets, parsed(
    {
      trig = [=[([a-zA-Z])dot]=],
      name = [=[dot postfix]=],
      dscr = [=[dot postfix]=],
      trigEngine = "ecma",
      wordTrig = false,
      priority = 2000,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[\dot{${LS_CAPTURE_1}}]=]
  ))
append(autosnippets, parsed(
    {
      trig = [=[([a-zA-Z])([.,]{2})]=],
      name = [=[mathbf postfix]=],
      dscr = [=[mathbf postfix]=],
      trigEngine = "ecma",
      wordTrig = false,
      priority = 2000,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[\mathbf{${LS_CAPTURE_1}$1}$0]=]
  ))
append(autosnippets, parsed(
    {
      trig = [=[ddot]=],
      name = [=[ddot]=],
      dscr = [=[ddot]=],
      wordTrig = false,
      priority = 2001,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[\ddot{${1:${TM_SELECTED_TEXT}}}$0]=]
  ))
append(autosnippets, parsed(
    {
      trig = [=[dot]=],
      name = [=[dot]=],
      dscr = [=[dot]=],
      wordTrig = false,
      priority = 2000,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[\dot{${1:${TM_SELECTED_TEXT}}}$0]=]
  ))
append(autosnippets, parsed(
    {
      trig = [=[hat]=],
      name = [=[hat]=],
      dscr = [=[hat]=],
      wordTrig = false,
      priority = 2000,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[\hat{${1:${TM_SELECTED_TEXT}}}$0]=]
  ))
append(autosnippets, parsed(
    {
      trig = [=[bar]=],
      name = [=[bar]=],
      dscr = [=[bar]=],
      wordTrig = false,
      priority = 2000,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[\bar{${1:${TM_SELECTED_TEXT}}}$0]=]
  ))
append(autosnippets, parsed(
    {
      trig = [=[tilde]=],
      name = [=[tilde]=],
      dscr = [=[tilde]=],
      wordTrig = false,
      priority = 2000,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[\tilde{${1:${TM_SELECTED_TEXT}}}$0]=]
  ))
append(autosnippets, parsed(
    {
      trig = [=[und]=],
      name = [=[underline]=],
      dscr = [=[underline]=],
      wordTrig = false,
      priority = 2000,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[\underline{${1:${TM_SELECTED_TEXT}}}$0]=]
  ))
append(autosnippets, parsed(
    {
      trig = [=[vec]=],
      name = [=[vec]=],
      dscr = [=[vec]=],
      wordTrig = false,
      priority = 2000,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[\vec{${1:${TM_SELECTED_TEXT}}}$0]=]
  ))

-- -------------------------------------------------------------------------
-- 8. Greek letters
-- -------------------------------------------------------------------------
append(autosnippets, s(
    {
      trig = [=[(@[a-zA-Z]|:e|:t|ome|Ome)]=],
      name = [=[Greek letter auto-expansion]=],
      dscr = [=[Greek letter auto-expansion]=],
      trigEngine = "ecma",
      wordTrig = false,
      priority = 2000,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    { f(greek_from_capture, {}) }
  ))
append(autosnippets, parsed(
    {
      trig = [=[([^\\])(alpha|beta|gamma|delta|epsilon|varepsilon|zeta|eta|theta|vartheta|iota|kappa|lambda|mu|nu|xi|pi|rho|sigma|tau|upsilon|phi|chi|psi|omega|Gamma|Delta|Theta|Lambda|Xi|Pi|Sigma|Upsilon|Phi|Psi|Omega)]=],
      name = [=[Add backslash before Greek]=],
      dscr = [=[Add backslash before Greek]=],
      trigEngine = "ecma",
      wordTrig = false,
      priority = 2000,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[${LS_CAPTURE_1}\\${LS_CAPTURE_2}]=]
  ))
append(autosnippets, parsed(
    {
      trig = [=[\\(alpha|beta|gamma|delta|epsilon|varepsilon|zeta|eta|theta|vartheta|iota|kappa|lambda|mu|nu|xi|pi|rho|sigma|tau|upsilon|phi|chi|psi|omega|Gamma|Delta|Theta|Lambda|Xi|Pi|Sigma|Upsilon|Phi|Psi|Omega)([A-Za-z])]=],
      name = [=[Space after Greek]=],
      dscr = [=[Space after Greek]=],
      trigEngine = "ecma",
      wordTrig = false,
      priority = 2000,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[\\${LS_CAPTURE_1} ${LS_CAPTURE_2}]=]
  ))
append(autosnippets, parsed(
    {
      trig = [=[\\([a-zA-Z]+) sr]=],
      name = [=[Square]=],
      dscr = [=[Square]=],
      trigEngine = "ecma",
      wordTrig = false,
      priority = 2000,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[\\${LS_CAPTURE_1}^{2}]=]
  ))
append(autosnippets, parsed(
    {
      trig = [=[\\([a-zA-Z]+) cb]=],
      name = [=[Cube]=],
      dscr = [=[Cube]=],
      trigEngine = "ecma",
      wordTrig = false,
      priority = 2000,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[\\${LS_CAPTURE_1}^{3}]=]
  ))
append(autosnippets, parsed(
    {
      trig = [=[\\([a-zA-Z]+) rd]=],
      name = [=[Superscript]=],
      dscr = [=[Superscript]=],
      trigEngine = "ecma",
      wordTrig = false,
      priority = 2000,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[\\${LS_CAPTURE_1}^{$1}$0]=]
  ))
append(autosnippets, parsed(
    {
      trig = [=[\\([a-zA-Z]+) hat]=],
      name = [=[hat]=],
      dscr = [=[hat]=],
      trigEngine = "ecma",
      wordTrig = false,
      priority = 2000,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[\hat{\\${LS_CAPTURE_1}}]=]
  ))
append(autosnippets, parsed(
    {
      trig = [=[\\([a-zA-Z]+) dot]=],
      name = [=[dot]=],
      dscr = [=[dot]=],
      trigEngine = "ecma",
      wordTrig = false,
      priority = 2000,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[\dot{\\${LS_CAPTURE_1}}]=]
  ))
append(autosnippets, parsed(
    {
      trig = [=[\\([a-zA-Z]+) bar]=],
      name = [=[bar]=],
      dscr = [=[bar]=],
      trigEngine = "ecma",
      wordTrig = false,
      priority = 2000,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[\bar{\\${LS_CAPTURE_1}}]=]
  ))
append(autosnippets, parsed(
    {
      trig = [=[\\([a-zA-Z]+) vec]=],
      name = [=[vec]=],
      dscr = [=[vec]=],
      trigEngine = "ecma",
      wordTrig = false,
      priority = 2000,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[\vec{\\${LS_CAPTURE_1}}]=]
  ))
append(autosnippets, parsed(
    {
      trig = [=[\\([a-zA-Z]+) tilde]=],
      name = [=[tilde]=],
      dscr = [=[tilde]=],
      trigEngine = "ecma",
      wordTrig = false,
      priority = 2000,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[\tilde{\\${LS_CAPTURE_1}}]=]
  ))
append(autosnippets, parsed(
    {
      trig = [=[\\([a-zA-Z]+) und]=],
      name = [=[underline]=],
      dscr = [=[underline]=],
      trigEngine = "ecma",
      wordTrig = false,
      priority = 2000,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[\underline{\\${LS_CAPTURE_1}}]=]
  ))

-- -------------------------------------------------------------------------
-- 9. Calculus and linear algebra
-- -------------------------------------------------------------------------
append(autosnippets, parsed(
    {
      trig = [=[([^a-zA-Z0-9])df]=],
      name = [=[\diff]=],
      dscr = [=[\diff]=],
      trigEngine = "ecma",
      wordTrig = false,
      priority = 2000,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[${LS_CAPTURE_1}\diff ]=]
  ))
append(regular, parsed(
    {
      trig = [=[pdv]=],
      name = [=[Partial derivative]=],
      dscr = [=[Partial derivative]=],
      wordTrig = false,
      priority = 2000,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[\frac{ \partial ${1:y} }{ \partial ${2:x} } $0]=]
  ))
append(regular, parsed(
    {
      trig = [=[ppdv]=],
      name = [=[Second partial derivative]=],
      dscr = [=[Second partial derivative]=],
      wordTrig = false,
      priority = 2000,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[\frac{\partial^2 {$1}}{\partial {$2} \partial {$3}} {$0}]=]
  ))
append(regular, parsed(
    {
      trig = [=[pa([a-zA-Z])([a-zA-Z])]=],
      name = [=[Auto partial derivative]=],
      dscr = [=[Auto partial derivative]=],
      trigEngine = "ecma",
      wordTrig = false,
      priority = 2000,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[\frac{ \partial ${LS_CAPTURE_1} }{ \partial ${LS_CAPTURE_2} } $0]=]
  ))
append(regular, parsed(
    {
      trig = [=[int]=],
      name = [=[Integral block]=],
      dscr = [=[Integral block]=],
      trigEngine = "ecma",
      wordTrig = false,
      priority = 2000,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[\int $1 \, d${2:x} $0]=]
  ))
append(autosnippets, parsed(
    {
      trig = [=[dint]=],
      name = [=[Definite integral]=],
      dscr = [=[Definite integral]=],
      wordTrig = false,
      priority = 2000,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[\int_{${1:0}}^{${2:1}} $3 \, d${4:x} $0]=]
  ))
append(autosnippets, parsed(
    {
      trig = [=[oint]=],
      name = [=[Contour integral]=],
      dscr = [=[Contour integral]=],
      wordTrig = false,
      priority = 2000,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[\oint]=]
  ))
append(autosnippets, parsed(
    {
      trig = [=[iint]=],
      name = [=[Double integral]=],
      dscr = [=[Double integral]=],
      wordTrig = false,
      priority = 2000,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[\iint]=]
  ))
append(autosnippets, parsed(
    {
      trig = [=[iiint]=],
      name = [=[Triple integral]=],
      dscr = [=[Triple integral]=],
      wordTrig = false,
      priority = 2000,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[\iiint]=]
  ))
append(autosnippets, parsed(
    {
      trig = [=[oinf]=],
      name = [=[Zero to infinity]=],
      dscr = [=[Zero to infinity]=],
      wordTrig = false,
      priority = 2000,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[\int_{0}^{\infty} $1 \, d${2:x} $0]=]
  ))
append(autosnippets, parsed(
    {
      trig = [=[infi]=],
      name = [=[Minus infinity to infinity]=],
      dscr = [=[Minus infinity to infinity]=],
      wordTrig = false,
      priority = 2000,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[\int_{-\infty}^{\infty} $1 \, d${2:x} $0]=]
  ))
append(autosnippets, parsed(
    {
      trig = [=[tsum]=],
      name = [=[Sum with limits]=],
      dscr = [=[Sum with limits]=],
      wordTrig = false,
      priority = 2000,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[\sum_{${1:t}=${2:1}}^{${3:T}} $0]=]
  ))
append(regular, parsed(
    {
      trig = [=[asum]=],
      name = [=[Sum a in A]=],
      dscr = [=[Sum a in A]=],
      wordTrig = false,
      priority = 2000,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[\sum_{a\in\mathcal{A}}]=]
  ))
append(autosnippets, parsed(
    {
      trig = [=[tprod]=],
      name = [=[Product with limits]=],
      dscr = [=[Product with limits]=],
      wordTrig = false,
      priority = 2000,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[\prod_{${1:t}=${2:1}}^{${3:T}} $0]=]
  ))
append(regular, parsed(
    {
      trig = [=[sum]=],
      name = [=[Sum]=],
      dscr = [=[Sum]=],
      wordTrig = false,
      priority = 2000,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[\sum]=]
  ))
append(regular, parsed(
    {
      trig = [=[prod]=],
      name = [=[Product]=],
      dscr = [=[Product]=],
      wordTrig = false,
      priority = 2000,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[\prod]=]
  ))
append(autosnippets, parsed(
    {
      trig = [=[lim]=],
      name = [=[Limit]=],
      dscr = [=[Limit]=],
      wordTrig = false,
      priority = 2000,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[\lim_{ ${1:n} \to ${2:\infty} } $0]=]
  ))
append(autosnippets, parsed(
    {
      trig = [=[(^|[^a-zA-Z\\])(det)]=],
      name = [=[Determinant]=],
      dscr = [=[Determinant]=],
      trigEngine = "ecma",
      wordTrig = false,
      priority = 2000,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[${LS_CAPTURE_1}\\${LS_CAPTURE_2}]=]
  ))
append(autosnippets, parsed(
    {
      trig = [=[trace]=],
      name = [=[Trace]=],
      dscr = [=[Trace]=],
      wordTrig = false,
      priority = 2000,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[\mathrm{Tr}]=]
  ))
append(autosnippets, parsed(
    {
      trig = [=[Id]=],
      name = [=[Identity]=],
      dscr = [=[Identity]=],
      wordTrig = false,
      priority = 2000,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[\mathrm{Id}]=]
  ))

-- -------------------------------------------------------------------------
-- 10. Trigonometry and complex functions
-- -------------------------------------------------------------------------
append(autosnippets, parsed(
    {
      trig = [=[(^|[^a-zA-Z\\])(exp|log|ln)]=],
      name = [=[Math functions]=],
      dscr = [=[Math functions]=],
      trigEngine = "ecma",
      wordTrig = false,
      priority = 2000,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[${LS_CAPTURE_1}\\${LS_CAPTURE_2}]=]
  ))
append(autosnippets, parsed(
    {
      trig = [=[([^\\])(arcsin|sin|arccos|cos|arctan|tan|csc|sec|cot)]=],
      name = [=[Add backslash before trig]=],
      dscr = [=[Add backslash before trig]=],
      trigEngine = "ecma",
      wordTrig = false,
      priority = 2000,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[${LS_CAPTURE_1}\\${LS_CAPTURE_2}]=]
  ))
append(autosnippets, parsed(
    {
      trig = [=[\\(arcsin|sin|arccos|cos|arctan|tan|csc|sec|cot)([A-Za-gi-z])]=],
      name = [=[Space after trig]=],
      dscr = [=[Space after trig]=],
      trigEngine = "ecma",
      wordTrig = false,
      priority = 2000,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[\\${LS_CAPTURE_1} ${LS_CAPTURE_2}]=]
  ))
append(autosnippets, parsed(
    {
      trig = [=[\\(sinh|cosh|tanh|coth)([A-Za-z])]=],
      name = [=[Space after hyperbolic trig]=],
      dscr = [=[Space after hyperbolic trig]=],
      trigEngine = "ecma",
      wordTrig = false,
      priority = 2000,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[\\${LS_CAPTURE_1} ${LS_CAPTURE_2}]=]
  ))
append(autosnippets, parsed(
    {
      trig = [=[(arccsc|arcsec|arccot|arcsinh|arcosh|arctanh|arcsech|arcsch|arcoth)]=],
      name = [=[Inverse trig operators]=],
      dscr = [=[Inverse trig operators]=],
      trigEngine = "ecma",
      wordTrig = false,
      priority = 2001,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[\operatorname{${LS_CAPTURE_1}}$0]=]
  ))
append(autosnippets, parsed(
    {
      trig = [=[conj]=],
      name = [=[Conjugate]=],
      dscr = [=[Conjugate]=],
      wordTrig = false,
      priority = 2001,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[^{*}]=]
  ))
append(autosnippets, parsed(
    {
      trig = [=[Re]=],
      name = [=[Real part]=],
      dscr = [=[Real part]=],
      wordTrig = false,
      priority = 2001,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[\mathrm{Re}]=]
  ))
append(autosnippets, parsed(
    {
      trig = [=[Im]=],
      name = [=[Imaginary part]=],
      dscr = [=[Imaginary part]=],
      wordTrig = false,
      priority = 2001,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[\mathrm{Im}]=]
  ))

-- -------------------------------------------------------------------------
-- 11. Symbols and logic
-- -------------------------------------------------------------------------
append(autosnippets, parsed(
    {
      trig = [=[ooo]=],
      name = [=[infinity]=],
      dscr = [=[infinity]=],
      wordTrig = false,
      priority = 2001,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[\infty]=]
  ))
append(autosnippets, parsed(
    {
      trig = [=[min]=],
      name = [=[min]=],
      dscr = [=[min]=],
      wordTrig = false,
      priority = 2001,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[\min]=]
  ))
append(autosnippets, parsed(
    {
      trig = [=[max]=],
      name = [=[max]=],
      dscr = [=[max]=],
      wordTrig = false,
      priority = 2001,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[\max]=]
  ))
append(autosnippets, parsed(
    {
      trig = [=[if]=],
      name = [=[inf]=],
      dscr = [=[inf]=],
      wordTrig = false,
      priority = 2001,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[\inf]=]
  ))
append(autosnippets, parsed(
    {
      trig = [=[sup]=],
      name = [=[sup]=],
      dscr = [=[sup]=],
      wordTrig = false,
      priority = 2001,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[\sup]=]
  ))
append(regular, parsed(
    {
      trig = [=[argmin]=],
      name = [=[argmin]=],
      dscr = [=[argmin]=],
      wordTrig = false,
      priority = 2001,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[\underset{${1:x}}{\arg\min}${2:f}$0]=]
  ))
append(regular, parsed(
    {
      trig = [=[argmax]=],
      name = [=[argmax]=],
      dscr = [=[argmax]=],
      wordTrig = false,
      priority = 2001,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[\underset{${1:x}}{\arg\max}${2:f}$0]=]
  ))
append(autosnippets, parsed(
    {
      trig = [=[pmod]=],
      name = [=[pmod parenthesized modulo]=],
      dscr = [=[pmod parenthesized modulo]=],
      wordTrig = false,
      priority = 2001,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[\pmod{${1:n}}$0]=]
  ))
append(autosnippets, parsed(
    {
      trig = [=[+-]=],
      name = [=[pm]=],
      dscr = [=[pm]=],
      wordTrig = false,
      priority = 2001,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[\pm]=]
  ))
append(autosnippets, parsed(
    {
      trig = [=[-+]=],
      name = [=[mp]=],
      dscr = [=[mp]=],
      wordTrig = false,
      priority = 2001,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[\mp]=]
  ))
append(autosnippets, parsed(
    {
      trig = [=[:=]=],
      name = [=[coloneqq]=],
      dscr = [=[coloneqq]=],
      wordTrig = false,
      priority = 2001,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[\coloneqq]=]
  ))
append(autosnippets, parsed(
    {
      trig = [=[===]=],
      name = [=[equiv]=],
      dscr = [=[equiv]=],
      wordTrig = false,
      priority = 2001,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[\equiv]=]
  ))
append(autosnippets, parsed(
    {
      trig = [=[!=]=],
      name = [=[neq]=],
      dscr = [=[neq]=],
      wordTrig = false,
      priority = 2001,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[\neq]=]
  ))
append(autosnippets, parsed(
    {
      trig = [=[>=]=],
      name = [=[geq]=],
      dscr = [=[geq]=],
      wordTrig = false,
      priority = 2001,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[\geq]=]
  ))
append(autosnippets, parsed(
    {
      trig = [=[<=]=],
      name = [=[leq]=],
      dscr = [=[leq]=],
      wordTrig = false,
      priority = 2001,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[\leq]=]
  ))
append(autosnippets, parsed(
    {
      trig = [=[>>]=],
      name = [=[gg]=],
      dscr = [=[gg]=],
      wordTrig = false,
      priority = 2001,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[\gg]=]
  ))
append(autosnippets, parsed(
    {
      trig = [=[<<]=],
      name = [=[ll]=],
      dscr = [=[ll]=],
      wordTrig = false,
      priority = 2001,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[\ll]=]
  ))
append(autosnippets, parsed(
    {
      trig = [=[>~]=],
      name = [=[gtrsim]=],
      dscr = [=[gtrsim]=],
      wordTrig = false,
      priority = 2001,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[\gtrsim]=]
  ))
append(autosnippets, parsed(
    {
      trig = [=[<~]=],
      name = [=[lesssim]=],
      dscr = [=[lesssim]=],
      wordTrig = false,
      priority = 2001,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[\lesssim]=]
  ))
append(autosnippets, parsed(
    {
      trig = [=[~~]=],
      name = [=[approx]=],
      dscr = [=[approx]=],
      wordTrig = false,
      priority = 2001,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[\approx]=]
  ))
append(autosnippets, parsed(
    {
      trig = [=[simm]=],
      name = [=[sim]=],
      dscr = [=[sim]=],
      wordTrig = false,
      priority = 2001,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[\sim]=]
  ))
append(autosnippets, parsed(
    {
      trig = [=[sim=]=],
      name = [=[simeq]=],
      dscr = [=[simeq]=],
      wordTrig = false,
      priority = 2001,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[\simeq]=]
  ))
append(autosnippets, parsed(
    {
      trig = [=[prop]=],
      name = [=[propto]=],
      dscr = [=[propto]=],
      wordTrig = false,
      priority = 2001,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[\propto]=]
  ))
append(autosnippets, parsed(
    {
      trig = [=[<->]=],
      name = [=[leftrightarrow]=],
      dscr = [=[leftrightarrow]=],
      wordTrig = false,
      priority = 2001,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[\leftrightarrow ]=]
  ))
append(autosnippets, parsed(
    {
      trig = [=[->]=],
      name = [=[to]=],
      dscr = [=[to]=],
      wordTrig = false,
      priority = 2001,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[\to]=]
  ))
append(autosnippets, parsed(
    {
      trig = [=[!>]=],
      name = [=[mapsto]=],
      dscr = [=[mapsto]=],
      wordTrig = false,
      priority = 2001,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[\mapsto]=]
  ))
append(autosnippets, parsed(
    {
      trig = [=[=>]=],
      name = [=[implies]=],
      dscr = [=[implies]=],
      wordTrig = false,
      priority = 2001,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[\implies]=]
  ))
append(autosnippets, parsed(
    {
      trig = [=[=<]=],
      name = [=[impliedby]=],
      dscr = [=[impliedby]=],
      wordTrig = false,
      priority = 2001,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[\impliedby]=]
  ))
append(autosnippets, parsed(
    {
      trig = [=[and]=],
      name = [=[cap]=],
      dscr = [=[cap]=],
      wordTrig = false,
      priority = 2001,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[\cap]=]
  ))
append(autosnippets, parsed(
    {
      trig = [=[orr]=],
      name = [=[cup]=],
      dscr = [=[cup]=],
      wordTrig = false,
      priority = 2001,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[\cup]=]
  ))
append(autosnippets, parsed(
    {
      trig = [=[inn]=],
      name = [=[in]=],
      dscr = [=[in]=],
      wordTrig = false,
      priority = 2001,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[\in]=]
  ))
append(autosnippets, parsed(
    {
      trig = [=[notin]=],
      name = [=[notin]=],
      dscr = [=[notin]=],
      wordTrig = false,
      priority = 2001,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[\not\in]=]
  ))
append(autosnippets, parsed(
    {
      trig = [=[\\\]=],
      name = [=[setminus]=],
      dscr = [=[setminus]=],
      wordTrig = false,
      priority = 2001,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[\setminus]=]
  ))
append(autosnippets, parsed(
    {
      trig = [=[sub=]=],
      name = [=[subseteq]=],
      dscr = [=[subseteq]=],
      wordTrig = false,
      priority = 2001,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[\subseteq]=]
  ))
append(autosnippets, parsed(
    {
      trig = [=[sup=]=],
      name = [=[supseteq]=],
      dscr = [=[supseteq]=],
      wordTrig = false,
      priority = 2001,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[\supseteq]=]
  ))
append(autosnippets, parsed(
    {
      trig = [=[eset]=],
      name = [=[emptyset]=],
      dscr = [=[emptyset]=],
      wordTrig = false,
      priority = 2001,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[\emptyset]=]
  ))
append(autosnippets, parsed(
    {
      trig = [=[set]=],
      name = [=[set]=],
      dscr = [=[set]=],
      wordTrig = false,
      priority = 2001,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[\\{ $1 \\}$0]=]
  ))
append(autosnippets, parsed(
    {
      trig = [=[for]=],
      name = [=[forall]=],
      dscr = [=[forall]=],
      wordTrig = false,
      priority = 2001,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[\forall]=]
  ))
append(autosnippets, parsed(
    {
      trig = [=[exi]=],
      name = [=[exists]=],
      dscr = [=[exists]=],
      wordTrig = false,
      priority = 2001,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[\exists]=]
  ))
append(autosnippets, parsed(
    {
      trig = [=[...]=],
      name = [=[dots]=],
      dscr = [=[dots]=],
      wordTrig = false,
      priority = 2001,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[\dots]=]
  ))
append(autosnippets, parsed(
    {
      trig = [=[nabl]=],
      name = [=[nabla]=],
      dscr = [=[nabla]=],
      wordTrig = false,
      priority = 2001,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[\nabla]=]
  ))
append(autosnippets, parsed(
    {
      trig = [=[xx]=],
      name = [=[times]=],
      dscr = [=[times]=],
      wordTrig = false,
      priority = 2001,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[\times]=]
  ))
append(autosnippets, parsed(
    {
      trig = [=[**]=],
      name = [=[cdot]=],
      dscr = [=[cdot]=],
      wordTrig = false,
      priority = 2001,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[\cdot]=]
  ))
append(autosnippets, parsed(
    {
      trig = [=[cdot]=],
      name = [=[cdot]=],
      dscr = [=[cdot]=],
      wordTrig = false,
      priority = 2001,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[\cdot]=]
  ))
append(autosnippets, parsed(
    {
      trig = [=[para]=],
      name = [=[parallel]=],
      dscr = [=[parallel]=],
      wordTrig = false,
      priority = 2001,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[\parallel]=]
  ))
append(autosnippets, parsed(
    {
      trig = [=[LL]=],
      name = [=[mathcal L]=],
      dscr = [=[mathcal L]=],
      wordTrig = false,
      priority = 2001,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[\mathcal{L}]=]
  ))
append(autosnippets, parsed(
    {
      trig = [=[HH]=],
      name = [=[mathcal H]=],
      dscr = [=[mathcal H]=],
      wordTrig = false,
      priority = 2001,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[\mathcal{H}]=]
  ))
append(autosnippets, parsed(
    {
      trig = [=[OO]=],
      name = [=[mathcal O]=],
      dscr = [=[mathcal O]=],
      wordTrig = false,
      priority = 2001,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[\mathcal{O}]=]
  ))
append(autosnippets, parsed(
    {
      trig = [=[FF]=],
      name = [=[mathcal F]=],
      dscr = [=[mathcal F]=],
      wordTrig = false,
      priority = 2001,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[\mathcal{F}]=]
  ))
append(autosnippets, parsed(
    {
      trig = [=[AA]=],
      name = [=[mathcal A]=],
      dscr = [=[mathcal A]=],
      wordTrig = false,
      priority = 2001,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[\mathcal{A}]=]
  ))
append(autosnippets, parsed(
    {
      trig = [=[CC]=],
      name = [=[mathbb C]=],
      dscr = [=[mathbb C]=],
      wordTrig = false,
      priority = 2001,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[\mathbb{C}]=]
  ))
append(autosnippets, parsed(
    {
      trig = [=[RR]=],
      name = [=[mathbb R]=],
      dscr = [=[mathbb R]=],
      wordTrig = false,
      priority = 2001,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[\mathbb{R}]=]
  ))
append(autosnippets, parsed(
    {
      trig = [=[ZZ]=],
      name = [=[mathbb Z]=],
      dscr = [=[mathbb Z]=],
      wordTrig = false,
      priority = 2001,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[\mathbb{Z}]=]
  ))
append(autosnippets, parsed(
    {
      trig = [=[EE]=],
      name = [=[mathbb E]=],
      dscr = [=[mathbb E]=],
      wordTrig = false,
      priority = 2001,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[\mathbb{E}[ $1 ]$0]=]
  ))
append(autosnippets, parsed(
    {
      trig = [=[tEE]=],
      name = [=[mathbb E_t]=],
      dscr = [=[mathbb E_t]=],
      wordTrig = false,
      priority = 2001,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[\mathbb{E}_t[ $1 ]$0]=]
  ))
append(autosnippets, parsed(
    {
      trig = [=[nat]=],
      name = [=[mathbb N]=],
      dscr = [=[mathbb N]=],
      wordTrig = false,
      priority = 2001,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[\mathbb{N}]=]
  ))
append(autosnippets, parsed(
    {
      trig = [=[real]=],
      name = [=[mathbb N]=],
      dscr = [=[mathbb N]=],
      wordTrig = false,
      priority = 2001,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[\mathbb{N}]=]
  ))
append(autosnippets, parsed(
    {
      trig = [=[comp]=],
      name = [=[mathbb N]=],
      dscr = [=[mathbb N]=],
      wordTrig = false,
      priority = 2001,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[\mathbb{N}]=]
  ))
append(autosnippets, parsed(
    {
      trig = [=[ept]=],
      name = [=[mathbb E]=],
      dscr = [=[mathbb E]=],
      wordTrig = false,
      priority = 2001,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[\mathbb{E}[ $1 ]$0]=]
  ))
append(autosnippets, parsed(
    {
      trig = [=[Var]=],
      name = [=[Var]=],
      dscr = [=[Var]=],
      wordTrig = false,
      priority = 2001,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[\mathrm{Var}[ $1 ]$0]=]
  ))
append(autosnippets, parsed(
    {
      trig = [=[II]=],
      name = [=[mathbb I]=],
      dscr = [=[mathbb I]=],
      wordTrig = false,
      priority = 2001,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[\mathbb{I}\\{ $1 \\}$0]=]
  ))
append(autosnippets, parsed(
    {
      trig = [=[Pr]=],
      name = [=[mathbb P]=],
      dscr = [=[mathbb P]=],
      wordTrig = false,
      priority = 2001,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[\mathbb{P}( $1 )$0]=]
  ))

-- -------------------------------------------------------------------------
-- 12. Brackets and delimiters
-- -------------------------------------------------------------------------
append(autosnippets, parsed(
    {
      trig = [=[avg]=],
      name = [=[Average]=],
      dscr = [=[Average]=],
      wordTrig = false,
      priority = 2001,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[\langle $1 \rangle $0]=]
  ))
append(autosnippets, parsed(
    {
      trig = [=[norm]=],
      name = [=[Norm absolute]=],
      dscr = [=[Norm absolute]=],
      wordTrig = false,
      priority = 2001,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[\lvert $1 \rvert $0]=]
  ))
append(autosnippets, parsed(
    {
      trig = [=[Norm]=],
      name = [=[Norm double]=],
      dscr = [=[Norm double]=],
      wordTrig = false,
      priority = 2001,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[\lVert $1 \rVert $0]=]
  ))
append(autosnippets, parsed(
    {
      trig = [=[ceil]=],
      name = [=[Ceil]=],
      dscr = [=[Ceil]=],
      wordTrig = false,
      priority = 2000,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[\lceil $1 \rceil $0]=]
  ))
append(autosnippets, parsed(
    {
      trig = [=[floor]=],
      name = [=[Floor]=],
      dscr = [=[Floor]=],
      wordTrig = false,
      priority = 2000,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[\lfloor $1 \rfloor $0]=]
  ))
append(autosnippets, parsed(
    {
      trig = [=[mod]=],
      name = [=[Modulus]=],
      dscr = [=[Modulus]=],
      wordTrig = false,
      priority = 2000,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[|$1|$0]=]
  ))
append(autosnippets, parsed(
    {
      trig = [=[(]=],
      name = [=[Parentheses]=],
      dscr = [=[Parentheses]=],
      wordTrig = false,
      priority = 2000,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[(${1:${TM_SELECTED_TEXT}})$0]=]
  ))
append(autosnippets, parsed(
    {
      trig = [=[[]=],
      name = [=[Square brackets]=],
      dscr = [=[Square brackets]=],
      wordTrig = false,
      priority = 2000,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[[${1:${TM_SELECTED_TEXT}}]$0]=]
  ))
append(autosnippets, parsed(
    {
      trig = [=[{]=],
      name = [=[Curly braces]=],
      dscr = [=[Curly braces]=],
      wordTrig = false,
      priority = 2000,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[{${1:${TM_SELECTED_TEXT}}}$0]=]
  ))
append(autosnippets, parsed(
    {
      trig = [=[lr(]=],
      name = [=[Left right parens]=],
      dscr = [=[Left right parens]=],
      wordTrig = false,
      priority = 2000,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[\left( $1 \right) $0]=]
  ))
append(autosnippets, parsed(
    {
      trig = [=[lr{]=],
      name = [=[Left right braces]=],
      dscr = [=[Left right braces]=],
      wordTrig = false,
      priority = 2000,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[\left\\{ $1 \right\\} $0]=]
  ))
append(autosnippets, parsed(
    {
      trig = [=[lr[]=],
      name = [=[Left right brackets]=],
      dscr = [=[Left right brackets]=],
      wordTrig = false,
      priority = 2000,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[\left[ $1 \right] $0]=]
  ))
append(autosnippets, parsed(
    {
      trig = [=[lr|]=],
      name = [=[Left right abs]=],
      dscr = [=[Left right abs]=],
      wordTrig = false,
      priority = 2000,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[\left| $1 \right| $0]=]
  ))
append(autosnippets, parsed(
    {
      trig = [=[lra]=],
      name = [=[Left right angle]=],
      dscr = [=[Left right angle]=],
      wordTrig = false,
      priority = 2000,
      condition = in_mathzone,
      show_condition = in_mathzone
    },
    [=[\left< $1 \right> $0]=]
  ))

-- -------------------------------------------------------------------------
-- 14. Debug, symbolic evaluation, and miscellaneous regex triggers
-- -------------------------------------------------------------------------
if ENABLE_DEBUG_TRIGGER_EXAMPLES then
  append(regular, parsed(
    {
      trig = [=[([^a-zA-Z])trigger]=],
      name = [=[Expands if 'trigger' is typed after characters other than a-z or A-Z]=],
      dscr = [=[Expands if 'trigger' is typed after characters other than a-z or A-Z]=],
      trigEngine = "ecma",
      wordTrig = false,
      priority = 2000,
      hidden = true
    },
    [=[${LS_CAPTURE_1}snippet body]=]
  ))
end
if ENABLE_DEBUG_TRIGGER_EXAMPLES then
  append(regular, parsed(
    {
      trig = [=[(^|[^a-zA-Z])trigger]=],
      name = [=[Expands on a new line or after characters other than a-z or A-Z]=],
      dscr = [=[Expands on a new line or after characters other than a-z or A-Z]=],
      trigEngine = "ecma",
      wordTrig = false,
      priority = 2000,
      hidden = true
    },
    [=[${LS_CAPTURE_1}snippet body]=]
  ))
end
if ENABLE_DEBUG_TRIGGER_EXAMPLES then
  append(regular, parsed(
    {
      trig = [=[(^|[\W])trigger]=],
      name = [=[Expands on a new line or after characters other than 0-9, a-z, or A-Z]=],
      dscr = [=[Expands on a new line or after characters other than 0-9, a-z, or A-Z]=],
      trigEngine = "ecma",
      wordTrig = false,
      priority = 2000,
      hidden = true
    },
    [=[${LS_CAPTURE_1}snippet body]=]
  ))
end
if ENABLE_DEBUG_TRIGGER_EXAMPLES then
  append(regular, parsed(
    {
      trig = [=[([\w])trigger]=],
      name = [=[([\w])trigger]=],
      dscr = [=[([\w])trigger]=],
      trigEngine = "ecma",
      wordTrig = false,
      priority = 2000,
      hidden = true
    },
    [=[${LS_CAPTURE_1}snippet body]=]
  ))
end
if ENABLE_DEBUG_TRIGGER_EXAMPLES then
  append(regular, parsed(
    {
      trig = [=[([\w]|[\}\)\]\|])trigger]=],
      name = [=[Expands after 0-9, a-z, A-Z and }, ), ], and |]=],
      dscr = [=[Expands after 0-9, a-z, A-Z and }, ), ], and |]=],
      trigEngine = "ecma",
      wordTrig = false,
      priority = 2000,
      hidden = true
    },
    [=[${LS_CAPTURE_1}snippet body]=]
  ))
end
if ENABLE_DEBUG_TRIGGER_EXAMPLES then
  append(regular, parsed(
    {
      trig = [=[([a-zA-Z]|[\}\)\]\|])trigger]=],
      name = [=[Expands after a-z, A-Z and }, ), ], and |]=],
      dscr = [=[Expands after a-z, A-Z and }, ), ], and |]=],
      trigEngine = "ecma",
      wordTrig = false,
      priority = 2000,
      hidden = true
    },
    [=[${LS_CAPTURE_1}snippet body]=]
  ))
end
append(regular, parsed(
    {
      trig = [=[sympy]=],
      name = [=[sympy block ]=],
      dscr = [=[sympy block ]=],
      priority = 2000
    },
    [=[sympy $1 sympy$0]=]
  ))
append(regular, s(
    {
      trig = [=[sympy(.*)sympy]=],
      name = [=[sympy]=],
      dscr = [=[sympy]=],
      trigEngine = "ecma",
      wordTrig = false,
      priority = 12000
    },
    { f(sympy_to_latex, {}) }
  ))
append(regular, parsed(
    {
      trig = [=[math]=],
      name = [=[mathematicablock]=],
      dscr = [=[mathematicablock]=],
      priority = 3000
    },
    [=[math $1 math$0]=]
  ))
append(regular, s(
    {
      trig = [=[math(.*)math]=],
      name = [=[math]=],
      dscr = [=[math]=],
      trigEngine = "ecma",
      wordTrig = false,
      priority = 12000
    },
    { f(wolfram_to_latex, {}) }
  ))

return regular, autosnippets
