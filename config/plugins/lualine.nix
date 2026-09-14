{...}: let
  registry = import ../ai/registry.nix;
  aiRoles = ["edit" "agent" "cli"];
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

      sections = {
        lualine_a = [
          {
            __unkeyed-1 = "mode";
            separator = {
              left = "";
              right = "";
            };
            right_padding = 2;
          }
        ];
        lualine_b = [
          {
            __unkeyed-1 = "filename";
            file_status = true;
            path = 1;
            shorting_target = 25;
            symbols = {
              modified = "[+]";
              readonly = "[-]";
              unnamed = "[No Name]";
              newfile = "[New]";
            };
          }
          "branch"
        ];
        lualine_c = [
          "fileformat"
          "diagnostics"
          "lsp_progress"
        ];
        lualine_x =
          [
            {
              __unkeyed-1.__raw = ''
                function()
                  if _G.scripture_lualine then
                    return _G.scripture_lualine()
                  end
                  return ""
                end
              '';
              color = {fg = "#d4a959";};
            }
            # One component per AI role: tool, provider, model, and a spinner on
            # whichever is running. Generated from the registry so a new role
            # shows up here automatically.
          ]
          ++ (map (r: {
              __unkeyed-1.__raw = "function() return _G.ai_lualine_role('${r}') end";
              cond.__raw = "function() return _G.ai_lualine_show('${r}') end";
              color.__raw = "function() return _G.ai_lualine_color('${r}') end";
            })
            aiRoles)
          ++ [
          ];
        lualine_y = ["filetype" "progress"];
        lualine_z = [
          {
            __unkeyed-1 = "location";
            separator = {
              left = "";
              right = "";
            };
            left_padding = 2;
          }
        ];
      };

      inactive_sections = {
        lualine_a = [
          {
            __unkeyed-1 = "mode";
            separator = {
              left = "";
              right = "";
            };
            right_padding = 2;
          }
        ];
        lualine_b = [
          {
            __unkeyed-1 = "filename";
            file_status = true;
            path = 1;
            shorting_target = 25;
            symbols = {
              modified = "[+]";
              readonly = "[-]";
              unnamed = "[No Name]";
              newfile = "[New]";
            };
          }
          "branch"
        ];
        lualine_c = ["fileformat" "diagnostics" "lsp_progress"];
        lualine_x = [];
        lualine_y = ["filetype" "progress"];
        lualine_z = [
          {
            __unkeyed-1 = "location";
            separator = {
              left = "";
              right = "";
            };
            left_padding = 2;
          }
        ];
      };

      tabline = {};

      extensions = ["quickfix" "nvim-tree" "toggleterm" "fzf"];
    };
  };

  # nvim-navic for winbar breadcrumbs
  plugins.navic = {
    enable = true;
    settings = {
      icons = {
        File = " ";
        Module = " ";
        Namespace = " ";
        Package = " ";
        Class = " ";
        Method = " ";
        Property = " ";
        Field = " ";
        Constructor = " ";
        Enum = "練";
        Interface = "練";
        Function = " ";
        Variable = " ";
        Constant = " ";
        String = " ";
        Number = " ";
        Boolean = "◩ ";
        Array = " ";
        Object = " ";
        Key = " ";
        Null = "ﳠ ";
        EnumMember = " ";
        Struct = " ";
        Event = " ";
        Operator = " ";
        TypeParameter = " ";
      };
      highlight = false;
      separator = "  ";
      depth_limit = 0;
      depth_limit_indicator = "..";
      safe_output = true;
      lsp.auto_attach = true;
    };
  };

  # lualine-lsp-progress added via extraPlugins
}
