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

@interface IJSVGColorList : NSObject <NSCopying> {

@private
    NSMutableDictionary<NSColor*, NSColor*>* _replacementColorTree;
    NSMutableSet<IJSVGColorType*>* _colors;
}

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
- (NSDictionary<NSColor*, NSColor*>*)replacementColors;

@end
