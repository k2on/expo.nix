# The module itself, as a function of android.nix's — so the flake that
# exports it can close it over its own `android` input, and a consumer needs
# no such input. In a file import-tree does not load on its own.
androidModule: {
  # What lets the module system recognise this when a consumer gets it twice,
  # once directly and once through a library built on this one: attribute-set
  # modules are anonymous unless keyed, and two copies of one would be two
  # definitions of `_module.args.expo`.
  key = "expo.nix";
  _file = toString ./_expo.nix;
  imports = [ androidModule ];
  perSystem = { pkgs, android, ... }: {
    _module.args.expo = import ../lib { inherit pkgs android; };
  };
}
