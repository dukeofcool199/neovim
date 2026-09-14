# sidekick.nvim -- CLI agents in a terminal split, the whole set under
# <leader>k: claude, aider, opencode, pi, plus sending editor context into
# whichever is running. Avante (<leader>a) is the sidebar; this is the
# terminal. The claude tool follows the `cli` role in config/ai/registry.nix.
{pkgs, ...}: let
  registry = import ../ai/registry.nix;
  claudeModel = registry.roles.cli.model;

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
    -- Seed the environment before any terminal spawns: sidekick snapshots
    -- vim.uv.os_environ() at jobstart, and its env table must hold plain
    -- strings (a function raises E729, and the zellij backend ignores tool
    -- env entirely), so eager export is the only shape that works here.
    pcall(function()
      require("ai.auth").export("opencode-go")
    end)

    local sidekick_ok, sidekick = pcall(require, "sidekick")
    if sidekick_ok then
      sidekick.setup({
        nes = {
          enabled = false,
        },
        cli = {
          picker = "telescope",
          win = {
            layout = "${registry.ui.panel.position}",
            split = {
              width = ${toString registry.ui.panel.width},
            },
          },
          tools = {
            claude = {
              cmd = { "claude", "--model", "${claudeModel}" },
            },
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

      -- Registry -> sidekick. Late-bound per spawn, so this reaches the
      -- next terminal; a running CLI keeps the argv and env it started
      -- with. require("sidekick.config").setup() must not be re-called:
      -- it rebuilds from defaults and would discard this.
      require("ai").on_change(function(name, r)
        if name ~= "cli" or not r then
          return
        end
        local cfg = require("sidekick.config")
        local bin = r.command or "claude"
        local tool = cfg.cli and cfg.cli.tools and cfg.cli.tools[bin]
        if tool and r.model then
          tool.cmd = {bin, "--model", r.model}
        end
      end)
    end
  '';

  keymaps = let
    cli = call: {__raw = "function() require('sidekick.cli').${call} end";};
    map = mode: key: call: desc: {
      inherit mode key;
      action = cli call;
      options = {
        inherit desc;
        silent = true;
        noremap = true;
      };
    };
    nv = ["n" "v"];
  in [
    (map nv "<leader>kk" "toggle()" "Toggle CLI")
    (map "n" "<leader>kc" "toggle({ name = 'claude', focus = true })" "Toggle Claude Code")
    (map "n" "<leader>ki" "toggle({ name = 'aider', focus = true })" "Toggle Aider")
    (map "n" "<leader>ko" "toggle({ name = 'opencode', focus = true })" "Toggle opencode")
    (map "n" "<leader>kP" "toggle({ name = 'pi', focus = true })" "Toggle pi")
    (map "n" "<leader>ks" "select()" "Select CLI tool")
    (map "n" "<leader>kd" "close()" "Detach CLI session")
    (map nv "<leader>kp" "prompt()" "Select prompt")
    (map nv "<leader>kt" "send({ msg = '{this}' })" "Send this")
    (map "v" "<leader>kv" "send({ msg = '{selection}' })" "Send selection")
    (map "n" "<leader>kf" "send({ msg = '{file}' })" "Send file")
    (map "n" "<leader>kq" "send({ msg = '{quickfix}' })" "Send quickfix list")
    (map "n" "<leader>kg" "send({ msg = '{diagnostics}' })" "Send diagnostics")
  ];
}
