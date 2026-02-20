-- Rockit LSP configuration for Neovim (nvim-lspconfig)
--
-- Add this to your init.lua or lua/plugins/lsp.lua:
--
--   require("lspconfig.configs").rockit = require("path.to.this.file")
--   require("lspconfig").rockit.setup({})
--
-- Or paste the config block directly into your lspconfig setup.

local util = require("lspconfig.util")

return {
  default_config = {
    cmd = { "rockit", "lsp" },
    filetypes = { "rockit" },
    root_dir = util.root_pattern("fuel.toml", ".git"),
    single_file_support = true,
    settings = {},
  },
  docs = {
    description = [[
Rockit Language Server

The language server for the Rockit programming language.
Provides diagnostics, hover, completion, go-to-definition,
document symbols, and signature help.

Install the `rockit` CLI and ensure it is on your PATH.
https://github.com/Dark-Matter/moon
]],
  },
}
