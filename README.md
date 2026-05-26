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
| [run-rocm.sh](run-rocm.sh) | Launch `llama-server` (ROCm) on port 8080 |
| [run-vulkan.sh](run-vulkan.sh) | Launch `llama-server` (Vulkan) on port 8080 |

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

Both scripts take the model path (relative to the host models dir, default `/data/models`) as the first argument, mount it read-only at `/models` in the container, and expose `llama-server` on `http://localhost:8080`. Anything after the model path is passed straight through to `llama-server`.

```sh
./run-rocm.sh glm-4.7-flash/GLM-4.7-Flash-Q4_K_M.gguf
./run-vulkan.sh glm-4.7-flash/GLM-4.7-Flash-Q4_K_M.gguf

# Pass extra llama-server flags after the model path
./run-rocm.sh path/to/model.gguf --temp 0.7 --top-p 0.9

# Override defaults via env
MODELS_DIR=/mnt/llm PORT=9090 CTX_SIZE=8192 ./run-vulkan.sh mistral/mistral-7b-instruct-q4_k_m.gguf
```

Env overrides supported by both scripts: `MODELS_DIR`, `PORT`, `IMAGE`, `CTX_SIZE`, `UBATCH`, `BATCH`, `THREADS`.

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
