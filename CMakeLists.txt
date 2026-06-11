cmake_minimum_required(
    VERSION 4.2.0
    FATAL_ERROR
)

project(
    libsodium
    VERSION 1.0.23
    LANGUAGES C
)

include(GNUInstallDirs)
include(CheckCCompilerFlag)
include(CheckCSourceCompiles)
include(CheckFunctionExists)
include(CheckIncludeFile)
include(CheckLibraryExists)
include(CheckLinkerFlag)
include(CheckSymbolExists)
include(CMakePushCheckState)
include(TestBigEndian)

option(SODIUM_MINIMAL "Only compile the minimum set of functions required for the high-level API" OFF)
option(SODIUM_ENABLE_BLOCKING_RANDOM "Enable this switch only if /dev/urandom is totally broken on the target platform" OFF)
option(SODIUM_ENABLE_SSP "Compile with stack protector flags when supported" ON)
option(SODIUM_ENABLE_ASM "Compile assembly code and assembly-backed implementations when supported" ON)
option(SODIUM_ENABLE_PIE "Produce position independent code/executables when supported" ON)
option(SODIUM_WITH_PTHREADS "Use pthreads library when available" ON)
option(SODIUM_WITH_SAFECODE "For maintainers only - please do not use" OFF)
option(SODIUM_WITH_CTGRIND "For maintainers only - please do not use" OFF)
option(SODIUM_ENABLE_RETPOLINE "Use return trampolines for indirect calls when supported" OFF)
option(SODIUM_ENABLE_DEBUG "For maintainers only - please do not use" OFF)
option(SODIUM_ENABLE_OPT "Optimize for the native CPU - the resulting library will be faster but not portable" OFF)
option(SODIUM_ENABLE_SONAME_VERSIONS "Enable soname versions" ON)

set(SODIUM_SAFECODE_HOME "/opt/safecode" CACHE PATH "SafeCode base directory")
set(SODIUM_CWFLAGS "" CACHE STRING "Extra warning flags used when SODIUM_ENABLE_DEBUG is enabled")

set(VERSION "1.0.23")
set(PACKAGE_NAME "libsodium")
set(PACKAGE_VERSION "${VERSION}")
set(SODIUM_LIBRARY_VERSION_MAJOR 30)
set(SODIUM_LIBRARY_VERSION_MINOR 0)
set(SODIUM_LIBRARY_VERSION "30:0:0")
set(DLL_VERSION "${SODIUM_LIBRARY_VERSION_MAJOR}")
set(PKGCONFIG_LIBS_PRIVATE "")
set(prefix "\${pcfiledir}/../..")
set(exec_prefix "\${prefix}")
set(libdir "\${exec_prefix}/${CMAKE_INSTALL_LIBDIR}")
set(includedir "\${prefix}/${CMAKE_INSTALL_INCLUDEDIR}")

if(CMAKE_SYSTEM_NAME STREQUAL "Emscripten" OR CMAKE_C_COMPILER MATCHES "emcc")
    set(SODIUM_EMSCRIPTEN ON)
else()
    set(SODIUM_EMSCRIPTEN OFF)
endif()

set(SODIUM_EFFECTIVE_ENABLE_ASM ${SODIUM_ENABLE_ASM})
if(SODIUM_EMSCRIPTEN)
    set(SODIUM_EFFECTIVE_ENABLE_ASM OFF)
    message(STATUS "Emscripten target detected; asm implementations disabled")
endif()

function(sodium_check_c_source_compiles_with_flags output_variable flags source)
    cmake_push_check_state(RESET)
    set(CMAKE_REQUIRED_QUIET TRUE)
    set(CMAKE_REQUIRED_FLAGS "${flags}")
    check_c_source_compiles("${source}" ${output_variable})
    cmake_pop_check_state()
endfunction()

function(sodium_append_supported_compile_option output_variable option)
    string(MAKE_C_IDENTIFIER "${option}" option_id)
    set(flag_variable "SODIUM_SUPPORTS_${option_id}")
    check_c_compiler_flag("${option}" ${flag_variable})
    if(${flag_variable})
        set(${output_variable} "${${output_variable}};${option}" PARENT_SCOPE)
    endif()
endfunction()

function(sodium_append_supported_compile_warning output_variable option)
    string(MAKE_C_IDENTIFIER "${output_variable}_${option}" option_id)
    set(flag_variable "SODIUM_SUPPORTS_${option_id}")
    set(required_flags "")
    set(candidate_flags "${${output_variable}}")
    list(APPEND candidate_flags "${option}")
    foreach(candidate_flag IN LISTS candidate_flags)
        string(APPEND required_flags " ${candidate_flag}")
    endforeach()
    cmake_push_check_state(RESET)
    set(CMAKE_REQUIRED_FLAGS "${required_flags}")
    check_c_source_compiles("int main(void) { return 0; }" ${flag_variable})
    cmake_pop_check_state()
    if(${flag_variable})
        set(${output_variable} "${${output_variable}};${option}" PARENT_SCOPE)
    endif()
endfunction()

function(sodium_append_supported_link_option output_variable option)
    string(MAKE_C_IDENTIFIER "${option}" option_id)
    set(flag_variable "SODIUM_SUPPORTS_LINK_${option_id}")
    check_linker_flag(C "${option}" ${flag_variable})
    if(${flag_variable})
        set(${output_variable} "${${output_variable}};${option}" PARENT_SCOPE)
    endif()
endfunction()

function(sodium_add_definition_if output_variable condition_variable definition)
    if(${condition_variable})
        set(${output_variable} "${${output_variable}};${definition}=1" PARENT_SCOPE)
    endif()
endfunction()

set(SODIUM_COMMON_COMPILE_OPTIONS "")
set(SODIUM_COMMON_LINK_OPTIONS "")
set(SODIUM_CWFLAGS_LIST "")
set(SODIUM_OUTPUT_DEF_FILE "")

if(NOT "${CMAKE_C_COMPILER_FRONTEND_VARIANT}" STREQUAL "MSVC")
    sodium_append_supported_compile_option(SODIUM_COMMON_COMPILE_OPTIONS "-fvisibility=hidden")
    sodium_append_supported_compile_option(SODIUM_COMMON_COMPILE_OPTIONS "-fno-strict-aliasing")
    sodium_append_supported_compile_option(SODIUM_COMMON_COMPILE_OPTIONS "-fno-strict-overflow")
    if(NOT SODIUM_COMMON_COMPILE_OPTIONS MATCHES "(^|;)-fno-strict-overflow($|;)")
        sodium_append_supported_compile_option(SODIUM_COMMON_COMPILE_OPTIONS "-fwrapv")
    endif()
    sodium_append_supported_compile_option(SODIUM_COMMON_COMPILE_OPTIONS "-Wno-deprecated-declarations")
    sodium_append_supported_compile_option(SODIUM_COMMON_COMPILE_OPTIONS "-Wno-unknown-pragmas")

    if(SODIUM_ENABLE_SSP)
        sodium_append_supported_compile_option(SODIUM_COMMON_COMPILE_OPTIONS "-fstack-protector")
    endif()

    if(SODIUM_ENABLE_PIE)
        sodium_append_supported_compile_option(SODIUM_COMMON_COMPILE_OPTIONS "-fPIE")
    endif()

    if(SODIUM_ENABLE_RETPOLINE)
        sodium_append_supported_compile_option(SODIUM_COMMON_COMPILE_OPTIONS "-mindirect-branch=thunk-inline")
        if(NOT SODIUM_COMMON_COMPILE_OPTIONS MATCHES "(^|;)-mindirect-branch=thunk-inline($|;)")
            sodium_append_supported_compile_option(SODIUM_COMMON_COMPILE_OPTIONS "-mretpoline")
        endif()
        sodium_append_supported_compile_option(SODIUM_COMMON_COMPILE_OPTIONS "-mindirect-branch-register")
    endif()

    if(SODIUM_ENABLE_OPT)
        sodium_append_supported_compile_option(SODIUM_COMMON_COMPILE_OPTIONS "-ftree-vectorize")
        sodium_append_supported_compile_option(SODIUM_COMMON_COMPILE_OPTIONS "-ftree-slp-vectorize")
        sodium_append_supported_compile_option(SODIUM_COMMON_COMPILE_OPTIONS "-fomit-frame-pointer")
        sodium_append_supported_compile_option(SODIUM_COMMON_COMPILE_OPTIONS "-march=native")
        sodium_append_supported_compile_option(SODIUM_COMMON_COMPILE_OPTIONS "-mtune=native")
    endif()

    if(NOT SODIUM_EMSCRIPTEN)
        sodium_append_supported_link_option(SODIUM_COMMON_LINK_OPTIONS "-Wl,-z,relro")
        sodium_append_supported_link_option(SODIUM_COMMON_LINK_OPTIONS "-Wl,-z,now")
        sodium_append_supported_link_option(SODIUM_COMMON_LINK_OPTIONS "-Wl,-z,noexecstack")
    endif()
endif()

if(BUILD_SHARED_LIBS AND (WIN32 OR CYGWIN) AND NOT "${CMAKE_C_COMPILER_LINKER_FRONTEND_VARIANT}" STREQUAL "MSVC")
    check_linker_flag(C "-Wl,--output-def,conftest.def" SODIUM_SUPPORTS_LINK_OUTPUT_DEF)
    if(SODIUM_SUPPORTS_LINK_OUTPUT_DEF)
        set(SODIUM_OUTPUT_DEF_FILE "${CMAKE_CURRENT_BINARY_DIR}/${PROJECT_NAME}-${DLL_VERSION}.def")
        list(APPEND SODIUM_COMMON_LINK_OPTIONS "-Wl,--output-def,${SODIUM_OUTPUT_DEF_FILE}")
    endif()
endif()

if(SODIUM_ENABLE_DEBUG)
    if(NOT "${CMAKE_C_COMPILER_FRONTEND_VARIANT}" STREQUAL "MSVC")
        sodium_append_supported_compile_option(SODIUM_COMMON_COMPILE_OPTIONS "-O")
        sodium_append_supported_compile_option(SODIUM_COMMON_COMPILE_OPTIONS "-g3")
        sodium_append_supported_compile_option(SODIUM_COMMON_COMPILE_OPTIONS "-U_FORTIFY_SOURCE")
    endif()
    separate_arguments(SODIUM_CWFLAGS_LIST NATIVE_COMMAND "${SODIUM_CWFLAGS}")
    if(NOT "${CMAKE_C_COMPILER_FRONTEND_VARIANT}" STREQUAL "MSVC")
        sodium_append_supported_compile_warning(SODIUM_CWFLAGS_LIST "-Wall")
        if(CMAKE_C_COMPILER_ID MATCHES "Clang")
            sodium_append_supported_compile_warning(SODIUM_CWFLAGS_LIST "-Wno-unknown-warning-option")
        endif()
        foreach(sodium_cwflag IN ITEMS
            "-Wextra"
            "-Warray-bounds"
            "-Wbad-function-cast"
            "-Wcast-qual"
            "-Wdiv-by-zero"
            "-Wduplicated-branches"
            "-Wduplicated-cond"
            "-Wfloat-equal"
            "-Wformat=2"
            "-Wlogical-op"
            "-Wmaybe-uninitialized"
            "-Wmisleading-indentation"
            "-Wmissing-declarations"
            "-Wmissing-prototypes"
            "-Wnested-externs"
            "-Wno-type-limits"
            "-Wno-unknown-pragmas"
            "-Wnormalized=id"
            "-Wnull-dereference"
            "-Wold-style-declaration"
            "-Wpointer-arith"
            "-Wredundant-decls"
            "-Wrestrict"
            "-Wshorten-64-to-32"
            "-Wsometimes-uninitialized"
            "-Wstrict-prototypes"
            "-Wswitch-enum"
            "-Wvariable-decl"
            "-Wvla"
            "-Wwrite-strings"
        )
            sodium_append_supported_compile_warning(SODIUM_CWFLAGS_LIST "${sodium_cwflag}")
        endforeach()
    endif()
