#!/usr/bin/env bash
# Build everything from a fresh clone: dependencies, the RADV driver, LLVM, the
# third-party libraries and RPCS3 itself. Each step skips work that is already done,
# so the script can be re-run after a failure. Result: dist/PPSA99300.
set -euo pipefail
tools=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

missing=()
for tool in git cmake ninja clang clang++ python3 curl nasm make llvm-spirv glslangValidator; do
    command -v "$tool" > /dev/null || missing+=("$tool")
done
if (( ${#missing[@]} )); then
    echo "bootstrap.sh: missing host tools: ${missing[*]} (see README.md)" >&2
    exit 2
fi

bash "$tools/fetch-deps.sh"
bash "$tools/install-sdk.sh"
bash "$tools/build-driver-chain.sh"
bash "$tools/build-llvm.sh"
bash "$tools/build-zlib.sh"
bash "$tools/build-libiconv.sh"
bash "$tools/build-ffmpeg.sh"
[[ -f $tools/../deps/config_database.json ]] || bash "$tools/update-config-database.sh"
bash "$tools/build-rpcs3.sh"
echo "==> done: dist/PPSA99300 (install it with PS5_HOST=<console ip> tools/deploy.sh)"
