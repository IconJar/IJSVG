//
//  IJSVGStop.m
//  IJSVG
//
//  Created by Curtis Hard on 05/09/2022.
//  Copyright © 2022 Curtis Hard. All rights reserved.
//

#import "IJSVGStop.h"

@implementation IJSVGStop

+ (NSIndexSet*)allowedAttributes
{
    NSMutableIndexSet* set = [[NSMutableIndexSet alloc] init];
    [set addIndexes:[super allowedAttributes]];
    [set addIndex:IJSVGNodeAttributeStopColor];
    [set addIndex:IJSVGNodeAttributeStopOpacity];
    [set addIndex:IJSVGNodeAttributeOffset];
    return set;
}

@end
