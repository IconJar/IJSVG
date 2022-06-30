//
//  IJSVGColorList.h
//  IconJar
//
//  Created by Curtis Hard on 07/07/2019.
//  Copyright © 2019 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGColor.h>
#import <IJSVG/IJSVGTraitedColor.h>
#import <Foundation/Foundation.h>

@interface IJSVGReplacementColor : IJSVGTraitedColor

@property (nonatomic, strong) NSColor* replacementColor;

@end

@interface IJSVGTraitedColorStorage : NSObject {

@private
    NSMutableArray<IJSVGReplacementColor*>* _replacementColors;
    NSMutableSet<IJSVGTraitedColor*>* _colors;
}

@property (nonatomic, readonly) NSUInteger count;
@property (nonatomic, readonly) NSSet<IJSVGTraitedColor*>* colors;
@property (nonatomic, readonly) NSUInteger replacedColorCount;

- (void)addTraits:(IJSVGColorUsageTraits)traits;
- (void)addColor:(IJSVGTraitedColor*)color;
- (void)replaceColor:(NSColor*)replaceColor
           withColor:(NSColor*)withColor
              traits:(IJSVGColorUsageTraits)traits;
- (void)mergeWithColors:(IJSVGTraitedColorStorage*)colorList;
- (NSColor*)colorForColor:(NSColor*)color
           matchingTraits:(IJSVGColorUsageTraits)traits;

@end
