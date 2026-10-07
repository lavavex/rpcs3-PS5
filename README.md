# rpcs3-PS5

> [!CAUTION]
> **EXPERIMENTAL. EXPECT CRASHES, FREEZES AND BROKEN GAMES.**
>
> This is an early, unofficial port, tested on a single console with a handful of games.
> It is **not** supported by the RPCS3 team: do not report problems with it to them.
>
> - Most games are untested; many will crash back to the PS5 home screen or freeze.
> - It runs as a homebrew title on a jailbroken console. Jailbreaks, payloads and
>   unsigned titles carry their own risks; you use all of this **at your own risk**.
> - Back up anything on `/data/rpcs3/` (saves, settings) that you care about.

> [!WARNING]
> **Source only, personal use only.** Never share built `eboot.bin`/title folders,
> firmware, keys or games. The licenses involved forbid it (below).

Build scripts for running [RPCS3](https://rpcs3.net) (the PlayStation 3 emulator) as a
native title on a jailbroken PS5. RPCS3 renders through Vulkan on
[PS5_Vulkan](https://github.com/mihawk-99/PS5_Vulkan)'s RADV port, plays audio through
SceAudioOut and reads DualSense controllers through ScePad. The frontend is RPCS3's own
Big Picture Mode.

**Source only.** This repository holds no binaries, firmware, keys or games, and builds
from it must not be redistributed. RPCS3 is GPL-2.0-only, and PS5_Vulkan and
PS5_PayloadSDK are GPL-3.0: the combined title cannot be shared under either license.
Build it yourself, for your own console.

Tested on a PS5 Pro, firmware 13.60, with the Relapse jailbreak, etaHEN, ftpsrv and
ShadowMount+. Need for Speed Carbon (BLUS30016) is fully playable.

## Screenshots

Captured over Remote Play on a PS5 Pro (Need for Speed Carbon, BLUS30016).

| | |
| --- | --- |
| ![The RPCS3 title on the PS5 home screen](media/ps5-home-screen.jpg) | ![RPCS3 compiling Carbon's PPU and SPU code on first launch](media/carbon-compiling.jpg) |
| ![Carbon's main menu](media/carbon-main-menu.jpg) | ![Carbon gameplay at 60 fps with the performance overlay](media/carbon-gameplay.jpg) |

## What you need

- An Arch/CachyOS host (others work if you install the equivalents):

  ```bash
  sudo pacman -S --needed base-devel clang llvm lld make python python-pip git curl \
    unzip tar pkgconf cmake ninja nasm glslang \
    spirv-llvm-translator libclc spirv-headers python-ply
  ```

- About 20 GB of disk space. A first build takes about 10 minutes on a 16-core
  desktop (LLVM and RADV are the slow parts); expect longer on smaller machines.
- On the console: an FTP server on port 2121 (ftpsrv) and ShadowMount+ to register the
  title.
- Your own PS3 firmware (`PS3UPDAT.PUP` from playstation.com) and your own game dumps.

## Building

```bash
git clone https://github.com/lavavex/rpcs3-PS5.git
cd rpcs3-PS5
tools/bootstrap.sh
```

`bootstrap.sh` runs these steps in order; each one skips work it has already done, so
re-run it after fixing a failure:

| Step | Script | Output |
| --- | --- | --- |
| Pinned sources | `tools/fetch-deps.sh` | `deps/PS5_*`, RPCS3's submodules |
| PS5 payload SDK fork | `tools/install-sdk.sh` | `deps/sdk-rpcs3` |
| RADV driver, ps5-native-tool, libc.prx | `tools/build-driver-chain.sh` | `deps/PS5_Vulkan/.deps/native/radv-release` |
| LLVM for the recompilers | `tools/build-llvm.sh` | `deps/llvm-ps5` |
| zlib, libiconv, FFmpeg | `tools/build-{zlib,libiconv,ffmpeg}.sh` | `deps/*-ps5` |
| Per-game settings database | `tools/update-config-database.sh` | `deps/config_database.json` |
| RPCS3 | `tools/build-rpcs3.sh` | `dist/PPSA99300` |

After changing RPCS3's code, rebuild with `ninja -C build/rpcs3-ps5 rpcs3_ps5`.

## Installing

Close RPCS3 on the console first (a running title's files cannot be replaced), then:

```bash
PS5_HOST=192.168.x.x tools/deploy.sh
```

This uploads `dist/PPSA99300` to `/data/homebrew/PPSA99300`, and ShadowMount+ adds it to
the home screen.

## First run

Put these in `/data/rpcs3/` on the console over FTP:

- `PS3UPDAT.PUP`: installed on the next launch, then you can delete it.
- Games: copy disc game folders (each holding `PS3_GAME/`) to `/data/rpcs3/games/`, or to
  a `games/` folder on an exFAT USB drive.

RPCS3 opens in Big Picture Mode with your games listed. Players 1–4 are the DualSenses of
the signed-in users. Options + touchpad acts as the PS button.

For a custom home-screen background, convert a 16:9 image with
`deps/PS5_Vulkan/tools/prepare-assets.sh --background <image> --output-directory title/sce_sys`
and rebuild; `pic0.dds`/`pic1.dds` stay out of git.

Settings, logs and caches live in `/data/rpcs3/` (log: `/data/rpcs3/cache/RPCS3.log`).
To boot one game straight away, write its path (or a `.pkg` to install) into
`/data/rpcs3/boot.txt`.

## Known issues

- **Few games tested.** Need for Speed Carbon (BLUS30016) plays at 60 fps. inFAMOUS (BCUS98119)
  plays, but stutters and runs below full speed in places. Nothing else has been tried yet.
- **The first launch of a game is slow.** RPCS3 compiles the game's PPU and SPU code and its
  shaders, and stutters while it does. The caches in `/data/rpcs3/cache` make later launches
  faster.
- **No video previews.** A game's details page in Big Picture Mode shows its icon, not its
  preview video.
- **The CPU usage in RPCS3's log is wrong** (a constant 6.3%): the PS5 does not report process
  CPU time. The performance overlay's PPU/SPU/RSX figures are correct.
- **A crash or freeze closes the title** without a message. The reason is in
  `/data/rpcs3/cache/RPCS3.log` (copy it off before relaunching: each launch replaces it).

## Layout

| Path | What |
| --- | --- |
| `src/rpcs3` | Submodule: [lavavex/rpcs3](https://github.com/lavavex/rpcs3), branch `ps5` (upstream RPCS3 plus the PS5 port; the frontend is `rpcs3/ps5/`) |
| `cmake/ps5-rpcs3.cmake` | CMake toolchain for the title |
| `tools/link-title.sh` | Links the title with RADV and signs `eboot.bin` |
| `title/sce_sys` | Title metadata (`PPSA99300`) and icon |
| `docs/` | Notes on the PS5 memory model |
| `PINS.md` | Pinned revisions of every dependency, and how to update them (`tools/sync-forks.sh`) |

## Credits

- [RPCS3](https://github.com/RPCS3/rpcs3) and its contributors.
- mihawk-99 for PS5_Vulkan, PS5_Mesa, PS5_PayloadSDK and PS5_LLVM, and the earlier RPCS3
  port notes this one follows.
- Swordpdf's [PS5SX2](https://github.com/Swordpdf/PS5SX2) for the memory model.
- [ps5-payload-dev](https://github.com/ps5-payload-dev) for the SDK.
- blackbearreloaded's [ps5-opengl](https://github.com/blackbearreloaded/ps5-opengl) for
  the shader compiler.

## License

The scripts in this repository are GPL-3.0-or-later (`LICENSE`). RPCS3 and the other
dependencies keep their own licenses.
