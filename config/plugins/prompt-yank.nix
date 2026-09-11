{pkgs, ...}: let
  prompt-yank = pkgs.vimUtils.buildVimPlugin {
    name = "prompt-yank.nvim";
    src = pkgs.fetchFromGitHub {
      owner = "polacekpavel";
      repo = "prompt-yank.nvim";
      rev = "5d278ca49bbb172b388287c6ae1aca4d466c1b36";
      sha256 = "sha256:18m3pwlla7qwn5zpd5nav4c5falc729kiqrc5xsw49wgrra31c1b";
    };
    doCheck = false;
  };
in {
  extraPlugins = [prompt-yank];

  extraConfigLua = ''
    require("prompt-yank").setup({
      output_style = "markdown",
      register = "+",
    })
  '';
}
