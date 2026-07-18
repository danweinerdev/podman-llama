Here's a minimal CMakeLists.txt snippet that sets `CMAKE_NINJA_PARALLEL_LINK_JOBS` to 2:

```cmake
cmake_minimum_required(VERSION 3.20)  # or any version ≥ 3.15

# Set the maximum number of concurrent link jobs to 2 (for Ninja)
set(CMAKE_NINJA_PARALLEL_LINK_JOBS 2)

project(MyProject)

add_executable(my_app main.cpp)
# ... rest of your CMakeLists.txt
```

> **Note**: `CMAKE_NINJA_PARALLEL_LINK_JOBS` is respected by Ninja only (not other generators), and must be set **before** the `project()` command to ensure it takes effect during toolchain discovery. It was introduced in CMake 3.15.