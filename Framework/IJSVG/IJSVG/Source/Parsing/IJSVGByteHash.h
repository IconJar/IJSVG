//
//  IJSVGByteHash.h
//  IJSVG
//

#ifndef IJSVGByteHash_h
#define IJSVGByteHash_h

#include <stddef.h>
#include <stdint.h>
#include <string.h>

// XXH64 with a zero seed, implemented from the algorithm specification:
// https://github.com/Cyan4973/xxHash/blob/dev/doc/xxhash_spec.md
// Internal, noncryptographic keys only. Always compare full keys on a hit.
// memcpy permits unaligned input and each read stays inside the supplied slice.
static inline uint64_t IJSVGHashRotate(uint64_t value, unsigned int bits)
{
    return (value << bits) | (value >> (64 - bits));
}

static inline uint64_t IJSVGHashRead64(const unsigned char* bytes)
{
    uint64_t value;
    memcpy(&value, bytes, sizeof(value));
#if __BYTE_ORDER__ == __ORDER_BIG_ENDIAN__
    value = __builtin_bswap64(value);
#endif
    return value;
}

static inline uint32_t IJSVGHashRead32(const unsigned char* bytes)
{
    uint32_t value;
    memcpy(&value, bytes, sizeof(value));
#if __BYTE_ORDER__ == __ORDER_BIG_ENDIAN__
    value = __builtin_bswap32(value);
#endif
    return value;
}

static inline uint64_t IJSVGHashRound(uint64_t state, uint64_t word)
{
    return IJSVGHashRotate(state + word * UINT64_C(0xC2B2AE3D27D4EB4F), 31) * UINT64_C(0x9E3779B185EBCA87);
}

static inline uint64_t IJSVGHashBytes(const void* data, size_t length)
{
    const uint64_t prime1 = UINT64_C(0x9E3779B185EBCA87);
    const uint64_t prime2 = UINT64_C(0xC2B2AE3D27D4EB4F);
    const uint64_t prime3 = UINT64_C(0x165667B19E3779F9);
    const uint64_t prime4 = UINT64_C(0x85EBCA77C2B2AE63);
    const uint64_t prime5 = UINT64_C(0x27D4EB2F165667C5);
    const unsigned char* bytes = data;
    size_t remaining = length;
    uint64_t hash = prime5;
    if (remaining >= 32) {
        uint64_t lanes[] = { prime1 + prime2, prime2, 0, 0 - prime1 };
        do {
            for (size_t index = 0; index < 4; index++) {
                lanes[index] = IJSVGHashRound(lanes[index], IJSVGHashRead64(bytes + index * 8));
            }
            bytes += 32;
            remaining -= 32;
        } while (remaining >= 32);
        hash = IJSVGHashRotate(lanes[0], 1) + IJSVGHashRotate(lanes[1], 7)
            + IJSVGHashRotate(lanes[2], 12) + IJSVGHashRotate(lanes[3], 18);
        for (size_t index = 0; index < 4; index++) {
            hash = (hash ^ IJSVGHashRound(0, lanes[index])) * prime1 + prime4;
        }
    }
    hash += length;
    while (remaining >= 8) {
        hash = IJSVGHashRotate(hash ^ IJSVGHashRound(0, IJSVGHashRead64(bytes)), 27) * prime1 + prime4;
        bytes += 8;
        remaining -= 8;
    }
    if (remaining >= 4) {
        hash = IJSVGHashRotate(hash ^ (uint64_t)IJSVGHashRead32(bytes) * prime1, 23) * prime2 + prime3;
        bytes += 4;
        remaining -= 4;
    }
    while (remaining != 0) {
        hash = IJSVGHashRotate(hash ^ (uint64_t)*bytes++ * prime5, 11) * prime1;
        remaining--;
    }
    hash = (hash ^ (hash >> 33)) * prime2;
    hash = (hash ^ (hash >> 29)) * prime3;
    return hash ^ (hash >> 32);
}

#endif
