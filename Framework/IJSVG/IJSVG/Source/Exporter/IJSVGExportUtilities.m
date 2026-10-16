//
//  IJSVGExportUtilities.m
//  IJSVG
//
//  Created by Curtis Hard on 16/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVGByteHash.h>
#import <IJSVGExportNodePrivate.h>
#import <IJSVGExportUtilities.h>

typedef struct {
    xmlAttrPtr attribute;
    double rank;
} IJSVGExportSortedAttribute;

static int IJSVGExportCompareAttributes(const void* left, const void* right)
{
    const IJSVGExportSortedAttribute* a = left;
    const IJSVGExportSortedAttribute* b = right;
    if (a->rank < b->rank) {
        return -1;
    }
    if (a->rank > b->rank) {
        return 1;
    }
    const xmlChar* aName = a->attribute->name;
    const xmlChar* bName = b->attribute->name;
    BOOL ascii = YES;
    for (const xmlChar* cursor = aName; *cursor != 0; cursor++) {
        if (*cursor >= 128) {
            ascii = NO;
            break;
        }
    }
    for (const xmlChar* cursor = bName; ascii && *cursor != 0; cursor++) {
        if (*cursor >= 128) {
            ascii = NO;
            break;
        }
    }
    if (ascii) {
        return xmlStrcmp(aName, bName);
    }
    return (int)[[NSString stringWithUTF8String:(const char*)aName] compare:[NSString stringWithUTF8String:(const char*)bName]];
}

void IJSVGExportSortAttributes(IJSVGExportElement* element, double (*rank)(const char*, NSUInteger))
{
    NSUInteger count = 0;
    for (xmlAttrPtr attribute = element->_node->properties; attribute != NULL; attribute = attribute->next) {
        count++;
    }
    if (count < 2) {
        return;
    }

    // Keep wrappers alive while their owning sibling links are reordered.
    __attribute__((objc_precise_lifetime)) NSArray* retainedAttributes = element.attributes;
    IJSVGExportSortedAttribute stack[32];
    IJSVGExportSortedAttribute* sorted = count <= 32 ? stack : calloc(count, sizeof(*sorted));
    IJSVGExportCheckAllocation(sorted);
    NSUInteger index = 0;
    for (xmlAttrPtr attribute = element->_node->properties; attribute != NULL; attribute = attribute->next) {
        sorted[index++] = (IJSVGExportSortedAttribute) { attribute, rank((const char*)attribute->name, count) };
    }
    qsort(sorted, count, sizeof(*sorted), IJSVGExportCompareAttributes);
    element->_node->properties = sorted[0].attribute;
    element->_firstAttribute = IJSVGExportWrapper((xmlNodePtr)sorted[0].attribute);
    for (index = 0; index < count; index++) {
        xmlAttrPtr attribute = sorted[index].attribute;
        attribute->prev = index == 0 ? NULL : sorted[index - 1].attribute;
        attribute->next = index + 1 == count ? NULL : sorted[index + 1].attribute;
        IJSVGExportWrapper((xmlNodePtr)attribute)->_nextOwned = IJSVGExportWrapper((xmlNodePtr)attribute->next);
    }
    if (sorted != stack) {
        free(sorted);
    }
    (void)retainedAttributes;
}

static xmlNodePtr IJSVGExportNextNode(xmlNodePtr node, xmlNodePtr root)
{
    if (node->children != NULL) {
        return node->children;
    }
    while (node != root && node->next == NULL) {
        node = node->parent;
    }
    return node == root ? NULL : node->next;
}

void IJSVGExportSortTreeAttributes(IJSVGExportElement* element, double (*rank)(const char*, NSUInteger))
{
    xmlNodePtr root = element->_node;
    for (xmlNodePtr node = root; node != NULL; node = IJSVGExportNextNode(node, root)) {
        if (node->type == XML_ELEMENT_NODE) {
            IJSVGExportSortAttributes((IJSVGExportElement*)IJSVGExportWrapper(node), rank);
        }
    }
}

NSArray<IJSVGExportElement*>* IJSVGExportElementsNamed(IJSVGExportDocument* document, const char* name, const char* excludedAttribute)
{
    NSMutableArray* result = [[NSMutableArray alloc] init];
    xmlNodePtr root = document.rootElement->_node;
    for (xmlNodePtr node = root; node != NULL; node = IJSVGExportNextNode(node, root)) {
        if (node->type == XML_ELEMENT_NODE && xmlStrEqual(node->name, (const xmlChar*)name)
            && (excludedAttribute == NULL || xmlHasProp(node, (const xmlChar*)excludedAttribute) == NULL)) {
            [result addObject:IJSVGExportWrapper(node)];
        }
    }
    return result;
}

