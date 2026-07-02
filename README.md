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
| [profiles/](profiles/) | Per-card / per-machine env config (`r9700.env`, `strixhalo.env`) |
| [models/](models/) | Per-model env config (path, sampling, KV cache, `n-cpu-moe`) |
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

Two machines are supported via env **profiles** in [profiles/](profiles/):

| `MACHINE` | Hardware | Backend | Key tuning |
| --- | --- | --- | --- |
| `r9700` | Radeon AI PRO R9700 (gfx1201, RDNA4, 32 GiB VRAM) | ROCm | native gfx1201, discrete-GPU pinning, ctx 32k |
| `strixhalo` | Ryzen AI Max+ 395 (gfx1151, unified mem) | Vulkan | `HSA_OVERRIDE=11.5.1` + UMA (ROCm), ctx 128k |

The run scripts are **generic**: they contain no per-model logic. Both `runtime/rocm/run-rocm.sh` and `runtime/vulkan/run-vulkan.sh` take a model **config name** (or a raw `.gguf` path), inject two env files, mount the models dir read-only, and expose `llama-server` on `http://localhost:8080`:

- `profiles/<MACHINE>.env` — card / machine config (GFX override, UMA, device pinning, ctx/batch).
- `models/<name>.env` — per-model config (model path, sampling flags, KV cache type, `n-cpu-moe`).

Set your machine once in `~/.bashrc` / `~/.zshrc`, then name the model:

```sh
export PODMAN_LLAMA_MACHINE=r9700        # or strixhalo

./runtime/rocm/run-rocm.sh glm-4.7-flash
./runtime/rocm/run-rocm.sh qwen3-27b --temp 0.7 --top-p 0.9   # extra flags pass through, last wins
```

Or select the machine per-invocation (overrides the global), and run any model on either backend:

```sh
MACHINE=strixhalo ./runtime/vulkan/run-vulkan.sh qwen3-coder-next
MACHINE=r9700     ./runtime/rocm/run-rocm.sh SomeModel/model.gguf --ctx-size 8192   # raw path
```

**Precedence** (highest first): trailing CLI args > inline `MACHINE=…` / `CTX_SIZE=…` > `PODMAN_LLAMA_*` global > `models/<name>.env` > `profiles/<MACHINE>.env` > built-in default.

Overridable vars (inline or `PODMAN_LLAMA_`-prefixed global): `MACHINE`, `MODELS_DIR`, `PORT`, `IMAGE` (`PODMAN_LLAMA_ROCM_IMAGE`/`_VULKAN_IMAGE`), `CTX_SIZE`, `UBATCH`, `BATCH`, `THREADS`, `GPU_INDEX` (Vulkan), plus `CACHE_TYPE_K`, `CACHE_TYPE_V`, `FLASH_ATTN`, `PARALLEL`, `N_CPU_MOE`. See [commands.txt](commands.txt) for the full model list and download commands.

### Per-model tuning

Each model's sampling and KV-cache flags live in [`models/<name>.env`](models/) — the launchers apply no per-model defaults themselves. Edit a model's `.env` to retune it; no script changes needed. Any flag you append on the command line is passed to `llama-server` **after** the model env's, so it overrides (last occurrence wins).

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

## Notes

- ROCm image sets `HSA_OVERRIDE_GFX_VERSION=11.5.1` and enables UMA — required for `gfx1151`.
- Vulkan image only needs `/dev/dri` (no `/dev/kfd`).
- `--ulimit memlock=-1:-1` and `--no-mmap` are recommended on Strix Halo for predictable allocation.
- Containers run as a non-root user (`llama`, uid 1000) with `--cap-drop=ALL` and `--security-opt no-new-privileges`.
