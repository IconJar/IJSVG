//
//  IJSVGInheritedElement.m
//  IJSVG
//
//  Created by Curtis Hard on 13/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVGInheritedElement.h>

@implementation IJSVGInheritedElement

- (instancetype)initWithElement:(NSXMLElement*)element fallback:(IJSVGInheritedElement*)fallback
{
    if ((self = [super init]) != nil) {
        _element = element;
        _hasReference = fallback != nil;
        _childrenElement = element.childCount != 0 || fallback == nil ? element : fallback.childrenElement;
        if (fallback == nil) {
            _attributes = element.attributes.copy;
        } else {
            NSMutableArray<NSXMLNode*>* attributes = [element.attributes mutableCopy] ?: [[NSMutableArray alloc] init];
            NSMutableSet<NSString*>* names = [[NSMutableSet alloc] init];
            for (NSXMLNode* attribute in attributes) {
                [names addObject:attribute.name];
            }
            for (NSXMLNode* attribute in fallback.attributes) {
                if (![names containsObject:attribute.name]) {
                    [attributes addObject:attribute];
                }
            }
            _attributes = attributes.copy;
        }
    }
    return self;
}

@end
