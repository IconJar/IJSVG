//
//  IJSVGColorList.h
//  IconJar
//
//  Created by Curtis Hard on 07/07/2019.
//  Copyright © 2019 Curtis Hard. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "IJSVGColor.h"

typedef NS_ENUM(NSInteger, IJSVGColorListUsageType) {
    IJSVGColorListUsageTypeFill,
    IJSVGColorListUsageTypeStop,
    IJSVGColorListUsageTypeStroke,
    IJSVGColorListUsageTypeGeneric
};

@interface IJSVGColorList : NSObject <NSCopying> {
    
@private
    NSMutableDictionary<NSNumber *, NSMutableDictionary<NSColor *, NSColor *> *> * _colorTree;
}

@property (nonatomic, copy) NSString * name;

- (NSColor *)proposedColorForColor:(NSColor *)color
                         usageType:(IJSVGColorListUsageType)usageType;
- (void)removeAllReplacementColors;
- (void)removeReplacementColor:(NSColor *)color
                  forUsageType:(IJSVGColorListUsageType)type;
- (void)setReplacementColor:(NSColor *)newColor
                   forColor:(NSColor *)color
                  usageType:(IJSVGColorListUsageType)type;
- (void)setReplacementColors:(NSDictionary<NSColor *, NSColor *> *)colors
                   usageType:(IJSVGColorListUsageType)usageType
         clearExistingColors:(BOOL)clearExistingColors;

- (void)addColorsFromList:(IJSVGColorList *)sheet;
- (NSSet<NSColor *> *)colorsForUsageType:(IJSVGColorListUsageType)type;
- (void)addColor:(NSColor *)color
    forUsageType:(IJSVGColorListUsageType)type;

@end
