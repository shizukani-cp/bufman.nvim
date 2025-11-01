-- plugin/bufman.lua

-- Do not load if already loaded
if vim.g.loaded_bufman then
  return
end
vim.g.loaded_bufman = 1

vim.api.nvim_create_user_command(
  'BufMan',
  function()
    require('bufman').open()
  end,
  { nargs = 0 }
)
