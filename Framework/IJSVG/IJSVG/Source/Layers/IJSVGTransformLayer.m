//
//  IJSVGTransformLayer.m
//  IJSVG
//
//  Created by Curtis Hard on 31/03/2022.
//  Copyright © 2022 Curtis Hard. All rights reserved.
//

#import "IJSVGTransformLayer.h"

@implementation IJSVGTransformLayer

@synthesize backingScaleFactor;
@synthesize renderQuality;
@synthesize requiresBackingScaleHelp;
@synthesize maskLayer;

- (BOOL)requiresBackingScaleHelp
{
    return YES;
}

- (void)performRenderInContext:(CGContextRef)ctx
{
    // do nothing, this does nothing as a group
}

@end
