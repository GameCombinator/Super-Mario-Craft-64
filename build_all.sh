#!/usr/bin/env bash
# Builds the combined Minecraft PE + Super Mario 64 APK.
#
#   1. libminecraftpe.so  - Pocket Edition, NDK r10e (what the original code needs)
#   2. libsm64.so         - SM64 port, any modern NDK (r25-r27), needs YOUR ROM
#   3. the APK            - Gradle packages both (Steve = MainActivity, Mario = Sm64Activity)
#
# Needs (Linux / macOS / WSL):
#   ANDROID_NDK_R10E     path to android-ndk-r10e
#   ANDROID_NDK_MODERN   path to a recent NDK (only if sm64/baserom.us.z64 exists)
#   ANDROID_HOME         Android SDK with platform android-34 + build-tools
#   gradle (8.7+) on PATH, JDK 17, python3, make, gcc/g++
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
JNILIBS="$ROOT/android/app/src/main/jniLibs/armeabi-v7a"
ROM="$ROOT/sm64/baserom.us.z64"

: "${ANDROID_NDK_R10E:?set ANDROID_NDK_R10E to your android-ndk-r10e folder}"
: "${ANDROID_HOME:=${ANDROID_SDK_ROOT:-}}"
if [[ -z "$ANDROID_HOME" ]]; then
  echo "error: set ANDROID_HOME to your Android SDK folder"; exit 1
fi
export ANDROID_HOME
mkdir -p "$JNILIBS"

NPROC="$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)"

echo "=== 1/3  Steve: Minecraft PE (NDK r10e) ==="
ANDROID_NDK_HOME="$ANDROID_NDK_R10E" "$ROOT/build_android.sh" release
cp "$ROOT/handheld/project/android/libs/armeabi-v7a/libminecraftpe.so" "$JNILIBS/"

if command -v readelf >/dev/null 2>&1; then
  if readelf -d "$JNILIBS/libminecraftpe.so" | grep -q TEXTREL; then
    echo "WARNING: libminecraftpe.so has text relocations. Android 6+ refuses to load that"
    echo "         for apps targeting API 23+. Send me this message and I'll adjust the build."
  fi
fi

echo "=== 2/3  Mario: Super Mario 64 port ==="
if [[ -f "$ROM" ]]; then
  : "${ANDROID_NDK_MODERN:?set ANDROID_NDK_MODERN to a recent NDK (r25-r27) to build Mario}"
  case "$(uname -s)" in
    Darwin) HOST_TAG=darwin-x86_64 ;;
    *)      HOST_TAG=linux-x86_64 ;;
  esac
  CC="$ANDROID_NDK_MODERN/toolchains/llvm/prebuilt/$HOST_TAG/bin/armv7a-linux-androideabi21-clang"
  [[ -x "$CC" ]] || { echo "error: compiler not found: $CC"; exit 1; }
  make -C "$ROOT/sm64" TARGET_ANDROID=1 VERSION=us ANDROID_CC="$CC" -j"$NPROC"
  cp "$ROOT/sm64/build/us_android/libsm64.so" "$JNILIBS/"
else
  rm -f "$JNILIBS/libsm64.so"
  echo "No sm64/baserom.us.z64 found -> building WITHOUT Mario."
  echo "(Put your own US Super Mario 64 ROM there and re-run to get him.)"
fi

echo "=== 3/3  APK (Gradle) ==="
if [[ -x "$ROOT/android/gradlew" ]]; then GRADLE="$ROOT/android/gradlew"; else GRADLE=gradle; fi
(cd "$ROOT/android" && "$GRADLE" --no-daemon assembleDebug)

mkdir -p "$ROOT/dist"
cp "$ROOT/android/app/build/outputs/apk/debug/app-debug.apk" "$ROOT/dist/MarioCraft.apk"
echo
echo "Done: $ROOT/dist/MarioCraft.apk"
