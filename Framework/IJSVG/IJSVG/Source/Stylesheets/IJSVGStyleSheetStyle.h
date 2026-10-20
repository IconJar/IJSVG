//
//  IJSVGStyleSheetStyle.h
//  IJSVG
//
//  Created by Curtis Hard on 03/09/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <IJSVG/IJSVGColor.h>

typedef struct {
    NSUInteger attribute;
    __unsafe_unretained NSString* name;
    __unsafe_unretained NSString* value;
    BOOL important;
    BOOL invalidAtComputedValue;
} IJSVGStyleSheetAttribute;

@interface IJSVGStyleSheetStyle : NSObject {
@private
    NSMutableDictionary<NSString*, NSString*>* _dict;
    NSMutableSet<NSString*>* _importantProperties;
    BOOL _geometryPropertiesKnown;
    BOOL _hasGeometryProperties;
    IJSVGStyleSheetAttribute* _attributes;
    NSUInteger _attributeCount;
    BOOL _attributesReady;
    BOOL _hasCustomProperties;
    BOOL _hasCascadeDependentValues;
    NSMutableSet<NSString*>* _normalInlineRollbacks;
    NSMutableSet<NSString*>* _invalidVariableProperties;
    NSMutableDictionary<NSString*, NSString*>* _variableSources;
}

// Deferred cascade evaluation is needed only when variable substitution can request layer rollback.
@property (nonatomic, copy) IJSVGStyleSheetStyle* (^layerResolver)(NSDictionary<NSString*, id>* properties);
- (BOOL)hasCascadeDependentValues;
- (BOOL)hasVariableProperties;
- (void)suppressNormalInlineProperty:(NSString*)property;
- (BOOL)suppressesNormalInlineProperty:(NSString*)property;
- (IJSVGStyleSheetStyle*)styleByRemovingLayerReverts;

// Parses a borrowed declaration slice with comments already removed.
+ (IJSVGStyleSheetStyle*)parseStyleBytes:(const char*)bytes length:(NSUInteger)length;
+ (IJSVGStyleSheetStyle*)parseStyleString:(NSString*)string;
+ (IJSVGStyleSheetStyle*)parseStyleString:(NSString*)string removeComments:(BOOL)removeComments;

- (void)setPropertyValue:(NSString*)value forProperty:(NSString*)key;
- (NSString*)property:(NSString*)key;
- (NSDictionary<NSString*, NSString*>*)properties;
- (BOOL)hasGeometryProperties;
- (BOOL)hasCustomProperties;
- (void)copyProperty:(NSString*)property fromStyle:(IJSVGStyleSheetStyle*)style;
- (IJSVGStyleSheetStyle*)styleByResolvingVariables:(NSDictionary<NSString*, id>*)properties;

// Borrowed entries remain valid until the style changes or is released.
- (const IJSVGStyleSheetAttribute*)attributesWithCount:(NSUInteger*)count;
- (BOOL)isPropertyImportant:(NSString*)key;
- (BOOL)hasImportantProperties;
- (void)setResolvedValue:(NSString*)value forProperty:(NSString*)key important:(BOOL)important;

- (void)addPropertiesFromStyle:(IJSVGStyleSheetStyle*)style;
- (IJSVGStyleSheetStyle*)mergedStyle:(IJSVGStyleSheetStyle*)style;

@end
