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

option(SODIUM_MINIMAL "Only compile the minimum set of functions required for the high-level API" OFF)
option(SODIUM_ENABLE_BLOCKING_RANDOM "Enable this switch only if /dev/urandom is totally broken on the target platform" OFF)
option(SODIUM_ENABLE_SSP "Compile with stack protector flags when supported" ON)
option(SODIUM_ENABLE_ASM "Compile assembly code and assembly-backed implementations when supported" ON)
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

include("${CMAKE_CURRENT_LIST_DIR}/CMake/SodiumConfigure.cmake")

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

set(
    SODIUM_PRIVATE_DEFINITION_CONDITIONS
    SODIUM_HAVE_SYS_MMAN_H
    SODIUM_HAVE_SYS_PARAM_H
    SODIUM_HAVE_SYS_RANDOM_H
    SODIUM_HAVE_INTRIN_H
    SODIUM_HAVE_SYS_AUXV_H
    SODIUM_HAVE_COMMONCRYPTO_COMMONRANDOM_H
    SODIUM_HAVE_CET_H
    SODIUM_HAVE_THREADS_H
    SODIUM_HAVE_ALLOCA_H
    SODIUM_HAVE_C_VARARRAYS
    SODIUM_HAVE_ALLOCA
    SODIUM_HAVE_ARC4RANDOM
    SODIUM_HAVE_ARC4RANDOM_BUF
    SODIUM_HAVE_MMAP
    SODIUM_HAVE_MLOCK
    SODIUM_HAVE_MADVISE
    SODIUM_HAVE_MPROTECT
    SODIUM_HAVE_RAISE
    SODIUM_HAVE_SYSCONF
    SODIUM_HAVE_GETPID
    SODIUM_HAVE_GETAUXVAL
    SODIUM_HAVE_ELF_AUX_INFO
    SODIUM_HAVE_POSIX_MEMALIGN
    SODIUM_HAVE_NANOSLEEP
    SODIUM_HAVE_CLOCK_GETTIME
    SODIUM_HAVE_MEMSET_S
    SODIUM_HAVE_EXPLICIT_BZERO
    SODIUM_HAVE_MEMSET_EXPLICIT
    SODIUM_HAVE_EXPLICIT_MEMSET
    SODIUM_HAVE_GETRANDOM
    SODIUM_HAVE_GETENTROPY
    SODIUM_HAVE_INLINE_ASM
    SODIUM_HAVE_TI_MODE
    SODIUM_HAVE_AMD64_ASM
    SODIUM_HAVE_AVX_ASM
    SODIUM_HAVE_CPUID
    SODIUM_HAVE_WEAK_SYMBOLS
    SODIUM_HAVE_ATOMIC_OPS
    SODIUM_HAVE_C11_MEMORY_FENCES
    SODIUM_HAVE_GCC_MEMORY_FENCES
    SODIUM_HAVE__XGETBV
    SODIUM_HAVE_ARMCRYPTO
    SODIUM_HAVE_MMINTRIN_H
    SODIUM_HAVE_EMMINTRIN_H
    SODIUM_HAVE_PMMINTRIN_H
    SODIUM_HAVE_TMMINTRIN_H
    SODIUM_HAVE_SMMINTRIN_H
    SODIUM_HAVE_AVXINTRIN_H
    SODIUM_HAVE_AVX2INTRIN_H
    SODIUM_HAVE_AVX512FINTRIN_H
    SODIUM_HAVE_WMMINTRIN_H
    SODIUM_HAVE_RDRAND
    SODIUM_HAVE_PTHREAD
    SODIUM_HAVE_LIBCTGRIND
)

set(
    SODIUM_PRIVATE_DEFINITION_NAMES
    HAVE_SYS_MMAN_H
    HAVE_SYS_PARAM_H
    HAVE_SYS_RANDOM_H
    HAVE_INTRIN_H
    HAVE_SYS_AUXV_H
    HAVE_COMMONCRYPTO_COMMONRANDOM_H
    HAVE_CET_H
    HAVE_THREADS_H
    HAVE_ALLOCA_H
    HAVE_C_VARARRAYS
    HAVE_ALLOCA
    HAVE_ARC4RANDOM
    HAVE_ARC4RANDOM_BUF
    HAVE_MMAP
    HAVE_MLOCK
    HAVE_MADVISE
    HAVE_MPROTECT
    HAVE_RAISE
    HAVE_SYSCONF
    HAVE_GETPID
    HAVE_GETAUXVAL
    HAVE_ELF_AUX_INFO
    HAVE_POSIX_MEMALIGN
    HAVE_NANOSLEEP
    HAVE_CLOCK_GETTIME
    HAVE_MEMSET_S
    HAVE_EXPLICIT_BZERO
    HAVE_MEMSET_EXPLICIT
    HAVE_EXPLICIT_MEMSET
    HAVE_GETRANDOM
    HAVE_GETENTROPY
    HAVE_INLINE_ASM
    HAVE_TI_MODE
    HAVE_AMD64_ASM
    HAVE_AVX_ASM
    HAVE_CPUID
    HAVE_WEAK_SYMBOLS
    HAVE_ATOMIC_OPS
    HAVE_C11_MEMORY_FENCES
    HAVE_GCC_MEMORY_FENCES
    HAVE__XGETBV
    HAVE_ARMCRYPTO
    HAVE_MMINTRIN_H
    HAVE_EMMINTRIN_H
    HAVE_PMMINTRIN_H
    HAVE_TMMINTRIN_H
    HAVE_SMMINTRIN_H
    HAVE_AVXINTRIN_H
    HAVE_AVX2INTRIN_H
    HAVE_AVX512FINTRIN_H
    HAVE_WMMINTRIN_H
    HAVE_RDRAND
    HAVE_PTHREAD
    HAVE_LIBCTGRIND
)

list(LENGTH SODIUM_PRIVATE_DEFINITION_CONDITIONS sodium_private_definition_conditions_length)
list(LENGTH SODIUM_PRIVATE_DEFINITION_NAMES sodium_private_definition_names_length)
if(NOT sodium_private_definition_conditions_length EQUAL sodium_private_definition_names_length)
    message(FATAL_ERROR "SODIUM_PRIVATE_DEFINITION_CONDITIONS and SODIUM_PRIVATE_DEFINITION_NAMES must have the same length")
endif()

foreach(condition_variable definition IN ZIP_LISTS SODIUM_PRIVATE_DEFINITION_CONDITIONS SODIUM_PRIVATE_DEFINITION_NAMES)
    sodium_add_definition_if(SODIUM_PRIVATE_DEFINITIONS "${condition_variable}" "${definition}")
endforeach()

if(SODIUM_TLS)
    list(APPEND SODIUM_PRIVATE_DEFINITIONS "TLS=${SODIUM_TLS}")
endif()

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
