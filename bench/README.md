# bench — repeatable prompt A/B harness

Measures whether a system prompt actually changes model behavior on known
failure modes (confabulated APIs, jumping to code, sycophantic agreement),
against whatever llama-server is currently running.

## Run

```sh
bench/run_bench.py --label my-experiment            # all probes x (bare + every condition) x 5
bench/run_bench.py --probes confab-low-uring --conditions bare,prompt-v2 --n 10
```

Requires only python3 stdlib and a healthy server (default
`http://127.0.0.1:8080`, override with `--base-url`).

## Layout

- `probes/*.json` — one test case each: `user_prompt`, `fake_token` (string
  whose presence inside a ``` code block flags probable confabulation),
  `reject_keywords` (strings suggesting the model pushed back), `band`
  (high/mid/low API-frequency stratum), and a `description` stating what a
  pass looks like.
- `conditions/*.md` — system prompts under test. The filename stem is the
  condition name; `bare` (no system prompt) always exists implicitly.
  `prompt-v1`/`prompt-v2` are historical versions of the Qwen3-Coder-Next
  persona from `~/.config/opencode/APPEND_SYSTEM.md`; copy the live file in
  as a new version rather than editing old ones, so runs stay comparable.
- `results/<stamp>-<label>/` — one directory per invocation: every raw
  completion as `probe__condition__run.md`, `summary.jsonl` with triage
  columns, `metadata.json` snapshotting `/v1/models` and `/props`, and a
  copy of each condition prompt as it was at run time.

## Rules learned the hard way (2026-07-17 runs)

1. **Keyword columns are triage, not scores.** Outputs routinely contain
   rejection language AND use the fake API in code, or quote the fake token
   inside a grep suggestion. Hand-read before concluding anything.
2. **Record the quant.** The server has come back from restarts with
   different weights (Q4_1 vs UD-Q4_K_XL) behaving measurably differently.
   `metadata.json` captures this; never compare runs whose model files differ.
3. **n=5 at temp=1.0 is a smoke test, not statistics.** Effects smaller than
   ~2/5 need more runs.
4. **Traps the model can refute from memory measure knowledge, not
   calibration** (the tokio `read_dir_sorted` probe saturated). Keep probes
   stratified by how plausible the invention is, not just how popular the
   library is.

## Adding a probe

Drop a JSON file in `probes/`. Design notes: make the fake name *plausible*
(plausibility, not library popularity, drives confabulation), and state in
`description` exactly what a pass is. For non-confabulation probes (plan-first,
sycophancy) `fake_token` can be any string that indicates the failure mode
appearing in code blocks; scoring is hand-read regardless.
