//
//  IJSVGGroupLayer.m
//  IJSVGExample
//
//  Created by Curtis Hard on 07/01/2017.
//  Copyright © 2017 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGGroupLayer.h>
#import <IJSVG/IJSVGViewBox.h>
#import <IJSVG/IJSVGUnitRect.h>
#import <IJSVG/IJSVGLayer.h>

@implementation IJSVGGroupLayer

- (CGRect)innerBoundingBox
{
    return self.outerBoundingBox;
}

@end