endif()

check_include_file("sys/mman.h" SODIUM_HAVE_SYS_MMAN_H)
check_include_file("sys/param.h" SODIUM_HAVE_SYS_PARAM_H)
check_include_file("sys/random.h" SODIUM_HAVE_SYS_RANDOM_H)
check_include_file("intrin.h" SODIUM_HAVE_INTRIN_H)
check_include_file("sys/auxv.h" SODIUM_HAVE_SYS_AUXV_H)
check_include_file("CommonCrypto/CommonRandom.h" SODIUM_HAVE_COMMONCRYPTO_COMMONRANDOM_H)
check_include_file("cet.h" SODIUM_HAVE_CET_H)
check_include_file("threads.h" SODIUM_HAVE_THREADS_H)
check_include_file("alloca.h" SODIUM_HAVE_ALLOCA_H)

test_big_endian(SODIUM_IS_BIG_ENDIAN)
if(SODIUM_IS_BIG_ENDIAN)
    set(SODIUM_NATIVE_BIG_ENDIAN ON)
    set(SODIUM_NATIVE_LITTLE_ENDIAN OFF)
else()
    set(SODIUM_NATIVE_BIG_ENDIAN OFF)
    set(SODIUM_NATIVE_LITTLE_ENDIAN ON)
endif()

check_c_source_compiles([[
int main(void) {
    int n = 1;
    char vla[n];
    return (int) sizeof vla - 1;
}
]] SODIUM_HAVE_C_VARARRAYS)

check_symbol_exists(alloca "alloca.h;stdlib.h" SODIUM_HAVE_ALLOCA)
check_function_exists(arc4random SODIUM_HAVE_ARC4RANDOM)
check_function_exists(arc4random_buf SODIUM_HAVE_ARC4RANDOM_BUF)
check_function_exists(mmap SODIUM_HAVE_MMAP)
check_function_exists(mlock SODIUM_HAVE_MLOCK)
check_function_exists(madvise SODIUM_HAVE_MADVISE)
check_function_exists(mprotect SODIUM_HAVE_MPROTECT)
check_function_exists(raise SODIUM_HAVE_RAISE)
check_function_exists(sysconf SODIUM_HAVE_SYSCONF)
check_function_exists(getpid SODIUM_HAVE_GETPID)
check_function_exists(getauxval SODIUM_HAVE_GETAUXVAL)
check_function_exists(elf_aux_info SODIUM_HAVE_ELF_AUX_INFO)
check_function_exists(posix_memalign SODIUM_HAVE_POSIX_MEMALIGN)
check_function_exists(nanosleep SODIUM_HAVE_NANOSLEEP)
check_function_exists(clock_gettime SODIUM_HAVE_CLOCK_GETTIME)
check_function_exists(memset_s SODIUM_HAVE_MEMSET_S)
check_function_exists(explicit_bzero SODIUM_HAVE_EXPLICIT_BZERO)
check_function_exists(memset_explicit SODIUM_HAVE_MEMSET_EXPLICIT)
check_function_exists(explicit_memset SODIUM_HAVE_EXPLICIT_MEMSET)

if(WIN32)
    set(SODIUM_HAVE_GETPID OFF)
endif()

if(NOT SODIUM_EMSCRIPTEN)
    check_symbol_exists(getrandom "stdlib.h;unistd.h;sys/random.h" SODIUM_HAVE_GETRANDOM)
    check_symbol_exists(getentropy "stdlib.h;unistd.h;sys/random.h" SODIUM_HAVE_GETENTROPY)
endif()

check_c_source_compiles([[
#ifdef __FILC__
# error inline assembly is not supported with FilC
#endif
int main(void) {
    int a = 42;
    int *pnt = &a;
    __asm__ __volatile__ ("" : : "r"(pnt) : "memory");
    return 0;
}
]] SODIUM_HAVE_INLINE_ASM)

if(SODIUM_NATIVE_LITTLE_ENDIAN AND NOT SODIUM_EMSCRIPTEN)
    check_c_source_compiles([[
#if !defined(__clang__) && !defined(__GNUC__) && !defined(__SIZEOF_INT128__)
# error mode(TI) is a gcc extension, and __int128 is not available
#endif
#if defined(__clang__) && !defined(__x86_64__) && !defined(__aarch64__)
# error clang does not properly handle the 128-bit type on 32-bit systems
#endif
#include <stddef.h>
#include <stdint.h>
#if defined(__SIZEOF_INT128__)
typedef unsigned __int128 uint128_t;
#else
typedef unsigned uint128_t __attribute__((mode(TI)));
#endif
void fcontract(uint128_t *t) {
    *t += 0x8000000000000 - 1;
    *t *= *t;
    *t >>= 84;
}
int main(void) { return 0; }
]] SODIUM_HAVE_TI_MODE)
else()
    set(SODIUM_HAVE_TI_MODE OFF)
endif()

if(SODIUM_EFFECTIVE_ENABLE_ASM)
    check_c_source_compiles([[
int main(void) {
#if defined(__amd64) || defined(__amd64__) || defined(__x86_64__)
# if defined(__CYGWIN__) || defined(__MINGW32__) || defined(__MINGW64__) || defined(_WIN32) || defined(_WIN64) || defined(__midipix__)
#  error Windows x86_64 calling conventions are not supported here
# endif
#else
# error !x86_64
#endif
    unsigned char i = 0, o = 0, t;
    __asm__ __volatile__ ("pxor %%xmm12, %%xmm6 \n"
                          "movb (%[i]), %[t] \n"
                          "addb %[t], (%[o]) \n"
                          : [t] "=&r"(t)
                          : [o] "D"(&o), [i] "S"(&i)
                          : "memory", "flags", "cc");
    return 0;
}
]] SODIUM_HAVE_AMD64_ASM)

    check_c_source_compiles([[
int main(void) {
#if defined(__amd64) || defined(__amd64__) || defined(__x86_64__)
# if defined(__CYGWIN__) || defined(__MINGW32__) || defined(__MINGW64__) || defined(_WIN32) || defined(_WIN64)
#  error Windows x86_64 calling conventions are not supported here
# endif
#else
# error !x86_64
#endif
    __asm__ __volatile__ ("vpunpcklqdq %xmm0,%xmm13,%xmm0");
    return 0;
}
]] SODIUM_HAVE_AVX_ASM)

    check_c_source_compiles([[
int main(void) {
    unsigned int cpu_info[4];
    __asm__ __volatile__ ("xchgl %%ebx, %k1; cpuid; xchgl %%ebx, %k1" :
                          "=a" (cpu_info[0]), "=&r" (cpu_info[1]),
                          "=c" (cpu_info[2]), "=d" (cpu_info[3]) :
                          "0" (0U), "2" (0U));
    return 0;
}
]] SODIUM_HAVE_CPUID)

    check_c_source_compiles([[
int main(void) {
    __asm__ __volatile__ (".hidden dummy_symbol \n"
                          ".hidden _dummy_symbol \n"
                          ".globl dummy_symbol \n"
                          ".globl _dummy_symbol \n"
                          "dummy_symbol: \n"
                          "_dummy_symbol: \n"
                          "    nop \n");
    return 0;
}
]] SODIUM_HAVE_ASM_HIDDEN)
else()
    set(SODIUM_HAVE_AMD64_ASM OFF)
    set(SODIUM_HAVE_AVX_ASM OFF)
    set(SODIUM_HAVE_CPUID OFF)
    set(SODIUM_HAVE_ASM_HIDDEN OFF)
endif()

check_c_source_compiles([[
#if !defined(__ELF__) && !defined(__APPLE_CC__)
# error Support for weak symbols may not be available
#endif
__attribute__((weak)) void __dummy(void *x) { }
void f(void *x) { __dummy(x); }
int main(void) { return 0; }
]] SODIUM_HAVE_WEAK_SYMBOLS)

check_c_source_compiles([[
int main(void) {
    static volatile int _sodium_lock;
    __sync_lock_test_and_set(&_sodium_lock, 1);
    __sync_lock_release(&_sodium_lock);
    return 0;
}
]] SODIUM_HAVE_ATOMIC_OPS)

check_c_source_compiles([[
#include <stdatomic.h>
int main(void) {
    atomic_thread_fence(memory_order_acquire);
    return 0;
}
]] SODIUM_HAVE_C11_MEMORY_FENCES)

check_c_source_compiles([[
int main(void) {
    __atomic_thread_fence(__ATOMIC_ACQUIRE);
    return 0;
}
]] SODIUM_HAVE_GCC_MEMORY_FENCES)

check_c_source_compiles([[
#if defined(_MSC_VER)
# include <intrin.h>
#else
# include <immintrin.h>
#endif
int main(void) {
    (void) _xgetbv(0);
    return 0;
}
]] SODIUM_HAVE__XGETBV)

set(SODIUM_CFLAGS_ARMCRYPTO "")
set(SODIUM_CFLAGS_MMX "")
set(SODIUM_CFLAGS_SSE2 "")
set(SODIUM_CFLAGS_SSE3 "")
set(SODIUM_CFLAGS_SSSE3 "")
set(SODIUM_CFLAGS_SSE41 "")
set(SODIUM_CFLAGS_AVX "")
set(SODIUM_CFLAGS_AVX2 "")
set(SODIUM_CFLAGS_AVX512F "")
set(SODIUM_CFLAGS_AESNI "")
set(SODIUM_CFLAGS_PCLMUL "")
set(SODIUM_CFLAGS_RDRAND "")

