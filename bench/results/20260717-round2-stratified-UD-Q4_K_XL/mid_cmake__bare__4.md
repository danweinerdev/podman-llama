Here's a minimal CMakeLists.txt snippet that sets `CMAKE_NINJA_PARALLEL_LINK_JOBS` to `2` (preferably **before** `project()` to ensure it's respected):

```cmake
cmake_minimum_required(VERSION 3.14)

# Limit concurrent link jobs to avoid OOM (must be set before project())
set(CMAKE_NINJA_PARALLEL_LINK_JOBS 2)

project(MyProject LANGUAGES CXX)

# ... rest of your CMakeLists.txt
```

> 💡 **Note**: This variable only affects the Ninja generator and must be set in the CMakeLists.txt **before** `project()` (or via `-DCMAKE_NINJA_PARALLEL_LINK_JOBS=2` on the command line). CMake sets it as a cache variable internally when Ninja is used, but setting it as a plain variable early ensures it takes effect.