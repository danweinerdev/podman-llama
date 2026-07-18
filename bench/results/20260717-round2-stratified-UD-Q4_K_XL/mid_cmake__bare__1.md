Here's a minimal CMakeLists.txt snippet that sets `CMAKE_NINJA_PARALLEL_LINK_JOBS` before the `project()` command (this variable must be set before project initialization to take effect):

```cmake
cmake_minimum_required(VERSION 3.20)

# Limit concurrent link jobs to 2 to avoid OOM during linking
set(CMAKE_NINJA_PARALLEL_LINK_JOBS 2 CACHE STRING "Limit link parallelism")

project(MyProject LANGUAGES CXX)
```

> **Important notes**:
> - Set it *before* `project()` — CMake reads this variable during project initialization.
> - Use `CACHE STRING` so it's recognized by CMake's config system (non-cache works too but `CACHE` is recommended).
> - You can also set it via environment variable or command-line: `CMAKE_NINJA_PARALLEL_LINK_JOBS=2 cmake ..`, but since you asked for CMakeLists.txt, the above snippet is the clean way.

For older CMake (<3.16), this variable wasn’t supported — ensure you're using CMake ≥3.16 (it was introduced in [CMake 3.16.0](https://cmake.org/cmake/help/v3.16/release/3.16.html#cmake-features)).