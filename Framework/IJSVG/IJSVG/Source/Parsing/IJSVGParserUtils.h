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
NSString* IJSVGAttributeValue(
    NSString* __unsafe_unretained const attributeValues[kIJSVGNodeAttributeStorageLength],
    IJSVGNodeAttribute attribute);
BOOL IJSVGAttributeHasValue(
    NSString* __unsafe_unretained const attributeValues[kIJSVGNodeAttributeStorageLength],
    IJSVGNodeAttribute attribute,
    NSString* __autoreleasing* value);
void IJSVGStoreStyleAttributes(
    IJSVGStyleSheetStyle* style,
    uint64_t activeAttributes,
    NSString* __unsafe_unretained attributeValues[kIJSVGNodeAttributeStorageLength],
    uint64_t* presentAttributes);
void IJSVGApplyTransformAttribute(IJSVGNode* node, NSString* value);
