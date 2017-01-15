//
//  IJSVGText.m
//  IJSVGExample
//
//  Created by Curtis Hard on 01/01/2017.
//  Copyright © 2017 Curtis Hard. All rights reserved.
//

#import "IJSVGText.h"

@implementation IJSVGText

@synthesize text;

- (void)dealloc
{
    [text release], text = nil;
    [super dealloc];
}

- (IJSVGText *)copyWithZone:(NSZone *)zone
{
    IJSVGText * node = [super copyWithZone:zone];
    node.text = self.text;
    return node;
}

@end
