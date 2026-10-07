#!/usr/bin/env bash
# Build LLVM (PS5_LLVM: RPCS3's LLVM revision plus two PS4/PS5 ABI fixes) as static
# libraries for the PS5, for RPCS3's PPU/SPU recompilers. The host builds tablegen first.
# Output: deps/llvm-ps5. Takes a while (about 3500 objects).
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
src="$root/deps/PS5_LLVM/llvm"
rev=$(git -C "$root/deps/PS5_LLVM" rev-parse HEAD)
prefix="$root/deps/llvm-ps5"
[[ -f $prefix/.stamp && $(<"$prefix/.stamp") == "$rev" ]] && { echo "==> [llvm] ${rev:0:12} already built"; exit 0; }

host="$root/build/llvm-host-tblgen"
echo "==> [llvm] host tablegen"
cmake -S "$src" -B "$host" -G Ninja -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_C_COMPILER=clang -DCMAKE_CXX_COMPILER=clang++ -DLLVM_TARGETS_TO_BUILD=X86 \
    -DLLVM_INCLUDE_TESTS=OFF -DLLVM_INCLUDE_BENCHMARKS=OFF -DLLVM_INCLUDE_EXAMPLES=OFF > /dev/null
ninja -C "$host" llvm-tblgen llvm-min-tblgen

build="$root/build/llvm-ps5"
echo "==> [llvm] PS5 libraries"
cmake -S "$src" -B "$build" -G Ninja \
    -DCMAKE_TOOLCHAIN_FILE="$root/deps/sdk-rpcs3/toolchain/prospero.cmake" -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="$prefix" \
    -DCMAKE_C_FLAGS=-march=znver2 -DCMAKE_CXX_FLAGS=-march=znver2 \
    -DCMAKE_EXE_LINKER_FLAGS="-L$root/deps/ps5-extra-libs" \
    -DLLVM_TARGETS_TO_BUILD=X86 -DLLVM_TARGET_ARCH=X86 -DLLVM_HOST_TRIPLE=x86_64-sie-ps5 \
    -DLLVM_DEFAULT_TARGET_TRIPLE=x86_64-unknown-linux-gnu \
    -DLLVM_NATIVE_TOOL_DIR="$host/bin" -DLLVM_TABLEGEN="$host/bin/llvm-tblgen" \
    -DLLVM_BUILD_TOOLS=OFF -DLLVM_INCLUDE_TOOLS=OFF -DLLVM_INCLUDE_UTILS=OFF -DLLVM_INCLUDE_TESTS=OFF \
    -DLLVM_INCLUDE_BENCHMARKS=OFF -DLLVM_INCLUDE_EXAMPLES=OFF -DLLVM_INCLUDE_DOCS=OFF -DLLVM_BUILD_RUNTIME=OFF \
    -DLLVM_ENABLE_ZLIB=OFF -DLLVM_ENABLE_ZSTD=OFF -DLLVM_ENABLE_LIBXML2=OFF -DLLVM_ENABLE_TERMINFO=OFF \
    -DLLVM_ENABLE_LIBEDIT=OFF -DLLVM_ENABLE_LIBPFM=OFF -DLLVM_ENABLE_BACKTRACES=OFF \
    -DLLVM_ENABLE_CRASH_OVERRIDES=OFF -DLLVM_ENABLE_THREADS=ON -DLLVM_ENABLE_PIC=ON \
    -DLLVM_ENABLE_RTTI=ON -DLLVM_ENABLE_EH=ON -DLLVM_ENABLE_WARNINGS=OFF -DLLVM_ENABLE_ASSERTIONS=OFF > /dev/null
ninja -C "$build"
rm -rf "$prefix"
ninja -C "$build" install > /dev/null
echo "$rev" > "$prefix/.stamp"
