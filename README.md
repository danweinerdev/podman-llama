# podman-llama

Rootless Podman containers for running [llama.cpp](https://github.com/ggerganov/llama.cpp) on AMD **Strix Halo** (Radeon 8060S / `gfx1151`, e.g. Ryzen AI Max / Minisforum MS-1 Max).

Two backends are provided:

- **ROCm/HIP** — best performance when the kernel/ROCm stack cooperates.
- **Vulkan (RADV)** — ~80–90% of ROCm throughput, works on kernels where ROCm is broken (e.g. 7.0.x KFD regression, see [ROCm#6182](https://github.com/ROCm/ROCm/issues/6182)).

## Files

| File | Purpose |
| --- | --- |
| [Containerfile.rocm](Containerfile.rocm) | Multi-stage Fedora 44 build of llama.cpp w/ ROCm/HIP + UMA, tuned for `gfx1151` |
| [Containerfile.vulkan](Containerfile.vulkan) | Multi-stage Fedora 44 build of llama.cpp w/ Vulkan via Mesa RADV |
| [Makefile](Makefile) | `make build-rocm` / `make build-vulkan` / `make all` |
| [runtime/rocm/run-rocm.sh](runtime/rocm/run-rocm.sh) | Generic `llama-server` launcher (ROCm) — no per-model logic |
| [runtime/vulkan/run-vulkan.sh](runtime/vulkan/run-vulkan.sh) | Generic `llama-server` launcher (Vulkan) — no per-model logic |
| [profiles/](profiles/) | Per-GPU env config: `profiles/<MACHINE>/default.env` (card defaults) + optional `profiles/<MACHINE>/<model>.env` (GPU-specific fit tuning) |
| [models/](models/) | Per-model env config, model-intrinsic only (path, sampling) |
| [commands.txt](commands.txt) | Model download + launch cheatsheet |

## Build

```sh
make build-rocm     # → llama-strix-halo:rocm
make build-vulkan   # → llama-strix-halo:vulkan
make                # both
```

Override the upstream llama.cpp ref:

```sh
podman build --build-arg LLAMA_TAG=b4400 -t llama-strix-halo:rocm -f Containerfile.rocm .
```

## Run

Machines are supported via env **profiles** in [profiles/](profiles/):

| `MACHINE` | Hardware | Backend | Key tuning |
| --- | --- | --- | --- |
| `r9700` | 1× Radeon AI PRO R9700 (gfx1201, RDNA4, 32 GiB VRAM) | ROCm | native gfx1201, discrete-GPU pinning, ctx 32k |
| `r9700-dual` | 2× Radeon AI PRO R9700 (~62 GiB VRAM total) | Vulkan | multi-GPU `--tensor-split`, all-VRAM (no CPU-MoE), e.g. Qwen-Next Q4_1 @ 256k |
| `strixhalo` | Ryzen AI Max+ 395 (gfx1151, unified mem) | Vulkan | `HSA_OVERRIDE=11.5.1` + UMA (ROCm), ctx 128k |

The run scripts are **generic**: they contain no per-model logic. Both `runtime/rocm/run-rocm.sh` and `runtime/vulkan/run-vulkan.sh` take a model **config name** (or a raw `.gguf` path), inject up to three env files, mount the models dir read-only, and expose `llama-server` on `http://localhost:8080`:

- `models/<name>.env` — **model-intrinsic** config only: weight path + sampling flags.
- `profiles/<MACHINE>/<name>.env` — *optional* **GPU-specific fit** for that model on that card (context, ubatch, KV quant, CPU-MoE offload, split). Absent ⇒ the card defaults are used as-is.
- `profiles/<MACHINE>/default.env` — **card / machine defaults** (GFX override, UMA, device pinning, split, ctx/batch baseline).

The split keeps model identity separate from hardware fit: the same `models/<name>.env` runs on every card, and each card decides how to make it fit via its own per-model profile.

Set your machine once in `~/.bashrc` / `~/.zshrc`, then name the model:

```sh
export PODMAN_LLAMA_MACHINE=r9700        # or strixhalo, r9700-dual

./runtime/rocm/run-rocm.sh glm-4.7-flash
./runtime/rocm/run-rocm.sh qwen3-27b --temp 0.7 --top-p 0.9   # extra flags pass through, last wins
```

Or select the machine per-invocation (overrides the global), and run any model on either backend:

```sh
MACHINE=strixhalo  ./runtime/vulkan/run-vulkan.sh qwen3-coder-next
MACHINE=r9700-dual ./runtime/vulkan/run-vulkan.sh qwen3-coder-next-q4   # Qwen-Next Q4_1 across both R9700s @ 256k
MACHINE=r9700      ./runtime/rocm/run-rocm.sh SomeModel/model.gguf --ctx-size 8192   # raw path
```

**Precedence** (highest first): trailing CLI args > inline `MACHINE=…` / `CTX_SIZE=…` > `PODMAN_LLAMA_*` global > `models/<name>.env` > `profiles/<MACHINE>/<name>.env` > `profiles/<MACHINE>/default.env` > built-in default.

(Env files use `:=` "set if unset", so the **first** assignment of each var wins. The launchers source in precedence order — model env, then per-model profile, then card default — so earlier files pin a value and later ones only fill gaps.)

Overridable vars (inline or `PODMAN_LLAMA_`-prefixed global): `MACHINE`, `MODELS_DIR`, `PORT`, `IMAGE` (`PODMAN_LLAMA_ROCM_IMAGE`/`_VULKAN_IMAGE`), `CTX_SIZE`, `UBATCH`, `BATCH`, `THREADS`, `GPU_INDEX` (Vulkan), plus `CACHE_TYPE_K`, `CACHE_TYPE_V`, `FLASH_ATTN`, `PARALLEL`, `N_CPU_MOE`. See [commands.txt](commands.txt) for the full model list and download commands.

### Per-model tuning

A model's identity (weight path + sampling) lives in [`models/<name>.env`](models/); how it *fits a given card* (context, ubatch, KV quant, CPU-MoE offload, multi-GPU split) lives in [`profiles/<MACHINE>/<name>.env`](profiles/) when the card needs model-specific tuning. The launchers apply no per-model defaults themselves. Retune by editing the relevant `.env`; no script changes needed. Any flag you append on the command line is passed to `llama-server` **after** both, so it overrides (last occurrence wins).

Passing a raw `.gguf` path instead of a config name skips **both** the model env and the per-model profile — only `profiles/<MACHINE>/default.env` and CLI flags apply.

| Model | KV cache | Sampling | Why |
| --- | --- | --- | --- |
| gpt-oss-20b | `f16` | `temp 1.0, top-p 1.0`, `--reasoning-format auto` | MXFP4 weights + sliding-window layers lose quality under KV quant; OpenAI's recommended sampling |
| Qwen3.6-27B | `q8_0` | `temp 0.6, top-p 0.95, top-k 20, min-p 0`, `presence-penalty 1.0` | Qwen3 thinking-mode defaults; presence penalty curbs looping |
| GLM-4.7-Flash | `q8_0` | `temp 0.7, top-p 1.0, min-p 0.01` | Zhipu's recommended sampling |
| Devstral-24B | `q8_0` | `temp 0.15, top-p 1.0` | near-deterministic output for coding/agentic use |
| Qwen3-Coder-Next | `q8_0` | `temp 0.7, top-p 0.8, top-k 20, repeat-penalty 1.05` | 80B MoE (~46 GiB) → `--n-cpu-moe 40`; Strix Halo only |

> On AMD (both ROCm and Vulkan/RADV) the fused flash-attention kernel only engages when K and V use the **same** cache type. Keep `CACHE_TYPE_K == CACHE_TYPE_V`; the wrappers already do.

## Host prerequisites

User must be in the `render` and `video` groups:

```sh
sudo usermod -aG render,video $USER
```

For large GTT allocations on Strix Halo, add to `GRUB_CMDLINE_LINUX` in `/etc/default/grub`:

```
iommu=pt amdgpu.gttsize=126976 ttm.pages_limit=32505856
```

then `sudo grub2-mkconfig -o /boot/grub2/grub.cfg && sudo reboot`.

### memlock ceiling (rootless podman)

Rootless containers inherit the systemd **user** session's `LimitMEMLOCK` (8 MiB by default), and `--ulimit memlock=-1:-1` cannot raise it above that. With `--no-mmap` (which locks the whole model in host RAM) this fails on multi-GB models. Two options:

- **Leave mmap on** (default for the `r9700` profile, `NO_MMAP=0`) — the GGUF is mmap-ed from the read-only mount, so the memlock ceiling doesn't matter.
- **Raise the ceiling** (needed if you want `--no-mmap`, and the default for `strixhalo`):

  ```sh
  sudo mkdir -p /etc/systemd/system/user@.service.d
  printf '[Service]\nLimitMEMLOCK=infinity\n' | sudo tee /etc/systemd/system/user@.service.d/memlock.conf
  sudo systemctl daemon-reload
  # log out and back in (restarts user@$UID.service), then check: ulimit -l  →  unlimited
  ```

## Notes

- ROCm image sets `HSA_OVERRIDE_GFX_VERSION=11.5.1` and enables UMA — required for `gfx1151`.
- Vulkan image only needs `/dev/dri` (no `/dev/kfd`).
- `--no-mmap` is opt-in per profile (`NO_MMAP`): on for `strixhalo` (predictable unified-memory allocation), off for `r9700` (mmap avoids the rootless memlock ceiling on dedicated VRAM). See the memlock note above.
- On kernel **7.0.x** the ROCm/KFD path can throw `Memory critical error … Reason: Memory in use` on model load ([ROCm#6182](https://github.com/ROCm/ROCm/issues/6182)). Use the Vulkan runtime (no `/dev/kfd`) until you move to a fixed kernel.
- Containers run as a non-root user (`llama`, uid 1000) with `--cap-drop=ALL` and `--security-opt no-new-privileges`.
