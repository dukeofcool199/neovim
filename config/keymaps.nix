{ ... }:
{
  keymaps = [
    # Exit terminal mode
    {
      mode = "t";
      key = "<C-o>";
      action = "<C-\\><C-n>";
      options = { silent = true; noremap = true; };
    }

    # Window navigation
    {
      mode = "n";
      key = "<C-k>";
      action = ":wincmd k<cr>";
      options = { silent = true; noremap = true; };
    }
    {
      mode = "n";
      key = "<C-j>";
      action = ":wincmd j<cr>";
      options = { silent = true; noremap = true; };
    }
    {
      mode = "n";
      key = "<C-h>";
      action = ":wincmd h<cr>";
      options = { silent = true; noremap = true; };
    }
    {
      mode = "n";
      key = "<C-l>";
      action = ":wincmd l<cr>";
      options = { silent = true; noremap = true; };
    }

    # Quick escape from insert mode
    {
      mode = "i";
      key = "jk";
      action = "<esc>";
      options = { silent = true; noremap = true; };
    }
    {
      mode = "i";
      key = "kj";
      action = "<esc>";
      options = { silent = true; noremap = true; };
    }

    # Remap increment/decrement since C-a/C-x are used by OpenCode
    {
      mode = "n";
      key = "+";
      action = "<C-a>";
      options = { silent = true; noremap = true; desc = "Increment"; };
    }
    {
      mode = "n";
      key = "_";
      action = "<C-x>";
      options = { silent = true; noremap = true; desc = "Decrement"; };
    }

    # LSP restart
    {
      mode = "n";
      key = "<leader>r";
      action = "<cmd>LspRestart<cr>";
      options = { silent = true; noremap = true; desc = "Restart LSP"; };
    }

    # Buffer management
    {
      mode = "n";
      key = "<leader>bd";
      action = "<cmd>BD<cr>";
      options = { silent = true; noremap = true; desc = "Delete Buffer"; };
    }
    {
      mode = "n";
      key = "<leader>bn";
      action = "<cmd>bnext<cr>";
      options = { silent = true; noremap = true; desc = "Next Buffer"; };
    }
    {
      mode = "n";
      key = "<leader>bp";
      action = "<cmd>bprevious<cr>";
      options = { silent = true; noremap = true; desc = "Previous Buffer"; };
    }

    # Split management
    {
      mode = "n";
      key = "<leader>sv";
      action = "<cmd>vsplit<cr>";
      options = { silent = true; noremap = true; desc = "Vertical Split"; };
    }
    {
      mode = "n";
      key = "<leader>sh";
      action = "<cmd>split<cr>";
      options = { silent = true; noremap = true; desc = "Horizontal Split"; };
    }
    {
      mode = "n";
      key = "<leader>ss";
      action = "<cmd>w!<cr>";
      options = { silent = true; noremap = true; desc = "Save"; };
    }

  ];
}
