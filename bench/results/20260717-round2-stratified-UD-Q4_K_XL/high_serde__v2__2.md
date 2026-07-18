Plan: Serialize `Cfg` to JSON with keys sorted alphabetically using `serde_json::to_string_sorted`. Assumptions: `serde_json` is available with the `serialize_sorted` feature (known — `to_string_sorted` exists in `serde_json` v1.0+ with the `serialize_sorted` feature enabled). Edge cases: none specific (all fields are serializable). Approach: Derive `Serialize`, enable the `serialize_sorted` feature in `Cargo.toml`, and call `serde_json::to_string_sorted`.

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
        alpha: "hello".to_string(),
        mid: true,
    };
    let json = serde_json::to_string_sorted(&cfg).unwrap();
    println!("{json}");
}
```

Check: `Cfg` derives `Serialize` correctly; `to_string_sorted` is used on a valid `Serialize` instance; the output JSON keys will be `"alpha"`, `"mid"`, `"zeta"` in sorted order (e.g., `{"alpha":"hello","mid":true,"zeta":42}`). No edge-case logic needed; fields are all trivially serializable.