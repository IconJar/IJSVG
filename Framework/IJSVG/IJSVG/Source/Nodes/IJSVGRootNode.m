//
//  IJSVGRootNode.m
//  IJSVG
//
//  Created by Curtis Hard on 28/03/2022.
//  Copyright © 2022 Curtis Hard. All rights reserved.
//

#import "IJSVGRootNode.h"

@implementation IJSVGRootNode

- (void)dealloc
{
    (void)[_intrinsicSize release], _intrinsicSize = nil;
    [super dealloc];
}

- (CGRect)bounds
{
    return [self.viewBox computeValue:CGSizeZero];
}

@end
