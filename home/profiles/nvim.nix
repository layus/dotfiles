{ pkgs, lib, ... }:
{
  home.sessionVariables = {
    EDITOR = "nvim";
  };

  home.packages = with pkgs; [
    haskell-language-server
    #(lib.lowPrio clang)
  ];

  programs.neovim = {
    enable = true;
    extraConfig = pkgs.lib.mkBefore ''
      lua <<EOF
        local cmd = vim.cmd
        local exec = vim.api.nvim_exec
        local api = vim.api
        local fn = vim.fn
        local g = vim.g
        local opt = vim.opt

        opt.mouse = 'a'
        opt.clipboard = 'unnamedplus'
        opt.swapfile = false
        opt.relativenumber = true
        opt.number = true
        opt.showmatch = true
        opt.colorcolumn = '80'
        opt.splitright = true
        opt.splitbelow = true
        opt.ignorecase = true
        opt.smartcase = true
        opt.linebreak = true
        opt.timeoutlen = 0
        opt.hidden = true
        opt.history = 100
        opt.lazyredraw = true
        opt.completeopt = 'menuone,noselect'
        opt.undofile = true

        cmd [[
          syntax enable
        ]]

        -- Don't lose selection
        api.nvim_set_keymap('v', '<', '<gv', { noremap=true })
        api.nvim_set_keymap('v', '>', '>gv', { noremap=true })

        api.nvim_set_keymap('n', '<C-h>', '<C-w>h', { noremap=true })
        api.nvim_set_keymap('n', '<C-j>', '<C-w>j', { noremap=true })
        api.nvim_set_keymap('n', '<C-k>', '<C-w>k', { noremap=true })
        api.nvim_set_keymap('n', '<C-l>', '<C-w>l', { noremap=true })


        local api = vim.api
    
        local function nvim_loaded_buffers()
          local result = {}
          local buffers = api.nvim_list_bufs()
          for _, buf in ipairs(buffers) do
            if api.nvim_buf_is_loaded(buf) then
              table.insert(result, buf)
            end
          end
          return result
        end
        
        -- Kill the target buffer (or the current one if 0/nil)
        function buf_kill(target_buf, should_force)
          if not should_force and vim.bo.modified then
            return api.nvim_err_writeln('Buffer is modified. Force required.')
          end
          local command = 'bd'
          if should_force then command = command..'!' end
          if target_buf == 0 or target_buf == nil then
            target_buf = api.nvim_get_current_buf()
          end
          local buffers = nvim_loaded_buffers()
          if #buffers == 1 then
            api.nvim_command(command)
            return
          end
          local nextbuf
          for i, buf in ipairs(buffers) do
            if buf == target_buf then
              nextbuf = buffers[(i - 1 + 1) % #buffers + 1]
              break
            end
          end
          api.nvim_set_current_buf(nextbuf)
          api.nvim_command(table.concat({command, target_buf}, ' '))
        end
        
        -- normal kill
        api.nvim_set_keymap('n', '<a-c>', '<Cmd>lua buf_kill(0)<CR>', { noremap=true })
        -- force kill
        api.nvim_set_keymap('n', '<a-s-c>', '<Cmd>lua buf_kill(0, true)<CR>', { noremap=true })
      EOF
    '';
    extraPackages = with pkgs; [
      # For telescope
      fzf
      ripgrep

      # Language Servers
      #haskell-language-server
      rnix-lsp
      rust-analyzer
      deno

      # Debuggers
      lldb
      haskellPackages.haskell-debug-adapter
      haskellPackages.ghci-dap

      # Formatters
      ormolu

      # Required for local grammars
      tree-sitter
      clang

      # Copy pasting
      #xsel
    ];
    viAlias = true;
    vimAlias = true;
    vimdiffAlias = true;
    withNodeJs = true;
    withPython3 = true;
    withRuby = true;
    plugins = with pkgs.vimPlugins; [
      # Which-key has to be first to bind the wk variable
      {
        plugin = which-key-nvim;
        type = "lua";
        config = ''
          wk = require("which-key")
        '';
      }
      #{
      #  plugin = firenvim;
      #  type = "lua";
      #  config = ''
      #  '';
      #}
      {
        plugin = nvim-cmp;
        type = "lua";
        config = ''
          local has_words_before = function()
            local line, col = unpack(vim.api.nvim_win_get_cursor(0))
            return col ~= 0 and vim.api.nvim_buf_get_lines(0, line - 1, line, true)[1]:sub(col, col):match("%s") == nil
          end
          local cmp = require('cmp')
          local luasnip = require("luasnip")
          cmp.setup {
            snippet = {
              expand = function(args)
                require('luasnip').lsp_expand(args.body)
              end,
            },
            sources = cmp.config.sources(
              {
                { name = 'nvim_lsp' },
                { name = 'luasnip' },
              },
              {
                { name = 'buffer' },
              }
            ),
            mapping = {
              ["<Tab>"] = cmp.mapping(function(fallback)
                if cmp.visible() then
                  cmp.select_next_item()
                elseif luasnip.expand_or_jumpable() then
                  luasnip.expand_or_jump()
                elseif has_words_before() then
                  cmp.complete()
                else
                  fallback()
                end
              end, { "i", "s" }),

              ["<S-Tab>"] = cmp.mapping(function(fallback)
                if cmp.visible() then
                  cmp.select_prev_item()
                elseif luasnip.jumpable(-1) then
                  luasnip.jump(-1)
                else
                  fallback()
                end
              end, { "i", "s" }),

              ['<CR>'] = cmp.mapping.confirm({ select = false }),
            },
          }
        '';
      }
      cmp-nvim-lsp
      # Snippets
      cmp_luasnip
      friendly-snippets
      {
        plugin = luasnip;
        type = "lua";
        config = ''
          require("luasnip.loaders.from_vscode").lazy_load()
        '';
      }
      {
        plugin = nvim-tree-lua;
        type = "lua";
        config = ''
          require("nvim-tree").setup{}
          wk.register{
            ["<leader>"] = {
              e = { "<cmd>NvimTreeFindFileToggle<cr>", "Tree"},
            },
          }
        '';
      }
      vim-markdown
      #vimwiki
      markdown-preview-nvim
      {
        plugin = nvim-treesitter.withPlugins (plugins: with plugins; [ c bash nix haskell python ]);
        type = "lua";
        config = ''
          local parser_config = require "nvim-treesitter.parsers".get_parser_configs()
          -- parser_config.clean = {
          --   install_info = {
          --     url = "~/Projects/tree-sitter-clean",
          --     files = {"src/parser.c", "src/scanner.cc"},
          --     branch = "main",
          --     generate_requires_npm = false,
          --     requires_generate_from_grammar = true,
          --   },
          -- }

          -- parser_config.nickel = {
          --   install_info = {
          --     url = "~/Projects/tweag/tree-sitter-nickel/",
          --     files = {"src/parser.c", "src/scanner.cc"},
          --     branch = "main",
          --     generate_requires_npm = false,
          --     requires_generate_from_grammar = false,
          --   },
          -- }

          require("nvim-treesitter.configs").setup {
            highlight = {
              enable = true,
              additional_vim_regex_highlighting = false,
            },
            indent = {
              enable = true
            },
            -- rainbow = {
            --   enable = true,
            --   extended_mode = true,
            --   max_file_lines = nul,
            -- },
            playground = {
              enable = true
            },
          }

          wk.register{
            ["<leader>"] = {
              t = {
                name = "+tree-sitter",
                p = { "<cmd>TSPlaygroundToggle<CR>", "Toggle Playground" },
              },
            },
          }
        '';
      }
      playground
      {
        plugin = nvim-lspconfig;
          type = "lua";
        config = ''
          wk.register{
            ["<leader>"] = {
              l = {
                name = "+lsp",
                d = { "<cmd>lua vim.lsp.buf.definition()<CR>", "Goto Definition" },
                i = { "<cmd>lua vim.lsp.buf.implementation()<CR>", "Goto Implementation" },
                D = { "<cmd>lua require('telescope.builtin').lsp_workspace_diagnostics()<CR>", "Open Diagnostics" },
                e = { "<cmd>lua vim.lsp.diagnostic.show_line_diagnostics()<CR>", "Show Diagnostic" },
                a = { "<cmd>lua vim.lsp.buf.code_action()<CR>", "Code Actions" },
                S = { "<cmd>lua require('telescope.builtin').diagnostics()<CR>", "Workspace Symbols" },
                r = { "<cmd>lua vim.lsp.buf.references()<CR>", "Find References" },
                R = { "<cmd>lua vim.lsp.buf.rename()<CR>", "Rename" },
                f = { "<cmd>lua vim.lsp.buf.formatting_sync(nil, 1000)<CR>", "Format"},
                h = { "<cmd>lua vim.lsp.buf.hover()<CR>", "Hover" },
                l = { "<cmd>e ~/.cache/nvim/lsp.log<CR>", "Open Log" },
              },
            },
          }
          local lspc = require("lspconfig")
          local on_attach = function(client, bufnr)
          end
          local flags = {
            debounce_text_changes = 500,
          }
          lspc.hls.setup {
            on_attach = on_attach,
            capabilities = capabilities,
            flags = flags,
            settings = {
              haskell = {
                plugin = {
                type = "lua";
                  hlint = {
                    globalOn = true
                  }
                }
              }
            }
          }
          lspc.rust_analyzer.setup{ on_attach = on_attach, capabilities = capabilities, flags = flags }
          lspc.rnix.setup{ on_attach = on_attach, capabilities = capabilities, flags = flags }
          lspc.clangd.setup{ on_attach = on_attach, capabilities = capabilities, flags = flags }
          lspc.denols.setup{ on_attach = on_attach, capabilities = capabilities, flags = flags }
          -- TODO: "autocmd BufWritePre * lua vim.lsp.buf.formatting_sync(nil, 1000)
        '';
      }
      {
        # plugin = zephyr-nvim;
        plugin = NeoSolarized;
        type = "lua";
        #require('solarized')
        config = ''
          vim.opt.termguicolors = true
          vim.cmd [[ colorscheme NeoSolarized ]]
        '';
      }
      {
        plugin = toggleterm-nvim;
        type = "lua";
        config = ''
            require("toggleterm").setup {
              open_mapping = [[<c-t>]],
              direction = 'float',
            }
        '';
      }
      vim-nix
      vim-lastplace
      {
        plugin = vim-gh-line;
          type = "lua";
        config = ''
            vim.g.gh_line_map_default = 0
            wk.register{
              ["<leader>"] = {
                g = {
                  name = "+git",
                  l = { "<cmd>call gh_line('blob', g:gh_always_interactive)<cr>", "Link" },
                },
              },
            }
        '';
      }
      {
        plugin = telescope-ui-select-nvim;
          type = "lua";
        config = ''
            require("telescope").load_extension("ui-select")
        '';
      }
      {
        plugin = telescope-nvim;
        type = "lua";
        config = ''
            wk.register{
              ["<leader>"] = {
                f = {
                  name = "+find",
                  f = { "<cmd>Telescope find_files<cr>", "File" },
                  r = { "<cmd>Telescope oldfiles<cr>", "Recent File" },
                  g = { "<cmd>Telescope live_grep<cr>", "RipGrep" },
                },
              },
            }
        '';
      }
      nvim-web-devicons
      {
        plugin = lazygit-nvim;
        type = "lua";
        config = ''
            wk.register{
              ["<leader>"] = {
                g = {
                  name = "+git",
                  g = { "<cmd>LazyGit<cr>", "LazyGit" },
                },
              },
            }
        '';
      }
      {
        plugin = tabline-nvim;
        type = "lua";
        config = ''
            require('tabline').setup {}
            wk.register{
              ["<tab>"] = { "<cmd>TablineBufferNext<cr>", "Next Buffer" },
              ["<s-tab>"] = { "<cmd>TablineBufferPrevious<cr>", "Previous Buffer" },
            }
        '';
      }
      lualine-lsp-progress
      {
        plugin = lualine-nvim;
          type = "lua";
        config = ''
          require('lualine').setup {
            sections = {
              lualine_c = {"filename", "lsp_progress"}
            }
          }
        '';
      }
      {
        plugin = nvim-notify;
          type = "lua";
        config = ''
            require('notify').setup {}
        '';
      }
      {
        plugin = gitsigns-nvim;
          type = "lua";
        config = ''
            require('gitsigns').setup { keymaps = {} }
            wk.register{
              ["<leader>"] = {
                g = {
                  name = "+git",
                  h = {
                    name = "+hunk",
                    s = { "<cmd>Gitsigns stage_hunk<cr>", "Stage" },
                    u = { "<cmd>Gitsigns undo_stage_hunk<cr>", "Undo" },
                    r = { "<cmd>Gitsigns reset_hunk<cr>", "Reset" },
                  },
                  b = { "<cmd>lua require('gitsigns').blame_line{full=true}<CR>", "Blame" },
                },
              },
            }
        '';
      }
      plenary-nvim
      editorconfig-nvim
      nvim-ts-rainbow
      {
        plugin = bufdelete-nvim;
        type = "lua";
        config = ''
            wk.register{
              ["<leader>"] = {
                b = {
                  name = "+buffers",
                  d = { "<cmd>lua require('bufdelete').bufdelete(0)<cr>", "Delete" },
                },
              },
            }
        '';
      }
      # DAP
      {
        plugin = nvim-dap;
          type = "lua";
        config = ''
            local dap = require('dap')
            wk.register{
              ["<leader>"] = {
                d = {
                  name = "+debug",
                  b = { "<cmd>lua require('dap').toggle_breakpoint()<cr>", "Breakpoint" },
                  c = { "<cmd>lua require('dap').continue()<cr>", "Continue" },
                },
              },
            }
            dap.adapters.lldb = {
              type = 'executable',
              command = '${pkgs.lldb}/bin/lldb-vscode',
              name = "lldb"
            }
            dap.configurations.rust = {
              {
                name = "Launch",
                type = "lldb",
                request = "launch",
                program = function()
                  return vim.fn.input('Path to executable: ', vim.fn.getcwd() .. '/', 'file')
                end,
                cwd = "''${workspaceFolder}",
                stopOnEntry = false,
                args = {},
                runInTerminal = false,
              },
              {
                name = "Attach to process",
                type = 'rust',
                request = 'attach',
                pid = require('dap.utils').pick_process,
                args = {},
              },
            }
            dap.adapters.haskell = {
              type = 'executable';
              command = 'haskell-debug-adapter';
              args = {};
            }
            dap.configurations.haskell = {
              {
                type = 'haskell',
                request = 'launch',
                name = 'cabal',
                workspace = "''${workspaceFolder}",
                startup = "''${file}",
                stopOnEntry = true,
                logFile = vim.fn.stdpath('cache') .. '/haskell-dap.log',
                logLevel = 'WARNING',
                ghciEnv = {HOI="hoi"},
                ghciPrompt = "Prelude>",
                ghciInitialPrompt = "Prelude>",
                ghciCmd= "cabal exec -- ghci-dap --interactive -i -i''${workspaceFolder}",
              },
            }
        '';
      }
      {
        plugin = nvim-dap-ui;
          type = "lua";
        config = ''
            require("dapui").setup()
            wk.register{
              ["<leader>"] = {
                d = {
                  name = "+debug",
                  o = { "<cmd>lua require('dapui').toggle()<cr>", "Toggle UI" },
                },
              },
            }
        '';
      }
      {
        plugin = telescope-dap-nvim;
        type = "lua";
        config = ''
            require('telescope').load_extension('dap')
        '';
      }
      {
        plugin = rust-tools-nvim;
          type = "lua";
        config = ''
            require('rust-tools').setup({})
        '';
      }
      #{
      #  plugin = indent-blankline-nvim;
      #  type = "lua";
      #  config = ''
      #      vim.cmd [[highlight IndentBlanklineIndent1 guifg=#E06C75 gui=nocombine]]
      #      vim.cmd [[highlight IndentBlanklineIndent2 guifg=#E5C07B gui=nocombine]]
      #      vim.cmd [[highlight IndentBlanklineIndent3 guifg=#98C379 gui=nocombine]]
      #      vim.cmd [[highlight IndentBlanklineIndent4 guifg=#56B6C2 gui=nocombine]]
      #      vim.cmd [[highlight IndentBlanklineIndent5 guifg=#61AFEF gui=nocombine]]
      #      vim.cmd [[highlight IndentBlanklineIndent6 guifg=#C678DD gui=nocombine]]

      #      vim.opt.list = true
      #      vim.opt.listchars = { space = "·", tab = "❥ " }

      #      require("indent_blankline").setup {
      #          space_char_blankline = " ",
      #          show_current_context = true,
      #          show_current_context_start = true,
      #          char_highlight_list = {
      #              "IndentBlanklineIndent1",
      #              "IndentBlanklineIndent2",
      #              "IndentBlanklineIndent3",
      #              "IndentBlanklineIndent4",
      #              "IndentBlanklineIndent5",
      #              "IndentBlanklineIndent6",
      #          },
      #      }
      #  '';
      #}
      rust-vim
      lalrpop-vim
      # CUSTOM/LOCAL PLUGINS
      #(pkgs.vimUtils.buildVimPluginFrom2Nix
      #  {
      #    pname = "vim-nickel";
      #    version = "0.1";
      #    src = /home/erin/Projects/tweag/vim-nickel;
      #  }
      #)
    ];
  };

  # The extraConfig is appended, resulting in problems with the leader key
  xdg.configFile."nvim/init.lua".text = pkgs.lib.mkBefore ''
    vim.g.mapleader = ' '
  '';
}
