{ ... }:
{
  # Define Rainbow highlight groups BEFORE plugins use them
  highlight = {
    RainbowRed.fg = "#E06C75";
    RainbowYellow.fg = "#E5C07B";
    RainbowBlue.fg = "#61AFEF";
    RainbowOrange.fg = "#D19A66";
    RainbowGreen.fg = "#98C379";
    RainbowViolet.fg = "#C678DD";
    RainbowCyan.fg = "#56B6C2";
  };

  plugins.indent-blankline = {
    enable = true;

    settings = {
      indent = {
        highlight = [
          "RainbowRed"
          "RainbowYellow"
          "RainbowBlue"
          "RainbowOrange"
          "RainbowGreen"
          "RainbowViolet"
          "RainbowCyan"
        ];
      };
    };
  };

  plugins.rainbow-delimiters = {
    enable = true;
    settings = {
      highlight = [
        "RainbowRed"
        "RainbowYellow"
        "RainbowBlue"
        "RainbowOrange"
        "RainbowGreen"
        "RainbowViolet"
        "RainbowCyan"
      ];
    };
  };

  opts = {
    list = true;
  };

  extraConfigLua = ''
    vim.opt.listchars:append "space:⋅"
    vim.opt.listchars:append "eol:↴"

    vim.g.indent_blankline_use_treesitter = true

    vim.g.indent_blankline_buftype_exclude = {
      "terminal",
      "nofile",
    }

    vim.g.indent_blankline_filetype_exclude = {
      "help",
      "dashboard",
      "NvimTree",
      "Trouble",
    }

    local hooks = require "ibl.hooks"
    hooks.register(hooks.type.SCOPE_HIGHLIGHT, hooks.builtin.scope_highlight_from_extmark)
  '';
}
