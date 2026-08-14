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
| `r9700-dual` | 2× Radeon AI PRO R9700 (~62 GiB VRAM total) | Vulkan | multi-GPU `--tensor-split`, all-VRAM (no CPU-MoE), e.g. Qwen-Next UD-Q4_K_XL @ 256k |
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
MACHINE=r9700-dual ./runtime/vulkan/run-vulkan.sh qwen3-coder-next-q4   # Qwen-Next UD-Q4_K_XL across both R9700s @ 256k
MACHINE=r9700      ./runtime/rocm/run-rocm.sh SomeModel/model.gguf --ctx-size 8192   # raw path
```

**Precedence** (highest first): trailing CLI args > inline `MACHINE=…` / `CTX_SIZE=…` > `PODMAN_LLAMA_*` global > `models/<name>.env` > `profiles/<MACHINE>/<name>.env` > `profiles/<MACHINE>/default.env` > built-in default.

(Env files use `:=` "set if unset", so the **first** assignment of each var wins. The launchers source in precedence order — model env, then per-model profile, then card default — so earlier files pin a value and later ones only fill gaps.)

Overridable vars (inline or `PODMAN_LLAMA_`-prefixed global): `MACHINE`, `MODELS_DIR`, `PORT`, `IMAGE` (`PODMAN_LLAMA_ROCM_IMAGE`/`_VULKAN_IMAGE`), `CTX_SIZE`, `UBATCH`, `BATCH`, `THREADS`, `GPU_INDEX` (Vulkan), `METRICS`, plus `CACHE_TYPE_K`, `CACHE_TYPE_V`, `FLASH_ATTN`, `PARALLEL`, `N_CPU_MOE`.

### Watching a running server

Both launchers pass `--metrics` by default, so `llama-server` exposes a Prometheus endpoint. Set `METRICS=0` to turn it off (upstream's own default is disabled — without the flag `/metrics` answers `501`).

| Endpoint | Needs a flag? | Use |
| --- | --- | --- |
| `/metrics` | `--metrics` (on by default here) | Prometheus counters: `llamacpp:prompt_tokens_total`, `llamacpp:tokens_predicted_total`, `llamacpp:kv_cache_usage_ratio`, slot counts. For scraping/Grafana. |
| `/slots` | no (on upstream by default) | Live per-slot state: `is_processing`, `n_prompt_tokens`, `n_decoded`, `n_ctx`. For watching one session. |
| `/props` | no | Static config readback — confirm split mode, context, and sampling actually took effect. |
| `/health` | no | Liveness. |

[`scripts/llama-watch.sh`](scripts/llama-watch.sh) polls `/slots` and redraws a status block **in place** each interval, so the terminal shows current state instead of a scrolling log:

```sh
scripts/llama-watch.sh          # 2s against http://127.0.0.1:8080
scripts/llama-watch.sh 5 http://otherhost:8080
```

```
llama-watch  http://127.0.0.1:8080  every 3s  16:12:07
  slot 0  BUSY    15.0 tok/s
  ████████████░░░░░░░░░░░░░░░░  109136/262144 (41.6% of ctx)
  prompt 108818   processed 108501
  decoded 318      remaining 31682
