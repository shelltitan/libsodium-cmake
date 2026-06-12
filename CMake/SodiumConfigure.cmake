# Configure-time probes and compatibility flags for libsodium.
# This file is included from the top-level CMakeLists.txt and runs in that directory scope.

include(CheckCCompilerFlag)
include(CheckCSourceCompiles)
include(CheckFunctionExists)
include(CheckIncludeFile)
include(CheckLibraryExists)
include(CheckLinkerFlag)
include(CheckSymbolExists)
include(CMakePushCheckState)
include(TestBigEndian)

if(CMAKE_SYSTEM_NAME STREQUAL "Emscripten" OR CMAKE_C_COMPILER MATCHES "emcc")
    set(SODIUM_EMSCRIPTEN ON)
else()
    set(SODIUM_EMSCRIPTEN OFF)
endif()

check_c_source_compiles([[
#ifndef __wasi__
# error __wasi__ is not defined
#endif
int main(void) { return 0; }
]] SODIUM_WASI)

check_c_source_compiles([[
#ifndef __COMPCERT__
# error __COMPCERT__ is not defined
#endif
int main(void) { return 0; }
]] SODIUM_COMPCERT)

set(SODIUM_EFFECTIVE_ENABLE_ASM ${SODIUM_ENABLE_ASM})
if(SODIUM_EMSCRIPTEN)
    set(SODIUM_EFFECTIVE_ENABLE_ASM OFF)
    message(STATUS "Emscripten target detected; asm implementations disabled")
endif()
if(SODIUM_COMPCERT)
    set(SODIUM_EFFECTIVE_ENABLE_ASM OFF)
    message(WARNING "Compiling with CompCert; asm implementations disabled")
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

function(sodium_append_supported_compile_option_with_context output_variable option)
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

