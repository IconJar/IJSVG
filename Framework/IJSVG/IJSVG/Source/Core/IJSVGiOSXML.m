//
//  IJSVGiOSXML.m
//  IconJar
//
//  Created by Curtis Hard on 30/08/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import "IJSVGiOSXML.h"

#if TARGET_OS_IOS
#import <libxml/parser.h>
#import <libxml/tree.h>

static NSString* IJSVGiOSXMLStringFromXMLChar(const xmlChar* chars)
{
    if(chars == NULL) {
        return nil;
    }
    return [NSString stringWithUTF8String:(const char*)chars];
}

static NSString* IJSVGiOSXMLQualifiedName(NSString* localName, NSString* prefix)
{
    if(prefix.length == 0 || localName.length == 0) {
        return localName;
    }
    return [NSString stringWithFormat:@"%@:%@", prefix, localName];
}

static NSString* IJSVGiOSXMLEscapeString(NSString* string, BOOL isAttribute)
{
    if(string.length == 0) {
        return @"";
    }
    NSMutableString* output = [string mutableCopy];
    [output replaceOccurrencesOfString:@"&"
                            withString:@"&amp;"
                               options:0
                                 range:NSMakeRange(0, output.length)];
    [output replaceOccurrencesOfString:@"<"
                            withString:@"&lt;"
                               options:0
                                 range:NSMakeRange(0, output.length)];
    [output replaceOccurrencesOfString:@">"
                            withString:@"&gt;"
                               options:0
                                 range:NSMakeRange(0, output.length)];
    if(isAttribute == YES) {
        [output replaceOccurrencesOfString:@"\""
                                withString:@"&quot;"
                                   options:0
                                     range:NSMakeRange(0, output.length)];
    }
    return output;
}

@interface IJSVGiOSXMLElement ()

@property (nonatomic, strong) NSMutableArray<NSXMLNode*>* mutableAttributes;
@property (nonatomic, strong) NSMutableArray<NSXMLNode*>* mutableChildren;

@end

@implementation IJSVGiOSXMLNode

- (instancetype)init
{
    return [self initWithKind:NSXMLInvalidKind];
}

- (instancetype)initWithKind:(NSXMLNodeKind)kind
{
    if((self = [super init]) != nil) {
        _kind = kind;
    }
    return self;
}

- (void)setName:(NSString*)name
{
    _name = [name copy];
    if(_name == nil) {
        _localName = nil;
        return;
    }
    NSRange range = [_name rangeOfString:@":" options:NSBackwardsSearch];
    _localName = (range.location == NSNotFound) ? _name : [_name substringFromIndex:(range.location + 1)];
}

- (NSUInteger)index
{
    if([_parent isKindOfClass:[NSXMLElement class]] == YES) {
        NSXMLElement* element = (NSXMLElement*)_parent;
        NSArray<NSXMLNode*>* nodes = (_kind == NSXMLAttributeKind) ? element.attributes : element.children;
        NSUInteger idx = [nodes indexOfObjectIdenticalTo:self];
        return idx == NSNotFound ? NSNotFound : idx;
    }
    if([_parent isKindOfClass:[NSXMLDocument class]] == YES) {
        NSXMLDocument* doc = (NSXMLDocument*)_parent;
        if(doc.rootElement == (NSXMLElement*)self) {
            return 0;
        }
    }
    return NSNotFound;
}

- (NSArray<NSXMLNode*>*)attributes
{
    return @[];
}

- (NSArray<NSXMLNode*>*)children
{
    return @[];
}

- (NSUInteger)childCount
{
    return 0;
}

- (NSXMLNode*)attributeForName:(NSString*)name
{
    return nil;
}

- (NSXMLNode*)attributeForLocalName:(NSString*)localName
                                URI:(NSString* _Nullable)URI
{
    return nil;
}

