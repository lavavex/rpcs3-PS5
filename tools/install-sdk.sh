#!/usr/bin/env bash
# Install the PS5_PayloadSDK fork (the pinned revision) into deps/sdk-rpcs3: the upstream
# v0.42 payload SDK with the fork's headers and platform layer (ps5_vrange_*, ps5_shm_*,
# libc gap functions) over it. Also writes deps/ps5-extra-libs/libm.a (empty: the SDK's
# libc holds the math functions, but configure checks link -lm).
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
deps="$root/deps"
rev=$(git -C "$deps/PS5_PayloadSDK" rev-parse HEAD)
sdk="$deps/sdk-rpcs3"
if [[ -f $sdk/.ps5-sdk-revision && $(<"$sdk/.ps5-sdk-revision") == "$rev" ]]; then
    echo "==> [sdk] sdk-rpcs3 at ${rev:0:12}"
else
    echo "==> [sdk] installing PS5_PayloadSDK ${rev:0:12} to deps/sdk-rpcs3"
    tree=$(mktemp -d)
    git -C "$deps/PS5_PayloadSDK" archive "$rev" | tar -x -C "$tree"
    bash "$tree/platform/tools/setup-sdk.sh" "$sdk" "$rev" "$deps/sdkcache"
    rm -rf "$tree"
fi
mkdir -p "$deps/ps5-extra-libs"
[[ -f $deps/ps5-extra-libs/libm.a ]] || "$sdk/bin/prospero-ar" rcs "$deps/ps5-extra-libs/libm.a"