function(sodium_append_fortify_source output_variable)
    if(NOT CMAKE_SYSTEM_NAME STREQUAL "Linux")
        return()
    endif()

    check_c_compiler_flag("-Werror" SODIUM_SUPPORTS_WERROR)
    set(sodium_fortify_required_flags "")
    foreach(sodium_common_compile_option IN LISTS ${output_variable})
        string(APPEND sodium_fortify_required_flags " ${sodium_common_compile_option}")
    endforeach()
    if(SODIUM_SUPPORTS_WERROR)
        string(APPEND sodium_fortify_required_flags " -Werror")
    endif()

    # Match AX_ADD_FORTIFY_SOURCE: prefer level 3, fall back to 2, and do not redefine toolchain-provided fortify.
    foreach(sodium_fortify_source_level IN ITEMS 3 2)
        if(NOT sodium_fortify_source)
            set(sodium_fortify_undefined_variable "SODIUM_FORTIFY_SOURCE_${sodium_fortify_source_level}_UNDEFINED")
            set(sodium_fortify_works_variable "SODIUM_FORTIFY_SOURCE_${sodium_fortify_source_level}_WORKS")
            cmake_push_check_state(RESET)
            set(CMAKE_REQUIRED_FLAGS "${sodium_fortify_required_flags}")
            check_c_source_compiles("
int main(void) {
#ifndef _FORTIFY_SOURCE
    return 0;
#else
    _FORTIFY_SOURCE_already_defined;
#endif
}
" ${sodium_fortify_undefined_variable})
            if(${sodium_fortify_undefined_variable})
                check_c_source_compiles("
#define _FORTIFY_SOURCE ${sodium_fortify_source_level}
#include <string.h>
int main(void) {
    char *s = \" \";
    strcpy(s, \"x\");
    return (int) strlen(s) - 1;
}
" ${sodium_fortify_works_variable})
            endif()
            cmake_pop_check_state()
            if(${sodium_fortify_works_variable})
                set(sodium_fortify_source "${sodium_fortify_source_level}")
            endif()
        endif()
    endforeach()

    if(sodium_fortify_source)
        set(${output_variable} "${${output_variable}};-D_FORTIFY_SOURCE=${sodium_fortify_source}" PARENT_SCOPE)
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

function(sodium_check_thread_local_storage output_variable)
    set(sodium_tls_result "")
    foreach(sodium_tls_keyword IN ITEMS
        "thread_local"
        "_Thread_local"
        "__thread"
        "__declspec(thread)"
    )
        if(NOT sodium_tls_result)
            string(MAKE_C_IDENTIFIER "${sodium_tls_keyword}" sodium_tls_keyword_id)
            set(sodium_tls_variable "SODIUM_SUPPORTS_TLS_${sodium_tls_keyword_id}")
            check_c_source_compiles("
#include <stdlib.h>
int main(void) {
    static ${sodium_tls_keyword} int bar;
    return bar;
}
" ${sodium_tls_variable})
            if(${sodium_tls_variable})
                set(sodium_tls_result "${sodium_tls_keyword}")
            endif()
        endif()
    endforeach()
    set(${output_variable} "${sodium_tls_result}" PARENT_SCOPE)
endfunction()

set(SODIUM_COMMON_COMPILE_OPTIONS "")
set(SODIUM_COMMON_LINK_OPTIONS "")
set(SODIUM_CWFLAGS_LIST "")
set(SODIUM_OUTPUT_DEF_FILE "")
set(SODIUM_TLS "")

if(SODIUM_COMPCERT)
    sodium_append_supported_compile_option(SODIUM_COMMON_COMPILE_OPTIONS "-fstruct-passing")
endif()

set(SODIUM_GNU_WINDOWS_TARGET OFF)
if(WIN32 OR CYGWIN OR MSYS OR CMAKE_SYSTEM_NAME MATCHES "^(CYGWIN|MSYS|Windows.*)$")
    set(SODIUM_GNU_WINDOWS_TARGET ON)
endif()

set(SODIUM_GNU_WINDOWS_OR_EMBEDDED_ABI_TARGET "${SODIUM_GNU_WINDOWS_TARGET}")
string(TOLOWER "${CMAKE_SYSTEM_NAME};${CMAKE_C_COMPILER_TARGET};${CMAKE_C_COMPILER}" sodium_target_descriptor)
if(sodium_target_descriptor MATCHES "(^|[^a-z0-9])(pw32|cegcc|eabi)([^a-z0-9]|$)")
    set(SODIUM_GNU_WINDOWS_OR_EMBEDDED_ABI_TARGET ON)
endif()

if(NOT "${CMAKE_C_COMPILER_FRONTEND_VARIANT}" STREQUAL "MSVC")
    foreach(sodium_common_flag IN ITEMS
        "-fvisibility=hidden"
        "-fno-strict-aliasing"
        "-fno-strict-overflow"
    )
        sodium_append_supported_compile_option(SODIUM_COMMON_COMPILE_OPTIONS "${sodium_common_flag}")
    endforeach()
    if(NOT SODIUM_COMMON_COMPILE_OPTIONS MATCHES "(^|;)-fno-strict-overflow($|;)")
        sodium_append_supported_compile_option(SODIUM_COMMON_COMPILE_OPTIONS "-fwrapv")
    endif()

    # Upstream keeps this workaround only for pre-4.3 GCC on x86-family targets.
    string(TOLOWER "${CMAKE_SYSTEM_PROCESSOR}" SODIUM_SYSTEM_PROCESSOR)
    if(CMAKE_C_COMPILER_ID STREQUAL "GNU"
        AND CMAKE_C_COMPILER_VERSION VERSION_LESS 4.3
        AND SODIUM_SYSTEM_PROCESSOR MATCHES "^(i.86|x86_64|amd64)$")
        sodium_append_supported_compile_option(SODIUM_COMMON_COMPILE_OPTIONS "-flax-vector-conversions")
    endif()

    foreach(sodium_common_flag IN ITEMS
        "-Wno-deprecated-declarations"
        "-Wno-unknown-pragmas"
    )
        sodium_append_supported_compile_option(SODIUM_COMMON_COMPILE_OPTIONS "${sodium_common_flag}")
    endforeach()

    if(SODIUM_ENABLE_SSP)
        sodium_append_supported_compile_option(SODIUM_COMMON_COMPILE_OPTIONS "-fstack-protector")
    endif()

    if(SODIUM_ENABLE_RETPOLINE)
        sodium_append_supported_compile_option(SODIUM_COMMON_COMPILE_OPTIONS "-mindirect-branch=thunk-inline")
        if(NOT SODIUM_COMMON_COMPILE_OPTIONS MATCHES "(^|;)-mindirect-branch=thunk-inline($|;)")
            sodium_append_supported_compile_option(SODIUM_COMMON_COMPILE_OPTIONS "-mretpoline")
        endif()
        sodium_append_supported_compile_option(SODIUM_COMMON_COMPILE_OPTIONS "-mindirect-branch-register")
    endif()

    if(SODIUM_ENABLE_OPT)
        foreach(sodium_opt_flag IN ITEMS
            "-ftree-vectorize"
            "-ftree-slp-vectorize"
            "-fomit-frame-pointer"
            "-march=native"
            "-mtune=native"
        )
            sodium_append_supported_compile_option(SODIUM_COMMON_COMPILE_OPTIONS "${sodium_opt_flag}")
        endforeach()
    endif()

    if(SODIUM_GNU_WINDOWS_OR_EMBEDDED_ABI_TARGET)
        sodium_append_supported_compile_option(SODIUM_COMMON_COMPILE_OPTIONS "-fno-asynchronous-unwind-tables")
    endif()

    if(NOT SODIUM_EMSCRIPTEN)
        foreach(sodium_hardening_link_flag IN ITEMS
            "-Wl,-z,relro"
            "-Wl,-z,now"
            "-Wl,-z,noexecstack"
        )
            sodium_append_supported_link_option(SODIUM_COMMON_LINK_OPTIONS "${sodium_hardening_link_flag}")
        endforeach()
    endif()
endif()

if(SODIUM_GNU_WINDOWS_TARGET AND NOT "${CMAKE_C_COMPILER_LINKER_FRONTEND_VARIANT}" STREQUAL "MSVC")
    foreach(sodium_windows_link_flag IN ITEMS
        "-Wl,--dynamicbase"
        "-Wl,--high-entropy-va"
        "-Wl,--nxcompat"
    )
        sodium_append_supported_link_option(SODIUM_COMMON_LINK_OPTIONS "${sodium_windows_link_flag}")
    endforeach()
endif()

# Upstream installs this generated import definition file when GNU-like Windows linkers support it.
if(BUILD_SHARED_LIBS AND SODIUM_GNU_WINDOWS_TARGET AND NOT "${CMAKE_C_COMPILER_LINKER_FRONTEND_VARIANT}" STREQUAL "MSVC")
    check_linker_flag(C "-Wl,--output-def,conftest.def" SODIUM_SUPPORTS_LINK_OUTPUT_DEF)
    if(SODIUM_SUPPORTS_LINK_OUTPUT_DEF)
        set(SODIUM_OUTPUT_DEF_FILE "${CMAKE_CURRENT_BINARY_DIR}/${PROJECT_NAME}-${DLL_VERSION}.def")
        list(APPEND SODIUM_COMMON_LINK_OPTIONS "-Wl,--output-def,${SODIUM_OUTPUT_DEF_FILE}")
    endif()
endif()

if(SODIUM_ENABLE_DEBUG)
    if(NOT "${CMAKE_C_COMPILER_FRONTEND_VARIANT}" STREQUAL "MSVC")
        foreach(sodium_debug_flag IN ITEMS
            "-O"
            "-g3"
            "-U_FORTIFY_SOURCE"
        )
            sodium_append_supported_compile_option(SODIUM_COMMON_COMPILE_OPTIONS "${sodium_debug_flag}")
        endforeach()
    endif()
    separate_arguments(SODIUM_CWFLAGS_LIST NATIVE_COMMAND "${SODIUM_CWFLAGS}")
    if(NOT "${CMAKE_C_COMPILER_FRONTEND_VARIANT}" STREQUAL "MSVC")
        # Upstream builds this CWFLAGS list only for maintainer/debug configurations.
        sodium_append_supported_compile_option_with_context(SODIUM_CWFLAGS_LIST "-Wall")
        if(CMAKE_C_COMPILER_ID MATCHES "Clang")
            sodium_append_supported_compile_option_with_context(SODIUM_CWFLAGS_LIST "-Wno-unknown-warning-option")
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
            sodium_append_supported_compile_option_with_context(SODIUM_CWFLAGS_LIST "${sodium_cwflag}")
        endforeach()
    endif()
endif()

sodium_append_fortify_source(SODIUM_COMMON_COMPILE_OPTIONS)

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
#include <limits.h>
#include <stdint.h>
int main(void) {
    (void) SIZE_MAX;
    (void) UINT64_MAX;
    return 0;
}
]] SODIUM_STDC_LIMIT_MACROS_NOT_REQUIRED)

if(NOT SODIUM_STDC_LIMIT_MACROS_NOT_REQUIRED)
    list(APPEND SODIUM_COMMON_COMPILE_OPTIONS "-D__STDC_LIMIT_MACROS" "-D__STDC_CONSTANT_MACROS")
endif()

check_c_source_compiles([[
int main(void) {
    int n = 1;
    char vla[n];
    return (int) sizeof vla - 1;
}
]] SODIUM_HAVE_C_VARARRAYS)

check_symbol_exists(alloca "alloca.h;stdlib.h" SODIUM_HAVE_ALLOCA)
if(NOT SODIUM_EMSCRIPTEN)
    check_function_exists(arc4random SODIUM_HAVE_ARC4RANDOM)
    check_function_exists(arc4random_buf SODIUM_HAVE_ARC4RANDOM_BUF)
    if(NOT SODIUM_WASI)
        check_function_exists(mmap SODIUM_HAVE_MMAP)
        check_function_exists(mlock SODIUM_HAVE_MLOCK)
        check_function_exists(madvise SODIUM_HAVE_MADVISE)
        check_function_exists(mprotect SODIUM_HAVE_MPROTECT)
        check_function_exists(raise SODIUM_HAVE_RAISE)
        check_function_exists(sysconf SODIUM_HAVE_SYSCONF)
    endif()
    check_symbol_exists(getrandom "stdlib.h;unistd.h;sys/random.h" SODIUM_HAVE_GETRANDOM)
    check_symbol_exists(getentropy "stdlib.h;unistd.h;sys/random.h" SODIUM_HAVE_GETENTROPY)
endif()

if(NOT SODIUM_WASI)
    check_function_exists(getpid SODIUM_HAVE_GETPID)
    check_function_exists(getauxval SODIUM_HAVE_GETAUXVAL)
    check_function_exists(elf_aux_info SODIUM_HAVE_ELF_AUX_INFO)
endif()

check_function_exists(posix_memalign SODIUM_HAVE_POSIX_MEMALIGN)
check_function_exists(nanosleep SODIUM_HAVE_NANOSLEEP)
check_function_exists(clock_gettime SODIUM_HAVE_CLOCK_GETTIME)

if(NOT SODIUM_WASI)
    check_function_exists(memset_s SODIUM_HAVE_MEMSET_S)
    check_function_exists(explicit_bzero SODIUM_HAVE_EXPLICIT_BZERO)
    check_function_exists(memset_explicit SODIUM_HAVE_MEMSET_EXPLICIT)
    check_function_exists(explicit_memset SODIUM_HAVE_EXPLICIT_MEMSET)
endif()

if(WIN32)
    set(SODIUM_HAVE_GETPID OFF)
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
    cmake_push_check_state(RESET)
    set(CMAKE_REQUIRED_DEFINITIONS "-DNATIVE_LITTLE_ENDIAN=1")
    check_c_source_compiles([[
#if !defined(__clang__) && !defined(__GNUC__) && !defined(__SIZEOF_INT128__)
# error mode(TI) is a gcc extension, and __int128 is not available
#endif
#if defined(__clang__) && !defined(__x86_64__) && !defined(__aarch64__)
# error clang does not properly handle the 128-bit type on 32-bit systems
#endif
#ifndef NATIVE_LITTLE_ENDIAN
# error libsodium currently expects a little endian CPU for the 128-bit type
#endif
#ifdef __EMSCRIPTEN__
# error emscripten currently doesn't support some operations on integers larger than 64 bits
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
    cmake_pop_check_state()
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
    __asm__ __volatile__ (".private_extern dummy_symbol \n"
                          ".private_extern _dummy_symbol \n"
                          ".globl dummy_symbol \n"
                          ".globl _dummy_symbol \n"
                          "dummy_symbol: \n"
                          "_dummy_symbol: \n"
                          "    nop \n");
    return 0;
}
]] SODIUM_HAVE_ASM_PRIVATE_EXTERN)

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

    if(SODIUM_HAVE_ASM_PRIVATE_EXTERN AND SODIUM_HAVE_ASM_HIDDEN)
        message(STATUS "Unable to reliably tag asm symbols as private")
        set(SODIUM_ASM_HIDE_SYMBOL "")
    elseif(SODIUM_HAVE_ASM_PRIVATE_EXTERN)
        set(SODIUM_ASM_HIDE_SYMBOL ".private_extern")
    elseif(SODIUM_HAVE_ASM_HIDDEN)
        set(SODIUM_ASM_HIDE_SYMBOL ".hidden")
    else()
        set(SODIUM_ASM_HIDE_SYMBOL "")
    endif()
