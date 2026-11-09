-- neotex.util.workspace
-- :Workspace builds a ready-made window layout for writing with two Claude sessions.
--
--   :Workspace        one tab page:  edit | edit | Claude #1 (plugin)
--                                                  Claude #2 (plain terminal)
--   :Workspace small  tab 1: edit | edit      tab 2: Claude #2 | Claude #1 (plugin)
--
-- Claude #1 is the plugin session (:ClaudeCode). Claude #2 is a separate plain `claude`
-- terminal, started without --dangerously-skip-permissions. Start nvim in the project folder.

local M = {}

local CLAUDE_PLAIN = "claude"

local function claude_plugin()
  if vim.fn.exists(":ClaudeCode") == 0 then
    pcall(vim.cmd, "Lazy load claude-code.nvim")
  end
  local ok, err = pcall(vim.cmd, "ClaudeCode")
  if not ok then
    vim.notify("Workspace: could not open Claude plugin: " .. tostring(err), vim.log.levels.WARN)
  end
end

-- Buffer of the plain Claude #2 session, kept so repeated :Workspace reuses it.
local claude2_buf = nil

local function claude2_alive()
  if not (claude2_buf and vim.api.nvim_buf_is_valid(claude2_buf)) then
    return false
  end
  local job = vim.b[claude2_buf].terminal_job_id
  return job ~= nil and vim.fn.jobwait({ job }, 0)[1] == -1 -- -1 = still running
end

local function plain_claude_terminal()
  if claude2_alive() then
    vim.cmd("buffer " .. claude2_buf) -- reattach the existing session
    return
  end
  vim.cmd("terminal " .. CLAUDE_PLAIN)
  claude2_buf = vim.api.nvim_get_current_buf()
end

function M.wide()
  local edit = vim.api.nvim_get_current_win()
  vim.cmd("only")
  vim.cmd("vsplit") -- second editing column
  claude_plugin() -- right column, cursor lands in it
  vim.cmd("belowright split") -- Claude #2 under Claude #1
  plain_claude_terminal()
  if vim.api.nvim_win_is_valid(edit) then
    vim.api.nvim_set_current_win(edit)
  end
end

function M.small()
  local edit = vim.api.nvim_get_current_win()
  vim.cmd("only")
  vim.cmd("vsplit") -- tab 1: two editing columns
  vim.cmd("tabnew") -- tab 2: both Claudes
  claude_plugin() -- right column
  vim.cmd("wincmd h") -- the empty left window
  plain_claude_terminal()
  vim.cmd("tabfirst")
  if vim.api.nvim_win_is_valid(edit) then
    vim.api.nvim_set_current_win(edit)
  end
end

function M.setup()
  vim.api.nvim_create_user_command("Workspace", function(opts)
    if opts.args == "small" then
      M.small()
    else
      M.wide()
    end
  end, {
    nargs = "?",
    complete = function() return { "small" } end,
    desc = "Build the edit + Claude window layout",
  })
end

return M
