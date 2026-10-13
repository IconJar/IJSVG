//
//  IJSVGReference.m
//  IJSVG
//
//  Created by Curtis Hard on 13/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

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

void IJSVGReadReferenceAttribute(NSXMLNode* node, NSString* name, IJSVGReferenceAttributes* attributes)
{
    if (attributes->href != nil) {
        return;
    }
    if ([name isEqualToString:@"href"]) {
        attributes->href = node;
        return;
    }
    if (![node.localName isEqualToString:@"href"]) {
        return;
    }
    if (attributes->namespacedHref == nil && [node.URI isEqualToString:@"http://www.w3.org/1999/xlink"]) {
        attributes->namespacedHref = node;
    }
    if ([name isEqualToString:@"xlink:href"]) {
        attributes->legacyHref = node;
    }
}

IJSVGReference* IJSVGEmptyReference(void)
{
    static IJSVGReference* emptyReference;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ emptyReference = [[IJSVGReference alloc] initWithHref:nil]; });
    return emptyReference;
}
