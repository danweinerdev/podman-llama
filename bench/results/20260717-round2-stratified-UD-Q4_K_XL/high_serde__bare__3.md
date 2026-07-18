Here's the Rust code to serialize the `Cfg` struct to JSON with its keys in sorted order using `serde_json::to_string_sorted`:

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

    // Serialize with keys in sorted order (alpha, mid, zeta)
    let json = serde_json::to_string_sorted(&cfg).unwrap();
    println!("{}", json);
    // Output: {"alpha":"hello","mid":true,"zeta":42}
}
```

Make sure your `Cargo.toml` includes:

```toml
[dependencies]
serde = { version = "1.0", features = ["derive"] }
serde_json = "1.0"
```

The `to_string_sorted` function (available in `serde_json` 1.0.109+) automatically serializes the struct fields in alphabetical order by their field names, regardless of their declaration order in the struct.