void IJSVGExportUnwrapElement(IJSVGExportElement* element)
{
    IJSVGExportElement* parent = (IJSVGExportElement*)element.parent;
    if (parent == nil) {
        return;
    }
    if (element->_childCount == 0) {
        [element detach];
        return;
    }

    // Splice the existing sibling chain instead of repeatedly inserting by
    // index. Keep the wrapper alive until both ownership chains are repaired.
    __attribute__((objc_precise_lifetime)) IJSVGExportElement* retainedElement = element;
    xmlNodePtr node = element->_node;
    xmlNodePtr first = node->children;
    xmlNodePtr last = node->last;
    xmlNodePtr previous = node->prev;
    xmlNodePtr next = node->next;
    for (xmlNodePtr child = first; child != NULL; child = child->next) {
        child->parent = parent->_node;
    }
    first->prev = previous;
    last->next = next;
    if (previous != NULL) {
        previous->next = first;
    } else {
        parent->_node->children = first;
    }
    if (next != NULL) {
        next->prev = last;
    } else {
        parent->_node->last = last;
    }
    IJSVGExportWrapper(last)->_nextOwned = element->_nextOwned;
    if (previous != NULL) {
        IJSVGExportWrapper(previous)->_nextOwned = element->_firstChild;
    } else {
        parent->_firstChild = element->_firstChild;
    }
    parent->_childCount += element->_childCount - 1;
    element->_firstChild = nil;
    element->_nextOwned = nil;
    element->_childCount = 0;
    node->children = node->last = node->prev = node->next = node->parent = NULL;
    if (node->doc != NULL) {
        xmlSetTreeDoc(node, NULL);
    }
    (void)retainedElement;
}

typedef struct {
    __unsafe_unretained IJSVGExportElement* first;
    __unsafe_unretained NSMutableArray* duplicates;
} IJSVGExportPathEntry;

static CFHashCode IJSVGExportPathHash(const void* key)
{
    return IJSVGHashBytes(key, strlen(key));
}

static Boolean IJSVGExportPathEqual(const void* left, const void* right)
{
    return xmlStrEqual(left, right);
}

NSArray<NSArray<IJSVGExportElement*>*>* IJSVGExportDuplicatePaths(IJSVGExportDocument* document)
{
    NSArray<IJSVGExportElement*>* paths = IJSVGExportElementsNamed(document, "path", "vector-effect");
    NSMutableArray* groups = [[NSMutableArray alloc] init];
    if (paths.count < 2) {
        return groups;
    }
    IJSVGExportPathEntry* entries = calloc(paths.count, sizeof(*entries));
    IJSVGExportCheckAllocation(entries);
    const CFDictionaryKeyCallBacks callbacks = { 0, NULL, NULL, NULL, IJSVGExportPathEqual, IJSVGExportPathHash };
    CFMutableDictionaryRef table = CFDictionaryCreateMutable(NULL, paths.count, &callbacks, NULL);
    IJSVGExportCheckAllocation(table);
    NSUInteger count = 0;

    // Keys borrow the XML buffers only during this read-only traversal.
    for (IJSVGExportElement* path in paths) {
        xmlAttrPtr attribute = xmlHasProp(path->_node, BAD_CAST "d");
        if (attribute == NULL) {
            continue;
        }
        const xmlChar* bytes = attribute->children == NULL ? BAD_CAST "" : attribute->children->content;
        IJSVGExportPathEntry* entry = (void*)CFDictionaryGetValue(table, bytes);
        if (entry == NULL) {
            entry = &entries[count++];
            entry->first = path;
            CFDictionarySetValue(table, bytes, entry);
        } else {
            if (entry->duplicates == nil) {
                NSMutableArray* duplicates = [[NSMutableArray alloc] initWithObjects:entry->first, nil];
                [groups addObject:duplicates];
                entry->duplicates = duplicates;
            }
            [entry->duplicates addObject:path];
        }
    }
    CFRelease(table);
    free(entries);
    return groups;
}

