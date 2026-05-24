#!/usr/bin/bash
set -euo pipefail

# Usage: ./run-vulkan.sh <model-path-relative-to-MODELS_DIR> [extra llama-server args...]
#
# Env overrides:
#   MODELS_DIR   host dir mounted read-only at /models   (default: /data/models)
#   PORT         host port to expose llama-server on     (default: 8080)
#   IMAGE        container image to run                  (default: llama-strix-halo:vulkan)
#   CTX_SIZE     --ctx-size                              (default: 131072)
#   UBATCH       --ubatch-size                           (default: 1024)
#   BATCH        --batch-size                            (default: 4096)
#   THREADS      --threads                               (default: 8)

if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <model-path> [extra llama-server args...]" >&2
    echo "  <model-path> is relative to MODELS_DIR (default /data/models)" >&2
    echo "  e.g.: $0 glm-4.7-flash/GLM-4.7-Flash-Q4_K_M.gguf" >&2
    exit 1
fi

MODEL="$1"; shift
MODELS_DIR="${MODELS_DIR:-/data/models}"
PORT="${PORT:-8080}"
IMAGE="${IMAGE:-llama-strix-halo:vulkan}"
CTX_SIZE="${CTX_SIZE:-131072}"
UBATCH="${UBATCH:-1024}"
BATCH="${BATCH:-4096}"
THREADS="${THREADS:-8}"

podman run --rm -it \
    --device /dev/dri \
    --group-add keep-groups \
    --security-opt no-new-privileges \
    --cap-drop=ALL \
    --ulimit memlock=-1:-1 \
    -v "${MODELS_DIR}:/models:ro,z" \
    -p "${PORT}:8080" \
    "${IMAGE}" \
    -m "/models/${MODEL}" \
    -ngl 999 \
    -fit off \
    --ctx-size "${CTX_SIZE}" \
    --parallel 1 \
    -fa on \
    --cache-type-k q8_0 \
    --cache-type-v q8_0 \
    --ubatch-size "${UBATCH}" \
    --batch-size "${BATCH}" \
    --threads "${THREADS}" \
    --no-mmap \
    --jinja \
    --host 0.0.0.0 \
    --port 8080 \
    "$@"
