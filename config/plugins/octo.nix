{ ... }:
{
  plugins.octo = {
    enable = true;

    settings = {
      picker = "telescope";
      default_remote = ["upstream" "origin"];
      timeout = 10000;
      use_local_fs = false;
      snippet_context_lines = 6;
      enable_builtin = true;

      suppress_missing_scope = {
        projects_v2 = true;
      };

      ui = {
        use_signcolumn = true;
        use_signstatus = true;
      };
    };
  };

  keymaps = [
    # Start/Resume review
    { mode = "n"; key = "<leader>ors"; action = "<cmd>Octo review start<CR>"; options = { desc = "Start Review"; silent = true; }; }
    { mode = "n"; key = "<leader>orr"; action = "<cmd>Octo review resume<CR>"; options = { desc = "Resume Review"; silent = true; }; }

    # Submit review
    { mode = "n"; key = "<leader>osa"; action = "<cmd>Octo review submit approve<CR>"; options = { desc = "Approve"; silent = true; }; }
    { mode = "n"; key = "<leader>osc"; action = "<cmd>Octo review submit comment<CR>"; options = { desc = "Comment Only"; silent = true; }; }
    { mode = "n"; key = "<leader>osr"; action = "<cmd>Octo review submit request_changes<CR>"; options = { desc = "Request Changes"; silent = true; }; }

    # Discard
    { mode = "n"; key = "<leader>ord"; action = "<cmd>Octo review discard<CR>"; options = { desc = "Discard Review"; silent = true; }; }
  ];

  extraConfigLua = ''
    vim.treesitter.language.register('markdown', 'octo')
  '';
}
