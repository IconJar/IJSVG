//
//  IJSVGFilterGraph+Outlines.h
//  IJSVG
//
//  Created by Curtis Hard on 11/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVGFilterGraph.h>

@interface IJSVGFilterGraph (Outlines)

// Conservative vector coverage in the same user space as boundingBox and viewPort.
// Approximates filter coverage rather than tracing rendered alpha.
// NULL means the graph cannot be represented meaningfully as vector coverage.
+ (BOOL)canOutlineMetadata:(IJSVGFilterMetadata*)metadata
         backgroundIsEmpty:(BOOL)backgroundIsEmpty;
- (CGPathRef)newOutlineForSourcePath:(CGPathRef)source
                   backgroundIsEmpty:(BOOL)backgroundIsEmpty CF_RETURNS_RETAINED;

@end
