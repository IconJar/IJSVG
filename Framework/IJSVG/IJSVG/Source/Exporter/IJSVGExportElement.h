//
//  IJSVGExportElement.h
//  IJSVG
//
//  Created by Curtis Hard on 16/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#pragma once
#import <IJSVG/IJSVGExportNode.h>

NS_ASSUME_NONNULL_BEGIN

@interface IJSVGExportElement : IJSVGExportNode
- (instancetype)init;
@property (nonatomic, readonly) NSArray<IJSVGExportNode*>* attributes;
- (instancetype)initWithName:(NSString*)name;
- (nullable IJSVGExportNode*)attributeForName:(NSString*)name;
- (void)addAttribute:(IJSVGExportNode*)attribute;
- (void)setAttributeWithName:(NSString*)name stringValue:(NSString*)value;
- (void)removeAttributeForName:(NSString*)name;
- (void)setAttributesAsDictionary:(NSDictionary<NSString*, NSString*>*)attributes;
@end

NS_ASSUME_NONNULL_END
