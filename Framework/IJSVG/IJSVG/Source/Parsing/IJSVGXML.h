//
//  IJSVGXML.h
//  IJSVG
//
//  Created by Curtis Hard on 13/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#pragma once
#import <Foundation/Foundation.h>
#import <IJSVG/IJSVGNode.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

struct _xmlDict;
typedef struct IJSVGXMLDocument IJSVGXMLDocument;

// Document owned storage. Node and attribute pointers remain stable after parsing.

static const uint32_t IJSVGXMLNodeNotFound = UINT32_MAX;

typedef struct {
    uint32_t offset;
    uint32_t length;
} IJSVGXMLByteRange;

typedef struct IJSVGXMLAttribute {
    IJSVGXMLDocument* document;
    CFStringRef cachedValue;
    const char* name;
    const char* prefix;
    const char* uri;
    IJSVGXMLByteRange value;
    IJSVGNodeAttribute identifier;
} IJSVGXMLAttribute;

typedef struct IJSVGXMLNode {
    IJSVGXMLDocument* document;
    uint32_t childCount;
    IJSVGNodeType type : 8;

    // Preserve CSS :empty information even when layout whitespace is discarded.
    bool hasSelectorText : 1;
    bool preservesTextWhitespace : 1;
    const char* name;
    const char* prefix;
    const char* uri;
    uint32_t parent;
    uint32_t firstChild;
    uint32_t lastChild;
    uint32_t nextSibling;
    uint32_t previousSibling;
    uint32_t firstAttribute;
    uint32_t attributeCount;
    IJSVGXMLNodeKind kind;
    IJSVGXMLByteRange text;
} IJSVGXMLNode;

struct IJSVGXMLDocument {
    CFMutableDictionaryRef stringNames;
    IJSVGXMLNode* nodes;
    IJSVGXMLAttribute* attributes;
    char* bytes;
    uint32_t nodeCount;
    uint32_t nodeCapacity;
    uint32_t attributeCount;
    uint32_t attributeCapacity;
    uint32_t byteCount;
    uint32_t byteCapacity;
    uint32_t root;
    uint32_t current;
    struct _xmlDict* names;
    bool failed;
};

// Lists borrow contiguous attributes or an inherited pointer overlay.
typedef struct {
    IJSVGXMLAttribute* first;
    IJSVGXMLAttribute** overlay;
    NSUInteger count;
    NSUInteger cursor;
} IJSVGXMLAttributeList;

// Document lifecycle. Attribute lists and byte ranges borrow document storage.
// DOCTYPE declarations do not load a DTD. Custom entity references are rejected.
IJSVGXMLDocument* IJSVGXMLDocumentCreate(const void* bytes, size_t length);
void IJSVGXMLDocumentDestroy(IJSVGXMLDocument* document);

// Node traversal and content.
IJSVGXMLNode* IJSVGXMLNodeAtIndex(IJSVGXMLDocument* document, uint32_t index);

IJSVGXMLNode* IJSVGXMLRoot(IJSVGXMLDocument* document);
IJSVGXMLNode* IJSVGXMLParent(IJSVGXMLNode* node);

IJSVGXMLNode* IJSVGXMLFirstChild(IJSVGXMLNode* node);

IJSVGXMLNode* IJSVGXMLNext(IJSVGXMLNode* node);

IJSVGNodeType IJSVGXMLType(IJSVGXMLNode* node);
NSUInteger IJSVGXMLChildCount(IJSVGXMLNode* node);
IJSVGXMLNodeKind IJSVGXMLKind(IJSVGXMLNode* node);
NSString* IJSVGXMLLocalName(IJSVGXMLNode* node);
NSString* IJSVGXMLText(IJSVGXMLNode* node);

// Attribute lookup and values. Strings are created lazily when requested.
IJSVGXMLAttributeList IJSVGXMLAttributes(IJSVGXMLNode* node);

IJSVGXMLAttribute* IJSVGXMLAttributeAt(IJSVGXMLAttributeList list, NSUInteger index);

// Each loop keeps its own list cursor. Attribute storage remains borrowed.
IJSVGXMLAttribute* IJSVGXMLFirstAttribute(IJSVGXMLAttributeList* list);

IJSVGXMLAttribute* IJSVGXMLNextAttribute(IJSVGXMLAttributeList* list);

IJSVGXMLAttribute* IJSVGXMLAttributeForIdentifier(IJSVGXMLNode* node, IJSVGNodeAttribute identifier);

IJSVGXMLAttribute* IJSVGXMLAttributeNamed(IJSVGXMLNode* node, NSString* name);
NSString* IJSVGXMLAttributeLocalName(IJSVGXMLAttribute* attribute);
NSString* IJSVGXMLAttributeURI(IJSVGXMLAttribute* attribute);
NSString* IJSVGXMLAttributeValue(IJSVGXMLAttribute* attribute);
const char* IJSVGXMLAttributeBytes(IJSVGXMLAttribute* attribute);

// These collections use opaque pointer keys: no Objective C message may be sent
// to a node address. The document owns the keys for the entire parse.
#define IJSVGXMLKey(node) ((__bridge id)(void*)(node))
