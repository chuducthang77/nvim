-- neotex.util.cheatsheet
-- Floating one-page cheatsheet of the most frequently used shortcuts.
-- Open with <leader>?; close with q, ? or <Esc>.

local M = {}

local lines = {
  "  NEOVIM CHEATSHEET                                  q / <Esc> to close",
  "",
  "  NOTATION   <Space> = leader   <C-x> = Ctrl+x   <A-x> = Alt/Option+x",
  "             <leader>ff = press Space, then f, then f (one after another)",
  "",
  "  VIM BASICS",
  "    i / Esc        insert mode / back to normal       u / <C-r>   undo / redo",
  "    :w  :q  :wq    save / quit / both                 :q!         quit, discard",
  "    h j k l        left down up right                 w b         word fwd / back",
  "    0  $  gg  G    line start/end, file top/bottom    /text  n    search, next",
  "    dd  yy  p      delete line, copy line, paste      .           repeat last edit",
  "    ciw  dw  cie   change word, delete word, change LaTeX environment",
  "",
  "  MOVING & SEARCHING IN A FILE (j/k scroll this sheet if it is cut off)",
  "    w b e          word fwd / back / end              H  L        line start / end",
  "    f{  ;  ,       jump to next {, repeat, reverse    t,  dt}     till char; delete till }",
  "    %              matching { } ( ) $ \\begin/\\end    J  K        down / up (wrapped lines)",
  "    { }            prev / next paragraph              <C-d> <C-u> half page, centred",
  "    /text  n  N    search, next, prev                 *  #        word under cursor fwd / back",
  "    :%s/a/b/gc     replace in file (asks each)        zz          centre current line",
  "    <C-o> / <C-i>  jump back / forward in history     g;          last edit position",
  "    ma  'a         set mark a, jump back to it        ''          previous position",
  "",
  "  FIND                                   FILES & WINDOWS",
  "    <C-p>        file by name              <Space>e      file explorer",
  "    <Space>ff    text in all files         <C-h/j/k/l>   move between windows",
  "    <Space>fw    word under cursor         <Tab> <S-Tab> next / prev buffer",
  "    <Space>fb    open buffers              <Space>c      vertical split",
  "    <Space>fc    BibTeX citations          <Space>d      save + close buffer",
  "    <Space>fl    resume last search        <Space>w      save all",
  "    <Space>fk    list ALL keymaps          <Space>q      save all + quit",
  "",
  "  SPLITS / TAB PAGES / SESSIONS (like tmux panes / windows / sessions)",
  "    <Space>c     vertical split (side)     <Space>C         horizontal split (stacked)",
  "    <Space>] [   wider / narrower split    <Space>+ -       taller / shorter split",
  "    <Space>=     equalize all splits       <C-\\><C-n>        leave terminal mode",
  "    <C-h/j/k/l>  move between splits       <C-w>=  <C-w>o   equalize / keep only this",
  "    <Space>N     new tab page              <Space>1..9      go to tab page N",
  "    gt / gT      next / prev tab page      <Space>X         close tab page",
  "    <Space>Ss    save session              <Space>Sl        load session",
  "    :Workspace   edit|edit|Claude#1/#2     :Workspace small  tab1 edit, tab2 Claudes",
  "    <C-w>T       move split to new tab     <Space>o or <C-t> floating terminal",
  "",
  "  LATEX (only in .tex files)             LSP / DIAGNOSTICS",
  "    <Space>lc    compile                   <Space>id     go to definition",
  "    <Space>lv    view PDF                  <Space>ir     find references",
  "    <Space>le    show errors               <Space>iR     rename symbol",
  "    <Space>li    table of contents         <Space>ih     hover docs",
  "    <Space>lw    word count                <Space>ib     errors in this file",
  "    <Space>lk    clean aux files           <Space>in/ip  next / prev problem",
  "",
  "  GIT                                    EDITING EXTRAS",
  "    <Space>gg    LazyGit                   <A-j> / <A-k>  move line down / up",
  "    <Space>gj/gh next / prev hunk          <C-;>          toggle comment",
  "    <Space>gp    preview hunk              <C-t>          toggle terminal",
  "    <Space>gs    git status                <Space>u       undo history",
  "",
  "  HUNK = one contiguous block of changed lines compared to the last commit.",
  "",
  "  AI: <Space>a... (Claude Code, sessions)   <C-CR> AI tool picker",
  "  Lost? Press <Space> and wait: a popup lists the keys available.",
}

function M.open()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].bufhidden = "wipe"

  local width = 0
  for _, line in ipairs(lines) do
    width = math.max(width, vim.fn.strdisplaywidth(line))
  end
  width = math.min(width + 2, vim.o.columns - 4)
  local height = math.min(#lines, vim.o.lines - 4)

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2) - 1,
    col = math.floor((vim.o.columns - width) / 2),
    style = "minimal",
    border = "rounded",
    title = " Cheatsheet ",
    title_pos = "center",
  })
  vim.wo[win].wrap = false

  for _, key in ipairs({ "q", "<Esc>", "?" }) do
    vim.keymap.set("n", key, function()
      pcall(vim.api.nvim_win_close, win, true)
    end, { buffer = buf, nowait = true, silent = true, desc = "Close cheatsheet" })
  end
end

return M
