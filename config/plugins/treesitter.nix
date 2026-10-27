{
  config,
  pkgs,
  ...
}: let
  hujson = pkgs.tree-sitter.buildGrammar {
    language = "hujson";
    version = "unstable";

    src = pkgs.fetchFromGitHub {
      owner = "ggfevans";
      repo = "tree-sitter-hujson";
      rev = "v1.2.0";
      hash = "sha256-E3CDEObObYx74ckSZfTIwRr5PIEObZ0PMrTKfOztz5Q=";
    };
  };
in {
  plugins.treesitter = {
    enable = true;

    indent = {
      enable = true;
      disable = ["haskell"];
    };
    settings = {
      highlight.enable = true;
    };
    grammarPackages = config.plugins.treesitter.package.allGrammars ++ [hujson];
    languageRegister.hujson = "hujson";
  };

  filetype.extension = {
    hujson = "hujson";
    jwcc = "hujson";
  };

  extraFiles."queries/hujson/highlights.scm".source = "${hujson.src}/queries/highlights.scm";

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
