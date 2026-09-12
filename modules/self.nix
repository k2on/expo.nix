# This flake uses its own module, the way a consumer would.
{ inputs, ... }: {
  imports = [ (import ./_expo.nix inputs.android.flakeModules.default) ];
}