- (NSXMLNode*)nextSibling
{
    if([_parent isKindOfClass:[NSXMLElement class]] == NO) {
        return nil;
    }
    NSXMLElement* element = (NSXMLElement*)_parent;
    NSUInteger idx = self.index;
    if(idx == NSNotFound || idx + 1 >= element.children.count) {
        return nil;
    }
    return element.children[idx + 1];
}

- (void)detach
{
    if([_parent isKindOfClass:[NSXMLElement class]] == YES) {
        NSXMLElement* parent = (NSXMLElement*)_parent;
        if(_kind == NSXMLAttributeKind) {
            [parent removeAttributeForName:self.name];
        } else {
            NSUInteger idx = self.index;
            if(idx != NSNotFound) {
                [parent removeChildAtIndex:idx];
            }
        }
        return;
    }
    if([_parent isKindOfClass:[NSXMLDocument class]] == YES) {
        NSXMLDocument* doc = (NSXMLDocument*)_parent;
        if(doc.rootElement == (NSXMLElement*)self) {
            doc.rootElement = nil;
        }
    }
}

- (id)copyWithZone:(NSZone*)zone
{
    IJSVGiOSXMLNode* copy = [[self.class allocWithZone:zone] initWithKind:_kind];
    copy.name = _name;
    copy.localName = _localName;
    copy.URI = _URI;
    copy.stringValue = _stringValue;
    return copy;
}

@end

@implementation IJSVGiOSXMLElement

- (instancetype)init
{
    return [self initWithName:nil];
}

- (instancetype)initWithName:(NSString*)name
{
    if((self = [super initWithKind:NSXMLElementKind]) != nil) {
        _mutableAttributes = [[NSMutableArray alloc] init];
        _mutableChildren = [[NSMutableArray alloc] init];
        self.name = name;
    }
    return self;
}

- (void)setDocument:(NSXMLDocument*)document
{
    [super setDocument:document];
    for(NSXMLNode* attribute in _mutableAttributes) {
        attribute.document = document;
    }
    for(NSXMLNode* child in _mutableChildren) {
        child.document = document;
    }
}

- (NSArray<NSXMLNode*>*)attributes
{
    return [_mutableAttributes copy];
}

- (NSArray<NSXMLNode*>*)children
{
    return [_mutableChildren copy];
}

- (NSUInteger)childCount
{
    return _mutableChildren.count;
}

- (NSXMLNode*)attributeForName:(NSString*)name
{
    if(name.length == 0) {
        return nil;
    }
    for(NSXMLNode* node in _mutableAttributes) {
        if([node.name isEqualToString:name] == YES) {
            return node;
        }
    }
    return nil;
}

- (NSXMLNode*)attributeForLocalName:(NSString*)localName
                                URI:(NSString* _Nullable)URI
{
    if(localName.length == 0) {
        return nil;
    }
    for(NSXMLNode* node in _mutableAttributes) {
        BOOL localMatch = [node.localName isEqualToString:localName];
        BOOL uriMatch = (URI == nil && node.URI == nil) || [node.URI isEqualToString:URI];
        if(localMatch == YES && uriMatch == YES) {
            return node;
        }
    }
    return nil;
}

- (void)setAttributesAsDictionary:(NSDictionary<NSString*, NSString*>*)attributes
{
    if(attributes.count == 0) {
        return;
    }
    NSArray<NSString*>* keys = [attributes.allKeys sortedArrayUsingSelector:@selector(compare:)];
    for(NSString* key in keys) {
        NSString* value = attributes[key];
        if(value == nil) {
            continue;
        }
        NSXMLNode* node = [[NSXMLNode alloc] initWithKind:NSXMLAttributeKind];
        node.name = key;
        node.stringValue = value;
        [self addAttribute:node];
    }
}

- (void)addAttribute:(NSXMLNode*)attribute
{
    if(attribute == nil) {
        return;
    }
    attribute.kind = NSXMLAttributeKind;
    if(attribute.name.length != 0) {
        [self removeAttributeForName:attribute.name];
    }
    attribute.parent = self;
    attribute.document = self.document;
    [_mutableAttributes addObject:attribute];
}