if(NOT SODIUM_EMSCRIPTEN)
    check_c_source_compiles([[
#ifndef __aarch64__
# error Not aarch64
#endif
#include <arm_neon.h>
int main(void) { return 0; }
]] SODIUM_TARGET_CPU_AARCH64)

    if(SODIUM_TARGET_CPU_AARCH64)
        sodium_check_c_source_compiles_with_flags(SODIUM_HAVE_ARMCRYPTO "" [[
#ifndef __ARM_FEATURE_CRYPTO
# define __ARM_FEATURE_CRYPTO 1
#endif
#ifndef __ARM_FEATURE_AES
# define __ARM_FEATURE_AES 1
#endif
#include <arm_neon.h>
int main(void) {
    int64x2_t x = { 0, 0 };
    vaeseq_u8(vmovq_n_u8(0), vmovq_n_u8(0));
    vmull_high_p64(vreinterpretq_p64_s64(x), vreinterpretq_p64_s64(x));
    return 0;
}
]])
        if(NOT SODIUM_HAVE_ARMCRYPTO)
            check_c_compiler_flag("-march=armv8-a+crypto+aes" SODIUM_SUPPORTS_MARCH_ARMV8_CRYPTO_AES)
            if(SODIUM_SUPPORTS_MARCH_ARMV8_CRYPTO_AES)
                sodium_check_c_source_compiles_with_flags(SODIUM_HAVE_ARMCRYPTO_WITH_FLAG "-march=armv8-a+crypto+aes" [[
#ifndef __ARM_FEATURE_CRYPTO
# define __ARM_FEATURE_CRYPTO 1
#endif
#ifndef __ARM_FEATURE_AES
# define __ARM_FEATURE_AES 1
#endif
#include <arm_neon.h>
int main(void) {
    int64x2_t x = { 0, 0 };
    vaeseq_u8(vmovq_n_u8(0), vmovq_n_u8(0));
    vmull_high_p64(vreinterpretq_p64_s64(x), vreinterpretq_p64_s64(x));
    return 0;
}
]])
                if(SODIUM_HAVE_ARMCRYPTO_WITH_FLAG)
                    set(SODIUM_HAVE_ARMCRYPTO ON)
                    list(APPEND SODIUM_CFLAGS_ARMCRYPTO "-march=armv8-a+crypto+aes")
                endif()
            endif()
        endif()
    endif()

    check_c_compiler_flag("-mmmx" SODIUM_SUPPORTS_MMMX)
    if(SODIUM_SUPPORTS_MMMX)
        sodium_check_c_source_compiles_with_flags(SODIUM_HAVE_MMINTRIN_H "-mmmx" [[
#pragma GCC target("mmx")
#include <mmintrin.h>
int main(void) { __m64 x = _mm_setzero_si64(); (void) x; return 0; }
]])
        if(SODIUM_HAVE_MMINTRIN_H)
            list(APPEND SODIUM_CFLAGS_MMX "-mmmx")
        endif()
    endif()

    check_c_compiler_flag("-msse2" SODIUM_SUPPORTS_MSSE2)
    if(SODIUM_SUPPORTS_MSSE2)
        sodium_check_c_source_compiles_with_flags(SODIUM_HAVE_EMMINTRIN_H "-msse2" [[
#pragma GCC target("sse2")
#ifndef __SSE2__
# define __SSE2__
#endif
#include <emmintrin.h>
int main(void) {
    __m128d x = _mm_setzero_pd();
    __m128i z = _mm_srli_epi64(_mm_setzero_si128(), 26);
    (void) x; (void) z;
    return 0;
}
]])
        if(SODIUM_HAVE_EMMINTRIN_H)
            list(APPEND SODIUM_CFLAGS_SSE2 "-msse2")
        endif()
    endif()

    check_c_compiler_flag("-msse3" SODIUM_SUPPORTS_MSSE3)
    if(SODIUM_SUPPORTS_MSSE3)
        sodium_check_c_source_compiles_with_flags(SODIUM_HAVE_PMMINTRIN_H "-msse3" [[
#pragma GCC target("sse3")
#include <pmmintrin.h>
int main(void) {
    __m128 x = _mm_addsub_ps(_mm_cvtpd_ps(_mm_setzero_pd()),
                             _mm_cvtpd_ps(_mm_setzero_pd()));
    (void) x;
    return 0;
}
]])
        if(SODIUM_HAVE_PMMINTRIN_H)
            list(APPEND SODIUM_CFLAGS_SSE3 "-msse3")
        endif()
    endif()

    check_c_compiler_flag("-mssse3" SODIUM_SUPPORTS_MSSSE3)
    if(SODIUM_SUPPORTS_MSSSE3)
        sodium_check_c_source_compiles_with_flags(SODIUM_HAVE_TMMINTRIN_H "-mssse3" [[
#pragma GCC target("ssse3")
#include <tmmintrin.h>
int main(void) { __m64 x = _mm_abs_pi32(_m_from_int(0)); (void) x; return 0; }
]])
        if(SODIUM_HAVE_TMMINTRIN_H)
            list(APPEND SODIUM_CFLAGS_SSSE3 "-mssse3")
        endif()
    endif()

    check_c_compiler_flag("-msse4.1" SODIUM_SUPPORTS_MSSE41)
    if(SODIUM_SUPPORTS_MSSE41)
        sodium_check_c_source_compiles_with_flags(SODIUM_HAVE_SMMINTRIN_H "-msse4.1" [[
#pragma GCC target("sse4.1")
#include <smmintrin.h>
int main(void) { __m128i x = _mm_minpos_epu16(_mm_setzero_si128()); (void) x; return 0; }
]])
        if(SODIUM_HAVE_SMMINTRIN_H)
            list(APPEND SODIUM_CFLAGS_SSE41 "-msse4.1")
        endif()
    endif()

    check_c_compiler_flag("-mavx" SODIUM_SUPPORTS_MAVX)
    if(SODIUM_SUPPORTS_MAVX)
        sodium_check_c_source_compiles_with_flags(SODIUM_HAVE_AVXINTRIN_H "-mavx" [[
#pragma GCC target("avx")
#include <immintrin.h>
int main(void) { _mm256_zeroall(); return 0; }
]])
        if(SODIUM_HAVE_AVXINTRIN_H)
            list(APPEND SODIUM_CFLAGS_AVX "-mavx")
        endif()
    endif()

    check_c_compiler_flag("-mavx2" SODIUM_SUPPORTS_MAVX2)
    if(SODIUM_SUPPORTS_MAVX2)
        sodium_check_c_source_compiles_with_flags(SODIUM_HAVE_AVX2INTRIN_H "-mavx2" [[
#pragma GCC target("avx2")
#include <immintrin.h>
int main(void) {
    __m256 x = _mm256_set1_ps(3.14f);
    __m256 y = _mm256_permutevar8x32_ps(x, _mm256_set1_epi32(42));
    return _mm256_movemask_ps(_mm256_cmp_ps(x, y, _CMP_NEQ_OQ));
}
]])
        if(SODIUM_HAVE_AVX2INTRIN_H)
            list(APPEND SODIUM_CFLAGS_AVX2 "-mavx2")
        endif()
    endif()

    check_c_compiler_flag("-mavx512f" SODIUM_SUPPORTS_MAVX512F)
    if(SODIUM_SUPPORTS_MAVX512F)
        sodium_check_c_source_compiles_with_flags(SODIUM_HAVE_AVX512FINTRIN_H "-mavx512f" [[
#pragma GCC target("avx512f")
#include <immintrin.h>
int main(void) {
#ifndef __AVX512F__
# error No AVX512 support
#endif
    __m512i x = _mm512_setzero_epi32();
    __m512i y = _mm512_permutexvar_epi64(_mm512_setr_epi64(0, 1, 4, 5, 2, 3, 6, 7), x);
    (void) y;
    return 0;
}
]])
        if(SODIUM_HAVE_AVX512FINTRIN_H)
            list(APPEND SODIUM_CFLAGS_AVX512F "-mavx512f")
        endif()
    endif()

    check_c_compiler_flag("-maes" SODIUM_SUPPORTS_MAES)
    check_c_compiler_flag("-mpclmul" SODIUM_SUPPORTS_MPCLMUL)
    if(SODIUM_SUPPORTS_MAES AND SODIUM_SUPPORTS_MPCLMUL)
        sodium_check_c_source_compiles_with_flags(SODIUM_HAVE_WMMINTRIN_H "-maes -mpclmul" [[
#pragma GCC target("aes")
#pragma GCC target("pclmul")
#include <wmmintrin.h>
int main(void) {
    __m128i x = _mm_aesimc_si128(_mm_setzero_si128());
    __m128i y = _mm_clmulepi64_si128(_mm_setzero_si128(), _mm_setzero_si128(), 0);
    (void) x; (void) y;
    return 0;
}
]])
        if(SODIUM_HAVE_WMMINTRIN_H)
            list(APPEND SODIUM_CFLAGS_AESNI "-maes")
            list(APPEND SODIUM_CFLAGS_PCLMUL "-mpclmul")
        endif()
    endif()

    check_c_compiler_flag("-mrdrnd" SODIUM_SUPPORTS_MRDRND)
    if(SODIUM_SUPPORTS_MRDRND)
        sodium_check_c_source_compiles_with_flags(SODIUM_HAVE_RDRAND "-mrdrnd" [[
#pragma GCC target("rdrnd")
#include <immintrin.h>
int main(void) {
    unsigned long long x = 0;
    return _rdrand64_step(&x) == 0;
}
]])
        if(SODIUM_HAVE_RDRAND)
            list(APPEND SODIUM_CFLAGS_RDRAND "-mrdrnd")
        endif()
    endif()
endif()

if(SODIUM_WITH_PTHREADS)
    set(THREADS_PREFER_PTHREAD_FLAG TRUE)
    find_package(Threads)
    if(Threads_FOUND AND CMAKE_USE_PTHREADS_INIT)
        set(SODIUM_HAVE_PTHREAD ON)
        if(CMAKE_THREAD_LIBS_INIT)
            string(APPEND PKGCONFIG_LIBS_PRIVATE " ${CMAKE_THREAD_LIBS_INIT}")
        else()
            string(APPEND PKGCONFIG_LIBS_PRIVATE " -pthread")
        endif()
    else()
        set(SODIUM_HAVE_PTHREAD OFF)
        message(STATUS "pthread mutexes are not available")
    endif()
else()
    set(SODIUM_HAVE_PTHREAD OFF)
endif()

if(SODIUM_WITH_CTGRIND)
    check_library_exists(ctgrind ct_poison "" SODIUM_HAVE_LIBCTGRIND)
    if(NOT SODIUM_HAVE_LIBCTGRIND)
        message(FATAL_ERROR "SODIUM_WITH_CTGRIND is enabled, but libctgrind was not found")
    endif()
endif()

if(SODIUM_WITH_SAFECODE)
    if(NOT EXISTS "${SODIUM_SAFECODE_HOME}")
        message(FATAL_ERROR "SODIUM_WITH_SAFECODE is enabled, but SODIUM_SAFECODE_HOME does not exist: ${SODIUM_SAFECODE_HOME}")
    endif()
    list(APPEND SODIUM_COMMON_COMPILE_OPTIONS "-fmemsafety")
endif()

if(SODIUM_HAVE_AMD64_ASM OR SODIUM_HAVE_AVX_ASM)
    enable_language(ASM)
endif()

