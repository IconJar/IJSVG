//
//  IJSVGParsedPathCache.h
//  IJSVG
//
//  Created by Curtis Hard on 11/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

typedef NS_ENUM(NSUInteger, IJSVGParsedPathKind) {
    IJSVGParsedPathData,
    IJSVGParsedPathPolygon,
    IJSVGParsedPathPolyline,
    IJSVGParsedPathKindCount
};

// Each parser owns a cache and accesses it on one thread at a time.
typedef struct IJSVGParsedPathCache IJSVGParsedPathCache;

IJSVGParsedPathCache* _Nullable IJSVGParsedPathCacheCreate(void);
void IJSVGParsedPathCacheDestroy(IJSVGParsedPathCache* _Nullable cache);

// Returns a retained immutable snapshot or NULL when the entry is absent.
CGPathRef _Nullable IJSVGParsedPathCacheCopy(IJSVGParsedPathCache* _Nullable cache,
                                             NSString* _Nullable source,
                                             IJSVGParsedPathKind kind) CF_RETURNS_RETAINED;

void IJSVGParsedPathCacheStore(IJSVGParsedPathCache* _Nullable cache,
                               NSString* _Nonnull source,
                               IJSVGParsedPathKind kind, CGPathRef _Nonnull path);
