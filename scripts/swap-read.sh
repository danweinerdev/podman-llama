#!/usr/bin/bash
# swap-read.sh [N] -- swap usage overview: devices, totals, top N swapped
# processes (default 20) with PID, swap, RSS, and share of total swap.
set -euo pipefail

TOP_N="${1:-20}"

# --- devices & totals --------------------------------------------------------
echo "== swap devices =="
swapon --show 2>/dev/null || echo "(no swap devices)"
command -v zramctl >/dev/null && { echo; echo "== zram (compressed) =="; zramctl 2>/dev/null || true; }

echo
awk '/^SwapTotal:/{t=$2} /^SwapFree:/{f=$2} /^SwapCached:/{c=$2} END{
  u=t-f
  printf "== totals ==\nswap: %.1f GiB used / %.1f GiB total (%.0f%%), %.1f MiB swap-cached\n",
    u/1048576, t/1048576, (t? u*100/t : 0), c/1024
}' /proc/meminfo

# --- per-process -------------------------------------------------------------
echo
echo "== top ${TOP_N} swapped processes =="
printf "%7s  %9s  %9s  %6s  %s\n" PID SWAP RSS "%SWAP" COMMAND

total_kb=$(awk '/^SwapTotal:/{t=$2} /^SwapFree:/{f=$2} END{print t-f}' /proc/meminfo)

for p in /proc/[0-9]*; do
  pid="${p#/proc/}"
  # smaps_rollup has both Swap: and Rss: -- one read per process.
  awk -v pid="$pid" '
    /^Swap:/{s+=$2} /^Rss:/{r+=$2}
    END{if (s>0) printf "%s %d %d\n", pid, s, r}' "$p/smaps_rollup" 2>/dev/null || true
done | sort -k2 -rn | head -"${TOP_N}" | while read -r pid sw rss; do
  comm=$(cat "/proc/$pid/comm" 2>/dev/null || echo "?")
  printf "%7s  %7d k  %7d k  %5.1f%%  %s\n" \
    "$pid" "$sw" "$rss" "$(awk -v s="$sw" -v t="$total_kb" 'BEGIN{print (t? s*100/t : 0)}')" "$comm"
done

# --- accounted vs total (kernel/shmem swap does not belong to any process) ---
echo
for p in /proc/[0-9]*; do
  awk '/^Swap:/{s+=$2} END{print s+0}' "$p/smaps_rollup" 2>/dev/null || true
done | awk -v t="$total_kb" '{a+=$1} END{
  printf "process-accounted: %.2f GiB of %.2f GiB used (rest is shmem/tmpfs/kernel)\n",
    a/1048576, t/1048576
}'
