//
//  IJSVGExportNode.m
//  IJSVG
//
//  Created by Curtis Hard on 16/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGExportNode.h>
#import <IJSVGExportNodePrivate.h>

@implementation IJSVGExportNode

- (instancetype)initWithXMLNode:(xmlNodePtr)node
{
    if ((self = [super init])) {
        IJSVGExportCheckAllocation(node);
        _node = node;
        _node->_private = (__bridge void*)self;
    }
    return self;
}

- (instancetype)initWithKind:(IJSVGXMLNodeKind)kind
{
    xmlNodePtr node = NULL;
    switch (kind) {
        case IJSVGXMLNodeKindElement:
            return (id)[[IJSVGExportElement alloc] initWithName:@"element"];
        case IJSVGXMLNodeKindAttribute:
            node = (xmlNodePtr)xmlNewProp(NULL, BAD_CAST "attribute", NULL);
            break;
        case IJSVGXMLNodeKindComment:
            node = xmlNewComment(BAD_CAST "");
            break;
        case IJSVGXMLNodeKindText:
            node = xmlNewText(BAD_CAST "");
            break;
        default:
            [NSException raise:NSInvalidArgumentException format:@"Unsupported export XML node kind"];
    }
    return [self initWithXMLNode:node];
}

+ (instancetype)attributeWithName:(NSString*)name stringValue:(NSString*)value
{
    // xmlNewProp accepts literal values and builds its text directly.
    return [[self alloc] initWithXMLNode:(xmlNodePtr)xmlNewProp(NULL, (const xmlChar*)name.UTF8String, (const xmlChar*)value.UTF8String)];
}

- (void)dealloc
{
    // Ownership follows the C sibling links, without parallel arrays or weak
    // references. Unlink iteratively so a wide tree never recurses through its
    // siblings, and externally retained nodes remain valid after teardown.
    if (_node != NULL && _node->type == XML_ELEMENT_NODE) {
        IJSVGExportElement* element = (IJSVGExportElement*)self;
        while (element->_firstChild != nil) {
            IJSVGExportNode* child = element->_firstChild;
            element->_firstChild = child->_nextOwned;
            child->_nextOwned = nil;
            xmlUnlinkNode(child->_node);
            if (child->_node->doc != NULL) {
                xmlSetTreeDoc(child->_node, NULL);
            }
        }
        while (element->_firstAttribute != nil) {
            IJSVGExportNode* attribute = element->_firstAttribute;
            element->_firstAttribute = attribute->_nextOwned;
            attribute->_nextOwned = nil;
            xmlUnlinkNode(attribute->_node);
            if (attribute->_node->doc != NULL) {
                xmlSetTreeDoc(attribute->_node, NULL);
            }
        }
    }
    if (_node != NULL) {
        xmlUnlinkNode(_node);
        _node->_private = NULL;
        if (_node->type == XML_ATTRIBUTE_NODE) {
            xmlFreeProp((xmlAttrPtr)_node);
        } else {
            xmlFreeNode(_node);
        }
    }
}

- (IJSVGXMLNodeKind)kind
{
    switch (_node->type) {
        case XML_ELEMENT_NODE:
            return IJSVGXMLNodeKindElement;
        case XML_ATTRIBUTE_NODE:
            return IJSVGXMLNodeKindAttribute;
        case XML_COMMENT_NODE:
            return IJSVGXMLNodeKindComment;
        case XML_TEXT_NODE:
            return IJSVGXMLNodeKindText;
        default:
            return IJSVGXMLNodeKindInvalid;
    }
}

- (NSString*)name
{
    return _node->name == NULL ? nil : [NSString stringWithUTF8String:(const char*)_node->name];
}

- (void)setName:(NSString*)name
{
    xmlNodeSetName(_node, (const xmlChar*)name.UTF8String);
}

- (NSString*)prefix
{
    NSString* name = self.name;
    NSRange colon = [name rangeOfString:@":"];
    return colon.location == NSNotFound ? nil : [name substringToIndex:colon.location];
}

- (NSString*)localName
{
    return [self.name componentsSeparatedByString:@":"].lastObject;
}

- (NSString*)URI
{
    NSString* prefix = self.prefix;
    if ([prefix isEqualToString:@"xml"]) {
        return @"http://www.w3.org/XML/1998/namespace";
    }
    if (self.kind == IJSVGXMLNodeKindAttribute && prefix == nil) {
        return nil;
    }
    NSString* declaration = prefix == nil ? @"xmlns" : [@"xmlns:" stringByAppendingString:prefix];
    for (IJSVGExportNode* node = self; node != nil; node = node.parent) {
        if (node.kind == IJSVGXMLNodeKindElement) {
            NSString* uri = [(IJSVGExportElement*)node attributeForName:declaration].stringValue;
            if (uri != nil) {
                return uri;
            }
        }
    }
    return nil;
}

