-- Bazel / Starlark: starpls LSP (not natively supported by nixvim).
-- The binary is picked from the environment first, with a fallback shipped
-- via home.packages.
vim.filetype.add({
  extension = {
    bzl = 'bzl',
    star = 'bzl',
  },
  filename = {
    ['BUILD'] = 'bzl',
    ['BUILD.bazel'] = 'bzl',
    ['WORKSPACE'] = 'bzl',
    ['WORKSPACE.bazel'] = 'bzl',
    ['MODULE.bazel'] = 'bzl',
  },
})

vim.lsp.config('starpls', {
  cmd = { 'starpls' },
  filetypes = { 'bzl' },
  root_markers = { 'WORKSPACE', 'WORKSPACE.bazel', 'MODULE.bazel', '.git' },
})
vim.lsp.enable('starpls')

-- Treesitter highlights Bazel files with the `starlark` grammar; map our `bzl`
-- filetype onto it so highlighting/indent/textobjects work there too.
vim.treesitter.language.register('starlark', 'bzl')
