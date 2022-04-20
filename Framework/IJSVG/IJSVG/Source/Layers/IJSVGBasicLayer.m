//
//  IJSVGBasicLayer.m
//  IJSVG
//
//  Created by Curtis Hard on 19/04/2022.
//  Copyright © 2022 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGBasicLayer.h>

@implementation IJSVGBasicLayer

@synthesize backingScaleFactor;
@synthesize requiresBackingScale;
@synthesize renderQuality;
@synthesize debugLayers;

- (id<CAAction>)actionForKey:(NSString*)event
{
    return nil;
}


- (void)performRenderInContext:(CGContextRef)ctx {
}



@end
