-- OAuth management module
-- Handles token validation and refresh
-- Password-auth accounts (e.g., Protonmail Bridge) are detected and skip OAuth

local M = {}

-- Dependencies
local logger = require('neotex.plugins.tools.himalaya.core.logger')
local state = require('neotex.plugins.tools.himalaya.core.state')
local config = require('neotex.plugins.tools.himalaya.core.config')

-- Constants
local REFRESH_COOLDOWN = 300 -- 5 minutes
local REFRESH_RETRY_COOLDOWN = 60 -- 1 minute

-- Cache for account auth types (avoid re-reading config)
local auth_type_cache = {}

-- macOS Keychain support (managed by neotex-himalaya-keychain-fix.py)
local function trim(value)
  if type(value) ~= 'string' then
    return nil
  end
  value = vim.trim(value)
  return value ~= '' and value or nil
end

local function append_unique(values, value)
  if not value or value == '' then
    return
  end
  for _, existing in ipairs(values) do
    if existing == value then
      return
    end
  end
  table.insert(values, value)
end

local function escape_pattern(value)
  return (value:gsub('([^%w])', '%%%1'))
end

-- Read the actual *.keyring values from the account block when possible.
local function configured_key_names(account)
  local result = { access = {}, refresh = {}, client_secret = {} }
  local path = vim.fn.expand('~/.config/himalaya/config.toml')
  if vim.fn.filereadable(path) ~= 1 then
    return result
  end

  local escaped = escape_pattern(account)
  local headers = {
    '^%s*%[accounts%.' .. escaped .. '%]%s*$',
    '^%s*%[accounts%."' .. escaped .. '"%]%s*$',
    "^%s*%[accounts%.'" .. escaped .. "'%]%s*$",
  }
  local in_account = false

  for _, raw_line in ipairs(vim.fn.readfile(path)) do
    local line = raw_line:gsub('%s+#.*$', '')
    if line:match('^%s*%[') then
      if in_account then
        break
      end
      for _, header in ipairs(headers) do
        if line:match(header) then
          in_account = true
          break
        end
      end
    elseif in_account then
      append_unique(
        result.access,
        line:match("auth%.access%-token%.keyring%s*=%s*['\"]([^'\"]+)['\"]")
      )
      append_unique(
        result.refresh,
        line:match("auth%.refresh%-token%.keyring%s*=%s*['\"]([^'\"]+)['\"]")
      )
      append_unique(
        result.client_secret,
        line:match("auth%.client%-secret%.keyring%s*=%s*['\"]([^'\"]+)['\"]")
      )
    end
  end
  return result
end

local function add_fallbacks(values, account, kind)
  -- Himalaya's common shared name, plus NeoTeX's split SMTP/IMAP names.
  append_unique(values, account .. '-oauth2-' .. kind)
  append_unique(values, account .. '-smtp-oauth2-' .. kind)
  append_unique(values, account .. '-imap-oauth2-' .. kind)

  -- gmail-imap should normally map to gmail-imap-oauth2-*, not the previous
  -- accidental gmail-imap-imap-oauth2-* derivation. Keep both for migration.
  local base = account:gsub('%-imap$', '')
  if base ~= account then
    append_unique(values, base .. '-oauth2-' .. kind)
    append_unique(values, base .. '-imap-oauth2-' .. kind)
  end
end

local function key_names(account)
  local result = configured_key_names(account)
  add_fallbacks(result.access, account, 'access-token')
  add_fallbacks(result.refresh, account, 'refresh-token')
  add_fallbacks(result.client_secret, account, 'client-secret')
  return result
end

local function keyring_command(username)
  if (vim.fn.has('macunix') == 1 or vim.fn.has('mac') == 1)
      and vim.fn.executable('security') == 1 then
    -- No -w: check entry existence without reading or printing the secret.
    return {
      'security', 'find-generic-password',
      '-s', 'himalaya-cli',
      '-a', username,
    }, true
  end

  if vim.fn.executable('secret-tool') == 1 then
    return {
      'secret-tool', 'lookup',
      'service', 'himalaya-cli',
      'username', username,
    }, false
  end
  return nil, false
end

local function keyring_entry_exists(username)
  local command, existence_only = keyring_command(username)
  if not command then
    return false
  end
  local result = vim.system(command, { text = true }):wait()
  if not result or result.code ~= 0 then
    return false
  end
  return existence_only or trim(result.stdout) ~= nil
end

local function find_key(usernames)
  for _, username in ipairs(usernames) do
    if keyring_entry_exists(username) then
      return true, username
    end
  end
  return false, nil
end

