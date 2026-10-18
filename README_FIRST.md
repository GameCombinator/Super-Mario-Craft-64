# MarioCraft: Minecraft PE (Steve) + Super Mario 64 (Mario) in one Android app

One APK, two games, one tap to swap:

* **Steve**: the 2013 Minecraft Pocket Edition source (`handheld/`), unchanged apart from the fixes listed below.
* **Mario**: the SM64 PC port (`sm64/`), running on a GLES2 surface with an N64-emulator-style touch controller.
* A red **MARIO** button floats in the top-right corner of Minecraft. In Mario mode, **STEVE** (top centre) or the Back key takes you home. Both games keep their state while you're away.

> **Status: written without being able to compile or run it.** My sandbox has no Android NDK/SDK and no
> internet. The C code that I could check on a PC compiles cleanly against stubs, but the
> Java, the NDK builds and everything on-device are untested. Expect to do one or two rounds of
> "paste me the build log / logcat" with me. Details under *If something goes wrong*.

---

## Getting an APK (no PC needed): GitHub Actions

1. Create a **private** GitHub repository and upload this whole folder (the contents of the zip).
   Private matters: this contains Nintendo's and Mojang's code, and in step 2 your Mario ROM.
2. For Mario, add your own legally obtained US ROM as `sm64/baserom.us.z64`
   (big-endian `.z64`, SHA-1 `9bef1128717f958171a4afac3ed78ee2bb4e86ce`).
   No ROM = the build still works, just without Mario (the button will say so).
3. **Actions → Build MarioCraft APK → Run workflow.** About 15-25 minutes.
4. Open the finished run, download the **MarioCraft-apk** artifact, unzip, install `app-debug.apk`
   (allow "install unknown apps" for your browser/Files app).

## Building on a PC instead

```bash
export ANDROID_NDK_R10E=/path/to/android-ndk-r10e      # Minecraft's code needs this old NDK
export ANDROID_NDK_MODERN=/path/to/android-ndk-r26      # for Mario (any r25-r27)
export ANDROID_HOME=/path/to/android-sdk                # platform android-34 + build-tools
./build_all.sh                                          # -> dist/MarioCraft.apk
```
Needs JDK 17, Gradle 8.7+, python3, make, gcc/g++ (and `sm64/baserom.us.z64` for Mario).

---

## Mario controls

| Control | Where | N64 |
|---|---|---|
| Analog stick | touch anywhere in the left ~45% (floating; it follows your thumb) | Stick |
| A / B | bottom right | A / B |
| Yellow arrows | right side, above A/B | C-buttons (camera) |
| Z | top left | Z (crouch, ground-pound, long jump) |
| R | top right | R |
| START | bottom centre | Start / pause |
| RES | top centre | cycles render resolution 100 / 75 / 50 % |

Multi-touch works (jump while running while turning the camera). Android's back-swipe gesture is
excluded over the control areas.

## Performance choices (Moto G 2026: Dimensity 6300, Mali-G57, 4 GB)

* Game logic stays at SM64's native 30 Hz, vsync-aligned through `Choreographer`, so it is paced
  correctly on a 120 Hz panel and the GPU idles between ticks (less heat/battery).
* The surface is flagged as 30 fps content (Android 11+), so the system can drop the display cadence.
* Renderer: GLES2, highp shaders, one streamed vertex buffer. NEON audio mixer is used on ARM.
* **If it still stutters: tap RES** to render at 75% or 50% (sharpness for speed; saved between runs).
* Audio: 32 kHz stereo ring buffer to a low-latency `AudioTrack`, about 55 ms of headroom.
* Minecraft: use *Options → Fast graphics / low view distance* if the 2013 renderer hitches.

## What I changed in the originals

**Minecraft (`handheld/`)**
* `main_android.cpp`: worlds are stored in the app's own folder
  (`Android/data/com.mojang.minecraftpe/files`) instead of the root of shared storage, which
  Android 11+ blocks. No storage permission needed.
* `MainActivity.java` + new `MarioSwitchButton.java`: the floating button (a `PopupWindow`, because
  a NativeActivity owns its input queue and ordinary views never receive touches).
* `android/` is a new Gradle project that packages the old Java/res/assets together with both native libs.
  `targetSdkVersion` is 28 on purpose (lowest value Android 14-16 installs cleanly; avoids
  scoped-storage and edge-to-edge changes the 2013 code knows nothing about).

**SM64 (`sm64/`)**: new `TARGET_ANDROID=1` build
* `Makefile`: cross-compiles `libsm64.so` with the NDK clang (armeabi-v7a), drops the SDL/X11/ALSA/Pulse files.
* New: `src/pc/gfx/gfx_android.c` (window layer), `src/pc/audio/audio_android.c`,
  `src/pc/controller/controller_touch.c`, `src/pc/android_jni.c` (stdout/stderr go to logcat tag `SM64`).
* `gfx_opengl.c`: GLSL ES 1.00 (`#version 100`) + float precision; the original shaders were desktop `#version 110` and phones reject them.
* `gfx_pc.c`: `gfx_reset_gl_resources()` so Mario survives losing/regaining the GL context when you swap games.
* `pc_main.c`: returns after init on Android; Java drives one frame at a time.
* Java side: `sm64/Sm64Activity`, `TouchControlsView`, `Sm64Audio`, `Sm64Native`.

## Why 32-bit?

Minecraft PE 0.6's code and build (NDK r10e, `armeabi-v7a`) are 32-bit only, and one app process
can't mix 32- and 64-bit libraries, so Mario is built 32-bit too. The Dimensity 6300's cores
(Cortex-A76/A55) still run 32-bit apps. If the install says the app isn't compatible, the phone's
software is 64-bit only and Minecraft's code would need a real 64-bit port.

## If something goes wrong

* **Build fails:** paste me the failing step's log. Likeliest culprits: Minecraft's own 2013 code not
  building on NDK r10e (the repo's README already calls its build WIP), or a clang strictness error in the SM64 port.
* **Installs but Minecraft is black/crashes:** I'd suspect OpenGL ES **1.1** (Minecraft's renderer)
  on a newer GPU driver, or the CI warning "text relocations". Run `adb logcat | grep -i -E "MinecraftPE|AndroidRuntime|linker"` and send it.
* **Mario button says Mario isn't in this build:** no ROM at build time (see step 2).
* **Mario crashes / black screen:** `adb logcat -s SM64` (shader errors and game output land there).
* **No sound in Minecraft:** the repo's Android assets contain no sound files; that's the source archive, not this change.

## Legal / housekeeping

Keep your repo private and don't redistribute the APK: it embeds Nintendo's game data (from your ROM)
and Mojang's code and assets. The ROM is only read at build time.
