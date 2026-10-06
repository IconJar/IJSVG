//
//  IJSVGText.m
//  IJSVG
//
//  Created on 06/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGText.h>

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

- (BOOL)containsRelativeUnits
{
    // Text layout depends on viewport percentages and inherited font metrics.
    return YES;
}

@end