set(
    Header_Files
    "libsodium/src/libsodium/crypto_aead/aegis128l/aegis128l_aesni.h"
    "libsodium/src/libsodium/crypto_aead/aegis128l/aegis128l_armcrypto.h"
    "libsodium/src/libsodium/crypto_aead/aegis128l/aegis128l_common.h"
    "libsodium/src/libsodium/crypto_aead/aegis128l/aegis128l_soft.h"
    "libsodium/src/libsodium/crypto_aead/aegis128l/implementations.h"
    "libsodium/src/libsodium/crypto_aead/aegis256/aegis256_aesni.h"
    "libsodium/src/libsodium/crypto_aead/aegis256/aegis256_armcrypto.h"
    "libsodium/src/libsodium/crypto_aead/aegis256/aegis256_common.h"
    "libsodium/src/libsodium/crypto_aead/aegis256/aegis256_soft.h"
    "libsodium/src/libsodium/crypto_aead/aegis256/implementations.h"
    "libsodium/src/libsodium/crypto_core/ed25519/core_h2c.h"
    "libsodium/src/libsodium/crypto_core/keccak1600/armsha3/keccak1600_armsha3.h"
    "libsodium/src/libsodium/crypto_core/keccak1600/ref/keccak1600_ref.h"
    "libsodium/src/libsodium/crypto_generichash/blake2b/ref/blake2.h"
    "libsodium/src/libsodium/crypto_generichash/blake2b/ref/blake2b-compress-avx2.h"
    "libsodium/src/libsodium/crypto_generichash/blake2b/ref/blake2b-compress-sse41.h"
    "libsodium/src/libsodium/crypto_generichash/blake2b/ref/blake2b-compress-ssse3.h"
    "libsodium/src/libsodium/crypto_generichash/blake2b/ref/blake2b-load-avx2.h"
    "libsodium/src/libsodium/crypto_generichash/blake2b/ref/blake2b-load-sse2.h"
    "libsodium/src/libsodium/crypto_generichash/blake2b/ref/blake2b-load-sse41.h"
    "libsodium/src/libsodium/crypto_ipcrypt/implementations.h"
    "libsodium/src/libsodium/crypto_ipcrypt/ipcrypt_aesni.h"
    "libsodium/src/libsodium/crypto_ipcrypt/ipcrypt_armcrypto.h"
    "libsodium/src/libsodium/crypto_ipcrypt/ipcrypt_soft.h"
    "libsodium/src/libsodium/crypto_kem/mlkem768/ref/kem_mlkem768_ref.h"
    "libsodium/src/libsodium/crypto_onetimeauth/poly1305/donna/poly1305_donna.h"
    "libsodium/src/libsodium/crypto_onetimeauth/poly1305/donna/poly1305_donna32.h"
    "libsodium/src/libsodium/crypto_onetimeauth/poly1305/donna/poly1305_donna64.h"
    "libsodium/src/libsodium/crypto_onetimeauth/poly1305/onetimeauth_poly1305.h"
    "libsodium/src/libsodium/crypto_onetimeauth/poly1305/sse2/poly1305_sse2.h"
    "libsodium/src/libsodium/crypto_pwhash/argon2/argon2-core.h"
    "libsodium/src/libsodium/crypto_pwhash/argon2/argon2-encoding.h"
    "libsodium/src/libsodium/crypto_pwhash/argon2/argon2.h"
    "libsodium/src/libsodium/crypto_pwhash/argon2/blake2b-long.h"
    "libsodium/src/libsodium/crypto_pwhash/argon2/blamka-round-avx2.h"
    "libsodium/src/libsodium/crypto_pwhash/argon2/blamka-round-avx512f.h"
    "libsodium/src/libsodium/crypto_pwhash/argon2/blamka-round-neon.h"
    "libsodium/src/libsodium/crypto_pwhash/argon2/blamka-round-ref.h"
    "libsodium/src/libsodium/crypto_pwhash/argon2/blamka-round-ssse3.h"
    "libsodium/src/libsodium/crypto_pwhash/argon2/blamka-round-wasm32.h"
    "libsodium/src/libsodium/crypto_scalarmult/curve25519/ref10/x25519_ref10.h"
    "libsodium/src/libsodium/crypto_scalarmult/curve25519/scalarmult_curve25519.h"
    "libsodium/src/libsodium/crypto_shorthash/siphash24/ref/shorthash_siphash_ref.h"
    "libsodium/src/libsodium/crypto_sign/ed25519/ref10/sign_ed25519_ref10.h"
    "libsodium/src/libsodium/crypto_stream/chacha20/dolbeau/chacha20_dolbeau-avx2.h"
    "libsodium/src/libsodium/crypto_stream/chacha20/dolbeau/chacha20_dolbeau-ssse3.h"
    "libsodium/src/libsodium/crypto_stream/chacha20/dolbeau/u0.h"
    "libsodium/src/libsodium/crypto_stream/chacha20/dolbeau/u1.h"
    "libsodium/src/libsodium/crypto_stream/chacha20/dolbeau/u4.h"
    "libsodium/src/libsodium/crypto_stream/chacha20/dolbeau/u8.h"
    "libsodium/src/libsodium/crypto_stream/chacha20/ref/chacha20_ref.h"
    "libsodium/src/libsodium/crypto_stream/chacha20/stream_chacha20.h"
    "libsodium/src/libsodium/crypto_stream/salsa20/stream_salsa20.h"
    "libsodium/src/libsodium/crypto_stream/salsa20/xmm6int/salsa20_xmm6int-avx2.h"
    "libsodium/src/libsodium/crypto_stream/salsa20/xmm6int/u0.h"
    "libsodium/src/libsodium/crypto_stream/salsa20/xmm6int/u1.h"
    "libsodium/src/libsodium/crypto_stream/salsa20/xmm6int/u4.h"
    "libsodium/src/libsodium/crypto_stream/salsa20/xmm6int/u8.h"
    "libsodium/src/libsodium/crypto_xof/shake128/ref/shake128_ref.h"
    "libsodium/src/libsodium/crypto_xof/shake256/ref/shake256_ref.h"
    "libsodium/src/libsodium/crypto_xof/turboshake128/ref/turboshake128_ref.h"
    "libsodium/src/libsodium/crypto_xof/turboshake256/ref/turboshake256_ref.h"
    "libsodium/src/libsodium/include/sodium.h"
    "libsodium/src/libsodium/include/sodium/core.h"
    "libsodium/src/libsodium/include/sodium/crypto_aead_aegis128l.h"
    "libsodium/src/libsodium/include/sodium/crypto_aead_aegis256.h"
    "libsodium/src/libsodium/include/sodium/crypto_aead_aes256gcm.h"
    "libsodium/src/libsodium/include/sodium/crypto_aead_chacha20poly1305.h"
    "libsodium/src/libsodium/include/sodium/crypto_aead_xchacha20poly1305.h"
    "libsodium/src/libsodium/include/sodium/crypto_auth_hmacsha256.h"
    "libsodium/src/libsodium/include/sodium/crypto_auth_hmacsha512.h"
    "libsodium/src/libsodium/include/sodium/crypto_auth_hmacsha512256.h"
    "libsodium/src/libsodium/include/sodium/crypto_auth.h"
    "libsodium/src/libsodium/include/sodium/crypto_box_curve25519xchacha20poly1305.h"
    "libsodium/src/libsodium/include/sodium/crypto_box_curve25519xsalsa20poly1305.h"
    "libsodium/src/libsodium/include/sodium/crypto_box.h"
    "libsodium/src/libsodium/include/sodium/crypto_core_ed25519.h"
    "libsodium/src/libsodium/include/sodium/crypto_core_hchacha20.h"
    "libsodium/src/libsodium/include/sodium/crypto_core_hsalsa20.h"
    "libsodium/src/libsodium/include/sodium/crypto_core_keccak1600.h"
    "libsodium/src/libsodium/include/sodium/crypto_core_ristretto255.h"
    "libsodium/src/libsodium/include/sodium/crypto_core_salsa20.h"
    "libsodium/src/libsodium/include/sodium/crypto_core_salsa2012.h"
    "libsodium/src/libsodium/include/sodium/crypto_core_salsa208.h"
    "libsodium/src/libsodium/include/sodium/crypto_generichash_blake2b.h"
    "libsodium/src/libsodium/include/sodium/crypto_generichash.h"
    "libsodium/src/libsodium/include/sodium/crypto_hash_sha256.h"
    "libsodium/src/libsodium/include/sodium/crypto_hash_sha3.h"
    "libsodium/src/libsodium/include/sodium/crypto_hash_sha512.h"
    "libsodium/src/libsodium/include/sodium/crypto_hash.h"
    "libsodium/src/libsodium/include/sodium/crypto_ipcrypt.h"
    "libsodium/src/libsodium/include/sodium/crypto_kdf_blake2b.h"
    "libsodium/src/libsodium/include/sodium/crypto_kdf_hkdf_sha256.h"
    "libsodium/src/libsodium/include/sodium/crypto_kdf_hkdf_sha512.h"
    "libsodium/src/libsodium/include/sodium/crypto_kdf.h"
    "libsodium/src/libsodium/include/sodium/crypto_kem_mlkem768.h"
    "libsodium/src/libsodium/include/sodium/crypto_kem_xwing.h"
    "libsodium/src/libsodium/include/sodium/crypto_kem.h"
    "libsodium/src/libsodium/include/sodium/crypto_kx.h"
    "libsodium/src/libsodium/include/sodium/crypto_onetimeauth_poly1305.h"
    "libsodium/src/libsodium/include/sodium/crypto_onetimeauth.h"
    "libsodium/src/libsodium/include/sodium/crypto_pwhash_argon2i.h"
    "libsodium/src/libsodium/include/sodium/crypto_pwhash_argon2id.h"
    "libsodium/src/libsodium/include/sodium/crypto_pwhash_scryptsalsa208sha256.h"
    "libsodium/src/libsodium/include/sodium/crypto_pwhash.h"
    "libsodium/src/libsodium/include/sodium/crypto_scalarmult_curve25519.h"
    "libsodium/src/libsodium/include/sodium/crypto_scalarmult_ed25519.h"
    "libsodium/src/libsodium/include/sodium/crypto_scalarmult_ristretto255.h"
    "libsodium/src/libsodium/include/sodium/crypto_scalarmult.h"
    "libsodium/src/libsodium/include/sodium/crypto_secretbox_xchacha20poly1305.h"
    "libsodium/src/libsodium/include/sodium/crypto_secretbox_xsalsa20poly1305.h"
    "libsodium/src/libsodium/include/sodium/crypto_secretbox.h"
    "libsodium/src/libsodium/include/sodium/crypto_secretstream_xchacha20poly1305.h"
    "libsodium/src/libsodium/include/sodium/crypto_shorthash_siphash24.h"
    "libsodium/src/libsodium/include/sodium/crypto_shorthash.h"
    "libsodium/src/libsodium/include/sodium/crypto_sign_ed25519.h"
    "libsodium/src/libsodium/include/sodium/crypto_sign.h"
    "libsodium/src/libsodium/include/sodium/crypto_stream_chacha20.h"
    "libsodium/src/libsodium/include/sodium/crypto_stream_salsa20.h"
    "libsodium/src/libsodium/include/sodium/crypto_stream_salsa2012.h"
    "libsodium/src/libsodium/include/sodium/crypto_stream_salsa208.h"
    "libsodium/src/libsodium/include/sodium/crypto_stream_xchacha20.h"
    "libsodium/src/libsodium/include/sodium/crypto_stream_xsalsa20.h"
    "libsodium/src/libsodium/include/sodium/crypto_stream.h"
    "libsodium/src/libsodium/include/sodium/crypto_verify_16.h"
    "libsodium/src/libsodium/include/sodium/crypto_verify_32.h"
    "libsodium/src/libsodium/include/sodium/crypto_verify_64.h"
    "libsodium/src/libsodium/include/sodium/crypto_xof_shake128.h"
    "libsodium/src/libsodium/include/sodium/crypto_xof_shake256.h"
    "libsodium/src/libsodium/include/sodium/crypto_xof_turboshake128.h"
    "libsodium/src/libsodium/include/sodium/crypto_xof_turboshake256.h"
    "libsodium/src/libsodium/include/sodium/export.h"
    "libsodium/src/libsodium/include/sodium/private/asm_cet.h"
    "libsodium/src/libsodium/include/sodium/private/chacha20_ietf_ext.h"
    "libsodium/src/libsodium/include/sodium/private/common.h"
    "libsodium/src/libsodium/include/sodium/private/ed25519_ref10.h"
    "libsodium/src/libsodium/include/sodium/private/implementations.h"
    "libsodium/src/libsodium/include/sodium/private/mutex.h"
    "libsodium/src/libsodium/include/sodium/private/quirks.h"
    "libsodium/src/libsodium/include/sodium/private/softaes.h"
    "libsodium/src/libsodium/include/sodium/private/sse2_64_32.h"
    "libsodium/src/libsodium/include/sodium/randombytes_internal_random.h"
    "libsodium/src/libsodium/include/sodium/randombytes_sysrandom.h"
    "libsodium/src/libsodium/include/sodium/randombytes.h"
    "libsodium/src/libsodium/include/sodium/runtime.h"
    "libsodium/src/libsodium/include/sodium/utils.h"
)

if(NOT SODIUM_HAVE_AMD64_ASM)
    list(
        APPEND Header_Files
        "libsodium/src/libsodium/crypto_stream/salsa20/ref/salsa20_ref.h"
        "libsodium/src/libsodium/crypto_stream/salsa20/xmm6int/salsa20_xmm6int-sse2.h"
        "libsodium/src/libsodium/crypto_stream/salsa20/xmm6int/u0.h"
        "libsodium/src/libsodium/crypto_stream/salsa20/xmm6int/u1.h"
        "libsodium/src/libsodium/crypto_stream/salsa20/xmm6int/u4.h"
    )
