//
//  IJSVGXML.m
//  IJSVG
//
//  Created by Curtis Hard on 13/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import "IJSVGXML.h"
#import "IJSVGParserUtils.h"
#include <limits.h>
#include <stdlib.h>
#include <string.h>

@import libxml2;

#pragma mark - Storage

static bool IJSVGXMLStorageGrow(void** storage, uint32_t* capacity, uint32_t count, size_t size)
{
    if (count <= *capacity) {
        return true;
    }
    uint32_t next = *capacity > UINT32_MAX / 2 ? UINT32_MAX : *capacity * 2;
    if (next < 256) {
        next = 256;
    }
    if (next < count) {
        next = count;
    }
    if (next > SIZE_MAX / size) {
        return false;
    }
    void* memory = realloc(*storage, next * size);
    if (memory == NULL) {
        return false;
    }
    *storage = memory;
    *capacity = next;
    return true;
}

static void IJSVGXMLStorageCompact(void** storage, uint32_t* capacity, uint32_t count, size_t size)
{
    if (count == 0) {
        free(*storage);
        *storage = NULL;
        *capacity = 0;
    } else if (count < *capacity) {
        void* memory = realloc(*storage, (size_t)count * size);
        if (memory != NULL) {
            *storage = memory;
            *capacity = count;
        }
    }
}

static IJSVGXMLByteRange IJSVGXMLDocumentStoreBytes(IJSVGXMLDocument* document, const void* bytes, size_t length)
{
    if (length >= UINT32_MAX - document->byteCount || !IJSVGXMLStorageGrow((void**)&document->bytes, &document->byteCapacity, document->byteCount + (uint32_t)length + 1, 1)) {
        document->failed = true;
        return (IJSVGXMLByteRange) { 0 };
    }
    IJSVGXMLByteRange result = { document->byteCount, (uint32_t)length };
    if (length != 0) {
        memcpy(document->bytes + document->byteCount, bytes, length);
    }
    document->byteCount += (uint32_t)length;
    document->bytes[document->byteCount++] = 0;
    return result;
}

static const char* IJSVGXMLDocumentInternName(IJSVGXMLDocument* document, const xmlChar* name)
{
    if (name == NULL) {
        return NULL;
    }
    if (xmlDictOwns(document->names, name) == 1) {
        return (const char*)name;
    }
    const char* result = (const char*)xmlDictLookup(document->names, name, -1);
    if (result == NULL) {
        document->failed = true;
    }
    return result;
}

static void IJSVGXMLDiscardTrailingWhitespace(IJSVGXMLDocument* document)
{
    if (document->failed || document->current == IJSVGXMLNodeNotFound) {
        return;
    }
    IJSVGXMLNode* parent = document->nodes + document->current;
    uint32_t index = parent->lastChild;
    if (index == IJSVGXMLNodeNotFound || index + 1 != document->nodeCount) {
        return;
    }
    IJSVGXMLNode* node = document->nodes + index;
    if (node->kind != IJSVGXMLNodeKindText && node->kind != IJSVGXMLNodeKindCDATA) {
        return;
    }
    for (uint32_t i = 0; i < node->text.length; i++) {
        char c = document->bytes[node->text.offset + i];
        if (c != ' ' && c != '\t' && c != '\r' && c != '\n') {
            return;
        }
    }
    parent->lastChild = node->previousSibling;
    if (node->previousSibling == IJSVGXMLNodeNotFound) {
        parent->firstChild = IJSVGXMLNodeNotFound;
    } else {
        document->nodes[node->previousSibling].nextSibling = IJSVGXMLNodeNotFound;
    }
    if (node->text.offset + node->text.length + 1 == document->byteCount) {
        document->byteCount = node->text.offset;
    }
    document->nodeCount--;
}

