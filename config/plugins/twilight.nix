{ ... }:
{
  plugins.twilight = {
    enable = true;
  };

  keymaps = [
    {
      mode = "n";
      key = "<leader>tT";
      action = "<cmd>Twilight<cr>";
      options = { desc = "Toggle Twilight"; silent = true; };
    }
  ];
}