endif()

if(NOT SODIUM_HAVE_TI_MODE)
    list(
        APPEND Header_Files
        "libsodium/src/libsodium/crypto_core/ed25519/ref10/fe_25_5/base.h"
        "libsodium/src/libsodium/crypto_core/ed25519/ref10/fe_25_5/base2.h"
        "libsodium/src/libsodium/crypto_core/ed25519/ref10/fe_25_5/constants.h"
        "libsodium/src/libsodium/crypto_core/ed25519/ref10/fe_25_5/fe.h"
        "libsodium/src/libsodium/include/sodium/private/ed25519_ref10_fe_25_5.h"
    )
endif()

if(NOT SODIUM_MINIMAL)
    list(
        APPEND Header_Files
        "libsodium/src/libsodium/crypto_pwhash/scryptsalsa208sha256/crypto_scrypt.h"
        "libsodium/src/libsodium/crypto_pwhash/scryptsalsa208sha256/pbkdf2-sha256.h"
    )
endif()

if(SODIUM_HAVE_AMD64_ASM)
    list(
        APPEND Header_Files
        "libsodium/src/libsodium/crypto_stream/salsa20/xmm6/salsa20_xmm6-asm_namespace.h"
        "libsodium/src/libsodium/crypto_stream/salsa20/xmm6/salsa20_xmm6.h"
    )
endif()

if(SODIUM_HAVE_AVX_ASM)
    list(
        APPEND Header_Files
        "libsodium/src/libsodium/crypto_scalarmult/curve25519/sandy2x/consts_namespace.h"
        "libsodium/src/libsodium/crypto_scalarmult/curve25519/sandy2x/curve25519_sandy2x.h"
        "libsodium/src/libsodium/crypto_scalarmult/curve25519/sandy2x/fe.h"
        "libsodium/src/libsodium/crypto_scalarmult/curve25519/sandy2x/fe51_namespace.h"
        "libsodium/src/libsodium/crypto_scalarmult/curve25519/sandy2x/fe51.h"
        "libsodium/src/libsodium/crypto_scalarmult/curve25519/sandy2x/ladder_namespace.h"
        "libsodium/src/libsodium/crypto_scalarmult/curve25519/sandy2x/ladder.h"
    )
endif()

if(SODIUM_HAVE_TI_MODE)
    list(
        APPEND Header_Files
        "libsodium/src/libsodium/crypto_core/ed25519/ref10/fe_51/base.h"
        "libsodium/src/libsodium/crypto_core/ed25519/ref10/fe_51/base2.h"
        "libsodium/src/libsodium/crypto_core/ed25519/ref10/fe_51/constants.h"
        "libsodium/src/libsodium/crypto_core/ed25519/ref10/fe_51/fe.h"
        "libsodium/src/libsodium/include/sodium/private/ed25519_ref10_fe_51.h"
    )
endif()

set(
    Source_Files
    "libsodium/src/libsodium/crypto_aead/aegis128l/aead_aegis128l.c"
    "libsodium/src/libsodium/crypto_aead/aegis128l/aegis128l_aesni.c"
    "libsodium/src/libsodium/crypto_aead/aegis128l/aegis128l_armcrypto.c"
    "libsodium/src/libsodium/crypto_aead/aegis128l/aegis128l_soft.c"
    "libsodium/src/libsodium/crypto_aead/aegis256/aead_aegis256.c"
    "libsodium/src/libsodium/crypto_aead/aegis256/aegis256_aesni.c"
    "libsodium/src/libsodium/crypto_aead/aegis256/aegis256_armcrypto.c"
    "libsodium/src/libsodium/crypto_aead/aegis256/aegis256_soft.c"
    "libsodium/src/libsodium/crypto_aead/aes256gcm/aead_aes256gcm.c"
    "libsodium/src/libsodium/crypto_aead/aes256gcm/aesni/aead_aes256gcm_aesni.c"
    "libsodium/src/libsodium/crypto_aead/aes256gcm/armcrypto/aead_aes256gcm_armcrypto.c"
    "libsodium/src/libsodium/crypto_aead/chacha20poly1305/aead_chacha20poly1305.c"
    "libsodium/src/libsodium/crypto_aead/xchacha20poly1305/aead_xchacha20poly1305.c"
    "libsodium/src/libsodium/crypto_auth/crypto_auth.c"
    "libsodium/src/libsodium/crypto_auth/hmacsha256/auth_hmacsha256.c"
    "libsodium/src/libsodium/crypto_auth/hmacsha512/auth_hmacsha512.c"
    "libsodium/src/libsodium/crypto_auth/hmacsha512256/auth_hmacsha512256.c"
    "libsodium/src/libsodium/crypto_box/crypto_box_easy.c"
    "libsodium/src/libsodium/crypto_box/crypto_box_seal.c"
    "libsodium/src/libsodium/crypto_box/crypto_box.c"
    "libsodium/src/libsodium/crypto_box/curve25519xsalsa20poly1305/box_curve25519xsalsa20poly1305.c"
    "libsodium/src/libsodium/crypto_core/ed25519/core_h2c.c"
    "libsodium/src/libsodium/crypto_core/ed25519/ref10/ed25519_ref10.c"
    "libsodium/src/libsodium/crypto_core/hchacha20/core_hchacha20.c"
    "libsodium/src/libsodium/crypto_core/hsalsa20/core_hsalsa20.c"
    "libsodium/src/libsodium/crypto_core/hsalsa20/ref2/core_hsalsa20_ref2.c"
    "libsodium/src/libsodium/crypto_core/keccak1600/armsha3/keccak1600_armsha3.c"
    "libsodium/src/libsodium/crypto_core/keccak1600/keccak1600.c"
    "libsodium/src/libsodium/crypto_core/keccak1600/ref/keccak1600_ref.c"
    "libsodium/src/libsodium/crypto_core/salsa/ref/core_salsa_ref.c"
    "libsodium/src/libsodium/crypto_core/softaes/softaes.c"
    "libsodium/src/libsodium/crypto_generichash/blake2b/generichash_blake2.c"
    "libsodium/src/libsodium/crypto_generichash/blake2b/ref/blake2b-compress-avx2.c"
    "libsodium/src/libsodium/crypto_generichash/blake2b/ref/blake2b-compress-ref.c"
    "libsodium/src/libsodium/crypto_generichash/blake2b/ref/blake2b-compress-sse41.c"
    "libsodium/src/libsodium/crypto_generichash/blake2b/ref/blake2b-compress-ssse3.c"
    "libsodium/src/libsodium/crypto_generichash/blake2b/ref/blake2b-ref.c"
    "libsodium/src/libsodium/crypto_generichash/blake2b/ref/generichash_blake2b.c"
    "libsodium/src/libsodium/crypto_generichash/crypto_generichash.c"
    "libsodium/src/libsodium/crypto_hash/crypto_hash.c"
    "libsodium/src/libsodium/crypto_hash/sha256/cp/hash_sha256_cp.c"
    "libsodium/src/libsodium/crypto_hash/sha256/hash_sha256.c"
    "libsodium/src/libsodium/crypto_hash/sha3/hash_sha3.c"
    "libsodium/src/libsodium/crypto_hash/sha512/cp/hash_sha512_cp.c"
    "libsodium/src/libsodium/crypto_hash/sha512/hash_sha512.c"
    "libsodium/src/libsodium/crypto_ipcrypt/crypto_ipcrypt.c"
    "libsodium/src/libsodium/crypto_ipcrypt/ipcrypt_aesni.c"
    "libsodium/src/libsodium/crypto_ipcrypt/ipcrypt_armcrypto.c"
    "libsodium/src/libsodium/crypto_ipcrypt/ipcrypt_soft.c"
    "libsodium/src/libsodium/crypto_kdf/blake2b/kdf_blake2b.c"
    "libsodium/src/libsodium/crypto_kdf/crypto_kdf.c"
    "libsodium/src/libsodium/crypto_kdf/hkdf/kdf_hkdf_sha256.c"
    "libsodium/src/libsodium/crypto_kdf/hkdf/kdf_hkdf_sha512.c"
    "libsodium/src/libsodium/crypto_kem/crypto_kem.c"
    "libsodium/src/libsodium/crypto_kem/mlkem768/kem_mlkem768.c"
    "libsodium/src/libsodium/crypto_kem/mlkem768/ref/kem_mlkem768_ref.c"
    "libsodium/src/libsodium/crypto_kem/xwing/kem_xwing.c"
    "libsodium/src/libsodium/crypto_kx/crypto_kx.c"
    "libsodium/src/libsodium/crypto_onetimeauth/crypto_onetimeauth.c"
    "libsodium/src/libsodium/crypto_onetimeauth/poly1305/donna/poly1305_donna.c"
    "libsodium/src/libsodium/crypto_onetimeauth/poly1305/onetimeauth_poly1305.c"
    "libsodium/src/libsodium/crypto_onetimeauth/poly1305/sse2/poly1305_sse2.c"
    "libsodium/src/libsodium/crypto_pwhash/argon2/argon2-core.c"
    "libsodium/src/libsodium/crypto_pwhash/argon2/argon2-encoding.c"
    "libsodium/src/libsodium/crypto_pwhash/argon2/argon2-fill-block-avx2.c"
    "libsodium/src/libsodium/crypto_pwhash/argon2/argon2-fill-block-avx512f.c"
    "libsodium/src/libsodium/crypto_pwhash/argon2/argon2-fill-block-neon.c"
    "libsodium/src/libsodium/crypto_pwhash/argon2/argon2-fill-block-ref.c"
    "libsodium/src/libsodium/crypto_pwhash/argon2/argon2-fill-block-ssse3.c"
    "libsodium/src/libsodium/crypto_pwhash/argon2/argon2-fill-block-wasm32.c"
    "libsodium/src/libsodium/crypto_pwhash/argon2/argon2.c"
    "libsodium/src/libsodium/crypto_pwhash/argon2/blake2b-long.c"
    "libsodium/src/libsodium/crypto_pwhash/argon2/pwhash_argon2i.c"
    "libsodium/src/libsodium/crypto_pwhash/argon2/pwhash_argon2id.c"
    "libsodium/src/libsodium/crypto_pwhash/crypto_pwhash.c"
    "libsodium/src/libsodium/crypto_scalarmult/crypto_scalarmult.c"
    "libsodium/src/libsodium/crypto_scalarmult/curve25519/ref10/x25519_ref10.c"
    "libsodium/src/libsodium/crypto_scalarmult/curve25519/scalarmult_curve25519.c"
    "libsodium/src/libsodium/crypto_secretbox/crypto_secretbox_easy.c"
    "libsodium/src/libsodium/crypto_secretbox/crypto_secretbox.c"
    "libsodium/src/libsodium/crypto_secretbox/xsalsa20poly1305/secretbox_xsalsa20poly1305.c"
    "libsodium/src/libsodium/crypto_secretstream/xchacha20poly1305/secretstream_xchacha20poly1305.c"
    "libsodium/src/libsodium/crypto_shorthash/crypto_shorthash.c"
    "libsodium/src/libsodium/crypto_shorthash/siphash24/ref/shorthash_siphash24_ref.c"
    "libsodium/src/libsodium/crypto_shorthash/siphash24/shorthash_siphash24.c"
    "libsodium/src/libsodium/crypto_sign/crypto_sign.c"
    "libsodium/src/libsodium/crypto_sign/ed25519/ref10/keypair.c"
    "libsodium/src/libsodium/crypto_sign/ed25519/ref10/open.c"
    "libsodium/src/libsodium/crypto_sign/ed25519/ref10/sign.c"
    "libsodium/src/libsodium/crypto_sign/ed25519/sign_ed25519.c"
    "libsodium/src/libsodium/crypto_stream/chacha20/dolbeau/chacha20_dolbeau-avx2.c"
    "libsodium/src/libsodium/crypto_stream/chacha20/dolbeau/chacha20_dolbeau-ssse3.c"
    "libsodium/src/libsodium/crypto_stream/chacha20/ref/chacha20_ref.c"
    "libsodium/src/libsodium/crypto_stream/chacha20/stream_chacha20.c"
    "libsodium/src/libsodium/crypto_stream/crypto_stream.c"
    "libsodium/src/libsodium/crypto_stream/salsa20/stream_salsa20.c"
    "libsodium/src/libsodium/crypto_stream/salsa20/xmm6int/salsa20_xmm6int-avx2.c"
    "libsodium/src/libsodium/crypto_stream/xsalsa20/stream_xsalsa20.c"
    "libsodium/src/libsodium/crypto_verify/verify.c"
    "libsodium/src/libsodium/crypto_xof/shake128/ref/shake128_ref.c"
    "libsodium/src/libsodium/crypto_xof/shake128/xof_shake128.c"
    "libsodium/src/libsodium/crypto_xof/shake256/ref/shake256_ref.c"
    "libsodium/src/libsodium/crypto_xof/shake256/xof_shake256.c"
    "libsodium/src/libsodium/crypto_xof/turboshake128/ref/turboshake128_ref.c"
    "libsodium/src/libsodium/crypto_xof/turboshake128/xof_turboshake128.c"
    "libsodium/src/libsodium/crypto_xof/turboshake256/ref/turboshake256_ref.c"
    "libsodium/src/libsodium/crypto_xof/turboshake256/xof_turboshake256.c"
    "libsodium/src/libsodium/randombytes/randombytes.c"
    "libsodium/src/libsodium/sodium/codecs.c"
    "libsodium/src/libsodium/sodium/core.c"
    "libsodium/src/libsodium/sodium/runtime.c"
    "libsodium/src/libsodium/sodium/utils.c"
    "libsodium/src/libsodium/sodium/version.c"
)

