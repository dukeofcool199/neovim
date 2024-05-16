{ nixd, ... }:

final: prev: {
  nixd = nixd.packages.${prev.system}.nixd;
}

