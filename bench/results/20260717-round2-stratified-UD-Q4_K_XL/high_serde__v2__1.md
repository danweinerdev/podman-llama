Plan: Serialize a struct to JSON with keys sorted lexicographically. Using `serde_json::to_string_sorted` (known: exists in serde_json 1.0+ as a convenience wrapper). Assumptions: `serde_json` crate with `derive` feature enabled, struct implements `Serialize` via `#[derive(Serialize)]`. Edge cases: none (trivial derivation). Approach: (1) add derive, (2) call `to_string_sorted`.

```rust
use serde::{Deserialize, Serialize};
use serde_json;

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
    let json = serde_json::to_string_sorted(&cfg).unwrap();
    println!("{}", json); // {"alpha":"hello","mid":true,"zeta":42}
}
```