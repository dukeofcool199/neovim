# oil-git.nvim: VCS status in oil buffers (filename highlights + eol symbols).
# Git-based, but jj colocated keeps git HEAD at @-, so it shows @'s changes.
{pkgs, ...}: let
  oil-git-nvim = pkgs.vimUtils.buildVimPlugin {
    name = "oil-git.nvim";
    src = pkgs.fetchFromGitHub {
      owner = "malewicz1337";
      repo = "oil-git.nvim";
      rev = "bc25e507061f3e1b4e05f0fcda8c0ac81811d8bc";
      sha256 = "sha256-/QIqYqQQYvZvOn8vV+JSjUjDrsQd5d5I+QKlziz0Lvo=";
    };
    doCheck = false;
  };
in {
  extraPlugins = [oil-git-nvim];

  extraConfigLua = ''
    require("oil-git").setup({})
  '';
}
