{...}: let
in {
  plugins.lualine = {
    enable = true;

    settings = {
      options = {
        theme = "auto";
        icons_enabled = true;
        component_separators = "";
        section_separators = {
          left = "";
          right = "";
        };
        disabled_filetypes = {
          winbar = ["dashboard" "NvimTree"];
        };
      };

      extensions = ["quickfix" "nvim-tree" "toggleterm" "fzf"];
    };
  };
}
