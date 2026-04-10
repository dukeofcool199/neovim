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
          tool = "claude",
        },
      })
    end
  '';

  keymaps = [
    {
      mode = "n";
      key = "<leader>aa";
      action = "<cmd>Sidekick cli toggle<CR>";
      options = {
        desc = "Sidekick CLI Toggle";
        silent = true;
        noremap = true;
      };
    }
    {
      mode = "v";
      key = "<leader>aa";
      action = "<cmd>Sidekick cli toggle<CR>";
      options = {
        desc = "Sidekick CLI Toggle (with selection)";
        silent = true;
        noremap = true;
      };
    }
  ];
}
