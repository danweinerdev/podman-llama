Here's the CMakeLists.txt snippet you can add (typically near the top, after `cmake_minimum_required` and before `project`, or anywhere before the first `add_executable`/`add_library`):

```cmake
# Limit parallel link jobs to avoid OOM during linking
set(CMAKE_NINJA_PARALLEL_LINK_JOBS 2)
```

✅ **Important notes**:
- This variable only affects **Ninja** builds (not Make, VS, etc.).
- It must be set **before** the first linkable target is defined (i.e., before `add_executable`, `add_library`).
- Works with CMake ≥ 3.20 (though behavior was improved in later versions).
- For full effectiveness, ensure your `CMAKE_MAKE_PROGRAM` is set to Ninja (e.g., `cmake -G Ninja`).

💡 Tip: If you want to be extra safe (e.g., for CI or low-memory systems), you can set it conditionally:

```cmake
if(CMAKE_GENERATOR STREQUAL "Ninja")
  set(CMAKE_NINJA_PARALLEL_LINK_JOBS 2 CACHE STRING "Limit parallel link jobs to avoid OOM")
endif()
```

This caches the value and makes it clear in `cmake-gui` or `ccmake`.