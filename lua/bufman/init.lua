-- lua/bufman/init.lua

local M = {}

-- バッファ一覧を更新するヘルパー関数
local function update_buffer_list(buf)
  -- バッファ一覧を取得
  local buffers = vim.fn.getbufinfo({ buflisted = 1 })
  local lines = {}
  local current_buf_nrs = {}

  for _, b in ipairs(buffers) do
    local bufnr = b.bufnr
    -- bufman自身のバッファはリストに表示しない
    if bufnr == buf then
      goto continue
    end
    local name = b.name or '[No Name]'
    name = vim.fn.fnamemodify(name, ':t')
    if name == '' then
      name = '[No Name]'
    end
    table.insert(lines, string.format('%d: %s', bufnr, name))
    table.insert(current_buf_nrs, bufnr)
    ::continue::
  end

  -- バッファに書き込む
  vim.api.nvim_buf_set_option(buf, 'modifiable', true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(buf, 'modifiable', true) -- 保存後も編集可能にしておく

  -- 現在のバッファ番号リストを保存
  vim.b[buf].bufman_buffers = current_buf_nrs
end

function M.select_buffer()
  local line = vim.api.nvim_get_current_line()
  local bufnr = tonumber(string.match(line, '^(%d+):'))
  if bufnr then
    vim.api.nvim_set_current_buf(bufnr)
  end
end

local function setup_keymaps(buf)
  vim.api.nvim_buf_set_keymap(buf, 'n', '<CR>', '<CMD>lua require("bufman").select_buffer()<CR>', { noremap = true, silent = true })
  vim.api.nvim_buf_set_keymap(buf, 'n', 'q', '<CMD>q<CR>', { noremap = true, silent = true })
end

local function setup_autocmds(buf)
  vim.api.nvim_create_autocmd('BufWriteCmd', {
    buffer = buf,
    callback = function(args)
      -- 現在のバッファ内容から新しいバッファリストを作成
      local new_lines = vim.api.nvim_buf_get_lines(args.buf, 0, -1, false)
      local new_buf_nrs = {}
      for _, line in ipairs(new_lines) do
        local bufnr = tonumber(string.match(line, '^(%d+):'))
        if bufnr then
          table.insert(new_buf_nrs, bufnr)
        end
      end

      -- 保存前のバッファリストと比較して削除されたものを特定
      local old_buf_nrs = vim.b[args.buf].bufman_buffers or {}
      local deleted_buf_nrs = {}
      local new_buf_nrs_set = {}
      for _, bufnr in ipairs(new_buf_nrs) do
        new_buf_nrs_set[bufnr] = true
      end
      for _, bufnr in ipairs(old_buf_nrs) do
        if not new_buf_nrs_set[bufnr] then
          table.insert(deleted_buf_nrs, bufnr)
        end
      end

      -- 該当バッファを削除
      if #deleted_buf_nrs > 0 then
        local cmd = 'bdelete'
        for _, bufnr in ipairs(deleted_buf_nrs) do
          cmd = cmd .. ' ' .. bufnr
        end
        vim.cmd(cmd)
      end

      -- bufmanウィンドウを更新
      update_buffer_list(args.buf)

      -- 'modified'フラグをfalseに設定して保存済み状態にする
      vim.api.nvim_buf_set_option(args.buf, 'modified', false)
    end,
  })
end

function M.open()
  -- 既存のbufmanウィンドウがあれば、それに切り替える
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local buf = vim.api.nvim_win_get_buf(win)
    if vim.bo[buf].filetype == 'bufman' then
      vim.api.nvim_set_current_win(win)
      update_buffer_list(buf) -- 表示を更新
      return
    end
  end

  -- 新しいバッファを作成
  local buf = vim.api.nvim_create_buf(false, false)
  vim.api.nvim_set_option_value('bufhidden', 'wipe', { buf = buf })
  vim.api.nvim_set_option_value('filetype', 'bufman', { buf = buf })
  vim.api.nvim_set_option_value('swapfile', false, { buf = buf })

  -- 現在のウィンドウを新しいバッファで開く
  vim.api.nvim_set_current_buf(buf)
  -- ダミーのバッファ名を設定
  vim.cmd('file bufman://buffers')

  -- バッファ一覧を表示
  update_buffer_list(buf)

  -- autocmdとキーマッピングを設定
  setup_autocmds(buf)
  setup_keymaps(buf)
end

return M
