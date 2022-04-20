//
//  IJSVGGroupLayer.m
//  IJSVGExample
//
//  Created by Curtis Hard on 07/01/2017.
//  Copyright © 2017 Curtis Hard. All rights reserved.
//

#import "IJSVGGroupLayer.h"
#import "IJSVGViewBox.h"
#import "IJSVGUnitRect.h"
#import "IJSVGLayer.h"

@implementation IJSVGGroupLayer

- (CGRect)innerBoundingBox
{
    return self.outerBoundingBox;
}

@end