if(NOT SODIUM_EMSCRIPTEN)
    list(
        APPEND Source_Files
        "libsodium/src/libsodium/randombytes/internal/randombytes_internal_random.c"
        "libsodium/src/libsodium/randombytes/sysrandom/randombytes_sysrandom.c"
    )
endif()

if(NOT SODIUM_HAVE_AMD64_ASM)
    list(
        APPEND Source_Files
        "libsodium/src/libsodium/crypto_stream/salsa20/ref/salsa20_ref.c"
        "libsodium/src/libsodium/crypto_stream/salsa20/xmm6int/salsa20_xmm6int-sse2.c"
    )
endif()

if(NOT SODIUM_MINIMAL)
    list(
        APPEND Source_Files
        "libsodium/src/libsodium/crypto_box/curve25519xchacha20poly1305/box_curve25519xchacha20poly1305.c"
        "libsodium/src/libsodium/crypto_box/curve25519xchacha20poly1305/box_seal_curve25519xchacha20poly1305.c"
        "libsodium/src/libsodium/crypto_core/ed25519/core_ed25519.c"
        "libsodium/src/libsodium/crypto_core/ed25519/core_ristretto255.c"
        "libsodium/src/libsodium/crypto_pwhash/scryptsalsa208sha256/crypto_scrypt-common.c"
        "libsodium/src/libsodium/crypto_pwhash/scryptsalsa208sha256/nosse/pwhash_scryptsalsa208sha256_nosse.c"
        "libsodium/src/libsodium/crypto_pwhash/scryptsalsa208sha256/pbkdf2-sha256.c"
        "libsodium/src/libsodium/crypto_pwhash/scryptsalsa208sha256/pwhash_scryptsalsa208sha256.c"
        "libsodium/src/libsodium/crypto_pwhash/scryptsalsa208sha256/scrypt_platform.c"
        "libsodium/src/libsodium/crypto_pwhash/scryptsalsa208sha256/sse/pwhash_scryptsalsa208sha256_sse.c"
        "libsodium/src/libsodium/crypto_scalarmult/ed25519/ref10/scalarmult_ed25519_ref10.c"
        "libsodium/src/libsodium/crypto_scalarmult/ristretto255/ref10/scalarmult_ristretto255_ref10.c"
        "libsodium/src/libsodium/crypto_secretbox/xchacha20poly1305/secretbox_xchacha20poly1305.c"
        "libsodium/src/libsodium/crypto_shorthash/siphash24/ref/shorthash_siphashx24_ref.c"
        "libsodium/src/libsodium/crypto_shorthash/siphash24/shorthash_siphashx24.c"
        "libsodium/src/libsodium/crypto_stream/salsa2012/ref/stream_salsa2012_ref.c"
        "libsodium/src/libsodium/crypto_stream/salsa2012/stream_salsa2012.c"
        "libsodium/src/libsodium/crypto_stream/salsa208/ref/stream_salsa208_ref.c"
        "libsodium/src/libsodium/crypto_stream/salsa208/stream_salsa208.c"
        "libsodium/src/libsodium/crypto_stream/xchacha20/stream_xchacha20.c"
    )
endif()

if(SODIUM_HAVE_AMD64_ASM)
    list(
        APPEND Source_Files
        "libsodium/src/libsodium/crypto_stream/salsa20/xmm6/salsa20_xmm6-asm.S"
        "libsodium/src/libsodium/crypto_stream/salsa20/xmm6/salsa20_xmm6.c"
    )
endif()

if(SODIUM_HAVE_AVX_ASM)
    list(
        APPEND Source_Files
        "libsodium/src/libsodium/crypto_scalarmult/curve25519/sandy2x/curve25519_sandy2x.c"
        "libsodium/src/libsodium/crypto_scalarmult/curve25519/sandy2x/fe_frombytes_sandy2x.c"
        "libsodium/src/libsodium/crypto_scalarmult/curve25519/sandy2x/fe51_invert.c"
        "libsodium/src/libsodium/crypto_scalarmult/curve25519/sandy2x/sandy2x.S"
    )
endif()

set(
    Support_Files
    "libsodium/src/libsodium/crypto_scalarmult/curve25519/sandy2x/consts.S"
    "libsodium/src/libsodium/crypto_scalarmult/curve25519/sandy2x/fe51_mul.S"
    "libsodium/src/libsodium/crypto_scalarmult/curve25519/sandy2x/fe51_nsquare.S"
    "libsodium/src/libsodium/crypto_scalarmult/curve25519/sandy2x/fe51_pack.S"
    "libsodium/src/libsodium/crypto_scalarmult/curve25519/sandy2x/ladder.S"
)

set(
    Public_Header_Files
    "libsodium/src/libsodium/include/sodium.h"
    "libsodium/src/libsodium/include/sodium/core.h"
    "libsodium/src/libsodium/include/sodium/crypto_aead_aegis128l.h"
    "libsodium/src/libsodium/include/sodium/crypto_aead_aegis256.h"
    "libsodium/src/libsodium/include/sodium/crypto_aead_aes256gcm.h"
    "libsodium/src/libsodium/include/sodium/crypto_aead_chacha20poly1305.h"
    "libsodium/src/libsodium/include/sodium/crypto_aead_xchacha20poly1305.h"
    "libsodium/src/libsodium/include/sodium/crypto_auth_hmacsha256.h"
    "libsodium/src/libsodium/include/sodium/crypto_auth_hmacsha512.h"
    "libsodium/src/libsodium/include/sodium/crypto_auth_hmacsha512256.h"
    "libsodium/src/libsodium/include/sodium/crypto_auth.h"
    "libsodium/src/libsodium/include/sodium/crypto_box_curve25519xchacha20poly1305.h"
    "libsodium/src/libsodium/include/sodium/crypto_box_curve25519xsalsa20poly1305.h"
    "libsodium/src/libsodium/include/sodium/crypto_box.h"
    "libsodium/src/libsodium/include/sodium/crypto_core_ed25519.h"
    "libsodium/src/libsodium/include/sodium/crypto_core_hchacha20.h"
    "libsodium/src/libsodium/include/sodium/crypto_core_hsalsa20.h"
    "libsodium/src/libsodium/include/sodium/crypto_core_keccak1600.h"
    "libsodium/src/libsodium/include/sodium/crypto_core_ristretto255.h"
    "libsodium/src/libsodium/include/sodium/crypto_core_salsa20.h"
    "libsodium/src/libsodium/include/sodium/crypto_core_salsa2012.h"
    "libsodium/src/libsodium/include/sodium/crypto_core_salsa208.h"
    "libsodium/src/libsodium/include/sodium/crypto_generichash_blake2b.h"
    "libsodium/src/libsodium/include/sodium/crypto_generichash.h"
    "libsodium/src/libsodium/include/sodium/crypto_hash_sha256.h"
    "libsodium/src/libsodium/include/sodium/crypto_hash_sha3.h"
    "libsodium/src/libsodium/include/sodium/crypto_hash_sha512.h"
    "libsodium/src/libsodium/include/sodium/crypto_hash.h"
    "libsodium/src/libsodium/include/sodium/crypto_ipcrypt.h"
    "libsodium/src/libsodium/include/sodium/crypto_kdf_blake2b.h"
    "libsodium/src/libsodium/include/sodium/crypto_kdf_hkdf_sha256.h"
    "libsodium/src/libsodium/include/sodium/crypto_kdf_hkdf_sha512.h"
    "libsodium/src/libsodium/include/sodium/crypto_kdf.h"
    "libsodium/src/libsodium/include/sodium/crypto_kem_mlkem768.h"
    "libsodium/src/libsodium/include/sodium/crypto_kem_xwing.h"
    "libsodium/src/libsodium/include/sodium/crypto_kem.h"
    "libsodium/src/libsodium/include/sodium/crypto_kx.h"
    "libsodium/src/libsodium/include/sodium/crypto_onetimeauth_poly1305.h"
    "libsodium/src/libsodium/include/sodium/crypto_onetimeauth.h"
    "libsodium/src/libsodium/include/sodium/crypto_pwhash_argon2i.h"
    "libsodium/src/libsodium/include/sodium/crypto_pwhash_argon2id.h"
    "libsodium/src/libsodium/include/sodium/crypto_pwhash_scryptsalsa208sha256.h"
    "libsodium/src/libsodium/include/sodium/crypto_pwhash.h"
    "libsodium/src/libsodium/include/sodium/crypto_scalarmult_curve25519.h"
    "libsodium/src/libsodium/include/sodium/crypto_scalarmult_ed25519.h"
    "libsodium/src/libsodium/include/sodium/crypto_scalarmult_ristretto255.h"
    "libsodium/src/libsodium/include/sodium/crypto_scalarmult.h"
    "libsodium/src/libsodium/include/sodium/crypto_secretbox_xchacha20poly1305.h"
    "libsodium/src/libsodium/include/sodium/crypto_secretbox_xsalsa20poly1305.h"
    "libsodium/src/libsodium/include/sodium/crypto_secretbox.h"
    "libsodium/src/libsodium/include/sodium/crypto_secretstream_xchacha20poly1305.h"
    "libsodium/src/libsodium/include/sodium/crypto_shorthash_siphash24.h"
    "libsodium/src/libsodium/include/sodium/crypto_shorthash.h"
    "libsodium/src/libsodium/include/sodium/crypto_sign_ed25519.h"
    "libsodium/src/libsodium/include/sodium/crypto_sign.h"
    "libsodium/src/libsodium/include/sodium/crypto_stream_chacha20.h"
    "libsodium/src/libsodium/include/sodium/crypto_stream_salsa20.h"
    "libsodium/src/libsodium/include/sodium/crypto_stream_salsa2012.h"
    "libsodium/src/libsodium/include/sodium/crypto_stream_salsa208.h"
    "libsodium/src/libsodium/include/sodium/crypto_stream_xchacha20.h"
    "libsodium/src/libsodium/include/sodium/crypto_stream_xsalsa20.h"
    "libsodium/src/libsodium/include/sodium/crypto_stream.h"
    "libsodium/src/libsodium/include/sodium/crypto_verify_16.h"
    "libsodium/src/libsodium/include/sodium/crypto_verify_32.h"
    "libsodium/src/libsodium/include/sodium/crypto_verify_64.h"
    "libsodium/src/libsodium/include/sodium/crypto_xof_shake128.h"
    "libsodium/src/libsodium/include/sodium/crypto_xof_shake256.h"
    "libsodium/src/libsodium/include/sodium/crypto_xof_turboshake128.h"
    "libsodium/src/libsodium/include/sodium/crypto_xof_turboshake256.h"
    "libsodium/src/libsodium/include/sodium/export.h"
    "libsodium/src/libsodium/include/sodium/randombytes_internal_random.h"
    "libsodium/src/libsodium/include/sodium/randombytes_sysrandom.h"
    "libsodium/src/libsodium/include/sodium/randombytes.h"
    "libsodium/src/libsodium/include/sodium/runtime.h"
    "libsodium/src/libsodium/include/sodium/utils.h"
)

