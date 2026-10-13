//
//  CXMLCheck.m
//  IJSVGExample
//
//  Created by Curtis Hard on 13/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

// Differential check of the production C XML representation against the former
// Foundation input tree. The source occupies pages made inaccessible after parse.
#import <Foundation/Foundation.h>
#import <IJSVGXML.h>
#import <sys/mman.h>
#import <unistd.h>

static BOOL EqualStrings(NSString* left, NSString* right)
{
    return left == right || [left isEqualToString:right];
}

static BOOL EqualNode(NSXMLNode* expected, IJSVGXMLNode* actual)
{
    if (actual == NULL || expected.kind != IJSVGXMLKind(actual) || !EqualStrings(expected.localName, IJSVGXMLLocalName(actual)) || !EqualStrings(expected.stringValue, IJSVGXMLText(actual))) {
        return NO;
    }
    if (expected.kind == NSXMLElementKind) {
        NSArray<NSXMLNode*>* attributes = ((NSXMLElement*)expected).attributes;
        if (attributes.count != actual->attributeCount) {
            return NO;
        }
        for (NSXMLNode* attribute in attributes) {
            IJSVGXMLAttribute* found = IJSVGXMLAttributeNamed(actual, attribute.name);
            if (found == NULL || !EqualStrings(attribute.stringValue, IJSVGXMLAttributeValue(found)) || !EqualStrings(attribute.URI, IJSVGXMLAttributeURI(found))) {
                return NO;
            }
        }
    }
    if (expected.childCount != IJSVGXMLChildCount(actual)) {
        return NO;
    }
    IJSVGXMLNode* child = IJSVGXMLFirstChild(actual);
    for (NSXMLNode* expectedChild in expected.children) {
        if (!EqualNode(expectedChild, child)) {
            return NO;
        }
        child = IJSVGXMLNext(child);
    }
    return child == NULL;
}

int main(int argc, const char** argv)
{
    @autoreleasepool {
        if (argc != 2) {
            return 2;
        }
        NSArray* fixtures = [NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfFile:@(argv[1])] options:0 error:nil];
        NSMutableArray* results = [NSMutableArray array];
        for (NSDictionary* fixture in fixtures) {
            @autoreleasepool {
                NSData* data = [fixture[@"svg"] dataUsingEncoding:NSUTF8StringEncoding];
                size_t page = (size_t)sysconf(_SC_PAGESIZE);
                size_t readable = ((data.length + page - 1) / page) * page;
                char* allocation = mmap(NULL, readable + page, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANON, -1, 0);
                if (allocation == MAP_FAILED || mprotect(allocation + readable, page, PROT_NONE) != 0) {
                    return 3;
                }
                char* source = allocation + readable - data.length;
                memcpy(source, data.bytes, data.length);
                IJSVGXMLDocument* document = IJSVGXMLDocumentCreate(source, data.length);
                if (mprotect(allocation, readable, PROT_NONE) != 0) {
                    return 4;
                }
                NSError* error = nil;
                NSXMLDocument* expected = [[NSXMLDocument alloc] initWithData:data options:0 error:&error];
                if (expected == nil || error != nil || !EqualNode(expected.rootElement, IJSVGXMLRoot(document))) {
                    fprintf(stderr, "XML mismatch: %s\n", [fixture[@"id"] UTF8String]);
                    return 5;
                }
                [results addObject:@{@"id" : fixture[@"id"],
                    @"nodes" : @(document->nodeCount),
                    @"attributes" : @(document->attributeCount),
                    @"compatibilityExpansion" : @(document->usedCompatibilityExpansion),
                    @"matched" : @YES}];
                IJSVGXMLDocumentDestroy(document);
                munmap(allocation, readable + page);
            }
        }
        NSData* output = [NSJSONSerialization dataWithJSONObject:results options:NSJSONWritingPrettyPrinted error:nil];
        fwrite(output.bytes, 1, output.length, stdout);
        putchar('\n');
    }
    return 0;
}
