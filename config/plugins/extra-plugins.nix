{ pkgs, ... }:
let
  # Custom plugins not available in nixpkgs
  opencode = pkgs.vimUtils.buildVimPlugin {
    name = "opencode.nvim";
    src = pkgs.fetchFromGitHub {
      owner = "NickvanDyke";
      repo = "opencode.nvim";
      rev = "aba9e8c64cdb074d3d481e3a0101f6113061bef3";
      sha256 = "sha256-+hgiJ6GXOPafdmUuSdwhbyIKILjI5HMJQYtsFtdSp0k=";
    };
    doCheck = false;
  };

  gitmoji-telescope = pkgs.vimUtils.buildVimPlugin rec {
    name = "telescope-gitmoji.nvim";
    src = pkgs.fetchFromGitHub {
      owner = "olacin";
      repo = name;
      rev = "1f7b5c7c6dfcce236638f82b3c19a7f1ecf77a8f";
      sha256 = "sha256-8ciPyFdpiLdLmS5LO/IBRMkhezU1WKGpk8w2LMeHdHQ=";
    };
  };

  spongebob = pkgs.vimUtils.buildVimPlugin {
    name = "sPoNGe-BoB.NvIm";
    src = pkgs.fetchFromGitHub {
      owner = "tjdevries";
      repo = "sPoNGe-BoB.NvIm";
      rev = "master";
      sha256 = "sha256-xR0JOsU4GYrYdpVzEFdnL5RmPu+GnxtDsTnc+jk54P4=";
    };
    doCheck = false;
  };

  prr = pkgs.vimUtils.buildVimPlugin {
    name = "prr";
    src = pkgs.fetchFromGitHub {
      owner = "danobi";
      repo = "prr";
      rev = "master";
      sha256 = "sha256-duoC3TMgW+h5OrRCbqYPppMtnQBfS9R7ZpHQySgPRv4=";
    };
    postPatch = ''
      mv vim/* .  # Move the vim directory's contents to the root
      rmdir vim
    '';
  };

  claudecode = pkgs.vimUtils.buildVimPlugin {
    name = "claudecode.nvim";
    src = pkgs.fetchFromGitHub {
      owner = "coder";
      repo = "claudecode.nvim";
      rev = "93f8e48b1f6cbf2469b378c20b3df4115252d379";
      sha256 = "sha256-dh7RrWezkmEtMKRasYCqfYanl6VxybC6Ra649H/KrPI=";
    };
    doCheck = false;
  };

in {
  extraPlugins = with pkgs.vimPlugins; [
    # Utility
    vim-bufkill

    # Custom plugins (not available in nixpkgs)
    spongebob
    prr
    opencode
    gitmoji-telescope
    claudecode

    # Telescope extensions
    telescope-symbols-nvim

    # LSP utilities
    lsp-colors-nvim
    nvim-jdtls
    neoformat

    # Writing
    vim-pencil

    # Colorschemes
    monokai-pro-nvim
    awesome-vim-colorschemes

    # Markdown
    vim-markdown
    vim-markdown-toc

    # Language specific
    vim-astro
    vim-prisma
    vim-vue-plugin
    vim-svelte

    # Bookmarks
    vim-bookmarks
    telescope-vim-bookmarks-nvim
  ];

  # OpenCode configuration
  extraConfigLua = ''
    -- ClaudeCode setup
    local claudecode_ok, claudecode = pcall(require, "claudecode")
    if claudecode_ok then
      claudecode.setup({})
    end

    -- OpenCode setup
    local ok, op = pcall(require, "opencode")
    if ok then
      -- Enable auto-reload for OpenCode file edits
      vim.o.autoread = true

      -- Enhanced OpenCode configuration
      vim.g.opencode_opts = {
        provider = {
          enabled = "kitty",
          kitty = {}
        },
        events = {
          reload = true,
        },
        prompts = {
          diagnostics = "Explain @diagnostics",
          diff = "Review the following git diff for correctness and readability: @diff",
          document = "Add comments documenting @this",
          explain = "Explain @this and its context",
          fix = "Fix @diagnostics",
          implement = "Implement @this",
          optimize = "Optimize @this for performance and readability",
          review = "Review @this for correctness and readability",
          test = "Add tests for @this"
        }
      }
    end

    -- Load telescope gitmoji extension
    local telescope_ok, telescope = pcall(require, "telescope")
    if telescope_ok then
      pcall(telescope.load_extension, "gitmoji")
      pcall(telescope.load_extension, "vim_bookmarks")
    end
  '';

  # Bookmark keymaps
  keymaps = [
    {
      mode = "n";
      key = "<leader>Ba";
      action = "<cmd>BookmarkAnnotate<CR>";
      options = {
        desc = "Annotate";
        silent = true;
        noremap = true;
      };
    }
    {
      mode = "n";
      key = "<leader>BF";
      action = "<cmd>Telescope vim_bookmarks all<CR>";
      options = {
        desc = "Find (All)";
        silent = true;
        noremap = true;
      };
    }
    {
      mode = "n";
      key = "<leader>Bf";
      action = "<cmd>Telescope vim_bookmarks current_file<CR>";
      options = {
        desc = "Find (Current File)";
        silent = true;
        noremap = true;
      };
    }
    {
      mode = "n";
      key = "<leader>Bc";
      action = "<cmd>BookmarkClear<CR>";
      options = {
        desc = "Clear";
        silent = true;
        noremap = true;
      };
    }
    {
      mode = "n";
      key = "<leader>BC";
      action = "<cmd>BookmarkClearAll<CR>";
      options = {
        desc = "Clear All";
        silent = true;
        noremap = true;
      };
    }
    {
      mode = "n";
      key = "<leader>Bu";
      action = "<cmd>BookmarkMoveDown<CR>";
      options = {
        desc = "Move Down";
        silent = true;
        noremap = true;
      };
    }
    {
      mode = "n";
      key = "<leader>Bd";
      action = "<cmd>BookmarkMoveUp<CR>";
      options = {
        desc = "Move Up";
        silent = true;
        noremap = true;
      };
    }
    {
      mode = "n";
      key = "<leader>Bn";
      action = "<cmd>BookmarkNext<CR>";
      options = {
        desc = "Next";
        silent = true;
        noremap = true;
      };
    }
    {
      mode = "n";
      key = "<leader>Bp";
      action = "<cmd>BookmarkPrev<CR>";
      options = {
        desc = "Previous";
        silent = true;
        noremap = true;
      };
    }
    {
      mode = "n";
      key = "<leader>Bt";
      action = "<cmd>BookmarkToggle<CR>";
      options = {
        desc = "Toggle";
        silent = true;
        noremap = true;
      };
    }

    # Gitmoji keymap
    {
      mode = "n";
      key = "<leader>fe";
      action.__raw = ''
        function()
          local telescope = require("telescope")
          if telescope.extensions.gitmoji then
            telescope.extensions.gitmoji.gitmoji()
          end
        end
      '';
      options = {
        desc = "Find Gitmojis";
        silent = true;
      };
    }

    # ClaudeCode keymaps
    {
      mode = "n";
      key = "<leader>ac";
      action = "<cmd>ClaudeCode<cr>";
      options = {
        desc = "Toggle Claude";
        silent = true;
        noremap = true;
      };
    }
    {
      mode = "n";
      key = "<leader>af";
      action = "<cmd>ClaudeCodeFocus<cr>";
      options = {
        desc = "Focus Claude";
        silent = true;
        noremap = true;
      };
    }
    {
      mode = "v";
      key = "<leader>as";
      action = "<cmd>ClaudeCodeSend<cr>";
      options = {
        desc = "Send to Claude";
        silent = true;
        noremap = true;
      };
    }
  ];
}
