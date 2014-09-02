//
//  IJSVGForeignObject.m
//  IconJar
//
//  Created by Curtis Hard on 02/09/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import "IJSVGForeignObject.h"

@implementation IJSVGForeignObject

@synthesize requiredExtension;

- (void)dealloc
{
    [requiredExtension release], requiredExtension = nil;
    [super dealloc];
}

@end
