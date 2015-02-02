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

// 5MB
#define MAX_CACHE_SIZE 5000000

static NSCache * _cache = nil;
static BOOL _enabled = YES;

+ (void)load
{
    [self setEnabled:_enabled];
}

+ (IJSVG *)cachedSVGForFileURL:(NSURL *)aURL
{
    if( ![[self class] enabled] || _cache == nil )
        return nil;
    IJSVG * svg = nil;
    if( ( svg = [_cache objectForKey:aURL] ) == nil )
        return nil;
    return svg;
}

+ (void)cacheSVG:(IJSVG *)svg
         fileURL:(NSURL *)aURL
{
    // use the malloc size for the object size,
    // actually bad idea, use the file size
    // is this correct?
    struct stat st;
    long cost = 0;
    if( lstat( [[aURL path] cStringUsingEncoding:NSUTF8StringEncoding], &st ) != -1 )
        cost = st.st_size;
    
    [_cache setObject:svg
               forKey:aURL
                 cost:cost];
}

+ (void)setEnabled:(BOOL)flag
{
    _enabled = flag;
    if( !flag )
    {
        [[self class] flushCache];
        if( _cache != nil )
            [_cache release], _cache = nil;
        return;
    }
    
    // create a new cache if allowed
    if( _cache == nil )
    {
        _cache = [[NSCache alloc] init];
        [_cache setTotalCostLimit:MAX_CACHE_SIZE];
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
