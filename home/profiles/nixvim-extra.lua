-- Starlark tree-sitter parser config
local parser_config = require("nvim-treesitter.parsers").get_parser_configs()
parser_config.starlark = {
  install_info = {
    url = "~/projects/tree-sitter-starlark",
    files = {"src/parser.c", "src/scanner.c"},
    branch = "main",
    generate_requires_npm = false,
    requires_generate_from_grammar = true,
  },
}

-- LSP: starlark_rust (not natively supported by nixvim)
vim.lsp.enable('starlark_rust')
vim.lsp.config('starlark_rust', {
  capabilities = vim.lsp.protocol.make_client_capabilities(),
})