- (NSString*)stringValue
{
    // Export attributes contain one literal text node. Read it directly
    // instead of allocating a temporary libxml buffer for every lookup.
    if (_node->type == XML_ATTRIBUTE_NODE) {
        xmlNodePtr text = _node->children;
        if (text == NULL) {
            return @"";
        }
        if (text->type == XML_TEXT_NODE && text->next == NULL) {
            return text->content == NULL ? @"" : [NSString stringWithUTF8String:(const char*)text->content];
        }
    } else if (_node->type == XML_TEXT_NODE || _node->type == XML_COMMENT_NODE) {
        return _node->content == NULL ? @"" : [NSString stringWithUTF8String:(const char*)_node->content];
    }
    xmlChar* content = xmlNodeGetContent(_node);
    NSString* value = content == NULL ? @"" : [NSString stringWithUTF8String:(const char*)content];
    xmlFree(content);
    return value;
}

- (void)setStringValue:(NSString*)value
{
    if (self.kind == IJSVGXMLNodeKindElement || self.kind == IJSVGXMLNodeKindAttribute) {
        self.children = nil;
        xmlNodeSetContent(_node, NULL);

        // xmlNodeSetContent interprets entity references on elements/attributes.
        // A text node accepts literal text. libxml escapes it during output.
        if (value.length != 0) {
            if (self.kind == IJSVGXMLNodeKindElement) {
                IJSVGExportNode* child = [[IJSVGExportNode alloc] initWithKind:IJSVGXMLNodeKindText];
                child.stringValue = value;
                [self addChild:child];
            } else {
                xmlNodePtr text = xmlNewText((const xmlChar*)value.UTF8String);
                IJSVGExportCheckAllocation(text);
                xmlAddChild(_node, text);
            }
        }
    } else {
        xmlNodeSetContent(_node, (const xmlChar*)value.UTF8String);
    }
}

- (IJSVGExportNode*)parent
{
    return IJSVGExportWrapper(_node->parent);
}

- (IJSVGExportNode*)nextSibling
{
    return IJSVGExportWrapper(_node->next);
}

- (NSUInteger)index
{
    NSUInteger index = 0;
    for (xmlNodePtr node = _node->prev; node != NULL; node = node->prev) {
        index++;
    }
    return index;
}

- (NSArray<IJSVGExportNode*>*)children
{
    if (_node->type != XML_ELEMENT_NODE) {
        return @[];
    }
    NSMutableArray* children = [[NSMutableArray alloc] initWithCapacity:((IJSVGExportElement*)self)->_childCount];
    for (xmlNodePtr child = _node->children; child != NULL; child = child->next) {
        [children addObject:IJSVGExportWrapper(child)];
    }
    return children;
}

- (NSUInteger)childCount
{
    return _node->type == XML_ELEMENT_NODE ? ((IJSVGExportElement*)self)->_childCount : 0;
}

- (void)setChildren:(NSArray<IJSVGExportNode*>*)children
{
    if (_node->type != XML_ELEMENT_NODE) {
        return;
    }
    NSArray* replacement = children.copy;
    IJSVGExportElement* element = (IJSVGExportElement*)self;
    while (element->_firstChild != nil) {
        [element->_firstChild detach];
    }
    for (IJSVGExportNode* child in replacement) {
        [self addChild:child];
    }
}

- (void)unlink
{
    if (_node->parent == NULL) {
        return;
    }

    // Removing the reference held by the owner must not destroy self during the operation.
    __attribute__((objc_precise_lifetime)) IJSVGExportNode* retainedSelf = self;
    IJSVGExportElement* parent = (IJSVGExportElement*)self.parent;
    IJSVGExportNode* previous = IJSVGExportWrapper(_node->prev);
    if (parent != nil) {
        if (previous != nil) {
            previous->_nextOwned = _nextOwned;
        } else if (_node->type == XML_ATTRIBUTE_NODE) {
            parent->_firstAttribute = _nextOwned;
        } else {
            parent->_firstChild = _nextOwned;
        }
        if (_node->type != XML_ATTRIBUTE_NODE) {
            parent->_childCount--;
        }
    }
    _nextOwned = nil;
    xmlUnlinkNode(_node);
    (void)retainedSelf;
}

