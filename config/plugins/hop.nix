{ ... }:
{
  plugins.hop = {
    enable = true;
  };

  keymaps = [
    {
      mode = "n";
      key = "<leader><leader>a";
      action = "<cmd>HopAnywhere<cr>";
      options = { desc = "Hop Anywhere"; silent = true; };
    }
    {
      mode = "n";
      key = "<leader><leader>c";
      action = "<cmd>HopChar1<cr>";
      options = { desc = "Hop To Character"; silent = true; };
    }
    {
      mode = "n";
      key = "<leader><leader>C";
      action = "<cmd>HopChar2<cr>";
      options = { desc = "Hop To Characters"; silent = true; };
    }
    {
      mode = "n";
      key = "<leader><leader>l";
      action = "<cmd>HopLineStart<cr>";
      options = { desc = "Hop To Line Start"; silent = true; };
    }
    {
      mode = "n";
      key = "<leader><leader>L";
      action = "<cmd>HopLine<cr>";
      options = { desc = "Hop To Line"; silent = true; };
    }
    {
      mode = "n";
      key = "<leader><leader>v";
      action = "<cmd>HopVertical<cr>";
      options = { desc = "Hop Vertically"; silent = true; };
    }
    {
      mode = "n";
      key = "<leader><leader>p";
      action = "<cmd>HopPattern<cr>";
      options = { desc = "Hop To Pattern"; silent = true; };
    }
    {
      mode = "n";
      key = "<leader><leader>b";
      action = "<cmd>HopWordBC<cr>";
      options = { desc = "Hop To Previous Word"; silent = true; };
    }
    {
      mode = "n";
      key = "<leader><leader>w";
      action = "<cmd>HopWordAC<cr>";
      options = { desc = "Hop To Next Word"; silent = true; };
    }
    {
      mode = "n";
      key = "<leader><leader>W";
      action = "<cmd>HopWord<cr>";
      options = { desc = "Hop To Word"; silent = true; };
    }
  ];
}
