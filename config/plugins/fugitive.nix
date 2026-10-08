# vim-fugitive: git commands for plain git repos.
# In jj repos use <leader>j instead; git HEAD is detached there, so :Git push fails.
{...}: {
  plugins.fugitive.enable = true;

  autoCmd = [
    {
      event = ["FileType"];
      pattern = ["gitcommit" "gitrebase"];
      command = "startinsert | 1";
    }
  ];

  keymaps = [
    {
      mode = "n";
      key = "<leader>gs";
      action = "<cmd>Git<cr>";
      options = {
        desc = "Git status";
        silent = true;
      };
    }
    {
      mode = "n";
      key = "<leader>gc";
      action = "<cmd>Git commit<cr>";
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
    {
      mode = "n";
      key = "<leader>gP";
      action = "<cmd>Git pull<cr>";
      options = {
        desc = "Git pull";
        silent = true;
      };
    }
    {
      mode = "n";
      key = "<leader>gw";
      action = "<cmd>Gwrite<cr>";
      options = {
        desc = "Git stage file";
        silent = true;
      };
    }
    {
      mode = "n";
      key = "<leader>gW";
      action = "<cmd>wall | Git add -A<cr>";
      options = {
        desc = "Git stage all";
        silent = true;
      };
    }
    {
      mode = "n";
      key = "<leader>gb";
      action = "<cmd>Git blame<cr>";
      options = {
        desc = "Git blame";
        silent = true;
      };
    }
    {
      mode = "n";
      key = "<leader>gd";
      action = "<cmd>Gvdiffsplit<cr>";
      options = {
        desc = "Git diff file";
        silent = true;
      };
    }
  ];
}