static uint32_t IJSVGXMLDocumentAppendNode(IJSVGXMLDocument* document, IJSVGXMLNodeKind kind)
{
    if (document->failed || document->nodeCount == UINT32_MAX || !IJSVGXMLStorageGrow((void**)&document->nodes, &document->nodeCapacity, document->nodeCount + 1, sizeof(IJSVGXMLNode))) {
        document->failed = true;
        return IJSVGXMLNodeNotFound;
    }
    if (kind != IJSVGXMLNodeKindText) {
        IJSVGXMLDiscardTrailingWhitespace(document);
    }
    uint32_t index = document->nodeCount++;
    document->nodes[index] = (IJSVGXMLNode) { .kind = kind, .parent = document->current, .firstChild = IJSVGXMLNodeNotFound, .lastChild = IJSVGXMLNodeNotFound, .nextSibling = IJSVGXMLNodeNotFound, .previousSibling = IJSVGXMLNodeNotFound };
    if (document->current != IJSVGXMLNodeNotFound) {
        IJSVGXMLNode* parent = &document->nodes[document->current];
        document->nodes[index].previousSibling = parent->lastChild;
        if (parent->lastChild != IJSVGXMLNodeNotFound) {
            document->nodes[parent->lastChild].nextSibling = index;
        } else {
            parent->firstChild = index;
        }
        parent->lastChild = index;
    }
    return index;
}

#pragma mark - Parser callbacks

static void IJSVGXMLParserStartElement(void* context, const xmlChar* local, const xmlChar* prefix, const xmlChar* uri, int namespaceCount, const xmlChar** namespaces, int count, int defaulted, const xmlChar** attributes)
{
    IJSVGXMLDocument* document = context;

    // SAX appends attributes supplied by DTD defaults after explicit attributes.
    // SVG properties come only from the document and its stylesheets.
    count -= defaulted;
    uint32_t index = IJSVGXMLDocumentAppendNode(document, IJSVGXMLNodeKindElement);
    if (index == IJSVGXMLNodeNotFound) {
        return;
    }
    IJSVGXMLNode* node = &document->nodes[index];
    node->name = IJSVGXMLDocumentInternName(document, local);
    node->prefix = IJSVGXMLDocumentInternName(document, prefix);
    node->uri = IJSVGXMLDocumentInternName(document, uri);
    node->firstAttribute = document->attributeCount;
    node->attributeCount = (uint32_t)count;
    if (document->root == IJSVGXMLNodeNotFound) {
        document->root = index;
    }
    document->current = index;
    if ((uint32_t)count > UINT32_MAX - document->attributeCount || !IJSVGXMLStorageGrow((void**)&document->attributes, &document->attributeCapacity, document->attributeCount + (uint32_t)count, sizeof(IJSVGXMLAttribute))) {
        document->failed = true;
        return;
    }
    for (int i = 0; i < count; i++) {
        const xmlChar** input = attributes + i * 5;
        IJSVGXMLAttribute* attribute = &document->attributes[document->attributeCount++];
        *attribute = (IJSVGXMLAttribute) { .name = IJSVGXMLDocumentInternName(document, input[0]), .prefix = IJSVGXMLDocumentInternName(document, input[1]), .uri = IJSVGXMLDocumentInternName(document, input[2]), .value = IJSVGXMLDocumentStoreBytes(document, input[3], input[4] - input[3]) };
        attribute->identifier = input[1] == NULL ? IJSVGNodeAttributeForBytes((const char*)input[0], strlen((const char*)input[0])) : IJSVGNodeAttributeUnknown;
    }
}

static void IJSVGXMLParserEndElement(void* context, const xmlChar* local, const xmlChar* prefix, const xmlChar* uri)
{
    IJSVGXMLDocument* document = context;
    if (document->failed || document->current == IJSVGXMLNodeNotFound) {
        return;
    }
    IJSVGXMLDiscardTrailingWhitespace(document);
    IJSVGXMLNode* node = document->nodes + document->current;
    uint32_t previous = IJSVGXMLNodeNotFound;
    for (uint32_t index = node->firstChild; index != IJSVGXMLNodeNotFound;) {
        IJSVGXMLNode* child = document->nodes + index;
        uint32_t next = child->nextSibling;
        bool blank = child->kind == IJSVGXMLNodeKindText || child->kind == IJSVGXMLNodeKindCDATA;
        for (uint32_t i = 0; blank && i < child->text.length; i++) {
            char c = document->bytes[child->text.offset + i];
            blank = c == ' ' || c == '\t' || c == '\r' || c == '\n';
        }

        // Foundation options:0 strips whitespace only text, including IJSVGXMLParserCDATA
        // and xml:space. Merge SAX chunks before making that decision.
        if (blank) {
            if (previous == IJSVGXMLNodeNotFound) {
                node->firstChild = next;
            } else {
                document->nodes[previous].nextSibling = next;
            }
        } else {
            child->previousSibling = previous;
            previous = index;
        }
        index = next;
    }
    node->lastChild = previous;
    document->current = node->parent;
}

