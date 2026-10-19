//
//  IJSVGRegion.m
//  IJSVG
//
//  Created by Curtis Hard on 19/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGRegion.h>

@implementation IJSVGRegion

- (instancetype)initWithRect:(CGRect)rect type:(IJSVGNodeType)type value:(NSString*)value
{
    return [self initWithRect:rect type:type value:value node:nil coordinateSpace:IJSVGRegionCoordinateSpaceDestination instanceIndex:0];
}

- (instancetype)initWithRect:(CGRect)rect type:(IJSVGNodeType)type value:(NSString*)value node:(IJSVGNode*)node coordinateSpace:(IJSVGRegionCoordinateSpace)coordinateSpace instanceIndex:(NSUInteger)instanceIndex
{
    if ((self = [super init]) != nil) {
        _rect = rect;
        _type = type;
        _value = [value copy];
        _identifier = [node.identifier copy];
        _node = node;
        _coordinateSpace = coordinateSpace;
        _instanceIndex = instanceIndex;
    }
    return self;
}

@end
