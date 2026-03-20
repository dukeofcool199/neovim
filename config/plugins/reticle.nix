{pkgs, ...}: let
  reticle = pkgs.vimUtils.buildVimPlugin {
    name = "reticle.nvim";
    src = pkgs.fetchFromGitHub {
      owner = "Tummetott";
      repo = "reticle.nvim";
      rev = "66bfa2b1c28fd71bb8ae4e871e0cd9e9c509ea86";
      sha256 = "sha256-lf60+D68Oep0kZ9clfJTuiOkIMhZhgWyvFhf/kSYwVM=";
    };
    doCheck = false;
  };
in {
  extraPlugins = [reticle];

  extraConfigLua = ''
    local reticle_ok, reticle = pcall(require, "reticle")
    if reticle_ok then
      reticle.setup({
        on_startup = {
          cursorline = true,
          cursorcolumn = true,
        },
      })
    end
  '';

  keymaps = [
    {
      mode = "n";
      key = "<leader>tr";
      action.__raw = ''
        function()
          require("reticle").toggle_cursorcross()
        end
      '';
      options = {
        desc = "Toggle Reticle Cross";
        silent = true;
      };
    }
  ];
}
