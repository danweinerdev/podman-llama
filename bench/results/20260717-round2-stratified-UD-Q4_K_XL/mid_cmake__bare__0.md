Here's the CMakeLists.txt snippet you can add (ideally near the top of your main CMakeLists.txt, before the first `add_executable`/`add_library` that uses linking):

```cmake
# Limit parallel link jobs to avoid out-of-memory during linking
set(CMAKE_NINJA_PARALLEL_LINK_JOBS 2 CACHE STRING "Maximum number of parallel link jobs for Ninja")
```

> 💡 **Note**: This variable must be set **before** CMake generates the build system (i.e., before running `cmake ..`). Setting it via `CACHE` ensures it persists across reconfigures and is respected by Ninja.  
> The value `2` caps the number of simultaneous link operations—adjust as needed based on your machine’s memory.