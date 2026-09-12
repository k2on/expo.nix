# The non-flake entry point.
#
#     expo = import ./expo.nix { inherit pkgs; };                  # android.nix at the pinned rev
#     expo = import ./expo.nix { inherit pkgs android; };          # …or one you fetched yourself
#
# With no `android` given, android.nix is fetched at the revision this
# repository's `flake.lock` pins, so a non-flake consumer gets the pair that
# was tested together.
{ pkgs ? import <nixpkgs> { }
, android ? let
    locked = (builtins.fromJSON (builtins.readFile ./flake.lock)).nodes.android.locked;
    src = builtins.fetchGit {
      url = "https://github.com/${locked.owner}/${locked.repo}";
      inherit (locked) rev;
      allRefs = true;
    };
  in
  import src { inherit pkgs; }
}:
import ./lib { inherit pkgs android; }
