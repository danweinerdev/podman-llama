Plan: Set `CMAKE_NINJA_PARALLEL_LINK_JOBS` to 2 early in CMakeLists.txt so it takes effect before any link jobs are started. This variable must be set as a CMake *cache* variable (or at least before the `project()` call) to be honored by Ninja.

**Assumptions**:  
- You're using Ninja generator (`-G Ninja`) — known from prompt.  
- `CMAKE_NINJA_PARALLEL_LINK_JOBS` is honored by CMake ≥3.14 (it is — introduced in 3.14.0).  
- Edge case: if set *after* `project()`, Ninja may have already started link jobs → must set *before* `project()`.

**Approach**:  
1. Place `set(CMAKE_NINJA_PARALLEL_LINK_JOBS 2 CACHE STRING "")` right after the `cmake_minimum_required()` and *before* `project()`.  
2. That’s sufficient — CMake will propagate it to the Ninja build config.

Here's the snippet:

```cmake
cmake_minimum_required(VERSION 3.14)

# Must be set *before* project() to take effect
set(CMAKE_NINJA_PARALLEL_LINK_JOBS 2 CACHE STRING "")

project(MyProject LANGUAGES CXX)
```

Check: Clean build with `cmake -S . -B build -G Ninja && cmake --build build` — verify linking is now serialized to 2 jobs (e.g., `ninja -v` shows max two `c++`/`ld` invocations in parallel).