# libsodium-cmake

Simple set up instructions
```
git clone --recurse-submodules https://github.com/shelltitan/libsodium-cmake.git
cd libsodium-cmake
cmake -B build
cmake --build build
cmake --install build
```

If you want to pair it with your custom toolchain or use a different generator
```
cmake -G <generator-of-choice> -B <build-folder> -DCMAKE_BUILD_TYPE=<build-type> -DCMAKE_TOOLCHAIN_FILE=<toolchain-file>
```

To list different build options
```
cmake -LAH
```