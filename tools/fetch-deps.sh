#!/usr/bin/env bash
# Clone the pinned source dependencies into deps/ and RPCS3's submodules into src/rpcs3.
# Revisions are listed in PINS.md; a checkout that already sits at its pin is left alone.
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
deps="$root/deps"
mkdir -p "$deps"

# name  url  revision
pins=(
    "PS5_Vulkan         https://github.com/mihawk-99/PS5_Vulkan.git      5b5e4fc2d80fdb67a4f61ba9e6a8a424026bb8a5"
    "PS5_Mesa           https://github.com/mihawk-99/PS5_Mesa.git        b3588f78dd7fd46fbadc7ecd487e5f14d4213e4b"
    "PS5_PayloadSDK     https://github.com/mihawk-99/PS5_PayloadSDK.git  b5efad528e0ac1b8289f39d72a0e890ff68ff0a6"
    "PS5_LLVM           https://github.com/mihawk-99/PS5_LLVM.git        be5b58f51c93c67947b7e18cd45c2f9913f2c311"
)

for pin in "${pins[@]}"; do
    read -r name url rev <<< "$pin"
    dir="$deps/$name"
    if [[ -d $dir/.git || -f $dir/.git ]] && [[ $(git -C "$dir" rev-parse HEAD) == "$rev" ]]; then
        echo "==> [deps] $name at ${rev:0:12}"
        continue
    fi
    echo "==> [deps] $name -> ${rev:0:12}"
    if [[ ! -e $dir ]]; then
        git init -q "$dir"
        git -C "$dir" remote add origin "$url"
    fi
    # LLVM is large: fetch only the pinned commit
    if [[ $name == PS5_LLVM ]]; then
        git -C "$dir" fetch -q --depth 1 origin "$rev"
    else
        git -C "$dir" fetch -q origin "$rev"
    fi
    git -C "$dir" -c advice.detachedHead=false checkout -q "$rev"
done

# RPCS3 (the fork's ps5 branch) is the src/rpcs3 submodule of this repo. Its bundled
# LLVM and prebuilt FFmpeg are not used on the PS5, so those two are skipped.
echo "==> [deps] src/rpcs3 submodules"
git -C "$root" submodule update --init src/rpcs3
git -C "$root/src/rpcs3" -c submodule.3rdparty/llvm/llvm.update=none -c submodule.3rdparty/ffmpeg.update=none \
    submodule update --init --recursive --jobs 8