-- Load OAuth variables from the process environment first, and retain the
-- original NixOS/systemd import when systemctl exists.
function M.load_environment()
  local env_vars = {}
  local oauth_vars = {
    'GMAIL_CLIENT_ID',
    'GMAIL_CLIENT_SECRET',
    'SASL_PATH',
    'GOOGLE_APPLICATION_CREDENTIALS',
  }

  for _, var in ipairs(oauth_vars) do
    local value = vim.env[var]
    if value and value ~= '' then
      env_vars[var] = value
    end
  end

  if vim.fn.executable('systemctl') == 1 then
    local result = vim.system(
      { 'systemctl', '--user', 'show-environment' },
      { text = true }
    ):wait()
    if result and result.code == 0 then
      for line in (result.stdout or ''):gmatch('[^\n]+') do
        local key, value = line:match('^([^=]+)=(.*)$')
        if key and value and value ~= '' and not env_vars[key] then
          env_vars[key] = value
        end
      end
    end
  end

  for _, var in ipairs(oauth_vars) do
    if env_vars[var] then
      vim.fn.setenv(var, env_vars[var])
    end
  end
  return env_vars
end

-- Check if an account uses OAuth authentication (vs password-based)
-- Reads the himalaya config.toml to detect auth.type for the account
-- Returns true for OAuth accounts (gmail), false for password accounts (logos)
function M.is_oauth_account(account)
  account = account or 'gmail'

  -- Check cache first
  if auth_type_cache[account] ~= nil then
    return auth_type_cache[account]
  end

  -- Read himalaya config to determine auth type
  local himalaya_config_path = vim.fn.expand('~/.config/himalaya/config.toml')
  if vim.fn.filereadable(himalaya_config_path) ~= 1 then
    -- Default to OAuth if we can't read config
    logger.debug('Cannot read himalaya config, assuming OAuth for ' .. account)
    auth_type_cache[account] = true
    return true
  end

  local content = vim.fn.readfile(himalaya_config_path)
  local in_account_section = false
  local found_auth_type = nil

  for _, line in ipairs(content) do
    -- Check if we're entering the correct account section
    if line:match("^%[accounts%." .. account .. "%]") then
      in_account_section = true
    elseif line:match("^%[accounts%.") then
      -- We've entered a different account section
      if in_account_section then
        break -- Stop if we were in our section and moved to another
      end
    elseif line:match("^%[") and not line:match("^%[accounts%.") then
      -- Non-account section - continue if not in our section, break if we were
      if in_account_section then
        break
      end
    elseif in_account_section then
      -- Look for auth.type field (handles nested TOML)
      -- Match patterns like: message.send.backend.auth.type = "password"
      local auth_type = line:match('auth%.type%s*=%s*["\']([^"\']+)["\']')
      if auth_type then
        found_auth_type = auth_type
        -- Don't break here - there might be multiple auth.type entries
        -- (e.g., IMAP and SMTP), keep the last one which is typically SMTP
      end
    end
  end

  -- Determine if this is an OAuth account
  local is_oauth
  if found_auth_type == nil then
    -- No auth.type found, assume OAuth for backward compatibility
    is_oauth = true
    logger.debug('No auth.type found for ' .. account .. ', assuming OAuth')
  elseif found_auth_type == 'oauth2' then
    is_oauth = true
  elseif found_auth_type == 'password' then
    is_oauth = false
    logger.debug('Account ' .. account .. ' uses password auth (skipping OAuth)')
  else
    -- Unknown auth type, assume OAuth
    is_oauth = true
    logger.debug('Unknown auth.type ' .. found_auth_type .. ' for ' .. account .. ', assuming OAuth')
  end

  auth_type_cache[account] = is_oauth
  return is_oauth
end

-- Clear auth type cache (useful for testing or config changes)
function M.clear_auth_type_cache()
  auth_type_cache = {}
end

-- Check if OAuth token exists
function M.has_token(account)
  account = account or 'gmail'
  local exists = find_key(key_names(account).access)
  return exists
end

-- Async-compatible wrapper. The Keychain lookup is a short local operation;
-- scheduling the callback avoids invoking callers re-entrantly.
function M.has_token_async(account, callback)
  vim.schedule(function()
    if callback then
      callback(M.has_token(account))
    end
  end)
end

-- Check if OAuth token is valid (not expired)
function M.is_valid(account)
  account = account or 'gmail'

  -- Password-auth accounts don't need OAuth tokens
  if not M.is_oauth_account(account) then
    return true
  end

  -- If we recently refreshed, assume it's valid
  local last_refresh = state.get("oauth.last_refresh", 0)
  if os.time() - last_refresh < REFRESH_COOLDOWN then
    return true
  end

  -- Check if token exists
  if not M.has_token(account) then
    return false
  end

  -- We can't easily check expiration without parsing the token
  -- So we'll rely on mbsync failing and triggering a refresh
  return true
