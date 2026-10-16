//
//  IJSVGExportNode.h
//  IJSVG
//
//  Created by Curtis Hard on 16/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#pragma once
#import <Foundation/Foundation.h>
#import <IJSVG/IJSVGXMLTypes.h>

NS_ASSUME_NONNULL_BEGIN

@interface IJSVGExportNode : NSObject
- (instancetype)init NS_UNAVAILABLE;
@property (nonatomic, copy) NSString* name;
@property (nonatomic, copy) NSString* stringValue;
@property (nonatomic, readonly) NSString* localName;
@property (nonatomic, readonly, nullable) NSString* prefix;
@property (nonatomic, readonly, nullable) NSString* URI;
@property (nonatomic, readonly) IJSVGXMLNodeKind kind;
@property (nonatomic, weak, readonly, nullable) IJSVGExportNode* parent;
@property (nonatomic, readonly, nullable) IJSVGExportNode* nextSibling;
@property (nonatomic, readonly) NSUInteger index;
@property (nonatomic, copy, null_resettable) NSArray<IJSVGExportNode*>* children;
@property (nonatomic, readonly) NSUInteger childCount;
- (instancetype)initWithKind:(IJSVGXMLNodeKind)kind;
+ (instancetype)attributeWithName:(NSString*)name stringValue:(NSString*)value;
- (void)detach;
- (void)addChild:(IJSVGExportNode*)child;
- (void)insertChild:(IJSVGExportNode*)child atIndex:(NSUInteger)index;
- (void)removeChildAtIndex:(NSUInteger)index;
- (void)replaceWithNode:(IJSVGExportNode*)node;
- (void)replaceChildAtIndex:(NSUInteger)index withNode:(IJSVGExportNode*)child;
@end

NS_ASSUME_NONNULL_END
