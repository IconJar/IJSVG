//
//  IJSVGGroup.h
//  IJSVG
//
//  Created by Curtis Hard on 30/08/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <IJSVG/IJSVGPath.h>
#import <IJSVG/IJSVGViewportNode.h>

NS_ASSUME_NONNULL_BEGIN

@interface IJSVGGroup : IJSVGViewportNode {
@private
    NSMutableArray<IJSVGNode*>* _children;
}

@property (nonatomic, readonly) NSArray<IJSVGNode*>* children;

- (void)addChild:(IJSVGNode* _Nullable)child;
- (void)addChildren:(NSArray<IJSVGNode*>*)children;
- (void)removeChild:(IJSVGNode*)child;
- (void)removeChildren:(NSArray<IJSVGNode*>*)children;
- (BOOL)childrenMatchTraits:(IJSVGNodeTraits)traits;
- (BOOL)containsNodesMatchingTraits:(IJSVGNodeTraits)traits;
- (NSArray<IJSVGNode*>*)nodesMatchingTraits:(IJSVGNodeTraits)traits;
- (NSSet<IJSVGNode*>*)childSetOfType:(IJSVGNodeType)type;
- (NSArray<IJSVGNode*>*)childrenOfType:(IJSVGNodeType)type;

@end

NS_ASSUME_NONNULL_END
