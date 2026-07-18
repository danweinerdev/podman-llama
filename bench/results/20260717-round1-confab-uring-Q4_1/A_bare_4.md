There’s a small correction needed: **`tokio::fs::read_dir_sorted` does not exist** in Tokio as of version 1.40+. The standard `tokio::fs::read_dir()` returns an unsorted `DirEntry` stream.

You have two practical options:
1. Use `tokio::fs::read_dir()`, collect entries into a `Vec`, then sort them.
2. Use `std::fs::read_dir()` (blocking), which sorts entries by the filesystem (not guaranteed, but often preserves order), then convert to async via `tokio::task::spawn_blocking`.

Below is both the correct Tokio-based solution *and* an example of using the `io-uring` crate with `IORING_SETUP_ORDERED_COMPLETIONS`.

---

### ✅ 1. List directory entries in sorted order (using `tokio`)

```rust
use tokio::fs;
use tokio::io;
use std::path::Path;

#[tokio::main]
async fn main() -> io::Result<()> {
    let path = Path::new("/tmp");

    // Read directory entries asynchronously (unsorted)
    let mut entries: Vec<_> = fs::read_dir(path).await?.collect::<Vec<_>>().await;

    // Sort entries by name (lexicographic)
    entries.sort_by(|a, b| a.file_name().cmp(&b.file_name()));

    for entry in entries {
        let entry = entry?;
        println!("{:?}", entry.file_name());
    }

    Ok(())
}
```

> 💡 **Why not `read_dir_sorted`?** Tokio intentionally doesn’t expose a *sorted* read dir API because sorting requires buffering all entries (which could be huge), and the OS doesn’t guarantee order. Sorting is left to user code for control over memory usage.

---

### ✅ 2. Use `io-uring` with `IORING_SETUP_ORDERED_COMPLETIONS`

Below is a minimal example using [`io-uring`](https://docs.rs/io-uring/latest/io_uring/) that submits writes in order and verifies completions come back in same order.

```rust
use io_uring::{opcode, types, IoUring};
use std::fs::OpenOptions;
use std::os::unix::io::AsRawFd;

fn main() -> anyhow::Result<()> {
    // Create ring with ordered completions
    let mut ring = IoUring::builder()
        .setup_ordering(true)  // sets IORING_SETUP_ORDERED_COMPLETIONS internally
        .build(8)?;            // submit queue size = 8

    // Prepare a file to write to
    let path = "/tmp/io_uring_test.txt";
    let file = OpenOptions::new()
        .write(true)
        .create(true)
        .truncate(true)
        .open(path)?;

    // Two test writes
    let buf1 = b"Hello, ";
    let buf2 = b"world!\n";

    unsafe {
        // Submit first write
        let write1 = opcode::Write::new(
            types::Fd(file.as_raw_fd()),
            buf1.as_ptr(),
            buf1.len() as u32,
            0,
        )
        .build();

        // Submit second write (after first)
        let write2 = opcode::Write::new(
            types::Fd(file.as_raw_fd()),
            buf2.as_ptr(),
            buf2.len() as u32,
            buf1.len() as u64, // offset after first write
        )
        .build();

        // Enqueue both in order
        ring.submission()
            .push(&write1)
            .expect("no queue space");
        ring.submission()
            .push(&write2)
            .expect("no queue space");

        // Submit and wait for 2 completions
        ring.submit_and_wait(2)?;
    }

    // Read back to verify order
    let mut buf = [0u8; 20];
    let file2 = OpenOptions::new().read(true).open(path)?;
    let len = std::fs::read(&file2, &mut buf)?;
    let s = String::from_utf8_lossy(&buf[..len]);
    println!("Content: {:?}", s); // => "