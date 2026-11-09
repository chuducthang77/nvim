return {
  "folke/snacks.nvim",
  priority = 1000,
  lazy = false,
  -- ---@type snacks.Config
  opts = {
    styles = {
      blame_lines = {
        width = 0.6,
        height = 0.6,
        border = "rounded",
        title = " Git Blame ",
        title_pos = "center",
        ft = "git",
      }
    },
    bigfile = {
      enabled = true,
      notify = true,
      size = 100 * 1024,   -- 100 KB
      line_length = 1000,  -- Lines longer than this trigger bigfile mode
      ---@param ctx {buf: number, ft: string}
      setup = function(ctx)
        -- Exclude tex/markdown from bigfile mode
        -- tex: preserves ftplugin keymaps
        -- markdown: legacy syntax misflags underscores in snake_case as broken emphasis
        if ctx.ft == "tex" or ctx.ft == "markdown" then
          vim.bo[ctx.buf].filetype = ctx.ft
          return
        end
        if vim.fn.exists(":NoMatchParen") ~= 0 then
          vim.cmd([[NoMatchParen]])
        end
        Snacks.util.wo(0, { foldmethod = "manual", statuscolumn = "", conceallevel = 0 })
        vim.b.completion = false
        vim.b.minianimate_disable = true
        vim.b.minihipatterns_disable = true
        vim.schedule(function()
          if vim.api.nvim_buf_is_valid(ctx.buf) then
            vim.bo[ctx.buf].syntax = ctx.ft
          end
        end)
      end,
    },
    bufdelete = { enabled = true },
    dashboard = {
      enabled = true,
      preset = require("neotex.plugins.tools.snacks.dashboard").preset,
      sections = require("neotex.plugins.tools.snacks.dashboard").sections,
    },
    git = { enabled = true },
    gitbrowse = { enabled = true },
    indent = {
      enabled = true,
      priority = 1,
      char = "|",
      only_scope = false,
      only_current = false,
      animate = { enabled = false },
      scope = {
        enabled = true, -- enable highlighting the current scope
        priority = 200,
        char = "│",
        underline = false, -- underline the start of the scope
        only_current = false, -- only show scope in the current window
        hl = "GruvboxGray", ---@type string|string[] hl group for scopes
      },
    },
    input = {
      enabled = true,
      backdrop = false,
      position = "float",
      border = "rounded",
      title_pos = "center",
      icon_hl = 'SnacksInputIcon',
      icon_pos = 'left',
      prompt_pos = 'title',
      win = { style = 'input' },
      expand = true,
    },
    lazygit = { enabled = true },
    notifier = {
      enabled = true,
      timeout = 4000,
      width = { min = 40, max = 0.4 },
      height = { min = 1, max = 0.6 },
      margin = { top = 0, right = 1, bottom = 0 },
      padding = true,
      sort = { 'level', 'added' },
      level = vim.log.levels.TRACE,
      -- icons = {
      --     debug = icons.ui.Bug,
      --     error = icons.diagnostics.Error,
      --     info = icons.diagnostics.Information,
      --     trace = icons.ui.Bookmark,
      --     warn = icons.diagnostics.Warning,
      -- },
      style = 'compact',
      top_down = true,
      date_format = '%R',
      more_format = ' ↓ %d lines ',
      refresh = 50,
    },
    notify = { enabled = true },
    profiler = { enabled = false },
    quickfile = { enabled = true },
    rename = { enabled = true },
    scope = {
      enabled = true,
      keys = {
        textobject = {
          ii = {
            min_size = 2,         -- minimum size of the scope
            edge = false,         -- inner scope
            cursor = false,
            treesitter = { blocks = { enabled = false } },
            desc = 'inner scope',
          },
          ai = {
            cursor = false,
            min_size = 2,         -- minimum size of the scope
            treesitter = { blocks = { enabled = false } },
            desc = 'full scope',
          },
        },
        -- jump = {
        --   ['[a'] = {
        --     min_size = 1,         -- allow single line scopes
        --     bottom = false,
        --     cursor = false,
        --     edge = true,
        --     treesitter = { blocks = { enabled = false } },
        --     desc = 'jump to top edge of scope',
        --   },
        --   ['];'] = {
        --     min_size = 1,         -- allow single line scopes
        --     bottom = true,
        --     cursor = false,
        --     edge = true,
        --     treesitter = { blocks = { enabled = false } },
        --     desc = 'jump to bottom edge of scope',
        --   },
        -- },
      },
    },
    scratch = { enabled = false },
    scroll = { enabled = false },
    statuscolumn = {
        enabled = true,
        left = { 'mark', 'sign' },
        right = { 'fold', 'git' },
        folds = {
            open = false,
            git_hl = false,
        },
        git = {
            patterns = { 'GitSign', 'MiniDiffSign' },
        },
        refresh = 50,
    },
    terminal = { enabled = true },
    toggle = { enabled = false },
    win = { enabled = true },
    words = { enabled = false },
    zen = {
        enabled = false,
        toggles = {
            dim = true,
            git_signs = false,
            mini_diff_signs = false,
            -- diagnostics = false,
            -- inlay_hints = false,
        },
        show = {
            statusline = false,
            tabline = false,
        },
        win = { style = 'zen' },
        zoom = {
            toggles = {},
            show = { statusline = true, tabline = true },
            win = {
                backdrop = false,
                width = 0,
            },
        },
    },
  },
  config = function(_, opts)
    -- NEOTEX_TEX_FILETYPE_FIX
    -- This higher-priority rule prevents Snacks.bigfile from claiming
    -- LaTeX files before VimTeX and the TeX ftplugins are initialized.
    vim.filetype.add({
      pattern = {
        [".*%.tex"] = { "tex", { priority = math.huge } },
      },
    })

    local snacks = require("snacks")
    snacks.setup(opts)
    -- Set vim.ui.input to use Snacks.input
    vim.ui.input = snacks.input
  end,
}