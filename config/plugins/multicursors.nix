{ ... }:
{
  plugins.multicursors = {
    enable = true;
    settings = {
      DEBUG_MODE = false;
      create_commands = true;
      updatetime = 50;
      nowait = true;
      mode_keys = {
        append = "a";
        change = "c";
        extend = "e";
        insert = "i";
      };
      hint_config = {
        float_opts = {
          border = "none";
        };
        position = "bottom";
      };
      generate_hints = {
        normal = true;
        insert = true;
        extend = true;
        config = {
          column_count = null;
          max_hint_length = 25;
        };
      };
    };
  };

  keymaps = [
    {
      mode = "n";
      key = "<leader>ms";
      action = "<cmd>MCstart<cr>";
      options = { desc = "Start multi cursor"; silent = true; };
    }
    {
      mode = "n";
      key = "<leader>mp";
      action = "<cmd>MCpattern<cr>";
      options = { desc = "Multi cursor pattern selection"; silent = true; };
    }
    {
      mode = "n";
      key = "<leader>mv";
      action = "<cmd>MCvisual<cr>";
      options = { desc = "Multi cursor visual"; silent = true; };
    }
    {
      mode = "n";
      key = "<leader>mc";
      action = "<cmd>MCclear<cr>";
      options = { desc = "Clear cursor"; silent = true; };
    }
    {
      mode = "v";
      key = "<leader>c";
      action = "<cmd>MCvisual<cr>";
      options = { desc = "Multi cursor visual"; silent = true; };
    }
  ];
}
