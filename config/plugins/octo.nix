{ ... }:
{
  plugins.octo = {
    enable = true;

    settings = {
      picker = "telescope";
      default_remote = ["upstream" "origin"];
      timeout = 10000;
      use_local_fs = true;
      snippet_context_lines = 6;
      enable_builtin = true;
    };
  };

  keymaps = [
    # PR List/Search/Open
    { mode = "n"; key = "<leader>ol"; action = "<cmd>Octo pr list<CR>"; options = { desc = "List PRs"; silent = true; }; }
    { mode = "n"; key = "<leader>os"; action = "<cmd>Octo pr search<CR>"; options = { desc = "Search PRs"; silent = true; }; }
    { mode = "n"; key = "<leader>oo"; action = "<cmd>Octo pr<CR>"; options = { desc = "Open PR by number"; silent = true; }; }
    { mode = "n"; key = "<leader>oc"; action = "<cmd>Octo pr create<CR>"; options = { desc = "Create PR"; silent = true; }; }

    # PR Actions
    { mode = "n"; key = "<leader>op"; action = "<cmd>Octo pr checkout<CR>"; options = { desc = "Checkout PR"; silent = true; }; }
    { mode = "n"; key = "<leader>ou"; action = "<cmd>Octo pr url<CR>"; options = { desc = "Copy PR URL"; silent = true; }; }
    { mode = "n"; key = "<leader>ob"; action = "<cmd>Octo pr browser<CR>"; options = { desc = "Open in Browser"; silent = true; }; }

    # Review Submission
    { mode = "n"; key = "<leader>ors"; action = "<cmd>Octo review start<CR>"; options = { desc = "Start Review"; silent = true; }; }
    { mode = "n"; key = "<leader>ora"; action = "<cmd>Octo review submit approve<CR>"; options = { desc = "Approve"; silent = true; }; }
    { mode = "n"; key = "<leader>orc"; action = "<cmd>Octo review submit comment<CR>"; options = { desc = "Comment Only"; silent = true; }; }
    { mode = "n"; key = "<leader>orr"; action = "<cmd>Octo review submit request_changes<CR>"; options = { desc = "Request Changes"; silent = true; }; }
    { mode = "n"; key = "<leader>ord"; action = "<cmd>Octo review discard<CR>"; options = { desc = "Discard Review"; silent = true; }; }
  ];

  extraConfigLua = ''
    vim.treesitter.language.register('markdown', 'octo')
  '';
}