else()
    set(SODIUM_HAVE_AMD64_ASM OFF)
    set(SODIUM_HAVE_AVX_ASM OFF)
    set(SODIUM_HAVE_CPUID OFF)
    set(SODIUM_HAVE_ASM_PRIVATE_EXTERN OFF)
    set(SODIUM_HAVE_ASM_HIDDEN OFF)
    set(SODIUM_ASM_HIDE_SYMBOL "")
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
#ifdef __clang__
# pragma clang attribute push(__attribute__((target("neon,crypto,aes"))), apply_to = function)
#elif defined(__GNUC__)
# pragma GCC target("+simd+crypto")
#endif
int main(void) {
    int64x2_t x = { 0, 0 };
    vaeseq_u8(vmovq_n_u8(0), vmovq_n_u8(0));
    vmull_high_p64(vreinterpretq_p64_s64(x), vreinterpretq_p64_s64(x));
    return 0;
}
#ifdef __clang__
# pragma clang attribute pop
#endif
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
#ifdef __clang__
# pragma clang attribute push(__attribute__((target("neon,crypto,aes"))), apply_to = function)
#elif defined(__GNUC__)
# pragma GCC target("+simd+crypto")
#endif
int main(void) {
    int64x2_t x = { 0, 0 };
    vaeseq_u8(vmovq_n_u8(0), vmovq_n_u8(0));
    vmull_high_p64(vreinterpretq_p64_s64(x), vreinterpretq_p64_s64(x));
    return 0;
}
#ifdef __clang__
# pragma clang attribute pop
#endif
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
        sodium_check_thread_local_storage(SODIUM_TLS)
        if(SODIUM_TLS)
            message(STATUS "Thread local storage is supported: ${SODIUM_TLS}")
            sodium_append_supported_compile_option(SODIUM_COMMON_COMPILE_OPTIONS "-ftls-model=global-dynamic")
        else()
            message(STATUS "Thread local storage is not supported")
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
