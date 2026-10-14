//
//  IJSVGGradientStops.h
//  IJSVG
//
//  Created by Curtis Hard on 13/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import "IJSVGXML.h"
#import <IJSVG/IJSVGGradient.h>

@class IJSVGParser;

BOOL IJSVGPopulatePlainGradientStops(IJSVGGradient* gradient, IJSVGXMLNode* element, IJSVGParser* parser);

@interface IJSVGGradientStops : NSObject
+ (BOOL)canCacheElement:(IJSVGXMLNode*)element;
@property (nonatomic, readonly) CGFloat inheritedOpacity;

- (instancetype)initWithGradient:(IJSVGGradient*)gradient element:(IJSVGXMLNode*)element;
- (void)applyToGradient:(IJSVGGradient*)gradient;
- (void)appendStopsToGradient:(IJSVGGradient*)gradient;
@end

// Internal parser handoff. Public child access materializes independent stops.
@interface IJSVGGradient (DeferredStops)
- (void)deferStops:(IJSVGGradientStops*)stops;
@end
