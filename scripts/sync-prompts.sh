#!/usr/bin/bash
# sync-prompts.sh -- capture the live opencode prompts for Qwen3-Coder-Next
# into prompts/qwen3-coder-next/ so prompt state is tracked next to the
# server config that runs the model. Run after editing either source file;
# commit the result.
set -euo pipefail

SRC_APPEND="$HOME/.config/opencode/APPEND_SYSTEM.md"
SRC_AGENT="$HOME/.config/opencode/agent/qwen-local.md"
DST="$(dirname "$(realpath "$0")")/../prompts/qwen3-coder-next"

mkdir -p "$DST"
cp "$SRC_APPEND" "$DST/APPEND_SYSTEM.md"
cp "$SRC_AGENT"  "$DST/qwen-local.agent.md"

echo "captured $(date -Idate):"
for f in "$DST/APPEND_SYSTEM.md" "$DST/qwen-local.agent.md"; do
  printf '  %s  (%s bytes)\n' "$f" "$(stat -c%s "$f")"
done
git -C "$DST" status --short -- . 2>/dev/null || true
