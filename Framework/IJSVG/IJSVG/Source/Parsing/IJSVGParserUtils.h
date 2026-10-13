//
//  IJSVGParserUtils.h
//  IJSVG
//
//  Created by Curtis Hard on 27/06/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <IJSVG/IJSVGGraphicsNode.h>
#import <IJSVG/IJSVGNode.h>
#import <IJSVG/IJSVGReference.h>

NS_ASSUME_NONNULL_BEGIN

BOOL IJSVGParseLengthNumber(const char* _Nonnull* _Nonnull position, BOOL allowNegative, CGFloat* value);
IJSVGUnitLength* _Nullable IJSVGLengthFromString(NSString* value, BOOL allowNegative);
NSArray<IJSVGUnitLength*>* IJSVGUnitLengthsFromString(NSString* value);
BOOL IJSVGUnitLengthsAreValid(NSString* value, BOOL allowNegative, BOOL single);
BOOL IJSVGAttributeIsGeometryProperty(NSUInteger attribute);
BOOL IJSVGAttributeSupportsVariables(NSUInteger attribute);

// Font longhands occupy consecutive attribute slots, text rendering uses
// bit 63.
static inline uint64_t IJSVGTextStyleBit(NSUInteger attribute)
{
    if (attribute >= IJSVGNodeAttributeFont && attribute <= IJSVGNodeAttributeFontSizeAdjust) {
        return UINT64_C(1) << (attribute - IJSVGNodeAttributeFont);
    }
    return attribute == IJSVGNodeAttributeTextRendering ? UINT64_C(1) << 63 : 0;
}
BOOL IJSVGGeometryLengthIsValid(NSString* value, IJSVGNodeAttribute attribute);
IJSVGUnitLength* _Nullable IJSVGGeometryLengthFromString(NSString* value, IJSVGNodeAttribute attribute);
IJSVGUnitLength* IJSVGGeometryInitialLength(IJSVGNodeAttribute attribute);

IJSVGPaintOrder IJSVGPaintOrderFromString(NSString* value);
NSString* IJSVGStringFromPaintOrder(IJSVGPaintOrder order);

BOOL IJSVGIsolationFromString(NSString* value, BOOL parentIsolation);

BOOL IJSVGAttributeMaskContains(uint64_t mask, IJSVGNodeAttribute attribute);
NSUInteger IJSVGNodeAttributeForName(NSString* _Nullable name);

typedef struct {
    __unsafe_unretained NSXMLNode* href;
    __unsafe_unretained NSXMLNode* namespacedHref;
    __unsafe_unretained NSXMLNode* legacyHref;
} IJSVGReferenceAttributes;

void IJSVGReadReferenceAttribute(NSXMLNode* node, NSString* name, IJSVGReferenceAttributes* attributes);
IJSVGReference* IJSVGEmptyReference(void);

// Read a known attribute with a nonempty value.
// Pass nil for activeAttributes to read all known attributes when building the
// cache.
BOOL IJSVGReadXMLAttribute(NSXMLNode* node, IJSVGBitFlags* _Nullable activeAttributes, NSUInteger* attribute, NSString* _Nullable __autoreleasing* _Nonnull value, IJSVGReferenceAttributes* _Nullable reference);
NSSet<NSString*>* IJSVGClassNameList(NSString* _Nullable value);

NSString* _Nullable IJSVGAttributeValue(NSString* _Nullable __unsafe_unretained const attributeValues[_Nonnull kIJSVGNodeAttributeStorageLength], IJSVGNodeAttribute attribute);

BOOL IJSVGAttributeHasValue(NSString* _Nullable __unsafe_unretained const attributeValues[_Nonnull kIJSVGNodeAttributeStorageLength], IJSVGNodeAttribute attribute, NSString* _Nullable __autoreleasing* _Nullable value);

uint64_t IJSVGStoreCascadedStyleAttributes(IJSVGStyleSheetStyle* _Nullable style, IJSVGStyleSheetStyle* _Nullable inlineStyle, IJSVGBitFlags* activeAttributes, NSString* _Nullable __unsafe_unretained attributeValues[_Nonnull kIJSVGNodeAttributeStorageLength]);

void IJSVGStoreStyleAttributes(IJSVGStyleSheetStyle* _Nullable style, IJSVGBitFlags* activeAttributes, NSString* _Nullable __unsafe_unretained attributeValues[_Nonnull kIJSVGNodeAttributeStorageLength]);

// Auto and negative dimensions on use/symbol leave the default size in effect.
IJSVGUnitLength* _Nullable IJSVGDimensionFromString(NSString* value, IJSVGNodeType type);
IJSVGUnitLength* _Nullable IJSVGSymbolReferenceFromString(NSString* _Nullable value, IJSVGNodeAttribute attribute);

typedef NS_ENUM(uint8_t, IJSVGPositionSyntax) { IJSVGPositionSyntaxTransformOrigin,
    IJSVGPositionSyntaxBasicShape };

// Splits a mutable NUL terminated buffer in place without retaining its bytes.
NSArray<IJSVGUnitLength*>* _Nullable IJSVGPositionFromBuffer(char* buffer, IJSVGPositionSyntax syntax);
NSArray<IJSVGUnitLength*>* _Nullable IJSVGTransformOriginFromString(NSString* value);
void IJSVGApplyTransformAttribute(IJSVGGraphicsNode* node, NSString* value, BOOL allowCSSUnits);
void IJSVGApplyParsedTransforms(IJSVGGraphicsNode* node, NSArray<IJSVGTransform*>* transforms);
void IJSVGApplyBackgroundAttribute(IJSVGGraphicsNode* node, NSString* value);

NS_ASSUME_NONNULL_END
