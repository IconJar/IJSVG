//
//  IJSVGRectPaint.m
//  IJSVG
//
//  Created by Curtis Hard on 01/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVGRectPaint.h>

@implementation IJSVGRectPaint

// Allocation already supplies the class. A static identity
// comparison here avoids object class queries in parsing and drawing, while
// subclasses keep the general implementation.
+ (instancetype)allocWithZone:(NSZone*)zone
{
    IJSVGRectPaint* instance = [super allocWithZone:zone];
    if (self == IJSVGRectPaint.class) {
        instance->_builtInPaintKind = IJSVGBuiltInPaintRect;
    }
    return instance;
}

- (BOOL)treatImplicitOriginAsTransform
{
    return NO;
}

@end
