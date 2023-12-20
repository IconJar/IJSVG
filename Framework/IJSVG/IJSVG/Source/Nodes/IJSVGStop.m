//
//  IJSVGStop.m
//  IJSVG
//
//  Created by Curtis Hard on 05/09/2022.
//  Copyright © 2022 Curtis Hard. All rights reserved.
//

#import "IJSVGStop.h"

@implementation IJSVGStop

+ (IJSVGBitFlags*)allowedAttributes
{
    IJSVGBitFlags64* storage = [[IJSVGBitFlags64 alloc] init];
    [storage addBits:[super allowedAttributes]];
    [storage setBit:IJSVGNodeAttributeStopColor];
    [storage setBit:IJSVGNodeAttributeStopOpacity];
    [storage setBit:IJSVGNodeAttributeOffset];
    return storage;
}

@end
