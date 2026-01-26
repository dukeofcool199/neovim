{ ... }:
{
  plugins.zen-mode = {
    enable = true;
    settings = {
      plugins = {
        twilight = {
          enabled = false;
        };
      };
    };
  };

  keymaps = [
    {
      mode = "n";
      key = "<leader>zz";
      action = "<cmd>ZenMode<cr>";
      options = { desc = "Toggle Zen Mode"; silent = true; };
    }
  ];
}