set(
    SODIUM_AESNI_SOURCES
    "libsodium/src/libsodium/crypto_aead/aegis128l/aegis128l_aesni.c"
    "libsodium/src/libsodium/crypto_aead/aegis256/aegis256_aesni.c"
    "libsodium/src/libsodium/crypto_aead/aes256gcm/aesni/aead_aes256gcm_aesni.c"
    "libsodium/src/libsodium/crypto_ipcrypt/ipcrypt_aesni.c"
)

set(
    SODIUM_ARMCRYPTO_SOURCES
    "libsodium/src/libsodium/crypto_aead/aegis128l/aegis128l_armcrypto.c"
    "libsodium/src/libsodium/crypto_aead/aegis256/aegis256_armcrypto.c"
    "libsodium/src/libsodium/crypto_aead/aes256gcm/armcrypto/aead_aes256gcm_armcrypto.c"
    "libsodium/src/libsodium/crypto_ipcrypt/ipcrypt_armcrypto.c"
    "libsodium/src/libsodium/crypto_pwhash/argon2/argon2-fill-block-neon.c"
)

set(
    SODIUM_AVX2_SOURCES
    "libsodium/src/libsodium/crypto_generichash/blake2b/ref/blake2b-compress-avx2.c"
    "libsodium/src/libsodium/crypto_pwhash/argon2/argon2-fill-block-avx2.c"
    "libsodium/src/libsodium/crypto_stream/chacha20/dolbeau/chacha20_dolbeau-avx2.c"
    "libsodium/src/libsodium/crypto_stream/salsa20/xmm6int/salsa20_xmm6int-avx2.c"
)

set(
    SODIUM_AVX512F_SOURCES
    "libsodium/src/libsodium/crypto_pwhash/argon2/argon2-fill-block-avx512f.c"
)

set(
    SODIUM_RDRAND_SOURCES
    "libsodium/src/libsodium/randombytes/internal/randombytes_internal_random.c"
)

set(
    SODIUM_SSE2_SOURCES
    "libsodium/src/libsodium/crypto_onetimeauth/poly1305/sse2/poly1305_sse2.c"
    "libsodium/src/libsodium/crypto_pwhash/scryptsalsa208sha256/sse/pwhash_scryptsalsa208sha256_sse.c"
    "libsodium/src/libsodium/crypto_stream/salsa20/xmm6int/salsa20_xmm6int-sse2.c"
)

set(
    SODIUM_SSE41_SOURCES
    "libsodium/src/libsodium/crypto_generichash/blake2b/ref/blake2b-compress-sse41.c"
)

set(
    SODIUM_SSSE3_SOURCES
    "libsodium/src/libsodium/crypto_generichash/blake2b/ref/blake2b-compress-ssse3.c"
    "libsodium/src/libsodium/crypto_pwhash/argon2/argon2-fill-block-ssse3.c"
    "libsodium/src/libsodium/crypto_stream/chacha20/dolbeau/chacha20_dolbeau-ssse3.c"
)

set(
    Generated_Header_Files
    "${CMAKE_CURRENT_BINARY_DIR}/include/sodium/version.h"
)

source_group(
    TREE "${CMAKE_CURRENT_SOURCE_DIR}/libsodium/src/libsodium"
    PREFIX "Header Files"
    FILES ${Header_Files}
)

source_group(
    TREE "${CMAKE_CURRENT_SOURCE_DIR}/libsodium/src/libsodium"
    PREFIX "Source Files"
    FILES ${Source_Files}
)

source_group(
    TREE "${CMAKE_CURRENT_SOURCE_DIR}/libsodium/src/libsodium"
    PREFIX "Support Files"
    FILES ${Support_Files}
)

source_group(
    "Generated Files"
    FILES ${Generated_Header_Files}
)

set(SODIUM_PRIVATE_HEADER_FILES ${Header_Files})
list(REMOVE_ITEM SODIUM_PRIVATE_HEADER_FILES ${Public_Header_Files})

if(SODIUM_MINIMAL)
    set(SODIUM_LIBRARY_MINIMAL_DEF "#define SODIUM_LIBRARY_MINIMAL 1")
else()
    set(SODIUM_LIBRARY_MINIMAL_DEF "")
endif()

configure_file(
    libsodium/src/libsodium/include/sodium/version.h.in
    "${CMAKE_CURRENT_BINARY_DIR}/include/sodium/version.h"
    @ONLY
)

configure_file(
    libsodium/libsodium.pc.in
    "${CMAKE_CURRENT_BINARY_DIR}/libsodium.pc"
    @ONLY
)

add_library(
    ${PROJECT_NAME}
)

add_library(
    ${PROJECT_NAME}::${PROJECT_NAME}
    ALIAS ${PROJECT_NAME}
)

target_sources(
    ${PROJECT_NAME}
    PRIVATE
        ${Source_Files}
        ${Support_Files}
    PRIVATE
        FILE_SET sodium_private_headers
        TYPE HEADERS
        BASE_DIRS
            "${CMAKE_CURRENT_SOURCE_DIR}/libsodium/src/libsodium"
        FILES
            ${SODIUM_PRIVATE_HEADER_FILES}
    PUBLIC
        FILE_SET sodium_public_headers
        TYPE HEADERS
        BASE_DIRS
            "${CMAKE_CURRENT_SOURCE_DIR}/libsodium/src/libsodium/include"
            "${CMAKE_CURRENT_BINARY_DIR}/include"
        FILES
            ${Public_Header_Files}
            ${Generated_Header_Files}
)

set_target_properties(
    ${PROJECT_NAME}
    PROPERTIES
        C_STANDARD 99
        C_STANDARD_REQUIRED ON
        C_EXTENSIONS ON
        POSITION_INDEPENDENT_CODE ${SODIUM_ENABLE_PIE}
)

if(BUILD_SHARED_LIBS AND SODIUM_ENABLE_SONAME_VERSIONS)
    set_target_properties(
        ${PROJECT_NAME}
        PROPERTIES
            VERSION "${SODIUM_LIBRARY_VERSION_MAJOR}.${SODIUM_LIBRARY_VERSION_MINOR}.0"
            SOVERSION "${SODIUM_LIBRARY_VERSION_MAJOR}"
    )
endif()

function(sodium_set_source_options source_list_name)
    foreach(source_file IN LISTS ${source_list_name})
        set_property(
            SOURCE "${source_file}"
            APPEND
            PROPERTY COMPILE_OPTIONS ${ARGN}
        )
    endforeach()
endfunction()

sodium_set_source_options(SODIUM_RDRAND_SOURCES ${SODIUM_CFLAGS_RDRAND})
sodium_set_source_options(SODIUM_ARMCRYPTO_SOURCES ${SODIUM_CFLAGS_ARMCRYPTO})
sodium_set_source_options(SODIUM_AESNI_SOURCES ${SODIUM_CFLAGS_SSE2} ${SODIUM_CFLAGS_SSSE3} ${SODIUM_CFLAGS_AVX} ${SODIUM_CFLAGS_AESNI} ${SODIUM_CFLAGS_PCLMUL})
sodium_set_source_options(SODIUM_SSE2_SOURCES ${SODIUM_CFLAGS_SSE2})
sodium_set_source_options(SODIUM_SSSE3_SOURCES ${SODIUM_CFLAGS_SSE2} ${SODIUM_CFLAGS_SSSE3})
sodium_set_source_options(SODIUM_SSE41_SOURCES ${SODIUM_CFLAGS_SSE2} ${SODIUM_CFLAGS_SSSE3} ${SODIUM_CFLAGS_SSE41})
sodium_set_source_options(SODIUM_AVX2_SOURCES ${SODIUM_CFLAGS_SSE2} ${SODIUM_CFLAGS_SSSE3} ${SODIUM_CFLAGS_SSE41} ${SODIUM_CFLAGS_AVX} ${SODIUM_CFLAGS_AVX2})
sodium_set_source_options(SODIUM_AVX512F_SOURCES ${SODIUM_CFLAGS_SSE2} ${SODIUM_CFLAGS_SSSE3} ${SODIUM_CFLAGS_SSE41} ${SODIUM_CFLAGS_AVX} ${SODIUM_CFLAGS_AVX2} ${SODIUM_CFLAGS_AVX512F})

target_include_directories(
    ${PROJECT_NAME}
    PUBLIC
        $<BUILD_INTERFACE:${CMAKE_CURRENT_BINARY_DIR}/include>
        $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/libsodium/src/libsodium/include>
        $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/libsodium/src/libsodium/include/sodium>
        $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>
    PRIVATE
        $<BUILD_INTERFACE:${CMAKE_CURRENT_BINARY_DIR}/include/sodium>
        $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/libsodium/src/libsodium/include/sodium>
)

set(SODIUM_PRIVATE_DEFINITIONS CONFIGURED=1)
if(SODIUM_NATIVE_BIG_ENDIAN)
    list(APPEND SODIUM_PRIVATE_DEFINITIONS NATIVE_BIG_ENDIAN=1)
else()
    list(APPEND SODIUM_PRIVATE_DEFINITIONS NATIVE_LITTLE_ENDIAN=1)
endif()

if(SODIUM_HAVE_ASM_HIDDEN)
    list(APPEND SODIUM_PRIVATE_DEFINITIONS "ASM_HIDE_SYMBOL=.hidden")
endif()

