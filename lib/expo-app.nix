# An Expo app as two gradle derivations: the layer and the APK that restores it.
{ pkgs, android, nodeModules, stateSrc, prepareLib }:
let
  inherit (pkgs) lib;
in
{
  # Everything Android about an Expo app, from one set of parameters.
  #
  # The APK, in both build types, and the gradle state layer they restore —
  # built with the same attributes, prepared by the same script, so that the
  # tree the layer recorded is the tree the build finds. What differs is only
  # what must: the layer's source has no app code, and the build's `prepare`
  # may add what the layer never saw.
  mkExpoApp =
    { name
      # The tree the APK is built from; `appDir` is the Expo project in it.
    , src
    , appDir ? "."
      # The Expo project directory as a *path*, for the layer's source: the
      # filter has to see the files rather than a derivation, or evaluating
      # it would mean building `src`.
    , appSrc
    , nodeModules
    , gradleDeps
    , sdk
    , gradle
    , jdk ? pkgs.jdk17
    , ndkVersion ? android.defaultNdk
    , aapt2BuildTools ? "36.0.0"
      # Whatever else the build runs, ahead of the standard tools on `PATH`.
    , nativeBuildInputs ? [ ]
      # Anything else both derivations should carry — environment above all.
    , extraAttrs ? { }
      # Shell run in the source root, in both, after `node_modules` and
      # before `expo prebuild`.
    , prepare ? ""
      # …and in the APK builds only: what the layer's source does not have.
      # A native module built by another derivation goes here.
    , buildPrepare ? ""
    , variants ? { debug = "development"; release = "production"; }
    , archs ? [ "arm64-v8a" "x86_64" ]
    , gradleProperties ? null
      # The layer's source: see `mkStateSrc`.
    , stateSrcExclude ? [ ]
    , stateSrcFiles ? { }
      # What the layer builds. Assembling the app rather than naming the
      # libraries, because the list of libraries is one this file must not
      # hold: assembling reaches all of them and the app's own half is cheap.
    , stateTask ? "assembleDebug"
    }:
    let
      projectDir = "${appDir}/android";

      common = {
        inherit sdk gradle jdk ndkVersion aapt2BuildTools nativeBuildInputs
          gradleDeps projectDir extraAttrs;
        # Where the layer's directories are, relative to the Expo project:
        # the generated project, and every library under `node_modules`,
        # which is where React Native's libraries actually build.
        stateRoots = [ "android" "node_modules" ];
        # Not this one. React Native's settings plugin caches the output of
        # `react-native config` — the list of libraries to link — here, and
        # reuses it whenever the lockfiles' hashes match. The layer wrote
        # that list without any module the build adds; the lockfiles are the
        # same files; so every APK built against the layer linked the
        # layer's list. Seven runs of a build without its native engine, 642
        # tasks against the 680 of a build without the layer, and not one
        # task from the missing module in the log. Deleting the cache costs
        # one `react-native config`, about two seconds.
        stateExclude = [ "android/build/generated/autolinking" ];
      };

      prep = extra: prepareLib.prepareScript ({
        inherit appDir nodeModules variants archs;
        before = prepare + extra;
      } // lib.optionalAttrs (gradleProperties != null) { inherit gradleProperties; });

      # The layer's source: the build's name, the project's manifests, and
      # nothing that changes per commit.
      src' = stateSrc.mkStateSrc {
        name = src.name or (builtins.head (builtins.match "[a-z0-9]{32}-(.*)" (baseNameOf src)));
        inherit appDir;
        src = appSrc;
        exclude = stateSrcExclude;
        files = stateSrcFiles;
      };

      gradleState = android.mkGradleState (common // {
        name = "${name}-gradle-state";
        src = src';
        prepare = prep "";
        task = stateTask;
        # The APK's recording, not a second one of the same graph.
        # `fetchDeps` names its derivation after the package, so giving it
        # this package would materialise the same artifacts twice, and only
        # one of the two rooted by whoever roots them.
        mitmCache = apk-debug.mitmCache;
      });

      apk-debug = android.mkGradleBuild (common // {
        name = "${name}-debug-apk";
        inherit src;
        variant = "debug";
        prepare = prep buildPrepare;
        restore = gradleState;
      });

      # The same build, gradle's release type: the JavaScript compiled to
      # Hermes bytecode and bundled into the APK rather than fetched from a
      # dev server, resources crunched, no debuggable flag. The debug build's
      # recording covers it because that recording runs both assembles.
      apk-release = android.mkGradleBuild (common // {
        name = "${name}-release-apk";
        inherit src;
        variant = "release";
        prepare = prep buildPrepare;
        restore = gradleState;
        mitmCache = apk-debug.mitmCache;
      });
    in
    {
      stateSrc = src';
      inherit gradleState apk-debug apk-release;
      apk = apk-debug;
    };
}
