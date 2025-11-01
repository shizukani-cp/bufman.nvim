-- tests/minimal_init.lua

-- bufman.nvimプラグインのパス（プロジェクトのルート）を取得
local plugin_path = vim.fn.getcwd()

-- Neovimのruntimepathにプラグインのパスを追加
vim.opt.runtimepath:prepend(plugin_path)

-- 起動時にメッセージを表示
print('テスト用の最小設定で起動しました。:BufMan コマンドが使えます。')
