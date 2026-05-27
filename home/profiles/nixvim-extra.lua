-- Starlark: reuse the python tree-sitter parser for .star / .bzl files
vim.treesitter.language.register('python', 'starlark')

-- LSP: starlark_rust (not natively supported by nixvim)
vim.lsp.enable('starlark_rust')
vim.lsp.config('starlark_rust', {
  capabilities = vim.lsp.protocol.make_client_capabilities(),
})
