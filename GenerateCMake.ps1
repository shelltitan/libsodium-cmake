$libsodiumRoot = "libsodium" 

# Get all .c and .h files inside src/libsodium/
$srcDir = Join-Path $libsodiumRoot "src\libsodium"

# Get source and header files relative to the source directory
$sourceFiles = Get-ChildItem -Recurse -Include *.c -Path $srcDir | ForEach-Object {
	$relativePath = $_.FullName.Replace($PSScriptRoot, "").Replace("\", "/")
    $relativePath.TrimStart("/").TrimStart("\")
}

$headerFiles = Get-ChildItem -Recurse -Include *.h -Path $srcDir | ForEach-Object {
    $relativePath = $_.FullName.Replace($PSScriptRoot, "").Replace("\", "/")
    $relativePath.TrimStart("/").TrimStart("\")
}

# Print the lists
Write-Host "`n=== Source Files ===" -ForegroundColor Cyan
$sourceFiles | ForEach-Object { Write-Host $_ }
$quotedSources = $sourceFiles | ForEach-Object { "`"$($_)`"" }
$joinedSources = $quotedSources -join "`n    "

Write-Host "`n=== Header Files ===" -ForegroundColor Green
$headerFiles | ForEach-Object { Write-Host $_ }
$quotedHeaders = $headerFiles | ForEach-Object { "`"$($_)`"" }
$joinedHeaders = $quotedHeaders -join "`n    "

@"
cmake_minimum_required(
	VERSION 4.0.0 
	FATAL_ERROR
)

project(
	libsodium 
	LANGUAGES C
)

option(SODIUM_DISABLE_TESTS "Disable tests" OFF)
option(SODIUM_MINIMAL "Only compile the minimum set of functions required for the high-level API" OFF)
option(SODIUM_ENABLE_BLOCKING_RANDOM "Enable this switch only if /dev/urandom is totally broken on the target platform" OFF)

set(
    Header_Files
	$joinedHeaders
)

source_group(
	TREE "`${CMAKE_CURRENT_SOURCE_DIR}/libsodium/src/libsodium" 
	PREFIX "Header Files" 
	FILES `${Header_Files}
)

set(
    Source_Files
	$joinedSources
)

source_group(
    TREE "`${CMAKE_CURRENT_SOURCE_DIR}/libsodium/src/libsodium" 
    PREFIX "Source Files" 
    FILES `${Source_Files}
)

set(
    ALL_FILES
    `${Header_Files}
    `${Source_Files}
)

add_library(
    `${PROJECT_NAME} 
    `${ALL_FILES}
)

set_target_properties(
	${PROJECT_NAME}
    PROPERTIES
    C_STANDARD 99
)

target_include_directories(
	`${PROJECT_NAME} 
	PUBLIC
    `${CMAKE_CURRENT_SOURCE_DIR}/libsodium/src/libsodium/include
	PRIVATE
	`${CMAKE_CURRENT_SOURCE_DIR}/libsodium/src/libsodium/include/sodium
)

target_compile_definitions(
	`${PROJECT_NAME}
    PUBLIC
        $<$<NOT:$<BOOL:${BUILD_SHARED_LIBS}>>:SODIUM_STATIC>
        $<$<BOOL:${SODIUM_MINIMAL}>:SODIUM_LIBRARY_MINIMAL>
    PRIVATE
        CONFIGURED
        $<$<BOOL:${BUILD_SHARED_LIBS}>:SODIUM_DLL_EXPORT>
        $<$<BOOL:${SODIUM_ENABLE_BLOCKING_RANDOM}>:USE_BLOCKING_RANDOM>
        $<$<BOOL:${SODIUM_MINIMAL}>:MINIMAL>
        $<$<C_COMPILER_FRONTEND_VARIANT:MSVC>:_CRT_SECURE_NO_WARNINGS>
)

if(CMAKE_C_COMPILER_ID STREQUAL "Clang" AND CMAKE_C_COMPILER_FRONTEND_VARIANT STREQUAL "MSVC")
    # Special manual feature-handling for clang-cl.
    target_compile_options(
		`${PROJECT_NAME}
        PUBLIC
            # blake2b-compress-avx2
            -mavx2
        PRIVATE
            # aead_aes256gcm_aesni
            -maes
            -mpclmul
            -mssse3
    )
endif()

if(SODIUM_MINIMAL)
    set(SODIUM_LIBRARY_MINIMAL_DEF "#define SODIUM_LIBRARY_MINIMAL 1")
endif()
set(VERSION 1.0.21)
set(SODIUM_LIBRARY_VERSION_MAJOR 28)
set(SODIUM_LIBRARY_VERSION_MINOR 0)

configure_file(
    libsodium/src/libsodium/include/sodium/version.h.in
    `${CMAKE_CURRENT_SOURCE_DIR}/libsodium/src/libsodium/include/sodium/version.h
)

if(NOT SODIUM_DISABLE_TESTS)
    enable_testing()
endif()

"@ | Set-Content "CMakeLists.txt"

Write-Host "CMakeLists.txt generated" -ForegroundColor Yellow