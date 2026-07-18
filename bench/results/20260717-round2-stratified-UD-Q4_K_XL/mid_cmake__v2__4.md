Plan: Set `CMAKE_NINJA_PARALLEL_LINK_JOBS` to 2 in CMakeLists.txt to limit concurrent link jobs and prevent OOM. This variable is read *before* the `project()` command or during early setup to take effect. Known: this is the standard CMake variable supported by Ninja generator (since CMake 3.14). Inferred: must be set before `project()` or at least before Ninja configures the build graph.

No need to modify build scripts beyond this assignment.

```cmake
set(CMAKE_NINJA_PARALLEL_LINK_JOBS 2)
project(MyProject CXX)
# ... rest of CMakeLists.txt
```