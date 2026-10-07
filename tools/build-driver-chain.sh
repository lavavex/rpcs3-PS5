#!/usr/bin/env bash
# Build PS5_Vulkan's RADV driver for the title: the PS5 shader compiler (psbc), the
# ps5-opengl 0.3.0 adapter, Mesa's Vulkan runtime and the RADV release archive, plus
# the host tools a title needs (ps5-native-tool, the clean-room libc.prx).
#
# Expects deps/PS5_Vulkan, deps/PS5_Mesa, deps/PS5_PayloadSDK (tools/fetch-deps.sh).
# Output: deps/PS5_Vulkan/.deps/native/radv-release/lib/libvulkan_radeon.ps5.a
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
deps="$root/deps"
vulkan="$deps/PS5_Vulkan"
step() { echo "==> [driver] $*"; }

# Mesa's code generators need mako and markupsafe: a private copy, no system install
if ! python3 -c 'import mako, markupsafe' 2>/dev/null && [[ ! -d $deps/pylib/mako ]]; then
    step "mako/markupsafe into deps/pylib"
    python3 -m pip install --quiet --target "$deps/pylib" mako markupsafe
fi
export PS5VK_MAKO_PATH="$deps/pylib"
export PYTHONPATH="$deps/pylib${PYTHONPATH:+:$PYTHONPATH}"

# ps5-opengl SDK 0.3.0: the release bundle and its source tree (the compiler sources)
release="$deps/ps5-opengl-sdk-0.3.0"
if [[ ! -d $release ]]; then
    step "ps5-opengl SDK 0.3.0"
    archive="$deps/downloads/ps5-opengl-sdk-0.3.0.tar.gz"
    mkdir -p "$deps/downloads"
    [[ -f $archive ]] || curl --fail --location --retry 3 -o "$archive" \
        https://github.com/blackbearreloaded/ps5-opengl/releases/download/v0.3.0/ps5-opengl-sdk-0.3.0.tar.gz
    printf '%s  %s\n' a7bd6b85f00398eaf8d87ecc58fa0bde7cab79e065acc783268070d2f14b403c "$archive" |
        sha256sum --check --status || { echo "ps5-opengl archive digest mismatch" >&2; exit 1; }
    tar xzf "$archive" -C "$deps"
fi
src="$deps/ps5-opengl-src/ps5-opengl"
if [[ ! -d $src/third_party/opengnm-psbc ]]; then
    step "ps5-opengl sources (pinned third-party trees)"
    mkdir -p "$deps/ps5-opengl-src"
    tar xf "$release/sources/ps5-opengl.tar" -C "$deps/ps5-opengl-src"
    (cd "$src" && python3 tools/fetch-sources.py)
fi
if [[ ! -f $src/third_party/opengnm-psbc/src/util/format/u_format_gen.h ]]; then
    # The 0.2.0-era layout PS5_Vulkan's build-psbc-ps5.sh expects carried the generated
    # sources; a fresh 0.3.0 tree does not. Generate them with the SDK's own command list.
    step "psbc generated sources"
    gen=$(mktemp)
    start=$(grep -n '^python3 src/util/format/u_format_table.py src/util/format/u_format.yaml --enums' \
        "$src/toolchain/build-opengnm-psbc.sh" | cut -d: -f1)
    awk -v s="$start" 'NR >= s' "$src/toolchain/build-opengnm-psbc.sh" |
        awk '/^make -B/ { exit } { print }' > "$gen"
    (cd "$src/third_party/opengnm-psbc" && config_file="../../toolchain/opengnm-psbc-host.mak" bash -e "$gen")
    rm -f "$gen"
    (cd "$src" && python3 tools/fetch-sources.py --verify-psbc)
fi

cd "$vulkan"
step "PS5_Vulkan native dependencies (its pinned payload SDK)"
bash tools/setup-native-dependencies.sh > /dev/null

if [[ ! -f .deps/native/psbc/PROVENANCE.txt ]]; then
    step "psbc (SPIR-V -> AGC shader compiler)"
    PS5_OPENGL_SDK="$src" bash tools/build-psbc-ps5.sh
fi
if [[ ! -d .deps/native/opengl-sdk/toolchain ]]; then
    step "adapt ps5-opengl 0.3.0"
    bash tools/adapt-opengl-sdk.sh "$release"
fi
step "Mesa 26.2.0 sources"
bash tools/fetch-mesa.sh
step "Vulkan runtime"
bash tools/build-vulkan-runtime.sh
step "RADV (release)"
bash tools/build-radv.sh release

step "ps5-native-tool and libc.prx"
make libc > /dev/null
# `make app` builds the host tool first; its sample title may then fail to link against
# PS5_Vulkan's older SDK pin, which does not matter here
make app > /dev/null 2>&1 || true
[[ -x build/host/ps5-native-tool && -f runtime/libc.prx ]] ||
    { echo "ps5-native-tool or libc.prx missing" >&2; exit 1; }

step "done: $(ls .deps/native/radv-release/lib/libvulkan_radeon.ps5.a)"
