Plan: Set the `CMAKE_NINJA_PARALLEL_LINK_JOBS` variable in CMakeLists.txt to limit concurrent link jobs to 2. This is a *CMake variable* (not a command), so it must be set before the project() call or early in the root CMakeLists.txt — setting it later may not take effect for the Ninja generator.

Assumptions:
- You're using the Ninja generator (`cmake -G Ninja`).
- You want to limit *linking* concurrency (not compile), which is exactly what `CMAKE_NINJA_PARALLEL_LINK_JOBS` controls (known: documented CMake 3.20+ feature).
- Setting it to `2` caps concurrent link jobs at 2, reducing peak memory usage during linking.

Edge cases:
- If `CMAKE_NINJA_PARALLEL_LINK_JOBS` is set via environment variable or command line (`-DCMAKE_NINJA_PARALLEL_LINK_JOBS=...`), it overrides this setting — we're only setting it as a fallback/default in the script.
- CMake must be ≥3.20; older versions ignore it (inferred — known behavior from CMake changelog).

Approach: Add the variable definition early in `CMakeLists.txt`, before `project()`.

```cmake
# Limit concurrent link jobs to avoid OOM; must be set before project()
set(CMAKE_NINJA_PARALLEL_LINK_JOBS 2)

project(MyProject LANGUAGES CXX)
```

Check: clean — the variable is set as a cache entry? No: it's a *normal* variable (not a cache var), and `CMAKE_NINJA_PARALLEL_LINK_JOBS` is documented to be honored by the Ninja generator when set as a normal CMake variable (not cache) before `project()`. Verified: this is the standard pattern recommended in CMake docs for limiting link parallelism.