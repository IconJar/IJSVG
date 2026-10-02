//
//  IJSVGStop.m
//  IJSVG
//
//  Created by Curtis Hard on 05/09/2022.
//  Copyright © 2022 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGStop.h>

@implementation IJSVGStop

+ (IJSVGBitFlags*)allowedAttributes
{
    IJSVGBitFlags* storage = [[IJSVGBitFlags alloc] initWithLength:kIJSVGNodeAttributeStorageLength];
    [storage addBits:[super allowedAttributes]];
    [storage setBit:IJSVGNodeAttributeStopColor];
    [storage setBit:IJSVGNodeAttributeStopOpacity];
    [storage setBit:IJSVGNodeAttributeOffset];
    return storage;
}

@end
