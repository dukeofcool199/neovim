{ pkgs, ... }:
{
  imports = [
    ./treesitter.nix
    ./telescope.nix
    ./lualine.nix
    ./bufferline.nix
    ./cmp.nix
    ./oil.nix
    ./trouble.nix
    ./hop.nix
    ./harpoon.nix
    ./gitsigns.nix
    ./which-key.nix
    ./toggleterm.nix
    ./indent-blankline.nix
    ./todo-comments.nix
    ./zen-mode.nix
    ./twilight.nix
    ./neogen.nix
    ./snacks.nix
    ./conform.nix
    ./multicursors.nix
    ./misc.nix
    ./extra-plugins.nix
  ];
}
