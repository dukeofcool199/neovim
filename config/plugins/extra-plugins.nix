{pkgs, ...}: let
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

  jj-nvim = pkgs.vimUtils.buildVimPlugin {
    name = "jj.nvim";
    src = pkgs.fetchFromGitHub {
      owner = "NicolasGB";
      repo = "jj.nvim";
      rev = "d13a5c9aec08318323f19fcdc1a1d2c469e00739";
      sha256 = "sha256-8POSGuNYdAR2peyzN92vWR87GqWf+Y6I1arOwNxwd6U=";
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
    jj-nvim

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
      claudecode.setup({
        cwd = vim.fn.getcwd()
      })
    end

    -- OpenCode setup
    local ok, op = pcall(require, "opencode")
    if ok then
      -- Enable auto-reload for OpenCode file edits
      vim.o.autoread = true

      -- Enhanced OpenCode configuration
      vim.g.opencode_opts = {
        provider = {
          enabled = "snacks",
          snacks = {}
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

    -- jj.nvim setup (Jujutsu VCS integration)
    local jj_ok, jj = pcall(require, "jj")
    if jj_ok then
      jj.setup({})
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

    # OpenCode keymaps
    {
      mode = "n";
      key = "<leader>oo";
      action.__raw = ''
        function()
          require("opencode").toggle()
        end
      '';
      options = {
        desc = "Toggle OpenCode";
        silent = true;
      };
    }
    {
      mode = ["n" "x"];
      key = "<leader>oa";
      action.__raw = ''
        function()
          require("opencode").ask("@this: ", { submit = true })
        end
      '';
      options = {
        desc = "Ask OpenCode";
        silent = true;
      };
    }
    {
      mode = ["n" "x"];
      key = "<leader>ox";
      action.__raw = ''
        function()
          require("opencode").select()
        end
      '';
      options = {
        desc = "Execute action";
        silent = true;
      };
    }
    {
      mode = ["n" "x"];
      key = "<leader>or";
      action.__raw = ''
        function()
          return require("opencode").operator("@this ")
        end
      '';
      options = {
        desc = "Add range to OpenCode";
        silent = true;
        expr = true;
      };
    }
    {
      mode = "n";
      key = "<leader>ol";
      action.__raw = ''
        function()
          return require("opencode").operator("@this ") .. "_"
        end
      '';
      options = {
        desc = "Add line to OpenCode";
        silent = true;
        expr = true;
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

    # jj.nvim (Jujutsu) keymaps
    {
      mode = "n";
      key = "<leader>jl";
      action = "<cmd>J log<cr>";
      options = {
        desc = "Log";
        silent = true;
        noremap = true;
      };
    }
    {
      mode = "n";
      key = "<leader>js";
      action = "<cmd>J status<cr>";
      options = {
        desc = "Status";
        silent = true;
        noremap = true;
      };
    }
    {
      mode = "n";
      key = "<leader>jd";
      action = "<cmd>Jdiff<cr>";
      options = {
        desc = "Diff (vertical)";
        silent = true;
        noremap = true;
      };
    }
    {
      mode = "n";
      key = "<leader>jD";
      action = "<cmd>Jhdiff<cr>";
      options = {
        desc = "Diff (horizontal)";
        silent = true;
        noremap = true;
      };
    }
    {
      mode = "n";
      key = "<leader>jn";
      action = "<cmd>J new<cr>";
      options = {
        desc = "New change";
        silent = true;
        noremap = true;
      };
    }
    {
      mode = "n";
      key = "<leader>jc";
      action = "<cmd>J describe<cr>";
      options = {
        desc = "Describe (commit msg)";
        silent = true;
        noremap = true;
      };
    }
    {
      mode = "n";
      key = "<leader>jp";
      action = "<cmd>J push<cr>";
      options = {
        desc = "Push";
        silent = true;
        noremap = true;
      };
    }
    {
      mode = "n";
      key = "<leader>jf";
      action = "<cmd>J fetch<cr>";
      options = {
        desc = "Fetch";
        silent = true;
        noremap = true;
      };
    }
    {
      mode = "n";
      key = "<leader>jo";
      action = "<cmd>J open_pr<cr>";
      options = {
        desc = "Open PR/MR";
        silent = true;
        noremap = true;
      };
    }
  ];
}
