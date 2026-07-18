Here's the Rust code that serializes the `Cfg` struct to JSON with keys in sorted order using `serde_json::to_string_sorted`:

```rust
use serde::{Serialize, Deserialize};

#[derive(Serialize, Deserialize)]
struct Cfg {
    zeta: u32,
    alpha: String,
    mid: bool,
}

fn main() {
    let config = Cfg {
        zeta: 42,
        alpha: "hello".to_string(),
        mid: true,
    };

    let json = serde_json::to_string_sorted(&config).expect("Failed to serialize");
    println!("{}", json);
    // Output: {"alpha":"hello","mid":true,"zeta":42}
}
```

Make sure you have the following in your `Cargo.toml`:

```toml
[dependencies]
serde = { version = "1.0", features = ["derive"] }
serde_json = "1.0"
```

Note: `serde_json::to_string_sorted` is available since `serde_json` version 1.0.91. It serializes map keys (including struct fields) in alphabetical order.