static void IJSVGXMLMarkSelectorText(void* context, int length)
{
    IJSVGXMLDocument* document = context;
    if (!document->failed && document->current != IJSVGXMLNodeNotFound && length > 0) {
        document->nodes[document->current].hasSelectorText = true;
    }
}

static void IJSVGXMLParserCharacters(void* context, const xmlChar* bytes, int length)
{
    IJSVGXMLMarkSelectorText(context, length);
    IJSVGXMLDocument* document = context;
    if (document->failed) {
        return;
    }
    if (document->current != IJSVGXMLNodeNotFound) {
        uint32_t last = document->nodes[document->current].lastChild;
        if (last != IJSVGXMLNodeNotFound && (document->nodes[last].kind == IJSVGXMLNodeKindText || document->nodes[last].kind == IJSVGXMLNodeKindCDATA)) {
            IJSVGXMLNode* node = document->nodes + last;
            if ((uint32_t)length > UINT32_MAX - document->byteCount || !IJSVGXMLStorageGrow((void**)&document->bytes, &document->byteCapacity, document->byteCount + (uint32_t)length, 1)) {
                document->failed = true;
                return;
            }
            memcpy(document->bytes + document->byteCount - 1, bytes, (size_t)length);
            document->byteCount += (uint32_t)length;
            document->bytes[document->byteCount - 1] = 0;
            node->text.length += (uint32_t)length;
            return;
        }
    }
    uint32_t index = IJSVGXMLDocumentAppendNode(document, IJSVGXMLNodeKindText);
    if (index != IJSVGXMLNodeNotFound) {
        document->nodes[index].text = IJSVGXMLDocumentStoreBytes(document, bytes, (size_t)length);
    }
}

static void IJSVGXMLParserCDATA(void* context, const xmlChar* bytes, int length)
{
    IJSVGXMLMarkSelectorText(context, length);
    IJSVGXMLDocument* document = context;
    uint32_t index = IJSVGXMLDocumentAppendNode(document, IJSVGXMLNodeKindCDATA);
    if (index != IJSVGXMLNodeNotFound) {
        document->nodes[index].text = IJSVGXMLDocumentStoreBytes(document, bytes, (size_t)length);
    }
}

static void IJSVGXMLParserIgnoreWhitespace(void* context, const xmlChar* bytes, int length)
{
    // Keep the layout whitespace policy and remember text for CSS :empty.
    IJSVGXMLMarkSelectorText(context, length);
}

static void IJSVGXMLParserComment(void* context, const xmlChar* bytes)
{
    IJSVGXMLDocument* document = context;
    uint32_t index = IJSVGXMLDocumentAppendNode(document, IJSVGXMLNodeKindComment);
    if (index != IJSVGXMLNodeNotFound) {
        document->nodes[index].text = IJSVGXMLDocumentStoreBytes(document, bytes, strlen((const char*)bytes));
    }
}

static void IJSVGXMLParserProcessingInstruction(void* context, const xmlChar* target, const xmlChar* bytes)
{
    IJSVGXMLDocument* document = context;
    uint32_t index = IJSVGXMLDocumentAppendNode(document, IJSVGXMLNodeKindProcessingInstruction);
    if (index != IJSVGXMLNodeNotFound) {
        document->nodes[index].name = IJSVGXMLDocumentInternName(document, target);
        document->nodes[index].text = IJSVGXMLDocumentStoreBytes(document, bytes, bytes == NULL ? 0 : strlen((const char*)bytes));
    }
}

