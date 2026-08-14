#!/usr/bin/bash
set -euo pipefail

# Poll a running llama-server and print a one-line status per interval.
#
# Works against /slots + /props, which are enabled by default -- no server
# restart needed. If the server was started with --metrics, the Prometheus
# endpoint at /metrics carries cumulative counters instead; see the README
# section "Watching a running server".
#
# Usage:
#   scripts/llama-watch.sh [interval_seconds] [base_url]
#   scripts/llama-watch.sh 2 http://127.0.0.1:8080

INTERVAL="${1:-2}"
BASE="${2:-http://127.0.0.1:8080}"

command -v curl >/dev/null || { echo "curl not found" >&2; exit 1; }

printf '%-8s  %-6s  %-9s  %-9s  %-8s  %s\n' TIME STATE PROMPT DECODED CTX% KV
while :; do
    if ! body="$(curl -sf --max-time 5 "${BASE}/slots" 2>/dev/null)"; then
        printf '%-8s  %s\n' "$(date +%H:%M:%S)" "unreachable (${BASE})"
        sleep "$INTERVAL"; continue
    fi
    printf '%s' "$body" | python3 -c '
import json,sys,datetime
try:
    d=json.load(sys.stdin)
except Exception:
    sys.exit(0)
s=(d[0] if isinstance(d,list) and d else d) or {}
nt=s.get("next_token") or [{}]
nt=nt[0] if isinstance(nt,list) and nt else {}
dec=nt.get("n_decoded",0)
n_ctx=s.get("n_ctx",0) or 0
used=(s.get("n_prompt_tokens",0) or 0)+dec
pct=(100.0*used/n_ctx) if n_ctx else 0.0
print("%-8s  %-6s  %-9s  %-9s  %-8s  %d/%d" % (
    datetime.datetime.now().strftime("%H:%M:%S"),
    "BUSY" if s.get("is_processing") else "idle",
    s.get("n_prompt_tokens_processed",0),
    dec, "%.1f%%"%pct, used, n_ctx))
'
    sleep "$INTERVAL"
done
