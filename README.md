> Customized Neovim, ready for development out of the box.

## Try Without Installing

You can try this configuration out without committing to installing it on your system by running
the following command.

```nix
nix run github:dukeofcool199/neovim
```

## Install

### Nix Profile

You can install this package imperatively with the following command.

```nix
nix profile install github:dukeofcool199/neovim
```

### Nix Configuration

You can install this package by adding it as an input to your Nix flake.

```nix
{
description = "My system flake";

inputs = {
nixpkgs.url = "github:nixos/nixpkgs/nixos-22.11";
unstable.url = "github:nixos/nixpkgs/nixos-unstable";

# Snowfall is not required, but will make configuration easier for you.
snowfall-lib = {
url = "github:snowfallorg/lib";
inputs.nixpkgs.follows = "nixpkgs";
};

neovim = {
url = "github:dukeofcool199/neovim";
# This flake currently requires changes that are only on the Unstable channel.
inputs.nixpkgs.follows = "nixpkgs";
inputs.unstable.follows = "unstable";
};
};

outputs = inputs:
inputs.snowfall-lib.mkFlake {
inherit inputs;
src = ./.;

overlays = with inputs; [
# Use the overlay provided by this flake.
neovim.overlays.default

# There is also a named overlay, though the output is the same.
neovim.overlays."package/neovim"
];
};
}
```
