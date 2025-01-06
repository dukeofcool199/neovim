{ channels, ... }:

final: prev:
let
  node-packages = import ./create-node-packages.nix {
    inherit (prev) system;
    pkgs = prev;
    nodejs = prev.nodejs-18_x;
  };
  tailwindcss-language-server = node-packages."@tailwindcss/language-server";
  astrojs-language-server = node-packages."@astrojs/language-server";
  vue-typescript-plugin = node-packages."@vue/typescript-plugin";
in {
  nodePackages = prev.nodePackages // {
    inherit tailwindcss-language-server vue-typescript-plugin
      astrojs-language-server;
  };
}
