Plan: Insert `set(CMAKE_NINJA_PARALLEL_LINK_JOBS 2)` into the top-level `CMakeLists.txt` before any `project()` call (required for Ninja to pick it up) — this is a cache variable only effective during toolchain discovery and must be set early.

```cmake
# At the top of CMakeLists.txt, before project()
set(CMAKE_NINJA_PARALLEL_LINK_JOBS 2)
```