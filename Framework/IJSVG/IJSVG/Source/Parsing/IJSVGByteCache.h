//
//  IJSVGByteCache.h
//  IJSVG
//

#ifndef IJSVGByteCache_h
#define IJSVGByteCache_h

#include <CoreFoundation/CoreFoundation.h>
#include <stddef.h>

typedef struct IJSVGByteCache IJSVGByteCache;

// Thread confined storage. Keys are copied on insertion. Lookups allocate
// nothing. Values are retained. Callers provide immutable snapshots and include
// dependencies in their keys. byteLimit bounds entry/key storage plus the
// caller supplied value cost. Bucket storage is separate.
IJSVGByteCache* IJSVGByteCacheCreate(size_t countLimit, size_t byteLimit);
void IJSVGByteCacheDestroy(IJSVGByteCache* cache);
size_t IJSVGByteCacheGetCount(const IJSVGByteCache* cache);

// Borrowed value, valid until replacement, eviction or cache destruction.
CFTypeRef IJSVGByteCacheGetValue(const IJSVGByteCache* cache, const void* bytes, size_t length);
void IJSVGByteCacheSetValue(IJSVGByteCache* cache, const void* bytes, size_t length, CFTypeRef value);

// Includes an estimated value cost in the byte budget. Oversized entries are ignored.
void IJSVGByteCacheSetValueWithCost(IJSVGByteCache* cache, const void* bytes, size_t length, CFTypeRef value, size_t valueCost);

#endif
