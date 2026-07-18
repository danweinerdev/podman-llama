Plan: Set `CMAKE_NINJA_PARALLEL_LINK_JOBS` to 2 early in `CMakeLists.txt` to limit concurrent link jobs and avoid OOM. This variable must be set before the first `project()` call to take effect, as Ninja generator initialization happens at `project()` time.

Assumptions:
- `known`: `CMAKE_NINJA_PARALLEL_LINK_JOBS` is a built-in CMake variable that controls how many link jobs Ninja runs in parallel.
- `inferred`: It must be set as a cache variable *before* `project()`; setting it after `project()` is ineffective (CMake’s documentation states it’s read at generator initialization).
- Edge cases: None — this is a configuration knob; no runtime logic involved.

Approach: Insert a `set(CACHE)` command before `project()`.

```cmake
set(CMAKE_NINJA_PARALLEL_LINK_JOBS 2 CACHE STRING "")
project(MyProject)
```