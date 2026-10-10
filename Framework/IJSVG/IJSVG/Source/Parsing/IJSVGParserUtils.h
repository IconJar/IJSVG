//
//  IJSVGParserUtils.h
//  IJSVG
//
//  Created by Curtis Hard on 27/06/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGNode.h>
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

NSArray<IJSVGUnitLength*>* IJSVGUnitLengthsFromString(NSString* value);
BOOL IJSVGAttributeIsGeometryProperty(NSUInteger attribute);
BOOL IJSVGGeometryLengthIsValid(NSString* value, IJSVGNodeAttribute attribute);
IJSVGUnitLength* _Nullable IJSVGGeometryLengthFromString(NSString* value, IJSVGNodeAttribute attribute);
BOOL IJSVGGeometryPropertyAppliesToNode(IJSVGNodeAttribute attribute, IJSVGNode* node);
void IJSVGApplyGeometryAttributes(IJSVGNode* node,
                                  NSString* _Nullable __unsafe_unretained attributeValues[_Nonnull kIJSVGNodeAttributeStorageLength],
                                  IJSVGStyleSheetStyle* _Nullable style, IJSVGStyleSheetStyle* _Nullable inlineStyle);

IJSVGPaintOrder IJSVGPaintOrderFromString(NSString* value);
NSString* IJSVGStringFromPaintOrder(IJSVGPaintOrder order);

BOOL IJSVGIsolationFromString(NSString* value, BOOL parentIsolation);

BOOL IJSVGAttributeMaskContains(uint64_t mask, IJSVGNodeAttribute attribute);
NSUInteger IJSVGNodeAttributeForName(NSString* _Nullable name);

// Read a known attribute with a nonempty value.
// Pass nil for activeAttributes to read all known attributes when building the cache.
BOOL IJSVGReadXMLAttribute(NSXMLNode* node, IJSVGBitFlags* _Nullable activeAttributes,
                           NSUInteger* attribute, NSString* _Nullable __autoreleasing* _Nonnull value);
NSSet<NSString*>* IJSVGClassNameList(NSString* _Nullable value);

NSString* _Nullable IJSVGAttributeValue(NSString* _Nullable __unsafe_unretained const attributeValues[_Nonnull kIJSVGNodeAttributeStorageLength],
                                        IJSVGNodeAttribute attribute);

BOOL IJSVGAttributeHasValue(NSString* _Nullable __unsafe_unretained const attributeValues[_Nonnull kIJSVGNodeAttributeStorageLength],
                            IJSVGNodeAttribute attribute,
                            NSString* _Nullable __autoreleasing* _Nullable value);

void IJSVGStoreCascadedStyleAttributes(IJSVGStyleSheetStyle* _Nullable style,
    IJSVGStyleSheetStyle* _Nullable inlineStyle, IJSVGBitFlags* activeAttributes,
    NSString* _Nullable __unsafe_unretained attributeValues[_Nonnull kIJSVGNodeAttributeStorageLength]);

void IJSVGStoreStyleAttributes(IJSVGStyleSheetStyle* _Nullable style,
                               IJSVGBitFlags* activeAttributes,
                               NSString* _Nullable __unsafe_unretained attributeValues[_Nonnull kIJSVGNodeAttributeStorageLength]);

// Auto and negative dimensions on use/symbol leave the default size in effect.
IJSVGUnitLength* _Nullable IJSVGDimensionFromString(NSString* value, IJSVGNodeType type);
IJSVGUnitLength* _Nullable IJSVGSymbolReferenceFromString(NSString* _Nullable value,
                                                          IJSVGNodeAttribute attribute);

NSArray<IJSVGUnitLength*>* _Nullable IJSVGTransformOriginFromString(NSString* value);
void IJSVGApplyTransformAttribute(IJSVGNode* node, NSString* value);
void IJSVGApplyBackgroundAttribute(IJSVGNode* node, NSString* value);

NS_ASSUME_NONNULL_END
