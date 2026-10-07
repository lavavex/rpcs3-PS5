# Pinned revisions (rpcs3-PS5)

`tools/fetch-deps.sh` checks these out; the RPCS3 revision is the `src/rpcs3` submodule's.

| Component | Where | Revision |
| --- | --- | --- |
| RPCS3 ([lavavex/rpcs3](https://github.com/lavavex/rpcs3) branch `ps5` = upstream master 55a3aff33 + PS5 port) | src/rpcs3 (submodule) | the submodule commit |
| [PS5_LLVM](https://github.com/mihawk-99/PS5_LLVM) (RPCS3's LLVM ca7933e4 + 2 PS5 ABI fixes) | deps/PS5_LLVM | be5b58f51c93 |
| [PS5_PayloadSDK](https://github.com/mihawk-99/PS5_PayloadSDK) (installed to deps/sdk-rpcs3) | deps/PS5_PayloadSDK | b5efad528e0a |
| [PS5_Vulkan](https://github.com/mihawk-99/PS5_Vulkan) (RADV build and link recipe) | deps/PS5_Vulkan | 5b5e4fc2d80f |
| [PS5_Mesa](https://github.com/mihawk-99/PS5_Mesa) | deps/PS5_Mesa | b3588f78dd7f |
| [ps5-opengl](https://github.com/blackbearreloaded/ps5-opengl) SDK (shader compiler) | deps/ps5-opengl-sdk-0.3.0 | release v0.3.0, sha256 a7bd6b85… |
| FFmpeg | deps/ffmpeg-ps5 | 8.1.1 (sha256 in tools/build-ffmpeg.sh) |
| GNU libiconv | deps/libiconv-ps5 | 1.18 (sha256 in tools/build-libiconv.sh) |
| zlib | deps/zlib-ps5 | RPCS3's zlib submodule |

Reference only (not built): [PS5SX2](https://github.com/Swordpdf/PS5SX2) 9183fda (memory model),
[PS5_VulkanTemplate](https://github.com/mihawk-99/PS5_VulkanTemplate) b577e950.