```

The tok/s figure is derived by differencing `n_decoded` between polls — `/slots` reports counters, not a rate — so it is a one-interval average and will jitter; the rate `llama-server` logs at the end of a request is authoritative.

Note that `/slots` is served from the same thread that runs inference, so a busy server answers it only between batches (measured 3–5.5 s latency, and occasional connection failures, while decoding at 262K). The script allows a generous timeout and shows a `stale xN` marker rather than flashing "unreachable" on one slow poll.

See [commands.txt](commands.txt) for the full model list and download commands.

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
| Qwen3.8-27B (thinking) | `q8_0` | `temp 1.0, top-p 0.95, top-k 20, min-p 0, presence 0` | Qwen thinking-mode recipe (matches the GGUF's own `general.sampling.*`); thinking is on by default |
| Qwen3.8-27B (instruct) | `q8_0` | `temp 0.7, top-p 0.80, top-k 20, min-p 0, presence 1.5` | Qwen non-thinking recipe; the high presence penalty is what suppresses loops without a thinking pass |

> On AMD (both ROCm and Vulkan/RADV) the fused flash-attention kernel only engages when K and V use the **same** cache type. Keep `CACHE_TYPE_K == CACHE_TYPE_V`; the wrappers already do.

### Qwen3.8-27B config matrix

Hybrid-attention VL model, arch `qwen35`, native context 262,144. Only 16 of its 65 blocks are full attention (`full_attention_interval 4`); the other 48 are Gated DeltaNet and hold a constant-size SSM state instead of per-token KV. KV therefore costs **~34 KiB/token** at `q8_0` (16 × 4 KV heads × 256 head_dim × K+V), so 262K ≈ 8.5 GiB.

| Config | Weights | `r9700` | `r9700-dual` | `strixhalo` |
| --- | --- | --- | --- | --- |
| `qwen3.8-27b` | BF16, 50.9 GiB | — | 131,072 — the practical BF16 ceiling here | **262,144** — flagship placement |
| `qwen3.8-27b-q8` | UD-Q8_K_XL, 29.3 GiB | — (no room for KV) | **262,144**, ~22 GiB slack | — (use BF16) |
| `qwen3.8-27b-q4` | UD-Q4_K_XL, 16.7 GiB | **262,144** on one card | — | — |
| `qwen3.8-27b-1m` | BF16 + YaRN ×4 | — | — | **1,048,576** (~88 GiB) |
| `qwen3.8-27b-instruct` | UD-Q8_K_XL | — | 262,144 | 262,144 |
| `qwen3.8-27b-instruct-q4` | UD-Q4_K_XL | 262,144 | — | — |

Why the gaps: BF16 at 262,144 on the pair needs ~62 GiB against a ~62 GiB ceiling — no margin for fragmentation or an uneven layer split, hence 131,072 there. Q8 is 29.3 GiB of weights alone, so on a single 31 GiB card nothing is left for KV; Q4 is what makes one card work. Only Strix Halo's 108 GiB holds BF16 weights *and* a 34 GiB 1M cache.

Download commands are in [commands.txt](commands.txt); the budgets above are arithmetic, not measured.

**Split mode on `r9700-dual`:** these profiles override the card default to `--split-mode row`. Layer mode assigns whole layers per card, so a *dense* model leaves one card idle while the other computes; row mode splits each tensor so both work at once. Measured on the Q8 config — prefill 74.23 → 98.56 t/s (**+32.8%**), decode 15.75 → 17.24 t/s (**+9.5%**) — and it relieves a VRAM imbalance that left GPU[0] at 97% allocated vs GPU[1] at 68%. Decode gains little because single-stream decode is bandwidth-bound: ~29.3 GiB of Q8 weights per token against ~640 GB/s caps a single card near 21 t/s, so 17.24 is ~82% of the practical ceiling. The Coder-Next profiles deliberately stay on `layer` (80B MoE, ~3B active — different traffic pattern, untested). Override inline with `SPLIT_MODE=layer`.

```bash
MACHINE=strixhalo  ./runtime/vulkan/run-vulkan.sh qwen3.8-27b        # BF16 @ 262K
MACHINE=strixhalo  ./runtime/vulkan/run-vulkan.sh qwen3.8-27b-1m     # YaRN x4 @ 1M
MACHINE=r9700-dual ./runtime/vulkan/run-vulkan.sh qwen3.8-27b-q8     # Q8 across both cards @ 262K
MACHINE=r9700      ./runtime/vulkan/run-vulkan.sh qwen3.8-27b-q4     # Q4 on one card @ 262K
```

Two things the CLI cannot control, because they live in the chat template:

- **Thinking is on by default** and emits `<think>…</think>` before the answer. Disabling it requires `chat_template_kwargs: {"enable_thinking": false}` **per request** — the `-instruct` configs only change sampling, so pairing them with a client that doesn't send that flag gives you thinking output under instruct sampling, which is the worst of both.
- **`reasoning_effort`** (`xhigh` default / `medium` / `low`) and **`preserve_thinking`** are likewise request-side. Lowering `reasoning_effort` does not reliably cut agentic latency; shallower analysis just causes retries.

Vision (image + video) is native but needs the multimodal projector, so every config passes `--mmproj` — BF16 weights pair with `mmproj-BF16.gguf`, quantized weights with `mmproj-F16.gguf`. Without it the server is text-only.

> Unlike the other models here, these quants sit at the model directory root rather than in per-quant subfolders; only the BF16 shards live in `BF16/`.

### Concurrency vs. context length

`--parallel` (env `PARALLEL`, default `1`) sets how many request slots `llama-server` allocates — but it **splits** the KV cache configured by `CTX_SIZE` across those slots rather than multiplying it. Each slot gets `CTX_SIZE / PARALLEL` context, and total VRAM cost scales with `CTX_SIZE x PARALLEL`, not per slot. There is no way to give N concurrent requests each the full configured context from one `llama-server` instance.

With `PARALLEL=1` (the default everywhere in this repo), a single slot serves the entire configured context to one request at a time; a second request arriving mid-generation queues at the HTTP layer and waits — it does not error, it just adds latency. Raising `PARALLEL` trades that queuing delay for reduced context per request (e.g. `PARALLEL=2` on a 256K-context profile caps each request at ~128K).

For large-context models like Qwen3-Coder-Next on `r9700-dual` (see [`profiles/r9700-dual/qwen3-coder-next-q4.env`](profiles/r9700-dual/qwen3-coder-next-q4.env)), VRAM is already nearly fully consumed by one instance's weights + full-context KV cache, so running a second full-context instance for true multi-session parallelism isn't feasible on this hardware — one session at a time, at full context, is the practical ceiling.

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
