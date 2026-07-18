# Prompts — Qwen3-Coder-Next

Tracked copies of the live opencode prompt stack for Qwen3-Coder-Next
(80B-A3B MoE, non-thinking; served by this repo's llama-server containers,
model envs in `models/qwen3-coder-next*.env`). These files are the deployed
prompt state; `bench/conditions/` holds frozen historical versions for A/B
comparison — never edit those, add new ones.

| File here | Live source | Role |
|---|---|---|
| `APPEND_SYSTEM.md` | `~/.config/opencode/APPEND_SYSTEM.md` | Global persona: Plan/Check output contract, premise-flagging, calibration rules, tool discipline. Designed against the model's constraints: non-thinking (all reasoning must be visible output), temp=1.0 sampling (structural guardrails), 3B active params (explicit decomposition + exemplars). |
| `qwen-local.agent.md` | `~/.config/opencode/agent/qwen-local.md` | opencode agent definition (`mode: primary`, model `llama.cpp/qwen3-coder-next-q4`): decision-workflow rules for premise checking, evidence ranking, scope, output, and stopping. |

Re-capture after editing either source:

```sh
scripts/sync-prompts.sh
```

Known limitation (measured, see `bench/results/20260717-*`): the persona
reliably produces the Plan/Check structure and premise-flagging, but does NOT
prevent API confabulation — the model adopts calibration vocabulary
("unverified:", "checked internally") while still shipping invented APIs in
code. Treat prompt-side calibration as cosmetic; real mitigation must be
tool-grounded verification in the agent loop.
