//
//  IJSVGText.m
//  IJSVGExample
//
//  Created by Curtis Hard on 01/01/2017.
//  Copyright © 2017 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGText.h>

@implementation IJSVGText

- (IJSVGText*)copyWithZone:(NSZone*)zone
{
    IJSVGText* node = [super copyWithZone:zone];
    node.text = _text;
    return node;
}

@end
