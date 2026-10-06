//
//  IJSVGParserUtils.h
//  IJSVG
//
//  Created by Curtis Hard on 27/06/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGNode.h>
#import <Foundation/Foundation.h>

BOOL IJSVGAttributeMaskContains(uint64_t mask, IJSVGNodeAttribute attribute);
NSUInteger IJSVGNodeAttributeForName(NSString* name);

// Read a known attribute with a nonempty value.
// Pass nil for activeAttributes to read all known attributes when building the cache.
BOOL IJSVGReadXMLAttribute(CXMLNode* node, IJSVGBitFlags* activeAttributes,
    NSUInteger* attribute, NSString* __autoreleasing* value);
NSSet<NSString*>* IJSVGClassNameList(NSString* value);

NSString* IJSVGAttributeValue(
    NSArray *attributeValues,
    IJSVGNodeAttribute attribute);

BOOL IJSVGAttributeHasValue(
    NSArray *attributeValues,
    IJSVGNodeAttribute attribute,
    NSString* __autoreleasing* value);

void IJSVGStoreStyleAttributes(
    IJSVGStyleSheetStyle* style,
    IJSVGBitFlags* activeAttributes,
    NSMutableArray *attributeValues);

void IJSVGApplyTransformAttribute(IJSVGNode* node, NSString* value);
void IJSVGApplyBackgroundAttribute(IJSVGNode* node, NSString* value);
