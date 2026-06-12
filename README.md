# libsodium-cmake

## Position Independent Code

CMake's standard `CMAKE_POSITION_INDEPENDENT_CODE` setting controls PIC for this project.
You normally do not need to set it for shared builds, because CMake handles the shared library requirements.

Set it when building a static library that will later be linked into another shared library:

```sh
cmake -S . -B build -DBUILD_SHARED_LIBS=OFF -DCMAKE_POSITION_INDEPENDENT_CODE=ON
```

PIE flags for executables should be configured on the executable target that links to libsodium, not on the libsodium library target.

## Autotools Compatibility Notes

Unlike upstream's Autotools build, this CMake build does not currently undefine `NDEBUG`; release builds may therefore compile out `assert()` calls unless that is handled separately.
