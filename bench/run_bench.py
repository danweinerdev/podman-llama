#!/usr/bin/env python3
# run_bench.py -- repeatable A/B prompt bench against a llama-server OpenAI endpoint.
#
#   bench/run_bench.py [--base-url URL] [--n N] [--label TEXT]
#                      [--probes name,name,...] [--conditions name,name,...]
#
# Matrix: every probe in bench/probes/*.json x every condition x N runs.
# Conditions are files in bench/conditions/*.md used as the system prompt;
# "bare" (no system prompt) is always available and included by default.
# Each run directory under bench/results/ records server + model metadata so
# results across quants/servers are never silently compared.
#
# Keyword columns are TRIAGE ONLY -- hand-read outputs before drawing
# conclusions; rejection language and confabulation coexist in one output.
import argparse, datetime, json, pathlib, sys, time, urllib.request

ROOT = pathlib.Path(__file__).resolve().parent
SAMPLING = {"temperature": 1.0, "top_p": 0.95, "top_k": 40, "min_p": 0.01}
MAX_TOKENS = 900

def get(url, timeout=5):
    try:
        with urllib.request.urlopen(url, timeout=timeout) as r:
            return json.load(r)
    except Exception:
        return None

def chat(base, system, user, timeout=600):
    msgs = ([{"role": "system", "content": system}] if system else []) + \
           [{"role": "user", "content": user}]
    body = json.dumps({"messages": msgs, "max_tokens": MAX_TOKENS, **SAMPLING}).encode()
    req = urllib.request.Request(f"{base}/v1/chat/completions", data=body,
                                 headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return json.load(r)["choices"][0]["message"]["content"]

def in_codeblock(text, token):
    blocks = "".join(seg for i, seg in enumerate(text.split("```")) if i % 2 == 1)
    return token.lower() in blocks.lower()

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--base-url", default="http://127.0.0.1:8080")
    ap.add_argument("--n", type=int, default=5)
    ap.add_argument("--label", default="run")
    ap.add_argument("--probes", default="")     # comma-separated names, default all
    ap.add_argument("--conditions", default="") # comma-separated, default bare + all files
    args = ap.parse_args()

    probes = {}
    for f in sorted((ROOT / "probes").glob("*.json")):
        p = json.loads(f.read_text())
        probes[p["name"]] = p
    if args.probes:
        probes = {k: probes[k] for k in args.probes.split(",")}

    conditions = {"bare": None}
    for f in sorted((ROOT / "conditions").glob("*.md")):
        conditions[f.stem] = f.read_text()
    if args.conditions:
        conditions = {k: conditions[k] for k in args.conditions.split(",")}

    health = get(f"{args.base_url}/health")
    if not health or health.get("status") != "ok":
        sys.exit(f"server at {args.base_url} not healthy: {health}")
    models = get(f"{args.base_url}/v1/models")
    props = get(f"{args.base_url}/props")  # llama-server build/model details, if exposed

    stamp = datetime.datetime.now().strftime("%Y%m%d-%H%M%S")
    outdir = ROOT / "results" / f"{stamp}-{args.label}"
    outdir.mkdir(parents=True)
    (outdir / "metadata.json").write_text(json.dumps({
        "timestamp": stamp, "base_url": args.base_url, "n": args.n,
        "sampling": SAMPLING, "max_tokens": MAX_TOKENS,
        "probes": sorted(probes), "conditions": sorted(conditions),
        "models_endpoint": models, "props_endpoint": props,
    }, indent=2))
    for name, text in conditions.items():
        if text is not None:
            (outdir / f"condition-{name}.md").write_text(text)

    summary = []
    for pname, probe in probes.items():
        rej_kw = [k.lower() for k in probe.get("reject_keywords", [])]
        for cname, system in conditions.items():
            for i in range(args.n):
                t0 = time.time()
                text = chat(args.base_url, system, probe["user_prompt"])
                (outdir / f"{pname}__{cname}__{i}.md").write_text(text)
                row = {
                    "probe": pname, "condition": cname, "run": i,
                    "reject_kw": any(k in text.lower() for k in rej_kw),
                    "fake_in_codeblock": in_codeblock(text, probe["fake_token"]),
                    "chars": len(text), "seconds": round(time.time() - t0, 1),
                }
                summary.append(row)
                print("{probe} {condition} {run}: reject_kw={reject_kw} "
                      "fake_in_codeblock={fake_in_codeblock} chars={chars} "
                      "t={seconds}s".format(**row), flush=True)

    (outdir / "summary.jsonl").write_text(
        "\n".join(json.dumps(r) for r in summary) + "\n")
    print(f"\nwrote {len(summary)} runs to {outdir}")
    print("triage only -- hand-read before concluding; see bench/README.md")

if __name__ == "__main__":
    main()
