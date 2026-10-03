//
//  IJSVGTraitedColorStorage.h
//  IJSVG
//
//  Created by Curtis Hard on 07/07/2019.
//  Copyright © 2019 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGColor.h>
#import <IJSVG/IJSVGTraitedColor.h>
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface IJSVGReplacementColor : IJSVGTraitedColor

@property (nonatomic, strong, nullable) NSColor* replacementColor;

@end

@interface IJSVGTraitedColorStorage : NSObject {

@private
    NSMutableArray<IJSVGReplacementColor*>* _replacementColors;
    NSMutableSet<IJSVGTraitedColor*>* _colors;
    IJSVGColorUsageTraits _traits;
    IJSVGColorUsageTraits _replacementTraits;
}

@property (nonatomic, readonly) NSUInteger count;
@property (nonatomic, readonly) NSSet<IJSVGTraitedColor*>* colors;
@property (nonatomic, readonly) NSUInteger replacedColorCount;

- (void)addTraits:(IJSVGColorUsageTraits)traits;
- (void)addColor:(IJSVGTraitedColor*)color;
- (void)replaceColor:(NSColor*)replaceColor
           withColor:(NSColor*)withColor
              traits:(IJSVGColorUsageTraits)traits;
- (void)unionColorStorage:(IJSVGTraitedColorStorage* _Nullable)colorList;
- (NSColor* _Nullable)colorForColor:(NSColor*)color
           matchingTraits:(IJSVGColorUsageTraits)traits;
- (BOOL)matchesReplacementTraits:(IJSVGColorUsageTraits)traits;
- (BOOL)matchesTraits:(IJSVGColorUsageTraits)traits;

@end

NS_ASSUME_NONNULL_END
