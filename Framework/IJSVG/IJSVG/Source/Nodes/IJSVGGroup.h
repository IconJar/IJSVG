//
//  IJSVGGroup.h
//  IconJar
//
//  Created by Curtis Hard on 30/08/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import "IJSVGNode.h"
#import "IJSVGPath.h"
#import <Foundation/Foundation.h>

@interface IJSVGGroup : IJSVGNode {

@private
    NSMutableArray<IJSVGNode*>* _childNodes;
}

- (void)addChild:(IJSVGNode*)child;
- (NSArray<IJSVGNode*>*)childNodes;
- (void)purgeChildren;

@end
