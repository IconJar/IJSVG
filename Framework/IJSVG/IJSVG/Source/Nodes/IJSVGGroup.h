//
//  IJSVGGroup.h
//  IconJar
//
//  Created by Curtis Hard on 30/08/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGNode.h>
#import <IJSVG/IJSVGPath.h>
#import <Foundation/Foundation.h>

@interface IJSVGGroup : IJSVGNode {

@private
    NSMutableArray<IJSVGNode*>* _children;
}

@property (weak, nonatomic, readonly) NSArray<IJSVGNode*>* children;

- (void)addChild:(IJSVGNode*)child;
- (void)addChildren:(NSArray<IJSVGNode*>*)children;
- (void)removeChild:(IJSVGNode*)child;
- (void)removeChildren:(NSArray<IJSVGNode*>*)children;
- (BOOL)childrenMatchTraits:(IJSVGNodeTraits)traits;
- (BOOL)containsNodesMatchingTraits:(IJSVGNodeTraits)traits;
- (NSArray<IJSVGNode*>*)nodesMatchingTraits:(IJSVGNodeTraits)traits;
- (NSSet<IJSVGNode*>*)childSetOfType:(IJSVGNodeType)type;
- (NSArray<IJSVGNode*>*)childrenOfType:(IJSVGNodeType)type;

@end
