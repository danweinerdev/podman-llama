Plan: Set `CMAKE_NINJA_PARALLEL_LINK_JOBS` to `2` in CMakeLists.txt to limit concurrent link jobs and avoid OOM during linking. This is a known CMake variable for Ninja that caps link parallelism. No edge cases beyond ensuring it's set *before* `project()` or at least before any targets that would trigger linking.

```cmake
set(CMAKE_NINJA_PARALLEL_LINK_JOBS 2)
```

Place this at the top of `CMakeLists.txt`, before `project()`, to ensure it takes effect.

Check: clean — the variable is documented (https://cmake.org/cmake/help/latest/variable/CMAKE_NINJA_PARALLEL_LINK_JOBS.html), and the snippet is minimal and correct.