{ pkgs, ... }:

with pkgs; with nodePackages; [
  # Grammar
  tree-sitter

  # Language Servers
  sqls
  gopls
  pyright
  rust-analyzer
  lua-language-server
  svelte-language-server
  volar
  templ

  # Language Server Dependencies
  nodePackages.pyright
  nodePackages.tailwindcss

  # Formatters
  nixfmt
  rustfmt
  nodePackages.prettier

  # Utility
  ripgrep

  # Documentation
  manix


  # Lua
  lua5_1

  # Node
  nodejs_20

  # Misc
  fortune

  #plantuml
  plantuml
  plantuml-c4

  #graphics
  graphviz
  imv
]
