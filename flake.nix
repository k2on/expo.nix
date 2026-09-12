{
  description = "Building Expo apps with nix, on top of android.nix";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
    import-tree.url = "github:vic/import-tree";
    android = {
      url = "github:k2on/android.nix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-parts.follows = "flake-parts";
      inputs.import-tree.follows = "import-tree";
    };
  };

  # Dendritic: every file under `modules/` is a flake-parts module. What a
  # consumer wants is `flakeModules.default`, which puts both `expo` and
  # `android` in scope of every `perSystem`.
  outputs = inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } (inputs.import-tree ./modules);
}
