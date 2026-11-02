# sidekick.nvim -- CLI agents in a floating terminal, the whole set under
# <leader>a: claude, aider, opencode, pi, plus sending editor context into
# whichever is running.
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
    -- One key in, same key out. Acts on the most recently focused terminal
    -- rather than asking sidekick to resolve a session, so several running
    -- agents never raise a picker on the fast path; with none running it
    -- starts claude.
    function _G.sidekick_overlay()
      local terminals = require("sidekick.cli.terminal").sessions()
      table.sort(terminals, function(a, b)
        return a.atime > b.atime
      end)
      local term = terminals[1]
      if not term then
        return require("sidekick.cli").toggle({ name = "claude", focus = true })
      end
      if term:is_focused() then
        term:hide()
      else
        term:focus()
      end
    end

    require("sidekick").setup({
      nes = { enabled = false },
      cli = {
        win = {
          layout = "float",
          float = { width = 0.85, height = 0.85 },
          keys = {
            -- Buffer-local, so <c-g> is only stolen from the agent
            -- terminals and every other terminal keeps it.
            overlay = { "<c-g>", "hide", mode = "nt", desc = "hide the overlay" },
          },
        },
      },
    })
  '';

  keymaps = let
    cli = call: {__raw = "function() require('sidekick.cli').${call} end";};
    keymapper = mode: key: call: desc: {
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
    {
      mode = ["n" "i" "v"];
      key = "<C-g>";
      action = {__raw = "function() _G.sidekick_overlay() end";};
      options = {
        desc = "Toggle agent overlay";
        silent = true;
        noremap = true;
      };
    }
    (keymapper nv "<leader>aa" "toggle()" "Toggle CLI")
    (keymapper "n" "<leader>ac" "toggle({ name = 'claude', focus = true })" "Toggle Claude Code")
    (keymapper "n" "<leader>ai" "toggle({ name = 'aider', focus = true })" "Toggle Aider")
    (keymapper "n" "<leader>ao" "toggle({ name = 'opencode', focus = true })" "Toggle opencode")
    (keymapper "n" "<leader>aP" "toggle({ name = 'pi', focus = true })" "Toggle pi")
    (keymapper "n" "<leader>as" "select()" "Select CLI tool")
    (keymapper "n" "<leader>ad" "close()" "Detach CLI session")
    (keymapper nv "<leader>ap" "prompt()" "Select prompt")
    (keymapper nv "<leader>at" "send({ msg = '{this}' })" "Send this")
    (keymapper "v" "<leader>av" "send({ msg = '{selection}' })" "Send selection")
    (keymapper "n" "<leader>af" "send({ msg = '{file}' })" "Send file")
    (keymapper "n" "<leader>aq" "send({ msg = '{quickfix}' })" "Send quickfix list")
    (keymapper "n" "<leader>ag" "send({ msg = '{diagnostics}' })" "Send diagnostics")
  ];
}
