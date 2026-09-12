# The flake-parts module a consumer imports.
#
#     imports = [ inputs.expo.flakeModules.default ];
#     perSystem = { expo, android, ... }: { … };
#
# It imports android.nix's module — *this* flake's `android` input, closed
# over here, so a consumer needs no `android` input of its own — and adds
# `expo` beside it.
{ inputs, ... }: {
  flake.flakeModules.default = import ./_expo.nix inputs.android.flakeModules.default;
}
