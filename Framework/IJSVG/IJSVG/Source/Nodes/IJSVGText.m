//
//  IJSVGText.m
//  IJSVG
//
//  Created on 06/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGText.h>
#import <IJSVG/IJSVGColorNode.h>
#import <IJSVG/IJSVGStyle.h>

@implementation IJSVGTextAttributeValue

@end

@implementation IJSVGText

+ (IJSVGBitFlags*)allowedAttributes
{
    IJSVGBitFlags* storage = [super allowedAttributes];
    [storage setBit:IJSVGNodeAttributeX];
    [storage setBit:IJSVGNodeAttributeY];
    [storage setBit:IJSVGNodeAttributeDX];
    [storage setBit:IJSVGNodeAttributeDY];
    for(IJSVGNodeAttribute attribute = IJSVGNodeAttributeRotate;
        attribute <= IJSVGNodeAttributePathLength; attribute++) {
        [storage setBit:(int)attribute];
    }
    return storage;
}

- (instancetype)init
{
    if((self = [super init])) {
        _textContent = @[];
        _positioning = @{};
    }
    return self;
}

- (id)copyWithZone:(NSZone*)zone
{
    IJSVGText* copy = [super copyWithZone:zone];
    NSMutableArray* content = [NSMutableArray arrayWithCapacity:self.textContent.count];
    for(id item in self.textContent) {
        if([item isKindOfClass:IJSVGText.class]) {
            // Point mixed text content at the copied children.
            NSUInteger index = [self.children indexOfObjectIdenticalTo:item];
            if(index != NSNotFound) {
                [content addObject:copy.children[index]];
            }
        } else {
            [content addObject:[item copy]];
        }
    }
    copy.textContent = content;
    copy.positioning = self.positioning;
    copy.textPath = self.textPath.copy;
    copy.isTextPath = self.isTextPath;
    return copy;
}

// Identifies direct text runs without counting child span containers.
- (BOOL)hasTextContent
{
    for(id item in self.textContent) {
        if([item isKindOfClass:NSString.class] && [item length] != 0) {
            return YES;
        }
    }
    return NO;
}

// Text strokes use the same visibility rules as path strokes.
- (void)computeTraits
{
    [super computeTraits];
    [self removeTraits:IJSVGNodeTraitStroked];
    if(!self.hasTextContent || self.stroke == nil) {
        return;
    }
    if([self.stroke isKindOfClass:IJSVGColorNode.class] &&
       ((IJSVGColorNode*)self.stroke).isNoneOrTransparent) {
        return;
    }
    [self addTraits:IJSVGNodeTraitStroked];
}

// Includes direct text paints alongside colors collected from child spans.
- (IJSVGTraitedColorStorage*)colorsWithStyle:(IJSVGStyle*)style
{
    IJSVGTraitedColorStorage* storage = [super colorsWithStyle:style];
    if(!self.shouldRender || !self.hasTextContent) {
        return storage;
    }
    IJSVGNode* fill = self.fill;
    if(fill == nil) {
        fill = [[IJSVGColorNode alloc] initWithColor:style.fillColor ?: NSColor.blackColor];
    }
    [storage unionColorStorage:[fill colorsWithStyle:style
                                     matchingTraits:IJSVGColorUsageTraitFill]];
    if([self matchesTraits:IJSVGNodeTraitStroked]) {
        [storage unionColorStorage:[self.stroke colorsWithStyle:style
                                                matchingTraits:IJSVGColorUsageTraitStroke]];
    }
    return storage;
}

- (BOOL)containsRelativeUnits
{
    // Text layout depends on viewport percentages and inherited font metrics.
    return YES;
}

@end
