//
//  IJSVGGradientStops.h
//  IJSVG
//
//  Created by Curtis Hard on 13/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGGradient.h>
#import <IJSVGXML.h>

@class IJSVGParser;

BOOL IJSVGPopulatePlainGradientStops(IJSVGGradient* gradient, IJSVGXMLNode* element, IJSVGParser* parser);

@interface IJSVGGradientStops : NSObject
+ (BOOL)canSharePlainElement:(IJSVGXMLNode*)element parser:(IJSVGParser*)parser;
+ (BOOL)canCacheElement:(IJSVGXMLNode*)element;
@property (nonatomic, readonly) CGFloat inheritedOpacity;

- (instancetype)initWithGradient:(IJSVGGradient*)gradient element:(IJSVGXMLNode*)element parser:(IJSVGParser*)parser;
- (void)applyToGradient:(IJSVGGradient*)gradient;
- (void)appendStopsToGradient:(IJSVGGradient*)gradient;
- (CGGradientRef)CGGradientForGradient:(IJSVGGradient*)gradient;
@end

// Internal parser handoff. Public child access materializes independent stops.
@interface IJSVGGradient (DeferredStops)
- (void)deferStops:(IJSVGGradientStops*)stops;
- (void)shareGradientWithStops:(IJSVGGradientStops*)stops;
- (CGGradientRef)newCGGradient CF_RETURNS_RETAINED;
@end

// A bounded stack key includes raw declarations and inherited opacity.
#define IJSVGGradientStopKeyCapacity 8192
BOOL IJSVGGradientStopCacheKey(IJSVGXMLNode* element, CGFloat opacity, unsigned char* key, NSUInteger* length);
