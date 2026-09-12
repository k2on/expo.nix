# From an Expo project to a gradle project: `expo prebuild`, and what has to
# be true around it.
{ pkgs }:
let
  inherit (pkgs) lib;
in
{
  # A shell fragment for `mkGradleBuild`'s `prepare`: run in the source root,
  # leaves the shell there, and leaves `${appDir}/android` ready for gradle.
  prepareScript =
    { appDir ? "."
    , nodeModules
      # Which app this is, per gradle build type. `APP_VARIANT` is the
      # convention an `app.config.ts` reads to decide its package name, its
      # display name and its icon, so that a development build and a release
      # build are different apps and can be installed side by side. `variant`
      # is the derivation's attribute; a state layer has none and gets the
      # development identity, which is the one it is restored into.
    , variants ? { debug = "development"; release = "production"; }
      # The ABIs gradle compiles C++ for, which the template sets to all four.
      # Measured: the first ABI costs about 5m50s of CMake and each one after
      # it about 85s, so an ABI nothing will run is three minutes of nothing.
    , archs ? [ "arm64-v8a" "x86_64" ]
      # Appended to `gradle.properties`. A properties file keeps the last
      # value for a key, so these replace the template's — including its
      # `-Xmx2048m` and no parallelism, which is a laptop's answer where a
      # runner has four cores and 16GB, and the Android build guide's own
      # advice is a bigger heap and the parallel collector when GC is a
      # visible share of the build.
    , gradleProperties ? [
        "org.gradle.jvmargs=-Xmx6g -XX:MaxMetaspaceSize=1g -XX:+UseParallelGC"
        "org.gradle.parallel=true"
        "org.gradle.caching=true"
      ]
      # Run in the source root after `node_modules` is in place and before
      # `expo prebuild`: for whatever the project needs generated first.
    , before ? ""
    }:
    let
      cases = lib.concatStringsSep "\n" (lib.mapAttrsToList
        (variant: app: "  ${variant}) export APP_VARIANT=${lib.escapeShellArg app} ;;")
        variants);
    in
    ''
      echo "--- node_modules"
      # A writable copy rather than a symlink into the store. `expo prebuild`,
      # gradle and Metro all write into `node_modules`, and a store path
      # refuses.
      cp -a ${nodeModules} ${appDir}/node_modules
      chmod -R u+w ${appDir}/node_modules

      # `#!/usr/bin/env node` is not a thing inside a sandbox, and the `expo`
      # shim starts that way — as does every other shim npm writes. Under an
      # unsandboxed build they were quietly handed the machine's
      # `/usr/bin/env`, which is a dependency on the host filesystem that
      # nobody notices until a machine is missing it.
      patchShebangs ${appDir}/node_modules

      ${before}

      echo "--- the native project"
      case "''${variant:-debug}" in
      ${cases}
        *) echo "no APP_VARIANT for gradle build type '$variant'" >&2; exit 1 ;;
      esac
      ( cd ${appDir} && ./node_modules/.bin/expo prebuild --platform android --no-install )

      # The leading newline is not cosmetic. `expo prebuild` writes this
      # file with no trailing one, and its last line is
      #
      #   expo.inlineModules.watchedDirectories=[]
      #
      # so an appended line lands on the *end* of it. That gives the property
      # the value `[]reactNativeArchitectures=…`, which Expo's autolinking
      # plugin hands to `JSON.parse`, and the ABI list is never set at all.
      # Gradle reports the first half as
      #
      #   Process 'command 'node''' finished with non-zero exit value 1
      #
      # (the third quote is nix's escape for the pair before it)
      #
      # with node's own message nowhere in the log.
      printf '\n' >> ${appDir}/android/gradle.properties
      cat >> ${appDir}/android/gradle.properties <<'PROPS'
      reactNativeArchitectures=${lib.concatStringsSep "," archs}
      ${lib.concatStringsSep "\n" gradleProperties}
      PROPS
    '';
}
