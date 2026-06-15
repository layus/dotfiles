{ pkgs, lib, config, ... }:
{
  options.custom.nixvim = lib.mkEnableOption "nixvim neovim configuration" // { default = true; };

  config = lib.mkIf config.custom.nixvim {
    home.sessionVariables = {
      EDITOR = "nvim";
    };

    # Fallback LSP servers. The environment (e.g. a nix devshell) always takes
    # precedence on PATH; these are only used when no server is found there.
    # Note: no Haskell tooling is shipped here on purpose (HLS is env-only).
    home.packages = with pkgs; [
      nil # nix
      bash-language-server # bash / zsh
      rust-analyzer # rust
      clang-tools # C/C++ (clangd)
      starpls # bazel / starlark
      buildifier # bazel formatter
      marksman # markdown
      vscode-langservers-extracted # json / json5 (vscode-json-language-server)
    ];

    programs.nixvim = {
      enable = true;
      defaultEditor = true;
      viAlias = true;
      vimAlias = true;
      vimdiffAlias = true;

      withNodeJs = true;
      withPython3 = true;
      withRuby = true;

      globals.mapleader = " ";

      opts = {
        mouse = "a";
        clipboard = "unnamedplus";
        swapfile = false;
        relativenumber = true;
        number = true;
        showmatch = true;
        colorcolumn = "80";
        splitright = true;
        splitbelow = true;
        ignorecase = true;
        smartcase = true;
        linebreak = true;
        timeoutlen = 0;
        hidden = true;
        history = 100;
        lazyredraw = true;
        completeopt = "menuone,noselect";
        undofile = true;
        termguicolors = true;
        spell = true;
        spelllang = "en,fr,nl";
      };

      keymaps = [
        { mode = "v"; key = "<"; action = "<gv"; options.noremap = true; }
        { mode = "v"; key = ">"; action = ">gv"; options.noremap = true; }
        { mode = "n"; key = "<C-h>"; action = "<C-w>h"; options.noremap = true; }
        { mode = "n"; key = "<C-j>"; action = "<C-w>j"; options.noremap = true; }
        { mode = "n"; key = "<C-k>"; action = "<C-w>k"; options.noremap = true; }
        { mode = "n"; key = "<C-l>"; action = "<C-w>l"; options.noremap = true; }
        { mode = "n"; key = "<a-c>"; action = "<Cmd>lua buf_kill(0)<CR>"; options.noremap = true; }
        { mode = "n"; key = "<a-s-c>"; action = "<Cmd>lua buf_kill(0, true)<CR>"; options.noremap = true; }
        { mode = "n"; key = "<C-Right>"; action = ":e %:h/CMakeLists.txt<CR>"; options.noremap = true; }
        { mode = "n"; key = "<C-Left>"; action = ":e %:h/BUILD.bazel<CR>"; options.noremap = true; }
      ];

      # buf_kill helper loaded before everything else
      extraConfigLuaPre = builtins.readFile ./nixvim-buf-kill.lua;

      extraConfigLua = builtins.readFile ./nixvim-extra.lua;

      extraPackages = with pkgs; [
        fzf
        ripgrep
        curl
      ];

      colorscheme = "NeoSolarized";

      plugins = {
        which-key = {
          enable = true;
          settings.spec = [
            { __unkeyed-1 = "<leader>l"; group = "lsp"; }
            { __unkeyed-1 = "<leader>lD"; __unkeyed-2 = "<cmd>lua require('telescope.builtin').lsp_workspace_diagnostics()<CR>"; desc = "Open Diagnostics"; }
            { __unkeyed-1 = "<leader>lR"; __unkeyed-2 = "<cmd>lua vim.lsp.buf.rename()<CR>"; desc = "Rename"; }
            { __unkeyed-1 = "<leader>lS"; __unkeyed-2 = "<cmd>lua require('telescope.builtin').diagnostics()<CR>"; desc = "Workspace Symbols"; }
            { __unkeyed-1 = "<leader>la"; __unkeyed-2 = "<cmd>lua vim.lsp.buf.code_action()<CR>"; desc = "Code Actions"; }
            { __unkeyed-1 = "<leader>ld"; __unkeyed-2 = "<cmd>lua vim.lsp.buf.definition()<CR>"; desc = "Goto Definition"; }
            { __unkeyed-1 = "<leader>le"; __unkeyed-2 = "<cmd>lua vim.lsp.diagnostic.show_line_diagnostics()<CR>"; desc = "Show Diagnostic"; }
            { __unkeyed-1 = "<leader>lf"; __unkeyed-2 = "<cmd>lua vim.lsp.buf.format { async = true }<CR>"; desc = "Format"; }
            { __unkeyed-1 = "<leader>lh"; __unkeyed-2 = "<cmd>lua vim.lsp.buf.hover()<CR>"; desc = "Hover"; }
            { __unkeyed-1 = "<leader>li"; __unkeyed-2 = "<cmd>lua vim.lsp.buf.implementation()<CR>"; desc = "Goto Implementation"; }
            { __unkeyed-1 = "<leader>ll"; __unkeyed-2 = "<cmd>e ~/.cache/nvim/lsp.log<CR>"; desc = "Open Log"; }
            { __unkeyed-1 = "<leader>lr"; __unkeyed-2 = "<cmd>lua vim.lsp.buf.references()<CR>"; desc = "Find References"; }
            { __unkeyed-1 = "<leader>e"; __unkeyed-2 = "<cmd>NvimTreeFindFileToggle<cr>"; desc = "Tree"; }
            { __unkeyed-1 = "<leader>f"; group = "find"; }
            # files / search
            { __unkeyed-1 = "<leader>fb"; __unkeyed-2 = "<cmd>Telescope buffers<cr>"; desc = "Buffers"; }
            { __unkeyed-1 = "<leader>ff"; __unkeyed-2 = "<cmd>Telescope find_files<cr>"; desc = "File"; }
            { __unkeyed-1 = "<leader>fg"; __unkeyed-2 = "<cmd>Telescope live_grep<cr>"; desc = "RipGrep"; }
            { __unkeyed-1 = "<leader>fh"; __unkeyed-2 = "<cmd>Telescope help_tags<cr>"; desc = "Help Tags"; }
            { __unkeyed-1 = "<leader>fr"; __unkeyed-2 = "<cmd>Telescope oldfiles<cr>"; desc = "Recent File"; }
            { __unkeyed-1 = "<leader>fs"; __unkeyed-2 = "<cmd>Telescope grep_string<cr>"; desc = "Grep Word Under Cursor"; }
            { __unkeyed-1 = "<leader>f/"; __unkeyed-2 = "<cmd>Telescope current_buffer_fuzzy_find<cr>"; desc = "Fuzzy In Buffer"; }
            { __unkeyed-1 = "<leader>ft"; __unkeyed-2 = "<cmd>Telescope treesitter<cr>"; desc = "Treesitter Symbols"; }
            { __unkeyed-1 = "<leader>f."; __unkeyed-2 = "<cmd>Telescope resume<cr>"; desc = "Resume Last Picker"; }
            # lsp pickers
            { __unkeyed-1 = "<leader>fl"; group = "lsp"; }
            { __unkeyed-1 = "<leader>flr"; __unkeyed-2 = "<cmd>Telescope lsp_references<cr>"; desc = "References"; }
            { __unkeyed-1 = "<leader>fld"; __unkeyed-2 = "<cmd>Telescope lsp_definitions<cr>"; desc = "Definitions"; }
            { __unkeyed-1 = "<leader>fli"; __unkeyed-2 = "<cmd>Telescope lsp_implementations<cr>"; desc = "Implementations"; }
            { __unkeyed-1 = "<leader>flt"; __unkeyed-2 = "<cmd>Telescope lsp_type_definitions<cr>"; desc = "Type Definitions"; }
            { __unkeyed-1 = "<leader>fls"; __unkeyed-2 = "<cmd>Telescope lsp_document_symbols<cr>"; desc = "Document Symbols"; }
            { __unkeyed-1 = "<leader>flS"; __unkeyed-2 = "<cmd>Telescope lsp_dynamic_workspace_symbols<cr>"; desc = "Workspace Symbols"; }
            { __unkeyed-1 = "<leader>flx"; __unkeyed-2 = "<cmd>Telescope diagnostics<cr>"; desc = "Diagnostics"; }
            # git pickers
            { __unkeyed-1 = "<leader>fG"; group = "git"; }
            { __unkeyed-1 = "<leader>fGf"; __unkeyed-2 = "<cmd>Telescope git_files<cr>"; desc = "Git Files"; }
            { __unkeyed-1 = "<leader>fGc"; __unkeyed-2 = "<cmd>Telescope git_commits<cr>"; desc = "Commits"; }
            { __unkeyed-1 = "<leader>fGb"; __unkeyed-2 = "<cmd>Telescope git_bcommits<cr>"; desc = "Buffer Commits"; }
            { __unkeyed-1 = "<leader>fGB"; __unkeyed-2 = "<cmd>Telescope git_branches<cr>"; desc = "Branches"; }
            { __unkeyed-1 = "<leader>fGs"; __unkeyed-2 = "<cmd>Telescope git_status<cr>"; desc = "Status"; }
            { __unkeyed-1 = "<leader>fGt"; __unkeyed-2 = "<cmd>Telescope git_stash<cr>"; desc = "Stash"; }
            # vim / misc pickers
            { __unkeyed-1 = "<leader>fv"; group = "vim/misc"; }
            { __unkeyed-1 = "<leader>fvc"; __unkeyed-2 = "<cmd>Telescope commands<cr>"; desc = "Commands"; }
            { __unkeyed-1 = "<leader>fvk"; __unkeyed-2 = "<cmd>Telescope keymaps<cr>"; desc = "Keymaps"; }
            { __unkeyed-1 = "<leader>fvh"; __unkeyed-2 = "<cmd>Telescope command_history<cr>"; desc = "Command History"; }
            { __unkeyed-1 = "<leader>fv/"; __unkeyed-2 = "<cmd>Telescope search_history<cr>"; desc = "Search History"; }
            { __unkeyed-1 = "<leader>fvm"; __unkeyed-2 = "<cmd>Telescope marks<cr>"; desc = "Marks"; }
            { __unkeyed-1 = "<leader>fvj"; __unkeyed-2 = "<cmd>Telescope jumplist<cr>"; desc = "Jumplist"; }
            { __unkeyed-1 = "<leader>fvr"; __unkeyed-2 = "<cmd>Telescope registers<cr>"; desc = "Registers"; }
            { __unkeyed-1 = "<leader>fvq"; __unkeyed-2 = "<cmd>Telescope quickfix<cr>"; desc = "Quickfix"; }
            { __unkeyed-1 = "<leader>fvl"; __unkeyed-2 = "<cmd>Telescope loclist<cr>"; desc = "Location List"; }
            { __unkeyed-1 = "<leader>fvC"; __unkeyed-2 = "<cmd>Telescope colorscheme<cr>"; desc = "Colorscheme"; }
            { __unkeyed-1 = "<leader>fvM"; __unkeyed-2 = "<cmd>Telescope man_pages<cr>"; desc = "Man Pages"; }
            { __unkeyed-1 = "<leader>fvo"; __unkeyed-2 = "<cmd>Telescope vim_options<cr>"; desc = "Vim Options"; }
            { __unkeyed-1 = "<leader>g"; group = "git"; }
            { __unkeyed-1 = "<leader>gl"; __unkeyed-2 = "<cmd>call gh_line('blob', g:gh_always_interactive)<cr>"; desc = "Link"; }
            { __unkeyed-1 = "<leader>gg"; __unkeyed-2 = "<cmd>LazyGit<cr>"; desc = "LazyGit"; }
            { __unkeyed-1 = "<leader>gb"; __unkeyed-2 = "<cmd>lua require('gitsigns').blame_line{full=true}<CR>"; desc = "Blame"; }
            { __unkeyed-1 = "<leader>gh"; group = "hunk"; }
            { __unkeyed-1 = "<leader>ghr"; __unkeyed-2 = "<cmd>Gitsigns reset_hunk<cr>"; desc = "Reset"; }
            { __unkeyed-1 = "<leader>ghs"; __unkeyed-2 = "<cmd>Gitsigns stage_hunk<cr>"; desc = "Stage"; }
            { __unkeyed-1 = "<leader>ghu"; __unkeyed-2 = "<cmd>Gitsigns undo_stage_hunk<cr>"; desc = "Undo"; }
            { __unkeyed-1 = "<leader>b"; group = "buffers"; }
            { __unkeyed-1 = "<leader>bd"; __unkeyed-2 = "<cmd>lua require('bufdelete').bufdelete(0)<cr>"; desc = "Delete"; }
            { __unkeyed-1 = "<s-tab>"; __unkeyed-2 = "<cmd>TablineBufferPrevious<cr>"; desc = "Previous Buffer"; }
            { __unkeyed-1 = "<tab>"; __unkeyed-2 = "<cmd>TablineBufferNext<cr>"; desc = "Next Buffer"; }
          ];
        };

        telescope = {
          enable = true;
          settings.defaults = {
            wrap_results = true;
            # Open all <Tab>-selected entries at once (falls back to the entry
            # under the cursor when nothing is multi-selected).
            mappings =
              let
                multiopen = ''
                  function(prompt_bufnr)
                    local actions = require("telescope.actions")
                    local state = require("telescope.actions.state")
                    local picker = state.get_current_picker(prompt_bufnr)
                    local multi = picker:get_multi_selection()
                    if vim.tbl_isempty(multi) then
                      actions.select_default(prompt_bufnr)
                      return
                    end
                    actions.close(prompt_bufnr)
                    for _, entry in ipairs(multi) do
                      local filename = entry.filename or entry.value
                      if filename then
                        vim.cmd(string.format("edit %s", vim.fn.fnameescape(filename)))
                      end
                    end
                  end
                '';
              in
              {
                i."<CR>".__raw = multiopen;
                n."<CR>".__raw = multiopen;
              };
          };
          extensions.ui-select.enable = true;
        };

        cmp = {
          enable = true;
          settings = {
            snippet.expand = ''
              function(args)
                require('luasnip').lsp_expand(args.body)
              end
            '';
            sources = [
              { name = "nvim_lsp"; }
              { name = "luasnip"; }
              { name = "buffer"; }
            ];
            mapping = {
              "<Tab>" = ''
                cmp.mapping(function(fallback)
                  local luasnip = require("luasnip")
                  if cmp.visible() then
                    cmp.select_next_item()
                  elseif luasnip.expand_or_jumpable() then
                    luasnip.expand_or_jump()
                  else
                    fallback()
                  end
                end, { "i", "s" })
              '';
              "<S-Tab>" = ''
                cmp.mapping(function(fallback)
                  local luasnip = require("luasnip")
                  if cmp.visible() then
                    cmp.select_prev_item()
                  elseif luasnip.jumpable(-1) then
                    luasnip.jump(-1)
                  else
                    fallback()
                  end
                end, { "i", "s" })
              '';
              "<CR>" = "cmp.mapping.confirm({ select = false })";
            };
          };
        };

        luasnip = {
          enable = true;
          fromVscode = [{ }];
        };
        friendly-snippets.enable = true;

        nvim-tree.enable = true;

        treesitter = {
          enable = true;
          settings = {
            highlight = {
              enable = true;
              additional_vim_regex_highlighting = false;
            };
            indent.enable = true;
            incremental_selection = {
              enable = true;
              keymaps = {
                init_selection = "<C-space>";
                node_incremental = "<C-space>";
                node_decremental = "<bs>";
                scope_incremental = "<C-s>";
              };
            };
          };
          grammarPackages = with pkgs.vimPlugins.nvim-treesitter.builtGrammars; [
            # languages I actively support
            nix
            bash # also used for zsh files
            rust
            c
            cpp
            starlark # bazel (BUILD/.bzl/WORKSPACE/MODULE)
            haskell
            json
            json5
            markdown
            markdown-inline
            # config / glue languages
            lua
            python
            toml
            yaml
            regex
            vimdoc
            query
          ];
        };

        treesitter-context.enable = true;

        treesitter-textobjects = {
          enable = true;
          settings = {
            select = {
              enable = true;
              lookahead = true;
              keymaps = {
                "af" = "@function.outer";
                "if" = "@function.inner";
                "ac" = "@class.outer";
                "ic" = "@class.inner";
                "aa" = "@parameter.outer";
                "ia" = "@parameter.inner";
              };
            };
            move = {
              enable = true;
              set_jumps = true;
              goto_next_start = {
                "]f" = "@function.outer";
                "]c" = "@class.outer";
              };
              goto_previous_start = {
                "[f" = "@function.outer";
                "[c" = "@class.outer";
              };
            };
            swap = {
              enable = true;
              swap_next = { "<leader>a" = "@parameter.inner"; };
              swap_previous = { "<leader>A" = "@parameter.inner"; };
            };
          };
        };

        lsp = {
          enable = true;
          # Servers are picked up from the environment (e.g. a nix devshell) first;
          # `package = null` keeps nixvim from prepending its own copy on PATH. A
          # fallback for each server is shipped via `home.packages` above, so a
          # server is always available even outside a devshell. Haskell is the
          # exception: HLS is used from the environment only, with no fallback.
          servers = {
            hls = {
              enable = true;
              package = null;
              installGhc = false;
            };
            rust_analyzer = {
              enable = true;
              package = null;
              installCargo = false;
              installRustc = false;
            };
            nil_ls = {
              enable = true;
              package = null;
              settings.formatting.command = [ "nixpkgs-fmt" ];
            };
            clangd = {
              enable = true;
              package = null;
            };
            bashls = {
              enable = true;
              package = null;
              filetypes = [ "sh" "bash" "zsh" ];
            };
            jsonls = {
              enable = true;
              package = null;
              filetypes = [ "json" "jsonc" "json5" ];
            };
            marksman = {
              enable = true;
              package = null;
            };
          };
        };

        gitsigns.enable = true;

        lualine = {
          enable = true;
          settings.sections = {
            lualine_b.__raw = "{ {'filename', path = 1} }";
            lualine_c = [ "branch" "diff" "diagnostics" "lsp_progress" ];
          };
        };

        toggleterm = {
          enable = true;
          settings = {
            open_mapping = "[[<c-t>]]";
            direction = "float";
          };
        };

        notify.enable = true;

        nvim-surround.enable = true;

        markdown-preview.enable = true;
        web-devicons.enable = true;
        lazygit.enable = true;
        rainbow-delimiters.enable = true;
      };

      extraPlugins = with pkgs.vimPlugins; [
        NeoSolarized
        octo-nvim
        vim-nix
        vim-lastplace
        vim-gh-line
        plenary-nvim
        editorconfig-nvim
        bufdelete-nvim
        rust-vim
        lalrpop-vim
        vim-markdown
        mini-nvim
        tabline-nvim
        dial-nvim
      ];

      extraConfigLuaPost = ''
        require('tabline').setup {}
        vim.g.gh_line_map_default = 0

        -- dial.nvim: extend <C-a>/<C-x> to cycle booleans (and the usual numbers,
        -- dates, hex). Works in normal and visual mode.
        do
          local augend = require("dial.augend")
          require("dial.config").augends:register_group {
            default = {
              augend.integer.alias.decimal_int,
              augend.integer.alias.hex,
              augend.date.alias["%Y-%m-%d"],
              augend.constant.new { elements = { "true", "false" }, word = true, cyclic = true },
              augend.constant.new { elements = { "True", "False" }, word = true, cyclic = true },
              #augend.constant.new { elements = { "and", "or" }, word = true, cyclic = true },
              #augend.constant.new { elements = { "yes", "no" }, word = true, cyclic = true },
            },
          }
          local map = require("dial.map")
          vim.keymap.set("n", "<C-a>", function() return map.inc_normal() end, { expr = true })
          vim.keymap.set("n", "<C-x>", function() return map.dec_normal() end, { expr = true })
          vim.keymap.set("v", "<C-a>", function() return map.inc_visual() end, { expr = true })
          vim.keymap.set("v", "<C-x>", function() return map.dec_visual() end, { expr = true })
          vim.keymap.set("v", "g<C-a>", function() return map.inc_gvisual() end, { expr = true })
          vim.keymap.set("v", "g<C-x>", function() return map.dec_gvisual() end, { expr = true })
        end

        -- Ensure en/fr/nl spell files are present. Neovim only bundles English,
        -- so the missing dictionaries are downloaded on first start into a
        -- writable runtimepath dir. Files only download if absent, so this is a
        -- no-op once they exist.
        do
          local spelldir = vim.fn.stdpath("data") .. "/site/spell"
          vim.fn.mkdir(spelldir, "p")
          local base = "https://ftp.nluug.nl/pub/vim/runtime/spell/"
          for _, lang in ipairs({ "en", "fr", "nl" }) do
            for _, ext in ipairs({ "spl", "sug" }) do
              local name = lang .. ".utf-8." .. ext
              local dest = spelldir .. "/" .. name
              if vim.fn.filereadable(dest) == 0 then
                vim.system(
                  { "curl", "-fsSL", "-o", dest, base .. name },
                  { text = true },
                  function(res)
                    if res.code ~= 0 then
                      vim.schedule(function()
                        vim.notify(
                          "Failed to download spell file " .. name,
                          vim.log.levels.WARN
                        )
                      end)
                    end
                  end
                )
              end
            end
          end
        end

        -- Keep user-added words (zg/zw) in a writable location.
        local userspell = vim.fn.stdpath("data") .. "/site/spell"
        vim.opt.spellfile = userspell .. "/custom.utf-8.add"
      '';
    };
  };
}
