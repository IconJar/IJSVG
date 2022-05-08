//
//  SVGExampleView1.m
//  IJSVGExample
//
//  Created by Curtis Hard on 04/09/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import "SVGExampleView1.h"

@implementation SVGExampleView1

- (IJSVG *)svg
{
    return [IJSVG svgNamed:@"conical"];
}

@end
