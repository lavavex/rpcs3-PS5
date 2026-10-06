#!/usr/bin/env bash
# Link RPCS3's PS5 frontend into a native title and package its folder.
#
#   link-title.sh OUTPUT INPUT...
#
# Run by CMake as the link step of rpcs3_ps5 (rpcs3/ps5/CMakeLists.txt): INPUT is
# what CMake would link (objects, static archives, -l stubs, -Wl, flags). The link
# is PS5_Vulkan's, as PS5_VulkanTemplate's tools/link-title.sh runs it: its RADV
# release archive, tools/radv-link.sh (the platform layer's heap, thread and libc
# bindings), its CRT, ps5-native-tool (ELF -> fake SELF) and the clean-room
# libc.prx. The title folder is dist/<TITLE_ID>/.
set -euo pipefail
[[ -n ${LINK_TRACE:-} ]] && set -x

out=$1
shift
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
vulkan="$root/deps/PS5_Vulkan"
sdk="$root/deps/sdk-rpcs3"
archive=${RADV_ARCHIVE:-$vulkan/.deps/native/radv-release/lib/libvulkan_radeon.ps5.a}
export PS5_CLANG=${PS5_CLANG:-$(command -v clang || true)}
tool="$vulkan/build/host/ps5-native-tool"
native="$vulkan/tooling/native"
param="$root/title/sce_sys/param.json"
work="$(dirname "$out")/title-link"

for file in "$archive" "$tool" "$param" "$sdk/bin/prospero-lld" "$vulkan/tools/radv-link.sh" "$vulkan/runtime/libc.prx"; do
    [[ -e $file ]] || { echo "link-title.sh: missing $file" >&2; exit 2; }
done
mkdir -p "$work/obj" "$work/stubs"

# What CMake hands over: objects first, archives as one group (RPCS3's libraries
# depend on each other in circles), linker flags as they are. -l names are the
# SDK's stubs, which the recipe links from target/lib anyway.
objects=() archives=() flags=()
for arg in "$@"; do
    case $arg in
        *.o) objects+=("$arg") ;;
        *.a) archives+=("$arg") ;;
        -Wl,*) IFS=',' read -r -a parts <<<"${arg#-Wl,}"; flags+=("${parts[@]}") ;;
        -l* | -L* | -march=* | -O* | -g* | -f* | -D* | --sysroot=*) ;;
        *) ;;
    esac
done

cc() { PS5_PAYLOAD_SDK="$sdk" sh "$vulkan/tooling/prospero-clang18" "$@"; }
cc -std=c++20 -O2 -fno-exceptions -fno-rtti -c "$native/app_crt.cpp" -o "$work/obj/app_crt.o"

# RADV calls AGC, which the SDK has no stubs for
stub() {
    local library=$1 source=$2
    cc -std=c11 -O2 -fPIC -c "$vulkan/$source" -o "$work/obj/${library}_stub.o"
    "$sdk/bin/prospero-lld" --shared -soname "${library}.prx" -o "$work/stubs/${library}.so" "$work/obj/${library}_stub.o"
}
stub libSceAgc vendor/ps5/sdk/stubs/agc_canary_link_stub.c
stub libSceAgcDriver vendor/ps5/sdk/stubs/agc_driver_canary_link_stub.c

# shellcheck source=/dev/null
source "$vulkan/tools/radv-link.sh"
radv_link_recipe "$vulkan" "$sdk" "$archive" || exit 2

"$sdk/bin/prospero-lld" "${radv_linker_script[@]}" --eh-frame-hdr "${radv_link_flags[@]}" \
    "${flags[@]}" \
    --version-script "$native/app-symbols.map" --exclude-libs=ALL \
    -e _start -o "$work/llvm-pie.elf" \
    "$work/obj/app_crt.o" "${objects[@]}" \
    --start-group "${archives[@]}" --end-group \
    "$work/stubs/libSceAgc.so" "$work/stubs/libSceAgcDriver.so" \
    "${radv_link_inputs[@]}" \
    --as-needed "$sdk"/target/lib/*.so

# A title loads neither libkernel_sys's exports nor libScePosixForWebKit's: an import
# only their stubs define is null at run time. Refuse it here, not on the console.
null_imports=$(comm -23 \
    <("$sdk/bin/llvm-nm" -D --undefined-only "$work/llvm-pie.elf" |
        awk '$1 == "U" { sub(/@.*/, "", $2); print $2 }' | sort -u) \
    <(for library in "$sdk"/target/lib/*.so "$work/stubs/libSceAgc.so" "$work/stubs/libSceAgcDriver.so"; do
        case ${library##*/} in libkernel_sys.so | libScePosixForWebKit.so) continue ;; esac
        "$sdk/bin/llvm-nm" -D --defined-only "$library" 2>/dev/null | awk '{ print $NF }'
    done | sort -u))
if [[ -n $null_imports ]]; then
    echo "link-title.sh: imports no module a title loads exports (null at run time): ${null_imports//$'\n'/ }" >&2
    echo "link-title.sh: bind them to the platform layer" >&2
    exit 1
fi

"$tool" link --in "$work/llvm-pie.elf" --out "$work/eboot.elf" \
    --stub-dir "$sdk/target/lib" --stub "$work/stubs/libSceAgc.so" \
    --stub "$work/stubs/libSceAgcDriver.so" --module-sdk 0x02000009 \
    --companion-sdk 0x08050001 --file-name eboot.elf

title_id=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["titleId"])' "$param")
app="$root/dist/$title_id"
mkdir -p "$app/sce_sys" "$app/sce_module"
"$tool" self --sign --in "$work/eboot.elf" --out "$app/eboot.bin" --magic 0x1D3D154F
"$tool" self --inspect --file "$app/eboot.bin" > /dev/null
cp "$param" "$app/sce_sys/param.json"
for asset in icon0.png pic0.dds pic1.dds snd0.at9; do
    [[ -f $root/title/sce_sys/$asset ]] && cp "$root/title/sce_sys/$asset" "$app/sce_sys/$asset"
done
(cd "$vulkan/runtime" && sha256sum --check --strict --quiet libc.prx.sha256)
cp "$vulkan/runtime/libc.prx" "$app/sce_module/libc.prx"

# RPCS3's own resources beside the eboot (/app0): overlay icons, patches, game configs
src="$root/src/rpcs3/bin"
mkdir -p "$app/Icons" "$app/patches"
cp -a "$src/Icons/ui" "$app/Icons/" 2>/dev/null || true
cp "$src"/patches/*.yml "$app/patches/" 2>/dev/null || true

# CMake's output is the unsigned ELF, for symbolising crashes
cp "$work/llvm-pie.elf" "$out"
printf '==> %s: %s (eboot.bin %s bytes)\n' "$title_id" "$app" "$(stat -c %s "$app/eboot.bin")"
