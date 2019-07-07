//
//  IJSVGColorList.h
//  IconJar
//
//  Created by Curtis Hard on 07/07/2019.
//  Copyright © 2019 Curtis Hard. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "IJSVGColor.h"

@interface IJSVGColorList : NSObject <NSCopying> {
    
@private
    NSMutableDictionary<NSColor *, NSColor *> * _replacementColorTree;
    NSMutableSet<NSColor *> * _colors;
}

- (NSColor *)proposedColorForColor:(NSColor *)color;
- (void)removeAllReplacementColors;
- (void)removeReplacementColor:(NSColor *)color;
- (void)setReplacementColor:(NSColor *)newColor
                   forColor:(NSColor *)color;
- (void)setReplacementColors:(NSDictionary<NSColor *, NSColor *> *)colors
         clearExistingColors:(BOOL)clearExistingColors;

- (void)addColorsFromList:(IJSVGColorList *)sheet;
- (NSSet<NSColor *> *)colors;
- (void)addColor:(NSColor *)color;

@end