end

-- Async version of is_valid to avoid blocking
function M.is_valid_async(account, callback)
  account = account or 'gmail'

  -- Password-auth accounts don't need OAuth tokens
  if not M.is_oauth_account(account) then
    if callback then
      callback(true)
    end
    return
  end

  -- If we recently refreshed, assume it's valid
  local last_refresh = state.get("oauth.last_refresh", 0)
  if os.time() - last_refresh < REFRESH_COOLDOWN then
    if callback then
      callback(true)
    end
    return
  end

  -- Check if token exists asynchronously
  M.has_token_async(account, function(has_token)
    if callback then
      callback(has_token)
    end
  end)
end

-- Refresh OAuth token
function M.refresh(account, callback)
  account = account or 'gmail'
  
  -- Check if refresh is already in progress
  if state.get("oauth.refresh_in_progress", false) then
    logger.info('OAuth refresh already in progress')
    if callback then
      callback(false, "refresh in progress")
    end
    return
  end
  
  -- Check cooldown only if we've tried recently and failed
  local last_refresh = state.get("oauth.last_refresh", 0)
  local last_refresh_failed = state.get("oauth.last_refresh_failed", false)
  if last_refresh_failed and os.time() - last_refresh < REFRESH_RETRY_COOLDOWN then
    logger.info('OAuth refresh on cooldown')
    if callback then
      callback(false, "cooldown")
    end
    return
  end
  
  state.set("oauth.refresh_in_progress", true)
  logger.debug('Refreshing OAuth token...')
  
  -- Load environment
  M.load_environment()
  
  -- Try to find refresh script
  local refresh_script = nil
  local possible_paths = {}
  
  -- For IMAP accounts, prefer our direct himalaya refresh script
  if account and account:match('-imap$') then
    -- Get the himalaya plugin directory path
    local current_file = debug.getinfo(1).source:sub(2)  -- Remove the @ prefix
    local sync_dir = vim.fn.fnamemodify(current_file, ':h')  -- sync directory
    local himalaya_dir = vim.fn.fnamemodify(sync_dir, ':h')  -- himalaya directory
    
    -- Try direct himalaya refresh first
    local direct_script_path = himalaya_dir .. '/scripts/refresh-himalaya-oauth2-direct'
    logger.debug('Looking for direct himalaya refresh script at: ' .. direct_script_path)
    table.insert(possible_paths, direct_script_path)
    
    -- Then fallback to wrapper script
    local script_path = himalaya_dir .. '/scripts/refresh-himalaya-oauth2'
    logger.debug('Looking for wrapper refresh script at: ' .. script_path)
    table.insert(possible_paths, script_path)
  end
  
  -- Get the himalaya scripts directory
  local current_file = debug.getinfo(1).source:sub(2)
  local sync_dir = vim.fn.fnamemodify(current_file, ':h')
  local himalaya_dir = vim.fn.fnamemodify(sync_dir, ':h')
  local scripts_dir = himalaya_dir .. '/scripts'
  
  -- Add standard paths
  local standard_paths = {
    scripts_dir .. '/refresh-gmail-oauth2',  -- Check himalaya scripts first
    'refresh-gmail-oauth2',  -- Try PATH
    '/home/benjamin/.nix-profile/bin/refresh-gmail-oauth2',
    vim.fn.expand('~/.local/bin/refresh-gmail-oauth2'),
    vim.fn.expand('~/.local/bin/refresh-oauth'),
    '/usr/local/bin/oauth2-refresh',
    '/usr/local/bin/refresh-gmail-oauth2'
  }
  
  for _, path in ipairs(standard_paths) do
    table.insert(possible_paths, path)
  end
  
  for _, path in ipairs(possible_paths) do
    -- Check if it's a command in PATH (no slashes)
    if not path:match('/') then
      if vim.fn.executable(path) == 1 then
        refresh_script = path
        break
      end
    else
      -- It's a full path, check if file exists
      if vim.fn.filereadable(path) == 1 then
        refresh_script = path
        logger.debug('Found refresh script at: ' .. path)
        break
      elseif vim.fn.executable(path) == 1 then
        -- Sometimes filereadable fails but executable works
        refresh_script = path
        logger.debug('Found executable refresh script at: ' .. path)
        break
      end
    end
  end
  
  if not refresh_script then
    state.set("oauth.refresh_in_progress", false)
    logger.error('OAuth refresh script not found')
    logger.info('Run: himalaya account configure ' .. account)
    if callback then
      callback(false, "no refresh script")
    end
    return
  end
  
  -- Build refresh command
  local cmd = {refresh_script}
  
  -- If using our wrapper script, pass the account name
  if refresh_script:match('refresh-himalaya-oauth2') and account then
    table.insert(cmd, account)
    logger.debug('Using wrapper script with account: ' .. account)
  end
  
  logger.debug('Running OAuth refresh command: ' .. table.concat(cmd, ' '))
  
  -- Run refresh script
  vim.fn.jobstart(cmd, {
    detach = false,
    on_exit = function(_, code)
      state.set("oauth.refresh_in_progress", false)
      
      if code == 0 then
        state.set("oauth.last_refresh", os.time())
        state.set("oauth.last_refresh_failed", false)
        logger.debug('OAuth token refreshed successfully for ' .. account)
        
        -- Debug notification
        local notify = require('neotex.util.notifications')
        if (notify.config.debug_mode or notify.config.modules.himalaya.debug_mode) then
          notify.himalaya('OAuth token refreshed successfully for ' .. account, notify.categories.BACKGROUND)
          
          -- Verify token exists after refresh
          vim.defer_fn(function()
            if M.has_token(account) then
              notify.himalaya('Token verified after refresh for ' .. account, notify.categories.BACKGROUND)
            else
              notify.himalaya('WARNING: Token still missing after refresh for ' .. account, notify.categories.BACKGROUND)
            end
          end, 500)
        end
        
        if callback then
          callback(true)
        end
      else
        state.set("oauth.last_refresh", os.time())
        state.set("oauth.last_refresh_failed", true)
        logger.error('OAuth refresh failed (exit code: ' .. code .. ')')
        logger.info('You may need to reconfigure: himalaya account configure ' .. account)
        if callback then
          callback(false, "exit code " .. code)
        end
      end
    end,
    on_stderr = function(_, data)
      if data and #data > 0 then
        for _, line in ipairs(data) do
          if line ~= '' and not line:match('Missing OAuth2 credentials') then
            logger.debug('OAuth: ' .. line)
          end
        end
      end
    end
  })
