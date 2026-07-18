Here's a CMakeLists.txt snippet showing how to set `CMAKE_NINJA_PARALLEL_LINK_JOBS` before the `project()` command (so it takes effect):

```cmake
cmake_minimum_required(VERSION 3.12)

# Set the number of parallel link jobs *before* project() to ensure Ninja picks it up
set(CMAKE_NINJA_PARALLEL_LINK_JOBS 2 CACHE STRING "" FORCE)

project(MyProject LANGUAGES CXX)

# ... rest of your CMakeLists.txt ...
```

> **Important**: This variable must be set *before* `project()` is called (i.e., before CMake configures the build system), otherwise Ninja won't see it.  
> The `CACHE ... FORCE` ensures it survives any reconfiguration and overrides potential command-line overrides — omit `CACHE` if you prefer it to be user-configurable (e.g., via `-D CMAKE_NINJA_PARALLEL_LINK_JOBS=2`).

Alternative (if you want to allow user override but still set a default):

```cmake
if(NOT DEFINED CMAKE_NINJA_PARALLEL_LINK_JOBS)
  set(CMAKE_NINJA_PARALLEL_LINK_JOBS 2)
endif()
```

But keep it **before** `project()`.