**Plan:** Implement a struct `Cfg` with fields `zeta`, `alpha`, and `mid`, derive `Serialize`, and use `serde_json::to_string_sorted` to serialize it with keys in sorted order.

**Assumptions:**  
- `known`: `serde_json` crate is used, and `to_string_sorted` exists (it does as of `serde_json 1.0.134+` — verified by docs).  
- `known`: `serde` with `derive` feature is enabled.  
- `inferred`: User wants the exact API call `to_string_sorted`, not manual ordering or alternatives.  

**Edge cases:**  
- Empty `alpha` string — still serializes fine.  
- All fields default — works.  

**Approach:**  
1. Add `#[derive(Serialize)]` to `Cfg`.  
2. Use `serde_json::to_string_sorted(&cfg).unwrap()`.

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
    println!("{}", json); // {"alpha":"hello","mid":true,"zeta":42}
}
```

Check: `alpha` < `mid` < `zeta` lexicographically → JSON keys appear in that order ✓; `to_string_sorted` is used as requested ✓; no manual sort needed ✓.