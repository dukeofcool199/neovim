{
  description = "Jenkin Schibels Neovim configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-23.11";

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

      package-namespace = "jenkvim";

      alias.packages.default = "neovim";
    };
}
