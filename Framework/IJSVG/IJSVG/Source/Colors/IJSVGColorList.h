//
//  IJSVGColorList.h
//  IconJar
//
//  Created by Curtis Hard on 07/07/2019.
//  Copyright © 2019 Curtis Hard. All rights reserved.
//

#import "IJSVGColor.h"
#import "IJSVGColorType.h"
#import <Foundation/Foundation.h>

typedef NS_OPTIONS(NSInteger, IJSVGColorListTypes) {
    IJSVGColorListTypeNone,
    IJSVGColorListTypeFill,
    IJSVGColorListTypeStroke,
    IJSVGColorListTypeStopColor,
    IJSVGColorListTypePatterns
};

@interface IJSVGColorList : NSObject <NSCopying> {

@private
    NSMutableDictionary<NSColor*, NSColor*>* _replacementColorTree;
    NSMutableSet<IJSVGColorType*>* _colors;
}

@property (nonatomic, assign) IJSVGColorListTypes types;
@property (nonatomic, assign, readonly) NSUInteger count;

- (NSColor*)proposedColorForColor:(NSColor*)color;
- (void)removeAllReplacementColors;
- (void)removeReplacementColor:(NSColor*)color;
- (void)setReplacementColor:(NSColor*)newColor
                   forColor:(NSColor*)color;
- (void)setReplacementColors:(NSDictionary<NSColor*, NSColor*>*)colors
         clearExistingColors:(BOOL)clearExistingColors;

- (void)addColorsFromList:(IJSVGColorList*)sheet;
- (NSSet<IJSVGColorType*>*)colors;
- (void)addColor:(IJSVGColorType*)color;

@end
