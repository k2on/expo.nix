# Does the library evaluate? An Expo app's derivations are only as cheap as
# their evaluation, and this is the part of it that can be checked without an
# app: the SDK, the gradle it would use, and that every function is reachable.
{
  perSystem = { pkgs, expo, android, ... }: {
    packages = {
      android-sdk = android.mkSdk { };
      ndk-check = android.ndkCheck { sdk = android.mkSdk { }; };
    };
    checks.lib-evaluates = pkgs.runCommand "expo-nix-lib-evaluates"
      {
        names = builtins.concatStringsSep " " (builtins.attrNames expo);
      } ''
      echo "$names" > $out
    '';
  };
}
