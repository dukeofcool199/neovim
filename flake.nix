{
  description = "Jenkin Schibels Neovim configuration - Nixvim";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";

    nixvim = {
      url = "github:nix-community/nixvim";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    nixpkgs,
    nixvim,
    ...
  }: let
    systems = ["x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin"];
    forAllSystems = nixpkgs.lib.genAttrs systems;
  in {
    packages = forAllSystems (system: let
      pkgs = nixpkgs.legacyPackages.${system};
      nixvim' = nixvim.legacyPackages.${system};
      gitRev =
        if self ? rev
        then self.rev
        else if self ? dirtyRev
        then builtins.substring 0 40 self.dirtyRev
        else "0000000000000000000000000000000000000000";
      nvim = nixvim'.makeNixvimWithModule {
        inherit pkgs;
        module = import ./config;
        extraSpecialArgs = {inherit gitRev;};
      };
    in {
      default = nvim;
      neovim = nvim;
    });
  };
}