- (void)removeAttributeForName:(NSString*)name
{
    if(name.length == 0) {
        return;
    }
    NSIndexSet* indexes = [_mutableAttributes indexesOfObjectsPassingTest:^BOOL(NSXMLNode* _Nonnull obj, NSUInteger idx, BOOL* _Nonnull stop) {
        return [obj.name isEqualToString:name];
    }];
    if(indexes.count == 0) {
        return;
    }
    NSArray<NSXMLNode*>* removing = [_mutableAttributes objectsAtIndexes:indexes];
    [_mutableAttributes removeObjectsAtIndexes:indexes];
    for(NSXMLNode* node in removing) {
        node.parent = nil;
        node.document = nil;
    }
}

- (void)addChild:(NSXMLNode*)child
{
    [self insertChild:child
              atIndex:_mutableChildren.count];
}

- (void)setChildren:(NSArray<NSXMLNode*>*)children
{
    for(NSXMLNode* child in _mutableChildren) {
        child.parent = nil;
        child.document = nil;
    }
    [_mutableChildren removeAllObjects];
    for(NSXMLNode* child in children) {
        [self addChild:child];
    }
}

- (void)insertChild:(NSXMLNode*)child
            atIndex:(NSUInteger)index
{
    if(child == nil) {
        return;
    }
    if(child.kind == NSXMLAttributeKind) {
        [self addAttribute:child];
        return;
    }
    child.parent = self;
    child.document = self.document;
    NSUInteger insertIndex = MIN(index, _mutableChildren.count);
    [_mutableChildren insertObject:child
                           atIndex:insertIndex];
}

- (void)removeChildAtIndex:(NSUInteger)index
{
    if(index >= _mutableChildren.count) {
        return;
    }
    NSXMLNode* child = _mutableChildren[index];
    [_mutableChildren removeObjectAtIndex:index];
    child.parent = nil;
    child.document = nil;
}

- (void)replaceChildAtIndex:(NSUInteger)index
                   withNode:(NSXMLNode*)node
{
    if(index >= _mutableChildren.count || node == nil) {
        return;
    }
    if(node.kind == NSXMLAttributeKind) {
        return;
    }
    NSXMLNode* oldNode = _mutableChildren[index];
    oldNode.parent = nil;
    oldNode.document = nil;
    node.parent = self;
    node.document = self.document;
    _mutableChildren[index] = node;
}

- (NSString*)stringValue
{
    if([super stringValue] != nil) {
        return [super stringValue];
    }
    NSMutableString* output = nil;
    for(NSXMLNode* child in _mutableChildren) {
        NSString* value = child.stringValue;
        if(value.length == 0) {
            continue;
        }
        if(output == nil) {
            output = [[NSMutableString alloc] init];
        }
        [output appendString:value];
    }
    return output;
}

- (id)copyWithZone:(NSZone*)zone
{
    NSXMLElement* copy = [[self.class allocWithZone:zone] initWithName:self.name];
    copy.localName = self.localName;
    copy.URI = self.URI;
    copy.stringValue = [super stringValue];
    for(NSXMLNode* attribute in _mutableAttributes) {
        [copy addAttribute:attribute.copy];
    }
    for(NSXMLNode* child in _mutableChildren) {
        [copy addChild:child.copy];
    }
    return copy;
}

@end

static BOOL IJSVGiOSXMLNodeIsElement(NSXMLNode* node)
{
    return [node isKindOfClass:[NSXMLElement class]] == YES && node.kind == NSXMLElementKind;
}

static void IJSVGiOSXMLVisitElements(NSXMLElement* element, void (^visitor)(NSXMLElement* _Nonnull))
{
    visitor(element);
    for(NSXMLNode* child in element.children) {
        if(IJSVGiOSXMLNodeIsElement(child) == NO) {
            continue;
        }
        IJSVGiOSXMLVisitElements((NSXMLElement*)child, visitor);
    }
}

