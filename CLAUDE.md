# expo.nix

Expo on top of android.nix. `README.md` says what; this says what to keep true.

- **Everything gradle is android.nix's.** `mkExpoApp` is `mkGradleState` and
  `mkGradleBuild` with an Expo-shaped `prepare`, an Expo-shaped layer source
  and the roots and exclusions React Native needs. If a change is about
  gradle, the SDK or the layer mechanism, it goes one repository down.
- **Nothing here may know about Rust or uniffi.** That is `petros-js`, which
  passes its engine in through `buildPrepare` and its exclusions through
  `stateSrcExclude`.
- **`prepare` runs in both derivations and `buildPrepare` in the APK builds
  only.** The layer must not see what the build adds, or a change to it
  invalidates the layer.
- **`flakeModules.default` is an attribute set with a `key`**, because it
  closes over this flake's `android` input so a consumer needs none; the key
  is what deduplicates it when a consumer gets it twice. android.nix's is a
  path and needs no key.
- **The layer's source is named after the build's source** — `src.name`, or
  the store name with its hash stripped — because gradle records absolute
  paths and `/build/<name>/…` has to match.
