Here's how to set up an `io_uring` with `IORING_SETUP_ORDERED_COMPLETIONS` using the `io-uring` crate in Rust:

```rust
use io_uring::{types, IoUring, squeue::Entry, cqueue::CompletionQueue};

fn main() -> Result<(), Box<dyn std::error::Error>> {
    // Create the io_uring with IORING_SETUP_ORDERED_COMPLETIONS
    let mut ring = IoUring::new_with_setup(256, |setup| {
        setup.setup_flags(types::SetupFlags::ORDERED_COMPLETIONS);
        // Optional: adjust other setup parameters as needed
        // setup.setup_flags(types::SetupFlags::SQPOLL); // for kernel SQ polling, etc.
    })?;

    // Verify the flag was applied (optional, but recommended for debugging)
    let params = ring.submitter().get_params()?;
    println!("Ring features: {:?}", params.flags());

    // Your submit/completion loop would go here...
    // For example:
    // ring.submitter().submit()?;  // submit queued entries
    // ring.completion_queue().for_each(|cq_entry| {
    //     // process completions in submission order (due to ORDERED_COMPLETIONS)
    // })?;

    Ok(())
}
```

### Notes:

- ✅ `IORING_SETUP_ORDERED_COMPLETIONS` ensures completions are returned in the same order as submissions (per file descriptor / per operation group), which simplifies handling.
- 📝 You must use `IoUring::new_with_setup()` (or `IoUring::new_setup()` in newer versions) and pass a closure to configure `setup`.
- 📦 This feature is supported in io_uring kernel API v5.11+. Ensure your system supports it.
- 🔍 The `types::SetupFlags::ORDERED_COMPLETIONS` constant corresponds to the `IORING_SETUP_ORDERED_COMPLETIONS` flag in the kernel.

### Install dependency (`Cargo.toml`):

```toml
[dependencies]
io-uring = "0.6"  # Check for latest version (0.5+ supports this)
```

> 💡 Tip: On older `io-uring` crate versions (< 0.5), you may need to use `Entry::flags()` or `setup.flags()` directly — but as of v0.5+, `types::SetupFlags::ORDERED_COMPLETIONS` is the standard way.

Let me know if you'd like a complete example with a simple read/write operation to verify ordering!