{ ... }:
{
  plugins.treesitter = {
    enable = true;

    settings = {
      highlight.enable = true;
      indent = {
        enable = true;
        disable = ["haskell"];
      };
    };
  };

  # Folding configuration (from tree-sitter.lua)
  opts = {
    foldmethod = "expr";
    foldexpr = "nvim_treesitter#foldexpr()";
    foldenable = false;
    foldlevel = 99;
  };

  # Force haskell-vim's GetHaskellIndent() after treesitter's FileType handler
  extraConfigLua = ''
    vim.api.nvim_create_autocmd("FileType", {
      pattern = { "haskell", "lhaskell" },
      callback = function(args)
        vim.bo[args.buf].indentexpr = "GetHaskellIndent()"
      end,
    })
  '';
}
