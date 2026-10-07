#!/usr/bin/env bash
# Configure and build RPCS3 (src/rpcs3) as the PS5 title. link-title.sh runs as the
# link step and leaves the installable folder in dist/PPSA99300.
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
deps="$root/deps"
build="$root/build/rpcs3-ps5"
ff="$deps/ffmpeg-ps5/lib"
if [[ ! -f $build/build.ninja ]]; then
    echo "==> [rpcs3] configure"
    cmake -S "$root/src/rpcs3" -B "$build" -G Ninja \
        -DCMAKE_TOOLCHAIN_FILE="$root/cmake/ps5-rpcs3.cmake" -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_C_FLAGS="-march=znver2 -DZSTD_TRACE=0" -DCMAKE_CXX_FLAGS="-march=znver2 -DZSTD_TRACE=0" \
        -DUSE_NATIVE_INSTRUCTIONS=OFF -DUSE_LTO=OFF -DUSE_PRECOMPILED_HEADERS=OFF \
        -DWITH_LLVM=ON -DBUILD_LLVM=OFF -DSTATIC_LINK_LLVM=ON -DLLVM_DIR="$deps/llvm-ps5/lib/cmake/llvm" \
        -DUSE_FAUDIO=OFF -DUSE_SDL=OFF -DUSE_LIBEVDEV=OFF -DUSE_DISCORD_RPC=OFF -DUSE_GAMEMODE=OFF \
        -DUSE_VULKAN=ON -DRPCS3_VULKAN_HEADERS_DIR="$deps/PS5_Vulkan/.deps/native/mesa/mesa-26.2.0/include" \
        -DUSE_SYSTEM_FFMPEG=ON -DFFMPEG_INCLUDE_DIR="$deps/ffmpeg-ps5/include" \
        -DFFMPEG_LIBRARIES="$ff/libavformat.a;$ff/libavcodec.a;$ff/libswscale.a;$ff/libswresample.a;$ff/libavutil.a" \
        -DIconv_INCLUDE_DIR="$deps/libiconv-ps5/include" -DIconv_LIBRARY="$deps/libiconv-ps5/lib/libiconv.a" \
        -DIconv_IS_BUILT_IN=OFF \
        -DUSE_SYSTEM_ZLIB=ON -DZLIB_INCLUDE_DIR="$deps/zlib-ps5/include" -DZLIB_LIBRARY="$deps/zlib-ps5/lib/libz.a" \
        -DUSE_SYSTEM_CURL=OFF -DUSE_SYSTEM_OPENCV=OFF -DUSE_SYSTEM_SDL=OFF
fi
echo "==> [rpcs3] build"
ninja -C "$build" rpcs3_ps5
