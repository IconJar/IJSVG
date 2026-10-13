//
//  IJSVGInheritedElement.m
//  IJSVG
//
//  Created by Curtis Hard on 13/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import "IJSVGInheritedElement.h"
#include <string.h>

@implementation IJSVGInheritedElement

- (instancetype)initWithElement:(IJSVGXMLNode*)element fallback:(IJSVGInheritedElement*)fallback
{
    if ((self = [super init]) != nil) {
        _element = element;
        _hasReference = fallback != nil;
        _childrenElement = IJSVGXMLChildCount(element) != 0 || fallback == nil ? element : fallback.childrenElement;
        _attributes = IJSVGXMLAttributes(element);
        if (fallback != nil) {
            IJSVGXMLAttributeList inherited = fallback.attributes;
            NSUInteger capacity = _attributes.count + inherited.count;
            IJSVGXMLAttribute** entries = capacity == 0 ? NULL : calloc(capacity, sizeof(*entries));
            if (capacity != 0 && entries == NULL) {
                return nil;
            }
            NSUInteger count = 0;
            IJSVGXMLAttributeList ownAttributeIterator = _attributes;
            for (IJSVGXMLAttribute* attribute = IJSVGXMLFirstAttribute(&ownAttributeIterator); attribute != NULL; attribute = IJSVGXMLNextAttribute(&ownAttributeIterator)) {
                entries[count++] = attribute;
            }
            IJSVGXMLAttributeList inheritedAttributeIterator = inherited;
            for (IJSVGXMLAttribute* attribute = IJSVGXMLFirstAttribute(&inheritedAttributeIterator); attribute != NULL; attribute = IJSVGXMLNextAttribute(&inheritedAttributeIterator)) {
                BOOL found = NO;
                for (NSUInteger i = 0; i < count; i++) {
                    IJSVGXMLAttribute* own = entries[i];
                    if (strcmp(own->name, attribute->name) == 0 && ((own->prefix == NULL && attribute->prefix == NULL) || (own->prefix != NULL && attribute->prefix != NULL && strcmp(own->prefix, attribute->prefix) == 0))) {
                        found = YES;
                        break;
                    }
                }
                if (!found) {
                    entries[count++] = attribute;
                }
            }
            _attributes = (IJSVGXMLAttributeList) { NULL, entries, count };
        }
    }
    return self;
}
- (void)dealloc
{
    free(_attributes.overlay);
}
@end
