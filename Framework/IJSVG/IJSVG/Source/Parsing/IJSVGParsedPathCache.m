//
//  IJSVGParsedPathCache.m
//  IJSVG
//
//  Created by Curtis Hard on 11/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import "IJSVGParsedPathCache.h"
#import "IJSVGByteCache.h"
#import <objc/runtime.h>

static const NSUInteger IJSVGParsedPathCostLimit = 12 * 1024 * 1024;

// One immutable bundle per source preserves separate geometry kinds while
// sharing the source key and the 3072 source budget.
@interface IJSVGParsedPathSnapshot : NSObject {
@public
    CGPathRef paths[IJSVGParsedPathKindCount];
    NSUInteger cost;
}
@end

@implementation IJSVGParsedPathSnapshot
- (void)dealloc
{
    for (NSUInteger kind = 0; kind < IJSVGParsedPathKindCount; kind++) {
        CGPathRelease(paths[kind]);
    }
}
@end

struct IJSVGParsedPathCache {
    IJSVGByteCache* storage;
};

IJSVGParsedPathCache* IJSVGParsedPathCacheCreate(void)
{
    IJSVGParsedPathCache* cache = calloc(1, sizeof(*cache));
    if (cache != NULL) {
        cache->storage = IJSVGByteCacheCreate(3072, IJSVGParsedPathCostLimit);
        if (cache->storage == NULL) {
            free(cache);
            return NULL;
        }
    }
    return cache;
}

void IJSVGParsedPathCacheDestroy(IJSVGParsedPathCache* cache)
{
    if (cache != NULL) {
        IJSVGByteCacheDestroy(cache->storage);
        free(cache);
    }
}

CGPathRef IJSVGParsedPathCacheCopyBytes(IJSVGParsedPathCache* cache, const char* bytes, NSUInteger length, IJSVGParsedPathKind kind)
{
    if (cache == NULL || bytes == NULL || (NSUInteger)kind >= IJSVGParsedPathKindCount || length > IJSVGParsedPathCostLimit / 2) {
        return NULL;
    }
    IJSVGParsedPathSnapshot* __unsafe_unretained snapshot = (__bridge IJSVGParsedPathSnapshot*)IJSVGByteCacheGetValue(cache->storage, bytes, length);
    return snapshot == nil ? NULL : CGPathRetain(snapshot->paths[kind]);
}

void IJSVGParsedPathCacheStoreBytes(IJSVGParsedPathCache* cache, const char* bytes, NSUInteger length, IJSVGParsedPathKind kind, CGPathRef path)
{
    if (cache == NULL || bytes == NULL || path == NULL || (NSUInteger)kind >= IJSVGParsedPathKindCount || length > IJSVGParsedPathCostLimit / 2) {
        return;
    }
    IJSVGParsedPathSnapshot* __unsafe_unretained previous = (__bridge IJSVGParsedPathSnapshot*)IJSVGByteCacheGetValue(cache->storage, bytes, length);
    if (previous != nil && previous->paths[kind] != NULL) {
        return;
    }
    IJSVGParsedPathSnapshot* snapshot = [[IJSVGParsedPathSnapshot alloc] init];
    snapshot->paths[kind] = CGPathCreateCopy(path);
    if (snapshot->paths[kind] == NULL) {
        return;
    }
    snapshot->cost = length * 2 + (previous != nil ? previous->cost : class_getInstanceSize(IJSVGParsedPathSnapshot.class));
    if (previous != nil) {
        for (NSUInteger index = 0; index < IJSVGParsedPathKindCount; index++) {
            if (index != (NSUInteger)kind) {
                snapshot->paths[index] = CGPathRetain(previous->paths[index]);
            }
        }
    }
    IJSVGByteCacheSetValueWithCost(cache->storage, bytes, length, (__bridge CFTypeRef)snapshot, snapshot->cost);
}

CGPathRef IJSVGParsedPathCacheCopy(IJSVGParsedPathCache* storage, NSString* source, IJSVGParsedPathKind kind)
{
    return IJSVGParsedPathCacheCopyBytes(storage, source.UTF8String, [source lengthOfBytesUsingEncoding:NSUTF8StringEncoding], kind);
}

void IJSVGParsedPathCacheStore(IJSVGParsedPathCache* storage, NSString* source, IJSVGParsedPathKind kind, CGPathRef path)
{
    IJSVGParsedPathCacheStoreBytes(storage, source.UTF8String, [source lengthOfBytesUsingEncoding:NSUTF8StringEncoding], kind, path);
}