static xmlEntityPtr IJSVGXMLParserGetEntity(void* context, const xmlChar* name)
{
    xmlEntityPtr result = xmlGetPredefinedEntity(name);
    if (result == NULL) {
        ((IJSVGXMLDocument*)context)->failed = true;
    }
    return result;
}

static xmlEntityPtr IJSVGXMLParserGetParameterEntity(void* context, const xmlChar* name)
{
    // Entities defined by a DTD are not supported. Never resolve an external entity.
    ((IJSVGXMLDocument*)context)->failed = true;
    return NULL;
}

#pragma mark - Document lifecycle

void IJSVGXMLDocumentDestroy(IJSVGXMLDocument* document)
{
    if (document == NULL) {
        return;
    }
    for (uint32_t i = 0; i < document->attributeCount; i++) {
        if (document->attributes[i].cachedValue != NULL) {
            CFRelease(document->attributes[i].cachedValue);
        }
    }
    if (document->stringNames != NULL) {
        CFRelease(document->stringNames);
    }
    free(document->nodes);
    free(document->attributes);
    free(document->bytes);
    xmlDictFree(document->names);
    free(document);
}

static IJSVGXMLDocument* IJSVGXMLDocumentParseBytes(const void* bytes, size_t length)
{
    if (length > INT_MAX) {
        return NULL;
    }
    IJSVGXMLDocument* document = calloc(1, sizeof(IJSVGXMLDocument));
    if (document == NULL) {
        return NULL;
    }
    document->root = document->current = IJSVGXMLNodeNotFound;
    xmlSAXHandler handler = { 0 };
    handler.initialized = XML_SAX2_MAGIC;
    handler.startElementNs = IJSVGXMLParserStartElement;
    handler.endElementNs = IJSVGXMLParserEndElement;
    handler.characters = IJSVGXMLParserCharacters;
    handler.ignorableWhitespace = IJSVGXMLParserIgnoreWhitespace;
    handler.cdataBlock = IJSVGXMLParserCDATA;
    handler.comment = IJSVGXMLParserComment;
    handler.processingInstruction = IJSVGXMLParserProcessingInstruction;
    handler.getEntity = IJSVGXMLParserGetEntity;

    // Only standard XML entities are supported. No DTD handlers or external subset loader.
    handler.getParameterEntity = IJSVGXMLParserGetParameterEntity;
    xmlParserCtxtPtr parser = xmlCreatePushParserCtxt(&handler, document, NULL, 0, NULL);
    if (parser == NULL) {
        IJSVGXMLDocumentDestroy(document);
        return NULL;
    }

    // Keep the parser name pool alive with the document to avoid duplicate names.
    if (parser->dict == NULL || xmlDictReference(parser->dict) != 0) {
        xmlFreeParserCtxt(parser);
        IJSVGXMLDocumentDestroy(document);
        return NULL;
    }
    document->names = parser->dict;
    xmlCtxtUseOptions(parser, XML_PARSE_NONET | XML_PARSE_NOENT | XML_PARSE_NOBLANKS | XML_PARSE_NOERROR | XML_PARSE_NOWARNING);

    // Bound parser lookahead for large documents without relaxing XML limits.
    int status = 0;
    size_t offset = 0;
    while (offset < length && status == 0 && !document->failed) {
        int chunk = (int)MIN(length - offset, (size_t)65536);
        status = xmlParseChunk(parser, (const char*)bytes + offset, chunk, 0);
        offset += chunk;
    }
    if (status == 0 && !document->failed) {
        status = xmlParseChunk(parser, NULL, 0, 1);
    }
    bool valid = status == 0 && parser->wellFormed && parser->nsWellFormed && !document->failed && document->root != IJSVGXMLNodeNotFound;
    xmlFreeParserCtxt(parser);
    if (!valid) {
        IJSVGXMLDocumentDestroy(document);
        return NULL;
    }
    IJSVGXMLStorageCompact((void**)&document->nodes, &document->nodeCapacity, document->nodeCount, sizeof(IJSVGXMLNode));
    IJSVGXMLStorageCompact((void**)&document->attributes, &document->attributeCapacity, document->attributeCount, sizeof(IJSVGXMLAttribute));
    IJSVGXMLStorageCompact((void**)&document->bytes, &document->byteCapacity, document->byteCount, 1);
    return document;
}

