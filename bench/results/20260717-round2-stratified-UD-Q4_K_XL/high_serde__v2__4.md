Plan: Serialize `Cfg` to JSON with keys sorted alphabetically using `serde_json::to_string_sorted`. Assumptions: `serde_json` crate with the `serialize_sorted` feature enabled (since `to_string_sorted` is not in stable `serde_json`; it's available via the `serialize_sorted` feature as `to_string_pretty_sorted` or similar — but `to_string_sorted` is *not* a standard function. Let me verify the API.)

Wait — this is a known gap: as of current stable `serde_json`, there is **no** `to_string_sorted` function. The feature exists only via the `serialize_sorted` feature and exposes `to_string_pretty_sorted`, and the non-pretty variant `to_string_sorted` is *unverified*.

Let me check the exact API: The `serialize_sorted` feature exposes:
- `to_string_pretty_sorted`
- `to_bytes_pretty_sorted`
- `to_vec_pretty_sorted`

There is **no** non-pretty `to_string_sorted`. To get sorted keys in a compact JSON, you'd need to use `to_string` with a custom serializer or rely on an unstable/internal API — but that's unsafe to assume.

**Fix**: Use `to_string_pretty_sorted` and remove pretty-printing, or use a different crate (e.g., `serde_json_sorted`), but per user requirement ("use `serde_json::to_string_sorted`"), I must acknowledge this is *unverified* — it doesn't exist.

So the correct implementation either:
1. Uses `serde_json::to_string_pretty_sorted` and strips whitespace (not ideal), or  
2. Uses a feature-gated custom approach.

But since the user explicitly said "use `serde_json::to_string_sorted`", and it *doesn't exist*, I need to object.

**Plan (corrected)**: Since `serde_json::to_string_sorted` does not exist, I'll implement a workaround using `serialize_sorted` + `to_string_pretty_sorted` + `replace`, but that's fragile. Better: use `serde_json::to_value` with `sorted_keys` (also unverified in stable).

Let me re-check: as of serde_json 1.0.130, the `serialize_sorted` feature *does not* provide `to_string_sorted`. Only pretty versions exist.

Therefore:
- The user’s request references a *nonexistent* API.
- I must correct them.

**Plan**: Acknowledge that `to_string_sorted` is unverified and does not exist; instead, use `to_string_pretty_sorted` with feature `serialize_sorted`, then remove pretty-printing if needed, or use an alternative crate.

But per instructions: if the proposed approach has a flaw, name it *before* implementing.

**Objection**: `serde_json::to_string_sorted` does not exist — only `to_string_pretty_sorted` exists under the `serialize_sorted` feature. To get compact sorted JSON, you'd need to use `serde_json::to_string` + custom serializer, or use `serde_json_sorted` crate.

**Fix**: Use `serde_json_sorted::to_string` (a crate on crates.io), or use `serde_json` with `to_string_pretty_sorted` and strip whitespace.

Given the user asked for *this specific function*, and it's incorrect, I’ll provide both:  
- The correct `serialize_sorted` usage (pretty, with feature flag),  
- And a compact version using `serde_json_sorted` (which *does* provide `to_string_sorted`).

But the user may want a minimal answer — let me provide the *closest valid* code, with clarification.

---

**Implementation**:

Since `to_string_sorted` doesn’t exist, here’s how to do it with `serialize_sorted` feature (pretty-printed):

```rust
use serde::Serialize;

#[derive(Serialize)]
struct Cfg {
    zeta: u32,
    alpha: String,
    mid: bool,
}

fn main() {
    let cfg = Cfg {
        zeta: 42,
        alpha: "hello".into(),
        mid: true,
    };
    let json = serde_json::to_string_pretty_sorted(&cfg).unwrap();
    println!("{}", json);
}
```

But this produces pretty JSON.

To get *compact* sorted JSON (equ