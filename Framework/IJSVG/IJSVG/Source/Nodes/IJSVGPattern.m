//
//  IJSVGPattern.m
//  IJSVGExample
//
//  Created by Curtis Hard on 27/05/2016.
//  Copyright © 2016 Curtis Hard. All rights reserved.
//

#import "IJSVGPattern.h"
#import "IJSVGUnitRect.h"

@implementation IJSVGPattern

- (instancetype)init
{
    if((self = [super init]) != nil) {
        self.viewBox = nil;
        self.viewBoxAlignment = IJSVGViewBoxAlignmentXMidYMid;
        self.viewBoxMeetOrSlice = IJSVGViewBoxMeetOrSliceMeet;
    }
    return self;
}


@end
