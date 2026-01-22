{ ... }: {
  # Utility plugins
  # neodev is configured in lsp/default.nix as lazydev

  # Icons
  plugins.web-devicons.enable = true;

  # Browser integration
  plugins.firenvim.enable = true;

  # Text manipulation
  plugins.vim-surround.enable = true;
  plugins.comment.enable = true;
  plugins.repeat.enable = true;

  # Editor configuration
  editorconfig.enable = true;

  # Highlighting - delimitMate added via extraPlugins

  # Direnv
  plugins.direnv.enable = true;

  # Nix syntax highlighting
  plugins.nix.enable = true;

  # Typst support
  plugins.typst-vim.enable = true;

  # Markdown
  plugins.markdown-preview.enable = true;

  # Project management with telescope integration
  plugins.project-nvim = {
    enable = true;
    enableTelescope = true;
  };

  # Ledger accounting files
  plugins.ledger.enable = true;

  # Git
  plugins.fugitive.enable = true;

  # FZF environment
  extraConfigLua = ''
    vim.env.FZF_DEFAULT_OPTS = '--layout=reverse'
  '';

  # Git autocommand for starting in insert mode
  autoCmd = [{
    event = [ "FileType" ];
    pattern = [ "gitcommit" "gitrebase" ];
    command = "startinsert | 1";
  }];

  # Keymaps for various functionality
  keymaps = [
    # Toggle highlight
    {
      mode = "n";
      key = "<leader>th";
      action.__raw = "function() vim.o.hlsearch = not vim.o.hlsearch end";
      options = {
        desc = "Toggle Highlight";
        silent = true;
      };
    }

    # Git keymaps
    {
      mode = "n";
      key = "<leader>gw";
      action = "<cmd>Gwrite<cr>";
      options = {
        desc = "Git write";
        silent = true;
      };
    }
    {
      mode = "n";
      key = "<leader>gc";
      action = "<cmd>G commit<cr>";
      options = {
        desc = "Git commit";
        silent = true;
      };
    }
    {
      mode = "n";
      key = "<leader>gp";
      action = "<cmd>Git push<cr>";
      options = {
        desc = "Git push";
        silent = true;
      };
    }

    # Previous buffer
    {
      mode = "n";
      key = "<leader>gg";
      action = "<cmd>e#<cr>";
      options = {
        desc = "Previous Buffer";
        silent = true;
      };
    }

    # Tab management
    {
      mode = "n";
      key = "<leader>te";
      action = "<cmd>tabedit<cr>";
      options = {
        desc = "New Tab";
        silent = true;
      };
    }
    {
      mode = "n";
      key = "<leader>tl";
      action = "<cmd>tabnext<cr>";
      options = {
        desc = "Next Tab";
        silent = true;
      };
    }
    {
      mode = "n";
      key = "<leader>tH";
      action = "<cmd>tabprevious<cr>";
      options = {
        desc = "Previous Tab";
        silent = true;
      };
    }

    # Toggle line wrap
    {
      mode = "n";
      key = "<leader>tw";
      action.__raw = ''
        function()
          vim.o.wrap = not vim.o.wrap
          vim.o.linebreak = vim.o.wrap
        end
      '';
      options = {
        desc = "Toggle Line Wrap";
        silent = true;
      };
    }

    # Quit keymaps
    {
      mode = "n";
      key = "<leader>qQ";
      action = "<cmd>q!<cr>";
      options = {
        desc = "Force Quit";
        silent = true;
      };
    }
    {
      mode = "n";
      key = "<leader>qa";
      action = "<cmd>qa!<cr>";
      options = {
        desc = "Force Quit All";
        silent = true;
      };
    }
    {
      mode = "n";
      key = "<leader>qw";
      action = "<cmd>wa<cr><cmd>q!<cr>";
      options = {
        desc = "Save and Quit";
        silent = true;
      };
    }
    {
      mode = "n";
      key = "<leader>qq";
      action = "<cmd>q<cr>";
      options = {
        desc = "Close buffer";
        silent = true;
      };
    }
  ];
}
