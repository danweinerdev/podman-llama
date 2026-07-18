Here's the Rust code to serialize the `Cfg` struct to JSON with its keys in sorted order using `serde_json::to_string_sorted`:

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

    // Serialize with keys in sorted order (alphabetically)
    let json = serde_json::to_string_sorted(&cfg).expect("failed to serialize");
    
    println!("{}", json);
    // Output: {"alpha":"hello","mid":true,"zeta":42}
}
```

**Note**: `serde_json::to_string_sorted` is available starting from `serde_json` version 1.0.91. Make sure your `Cargo.toml` includes:

```toml
[dependencies]
serde = { version = "1.0", features = ["derive"] }
serde_json = "1.0"
```

The keys appear in the output JSON in alphabetical order: `"alpha"`, `"mid"`, `"zeta"`, regardless of the order they were declared in the struct.