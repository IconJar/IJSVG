//
//  IJSVGPattern.m
//  IJSVGExample
//
//  Created by Curtis Hard on 27/05/2016.
//  Copyright © 2016 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGPattern.h>
#import <IJSVG/IJSVGUnitRect.h>
#import <IJSVG/IJSVGRootNode.h>

@implementation IJSVGPattern

+ (NSIndexSet*)allowedAttributes
{
    NSMutableIndexSet* set = [[NSMutableIndexSet alloc] init];
    [set addIndexes:[super allowedAttributes]];
    [set addIndex:IJSVGNodeAttributePatternTransform];
    [set addIndex:IJSVGNodeAttributePatternUnits];
    [set addIndex:IJSVGNodeAttributePatternContentUnits];
    [set addIndex:IJSVGNodeAttributeViewBox];
    return set;
}

- (instancetype)init
{
    if((self = [super init]) != nil) {
        self.viewBox = nil;
        self.viewBoxAlignment = IJSVGViewBoxAlignmentXMidYMid;
        self.viewBoxMeetOrSlice = IJSVGViewBoxMeetOrSliceMeet;
    }
    return self;
}

- (IJSVGUnitType)contentUnitsWithReferencingNodeBounds:(CGRect*)bounds
{
    // as far as I can tell, units are inherited, so we need to go to the root
    // level pattern if there is one (we could be nested) and if so, return those
    // units as the actual units, but the bounds are based on the units of current
    // units defined on this node... wtf?!
    IJSVGNode* node = nil;
    IJSVGPattern* parentPattern = [self rootNodeMatchingClass:self.class];
    IJSVGUnitType units = [self contentUnitsWithReferencingNode:&node];
    if(units == IJSVGUnitUserSpaceOnUse) {
        *bounds = node.rootNode.bounds;
    } else {
        *bounds = node.parentNode.bounds;
    }
    return parentPattern ? [parentPattern contentUnitsWithReferencingNode:&node] : units;
}


@end
