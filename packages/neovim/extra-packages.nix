{ pkgs, ... }:

with pkgs;
with nodePackages; [

  # Language Servers
  gopls
  rust-analyzer
  lua-language-server
  svelte-language-server
  nixd
  alejandra
  templ

  nodePackages.tailwindcss

  # Formatters
  nixfmt
  rustfmt

  # Utility
  ripgrep

  # Lua
  lua5_1

  # Node
  nodejs_22
]
