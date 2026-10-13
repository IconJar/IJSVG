//
//  IJSVGParsedPathCache.m
//  IJSVG
//
//  Created by Curtis Hard on 11/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVGParsedPathCache.h>

typedef struct IJSVGParsedPathEntry {
    CFStringRef source;
    CGPathRef paths[IJSVGParsedPathKindCount];
    NSUInteger cost;
    struct IJSVGParsedPathEntry* next;
} IJSVGParsedPathEntry;

struct IJSVGParsedPathCache {
    CFMutableDictionaryRef entries;
    IJSVGParsedPathEntry* oldest;
    IJSVGParsedPathEntry* newest;
    NSUInteger count;
    NSUInteger cost;
};

static const NSUInteger IJSVGParsedPathCountLimit = 3072;
static const NSUInteger IJSVGParsedPathCostLimit = 12 * 1024 * 1024;

IJSVGParsedPathCache* IJSVGParsedPathCacheCreate(void)
{
    IJSVGParsedPathCache* storage = calloc(1, sizeof(IJSVGParsedPathCache));
    if (storage == NULL) {
        return NULL;
    }
    CFDictionaryKeyCallBacks keys = kCFTypeDictionaryKeyCallBacks;
    // Entries own their immutable keys and paths.
    keys.retain = NULL;
    keys.release = NULL;
    storage->entries = CFDictionaryCreateMutable(NULL, 0, &keys, NULL);
    if (storage->entries == NULL) {
        free(storage);
        return NULL;
    }
    return storage;
}

static void IJSVGParsedPathEvictOldest(IJSVGParsedPathCache* storage)
{
    IJSVGParsedPathEntry* entry = storage->oldest;
    storage->oldest = entry->next;
    if (storage->oldest == NULL) {
        storage->newest = NULL;
    }
    CFDictionaryRemoveValue(storage->entries, entry->source);
    storage->count--;
    storage->cost -= entry->cost;
    CFRelease(entry->source);
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
    CFRelease(storage->entries);
    free(storage);
}

static IJSVGParsedPathEntry* IJSVGParsedPathEntryCreate(IJSVGParsedPathCache* storage, CFStringRef source)
{
    IJSVGParsedPathEntry* entry = calloc(1, sizeof(IJSVGParsedPathEntry));
    if (entry == NULL) {
        return NULL;
    }
    entry->source = CFStringCreateCopy(NULL, source);
    if (entry->source == NULL) {
        free(entry);
        return NULL;
    }
    entry->cost = sizeof(IJSVGParsedPathEntry);
    if (storage->newest != NULL) {
        storage->newest->next = entry;
    } else {
        storage->oldest = entry;
    }
    storage->newest = entry;
    storage->count++;
    storage->cost += entry->cost;
    CFDictionarySetValue(storage->entries, entry->source, entry);
    return entry;
}

CGPathRef IJSVGParsedPathCacheCopy(IJSVGParsedPathCache* storage, NSString* source, IJSVGParsedPathKind kind)
{
    if (storage == NULL || source == nil || kind >= IJSVGParsedPathKindCount) {
        return NULL;
    }
    const IJSVGParsedPathEntry* entry = CFDictionaryGetValue(storage->entries, (__bridge CFStringRef)source);
    CGPathRef path = entry != NULL ? CGPathRetain(entry->paths[kind]) : NULL;
    return path;
}

void IJSVGParsedPathCacheStore(IJSVGParsedPathCache* storage, NSString* source, IJSVGParsedPathKind kind, CGPathRef path)
{
    if (storage == NULL || kind >= IJSVGParsedPathKindCount) {
        return;
    }
    CFStringRef key = (__bridge CFStringRef)source;
    NSUInteger length = CFStringGetLength(key);
    if (length > IJSVGParsedPathCostLimit / sizeof(unichar)) {
        return;
    }
    NSUInteger cost = length * sizeof(unichar);
    CGPathRef snapshot = CGPathCreateCopy(path);
    if (snapshot == NULL) {
        return;
    }
    IJSVGParsedPathEntry* entry = (IJSVGParsedPathEntry*)CFDictionaryGetValue(storage->entries, key);
    if (entry == NULL) {
        entry = IJSVGParsedPathEntryCreate(storage, key);
    }
    if (entry != NULL && entry->paths[kind] == NULL) {
        entry->paths[kind] = snapshot;
        snapshot = NULL;
        entry->cost += cost;
        storage->cost += cost;
    }
    // Eviction limits entry count and estimated source storage.
    while (storage->oldest != NULL && (storage->count > IJSVGParsedPathCountLimit || storage->cost > IJSVGParsedPathCostLimit)) {
        IJSVGParsedPathEvictOldest(storage);
    }
    CGPathRelease(snapshot);
}
