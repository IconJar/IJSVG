//
//  IJSVGTextLayoutUtils.h
//  IJSVG
//
//  Created on 06/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGText.h>
#import <CoreText/CoreText.h>

@interface IJSVGTextComputedStyle: NSObject

@property (nonatomic, copy) NSDictionary<NSString*, IJSVGTextAttributeValue*>* values;
@property (nonatomic, strong) id font;
@property (nonatomic, assign) CGFloat size;
@property (nonatomic, assign) CGFloat xHeight;
@property (nonatomic, assign) CGFloat baseline;
@property (nonatomic, assign) CGFloat resolvedBaseline;
@property (nonatomic, assign) BOOL hasResolvedBaseline;
@property (nonatomic, assign) CGFloat lineHeight;
@property (nonatomic, assign) BOOL vertical;
@property (nonatomic, assign) BOOL rtl;
@property (nonatomic, assign) BOOL nativeSpacing;
@property (nonatomic, assign) CGFloat fontScale;
@property (nonatomic, assign) CGFloat wordSpacing;
@property (nonatomic, assign) IJSVGTextKeyword orientation;
@property (nonatomic, assign) IJSVGTextDecoration decorations;

@end

// Nodes and computed styles remain owned by the layout during processing.
typedef struct {
    __unsafe_unretained IJSVGText* owner;
    __unsafe_unretained IJSVGText* pathNode;
    __unsafe_unretained IJSVGTextComputedStyle* style;
    NSUInteger utf16;
    NSUInteger cluster;
    CGPoint position;
    CGFloat advance;
    CGFloat x;
    CGFloat y;
    CGFloat dx;
    CGFloat dy;
    CGFloat rotation;
    CGFloat scale;
    unichar firstCodeUnit;
    unichar secondCodeUnit;
    BOOL middle;
    BOOL chunk;
    BOOL hidden;
} IJSVGTextCharacter;

typedef struct {
    CTFontRef font;
    NSUInteger character;
    CGPoint offset;
    CGGlyph glyph;
} IJSVGTextGlyph;

IJSVGTextKeyword IJSVGTextRenderingForNode(IJSVGNode* node);

CGFloat IJSVGTextLength(IJSVGTextAttributeValue* value, CGFloat fontSize,
                        CGFloat xHeight, CGFloat percentage);

void IJSVGTextAppendCharacter(IJSVGTextCharacter** characters,
                              NSUInteger* count, NSUInteger* capacity,
                              const IJSVGTextCharacter* character);

CGFloat IJSVGTextBaselineOffset(IJSVGTextComputedStyle* style);

CGFloat IJSVGTextFontSize(IJSVGTextAttributeValue* size, CGFloat parentSize,
                          CGFloat parentXHeight, CGFloat defaultFontSize);
CGFloat IJSVGTextFontXHeight(CTFontRef font, CGFloat fontSize, CGFloat scale);

BOOL IJSVGTextCanReuseFont(IJSVGTextComputedStyle* parent,
                           NSDictionary<NSString*, IJSVGTextAttributeValue*>* values,
                           CGFloat size);

NSUInteger IJSVGTextBuildSpacingUnits(IJSVGTextCharacter* characters,
                                      NSRange range, IJSVGText* node,
                                      NSUInteger* spacingUnits);
