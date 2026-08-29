{pkgs, ...}: let
  sidekick-nvim = pkgs.vimUtils.buildVimPlugin {
    name = "sidekick.nvim";
    src = pkgs.fetchFromGitHub {
      owner = "folke";
      repo = "sidekick.nvim";
      rev = "17447a05f9385e5f8372b61530f6f9329cb82421";
      sha256 = "sha256-scCYymquGaT9/e7nU2kuyiwFutKfAq8pGQQsOWK+7rM=";
    };
    doCheck = false;
  };
in {
  extraPlugins = [sidekick-nvim];

  extraConfigLua = ''
    local sidekick_ok, sidekick = pcall(require, "sidekick")
    if sidekick_ok then
      sidekick.setup({
        nes = {
          enabled = false,
        },
        cli = {
          picker = "telescope",
          win = {
            layout = "left",
            split = {
              width = 50,
            },
          },
          tools = {
            aider = {
              -- aider only offers `/add` for words that match a repo path verbatim,
              -- so drop the `@` prefix and `:` separator the default location format adds
              format = function(text)
                local Text = require("sidekick.text")
                Text.transform(text, function(chunk)
                  return (chunk == "@" or chunk == ":") and "" or chunk
                end, "SidekickLocDelim")
                return Text.to_string(text)
              end,
            },
          },
        },
      })
    end
  '';

  keymaps = [
    {
      mode = ["n" "v"];
      key = "<leader>aa";
      action.__raw = ''
        function()
          require("sidekick.cli").toggle()
        end
      '';
      options = {
        desc = "Sidekick: toggle CLI";
        silent = true;
        noremap = true;
      };
    }
    {
      mode = "n";
      key = "<leader>ac";
      action.__raw = ''
        function()
          require("sidekick.cli").toggle({ name = "claude", focus = true })
        end
      '';
      options = {
        desc = "Sidekick: toggle Claude Code";
        silent = true;
        noremap = true;
      };
    }
    {
      mode = "n";
      key = "<leader>ai";
      action.__raw = ''
        function()
          require("sidekick.cli").toggle({ name = "aider", focus = true })
        end
      '';
      options = {
        desc = "Sidekick: toggle Aider";
        silent = true;
        noremap = true;
      };
    }
    {
      mode = "n";
      key = "<leader>ao";
      action.__raw = ''
        function()
          require("sidekick.cli").toggle({ name = "opencode", focus = true })
        end
      '';
      options = {
        desc = "Sidekick: toggle opencode";
        silent = true;
        noremap = true;
      };
    }
    {
      mode = "n";
      key = "<leader>aP";
      action.__raw = ''
        function()
          require("sidekick.cli").toggle({ name = "pi", focus = true })
        end
      '';
      options = {
        desc = "Sidekick: toggle pi";
        silent = true;
        noremap = true;
      };
    }
    {
      mode = "n";
      key = "<leader>as";
      action.__raw = ''
        function()
          require("sidekick.cli").select()
        end
      '';
      options = {
        desc = "Sidekick: select CLI tool";
        silent = true;
        noremap = true;
      };
    }
    {
      mode = "n";
      key = "<leader>ad";
      action.__raw = ''
        function()
          require("sidekick.cli").close()
        end
      '';
      options = {
        desc = "Sidekick: detach CLI session";
        silent = true;
        noremap = true;
      };
    }
    {
      mode = ["n" "v"];
      key = "<leader>ap";
      action.__raw = ''
        function()
          require("sidekick.cli").prompt()
        end
      '';
      options = {
        desc = "Sidekick: select prompt";
        silent = true;
        noremap = true;
      };
    }
    {
      mode = ["n" "v"];
      key = "<leader>at";
      action.__raw = ''
        function()
          require("sidekick.cli").send({ msg = "{this}" })
        end
      '';
      options = {
        desc = "Sidekick: send this";
        silent = true;
        noremap = true;
      };
    }
    {
      mode = "v";
      key = "<leader>av";
      action.__raw = ''
        function()
          require("sidekick.cli").send({ msg = "{selection}" })
        end
      '';
      options = {
        desc = "Sidekick: send selection";
        silent = true;
        noremap = true;
      };
    }
    {
      mode = "n";
      key = "<leader>af";
      action.__raw = ''
        function()
          require("sidekick.cli").send({ msg = "{file}" })
        end
      '';
      options = {
        desc = "Sidekick: send file";
        silent = true;
        noremap = true;
      };
    }
  ];
}
