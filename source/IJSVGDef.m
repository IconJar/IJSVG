//
//  IJSVGDef.m
//  IJSVGExample
//
//  Created by Curtis Hard on 03/09/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import "IJSVGDef.h"

@implementation IJSVGDef

- (void)dealloc
{
    [_dict release], _dict = nil;
    [super dealloc];
}

- (id)init
{
    if( ( self = [super initWithDef:NO] ) != nil )
    {
        _dict = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (void)addDef:(IJSVGNode *)aDef
{
    if( aDef.identifier == nil )
        return;
    [_dict setObject:aDef
              forKey:aDef.identifier];
}

- (IJSVGDef *)defForID:(NSString *)anID
{
    return [_dict objectForKey:anID];
}

@end