static IJSVGXMLDocument* IJSVGXMLDocumentFinalize(IJSVGXMLDocument* document)
{
    document->stringNames = CFDictionaryCreateMutable(NULL, 0, NULL, &kCFTypeDictionaryValueCallBacks);
    if (document->stringNames == NULL) {
        IJSVGXMLDocumentDestroy(document);
        return NULL;
    }
    for (uint32_t i = 0; i < document->nodeCount; i++) {
        IJSVGXMLNode* node = document->nodes + i;
        node->document = document;
        node->type = node->kind == IJSVGXMLNodeKindElement ? IJSVGNodeTypeForBytes(node->name, strlen(node->name)) : IJSVGNodeTypeNotFound;
        for (uint32_t child = node->firstChild; child != IJSVGXMLNodeNotFound; child = document->nodes[child].nextSibling) {
            node->childCount++;
        }
    }
    for (uint32_t i = 0; i < document->attributeCount; i++) {
        IJSVGXMLAttribute* attribute = document->attributes + i;
        attribute->document = document;
        if (attribute->prefix != NULL) {
            // Only these qualified attributes are presentation inputs.
            if (strcmp(attribute->prefix, "xml") == 0) {
                if (strcmp(attribute->name, "space") == 0) {
                    attribute->identifier = IJSVGNodeAttributeXMLSpace;
                } else if (strcmp(attribute->name, "lang") == 0) {
                    attribute->identifier = IJSVGNodeAttributeXMLLang;
                }
            } else if (strcmp(attribute->prefix, "xlink") == 0 && strcmp(attribute->name, "href") == 0) {
                attribute->identifier = IJSVGNodeAttributeXLink;
            }
        }
    }
    return document;
}

IJSVGXMLDocument* IJSVGXMLDocumentCreate(const void* bytes, size_t length)
{
    if (bytes == NULL || length == 0) {
        return NULL;
    }
    IJSVGXMLDocument* document = IJSVGXMLDocumentParseBytes(bytes, length);
    if (document == NULL) {
        return NULL;
    }
    return IJSVGXMLDocumentFinalize(document);
}

// Compatibility boundary for the public NSXMLElement gradient APIs. Copy just
// the attributes they consume. Serializing a subtree can lose inherited
// namespace declarations or reject values previously accepted by these APIs.
IJSVGXMLDocument* IJSVGXMLDocumentForElementAttributes(NSXMLElement* element)
{
    IJSVGXMLDocument* document = calloc(1, sizeof(*document));
    if (document == NULL) {
        return NULL;
    }
    document->root = document->current = IJSVGXMLNodeNotFound;
    document->names = xmlDictCreate();
    if (document->names == NULL) {
        IJSVGXMLDocumentDestroy(document);
        return NULL;
    }
    IJSVGXMLParserStartElement(document, (const xmlChar*)"g", NULL, NULL, 0, NULL, 0, 0, NULL);
    NSArray<NSXMLNode*>* attributes = element.attributes;
    if (document->failed || attributes.count > UINT32_MAX || !IJSVGXMLStorageGrow((void**)&document->attributes, &document->attributeCapacity, (uint32_t)attributes.count, sizeof(IJSVGXMLAttribute))) {
        IJSVGXMLDocumentDestroy(document);
        return NULL;
    }
    for (NSXMLNode* input in attributes) {
        const char* prefix = input.prefix.UTF8String;
        if (prefix != NULL && *prefix == 0) {
            prefix = NULL;
        }
        NSString* value = input.stringValue ?: @"";
        NSString* name = input.name;
        IJSVGXMLAttribute* attribute = document->attributes + document->attributeCount++;
        *attribute = (IJSVGXMLAttribute) {
            .name = IJSVGXMLDocumentInternName(document, (const xmlChar*)input.localName.UTF8String),
            .prefix = IJSVGXMLDocumentInternName(document, (const xmlChar*)prefix),
            .uri = IJSVGXMLDocumentInternName(document, (const xmlChar*)input.URI.UTF8String),
            .value = IJSVGXMLDocumentStoreBytes(document, value.UTF8String, [value lengthOfBytesUsingEncoding:NSUTF8StringEncoding]),
            .identifier = IJSVGNodeAttributeForName(name)
        };
    }
    if (document->failed) {
        IJSVGXMLDocumentDestroy(document);
        return NULL;
    }
    document->nodes[document->root].attributeCount = document->attributeCount;
    return IJSVGXMLDocumentFinalize(document);
}

