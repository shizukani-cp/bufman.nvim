-- lua/bufman/init.lua

local M = {}

-- Helper to create the floating window for confirmation
local function open_delete_confirmation(deleted_buf_nrs, original_bufnr)
    -- Get buffer names for the message
    local deleted_buf_names = {}
    for _, bufnr in ipairs(deleted_buf_nrs) do
        local buf_info = vim.fn.getbufinfo(bufnr)[1]
        if buf_info then
            local name = buf_info.name or '[No Name]'
            name = vim.fn.fnamemodify(name, ':t')
            if name == '' then
                name = '[No Name]'
            end
            table.insert(deleted_buf_names, name)
        end
    end

    -- Create a new buffer for the confirmation window
    local confirm_buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_option(confirm_buf, 'bufhidden', 'wipe')
    vim.api.nvim_buf_set_option(confirm_buf, 'filetype', 'bufman-confirm')
    vim.api.nvim_buf_set_option(confirm_buf, 'swapfile', false)

    -- Prepare window content with a frame
    local content = {}
    for _, name in ipairs(deleted_buf_names) do
        table.insert(content, 'DELETE ' .. name)
    end
    table.insert(content, '')
    table.insert(content, '[Y]es / [N]o')

    local max_width = 0
    for _, line in ipairs(content) do
        if vim.fn.strwidth(line) > max_width then
            max_width = vim.fn.strwidth(line)
        end
    end
    max_width = max_width + 4 -- for padding

    local lines = { '┌' .. string.rep('─', max_width - 2) .. '┐' }
    for _, line in ipairs(content) do
        local padding = max_width - 2 - vim.fn.strwidth(line)
        local left_padding = math.floor(padding / 2)
        local right_padding = padding - left_padding
        table.insert(lines, '│' .. string.rep(' ', left_padding) .. line .. string.rep(' ', right_padding) .. '│')
    end
    table.insert(lines, '└' .. string.rep('─', max_width - 2) .. '┘')

    vim.api.nvim_buf_set_lines(confirm_buf, 0, -1, false, lines)
    vim.api.nvim_buf_set_option(confirm_buf, 'modifiable', false)

    -- Calculate window dimensions and position
    local height = #lines
    local width = max_width
    local win_height = vim.api.nvim_get_option('lines')
    local win_width = vim.api.nvim_get_option('columns')
    local row = math.floor((win_height - height) / 2)
    local col = math.floor((win_width - width) / 2)

    -- Create floating window
    local confirm_win = vim.api.nvim_open_win(confirm_buf, true, {
        relative = 'editor',
        width = width,
        height = height,
        row = row,
        col = col,
        style = 'minimal',
        border = 'none', -- The border is drawn inside the buffer
    })

    -- Function to update the original bufman buffer list
    local function update_original_bufman()
        -- We need to find the bufman buffer again if the user switched focus
        for _, win in ipairs(vim.api.nvim_list_wins()) do
            local buf = vim.api.nvim_win_get_buf(win)
            if buf == original_bufnr then
                M.update_buffer_list(buf)
                break
            end
        end
    end

    -- Keymaps for the confirmation window
    local function close_and_cleanup()
        if vim.api.nvim_win_is_valid(confirm_win) then
            vim.api.nvim_win_close(confirm_win, true)
        end
    end

    local yes_callback = function()
        close_and_cleanup()
        local cmd = 'bdelete'
        for _, bufnr in ipairs(deleted_buf_nrs) do
            cmd = cmd .. ' ' .. bufnr
        end
        vim.cmd(cmd)
        update_original_bufman()
    end

    local no_callback = function()
        close_and_cleanup()
        update_original_bufman() -- Revert changes by reloading the buffer list
    end

    vim.api.nvim_buf_set_keymap(confirm_buf, 'n', 'y', '', { noremap = true, silent = true, callback = yes_callback })
    vim.api.nvim_buf_set_keymap(confirm_buf, 'n', 'Y', '', { noremap = true, silent = true, callback = yes_callback })
    vim.api.nvim_buf_set_keymap(confirm_buf, 'n', 'n', '', { noremap = true, silent = true, callback = no_callback })
    vim.api.nvim_buf_set_keymap(confirm_buf, 'n', 'N', '', { noremap = true, silent = true, callback = no_callback })
    vim.api.nvim_buf_set_keymap(confirm_buf, 'n', '<Esc>', '', { noremap = true, silent = true, callback = no_callback })
    vim.api.nvim_buf_set_keymap(confirm_buf, 'n', 'q', '', { noremap = true, silent = true, callback = no_callback })
