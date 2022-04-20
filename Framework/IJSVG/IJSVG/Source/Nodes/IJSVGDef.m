//
//  IJSVGDef.m
//  IJSVGExample
//
//  Created by Curtis Hard on 03/09/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import "IJSVGDef.h"

@implementation IJSVGDef

- (id)init
{
    if ((self = [super init]) != nil) {
        _dict = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (void)addDef:(IJSVGNode*)aDef
{
    if (aDef.identifier == nil) {
        return;
    }
    _dict[aDef.identifier] = aDef;
}

- (IJSVGDef*)defForID:(NSString*)anID
{
    return _dict[anID];
}

@end
