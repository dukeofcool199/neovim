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

  spongebob = pkgs.vimUtils.buildVimPlugin {
    name = "sPoNGe-BoB.NvIm";
    src = pkgs.fetchFromGitHub {
      owner = "tjdevries";
      repo = "sPoNGe-BoB.NvIm";
      rev = "master";
      sha256 = "sha256-xR0JOsU4GYrYdpVzEFdnL5RmPu+GnxtDsTnc+jk54P4=";
    };
    doCheck = false;
  };

  strudel = pkgs.vimUtils.buildVimPlugin {
    name = "strudel.nvim";
    version = "main";

    src = pkgs.buildNpmPackage rec {
      name = "strudel.nvim";
      PUPPETEER_SKIP_DOWNLOAD = true;
      src = pkgs.fetchFromGitHub {
        owner = "gruvw";
        repo = "strudel.nvim";
        rev = "9ad3634c7c302f16db889a55c2ff13e66f56ded2";
        hash = "sha256-SSD76hTVKZmCBT5sfji/fC8MExO2sZBumHM+rPIF4vQ=";
      };
      buildPhase = "echo 'nuttin'";
      npmDeps = pkgs.importNpmLock { npmRoot = src; };
      npmConfigHook = pkgs.importNpmLock.npmConfigHook;
      buildInputs = [ pkgs.sedutil ];
      postPatch = ''
        sed -i '286a\
                  executablePath: "${pkgs.chromium}/bin/chromium",' ./js/launch.js
      '';
      installPhase = "mkdir $out; cp -r ./* $out";
    };
    doCheck = false;
  };

  prr = pkgs.vimUtils.buildVimPlugin {
    name = "prr";
    src = fetchFromGitHub {
      owner = "danobi";
      repo = "prr";
      rev = "master";
      sha256 = "sha256-duoC3TMgW+h5OrRCbqYPppMtnQBfS9R7ZpHQySgPRv4=";
    };
    postPatch = ''
      mv vim/* .  # Move the vim directory's contents to the root
      rmdir vim
    '';
  };

in with vimPlugins; [
  # Icons
  nvim-web-devicons

  firenvim

  # Syntax
  vim-nix
  nvim-treesitter.withAllGrammars
  nvim-treesitter-context

  # Utility
  plenary-nvim
  vim-bufkill
  neodev-nvim
  dressing-nvim

  multicursors-nvim

  prettier-nvim

  spongebob

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

  strudel

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

  prr

  harpoon2

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
  obsidian-nvim

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
