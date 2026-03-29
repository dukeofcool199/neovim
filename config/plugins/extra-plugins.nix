{pkgs, ...}: let
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

  prr = pkgs.vimUtils.buildVimPlugin {
    name = "prr";
    src = pkgs.fetchFromGitHub {
      owner = "danobi";
      repo = "prr";
      rev = "master";
      sha256 = "sha256-duoC3TMgW+h5OrRCbqYPppMtnQBfS9R7ZpHQySgPRv4=";
    };
    postPatch = ''
      mv vim/* .
      rmdir vim
    '';
  };
in {
  extraPlugins = with pkgs.vimPlugins; [
    # Utility
    vim-bufkill

    # Custom plugins (no config needed)
    spongebob
    prr

    # Telescope extensions
    telescope-symbols-nvim

    # LSP utilities
    lsp-colors-nvim
    nvim-jdtls
    neoformat

    # Writing
    vim-pencil

    # Colorschemes
    monokai-pro-nvim
    awesome-vim-colorschemes
    catppuccin-nvim
    tokyonight-nvim
    kanagawa-nvim

    # Markdown
    vim-markdown
    vim-markdown-toc

    # Language specific
    haskell-vim
    vim-astro
    vim-prisma
    vim-vue-plugin
    vim-svelte
  ];
}
