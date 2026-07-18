Here's a minimal example of how to set up an `io_uring` with the `io_uring` crate (v0.9+) and enable `IORING_SETUP_ORDERED_COMPLETIONS`:

```rust
use io_uring::{types, IoUring, squeue::Entry, cqueue::Cqe};

fn main() -> anyhow::Result<()> {
    // Create the ring with ordered completions
    let entries = 8;
    let mut ring = IoUring::new_with_flags(
        entries,
        // Pass the setup flags (IORING_SETUP_ORDERED_COMPLETIONS)
        types::SetupFlags::ORDERED_COMPLETIONS,
    )?;

    // Now you can submit work; completions will be dequeued in submission order

    // Example: submit a dummy write to /dev/null to test ordering
    let buf = "Hello, ordered completions!\n";
    let write_fd = std::fs::OpenOptions::new()
        .write(true)
        .open("/dev/null")?;
    let write_op = Entry::write(
        types::Fd(write_fd.as_raw_fd()),
        buf.as_ptr() as *const _,
        buf.len() as u32,
        0,
    )
    .user_data(1u64); // user_data to identify operation

    unsafe {
        ring.submission().push(&write_op).expect("queue full");
    }
    ring.submit()?; // actually submit to kernel

    // Wait for and process completions in order
    let mut cq = ring.completion();
    if let Some(cqe) = cq.next() {
        // Completions will appear in submission order (thanks to ORDERED_COMPLETIONS)
        println!("Completion for user_data: {}", cqe.user_data());
    } else {
        println!("No completion ready (non-blocking)");
    }

    Ok(())
}
```

### Notes:
- ✅ **`IORING_SETUP_ORDERED_COMPLETIONS`** is exposed as `SetupFlags::ORDERED_COMPLETIONS`.
- 📌 This flag requires Linux 5.11+ (or kernel with backport).
- 🔄 With ordered completions, `cq.next()` and `cq` iteration will yield CQEs in the order submissions were enqueued, not in the order they complete.
- ⚠️ If you submit operations asynchronously or in bursts, make sure to submit them *before* waiting for completions if you want to preserve ordering.

### Cargo.toml dependency:
```toml
[dependencies]
io_uring = "0.9"  # or latest 0.9.x
anyhow = "1.0"
```

Let me know if you need an async (Tokio) version or error-handling improvements.