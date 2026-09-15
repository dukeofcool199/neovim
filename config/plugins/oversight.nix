# oversight.nvim -- review the uncommitted working copy the way you'd review a
# PR: dual-pane diff, line and file comments, reviewed marks, markdown export
# (`y` in the file list). Built for reading what an agent just wrote, and it
# speaks jj natively. Lives under <leader>v.
{pkgs, ...}: let
  oversight-nvim = pkgs.vimUtils.buildVimPlugin {
    name = "oversight.nvim";
    src = pkgs.fetchFromGitHub {
      owner = "krisajenkins";
      repo = "oversight.nvim";
      rev = "f63a359e6faebfc1ca3440c0d898fd5122b6f420";
      sha256 = "sha256-pz3uweBUfDlyDDMHDVdfOE4ISYD83SvUiZNQdQi7XRE=";
    };
    doCheck = false;
  };
in {
  extraPlugins = [oversight-nvim pkgs.vimPlugins.plenary-nvim];

  extraConfigLua = ''
    local oversight_ok, oversight = pcall(require, "oversight")
    if oversight_ok then
      oversight.setup({
        watch = true,
      })
    end
  '';

  keymaps = let
    map = key: call: desc: {
      mode = "n";
      inherit key;
      action = {__raw = "function() require('oversight').${call} end";};
      options = {
        inherit desc;
        silent = true;
        noremap = true;
      };
    };
  in [
    (map "<leader>vv" "open_review()" "Review changes")
    (map "<leader>vb" "open_browse()" "Browse codebase")
    (map "<leader>vq" "close()" "Close review")
  ];
}
