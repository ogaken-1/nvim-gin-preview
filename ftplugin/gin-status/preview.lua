local bufnr = tonumber(vim.fn.expand '<abuf>')
vim.api.nvim_create_autocmd('BufWinEnter', {
  buffer = bufnr,
  group = vim.api.nvim_create_augroup('gin-status-preview', { clear = false }),
  callback = vim.schedule_wrap(function(ctx)
    require('gin.status.preview_diff').open(vim.fn.bufwinid(ctx.buf))
  end),
})