#pragma mark - Node access

IJSVGXMLNode* IJSVGXMLNodeAtIndex(IJSVGXMLDocument* document, uint32_t index)
{
    return document == NULL || index == IJSVGXMLNodeNotFound ? NULL : document->nodes + index;
}

IJSVGXMLNode* IJSVGXMLFirstChild(IJSVGXMLNode* node)
{
    return node == NULL ? NULL : IJSVGXMLNodeAtIndex(node->document, node->firstChild);
}

IJSVGXMLNode* IJSVGXMLNext(IJSVGXMLNode* node)
{
    return node == NULL ? NULL : IJSVGXMLNodeAtIndex(node->document, node->nextSibling);
}

IJSVGXMLNode* IJSVGXMLRoot(IJSVGXMLDocument* document)
{
    return document == NULL ? NULL : IJSVGXMLNodeAtIndex(document, document->root);
}

IJSVGXMLNode* IJSVGXMLParent(IJSVGXMLNode* node)
{
    return node == NULL ? NULL : IJSVGXMLNodeAtIndex(node->document, node->parent);
}

IJSVGNodeType IJSVGXMLType(IJSVGXMLNode* node)
{
    return node == NULL ? IJSVGNodeTypeNotFound : node->type;
}

NSUInteger IJSVGXMLChildCount(IJSVGXMLNode* node)
{
    return node == NULL ? 0 : node->childCount;
}

NSXMLNodeKind IJSVGXMLKind(IJSVGXMLNode* node)
{
    if (node == NULL) {
        return NSXMLInvalidKind;
    }
    switch (node->kind) {
        case IJSVGXMLNodeKindElement:
            return NSXMLElementKind;
        case IJSVGXMLNodeKindText:
        case IJSVGXMLNodeKindCDATA:
            return NSXMLTextKind;
        case IJSVGXMLNodeKindComment:
            return NSXMLCommentKind;
        case IJSVGXMLNodeKindProcessingInstruction:
            return NSXMLProcessingInstructionKind;
    }
}

static NSString* IJSVGXMLDocumentInternString(IJSVGXMLDocument* document, const char* name)
{
    if (name == NULL) {
        return nil;
    }
    CFStringRef string = CFDictionaryGetValue(document->stringNames, name);
    if (string == NULL) {
        string = CFStringCreateWithCString(NULL, name, kCFStringEncodingUTF8);
        if (string == NULL) {
            return nil;
        }
        CFDictionarySetValue(document->stringNames, name, string);
        CFRelease(string);
    }
    return (__bridge NSString*)string;
}

NSString* IJSVGXMLLocalName(IJSVGXMLNode* node)
{
    return node == NULL ? nil : IJSVGXMLDocumentInternString(node->document, node->name);
}

NSString* IJSVGXMLText(IJSVGXMLNode* node)
{
    if (node == NULL) {
        return nil;
    }
    if (node->kind != IJSVGXMLNodeKindElement) {
        return [[NSString alloc] initWithBytes:node->document->bytes + node->text.offset length:node->text.length encoding:NSUTF8StringEncoding];
    }
    NSMutableString* result = [NSMutableString string];
    for (IJSVGXMLNode* child = IJSVGXMLFirstChild(node); child != NULL; child = IJSVGXMLNext(child)) {
        [result appendString:IJSVGXMLText(child) ?: @""];
    }
    return result;
}

