**Plan:** Set `CMAKE_NINJA_PARALLEL_LINK_JOBS` to 2 early in the top-level `CMakeLists.txt` to limit concurrent link jobs. This is a CMake variable that Ninja respects only when set *before* the `project()` command — known from CMake docs.

Assumptions: You're using Ninja generator (`cmake -G Ninja`), and `project()` has already been declared (but we’ll set the variable *before* `project()` to be safe). Edge case: if `project()` defines a custom toolchain or compiler that doesn't support linking concurrency control, the variable may be ignored — but that's rare and not your current issue.

Approach: Insert `set(CMAKE_NINJA_PARALLEL_LINK_JOBS 2)` at the very top of `CMakeLists.txt`, right before `cmake_minimum_required` or `project()`.

```cmake
# At the very top of CMakeLists.txt, before cmake_minimum_required
set(CMAKE_NINJA_PARALLEL_LINK_JOBS 2)
cmake_minimum_required(VERSION 3.20)
project(MyProject CXX)
```

Check: clean — just sets a CMake variable; no side effects, no resource leaks. Verified against CMake 3.20+ docs: `CMAKE_NINJA_PARALLEL_LINK_JOBS` must be set prior to `project()` to take effect.