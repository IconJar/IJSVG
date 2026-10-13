//
//  IJSVGParsedPathCache.m
//  IJSVG
//
//  Created by Curtis Hard on 11/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

// Per parser byte keyed cache. Sources and immutable paths are owned here.
// neither XML buffer lifetime nor mutable graph paths affect cached entries.
#import "IJSVGParsedPathCache.h"
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#define IJSVGPathBucketCount 4096
static const NSUInteger IJSVGParsedPathCountLimit = 3072;
static const NSUInteger IJSVGParsedPathCostLimit = 12 * 1024 * 1024;

typedef struct IJSVGParsedPathEntry {
    struct IJSVGParsedPathEntry* next;
    struct IJSVGParsedPathEntry* bucketNext;
    CGPathRef paths[IJSVGParsedPathKindCount];
    uint64_t hash;
    NSUInteger length;
    NSUInteger cost;
    char source[];
} IJSVGParsedPathEntry;

struct IJSVGParsedPathCache {
    IJSVGParsedPathEntry* buckets[IJSVGPathBucketCount];
    IJSVGParsedPathEntry* oldest;
    IJSVGParsedPathEntry* newest;
    NSUInteger count;
    NSUInteger cost;
};

static uint64_t IJSVGPathHash(const char* bytes, NSUInteger length)
{
    uint64_t hash = UINT64_C(14695981039346656037);
    for (NSUInteger i = 0; i < length; i++) {
        hash = (hash ^ (unsigned char)bytes[i]) * UINT64_C(1099511628211);
    }
    return hash;
}

IJSVGParsedPathCache* IJSVGParsedPathCacheCreate(void)
{
    return calloc(1, sizeof(IJSVGParsedPathCache));
}

static void IJSVGParsedPathEvictOldest(IJSVGParsedPathCache* storage)
{
    IJSVGParsedPathEntry* entry = storage->oldest;
    storage->oldest = entry->next;
    if (storage->oldest == NULL) {
        storage->newest = NULL;
    }
    IJSVGParsedPathEntry** slot = &storage->buckets[entry->hash & (IJSVGPathBucketCount - 1)];
    while (*slot != entry) {
        slot = &(*slot)->bucketNext;
    }
    *slot = entry->bucketNext;
    storage->count--;
    storage->cost -= entry->cost;
    for (NSUInteger kind = 0; kind < IJSVGParsedPathKindCount; kind++) {
        CGPathRelease(entry->paths[kind]);
    }
    free(entry);
}

void IJSVGParsedPathCacheDestroy(IJSVGParsedPathCache* storage)
{
    if (storage == NULL) {
        return;
    }
    while (storage->oldest != NULL) {
        IJSVGParsedPathEvictOldest(storage);
    }
    free(storage);
}

static IJSVGParsedPathEntry* IJSVGPathFind(IJSVGParsedPathCache* storage, const char* bytes, NSUInteger length, uint64_t hash)
{
    for (IJSVGParsedPathEntry* entry = storage->buckets[hash & (IJSVGPathBucketCount - 1)]; entry != NULL; entry = entry->bucketNext) {
        if (entry->hash == hash && entry->length == length && memcmp(entry->source, bytes, length) == 0) {
            return entry;
        }
    }
    return NULL;
}

CGPathRef IJSVGParsedPathCacheCopyBytes(IJSVGParsedPathCache* storage, const char* bytes, NSUInteger length, IJSVGParsedPathKind kind)
{
    if (storage == NULL || bytes == NULL || kind >= IJSVGParsedPathKindCount || length > IJSVGParsedPathCostLimit / 2) {
        return NULL;
    }
    IJSVGParsedPathEntry* entry = IJSVGPathFind(storage, bytes, length, IJSVGPathHash(bytes, length));
    return entry == NULL ? NULL : CGPathRetain(entry->paths[kind]);
}

void IJSVGParsedPathCacheStoreBytes(IJSVGParsedPathCache* storage, const char* bytes, NSUInteger length, IJSVGParsedPathKind kind, CGPathRef path)
{
    if (storage == NULL || bytes == NULL || path == NULL || kind >= IJSVGParsedPathKindCount || length > IJSVGParsedPathCostLimit / 2) {
        return;
    }
    uint64_t hash = IJSVGPathHash(bytes, length);
    IJSVGParsedPathEntry* entry = IJSVGPathFind(storage, bytes, length, hash);
    if (entry != NULL && entry->paths[kind] != NULL) {
        return;
    }
    CGPathRef snapshot = CGPathCreateCopy(path);
    if (snapshot == NULL) {
        return;
    }
    if (entry == NULL) {
        entry = calloc(1, sizeof(*entry) + length);
        if (entry == NULL) {
            CGPathRelease(snapshot);
            return;
        }
        entry->hash = hash;
        entry->length = length;
        memcpy(entry->source, bytes, length);
        entry->cost = sizeof(*entry) + length;
        NSUInteger bucket = hash & (IJSVGPathBucketCount - 1);
        entry->bucketNext = storage->buckets[bucket];
        storage->buckets[bucket] = entry;
        if (storage->newest != NULL) {
            storage->newest->next = entry;
        } else {
            storage->oldest = entry;
        }
        storage->newest = entry;
        storage->count++;
        storage->cost += entry->cost;
    }
    entry->paths[kind] = snapshot;

    // Retain a conservative per path estimate as well as owned source bytes.
    entry->cost += length * 2;
    storage->cost += length * 2;
    while (storage->oldest != NULL && (storage->count > IJSVGParsedPathCountLimit || storage->cost > IJSVGParsedPathCostLimit)) {
        IJSVGParsedPathEvictOldest(storage);
    }
}

CGPathRef IJSVGParsedPathCacheCopy(IJSVGParsedPathCache* storage, NSString* source, IJSVGParsedPathKind kind)
{
    return IJSVGParsedPathCacheCopyBytes(storage, source.UTF8String, [source lengthOfBytesUsingEncoding:NSUTF8StringEncoding], kind);
}

void IJSVGParsedPathCacheStore(IJSVGParsedPathCache* storage, NSString* source, IJSVGParsedPathKind kind, CGPathRef path)
{
    IJSVGParsedPathCacheStoreBytes(storage, source.UTF8String, [source lengthOfBytesUsingEncoding:NSUTF8StringEncoding], kind, path);
}
