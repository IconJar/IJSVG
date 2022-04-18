//
//  IJSVGStrokeLayer.m
//  IJSVGExample
//
//  Created by Curtis Hard on 09/01/2017.
//  Copyright © 2017 Curtis Hard. All rights reserved.
//

#import "IJSVGStrokeLayer.h"

@implementation IJSVGStrokeLayer

- (CGRect)outerBoundingBox
{
    return CGRectMake(-self.lineWidth / 2.f, -self.lineWidth / 2.f,
                      self.boundingBox.size.width + self.lineWidth,
                      self.boundingBox.size.height + self.lineWidth);
}

@end
