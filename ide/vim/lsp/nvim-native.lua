-- Rockit LSP configuration for Neovim 0.11+ native vim.lsp.config
--
-- Add this to ~/.config/nvim/lsp/rockit.lua (Neovim will auto-detect it)
-- OR require it from your init.lua.

vim.lsp.config("rockit", {
  cmd = { "rockit", "lsp" },
  filetypes = { "rockit" },
  root_markers = { "fuel.toml", ".git" },
})

vim.lsp.enable("rockit")
