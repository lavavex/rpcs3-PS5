#!/usr/bin/env bash
# Clone the pinned source dependencies into deps/ and RPCS3's submodules into src/rpcs3.
# Revisions are listed in PINS.md; a checkout that already sits at its pin is left alone.
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
deps="$root/deps"
mkdir -p "$deps"

# name  revision. Sources are lavavex's forks (kept current with tools/sync-forks.sh), with
# mihawk-99's originals as the fallback when a fork lacks a pinned commit.
pins=(
    "PS5_Vulkan         5b5e4fc2d80fdb67a4f61ba9e6a8a424026bb8a5"
    "PS5_Mesa           b3588f78dd7fd46fbadc7ecd487e5f14d4213e4b"
    "PS5_PayloadSDK     b5efad528e0ac1b8289f39d72a0e890ff68ff0a6"
    "PS5_LLVM           be5b58f51c93c67947b7e18cd45c2f9913f2c311"
)

for pin in "${pins[@]}"; do
    read -r name rev <<< "$pin"
    dir="$deps/$name"
    if [[ -d $dir/.git || -f $dir/.git ]] && [[ $(git -C "$dir" rev-parse HEAD) == "$rev" ]]; then
        echo "==> [deps] $name at ${rev:0:12}"
        continue
    fi
    echo "==> [deps] $name -> ${rev:0:12}"
    [[ -e $dir ]] || git init -q "$dir"
    # LLVM is large: fetch only the pinned commit
    depth=(); [[ $name == PS5_LLVM ]] && depth=(--depth 1)
    fetched=false
    for owner in lavavex mihawk-99; do
        if git -C "$dir" fetch -q "${depth[@]}" "https://github.com/$owner/$name.git" "$rev" 2>/dev/null; then
            git -C "$dir" remote remove origin 2>/dev/null || true
            git -C "$dir" remote add origin "https://github.com/$owner/$name.git"
            fetched=true
            break
        fi
    done
    $fetched || { echo "fetch-deps.sh: $name ${rev:0:12} not found in lavavex or mihawk-99" >&2; exit 1; }
    git -C "$dir" -c advice.detachedHead=false checkout -q "$rev"
done

# RPCS3 (the fork's ps5 branch) is the src/rpcs3 submodule of this repo. Its bundled
# LLVM and prebuilt FFmpeg are not used on the PS5, so those two are skipped.
echo "==> [deps] src/rpcs3 submodules"
git -C "$root" submodule update --init src/rpcs3
git -C "$root/src/rpcs3" -c submodule.3rdparty/llvm/llvm.update=none -c submodule.3rdparty/ffmpeg.update=none \
    submodule update --init --recursive --jobs 8
