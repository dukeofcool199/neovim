{ pkgs, ... }: {
  imports = [ ./options.nix ./keymaps.nix ./plugins ./lsp ];

  # Package configuration
  viAlias = true;
  vimAlias = true;
  withPython3 = true;
  withRuby = true;
  withNodeJs = true;

  # Extra packages available in PATH
  extraPackages = with pkgs; [
    # Language Servers
    gopls
    rust-analyzer
    lua-language-server
    nixd
    templ
    cue

    # Formatters
    nixfmt
    alejandra
    rustfmt

    # Utility
    ripgrep

    # Lua
    lua5_1

    # Node
    nodejs_24
    nodePackages.tailwindcss
  ];

  # Custom colorscheme
  colorschemes.monokai-pro = { enable = true; };
}
