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
BOOL IJSVGReadXMLAttribute(NSXMLNode* node, IJSVGBitFlags* activeAttributes,
    NSUInteger* attribute, NSString* __autoreleasing* value);
NSSet<NSString*>* IJSVGClassNameList(NSString* value);

NSString* IJSVGAttributeValue(
    NSString* __unsafe_unretained const attributeValues[kIJSVGNodeAttributeStorageLength],
    IJSVGNodeAttribute attribute);

BOOL IJSVGAttributeHasValue(
    NSString* __unsafe_unretained const attributeValues[kIJSVGNodeAttributeStorageLength],
    IJSVGNodeAttribute attribute,
    NSString* __autoreleasing* value);

void IJSVGStoreStyleAttributes(
    IJSVGStyleSheetStyle* style,
    IJSVGBitFlags* activeAttributes,
    NSString* __unsafe_unretained attributeValues[kIJSVGNodeAttributeStorageLength]);

void IJSVGApplyTransformAttribute(IJSVGNode* node, NSString* value);
void IJSVGApplyBackgroundAttribute(IJSVGNode* node, NSString* value);
