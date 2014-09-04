//
//  IJSVGDef.h
//  IJSVGExample
//
//  Created by Curtis Hard on 03/09/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "IJSVGNode.h"

@interface IJSVGDef : IJSVGNode {

@private
    NSMutableDictionary * _dict;
    
}

- (void)addDef:(IJSVGNode *)aDef;

@end
