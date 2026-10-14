//
//  IJSVGTraitedColorStorage.h
//  IJSVG
//
//  Created by Curtis Hard on 07/07/2019.
//  Copyright © 2019 Curtis Hard. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <IJSVG/IJSVGColor.h>
#import <IJSVG/IJSVGTraitedColor.h>

NS_ASSUME_NONNULL_BEGIN

@interface IJSVGReplacementColor : IJSVGTraitedColor

@property (nonatomic, assign, nullable) CGColorRef replacementColor;

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
- (void)replaceColor:(CGColorRef)replaceColor withColor:(CGColorRef)withColor traits:(IJSVGColorUsageTraits)traits;
- (void)unionColorStorage:(IJSVGTraitedColorStorage* _Nullable)colorList;
- (CGColorRef _Nullable)colorForColor:(CGColorRef)color matchingTraits:(IJSVGColorUsageTraits)traits;
- (BOOL)matchesReplacementTraits:(IJSVGColorUsageTraits)traits;
- (BOOL)matchesTraits:(IJSVGColorUsageTraits)traits;

@end

NS_ASSUME_NONNULL_END
