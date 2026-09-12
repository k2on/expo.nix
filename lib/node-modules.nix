# An Expo app's JavaScript dependencies, fetched once.
{ pkgs }:
{
  # A fixed-output derivation, because `bun install` needs the network. Built
  # natively rather than under emulation: qemu cannot run bun at all — it
  # wants an address-space layout qemu will not give it, and says so with
  # "Unable to find a guest_base".
  mkNodeModules =
    { name
      # The project, or enough of it: `package.json` and `bun.lock` at least.
      # Filter out `node_modules`, `android` and `ios` — see `cleanExpoSource`.
    , src
      # The output's hash, or one per system. The content really is different
      # per platform: bun resolves the optional dependencies that carry native
      # binaries — `lightningcss-linux-arm64-gnu` against `lightningcss-linux-
      # x64-gnu` — for the machine it installs on, and `--cpu=x64` does not
      # override that because `bun.lock` was written on one platform and
      # `--frozen-lockfile` means the lock wins.
      #
      # Each moves whenever `package.json` or `bun.lock` does, and each can
      # only be computed on the machine it belongs to — so one of them is
      # always being taken on trust from whoever ran the other. When one goes
      # stale, nix prints the right one and it goes here.
    , hash
    }:
    let
      system = pkgs.stdenv.buildPlatform.system;
      outputHash =
        if builtins.isString hash then hash
        else hash.${system} or (throw "${name}: no node_modules hash recorded for ${system}");
    in
    pkgs.stdenv.mkDerivation {
      inherit name src outputHash;
      nativeBuildInputs = [ pkgs.bun pkgs.cacert ];
      buildPhase = ''
        export HOME=$TMPDIR
        bun install --frozen-lockfile --no-progress
      '';
      installPhase = ''
        mkdir -p $out
        cp -r node_modules/. $out/
      '';
      dontFixup = true;
      outputHashMode = "recursive";
      outputHashAlgo = "sha256";
    };

  # An Expo project minus what is generated: what `mkNodeModules` should read.
  cleanExpoSource = src: pkgs.lib.cleanSourceWith {
    inherit src;
    filter = path: _type:
      !(builtins.elem (baseNameOf path) [ "node_modules" "android" "ios" ".expo" ]);
  };
}
