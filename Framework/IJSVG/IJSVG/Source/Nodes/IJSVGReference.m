//
//  IJSVGReference.m
//  IJSVG
//
//  Created by Curtis Hard on 13/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import "IJSVGXML.h"
#import <IJSVG/IJSVGReference.h>
#import <IJSVGParserUtils.h>

@implementation IJSVGReference

- (instancetype)initWithHref:(NSString*)href
{
    if ((self = [super init]) != nil) {
        _href = href.copy;
        if ([_href hasPrefix:@"#"] && _href.length > 1) {
            _fragmentIdentifier = [_href substringFromIndex:1];
        }
    }
    return self;
}

- (id)copyWithZone:(NSZone*)zone
{
    return self;
}

@end

#pragma mark - Parsing

void IJSVGReadReferenceAttribute(IJSVGXMLAttribute* node, IJSVGReferenceAttributes* attributes)
{
    if (attributes->href != NULL || strcmp(node->name, "href") != 0) {
        return;
    }
    if (node->prefix == NULL) {
        attributes->href = node;
        return;
    }
    if (attributes->namespacedHref == NULL && node->uri != NULL && strcmp(node->uri, "http://www.w3.org/1999/xlink") == 0) {
        attributes->namespacedHref = node;
    }
    if (strcmp(node->prefix, "xlink") == 0) {
        attributes->legacyHref = node;
    }
}

IJSVGReference* IJSVGEmptyReference(void)
{
    static IJSVGReference* emptyReference;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        emptyReference = [[IJSVGReference alloc] initWithHref:nil];
    });
    return emptyReference;
}
