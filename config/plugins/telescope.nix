{ ... }:
{
  plugins.telescope = {
    enable = true;

    settings = {
      defaults = {
        mappings = {
          i = {
            "<C-h>" = "which_key";
          };
        };
      };
    };

    extensions = {
      fzf-native.enable = true;
    };

    keymaps = {
      "<leader>ff" = {
        action = "find_files";
        options.desc = "Find File";
      };
      "<leader>fF" = {
        action = "find_files hidden=true";
        options.desc = "Find File (Hidden)";
      };
      "<leader>fr" = {
        action = "oldfiles";
        options.desc = "Recent File";
      };
      "<leader>fg" = {
        action = "live_grep";
        options.desc = "Grep";
      };
      "<leader>fG" = {
        action = "live_grep hidden=true";
        options.desc = "Grep (Hidden Files)";
      };
      "<leader>fb" = {
        action = "buffers";
        options.desc = "Find Buffer";
      };
      "<leader>fd" = {
        action = "git_status";
        options.desc = "Find Diff Files";
      };
      "<leader>p" = {
        action = "find_files";
        options.desc = "Find File";
      };
      "<C-p>" = {
        action = "find_files";
        options.desc = "Find File";
      };
      "<C-c>" = {
        action = "commands";
        options.desc = "Run Command";
      };
    };
  };

  plugins.web-devicons.enable = true;
}
