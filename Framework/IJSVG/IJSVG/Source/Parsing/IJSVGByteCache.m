//
//  IJSVGByteCache.m
//  IJSVG
//
//  Created by Curtis Hard on 15/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#include <IJSVGByteCache.h>
#include <IJSVGByteHash.h>
#include <stdlib.h>
#include <string.h>

typedef struct IJSVGByteCacheEntry {
    struct IJSVGByteCacheEntry* next;
    struct IJSVGByteCacheEntry* previous;
    struct IJSVGByteCacheEntry* bucketNext;
    CFTypeRef value;
    uint64_t hash;
    size_t length;
    size_t cost;
    unsigned char bytes[];
} IJSVGByteCacheEntry;

struct IJSVGByteCache {
    IJSVGByteCacheEntry** buckets;
    size_t bucketCount;
    IJSVGByteCacheEntry* oldest;
    IJSVGByteCacheEntry* newest;
    size_t count;
    size_t countLimit;
    size_t byteLimit;
    size_t cost;
};

IJSVGByteCache* IJSVGByteCacheCreate(size_t countLimit, size_t byteLimit)
{
    IJSVGByteCache* cache = calloc(1, sizeof(*cache));
    if (cache != NULL) {
        size_t buckets = 1024;
        while (buckets < countLimit && buckets < 65536) {
            buckets *= 2;
        }
        cache->buckets = calloc(buckets, sizeof(*cache->buckets));
        if (cache->buckets == NULL) {
            free(cache);
            return NULL;
        }
        cache->bucketCount = buckets;
        cache->countLimit = countLimit;
        cache->byteLimit = byteLimit;
    }
    return cache;
}

size_t IJSVGByteCacheGetCount(const IJSVGByteCache* cache)
{
    return cache != NULL ? cache->count : 0;
}

static bool IJSVGByteCacheAccepts(const IJSVGByteCache* cache, const void* bytes, size_t length)
{
    return cache != NULL && cache->countLimit != 0 && cache->byteLimit >= sizeof(IJSVGByteCacheEntry)
        && length <= cache->byteLimit - sizeof(IJSVGByteCacheEntry)
        && (bytes != NULL || length == 0);
}

static IJSVGByteCacheEntry* IJSVGByteCacheFind(const IJSVGByteCache* cache, const void* bytes, size_t length, uint64_t hash)
{
    for (IJSVGByteCacheEntry* entry = cache->buckets[hash & (cache->bucketCount - 1)]; entry != NULL; entry = entry->bucketNext) {
        if (entry->hash == hash && entry->length == length && (length == 0 || memcmp(entry->bytes, bytes, length) == 0)) {
            return entry;
        }
    }
    return NULL;
}

CFTypeRef IJSVGByteCacheGetValue(const IJSVGByteCache* cache, const void* bytes, size_t length)
{
    if (!IJSVGByteCacheAccepts(cache, bytes, length)) {
        return NULL;
    }
    IJSVGByteCacheEntry* entry = IJSVGByteCacheFind(cache, bytes, length, IJSVGHashBytes(bytes, length));
    return entry != NULL ? entry->value : NULL;
}

static void IJSVGByteCacheRemove(IJSVGByteCache* cache, IJSVGByteCacheEntry* entry)
{
    if (entry->previous != NULL) {
        entry->previous->next = entry->next;
    } else {
        cache->oldest = entry->next;
    }
    if (entry->next != NULL) {
        entry->next->previous = entry->previous;
    } else {
        cache->newest = entry->previous;
    }
    IJSVGByteCacheEntry** slot = &cache->buckets[entry->hash & (cache->bucketCount - 1)];
    while (*slot != entry) {
        slot = &(*slot)->bucketNext;
    }
    *slot = entry->bucketNext;
    cache->cost -= entry->cost;
    cache->count--;
    CFRelease(entry->value);
    free(entry);
}

void IJSVGByteCacheSetValue(IJSVGByteCache* cache, const void* bytes, size_t length, CFTypeRef value)
{
    IJSVGByteCacheSetValueWithCost(cache, bytes, length, value, 0);
}

void IJSVGByteCacheSetValueWithCost(IJSVGByteCache* cache, const void* bytes, size_t length, CFTypeRef value, size_t valueCost)
{
    if (value == NULL || !IJSVGByteCacheAccepts(cache, bytes, length)) {
        return;
    }
    size_t allocation = sizeof(IJSVGByteCacheEntry) + length;
    if (valueCost > cache->byteLimit - allocation) {
        return;
    }
    size_t cost = allocation + valueCost;
    uint64_t hash = IJSVGHashBytes(bytes, length);
    IJSVGByteCacheEntry* entry = IJSVGByteCacheFind(cache, bytes, length, hash);
    if (entry != NULL) {
        CFTypeRef replacement = CFRetain(value);
        cache->cost -= entry->cost;
        while (cache->cost > cache->byteLimit - cost) {
            IJSVGByteCacheRemove(cache, cache->oldest == entry ? entry->next : cache->oldest);
        }
        cache->cost += cost;
        entry->cost = cost;
        CFRelease(entry->value);
        entry->value = replacement;
        return;
    }
    entry = calloc(1, allocation);
    if (entry == NULL) {
        return;
    }
    entry->value = CFRetain(value);
    entry->hash = hash;
    entry->length = length;
    entry->cost = cost;
    if (length != 0) {
        memcpy(entry->bytes, bytes, length);
    }
    while (cache->oldest != NULL && (cache->count >= cache->countLimit || cache->cost > cache->byteLimit - cost)) {
        IJSVGByteCacheRemove(cache, cache->oldest);
    }
    size_t bucket = hash & (cache->bucketCount - 1);
    entry->bucketNext = cache->buckets[bucket];
    cache->buckets[bucket] = entry;
    entry->previous = cache->newest;
    if (cache->newest != NULL) {
        cache->newest->next = entry;
    } else {
        cache->oldest = entry;
    }
    cache->newest = entry;
    cache->cost += cost;
    cache->count++;
}

void IJSVGByteCacheDestroy(IJSVGByteCache* cache)
{
    if (cache == NULL) {
        return;
    }
    while (cache->oldest != NULL) {
        IJSVGByteCacheRemove(cache, cache->oldest);
    }
    free(cache->buckets);
    free(cache);
}
