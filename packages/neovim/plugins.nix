{ lib, pkgs, vimPlugins, fetchFromGitHub, tree-sitter, callPackage, ... }:

let
  prettier-nvim = pkgs.vimUtils.buildVimPlugin {
    name = "prettier.nvim";
    src = pkgs.fetchFromGitHub {
      owner = "MunifTanjim";
      repo = "prettier.nvim";
      rev = "main";
      sha256 = "sha256-4xq+caprcQQotvBXnWWSsMwVB2hc5uyjrhT1dPBffXI=";
    };
    doCheck = false;
  };

in with vimPlugins; [
  # Icons
  nvim-web-devicons

  # Syntax
  vim-nix
  nvim-treesitter.withAllGrammars
  nvim-treesitter-context

  # Utility
  plenary-nvim
  vim-bufkill
  neodev-nvim
  dressing-nvim

  prettier-nvim

  # Telescope
  telescope-nvim
  telescope-symbols-nvim
  telescope-project-nvim

  # Language Server
  nvim-lspconfig
  null-ls-nvim
  lsp-colors-nvim
  nvim-jdtls
  trouble-nvim
  neoformat

  # Autocomplete
  nvim-cmp
  cmp-nvim-lsp

  # Snippets
  luasnip
  cmp_luasnip

  # Direnv
  direnv-vim

  # Text Manipulation
  vim-repeat
  vim-surround
  vim-commentary

  # writing
  vim-pencil

  # Movement
  hop-nvim
  neoscroll-nvim

  # Editor Configuration
  editorconfig-nvim

  # Highlighting & View Augmentation
  # vim-illuminate
  todo-comments-nvim
  delimitMate
  twilight-nvim

  # Theme
  monokai-pro-nvim
  awesome-vim-colorschemes

  # Status Line & Buffer Line
  lualine-nvim
  lualine-lsp-progress
  bufferline-nvim
  nvim-navic

  # Termianl
  toggleterm-nvim

  # Git
  # gitsigns-nvim
  vim-fugitive
  # vim-gitgutter
  # git-messenger-vim

  # Which Key
  which-key-nvim

  oil-nvim

  # Markdown
  markdown-preview-nvim
  vim-markdown
  vim-markdown-toc
  typst-vim

  #documenting
  neogen

  # Astro
  vim-astro

  # Prisma
  vim-prisma

  # Bookmarks
  vim-bookmarks
  telescope-vim-bookmarks-nvim

  # Line Indentation
  indent-blankline-nvim

  rainbow-delimiters-nvim

  #vuejs
  vim-vue-plugin

  #zen mode
  zen-mode-nvim

  #ledger
  vim-ledger

  #svelte
  vim-svelte
  nvim-treesitter-parsers.svelte

]