NSArray<IJSVGExportNode*>* IJSVGExportAttributesNamed(IJSVGExportDocument* document, const char* const* names, NSUInteger count)
{
    NSMutableArray* result = [[NSMutableArray alloc] init];
    xmlNodePtr root = document.rootElement->_node;
    for (xmlNodePtr node = root; node != NULL; node = IJSVGExportNextNode(node, root)) {
        if (node->type != XML_ELEMENT_NODE) {
            continue;
        }
        for (xmlAttrPtr attribute = node->properties; attribute != NULL; attribute = attribute->next) {
            for (NSUInteger index = 0; index < count; index++) {
                if (xmlStrEqual(attribute->name, (const xmlChar*)names[index])) {
                    [result addObject:IJSVGExportWrapper((xmlNodePtr)attribute)];
                    break;
                }
            }
        }
    }
    return result;
}

static BOOL IJSVGExportHiddenStyle(const xmlChar* style)
{
    static const char needle[] = "display:none";
    NSUInteger matched = 0;
    for (const xmlChar* cursor = style; cursor != NULL && *cursor != 0; cursor++) {
        unsigned char character = *cursor;
        if (character == ' ' || character == '\t' || character == '\n' || character == '\r') {
            continue;
        }
        if (character >= 'A' && character <= 'Z') {
            character += 'a' - 'A';
        }
        if (character == needle[matched]) {
            if (++matched == sizeof(needle) - 1) {
                return YES;
            }
        } else {
            matched = character == needle[0] ? 1 : 0;
        }
    }
    return NO;
}

NSArray<IJSVGExportElement*>* IJSVGExportHiddenElements(IJSVGExportDocument* document)
{
    NSMutableArray* result = [[NSMutableArray alloc] init];
    xmlNodePtr root = document.rootElement->_node;
    for (xmlNodePtr node = root; node != NULL; node = IJSVGExportNextNode(node, root)) {
        if (node->type != XML_ELEMENT_NODE) {
            continue;
        }
        for (xmlAttrPtr attribute = node->properties; attribute != NULL; attribute = attribute->next) {
            xmlNodePtr text = attribute->children;
            if (text == NULL || text->content == NULL) {
                continue;
            }
            if ((xmlStrEqual(attribute->name, BAD_CAST "display") && xmlStrEqual(text->content, BAD_CAST "none"))
                || (xmlStrEqual(attribute->name, BAD_CAST "style") && IJSVGExportHiddenStyle(text->content))) {
                [result addObject:IJSVGExportWrapper(node)];
                break;
            }
        }
    }
    return result;
}

// Export trees store qualified names and namespace declarations as literal
// attributes. Resolve their URI without creating NSStrings or splitting names.
static const xmlChar* IJSVGExportNodeURI(xmlNodePtr node)
{
    const xmlChar* colon = node->name == NULL ? NULL : (const xmlChar*)strchr((const char*)node->name, ':');
    size_t length = colon == NULL ? 0 : (size_t)(colon - node->name);
    if (colon != NULL && length == 3 && memcmp(node->name, "xml", 3) == 0) {
        return BAD_CAST "http://www.w3.org/XML/1998/namespace";
    }
    if (colon == NULL && node->type == XML_ATTRIBUTE_NODE) {
        return NULL;
    }
    for (xmlNodePtr ancestor = node; ancestor != NULL; ancestor = ancestor->parent) {
        if (ancestor->type != XML_ELEMENT_NODE) {
            continue;
        }
        for (xmlAttrPtr attribute = ancestor->properties; attribute != NULL; attribute = attribute->next) {
            const char* name = (const char*)attribute->name;
            BOOL matches = colon == NULL ? strcmp(name, "xmlns") == 0 : strncmp(name, "xmlns:", 6) == 0 && strlen(name + 6) == length && memcmp(name + 6, node->name, length) == 0;
            if (matches) {
                return attribute->children == NULL ? BAD_CAST "" : attribute->children->content;
            }
        }
    }
    return NULL;
}

static NSUInteger IJSVGExportHashBytes(NSUInteger hash, const xmlChar* bytes)
{
    size_t length = bytes == NULL ? 0 : strlen((const char*)bytes);
    return (hash ^ IJSVGHashBytes(bytes, length)) * 1099511628211ULL;
}

static NSUInteger IJSVGExportHashNodes(NSUInteger hash, xmlNodePtr node)
{
    for (; node != NULL; node = node->next) {
        hash = (hash ^ node->type) * 1099511628211ULL;
        hash = IJSVGExportHashBytes(hash, node->name);
        if (node->type == XML_ELEMENT_NODE) {
            hash = IJSVGExportHashNodes(hash, (xmlNodePtr)node->properties);
        }
        if (node->type == XML_ELEMENT_NODE || node->type == XML_ATTRIBUTE_NODE) {
            hash = IJSVGExportHashNodes(hash, node->children);
        } else {
            hash = IJSVGExportHashBytes(hash, node->content);
        }
        hash = (hash ^ 255) * 1099511628211ULL;
    }
    return hash;
}

