{ ... }:
{
  plugins.treesitter = {
    enable = true;

    settings = {
      highlight.enable = true;
      indent.enable = true;
    };
  };

  plugins.treesitter-context = {
    enable = true;
  };

  # Folding configuration (from tree-sitter.lua)
  opts = {
    foldmethod = "expr";
    foldexpr = "nvim_treesitter#foldexpr()";
    foldenable = false;
    foldlevel = 99;
  };
}