#pragma mark - Attribute access

IJSVGXMLAttribute* IJSVGXMLAttributeAt(IJSVGXMLAttributeList list, NSUInteger index)
{
    return index >= list.count ? NULL : list.overlay != NULL ? list.overlay[index]
                                                             : list.first + index;
}

IJSVGXMLAttribute* IJSVGXMLFirstAttribute(IJSVGXMLAttributeList* list)
{
    list->cursor = 0;
    return IJSVGXMLAttributeAt(*list, list->cursor);
}

IJSVGXMLAttribute* IJSVGXMLNextAttribute(IJSVGXMLAttributeList* list)
{
    return IJSVGXMLAttributeAt(*list, ++list->cursor);
}

IJSVGXMLAttribute* IJSVGXMLAttributeForIdentifier(IJSVGXMLNode* node, IJSVGNodeAttribute identifier)
{
    if (identifier < 0 || identifier >= IJSVGNodeAttributeCount) {
        return NULL;
    }
    IJSVGXMLAttributeList attributes = IJSVGXMLAttributes(node);
    for (IJSVGXMLAttribute* attribute = IJSVGXMLFirstAttribute(&attributes); attribute != NULL; attribute = IJSVGXMLNextAttribute(&attributes)) {
        if (attribute->identifier == identifier) {
            return attribute;
        }
    }
    return NULL;
}

IJSVGXMLAttributeList IJSVGXMLAttributes(IJSVGXMLNode* node)
{
    if (node == NULL || node->attributeCount == 0) {
        return (IJSVGXMLAttributeList) { 0 };
    }
    return (IJSVGXMLAttributeList) { node->document->attributes + node->firstAttribute, NULL, node->attributeCount };
}

IJSVGXMLAttribute* IJSVGXMLAttributeNamed(IJSVGXMLNode* node, NSString* name)
{
    const char* bytes = name.UTF8String;
    if (bytes == NULL) {
        return NULL;
    }
    const char* colon = strchr(bytes, ':');
    IJSVGXMLAttributeList nodeAttributeIterator = IJSVGXMLAttributes(node);
    for (IJSVGXMLAttribute* attribute = IJSVGXMLFirstAttribute(&nodeAttributeIterator); attribute != NULL; attribute = IJSVGXMLNextAttribute(&nodeAttributeIterator)) {
        if (colon == NULL) {
            if (attribute->prefix == NULL && strcmp(attribute->name, bytes) == 0) {
                return attribute;
            }
        } else if (attribute->prefix != NULL && strlen(attribute->prefix) == (size_t)(colon - bytes) && memcmp(attribute->prefix, bytes, colon - bytes) == 0 && strcmp(attribute->name, colon + 1) == 0) {
            return attribute;
        }
    }
    return NULL;
}

NSString* IJSVGXMLAttributeLocalName(IJSVGXMLAttribute* attribute)
{
    return attribute == NULL ? nil : IJSVGXMLDocumentInternString(attribute->document, attribute->name);
}

NSString* IJSVGXMLAttributeURI(IJSVGXMLAttribute* attribute)
{
    return attribute == NULL ? nil : IJSVGXMLDocumentInternString(attribute->document, attribute->uri);
}

const char* IJSVGXMLAttributeBytes(IJSVGXMLAttribute* attribute)
{
    return attribute == NULL ? NULL : attribute->document->bytes + attribute->value.offset;
}

NSString* IJSVGXMLAttributeValue(IJSVGXMLAttribute* attribute)
{
    if (attribute == NULL) {
        return nil;
    }
    if (attribute->cachedValue == NULL) {
        attribute->cachedValue = CFStringCreateWithBytes(NULL, (const UInt8*)IJSVGXMLAttributeBytes(attribute), attribute->value.length, kCFStringEncodingUTF8, false);
    }
    return (__bridge NSString*)attribute->cachedValue;
}
