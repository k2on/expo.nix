# What the gradle state layer is built from: the Expo project's manifests and
# nothing that changes per commit.
{ pkgs }:
let
  inherit (pkgs) lib;
in
{
  # The layer's source, laid out the way the build's is.
  #
  # An exclusion list rather than a list of files, so a new config file — a
  # `babel.config.js`, a `react-native.config.js` — is an input the day it
  # appears, instead of the day someone remembers to name it here. The cost
  # of a forgotten exclusion is one extra layer build; the cost of a forgotten
  # inclusion was a layer that quietly stopped matching the build it was
  # meant to serve.
  #
  # Written as `${src}/…` over the whole repository it would take the entire
  # tree as an input and every commit would rebuild the layer. The Expo
  # project's directory is a path of its own and moves only when it does.
  mkStateSrc =
    {
      # The build's source unpacks to this name, and the layer's has to match:
      # gradle records absolute paths, and `/build/<name>/…` must be the same
      # in both.
      name
      # The Expo project directory, as a path.
    , src
      # Where it sits inside the build's tree.
    , appDir ? "."
      # What to leave out, beyond the generated directories and `src`. The
      # app's own screens change on every commit; the engine's module belongs
      # to another derivation; prose is prose.
    , exclude ? [ ]
      # Files to write into the result, relative to the project — for what a
      # config plugin insists on finding and the layer must not depend on.
      # An `expo-router` app wants a route to exist: never rendered, since a
      # debug APK bundles no JavaScript at all, so what is in it does not
      # matter, only that the directory is not missing.
    , files ? { }
    }:
    let
      config = lib.cleanSourceWith {
        name = "${name}-expo-config";
        inherit src;
        filter = path: _type:
          let rel = lib.removePrefix (toString src + "/") (toString path);
          in !(builtins.elem rel ([ "src" "node_modules" "android" "ios" ".expo" ] ++ exclude));
      };
    in
    pkgs.runCommand name { } ''
      mkdir -p $out/${lib.escapeShellArg appDir}
      cp -a ${config}/. $out/${lib.escapeShellArg appDir}/
      chmod -R u+w $out
      ${lib.concatStringsSep "\n" (lib.mapAttrsToList (path: content: ''
        mkdir -p "$(dirname $out/${lib.escapeShellArg "${appDir}/${path}"})"
        cp ${pkgs.writeText (baseNameOf path) content} $out/${lib.escapeShellArg "${appDir}/${path}"}
      '') files)}
    '';
}
