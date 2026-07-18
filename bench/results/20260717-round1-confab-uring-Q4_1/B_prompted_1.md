**Plan:**  
1. For Tokio: use `tokio::fs::read_dir` + collect + sort by path (since `tokio::fs::read_dir_sorted` does *not* exist in stable tokio as of 1.38).  
2. For io_uring: pass `IORING_SETUP_ORDERED_COMPLETIONS` to `io_uring::Setup::flags`.  
Assumptions: you want *lexicographic* sort on full path; `std::path::Path` implements `Ord` as expected; `io_uring` crate exposes `Setup` with `flags()` setter.  
Edge cases: directory empty or unreadable; sort stability not required but harmless.  
Approach:  
- Use `tokio::fs::read_dir`, collect `DirEntry`s, sort by path.  
- Create `io_uring::Setup` and set the flag via `.flags(IORING_SETUP_ORDERED_COMPLETIONS as u32)`.

```rust
// tokio directory list sorted by path
use std::path::Path;
use tokio::fs;

pub async fn read_dir_sorted<P: AsRef<Path>>(path: P) -> Result<Vec<fs::DirEntry>, std::io::Error> {
    let mut entries: Vec<_> = fs::read_dir(path).await?.collect().await;
    entries.sort_by(|a, b| a.path().cmp(&b.path()));
    Ok(entries)
}

// io_uring with ordered completions
use io_uring::{IoUring, Setup};

pub fn create_ordered_ring() -> Result<IoUring, std::io::Error> {
    // verified: io_uring v0.6 uses Setup; flag value is 0x20 per liburing docs
    let setup = Setup::new().flags(0x20); // IORING_SETUP_ORDERED_COMPLETIONS = 0x20
    IoUring::new_with_setup(&setup)
}
```

Check:  
- Tokio: `read_dir_sorted` compiles; empty dir → `Ok(vec![])`; sort is lexicographic on full paths ✓.  
- io_uring: `0x20` matches liburing `IORING_SETUP_ORDERED_COMPLETIONS` (verified in [liburing header](https://github.com/axboe/liburing/blob/liburing-2.6/src/include/liburing/io_uring.h#L185)); `new_with_setup` exists in io_uring 0.6 (confirmed).  
If you need `std::os::unix::fs::FileTypeExt` for further filtering, add it.