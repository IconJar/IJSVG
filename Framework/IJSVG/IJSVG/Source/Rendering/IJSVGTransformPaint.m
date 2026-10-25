//
//  IJSVGTransformPaint.m
//  IJSVG
//
//  Created by Curtis Hard on 01/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVGTransformPaint.h>

@implementation IJSVGTransformPaint

// Allocation already supplies the class. A static identity
// comparison here avoids object class queries in parsing and drawing, while
// subclasses keep the general implementation.
+ (instancetype)allocWithZone:(NSZone*)zone
{
    IJSVGTransformPaint* instance = [super allocWithZone:zone];
    if (self == IJSVGTransformPaint.class) {
        instance->_builtInPaintKind = IJSVGBuiltInPaintTransform;
    }
    return instance;
}

- (IJSVGPaintTraits)paintTraits
{
    return IJSVGPaintTraitTransform;
}
@end
