{ ... }:
{
  plugins.neogen = {
    enable = true;
  };

  keymaps = [
    {
      mode = "n";
      key = "<leader>nc";
      action = "<cmd>Neogen<cr>";
      options = { desc = "Generate doc comment"; silent = true; };
    }
  ];
}
