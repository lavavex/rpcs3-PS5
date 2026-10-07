# PS5 memory model: notes for the RPCS3 port

Taken from Swordpdf/PS5SX2 (`deps/PS5SX2`, commit 9183fda) and mihawk-99's RPCS3 port spec
(`docs/RPCS3_PORT_prior_art.md`). These notes feed Phase 3 (`rpcs3/util/vm_native.cpp`,
`Utilities/Thread.cpp`).

## Rules from PS5SX2

1. **Plain `mmap` fails in a native title.** In the "bigapp" sandbox, anonymous `mmap` returns
   `MAP_FAILED` (`ps5/coreorbis/orbis-shims/mmapshim.cpp`). The shim backs it with
   `sceKernelMapFlexibleMemory`, which draws on the flexible budget (448 MiB, set by
   `kernel.flexibleMemorySize` in param.json). Flexible mappings **cannot be mprotected afterwards
   and cannot be aliased**, so they are fine for the heap and stacks but useless for guest memory.
2. **Guest memory lives in direct memory** (`pcsx2/Memory.cpp`):
   `sceKernelAllocateDirectMemory(0, sceKernelGetDirectMemorySize(), len, 16 KiB, type 12, &phys)`,
   then `sceKernelMapDirectMemory(&addr, len, prot 0x33 /*CPU+GPU RW*/, 0, phys, align)`.
3. **Aliased views replace `shm_open` and `memfd`** (`common/Linux/LnxHostSys.cpp`,
   `SharedMemoryMappingArea`):
   - Reserve the whole area with `sceKernelReserveVirtualRange(&addr, size, 0, 0)`.
   - Map each view with `sceKernelMapDirectMemory(&view, n, prot, MAP_FIXED=0x10, phys + off, 16 KiB)`.
     The kernel lets one direct-memory range be mapped at several addresses.
   - To unmap, call `sceKernelMunmap`, then `sceKernelReserveVirtualRange(..., MAP_FIXED)` again so
     nothing else lands in the hole.
   - RPCS3 relies on exactly this: `g_base_addr` and `g_sudo_addr` are two views of one `utils::shm`.
4. **Keep the GPU window free.** RADV's GPU-visible memory must sit in
   `[0x2_0000_0000, 0x3_0000_0000)`. An unhinted reservation goes first-fit from there, steals the
   window, and `vkCreateDevice` then fails with `VK_ERROR_OUT_OF_DEVICE_MEMORY`. Always pass hints
   above it. PS5SX2 uses 0x3_0000_0000 for fastmem, 0x6_0000_0000 for guest data and
   0x9_0000_0000 for code. The RPCS3 spec measured: at most 15 GiB from 0x4_0000_0000; 16 GiB at
   the hint from 0x10_0000_0000 to 0x80_0000_0000; nothing at or above 1 TiB; a hint with too
   little free space is refused, not moved.
5. **JIT code** has two routes:
   - `sceKernelJitCreateSharedMemory(0, len, 7, &fd)` plus `sceKernelJitMapSharedMemory(fd, 7, &p)`
     gives RWX, but it comes out of the flexible budget.
   - Direct memory mapped RW (`0x03`) and then `sceKernelMprotect(p, len, 0x07)` works too, and does
     not use the flexible budget. PS5SX2 calls this "jitdirect". Use 2 MiB alignment for large
     pages. The RPCS3 spec measured about 26 µs per protection change.
6. **Signal mcontext offset.** On PS5 the mcontext starts at `ucontext + 0x40`, not FreeBSD's
   `+ 0x10`. Reading `uc_mcontext.mc_rip` through FreeBSD's struct actually reads r14. Field
   offsets relative to the mcontext: `mc_rbp` 0x48, `mc_addr` 0x88, `mc_err` 0x98, `mc_rip` 0xa0,
   `mc_rsp` 0xb8. RPCS3's access-violation handler in `Utilities/Thread.cpp` needs this fix (or the
   SDK fork's corrected `sys/_ucontext.h`).
7. Pages are 16 KiB.

## RPCS3's needs against this model

| RPCS3 | Size | PS5 approach |
| --- | --- | --- |
| `g_base_addr` + `g_sudo_addr` (the same shm twice) | 4 GiB + 4 GiB | one direct-memory block, mapped as two fixed views inside a reservation at or above 0x10_0000_0000 |
| `g_exec_addr` | 12 GiB | reserve, then commit direct memory on demand |
| `g_hook_addr` | 32 GiB | reservation only (the spec: nothing reads it) |
| `g_stat_addr` / `g_free_addr` | 4 GiB+ | reserve, then commit on demand |
| asmjit and LLVM code | 2 GiB plus 768 MiB per manager | jitdirect (direct memory with mprotect RWX), growing on demand |
| RSX mappings and Vulkan | | must stay out of `[0x2_0000_0000, 0x3_0000_0000)` |

The "PS5 has 16 GiB of shared GDDR" budget is the real ceiling: committed guest memory, JIT code and
GPU allocations all come out of direct memory.

## Thread-local storage (performance risk)

- The SDK's `prospero-clang` wrapper always passes **`-femulated-tls`**. Every `thread_local` access
  therefore goes through `__emutls_get_address`, a function call plus a lookup.
- (No longer applies: PR #19444 was dropped on 2026-10-06 and the port is on plain upstream, where these are ordinary globals. Kept for reference.) PR #19444 turned `vm::g_base_addr`, `g_sudo_addr`, `g_exec_addr`, `g_hook_addr`, `g_stat_addr`,
  `g_vm_image`, `g_tls_locked` and `rsx::method_registers` into `thread_local` variables, and
  `vm::_ptr`, `vm::_ref` and `vm::read/write` dereference `g_base_addr` on every guest access in
  HLE, interpreter and RSX code. Recompiled PPU/SPU code takes the base from a register, so it is
  less affected.
- Options, to measure once the core runs:
  1. Check whether native titles support real PT_TLS (the earlier libretro port lacked it only
     because of its core loader). If they do, build RPCS3 without `-femulated-tls`.
  2. Otherwise cache the bases in a per-thread structure that `cpu_thread` already carries, as
     the prior-art spec suggests for `g_tls_this_thread` and `g_tls_locked`.