static NSXMLNode* IJSVGiOSXMLNodeFromLibXMLNode(xmlNodePtr node, xmlDocPtr doc)
{
    if(node == NULL) {
        return nil;
    }
    switch(node->type) {
        case XML_ELEMENT_NODE: {
            NSString* localName = IJSVGiOSXMLStringFromXMLChar(node->name);
            NSString* prefix = IJSVGiOSXMLStringFromXMLChar(node->ns == NULL ? NULL : node->ns->prefix);
            NSString* qualifiedName = IJSVGiOSXMLQualifiedName(localName, prefix);
            NSXMLElement* element = [[NSXMLElement alloc] initWithName:qualifiedName];
            element.localName = localName;
            element.URI = IJSVGiOSXMLStringFromXMLChar(node->ns == NULL ? NULL : node->ns->href);

            for(xmlAttrPtr attr = node->properties; attr != NULL; attr = attr->next) {
                NSXMLNode* attribute = [[NSXMLNode alloc] initWithKind:NSXMLAttributeKind];
                NSString* attrLocalName = IJSVGiOSXMLStringFromXMLChar(attr->name);
                NSString* attrPrefix = IJSVGiOSXMLStringFromXMLChar(attr->ns == NULL ? NULL : attr->ns->prefix);
                attribute.name = IJSVGiOSXMLQualifiedName(attrLocalName, attrPrefix);
                attribute.localName = attrLocalName;
                attribute.URI = IJSVGiOSXMLStringFromXMLChar(attr->ns == NULL ? NULL : attr->ns->href);
                xmlChar* value = xmlNodeListGetString(doc, attr->children, 1);
                attribute.stringValue = IJSVGiOSXMLStringFromXMLChar(value);
                if(value != NULL) {
                    xmlFree(value);
                }
                [element addAttribute:attribute];
            }

            for(xmlNodePtr child = node->children; child != NULL; child = child->next) {
                NSXMLNode* childNode = IJSVGiOSXMLNodeFromLibXMLNode(child, doc);
                if(childNode != nil) {
                    [element addChild:childNode];
                }
            }
            return element;
        }
        case XML_TEXT_NODE:
        case XML_CDATA_SECTION_NODE: {
            NSXMLNode* textNode = [[NSXMLNode alloc] initWithKind:NSXMLTextKind];
            textNode.stringValue = IJSVGiOSXMLStringFromXMLChar(node->content);
            return textNode;
        }
        case XML_COMMENT_NODE: {
            NSXMLNode* commentNode = [[NSXMLNode alloc] initWithKind:NSXMLCommentKind];
            commentNode.stringValue = IJSVGiOSXMLStringFromXMLChar(node->content);
            return commentNode;
        }
        default:
            break;
    }
    return nil;
}

static BOOL IJSVGiOSXMLChildrenContainTextNodes(NSXMLElement* element)
{
    for(NSXMLNode* child in element.children) {
        if(child.kind == NSXMLTextKind) {
            return YES;
        }
    }
    return NO;
}