end

-- バッファ一覧を更新するヘルパー関数
function M.update_buffer_list(buf)
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
        -- 表示フォーマットを「番号 名前」に変更
        table.insert(lines, string.format('%d %s', bufnr, name))
        table.insert(current_buf_nrs, bufnr)
        ::continue::
    end

    -- バッファに書き込む
    vim.api.nvim_buf_set_option(buf, 'modifiable', true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.api.nvim_buf_set_option(buf, 'modifiable', true) -- 保存後も編集可能にしておく
    vim.api.nvim_buf_set_option(buf, 'modified', false)  -- バッファ更新後にmodifiedフラグをリセット

    -- 現在のバッファ番号リストを保存
    vim.b[buf].bufman_buffers = current_buf_nrs
end

function M.select_buffer()
    local current_buf = vim.api.nvim_get_current_buf()
    local line = vim.api.nvim_get_current_line()
    -- パースする正規表現を更新
    local bufnr = tonumber(string.match(line, '^(%d+)%s'))
    if bufnr then
        -- bufmanバッファの変更を破棄するため、modifiedフラグを強制的に下ろす
        vim.api.nvim_buf_set_option(current_buf, 'modified', false)
        vim.api.nvim_set_current_buf(bufnr)
    end
end

local function setup_keymaps(buf)
    vim.api.nvim_buf_set_keymap(buf, 'n', '<CR>', '<CMD>lua require("bufman").select_buffer()<CR>',
        { noremap = true, silent = true })
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
                -- パースする正規表現を更新
                local bufnr = tonumber(string.match(line, '^(%d+)%s'))
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

            -- 削除対象がある場合は確認ウィンドウを開く
            if #deleted_buf_nrs > 0 then
                vim.schedule(function()
                    open_delete_confirmation(deleted_buf_nrs, args.buf)
                end)
            else
                -- 変更がない場合もmodifiedフラグをリセットするために更新
                M.update_buffer_list(args.buf)
            end

            -- BufWriteCmdでは実際の書き込みはせず、modifiedフラグを下ろすだけ
            -- これにより、`:w`が完了したように見せかける
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
            M.update_buffer_list(buf) -- 表示を更新
            return
        end
    end

    -- 新しいバッファを作成
    local buf = vim.api.nvim_create_buf(false, false)
    vim.api.nvim_buf_set_name(buf, 'bufman')
    vim.api.nvim_set_option_value('buftype', 'acwrite', { buf = buf })
    vim.api.nvim_set_option_value('bufhidden', 'wipe', { buf = buf })
    vim.api.nvim_set_option_value('filetype', 'bufman', { buf = buf })
    vim.api.nvim_set_option_value('swapfile', false, { buf = buf })

    -- 現在のウィンドウを新しいバッファで開く
    vim.api.nvim_set_current_buf(buf)

    -- conceal（隠蔽）オプションを設定
    local win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_option(win, 'conceallevel', 2)
    vim.api.nvim_win_set_option(win, 'concealcursor', 'n')

    -- バッファ一覧を表示
    M.update_buffer_list(buf)

    -- autocmdとキーマッピングを設定
    setup_autocmds(buf)
    setup_keymaps(buf)
end

function M.setup(opts)
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
end

return M
