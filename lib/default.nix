# Everything here, as one attribute set.
#
#     expo = import ./lib { inherit pkgs android; };
#
# `android` is android.nix's library over the same `pkgs`.
{ pkgs, android }:
let
  nodeModules = import ./node-modules.nix { inherit pkgs; };
  stateSrc = import ./state-src.nix { inherit pkgs; };
  prepare = import ./prepare.nix { inherit pkgs; };
  expoApp = import ./expo-app.nix { inherit pkgs android nodeModules stateSrc; prepareLib = prepare; };
in
nodeModules // stateSrc // prepare // expoApp
