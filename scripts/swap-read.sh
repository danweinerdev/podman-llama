#!/usr/bin/bash

for p in /proc/[0-9]*; do
  sw=$(awk '/^Swap:/{s+=$2} END{print s+0}' "$p/smaps_rollup" 2>/dev/null)
  [ "${sw:-0}" -gt 0 ] && printf "%8d kB  %s\n" "$sw" "$(cat "$p/comm" 2>/dev/null)"
done | sort -rn | head -20
