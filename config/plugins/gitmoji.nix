{pkgs, ...}: let
  gitmoji-telescope = pkgs.vimUtils.buildVimPlugin rec {
    name = "telescope-gitmoji.nvim";
    src = pkgs.fetchFromGitHub {
      owner = "olacin";
      repo = name;
      rev = "1f7b5c7c6dfcce236638f82b3c19a7f1ecf77a8f";
      sha256 = "sha256-8ciPyFdpiLdLmS5LO/IBRMkhezU1WKGpk8w2LMeHdHQ=";
    };
  };
in {
  extraPlugins = [gitmoji-telescope];

  extraConfigLua = ''
    local telescope_ok, telescope = pcall(require, "telescope")
    if telescope_ok then
      pcall(telescope.load_extension, "gitmoji")
    end
  '';

  keymaps = [
    {
      mode = "n";
      key = "<leader>fe";
      action.__raw = ''
        function()
          local telescope = require("telescope")
          if telescope.extensions.gitmoji then
            telescope.extensions.gitmoji.gitmoji()
          end
        end
      '';
      options = {
        desc = "Find Gitmojis";
        silent = true;
      };
    }
  ];
}
