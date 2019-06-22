//
//  IJSVGCache.m
//  IconJar
//
//  Created by Curtis Hard on 02/09/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import "IJSVGCache.h"
#import <malloc/malloc.h>

@implementation IJSVGCache

static NSInteger _maxCacheItems = 20;
static NSCache * _cache = nil;
static BOOL _enabled = YES;

+ (void)load
{
    [self setEnabled:_enabled];
}

+ (void)setEvictItemsAfter:(NSInteger)count
{
    _maxCacheItems = count;
    [_cache setTotalCostLimit:_maxCacheItems];
}

+ (IJSVG *)cachedSVGForFileURL:(NSURL *)aURL
{
    if( ![self.class enabled] || _cache == nil )
        return nil;
    IJSVG * svg = nil;
    if( ( svg = [_cache objectForKey:aURL] ) == nil )
        return nil;
    return svg;
}

+ (void)purgeCachedSVGForFileURL:(NSURL *)aURL
{
    [_cache removeObjectForKey:aURL];
}

+ (void)cacheSVG:(IJSVG *)svg
         fileURL:(NSURL *)aURL
{
    [_cache setObject:svg
               forKey:aURL
                 cost:1];
}

+ (void)setEnabled:(BOOL)flag
{
    _enabled = flag;
    if( !flag ) {
        [self.class flushCache];
        return;
    }
    
    // create a new cache if allowed
    if( _cache == nil ) {
        _cache = [[NSCache alloc] init];
        [_cache setTotalCostLimit:_maxCacheItems];
    }
}

+ (BOOL)enabled
{
    return _enabled;
}

+ (void)flushCache
{
    [_cache removeAllObjects];
}

@end
