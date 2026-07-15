#!/usr/bin/bash
set -euo pipefail

# Generic Vulkan (RADV) llama-server launcher.
#
# All tuning lives in injectable env files, none in this script:
#   - model-intrinsic config -> models/<MODEL_CONF>.env             (model path, sampling, n-cpu-moe)
#   - GPU-specific model fit  -> profiles/<MACHINE>/<MODEL_CONF>.env (optional: ctx/ubatch/KV to fit this model on this card)
#   - card / machine defaults -> profiles/<MACHINE>/default.env     (device selection, split, ctx/batch baseline)
# Vulkan ignores the ROCm-only GFX/UMA profile values.
#
# Usage:
#   MACHINE=<machine> ./run-vulkan.sh <model-conf>            # named model, e.g. qwen3-coder-next
#   MACHINE=<machine> ./run-vulkan.sh <path/to/model.gguf>    # raw path (no model env file)
# Anything after the model arg is passed straight through to llama-server and overrides
# both the model env file and the launcher (llama-server takes the last occurrence).
#
# Precedence (highest first): trailing CLI args > inline env > model env
#   > profiles/<MACHINE>/<model>.env > profiles/<MACHINE>/default.env > built-in.
# (Env files use `:=`, so the FIRST source of each var wins; sourcing order below
#  matches this precedence -- model env, then per-model profile, then card default.)

if [[ $# -lt 1 ]]; then
    echo "Usage: MACHINE=<machine> $0 <model-conf|model-path> [extra llama-server args...]" >&2
    echo "  <model-conf> names models/<name>.env; a value ending in .gguf is used as a raw path." >&2
    echo "  model configs: $(cd "$(dirname "${BASH_SOURCE[0]}")/../../models" 2>/dev/null && ls *.env 2>/dev/null | sed 's/\.env$//' | paste -sd' ')" >&2
    exit 1
fi

MODEL_ARG="$1"; shift

# Resolve repo root so the script works from anywhere.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Extra llama-server args accumulate here: model env files append their sampling flags,
# then the trailing CLI args are added last (so they win).
LLAMA_ARGS=()

# Apply PODMAN_LLAMA_*-prefixed globals as fallbacks (see runtime/rocm/run-rocm.sh).
fallback() { local cur="${!1:-}" src="${!2:-}"; [[ -z "$cur" && -n "$src" ]] && printf -v "$1" '%s' "$src"; return 0; }
fallback MACHINE    PODMAN_LLAMA_MACHINE
fallback MODELS_DIR PODMAN_LLAMA_MODELS_DIR
fallback PORT       PODMAN_LLAMA_PORT
fallback IMAGE      PODMAN_LLAMA_VULKAN_IMAGE
fallback CTX_SIZE   PODMAN_LLAMA_CTX_SIZE
fallback UBATCH     PODMAN_LLAMA_UBATCH
fallback BATCH      PODMAN_LLAMA_BATCH
fallback THREADS    PODMAN_LLAMA_THREADS
fallback GPU_INDEX  PODMAN_LLAMA_GPU_INDEX
fallback N_CPU_MOE  PODMAN_LLAMA_N_CPU_MOE

# --- inject per-model config -------------------------------------------------
if [[ "$MODEL_ARG" != *.gguf && -f "${REPO_ROOT}/models/${MODEL_ARG}.env" ]]; then
    # shellcheck disable=SC1090
    source "${REPO_ROOT}/models/${MODEL_ARG}.env"
elif [[ "$MODEL_ARG" == *.gguf ]]; then
    MODEL="$MODEL_ARG"
else
    echo "Unknown model config '${MODEL_ARG}': no models/${MODEL_ARG}.env (and not a .gguf path)" >&2
    echo "Available: $(cd "${REPO_ROOT}/models" && ls *.env | sed 's/\.env$//' | paste -sd' ')" >&2
    exit 1
fi

# --- inject card / machine config --------------------------------------------
# Each GPU type is a directory: profiles/<MACHINE>/default.env holds card-generic
# settings, and an optional profiles/<MACHINE>/<model>.env holds tuning to fit that
# specific model on this card. The per-model profile is sourced BEFORE default.env
# so its `:=` values win over the card defaults (but CLI/env, sourced earlier, win
# over both).
MACHINE="${MACHINE:-strixhalo}"
PROFILE_DIR="${REPO_ROOT}/profiles/${MACHINE}"
PROFILE="${PROFILE_DIR}/default.env"
if [[ ! -f "$PROFILE" ]]; then
    echo "Unknown MACHINE='${MACHINE}': no profile at ${PROFILE}" >&2
    echo "Available: $(cd "${REPO_ROOT}/profiles" && ls -d */ 2>/dev/null | sed 's#/##' | paste -sd' ')" >&2
    exit 1
fi
# Optional GPU-specific per-model overrides (skipped for raw .gguf paths).
if [[ "$MODEL_ARG" != *.gguf && -f "${PROFILE_DIR}/${MODEL_ARG}.env" ]]; then
    # shellcheck disable=SC1090
    source "${PROFILE_DIR}/${MODEL_ARG}.env"
fi
# shellcheck disable=SC1090
source "$PROFILE"

# Trailing CLI args go last so they override everything above.
LLAMA_ARGS+=("$@")

MODELS_DIR="${MODELS_DIR:-/data/models}"
PORT="${PORT:-8080}"
IMAGE="${IMAGE:-llama-strix-halo:vulkan}"

# Attention / KV-cache knobs (model env may have set these; fall back to sane defaults).
FLASH_ATTN="${FLASH_ATTN:-on}"
CACHE_TYPE_K="${CACHE_TYPE_K:-q8_0}"
CACHE_TYPE_V="${CACHE_TYPE_V:-q8_0}"
PARALLEL="${PARALLEL:-1}"

# On multi-GPU hosts (e.g. R9700 discrete + iGPU) pin RADV to a device index.
env_args=()
[[ -n "${GPU_INDEX:-}" ]] && env_args+=(-e "GGML_VK_VISIBLE_DEVICES=${GPU_INDEX}")

# --no-mmap is opt-in per profile (NO_MMAP=1). Defaults on for Strix Halo (unified mem),
# off for dedicated-VRAM cards where the rootless memlock ceiling would bite.
mmap_args=()
[[ "${NO_MMAP:-0}" == "1" ]] && mmap_args+=(--no-mmap)

podman run --rm -it \
    --device /dev/dri \
    --group-add keep-groups \
    --security-opt no-new-privileges \
    --cap-drop=ALL \
    --ulimit memlock=-1:-1 \
    --name llama-server --network llama \
    "${env_args[@]}" \
    -v "${MODELS_DIR}:/models:ro,z" \
    -p "${PORT}:8080" \
    "${IMAGE}" \
    -m "/models/${MODEL}" \
    -ngl 999 \
    -fit off \
    --ctx-size "${CTX_SIZE}" \
    --parallel "${PARALLEL}" \
    -fa "${FLASH_ATTN}" \
    --cache-type-k "${CACHE_TYPE_K}" \
    --cache-type-v "${CACHE_TYPE_V}" \
    --ubatch-size "${UBATCH}" \
    --batch-size "${BATCH}" \
    --threads "${THREADS}" \
    "${mmap_args[@]}" \
    --jinja \
    --host 0.0.0.0 \
    --port 8080 \
    "${LLAMA_ARGS[@]}"
