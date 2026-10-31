# sidekick.nvim -- CLI agents in a floating terminal, the whole set under
# <leader>a: claude, aider, opencode, pi, plus sending editor context into
# whichever is running. The claude tool follows the `cli` role in
# config/ai/registry.nix.
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
    (map nv "<leader>aa" "toggle()" "Toggle CLI")
    (map "n" "<leader>ac" "toggle({ name = 'claude', focus = true })" "Toggle Claude Code")
    (map "n" "<leader>ai" "toggle({ name = 'aider', focus = true })" "Toggle Aider")
    (map "n" "<leader>ao" "toggle({ name = 'opencode', focus = true })" "Toggle opencode")
    (map "n" "<leader>aP" "toggle({ name = 'pi', focus = true })" "Toggle pi")
    (map "n" "<leader>as" "select()" "Select CLI tool")
    (map "n" "<leader>ad" "close()" "Detach CLI session")
    (map nv "<leader>ap" "prompt()" "Select prompt")
    (map nv "<leader>at" "send({ msg = '{this}' })" "Send this")
    (map "v" "<leader>av" "send({ msg = '{selection}' })" "Send selection")
    (map "n" "<leader>af" "send({ msg = '{file}' })" "Send file")
    (map "n" "<leader>aq" "send({ msg = '{quickfix}' })" "Send quickfix list")
    (map "n" "<leader>ag" "send({ msg = '{diagnostics}' })" "Send diagnostics")
  ];
}
