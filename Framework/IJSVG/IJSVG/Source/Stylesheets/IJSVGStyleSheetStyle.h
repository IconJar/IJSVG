//
//  IJSVGStyleSheetStyle.h
//  IJSVG
//
//  Created by Curtis Hard on 03/09/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGColor.h>
#import <Foundation/Foundation.h>

typedef struct {
    NSUInteger attribute;
    __unsafe_unretained NSString* name;
    __unsafe_unretained NSString* value;
    BOOL important;
} IJSVGStyleSheetAttribute;

@interface IJSVGStyleSheetStyle : NSObject {

@private
    NSMutableDictionary* _dict;
    NSMutableSet<NSString*>* _importantProperties;
    BOOL _geometryPropertiesKnown;
    BOOL _hasGeometryProperties;
    IJSVGStyleSheetAttribute* _attributes;
    NSUInteger _attributeCount;
    BOOL _attributesReady;
}

+ (IJSVGStyleSheetStyle*)parseStyleString:(NSString*)string;
+ (IJSVGStyleSheetStyle*)parseStyleString:(NSString*)string
                           removeComments:(BOOL)removeComments;

- (void)setPropertyValue:(id)value
             forProperty:(NSString*)key;
- (id)property:(NSString*)key;
- (NSDictionary*)properties;
- (BOOL)hasGeometryProperties;
// Borrowed entries remain valid until the style changes or is released.
- (const IJSVGStyleSheetAttribute*)attributesWithCount:(NSUInteger*)count;
- (BOOL)isPropertyImportant:(NSString*)key;
- (BOOL)hasImportantProperties;
- (void)setResolvedValue:(id)value
             forProperty:(NSString*)key
               important:(BOOL)important;

- (void)addPropertiesFromStyle:(IJSVGStyleSheetStyle*)style;
- (IJSVGStyleSheetStyle*)mergedStyle:(IJSVGStyleSheetStyle*)style;

@end