static void IJSVGiOSXMLAppendNodeString(NSXMLNode* node,
                                     NSMutableString* output,
                                     NSXMLNodeOptions options,
                                     NSUInteger depth)
{
    if(node == nil) {
        return;
    }
    if(node.kind == NSXMLTextKind) {
        [output appendString:IJSVGiOSXMLEscapeString(node.stringValue ?: @"", NO)];
        return;
    }
    if(node.kind == NSXMLCommentKind) {
        [output appendFormat:@"<!--%@-->", node.stringValue ?: @""];
        return;
    }
    if(IJSVGiOSXMLNodeIsElement(node) == NO) {
        return;
    }

    NSXMLElement* element = (NSXMLElement*)node;
    NSString* name = element.name ?: element.localName ?: @"node";
    [output appendFormat:@"<%@", name];
    for(NSXMLNode* attribute in element.attributes) {
        NSString* attributeName = attribute.name ?: attribute.localName ?: @"";
        NSString* attributeValue = IJSVGiOSXMLEscapeString(attribute.stringValue ?: @"", YES);
        [output appendFormat:@" %@=\"%@\"", attributeName, attributeValue];
    }

    BOOL hasChildren = element.childCount != 0;
    if(hasChildren == NO) {
        if((options & NSXMLNodeCompactEmptyElement) != 0) {
            [output appendString:@"/>"];
        } else {
            [output appendFormat:@"></%@>", name];
        }
        return;
    }

    BOOL prettyPrint = (options & NSXMLNodePrettyPrint) != 0;
    BOOL containsTextChildren = IJSVGiOSXMLChildrenContainTextNodes(element);

    [output appendString:@">"];
    if(prettyPrint == YES && containsTextChildren == NO) {
        [output appendString:@"\n"];
    }
    for(NSXMLNode* child in element.children) {
        if(prettyPrint == YES && containsTextChildren == NO) {
            for(NSUInteger i = 0; i < depth + 1; i++) {
                [output appendString:@"  "];
            }
        }
        IJSVGiOSXMLAppendNodeString(child, output, options, depth + 1);
        if(prettyPrint == YES && containsTextChildren == NO) {
            [output appendString:@"\n"];
        }
    }
    if(prettyPrint == YES && containsTextChildren == NO) {
        for(NSUInteger i = 0; i < depth; i++) {
            [output appendString:@"  "];
        }
    }
    [output appendFormat:@"</%@>", name];
}

@implementation IJSVGiOSXMLDocument

- (instancetype)init
{
    if((self = [super init]) != nil) {
        _version = @"1.0";
        _characterEncoding = @"UTF-8";
    }
    return self;
}

- (instancetype)initWithRootElement:(NSXMLElement*)rootElement
{
    if((self = [self init]) != nil) {
        self.rootElement = rootElement;
    }
    return self;
}

- (instancetype)initWithXMLString:(NSString*)string
                          options:(NSXMLNodeOptions)options
                            error:(NSError**)error
{
    NSData* data = [string dataUsingEncoding:NSUTF8StringEncoding];
    return [self initWithData:data
                      options:options
                        error:error];
}

- (instancetype)initWithData:(NSData*)data
                     options:(NSXMLNodeOptions)options
                       error:(NSError**)error
{
    if((self = [self init]) != nil) {
        if(data.length == 0) {
            if(error != nil) {
                *error = [NSError errorWithDomain:@"IJSVGiOSXML"
                                             code:1001
                                         userInfo:nil];
            }
            return nil;
        }

        xmlDocPtr doc = xmlReadMemory(data.bytes,
                                      (int)data.length,
                                      NULL,
                                      NULL,
                                      XML_PARSE_NONET | XML_PARSE_RECOVER | XML_PARSE_NOERROR | XML_PARSE_NOWARNING);
        if(doc == NULL) {
            if(error != nil) {
                *error = [NSError errorWithDomain:@"IJSVGiOSXML"
                                             code:1002
                                         userInfo:nil];
            }
            return nil;
        }

        xmlNodePtr root = xmlDocGetRootElement(doc);
        NSXMLNode* rootNode = IJSVGiOSXMLNodeFromLibXMLNode(root, doc);
        if(IJSVGiOSXMLNodeIsElement(rootNode) == NO) {
            xmlFreeDoc(doc);
            if(error != nil) {
                *error = [NSError errorWithDomain:@"IJSVGiOSXML"
                                             code:1003
                                         userInfo:nil];
            }
            return nil;
        }

        self.rootElement = (NSXMLElement*)rootNode;
        xmlFreeDoc(doc);
    }
    return self;
}

