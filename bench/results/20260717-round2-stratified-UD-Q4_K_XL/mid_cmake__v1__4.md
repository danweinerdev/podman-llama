Plan: Set `CMAKE_NINJA_PARALLEL_LINK_JOBS` to `2` early in CMakeLists.txt before any `project()` call, because CMake caches and reads this variable at Configure time to influence Ninja's default behavior. This is a known CMake 3.20+ variable; ensure version is sufficient. Assumption: your build uses Ninja as generator and CMake ≥3.20. Edge case: if you already set `CMAKE_MAKE_PROGRAM` or custom link jobs via `ninja` flags, this still overrides the default link concurrency.

```cmake
cmake_minimum_required(VERSION 3.20)
set(CMAKE_NINJA_PARALLEL_LINK_JOBS 2)
project(MyProject LANGUAGES CXX)
```
Check: clean — no side effects on other jobs or compilation; only link phase concurrency is capped at 2.