static BOOL IJSVGExportEqualNodes(xmlNodePtr left, xmlNodePtr right)
{
    for (; left != NULL && right != NULL; left = left->next, right = right->next) {
        if (left->type != right->type || !xmlStrEqual(left->name, right->name)
            || !xmlStrEqual(IJSVGExportNodeURI(left), IJSVGExportNodeURI(right))) {
            return NO;
        }
        if (left->type == XML_ELEMENT_NODE && !IJSVGExportEqualNodes((xmlNodePtr)left->properties, (xmlNodePtr)right->properties)) {
            return NO;
        }
        if (left->type == XML_ELEMENT_NODE || left->type == XML_ATTRIBUTE_NODE) {
            if (!IJSVGExportEqualNodes(left->children, right->children)) {
                return NO;
            }
        } else if (!xmlStrEqual(left->content, right->content)) {
            return NO;
        }
    }
    return left == right;
}

NSUInteger IJSVGExportChildrenHash(IJSVGExportElement* element)
{
    // Namespace differences can collide; equality resolves them before sharing.
    return IJSVGExportHashNodes(14695981039346656037ULL, element->_node->children);
}

BOOL IJSVGExportChildrenEqual(IJSVGExportElement* left, IJSVGExportElement* right)
{
    return IJSVGExportEqualNodes(left->_node->children, right->_node->children);
}

typedef struct {
    const xmlChar* name;
    const xmlChar* value;
    BOOL inheritable;
    xmlNodePtr inheritedFrom;
} IJSVGExportDefaultAttribute;

static void IJSVGExportRemoveDefaults(xmlNodePtr node, xmlNodePtr root, IJSVGExportDefaultAttribute* rules, NSUInteger count)
{
    if (node->type != XML_ELEMENT_NODE) {
        return;
    }
    BOOL hasIdentifier = xmlHasProp(node, BAD_CAST "id") != NULL;
    for (xmlAttrPtr attribute = node->properties; attribute != NULL;) {
        xmlAttrPtr next = attribute->next;
        for (NSUInteger index = 0; index < count; index++) {
            IJSVGExportDefaultAttribute* rule = &rules[index];
            if (!xmlStrEqual(attribute->name, rule->name)) {
                continue;
            }
            xmlNodePtr text = attribute->children;
            const xmlChar* value = text == NULL ? BAD_CAST "" : text->content;
            if (!hasIdentifier && rule->inheritedFrom == NULL && (text == NULL || text->next == NULL) && xmlStrEqual(value, rule->value)) {
                [IJSVGExportWrapper((xmlNodePtr)attribute) detach];
            } else if (node != root && rule->inheritable && rule->inheritedFrom == NULL) {
                rule->inheritedFrom = node;
            }
            break;
        }
        attribute = next;
    }
    for (xmlNodePtr child = node->children; child != NULL; child = child->next) {
        IJSVGExportRemoveDefaults(child, root, rules, count);
    }

    // Presence, not the inherited value, controls this cleanup rule. Remember
    // the first owning ancestor and restore it without per-element dictionaries.
    for (NSUInteger index = 0; index < count; index++) {
        if (rules[index].inheritedFrom == node) {
            rules[index].inheritedFrom = NULL;
        }
    }
}

void IJSVGExportRemoveDefaultAttributes(IJSVGExportElement* root, NSDictionary<NSString*, NSString*>* defaults, NSSet<NSString*>* inheritableNames)
{
    NSUInteger count = defaults.count;
    IJSVGExportDefaultAttribute stack[32];
    IJSVGExportDefaultAttribute* rules = count <= 32 ? stack : calloc(count, sizeof(*rules));
    IJSVGExportCheckAllocation(rules);
    NSUInteger index = 0;
    for (NSString* name in defaults) {
        rules[index++] = (IJSVGExportDefaultAttribute) {
            .name = (const xmlChar*)name.UTF8String,
            .value = (const xmlChar*)defaults[name].UTF8String,
            .inheritable = [inheritableNames containsObject:name],
            .inheritedFrom = NULL,
        };
    }
    IJSVGExportRemoveDefaults(root->_node, root->_node, rules, count);
    if (rules != stack) {
        free(rules);
    }
}

