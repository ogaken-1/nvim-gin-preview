local preview_diff = {}

preview_diff.winid_autocmds = {}

function preview_diff.dispose(winid)
  local autocmds = preview_diff.winid_autocmds[winid]
  if autocmds == nil then
    return
  end
  for _, auid in ipairs(autocmds) do
    vim.api.nvim_del_autocmd(auid)
  end
  preview_diff.winid_autocmds[winid] = nil
end

local function get_diff_bufnr(status_winid)
  if not vim.api.nvim_win_is_valid(status_winid) then
    return
  end
  local status_bufnr = vim.api.nvim_win_get_buf(status_winid)
  if not vim.fn.bufname(status_bufnr):match 'ginstatus://' then
    vim.print 'Diff preview is only available in status buffer'
    return
  end
  local row, _ = unpack(vim.api.nvim_win_get_cursor(status_winid))
  ---@type string
  local line_text = vim.fn.getbufline(status_bufnr, row)[1]
  local diff_file_relative_path = line_text:sub(4)
  local diff_bufname = ('gindiff://%s;#[%%22%s%%22]'):format(vim.fn['gin#util#worktree'](), diff_file_relative_path)
  local diff_bufnr
  if vim.fn.bufexists(diff_bufname) == 1 then
    diff_bufnr = vim.fn.bufnr(diff_bufname)
  else
    diff_bufnr = vim.fn.bufadd(diff_bufname)
  end
  return diff_bufnr
end

local function redraw_preview_with_cursor(status_winid, preview_winid)
  if vim.api.nvim_win_is_valid(preview_winid) then
    local diff_bufnr = get_diff_bufnr(status_winid)
    if diff_bufnr == nil then
      return
    end
    vim.fn.win_execute(preview_winid, ('buffer %d'):format(diff_bufnr), false)
  end
end

local function preview_window_config(status_winid)
  return {
    focusable = false,
    title = 'diff preview',
    relative = 'win',
    win = status_winid,
    border = 'rounded',
    width = math.floor(vim.fn.winwidth(status_winid) / 2),
    height = math.floor(vim.fn.winheight(status_winid) - 2),
    style = 'minimal',
    row = 0,
    col = math.floor(vim.fn.winwidth(status_winid) / 2),
    zindex = 1,
  }
end

local augroup = vim.api.nvim_create_augroup('gin-status-preview', { clear = true })

---Show preview
---@param status_winid integer
function preview_diff.open(status_winid)
  status_winid = status_winid or vim.api.nvim_get_current_win()
  local diff_bufnr = get_diff_bufnr(status_winid)
  if diff_bufnr == nil then
    return
  end
  if vim.w[status_winid].gin_status_preview_winid ~= nil then
    return
  end
  vim.w[status_winid].gin_status_preview_winid =
    vim.api.nvim_open_win(diff_bufnr, false, preview_window_config(status_winid))
  local status_bufnr = vim.api.nvim_win_get_buf(status_winid)
  local close_auid = vim.api.nvim_create_autocmd({ 'BufWinLeave', 'BufHidden', 'BufUnload' }, {
    buffer = status_bufnr,
    group = augroup,
    desc = 'Close preview window if opened',
    callback = function()
      if not vim.api.nvim_win_is_valid(status_winid) then
        preview_diff.dispose(status_winid)
        return
      end
      preview_diff.close(status_winid)
    end,
  })
  local redraw_auid = vim.api.nvim_create_autocmd('CursorMoved', {
    buffer = status_bufnr,
    group = augroup,
    nested = true,
    callback = function()
      if not vim.api.nvim_win_is_valid(status_winid) then
        preview_diff.dispose(status_winid)
        return
      end
      local preview_winid = vim.w[status_winid].gin_status_preview_winid
      if preview_winid == nil then
        return
      end
      if not vim.api.nvim_win_is_valid(preview_winid) then
        vim.w[status_winid].gin_status_preview_winid = nil
        return
      end
      redraw_preview_with_cursor(status_winid, preview_winid)
    end,
  })
  local resize_auid = vim.api.nvim_create_autocmd('WinResized', {
    group = augroup,
    callback = function()
      preview_diff.resize(status_winid)
    end,
  })
  preview_diff.winid_autocmds[status_winid] = { close_auid, redraw_auid, resize_auid }
end

function preview_diff.close(status_winid)
  local preview_winid = vim.w[status_winid].gin_status_preview_winid
  if preview_winid == nil then
    return
  end
  -- Window will not be closed if `preview_diff.close()` called in asynchronous context
  vim.schedule(function()
    if vim.api.nvim_win_is_valid(preview_winid) then
      vim.api.nvim_win_close(preview_winid, false)
      vim.w[status_winid].gin_status_preview_winid = nil
    end
  end)
end

function preview_diff.resize(status_winid)
  if not vim.api.nvim_win_is_valid(status_winid) then
    preview_diff.dispose(status_winid)
    return
  end
  local preview_winid = vim.w[status_winid].gin_status_preview_winid
  if preview_winid == nil then
    return
  end
  if not vim.api.nvim_win_is_valid(preview_winid) then
    vim.w[status_winid].gin_status_preview_winid = nil
    return
  end
  vim.api.nvim_win_set_config(preview_winid, preview_window_config(status_winid))
end

return preview_diff
