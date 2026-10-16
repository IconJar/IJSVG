//
//  IJSVGExportElement.m
//  IJSVG
//
//  Created by Curtis Hard on 16/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGExportElement.h>
#import <IJSVGExportNodePrivate.h>

@implementation IJSVGExportElement

- (instancetype)init
{
    return [self initWithName:@"element"];
}

- (instancetype)initWithName:(NSString*)name
{
    return [super initWithXMLNode:xmlNewNode(NULL, (const xmlChar*)name.UTF8String)];
}

- (NSArray<IJSVGExportNode*>*)attributes
{
    NSMutableArray* attributes = [[NSMutableArray alloc] init];
    for (xmlAttrPtr attribute = _node->properties; attribute != NULL; attribute = attribute->next) {
        [attributes addObject:IJSVGExportWrapper((xmlNodePtr)attribute)];
    }
    return attributes;
}

- (IJSVGExportNode*)attributeForName:(NSString*)name
{
    xmlAttrPtr attribute = xmlHasProp(_node, (const xmlChar*)name.UTF8String);
    return attribute == NULL ? nil : (__bridge IJSVGExportNode*)attribute->_private;
}

- (void)addAttribute:(IJSVGExportNode*)attribute
{
    if (attribute->_node->type != XML_ATTRIBUTE_NODE) {
        [NSException raise:NSInvalidArgumentException format:@"Expected an export XML attribute"];
    }
    if (attribute->_node->parent == _node) {
        return;
    }
    [attribute unlink];
    xmlAttrPtr previous = NULL;
    xmlAttrPtr existing = NULL;
    for (xmlAttrPtr current = _node->properties; current != NULL; current = current->next) {
        if (xmlStrEqual(current->name, attribute->_node->name)) {
            existing = current;
        }
        previous = current;
    }
    if (existing != NULL) {
        if (previous == existing) {
            previous = existing->prev;
        }
        [IJSVGExportWrapper((xmlNodePtr)existing) detach];
    }
    xmlAttrPtr node = (xmlAttrPtr)attribute->_node;
    node->parent = _node;
    node->prev = previous;
    node->next = NULL;
    if (node->doc != _node->doc) {
        xmlSetTreeDoc((xmlNodePtr)node, _node->doc);
    }
    if (previous != NULL) {
        previous->next = node;
        IJSVGExportWrapper((xmlNodePtr)previous)->_nextOwned = attribute;
    } else {
        _node->properties = node;
        _firstAttribute = attribute;
    }
}

- (void)removeAttributeForName:(NSString*)name
{
    [[self attributeForName:name] detach];
}

- (void)setAttributeWithName:(NSString*)name stringValue:(NSString*)value
{
    const xmlChar* bytes = (const xmlChar*)name.UTF8String;
    xmlAttrPtr existing = xmlHasProp(_node, bytes);
    if (existing != NULL) {
        IJSVGExportWrapper((xmlNodePtr)existing).stringValue = value;
        return;
    }

    // libxml appends the new literal property and sets its document directly.
    // Mirror that link in wrapper ownership without a second attribute lookup.
    xmlAttrPtr node = xmlNewProp(_node, bytes, (const xmlChar*)value.UTF8String);
    IJSVGExportNode* attribute = [[IJSVGExportNode alloc] initWithXMLNode:(xmlNodePtr)node];
    if (node->prev != NULL) {
        IJSVGExportWrapper((xmlNodePtr)node->prev)->_nextOwned = attribute;
    } else {
        _firstAttribute = attribute;
    }
}

- (void)setAttributesAsDictionary:(NSDictionary<NSString*, NSString*>*)attributes
{
    for (NSString* name in attributes) {
        [self setAttributeWithName:name stringValue:attributes[name]];
    }
}

@end