NSSet<NSString*>* IJSVGExportReferencedIdentifiers(IJSVGExportDocument* document, NSString* (*parseURL)(const char*, NSUInteger))
{
    static const char* names[] = { "href", "xlink:href", "fill", "stroke", "clip-path", "mask", "filter", "marker", "style" };
    NSMutableSet<NSString*>* identifiers = [[NSMutableSet alloc] init];
    xmlNodePtr root = document.rootElement->_node;
    for (xmlNodePtr node = root; node != NULL; node = IJSVGExportNextNode(node, root)) {
        if (node->type != XML_ELEMENT_NODE) {
            continue;
        }
        for (xmlAttrPtr attribute = node->properties; attribute != NULL; attribute = attribute->next) {
            for (NSUInteger index = 0; index < sizeof(names) / sizeof(*names); index++) {
                if (!xmlStrEqual(attribute->name, (const xmlChar*)names[index])) {
                    continue;
                }

                // Export attributes have a single literal text child. Only
                // materialize an NSString when the value contains a reference.
                const char* bytes = attribute->children == NULL ? NULL : (const char*)attribute->children->content;
                if (bytes == NULL || *bytes == 0) {
                    break;
                }
                NSUInteger length = strlen(bytes);
                NSString* identifier = nil;
                if (index < 2) {
                    if (bytes[0] == '#' && length > 1) {
                        identifier = [[NSString alloc] initWithBytes:bytes + 1 length:length - 1 encoding:NSUTF8StringEncoding];
                    }
                } else if (bytes[0] != '#') {
                    identifier = parseURL(bytes, length);
                }
                if (identifier.length != 0) {
                    [identifiers addObject:identifier];
                }
                break;
            }
        }
    }
    return identifiers;
}

typedef struct {
    const xmlChar* name;
    const xmlChar* nextValue;
    const xmlChar* bestValue;
    NSUInteger length;
} IJSVGExportAttributeRun;

NSDictionary<NSString*, NSString*>* IJSVGExportSharedAttributes(IJSVGExportElement* parent, NSArray<NSString*>* names, NSRange* range)
{
    *range = NSMakeRange(NSNotFound, 0);
    if (parent->_childCount < 2 || names.count == 0) {
        return @ {};
    }
    NSUInteger count = names.count;
    IJSVGExportAttributeRun stack[32] = { 0 };
    IJSVGExportAttributeRun* runs = count <= 32 ? stack : calloc(count, sizeof(*runs));
    IJSVGExportCheckAllocation(runs);
    for (NSUInteger index = 0; index < count; index++) {
        runs[index].name = (const xmlChar*)names[index].UTF8String;
    }
    NSUInteger position = parent->_childCount;
    NSUInteger bestCount = 0;

    // One running length per inheritable name replaces per-child dictionaries
    // and boxed run ends. Reverse traversal also makes earliest-run ties cheap.
    for (xmlNodePtr node = parent->_node->last; node != NULL; node = node->prev) {
        position--;
        NSUInteger longest = 0;
        NSUInteger sharedCount = 0;
        for (NSUInteger index = 0; index < count; index++) {
            IJSVGExportAttributeRun* run = &runs[index];
            xmlAttrPtr attribute = node->type == XML_ELEMENT_NODE ? xmlHasProp(node, run->name) : NULL;
            const xmlChar* value = attribute == NULL ? NULL : attribute->children == NULL ? BAD_CAST ""
                                                                                          : attribute->children->content;
            run->length = value == NULL ? 0 : xmlStrEqual(value, run->nextValue) ? run->length + 1
                                                                                 : 1;
            run->nextValue = value;
            if (run->length > longest) {
                longest = run->length;
                sharedCount = 1;
            } else if (run->length == longest && longest != 0) {
                sharedCount++;
            }
        }
        if (longest >= 2 && (longest > range->length || (longest == range->length && sharedCount >= bestCount))) {
            *range = NSMakeRange(position, longest);
            bestCount = sharedCount;
            for (NSUInteger index = 0; index < count; index++) {
                runs[index].bestValue = runs[index].length == longest ? runs[index].nextValue : NULL;
            }
        }
    }
    NSMutableDictionary* attributes = [[NSMutableDictionary alloc] initWithCapacity:bestCount];
    for (NSUInteger index = 0; index < count; index++) {
        if (runs[index].bestValue != NULL) {
            attributes[names[index]] = [NSString stringWithUTF8String:(const char*)runs[index].bestValue];
        }
    }
    if (runs != stack) {
        free(runs);
    }
    return attributes;
}
