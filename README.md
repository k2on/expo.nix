# expo.nix

Building Expo apps with nix, on top of [android.nix](https://github.com/k2on/android.nix).

What an Expo app adds to a gradle build: `node_modules` as a fixed-output
derivation, `expo prebuild` to get a gradle project at all, `APP_VARIANT` so
a development build and a release build are different apps, and a gradle
state layer whose source is the project's manifests and nothing that changes
per commit — so a `.tsx` edit rebuilds the APK in minutes rather than the
whole of React Native in twenty.

## Using it

```nix
inputs.expo.url = "github:k2on/expo.nix";
inputs.expo.inputs.nixpkgs.follows = "nixpkgs";

{ imports = [ inputs.expo.flakeModules.default ]; }   # brings android.nix's too

perSystem = { expo, android, ... }:
  let
    app = expo.mkExpoApp {
      name = "myapp";
      src = ./.;                  # the tree the APK is built from
      appDir = ".";               # the Expo project inside it
      appSrc = ./.;               # the same, as a path, for the layer's filter
      nodeModules = expo.mkNodeModules {
        name = "myapp-node-modules";
        src = expo.cleanExpoSource ./.;
        hash = { x86_64-linux = "sha256-…"; aarch64-linux = "sha256-…"; };
      };
      gradleDeps = ./gradle-deps.json;
      sdk = android.mkSdk { };
      gradle = android.mkGradle { version = "9.3.1"; hash = "sha256-…"; };
    };
  in
  { packages = { inherit (app) apk apk-debug apk-release gradleState; }; };
```

`inputs.expo.lib.mkExpo pkgs { }` from a flake that is not flake-parts;
`import ./expo.nix { inherit pkgs; }` without flakes, which fetches android.nix
at the revision `flake.lock` pins.

## What `mkExpoApp` returns

| attribute     | what                                                    |
|---------------|---------------------------------------------------------|
| `apk-debug`   | `assembleDebug`, `APP_VARIANT=development`              |
| `apk-release` | `assembleRelease`, `APP_VARIANT=production`. Signed with the template's debug key unless the project says otherwise |
| `apk`         | `apk-debug`                                             |
| `gradleState` | the layer both restore                                  |
| `stateSrc`    | what the layer was built from — read it when the layer rebuilds and should not have |

The Maven recording is shared: `gradleState` and `apk-release` use
`apk-debug.mitmCache`, and `nix run .#apk-debug.mitmCache.updateScript`
regenerates it by running both assembles.

## The layer's source

`stateSrc` is the Expo project *minus* an exclusion list: `src`,
`node_modules`, `android`, `ios`, `.expo`, and whatever `stateSrcExclude`
adds. An exclusion list rather than a list of files, so a new
`babel.config.js` is an input the day it appears. `stateSrcFiles` writes
what a config plugin insists on finding — an `expo-router` app wants a route
to exist, which is never rendered because a debug APK bundles no JavaScript.

Two things about restoring it that `expo.nix` knows and `android.nix` does
not:

- **React Native's autolinking cache is deleted on restore.** The settings
  plugin keeps `react-native config`'s output in
  `android/build/generated/autolinking/` and reuses it while the lockfiles'
  hashes match; the layer wrote it without any module the build adds. Seven
  runs of APKs linked the layer's list and carried no native engine at all.
- **`gradle.properties` gets a newline first.** `expo prebuild` writes it
  without a trailing one and its last line is
  `expo.inlineModules.watchedDirectories=[]`; an appended line lands on the
  end of that and Expo's plugin hands the result to `JSON.parse`. Gradle
  reports only `command 'node' finished with non-zero exit value 1`.

## Layout

```
lib/node-modules.nix   mkNodeModules, cleanExpoSource
lib/state-src.nix      mkStateSrc
lib/prepare.nix        prepareScript — node_modules, APP_VARIANT, prebuild, properties
lib/expo-app.nix       mkExpoApp
modules/               flake-parts wiring; `_expo.nix` is the module a consumer gets
```
