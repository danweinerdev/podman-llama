#!/usr/bin/bash
set -euo pipefail

# Live in-place status view for a running llama-server.
#
# Redraws a fixed block in place each interval instead of scrolling, so the
# terminal shows current state rather than a growing log. Reads /slots and
# /props, which llama-server enables by default -- no server restart and no
# --metrics needed. (The launchers also pass --metrics, which adds cumulative
# Prometheus counters at /metrics; that endpoint is for scraping, not for this.)
#
# Decode t/s is derived here by differencing n_decoded between polls, because
# /slots reports progress counters, not a rate. It is a short-window average
# over one interval, so expect it to jitter; the figure llama-server itself
# reports at the end of a request is the authoritative one.
#
# Usage:
#   scripts/llama-watch.sh [interval_seconds] [base_url]
#   scripts/llama-watch.sh 1
#   scripts/llama-watch.sh 5 http://otherhost:8080
#
# Ctrl-C to exit; the cursor is restored on the way out.

INTERVAL="${1:-2}"
BASE="${2:-http://127.0.0.1:8080}"

command -v curl >/dev/null || { echo "curl not found" >&2; exit 1; }

# Restore the cursor and drop below the block on exit, however we leave.
cleanup() { printf '\033[?25h\n'; }

# Rate state is per-process: a leftover file from an earlier run would make the
# first poll diff against unrelated counters and print a nonsense rate.
STATE_PATH="$(mktemp -t llama-watch.XXXXXX)"
cleanup_state() { rm -f "$STATE_PATH"; }
trap 'cleanup; cleanup_state' EXIT INT TERM

printf '\033[?25l'   # hide cursor while redrawing

FIRST=1
LINES=0

# /slots is served from the same thread that runs inference, so a busy server
# answers it only between batches -- measured 3-5.5s latency, and outright
# connection failures, while decoding at 262K context. Allow generously more
# than the poll interval, and treat a miss as "stale", not "down": STALE_LIMIT
# consecutive failures must pass before the view reports the server unreachable.
CURL_TIMEOUT="$(python3 -c "print(max(15, ${INTERVAL}*4))")"
STALE_LIMIT=3
stale=0
last_body=""

while :; do
    if body="$(curl -sf --max-time "$CURL_TIMEOUT" "${BASE}/slots" 2>/dev/null)"; then
        last_body="$body"; stale=0
    else
        stale=$((stale+1))
        # Reuse the last good payload so one slow poll doesn't blank the view.
        if [[ $stale -lt $STALE_LIMIT && -n "$last_body" ]]; then
            body="$last_body"
        else
            body=""
        fi
    fi

    # Move back up over the previously drawn block (skip on the first pass).
    if [[ $FIRST -eq 0 && $LINES -gt 0 ]]; then
        printf '\033[%dA' "$LINES"
    fi
    FIRST=0

    out="$(BASE="$BASE" INTERVAL="$INTERVAL" STALE="$stale" STATE_PATH="$STATE_PATH" python3 -c '
import json, os, sys, datetime

RESET="\033[0m"; BOLD="\033[1m"; DIM="\033[2m"
GRN="\033[32m"; YEL="\033[33m"; RED="\033[31m"; CYN="\033[36m"

base=os.environ["BASE"]; interval=float(os.environ["INTERVAL"])
stale=int(os.environ.get("STALE","0"))
state_path=os.environ["STATE_PATH"]

raw=sys.stdin.read().strip()
lines=[]
def emit(s=""): lines.append(s)

now=datetime.datetime.now().strftime("%H:%M:%S")

if not raw:
    emit(f"{BOLD}llama-watch{RESET}  {DIM}{base}{RESET}")
    emit(f"  {RED}unreachable{RESET}  {DIM}last check {now}{RESET}")
    emit("")
    print("\n".join(lines)); sys.exit(0)

try:
    d=json.loads(raw)
except Exception:
    emit(f"{BOLD}llama-watch{RESET}  {DIM}{base}{RESET}")
    emit(f"  {RED}bad response{RESET}  {DIM}{now}{RESET}")
    emit("")
    print("\n".join(lines)); sys.exit(0)

slots = d if isinstance(d, list) else [d]

# Derive a decode rate by differencing n_decoded against the previous poll.
prev={}
try:
    with open(state_path) as f: prev=json.load(f)
except Exception:
    pass
cur={}

def bar(frac, width=28):
    frac=max(0.0, min(1.0, frac))
    fill=int(round(frac*width))
    color = GRN if frac < 0.75 else (YEL if frac < 0.9 else RED)
    return f"{color}{chr(9608)*fill}{DIM}{chr(9617)*(width-fill)}{RESET}"

suffix=""
if stale:
    # Busy servers answer /slots only between batches; say so instead of lying.
    suffix=f"  {YEL}stale x{stale}{RESET}"
emit(f"{BOLD}llama-watch{RESET}  {DIM}{base}  every {interval:g}s  {now}{RESET}{suffix}")

for s in slots:
    sid=s.get("id", 0)
    busy=bool(s.get("is_processing"))
    nt=s.get("next_token") or [{}]
    nt=nt[0] if isinstance(nt, list) and nt else (nt if isinstance(nt, dict) else {})
    dec=int(nt.get("n_decoded", 0) or 0)
    remain=nt.get("n_remain")
    n_ctx=int(s.get("n_ctx", 0) or 0)
    p_tot=int(s.get("n_prompt_tokens", 0) or 0)
    p_cache=int(s.get("n_prompt_tokens_cache", 0) or 0)
    p_proc=int(s.get("n_prompt_tokens_processed", 0) or 0)
    used=p_tot+dec
    frac=(used/n_ctx) if n_ctx else 0.0

    key=str(sid)
    cur[key]={"dec": dec, "used": used}
    rate=None
    if key in prev and busy:
        ddec=dec-int(prev[key].get("dec", 0))
        if ddec >= 0 and interval > 0:
            rate=ddec/interval

    tag = f"{GRN}BUSY{RESET}" if busy else f"{DIM}idle{RESET}"
    emit(f"  slot {sid}  {tag}"
         + (f"   {CYN}{rate:5.1f} tok/s{RESET}" if rate is not None else "               "))
    emit(f"  {bar(frac)} {used:>7}/{n_ctx} {DIM}({frac*100:.1f}% of ctx){RESET}")
    cached = f"  {DIM}cached {p_cache}{RESET}" if p_cache else ""
    emit(f"  {DIM}prompt{RESET} {p_tot:<8} {DIM}processed{RESET} {p_proc:<8}{cached}")
    # n_remain is -1 when the request set no token limit.
    r = "unlimited" if remain in (-1, None) else f"{remain}"
    emit(f"  {DIM}decoded{RESET} {dec:<8} {DIM}remaining{RESET} {r}")

try:
    with open(state_path, "w") as f: json.dump(cur, f)
except Exception:
    pass

emit(f"  {DIM}Ctrl-C to exit{RESET}")
print("\n".join(lines))
' <<<"$body")"

    # Clear each line as we redraw so shorter output never leaves stale text.
    while IFS= read -r line; do
        printf '\033[2K%s\n' "$line"
    done <<<"$out"

    LINES=$(printf '%s\n' "$out" | wc -l)
    sleep "$INTERVAL"
done