sodium_add_definition_if(SODIUM_PRIVATE_DEFINITIONS SODIUM_HAVE_SYS_MMAN_H HAVE_SYS_MMAN_H)
sodium_add_definition_if(SODIUM_PRIVATE_DEFINITIONS SODIUM_HAVE_SYS_PARAM_H HAVE_SYS_PARAM_H)
sodium_add_definition_if(SODIUM_PRIVATE_DEFINITIONS SODIUM_HAVE_SYS_RANDOM_H HAVE_SYS_RANDOM_H)
sodium_add_definition_if(SODIUM_PRIVATE_DEFINITIONS SODIUM_HAVE_INTRIN_H HAVE_INTRIN_H)
sodium_add_definition_if(SODIUM_PRIVATE_DEFINITIONS SODIUM_HAVE_SYS_AUXV_H HAVE_SYS_AUXV_H)
sodium_add_definition_if(SODIUM_PRIVATE_DEFINITIONS SODIUM_HAVE_COMMONCRYPTO_COMMONRANDOM_H HAVE_COMMONCRYPTO_COMMONRANDOM_H)
sodium_add_definition_if(SODIUM_PRIVATE_DEFINITIONS SODIUM_HAVE_CET_H HAVE_CET_H)
sodium_add_definition_if(SODIUM_PRIVATE_DEFINITIONS SODIUM_HAVE_THREADS_H HAVE_THREADS_H)
sodium_add_definition_if(SODIUM_PRIVATE_DEFINITIONS SODIUM_HAVE_ALLOCA_H HAVE_ALLOCA_H)
sodium_add_definition_if(SODIUM_PRIVATE_DEFINITIONS SODIUM_HAVE_C_VARARRAYS HAVE_C_VARARRAYS)
sodium_add_definition_if(SODIUM_PRIVATE_DEFINITIONS SODIUM_HAVE_ALLOCA HAVE_ALLOCA)
sodium_add_definition_if(SODIUM_PRIVATE_DEFINITIONS SODIUM_HAVE_ARC4RANDOM HAVE_ARC4RANDOM)
sodium_add_definition_if(SODIUM_PRIVATE_DEFINITIONS SODIUM_HAVE_ARC4RANDOM_BUF HAVE_ARC4RANDOM_BUF)
sodium_add_definition_if(SODIUM_PRIVATE_DEFINITIONS SODIUM_HAVE_MMAP HAVE_MMAP)
sodium_add_definition_if(SODIUM_PRIVATE_DEFINITIONS SODIUM_HAVE_MLOCK HAVE_MLOCK)
sodium_add_definition_if(SODIUM_PRIVATE_DEFINITIONS SODIUM_HAVE_MADVISE HAVE_MADVISE)
sodium_add_definition_if(SODIUM_PRIVATE_DEFINITIONS SODIUM_HAVE_MPROTECT HAVE_MPROTECT)
sodium_add_definition_if(SODIUM_PRIVATE_DEFINITIONS SODIUM_HAVE_RAISE HAVE_RAISE)
sodium_add_definition_if(SODIUM_PRIVATE_DEFINITIONS SODIUM_HAVE_SYSCONF HAVE_SYSCONF)
sodium_add_definition_if(SODIUM_PRIVATE_DEFINITIONS SODIUM_HAVE_GETPID HAVE_GETPID)
sodium_add_definition_if(SODIUM_PRIVATE_DEFINITIONS SODIUM_HAVE_GETAUXVAL HAVE_GETAUXVAL)
sodium_add_definition_if(SODIUM_PRIVATE_DEFINITIONS SODIUM_HAVE_ELF_AUX_INFO HAVE_ELF_AUX_INFO)
sodium_add_definition_if(SODIUM_PRIVATE_DEFINITIONS SODIUM_HAVE_POSIX_MEMALIGN HAVE_POSIX_MEMALIGN)
sodium_add_definition_if(SODIUM_PRIVATE_DEFINITIONS SODIUM_HAVE_NANOSLEEP HAVE_NANOSLEEP)
sodium_add_definition_if(SODIUM_PRIVATE_DEFINITIONS SODIUM_HAVE_CLOCK_GETTIME HAVE_CLOCK_GETTIME)
sodium_add_definition_if(SODIUM_PRIVATE_DEFINITIONS SODIUM_HAVE_MEMSET_S HAVE_MEMSET_S)
sodium_add_definition_if(SODIUM_PRIVATE_DEFINITIONS SODIUM_HAVE_EXPLICIT_BZERO HAVE_EXPLICIT_BZERO)
sodium_add_definition_if(SODIUM_PRIVATE_DEFINITIONS SODIUM_HAVE_MEMSET_EXPLICIT HAVE_MEMSET_EXPLICIT)
sodium_add_definition_if(SODIUM_PRIVATE_DEFINITIONS SODIUM_HAVE_EXPLICIT_MEMSET HAVE_EXPLICIT_MEMSET)
sodium_add_definition_if(SODIUM_PRIVATE_DEFINITIONS SODIUM_HAVE_GETRANDOM HAVE_GETRANDOM)
sodium_add_definition_if(SODIUM_PRIVATE_DEFINITIONS SODIUM_HAVE_GETENTROPY HAVE_GETENTROPY)
sodium_add_definition_if(SODIUM_PRIVATE_DEFINITIONS SODIUM_HAVE_INLINE_ASM HAVE_INLINE_ASM)
sodium_add_definition_if(SODIUM_PRIVATE_DEFINITIONS SODIUM_HAVE_TI_MODE HAVE_TI_MODE)
sodium_add_definition_if(SODIUM_PRIVATE_DEFINITIONS SODIUM_HAVE_AMD64_ASM HAVE_AMD64_ASM)
sodium_add_definition_if(SODIUM_PRIVATE_DEFINITIONS SODIUM_HAVE_AVX_ASM HAVE_AVX_ASM)
sodium_add_definition_if(SODIUM_PRIVATE_DEFINITIONS SODIUM_HAVE_CPUID HAVE_CPUID)
sodium_add_definition_if(SODIUM_PRIVATE_DEFINITIONS SODIUM_HAVE_WEAK_SYMBOLS HAVE_WEAK_SYMBOLS)
sodium_add_definition_if(SODIUM_PRIVATE_DEFINITIONS SODIUM_HAVE_ATOMIC_OPS HAVE_ATOMIC_OPS)
sodium_add_definition_if(SODIUM_PRIVATE_DEFINITIONS SODIUM_HAVE_C11_MEMORY_FENCES HAVE_C11_MEMORY_FENCES)
sodium_add_definition_if(SODIUM_PRIVATE_DEFINITIONS SODIUM_HAVE_GCC_MEMORY_FENCES HAVE_GCC_MEMORY_FENCES)
sodium_add_definition_if(SODIUM_PRIVATE_DEFINITIONS SODIUM_HAVE__XGETBV HAVE__XGETBV)
sodium_add_definition_if(SODIUM_PRIVATE_DEFINITIONS SODIUM_HAVE_ARMCRYPTO HAVE_ARMCRYPTO)
sodium_add_definition_if(SODIUM_PRIVATE_DEFINITIONS SODIUM_HAVE_MMINTRIN_H HAVE_MMINTRIN_H)
sodium_add_definition_if(SODIUM_PRIVATE_DEFINITIONS SODIUM_HAVE_EMMINTRIN_H HAVE_EMMINTRIN_H)
sodium_add_definition_if(SODIUM_PRIVATE_DEFINITIONS SODIUM_HAVE_PMMINTRIN_H HAVE_PMMINTRIN_H)
sodium_add_definition_if(SODIUM_PRIVATE_DEFINITIONS SODIUM_HAVE_TMMINTRIN_H HAVE_TMMINTRIN_H)
sodium_add_definition_if(SODIUM_PRIVATE_DEFINITIONS SODIUM_HAVE_SMMINTRIN_H HAVE_SMMINTRIN_H)
sodium_add_definition_if(SODIUM_PRIVATE_DEFINITIONS SODIUM_HAVE_AVXINTRIN_H HAVE_AVXINTRIN_H)
sodium_add_definition_if(SODIUM_PRIVATE_DEFINITIONS SODIUM_HAVE_AVX2INTRIN_H HAVE_AVX2INTRIN_H)
sodium_add_definition_if(SODIUM_PRIVATE_DEFINITIONS SODIUM_HAVE_AVX512FINTRIN_H HAVE_AVX512FINTRIN_H)
sodium_add_definition_if(SODIUM_PRIVATE_DEFINITIONS SODIUM_HAVE_WMMINTRIN_H HAVE_WMMINTRIN_H)
sodium_add_definition_if(SODIUM_PRIVATE_DEFINITIONS SODIUM_HAVE_RDRAND HAVE_RDRAND)
sodium_add_definition_if(SODIUM_PRIVATE_DEFINITIONS SODIUM_HAVE_PTHREAD HAVE_PTHREAD)
sodium_add_definition_if(SODIUM_PRIVATE_DEFINITIONS SODIUM_HAVE_LIBCTGRIND HAVE_LIBCTGRIND)

target_compile_definitions(
    ${PROJECT_NAME}
    PUBLIC
        $<$<NOT:$<BOOL:${BUILD_SHARED_LIBS}>>:SODIUM_STATIC>
        $<$<BOOL:${SODIUM_MINIMAL}>:SODIUM_LIBRARY_MINIMAL>
    PRIVATE
        ${SODIUM_PRIVATE_DEFINITIONS}
        $<$<BOOL:${BUILD_SHARED_LIBS}>:SODIUM_DLL_EXPORT>
        $<$<BOOL:${SODIUM_ENABLE_BLOCKING_RANDOM}>:USE_BLOCKING_RANDOM>
        $<$<BOOL:${SODIUM_MINIMAL}>:MINIMAL>
        $<$<C_COMPILER_FRONTEND_VARIANT:MSVC>:_CRT_SECURE_NO_WARNINGS>
        $<$<NOT:$<C_COMPILER_FRONTEND_VARIANT:MSVC>>:_GNU_SOURCE=1>
        $<$<BOOL:${SODIUM_ENABLE_DEBUG}>:DEBUG=1>
)

target_compile_options(
    ${PROJECT_NAME}
    PRIVATE
        ${SODIUM_COMMON_COMPILE_OPTIONS}
        ${SODIUM_CWFLAGS_LIST}
)

target_link_options(
    ${PROJECT_NAME}
    PRIVATE
        ${SODIUM_COMMON_LINK_OPTIONS}
)

if(SODIUM_HAVE_PTHREAD)
    target_link_libraries(
        ${PROJECT_NAME}
        PRIVATE Threads::Threads
    )
endif()

if(SODIUM_WITH_CTGRIND AND SODIUM_HAVE_LIBCTGRIND)
    target_link_libraries(
        ${PROJECT_NAME}
        PRIVATE ctgrind
    )
endif()

if(SODIUM_WITH_SAFECODE)
    target_link_directories(
        ${PROJECT_NAME}
        PRIVATE "${SODIUM_SAFECODE_HOME}/lib"
    )
    target_link_libraries(
        ${PROJECT_NAME}
        PRIVATE sc_dbg_rt poolalloc_bitmap stdc++
    )
endif()

if(CMAKE_C_COMPILER_ID STREQUAL "Clang" AND CMAKE_C_COMPILER_FRONTEND_VARIANT STREQUAL "MSVC")
    target_compile_options(
        ${PROJECT_NAME}
        PRIVATE
            -mavx2
            -maes
            -mpclmul
            -mssse3
    )
endif()

install(
    TARGETS ${PROJECT_NAME}
    EXPORT ${PROJECT_NAME}Config
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
    FILE_SET sodium_public_headers DESTINATION "${CMAKE_INSTALL_INCLUDEDIR}"
)

install(
    FILES "${CMAKE_CURRENT_BINARY_DIR}/libsodium.pc"
    DESTINATION "${CMAKE_INSTALL_LIBDIR}/pkgconfig"
)

if(SODIUM_OUTPUT_DEF_FILE)
    install(
        FILES "${SODIUM_OUTPUT_DEF_FILE}"
        DESTINATION "${CMAKE_INSTALL_BINDIR}"
    )
endif()

install(
    EXPORT ${PROJECT_NAME}Config
    NAMESPACE ${PROJECT_NAME}::
    DESTINATION "${CMAKE_INSTALL_LIBDIR}/cmake/${PROJECT_NAME}"
)
