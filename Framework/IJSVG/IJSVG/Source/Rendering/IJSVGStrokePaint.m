//
//  IJSVGStrokePaint.m
//  IJSVG
//
//  Created by Curtis Hard on 01/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVGStrokePaint.h>

@implementation IJSVGStrokePaint

// Allocation already supplies the class. A static identity
// comparison here avoids object class queries in parsing and drawing, while
// subclasses keep the general implementation.
+ (instancetype)allocWithZone:(NSZone*)zone
{
    IJSVGStrokePaint* instance = [super allocWithZone:zone];
    if (self == IJSVGStrokePaint.class) {
        instance->_builtInPaintKind = IJSVGBuiltInPaintStroke;
    }
    return instance;
}
@end
