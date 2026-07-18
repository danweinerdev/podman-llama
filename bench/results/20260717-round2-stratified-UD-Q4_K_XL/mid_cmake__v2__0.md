Plan: Set `CMAKE_NINJA_PARALLEL_LINK_JOBS` to 2 in CMakeLists.txt to limit parallel link jobs and avoid OOM. This is a CMake variable that must be set *before* the `project()` call, or at least before the linker jobs are initialized (typically after `cmake_minimum_required` and before `project`). Known: CMake 3.18+ supports this variable; inferred: user’s current setup doesn’t limit link parallelism, causing OOM. Edge cases: if set after `project()` with certain generator states, behavior may be undefined — best practice is to set it early. Approach: add variable assignment right after `cmake_minimum_required` and before `project()`.

```cmake
cmake_minimum_required(VERSION 3.18)
set(CMAKE_NINJA_PARALLEL_LINK_JOBS 2)
project(MyProject LANGUAGES CXX)
```
Check: clean — only adds one line after the minimum required version and before project, which is the documented correct location for this variable; no other code changed.