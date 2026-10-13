//
//  IJSVGRoundedShape.m
//  IJSVG
//
//  Created by Curtis Hard on 13/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGRoundedShape.h>

@implementation IJSVGRoundedShape

- (id)copyWithZone:(NSZone*)zone
{
    IJSVGRoundedShape* node = [super copyWithZone:zone];
    node.rx = _rx.copy;
    node.ry = _ry.copy;
    return node;
}

- (BOOL)containsRelativeUnits
{
    return _rx.isRelativeUnit || _ry.isRelativeUnit || [super containsRelativeUnits];
}

@end
