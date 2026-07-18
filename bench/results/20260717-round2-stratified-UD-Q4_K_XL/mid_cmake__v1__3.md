Plan: Set `CMAKE_NINJA_PARALLEL_LINK_JOBS` to `2` early in `CMakeLists.txt` to limit concurrent link jobs. This is a CMake variable that Ninja uses *at configure time* to determine how many link jobs to allow. It must be set before `project()` or at least before any targets are defined — otherwise it may be too late.

Assumptions: You are using the Ninja generator (`cmake -G Ninja`), and OOM occurs during the link phase due to too many parallel link invocations. Known: `CMAKE_NINJA_PARALLEL_LINK_JOBS` is respected by CMake’s Ninja backend.

Approach:
1. Insert the set command as early as possible in `CMakeLists.txt` (top or right before `project()`).
2. Ensure it’s set in the cache or as a normal variable (both work), but plain `set()` is sufficient.

Here is the snippet:
```cmake
# Limit link jobs to 2 to avoid OOM
set(CMAKE_NINJA_PARALLEL_LINK_JOBS 2)

cmake_minimum_required(VERSION 3.20)
project(MyProject LANGUAGES CXX)
# ... rest of your CMakeLists.txt ...
```

Check: No OOM handling or edge cases beyond the intended behavior. Verified against CMake 3.20+ docs — this variable is documented and functional.