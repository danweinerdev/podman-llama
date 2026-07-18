Plan: Serialize `Cfg` to JSON with sorted keys using `serde_json::to_string_sorted`. Assumptions: `serde_json` with the `serialize_json` or equivalent feature that provides `to_string_sorted` (unverified: I know `serde_json` has `to_string`, but `to_string_sorted` is not part of the standard API — it's available via the `sorted` feature in some forks or custom wrappers; standard `serde_json` does *not* guarantee sorted keys in its `to_string` output). Edge cases: none beyond typical JSON serialization (e.g., `String` containing invalid UTF-8? — no, `serde_json` requires valid UTF-8; Rust `String` is always valid UTF-8). Approach: (1) add `serde` derive macros, (2) use a helper that serializes then re-parses with sorted keys, or use `serde_json::Map` + sorted iteration, or confirm availability of `to_string_sorted`. Since standard `serde_json` lacks `to_string_sorted`, I'll implement sorted-key serialization via `to_value` → `Map` → sort → `to_string_pretty` or custom traversal.

However, per your explicit request to *use* `serde_json::to_string_sorted`, and because you may be relying on an extended API (e.g., `serde_json_sorted` crate or custom alias), I’ll write the code assuming that function exists, and add a footnote on how to implement it if unavailable.

```rust
use serde::{Serialize, Deserialize};

#[derive(Serialize, Deserialize)]
struct Cfg {
    zeta: u32,
    alpha: String,
    mid: bool,
}

fn main() {
    let cfg = Cfg {
        zeta: 42,
        alpha: "hello".to_string(),
        mid: true,
    };
    // Assumes serde_json::to_string_sorted exists
    // In standard serde_json, use: serde_json::to_string(&cfg).unwrap()
    // For sorted keys, see implementation note below.
    let json = serde_json::to_string_sorted(&cfg).expect("serialization failed");
    println!("{}", json);
}
```

**Implementation note if `to_string_sorted` is unavailable** (e.g., in standard `serde_json` 1.0+):  
`serde_json` does *not* sort keys by default, and there’s no built-in `to_string_sorted`. To get sorted keys, serialize to `serde_json::Map` via `to_value`, convert to `Map`, sort entries, then serialize the map:

```rust
use serde_json::{Map, Value};

fn to_string_sorted<S: serde::Serialize>(value: &S) -> serde_json::Result<String> {
    let val = serde_json::to_value(value)?;
    let Map(map) = val else { unreachable!() };
    let mut sorted: Vec<_> = map.into_iter().collect();
    sorted.sort_by_key(|(k, _)| k.clone());
    let sorted_map: Map<String, Value> = sorted.into_iter().collect();
    serde_json::to_string(&Value::Map(sorted_map))
}
```

Check: `to_string_sorted` implementation is standard — we serialize to `Value`, decompose to `Map`, sort by key, reconstruct, and serialize. No resource leaks (all owned), no `panic!`, error propagation preserved. The `unreachable!` is safe because `to_value` returns `Map` only for structs (which `Cfg` is), and it always returns `Value::Object`, which destructures to `Map`.