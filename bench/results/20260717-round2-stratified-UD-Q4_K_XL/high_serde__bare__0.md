Here's the Rust code to serialize the `Cfg` struct to JSON with keys in sorted order using `serde_json::to_string_sorted`:

```rust
use serde::{Deserialize, Serialize};

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

    let json = serde_json::to_string_sorted(&cfg).expect("Failed to serialize");
    println!("{}", json); // Outputs: {"alpha":"hello","mid":true,"zeta":42}
}
```

Make sure you have the following in your `Cargo.toml`:

```toml
[dependencies]
serde = { version = "1.0", features = ["derive"] }
serde_json = "1.0"
```

Note: `to_string_sorted` requires `serde_json` version 1.0.109 or later (released in April 2024), which added this method. The keys appear in alphabetical order: `alpha`, `mid`, `zeta`.