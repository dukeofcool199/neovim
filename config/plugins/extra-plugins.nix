{pkgs, ...}: let
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

  reticle = pkgs.vimUtils.buildVimPlugin {
    name = "reticle.nvim";
    src = pkgs.fetchFromGitHub {
      owner = "Tummetott";
      repo = "reticle.nvim";
      rev = "66bfa2b1c28fd71bb8ae4e871e0cd9e9c509ea86";
      sha256 = "sha256-lf60+D68Oep0kZ9clfJTuiOkIMhZhgWyvFhf/kSYwVM=";
    };
    doCheck = false;
  };

  # Override avante-nvim to use the latest source with Claude Max subscription fix
  # while keeping the nixpkgs build infrastructure for native libraries
  avante = pkgs.vimPlugins.avante-nvim.overrideAttrs (oldAttrs: {
    version = "unstable-2026-03-11";
    src = pkgs.fetchFromGitHub {
      owner = "yetone";
      repo = "avante.nvim";
      rev = "9a7793461549939f1d52b2b309a1aa44680170c8";
      sha256 = "sha256-EEkAoufj29P46RIUrRNG0xJL9Wu4X7LZCS1fer4/nZQ=";
    };
  });
in {
  extraPlugins = with pkgs.vimPlugins; [
    # Utility
    vim-bufkill

    # Custom plugins (not available in nixpkgs)
    spongebob
    prr
    gitmoji-telescope
    jj-nvim
    reticle
    avante

    # Avante dependencies
    nui-nvim
    plenary-nvim
    render-markdown-nvim
    dressing-nvim

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
    haskell-vim
    vim-astro
    vim-prisma
    vim-vue-plugin
    vim-svelte

    # Bookmarks
    vim-bookmarks
    telescope-vim-bookmarks-nvim
  ];

  extraConfigLua = ''
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

            -- Dressing setup for better input/select UI
            local dressing_ok, dressing = pcall(require, "dressing")
            if dressing_ok then
              dressing.setup({
                input = {
                  enabled = true,
                  default_prompt = "Input:",
                  start_in_insert = true,
                  border = "rounded",
                  relative = "cursor",
                  prefer_width = 40,
                  win_options = {
                    winblend = 0,
                  },
                },
                select = {
                  enabled = true,
                  backend = { "telescope", "builtin" },
                },
              })
            end

            -- Render-markdown setup (exclude octo buffers to prevent conflicts)
            local render_markdown_ok, render_markdown = pcall(require, "render-markdown")
            if render_markdown_ok then
              render_markdown.setup({
                file_types = { "markdown", "Avante" },
              })
            end

            -- Reticle setup (cursor cross)
            local reticle_ok, reticle = pcall(require, "reticle")
            if reticle_ok then
              reticle.setup({
                on_startup = {
                  cursorline = true,
                  cursorcolumn = true,
                },
              })
            end

            -- Avante setup with inline autocomplete enabled
        local avante_ok, avante = pcall(require, "avante")
        if avante_ok then
              require("avante").setup({
      mode = "agentic",
      provider = "opencode",

      behaviour = {
        auto_suggestions = false,
        auto_apply_diff_after_generation = false,
        enable_token_counting = true,
      },

      windows = {
        position = "right",
        width = 30,
      },

      selector = {
        provider = "dressing",
      },

      input = {
        provider = "dressing",
      },

      -- optional, because current Avante already ships an opencode ACP entry
      acp_providers = {
        ["opencode"] = {
          command = "opencode",
          args = { "acp" },
        },
      },

      mappings = {
        suggestion = {
          accept = "<C-l>",
          next = "<C-j>",
          prev = "<C-k>",
          dismiss = "<C-e>",
        },
      },
    })

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

    # Avante keymaps (primary AI)
    {
      mode = "n";
      key = "<leader>aa";
      action = "<cmd>AvanteAsk<CR>";
      options = {
        desc = "Avante Ask";
        silent = true;
        noremap = true;
      };
    }
    {
      mode = "n";
      key = "<leader>at";
      action = "<cmd>AvanteToggle<CR>";
      options = {
        desc = "Avante Toggle";
        silent = true;
        noremap = true;
      };
    }
    {
      mode = "n";
      key = "<leader>ar";
      action = "<cmd>AvanteRefresh<CR>";
      options = {
        desc = "Avante Refresh";
        silent = true;
        noremap = true;
      };
    }
    {
      mode = "v";
      key = "<leader>ae";
      action = "<cmd>AvanteEdit<CR>";
      options = {
        desc = "Avante Edit";
        silent = true;
        noremap = true;
      };
    }
    {
      mode = "n";
      key = "<leader>an";
      action = "<cmd>AvanteChatNew<CR>";
      options = {
        desc = "Avante New Chat";
        silent = true;
        noremap = true;
      };
    }

    # Reticle keymap
    {
      mode = "n";
      key = "<leader>tr";
      action.__raw = ''
        function()
          require("reticle").toggle_cursorcross()
        end
      '';
      options = {
        desc = "Toggle Reticle Cross";
        silent = true;
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