- (instancetype)initWithContentsOfURL:(NSURL*)URL
                              options:(NSXMLNodeOptions)options
                                error:(NSError**)error
{
    if(URL == nil) {
        if(error != nil) {
            *error = [NSError errorWithDomain:@"IJSVGiOSXML"
                                         code:1005
                                     userInfo:nil];
        }
        return nil;
    }

    NSData* data = [NSData dataWithContentsOfURL:URL
                                         options:0
                                           error:error];
    if(data == nil) {
        if(error != nil && *error == nil) {
            *error = [NSError errorWithDomain:@"IJSVGiOSXML"
                                         code:1005
                                     userInfo:nil];
        }
        return nil;
    }
    return [self initWithData:data
                      options:options
                        error:error];
}

- (void)setRootElement:(NSXMLElement*)rootElement
{
    if(_rootElement == rootElement) {
        return;
    }
    _rootElement.parent = nil;
    _rootElement.document = nil;
    _rootElement = rootElement;
    _rootElement.parent = self;
    _rootElement.document = self;
}

- (id)rootDocument
{
    return self;
}

- (NSArray<NSXMLElement*>*)nodesForXPath:(NSString*)xPath
                                   error:(NSError**)error
{
    if(_rootElement == nil || xPath.length == 0) {
        return @[];
    }

    NSMutableArray<NSXMLElement*>* output = [[NSMutableArray alloc] init];
    if([xPath isEqualToString:@"//use"] == YES) {
        IJSVGiOSXMLVisitElements(_rootElement, ^(NSXMLElement* element) {
            if([element.localName.lowercaseString isEqualToString:@"use"] == YES) {
                [output addObject:element];
            }
        });
        return output;
    }

    if([xPath isEqualToString:@"//*[@display='none']"] == YES) {
        IJSVGiOSXMLVisitElements(_rootElement, ^(NSXMLElement* element) {
            NSString* value = [element attributeForName:@"display"].stringValue;
            if([value.lowercaseString isEqualToString:@"none"] == YES) {
                [output addObject:element];
            }
        });
        return output;
    }

    if([xPath isEqualToString:@"//defs/*[self::linearGradient or self::radialGradient]"] == YES) {
        IJSVGiOSXMLVisitElements(_rootElement, ^(NSXMLElement* element) {
            if([element.localName.lowercaseString isEqualToString:@"defs"] == NO) {
                return;
            }
            for(NSXMLNode* child in element.children) {
                if(IJSVGiOSXMLNodeIsElement(child) == NO) {
                    continue;
                }
                NSString* localName = ((NSXMLElement*)child).localName.lowercaseString;
                if([localName isEqualToString:@"lineargradient"] == YES ||
                   [localName isEqualToString:@"radialgradient"] == YES) {
                    [output addObject:(NSXMLElement*)child];
                }
            }
        });
        return output;
    }

    if([xPath isEqualToString:@"//g"] == YES) {
        IJSVGiOSXMLVisitElements(_rootElement, ^(NSXMLElement* element) {
            if([element.localName.lowercaseString isEqualToString:@"g"] == YES) {
                [output addObject:element];
            }
        });
        return output;
    }

    if([xPath isEqualToString:@"//path"] == YES) {
        IJSVGiOSXMLVisitElements(_rootElement, ^(NSXMLElement* element) {
            if([element.localName.lowercaseString isEqualToString:@"path"] == YES) {
                [output addObject:element];
            }
        });
        return output;
    }

    if(error != nil) {
        *error = [NSError errorWithDomain:@"IJSVGiOSXML"
                                     code:1004
                                 userInfo:nil];
    }
    return @[];
}

- (NSString*)XMLStringWithOptions:(NSXMLNodeOptions)options
{
    if(_rootElement == nil) {
        return @"";
    }
    NSString* version = _version ?: @"1.0";
    NSString* charset = _characterEncoding ?: @"UTF-8";
    NSMutableString* output = [[NSMutableString alloc] initWithFormat:@"<?xml version=\"%@\" encoding=\"%@\"?>",
                               version,
                               charset];
    if((options & NSXMLNodePrettyPrint) != 0) {
        [output appendString:@"\n"];
    }
    IJSVGiOSXMLAppendNodeString(_rootElement, output, options, 0);
    return output;
}

@end
#endif
