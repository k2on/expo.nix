# The library, for a consumer that is not flake-parts:
#
#     expo = inputs.expo.lib.mkExpo pkgs;
#
# which brings its own `android` over the same `pkgs`; pass one to share it.
{ inputs, ... }: {
  flake.lib.mkExpo = pkgs: { android ? inputs.android.lib.mkAndroid pkgs }:
    import ../lib { inherit pkgs android; };
}