- (void)detach
{
    __attribute__((objc_precise_lifetime)) IJSVGExportNode* retainedSelf = self;
    [self unlink];
    if (_node->doc != NULL) {
        xmlSetTreeDoc(_node, NULL);
    }
    (void)retainedSelf;
}

- (void)addChild:(IJSVGExportNode*)child
{
    [self insertChild:child atIndex:self.childCount];
}

- (void)insertChild:(IJSVGExportNode*)child atIndex:(NSUInteger)index
{
    if (child == nil) {
        return;
    }
    if (_node->type != XML_ELEMENT_NODE || child->_node->type == XML_ATTRIBUTE_NODE) {
        [NSException raise:NSInvalidArgumentException format:@"Invalid export XML child"];
    }
    for (xmlNodePtr ancestor = _node; ancestor != NULL; ancestor = ancestor->parent) {
        if (ancestor == child->_node) {
            [NSException raise:NSInvalidArgumentException format:@"An XML node cannot contain itself"];
        }
    }
    IJSVGExportElement* element = (IJSVGExportElement*)self;
    if (index > element->_childCount) {
        [NSException raise:NSRangeException format:@"Invalid export XML child index"];
    }
    if (child->_node->parent == _node && child.index < index) {
        index--;
    }
    [child unlink];
    xmlNodePtr next = NULL;
    if (index != element->_childCount) {
        next = _node->children;
        for (NSUInteger position = 0; position < index; position++) {
            next = next->next;
        }
    }
    xmlNodePtr previous = next == NULL ? _node->last : next->prev;

    // Link explicitly: xmlAddChild merges adjacent text nodes and frees one.
    child->_node->parent = _node;
    child->_node->prev = previous;
    child->_node->next = next;
    if (previous != NULL) {
        previous->next = child->_node;
    } else {
        _node->children = child->_node;
    }
    if (next != NULL) {
        next->prev = child->_node;
    } else {
        _node->last = child->_node;
    }
    if (child->_node->doc != _node->doc) {
        xmlSetTreeDoc(child->_node, _node->doc);
    }
    child->_nextOwned = IJSVGExportWrapper(next);
    if (previous != NULL) {
        IJSVGExportWrapper(previous)->_nextOwned = child;
    } else {
        element->_firstChild = child;
    }
    element->_childCount++;
}

- (void)removeChildAtIndex:(NSUInteger)index
{
    if (index >= self.childCount) {
        [NSException raise:NSRangeException format:@"Invalid export XML child index"];
    }
    xmlNodePtr node = _node->children;
    for (NSUInteger position = 0; position < index; position++) {
        node = node->next;
    }
    [IJSVGExportWrapper(node) detach];
}

- (void)replaceChildAtIndex:(NSUInteger)index withNode:(IJSVGExportNode*)child
{
    if (index >= self.childCount) {
        [NSException raise:NSRangeException format:@"Invalid export XML child index"];
    }
    xmlNodePtr node = _node->children;
    for (NSUInteger position = 0; position < index; position++) {
        node = node->next;
    }
    [IJSVGExportWrapper(node) replaceWithNode:child];
}

- (void)replaceWithNode:(IJSVGExportNode*)child
{
    if (child == self || child == nil) {
        return;
    }
    IJSVGExportElement* parent = (IJSVGExportElement*)self.parent;
    if (parent == nil || _node->type == XML_ATTRIBUTE_NODE || child->_node->type == XML_ATTRIBUTE_NODE) {
        [NSException raise:NSInvalidArgumentException format:@"Invalid export XML replacement"];
    }
    for (xmlNodePtr ancestor = parent->_node; ancestor != NULL; ancestor = ancestor->parent) {
        if (ancestor == child->_node) {
            [NSException raise:NSInvalidArgumentException format:@"An XML node cannot contain itself"];
        }
    }

    // Hold the replaced wrapper while updating the owning sibling chain.
    __attribute__((objc_precise_lifetime)) IJSVGExportNode* retainedSelf = self;
    [child unlink];
    IJSVGExportNode* previous = IJSVGExportWrapper(_node->prev);
    child->_nextOwned = _nextOwned;
    xmlReplaceNode(_node, child->_node);
    if (previous != nil) {
        previous->_nextOwned = child;
    } else {
        parent->_firstChild = child;
    }
    _nextOwned = nil;
    if (_node->doc != NULL) {
        xmlSetTreeDoc(_node, NULL);
    }
    (void)retainedSelf;
}

@end
