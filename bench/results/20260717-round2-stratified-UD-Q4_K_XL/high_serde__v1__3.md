**Plan:** Serialize `Cfg` to JSON with keys in lexicographic order using `serde_json::to_string_sorted`.  
- `known`: `Cfg` is a plain struct; `zeta`, `alpha`, `mid` are field names to be sorted.  
- `inferred`: user wants default field naming (no `rename` attributes); `mid: bool` serializes as `true`/`false`.  
- Edge cases: empty `String` in `alpha` is valid; all fields non-optional, so no null handling needed.  
- Approach: derive `Serialize`, use `to_string_sorted` from `serde_json`.

```rust
use serde::Serialize;
use serde_json;

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
    println!("{}", json); // prints: {"alpha":"hello","mid":true,"zeta":42}
}
```