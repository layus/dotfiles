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
      nil                            # nix
      bash-language-server           # bash / zsh
      rust-analyzer                  # rust
      clang-tools                    # C/C++ (clangd)
      starpls                        # bazel / starlark
      buildifier                     # bazel formatter
      marksman                       # markdown
      vscode-langservers-extracted   # json / json5 (vscode-json-language-server)
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
          { __unkeyed-1 = "<leader>fb"; __unkeyed-2 = "<cmd>Telescope buffers<cr>"; desc = "Buffers"; }
          { __unkeyed-1 = "<leader>ff"; __unkeyed-2 = "<cmd>Telescope find_files<cr>"; desc = "File"; }
          { __unkeyed-1 = "<leader>fg"; __unkeyed-2 = "<cmd>Telescope live_grep<cr>"; desc = "RipGrep"; }
          { __unkeyed-1 = "<leader>fh"; __unkeyed-2 = "<cmd>Telescope help_tags<cr>"; desc = "Help Tags"; }
          { __unkeyed-1 = "<leader>fr"; __unkeyed-2 = "<cmd>Telescope oldfiles<cr>"; desc = "Recent File"; }
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
        settings.defaults.wrap_results = true;
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
        fromVscode = [{}];
      };
      friendly-snippets.enable = true;

      nvim-tree.enable = true;

      # treesitter = {
      #   enable = true;
      #   settings = {
      #     highlight = {
      #       enable = true;
      #       additional_vim_regex_highlighting = false;
      #     };
      #     indent.enable = true;
      #   };
      #   grammarPackages = with pkgs.vimPlugins.nvim-treesitter.builtGrammars; [
      #     c bash nix haskell python
      #   ];
      # };

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
    ];

    extraConfigLuaPost = ''
      require('tabline').setup {}
      vim.g.gh_line_map_default = 0
    '';
    };
  };
}
