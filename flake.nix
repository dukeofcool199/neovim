{
  description = "Jenkin Schibels Neovim configuration - Nixvim";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    nixvim = {
      url = "github:nix-community/nixvim";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, nixvim, ... }:
    let
      systems =
        [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in {
      packages = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          nixvim' = nixvim.legacyPackages.${system};
          config = import ./config { inherit pkgs; };
          nvim = nixvim'.makeNixvimWithModule {
            inherit pkgs;
            module = config;
          };
        in {
          default = nvim;
          neovim = nvim;
        });
    };
}