end

-- Refresh and retry a function
function M.refresh_and_retry(fn, account)
  M.refresh(account, function(success)
    if success then
      -- Give it a moment for the token to propagate
      vim.defer_fn(function()
        fn()
      end, 1000)
    else
      logger.error('Failed to refresh OAuth token')
    end
  end)
end

-- Get detailed token information
function M.get_token_info(account)
  account = account or 'gmail'
  local names = key_names(account)
  local has_access, access_key = find_key(names.access)
  local has_refresh, refresh_key = find_key(names.refresh)
  local has_client_secret, client_secret_key = find_key(names.client_secret)

  return {
    has_access_token = has_access,
    access_token_preview = nil,
    access_token_key = access_key,
    has_refresh_token = has_refresh,
    refresh_token_key = refresh_key,
    has_client_secret = has_client_secret,
    client_secret_key = client_secret_key,
  }
end

-- Get OAuth status information
function M.get_status(account)
  account = account or 'gmail'
  
  local status = {
    has_token = M.has_token(account),
    last_refresh = state.get("oauth.last_refresh", 0),
    refresh_in_progress = state.get("oauth.refresh_in_progress", false),
    environment_loaded = false,
    token_info = M.get_token_info(account)
  }
  
  -- Check environment
  local env = M.load_environment()
  status.environment_loaded = env.GMAIL_CLIENT_ID ~= nil
    or status.has_token
    or status.token_info.has_client_secret
  
  return status
end

-- Ensure OAuth token exists, refreshing if necessary
function M.ensure_token(account, callback)
  account = account or 'gmail'

  -- Password-auth accounts don't need OAuth tokens
  if not M.is_oauth_account(account) then
    logger.debug('Account ' .. account .. ' uses password auth, no OAuth token needed')
    if callback then
      callback(true)
    end
    return
  end

  -- First check if token exists
  if M.has_token(account) then
    logger.debug('OAuth token found')
    if callback then
      callback(true)
    end
    return
  end

  -- No token found, try to refresh
  logger.info('No OAuth token found, attempting automatic refresh...')
  M.refresh(account, function(success, error)
    if success then
      -- Double check that token now exists
      if M.has_token(account) then
        logger.info('OAuth token successfully obtained')
        if callback then
          callback(true)
        end
      else
        logger.error('OAuth refresh succeeded but token still not found')
        if callback then
          callback(false, "token not found after refresh")
        end
      end
    else
      -- Refresh failed, but let's check one more time in case
      -- the token was created by another process
      vim.defer_fn(function()
        if M.has_token(account) then
          logger.info('OAuth token found after retry')
          if callback then
            callback(true)
          end
        else
          logger.debug('OAuth token still not found after refresh attempt')
          if callback then
            callback(false, error or "no token")
          end
        end
      end, 1000)
    end
  end)
end

-- Initialize OAuth module
function M.setup()
  -- Load environment on startup
  M.load_environment()
end

return M