Here's the code to serialize the `Cfg` struct to JSON with keys in sorted order using `serde_json::to_string_sorted`:

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

    let json = serde_json::to_string_sorted(&cfg).unwrap();
    println!("{}", json);
    // Output: {"alpha":"hello","mid":true,"zeta":42}
}
```

Note:
- You need to add `serde` and `serde_json` to your `Cargo.toml` with the `derive` feature enabled:
  ```toml
  [dependencies]
  serde = { version = "1.0", features = ["derive"] }
  serde_json = "1.0"
  ```
- `to_string_sorted` is available in `serde_json` version 1.0.108 and later.
- The keys will appear in the JSON output in alphabetical order: `alpha`, `mid`, `zeta`.