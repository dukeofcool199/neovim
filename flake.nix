{
  description = "Jenkin Schibels Neovim configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    nixd.url = "github:nix-community/nixd";

    snowfall-lib = {
      url = "github:snowfallorg/lib";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs:
    inputs.snowfall-lib.mkFlake {
      inherit inputs;

      src = ./.;

      channels-config.allowUnfree = true;

      package-namespace = "neovim";

      alias.packages.default = "neovim";
    };
}
