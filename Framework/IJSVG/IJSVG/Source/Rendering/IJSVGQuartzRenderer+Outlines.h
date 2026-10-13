//
//  IJSVGQuartzRenderer+Outlines.h
//  IJSVG
//
//  Created by Curtis Hard on 11/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVGQuartzRenderer.h>

@interface IJSVGQuartzRenderer (Outlines)

// Borrowed until measurement invalidation. NULL means unsupported coverage.
- (CGPathRef)outlinePathForRootNode:(IJSVGRootNode*)rootNode includingFilterExtents:(BOOL)includingFilterExtents preservingHoles:(BOOL)preservingHoles CF_RETURNS_NOT_RETAINED;

@end
