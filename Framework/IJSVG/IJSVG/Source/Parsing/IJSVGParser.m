//
//  IJSVGParser.m
//  IconJar
//
//  Created by Curtis Hard on 30/08/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import "IJSVG.h"
#import "IJSVGParser.h"

NSString* const IJSVGAttributeViewBox = @"viewBox";
NSString* const IJSVGAttributeID = @"id";
NSString* const IJSVGAttributeClass = @"class";
NSString* const IJSVGAttributeX = @"x";
NSString* const IJSVGAttributeY = @"y";
NSString* const IJSVGAttributeWidth = @"width";
NSString* const IJSVGAttributeHeight = @"height";
NSString* const IJSVGAttributeOpacity = @"opacity";
NSString* const IJSVGAttributeStrokeOpacity = @"stroke-opacity";
NSString* const IJSVGAttributeStrokeWidth = @"stroke-width";
NSString* const IJSVGAttributeStrokeDashOffset = @"stroke-dashoffset";
NSString* const IJSVGAttributeFillOpacity = @"fill-opacity";
NSString* const IJSVGAttributeClipPath = @"clip-path";
NSString* const IJSVGAttributeMask = @"mask";
NSString* const IJSVGAttributeGradientUnits = @"gradientUnits";
NSString* const IJSVGAttributePatternUnits = @"patternUnits";
NSString* const IJSVGAttributePatternContentUnits = @"patternContentUnits";
NSString* const IJSVGAttributeMaskUnits = @"maskUnits";
NSString* const IJSVGAttributeMaskContentUnits = @"maskContentUnits";
NSString* const IJSVGAttributeTransform = @"transform";
NSString* const IJSVGAttributeGradientTransform = @"gradientTransform";
NSString* const IJSVGAttributeUnicode = @"unicode";
NSString* const IJSVGAttributeStrokeLineCap = @"stroke-linecap";
NSString* const IJSVGAttributeLineJoin = @"stroke-linejoin";
NSString* const IJSVGAttributeStroke = @"stroke";
NSString* const IJSVGAttributeStrokeDashArray = @"stroke-dasharray";
NSString* const IJSVGAttributeFill = @"fill";
NSString* const IJSVGAttributeFillRule = @"fill-rule";
NSString* const IJSVGAttributeBlendMode = @"mix-blend-mode";
NSString* const IJSVGAttributeDisplay = @"display";
NSString* const IJSVGAttributeStyle = @"style";
NSString* const IJSVGAttributeD = @"d";
NSString* const IJSVGAttributeXLink = @"xlink:href";
NSString* const IJSVGAttributeX1 = @"x1";
NSString* const IJSVGAttributeX2 = @"x2";
NSString* const IJSVGAttributeY1 = @"y1";
NSString* const IJSVGAttributeY2 = @"y2";
NSString* const IJSVGAttributeRX = @"rx";
NSString* const IJSVGAttributeRY = @"ry";
NSString* const IJSVGAttributeCX = @"cx";
NSString* const IJSVGAttributeCY = @"cy";
NSString* const IJSVGAttributeR = @"r";
NSString* const IJSVGAttributeFX = @"fx";
NSString* const IJSVGAttributeFY = @"fy";
NSString* const IJSVGAttributePoints = @"points";
NSString* const IJSVGAttributeOffset = @"offset";
NSString* const IJSVGAttributeStopColor = @"stop-color";
NSString* const IJSVGAttributeStopOpacity = @"stop-opacity";
NSString* const IJSVGAttributeHref = @"href";
NSString* const IJSVGAttributeOverflow = @"overflow";

@implementation IJSVGParser

static NSDictionary* _IJSVGAttributeDictionaryFloats = nil;
static NSDictionary* _IJSVGAttributeDictionaryNodes = nil;
static NSDictionary* _IJSVGAttributeDictionaryUnits = nil;
static NSDictionary* _IJSVGAttributeDictionaryTransforms = nil;

+ (void)load
{
    _IJSVGAttributeDictionaryFloats = [@{
        IJSVGAttributeX : @"x",
        IJSVGAttributeY : @"y",
        IJSVGAttributeWidth : @"width",
        IJSVGAttributeHeight : @"height",
        IJSVGAttributeOpacity : @"opacity",
        IJSVGAttributeStrokeOpacity : @"strokeOpacity",
        IJSVGAttributeStrokeWidth : @"strokeWidth",
        IJSVGAttributeStrokeDashOffset : @"strokeDashOffset",
        IJSVGAttributeFillOpacity : @"fillOpacity" } retain];
    _IJSVGAttributeDictionaryNodes = [@{
        IJSVGAttributeClipPath : @"clipPath",
        IJSVGAttributeMask : @"mask" } retain];
    _IJSVGAttributeDictionaryUnits = [@{
        IJSVGAttributeGradientUnits : @"units",
        IJSVGAttributeMaskUnits : @"units",
        IJSVGAttributePatternUnits : @"units",
        IJSVGAttributeMaskContentUnits : @"contentUnits",
        IJSVGAttributePatternContentUnits : @"contentUnits"
    } retain];
    _IJSVGAttributeDictionaryTransforms = [@{
        IJSVGAttributeTransform : @"transforms",
        IJSVGAttributeGradientTransform : @"transforms" } retain];
}

+ (IJSVGParser*)groupForFileURL:(NSURL*)aURL
{
    return [self.class groupForFileURL:aURL
                                 error:nil
                              delegate:nil];
}

+ (IJSVGParser*)groupForFileURL:(NSURL*)aURL
                       delegate:(id<IJSVGParserDelegate>)delegate
{
    return [self.class groupForFileURL:aURL
                                 error:nil
                              delegate:delegate];
}

+ (IJSVGParser*)groupForFileURL:(NSURL*)aURL
                          error:(NSError**)error
                       delegate:(id<IJSVGParserDelegate>)delegate
{
    return [[[self.class alloc] initWithFileURL:aURL
                                          error:error
                                       delegate:delegate] autorelease];
}

- (void)dealloc
{
    (void)([_detachedElements release]), _detachedElements = nil;
    (void)([_styleSheet release]), _styleSheet = nil;
    (void)([_intrinsicSize release]), _intrinsicSize = nil;
    if (_commandDataStream != NULL) {
        (void)IJSVGPathDataStreamRelease(_commandDataStream), _commandDataStream = nil;
    }
    [super dealloc];
}

- (id)initWithSVGString:(NSString*)string
                  error:(NSError**)error
               delegate:(id<IJSVGParserDelegate>)delegate
{
    if ((self = [super init]) != nil) {
        _delegate = delegate;

        _respondsTo.handleForeignObject = [_delegate respondsToSelector:@selector(svgParser:handleForeignObject:document:)];
        _respondsTo.shouldHandleForeignObject = [_delegate respondsToSelector:@selector(svgParser:shouldHandleForeignObject:)];
        _respondsTo.handleSubSVG = [_delegate respondsToSelector:@selector(svgParser:foundSubSVG:withSVGString:)];

        // load the document / file, assume its UTF8

        // use NSXMLDocument as its the easiest thing to do on OSX
        NSError* anError = nil;
        @try {
            _document = [[NSXMLDocument alloc] initWithXMLString:string
                                                         options:0
                                                           error:&anError];
        }
        @catch (NSException* exception) {
        }

        // error parsing the XML document
        if (anError != nil) {
            return [self _handleErrorWithCode:IJSVGErrorParsingFile
                                        error:error];
        }

        // attempt to parse the file
        anError = nil;
        @try {
            [self begin];
        }
        @catch (NSException* exception) {
            return [self _handleErrorWithCode:IJSVGErrorParsingSVG
                                        error:error];
        }

        // check the actual parsed SVG
        anError = nil;
        if (![self _validateParse:&anError]) {
            *error = anError;
            (void)([_document release]), _document = nil;
            (void)([self release]), self = nil;
            return nil;
        }

        // we have actually finished with the document at this point
        // so just get rid of it
        (void)([_document release]), _document = nil;
    }
    return self;
}

+ (BOOL)isDataSVG:(NSData*)data
{
    @try {
        NSError* error;
        NSXMLDocument* doc = [[[NSXMLDocument alloc] initWithData:data
                                                          options:0
                                                            error:&error] autorelease];
        return doc != nil && error == nil;
    } @catch (NSException* exception) {
    }
    return NO;
}

- (id)initWithFileURL:(NSURL*)aURL
                error:(NSError**)error
             delegate:(id<IJSVGParserDelegate>)delegate
{
    NSError* anError = nil;
    NSStringEncoding encoding;
    NSString* str = [NSString stringWithContentsOfFile:aURL.path
                                          usedEncoding:&encoding
                                                 error:&anError];

    // error reading file
    if (str == nil) {
        return [self _handleErrorWithCode:IJSVGErrorReadingFile
                                    error:error];
    }

    return [self initWithSVGString:str
                             error:error
                          delegate:delegate];
}

- (void*)_handleErrorWithCode:(NSUInteger)code
                        error:(NSError**)error
{
    if (error) {
        *error = [[[NSError alloc] initWithDomain:IJSVGErrorDomain
                                             code:code
                                         userInfo:nil] autorelease];
    }
    (void)([_document release]), _document = nil;
    (void)([self release]), self = nil;
    return nil;
}

- (BOOL)_validateParse:(NSError**)error
{
    // check is font
    if (self.isFont) {
        return YES;
    }

    // check the viewbox
    if (NSEqualRects(self.viewBox, NSZeroRect) || self.size.width == 0 || self.size.height == 0) {
        if (error != NULL) {
            *error = [[[NSError alloc] initWithDomain:IJSVGErrorDomain
                                                 code:IJSVGErrorInvalidViewBox
                                             userInfo:nil] autorelease];
        }
        return NO;
    }
    return YES;
}

- (NSSize)size
{
    return _viewBox.size;
}

- (CGRect)bounds
{
    return _viewBox;
}

- (BOOL)isFont
{
    return NO;
}

- (void)begin {
    // setup basics to begin with
    _styleSheet = [[IJSVGStyleSheet alloc] init];
    _commandDataStream = IJSVGPathDataStreamCreateDefault();
    _detachedElements = [[NSMutableDictionary alloc] init];
    [self computeAttributesFromElement:_document.rootElement
                                onNode:self
                     ignoredAttributes:nil];
    [self computeViewBox:_document.rootElement];
    [self computeElement:_document.rootElement
              parentNode:self];
}

- (void)computeDefsForElement:(NSXMLElement*)element
                   parentNode:(IJSVGNode*)parentNode
{
    for(NSXMLElement* childElement in element.children) {
        IJSVGNodeType type = [IJSVGNode typeForString:childElement.localName
                                                 kind:childElement.kind];
        if(type != IJSVGNodeTypeDef) {
            continue;
        }
        [self parseDefElement:childElement
                   parentNode:parentNode];
    }
}

- (void)computeViewBox:(NSXMLElement*)element
{
    NSXMLNode* attribute = nil;
    if ((attribute = [element attributeForName:IJSVGAttributeViewBox]) != nil) {
        CGFloat* box = [IJSVGUtils parseViewBox:attribute.stringValue];
        _viewBox = NSMakeRect(box[0], box[1], box[2], box[3]);
        (void)free(box);
    } else {
        // its possible wlength or hlength are nil
        CGFloat w = self.width.value;
        CGFloat h = self.height.value;
        
        if (h == 0.f && w != 0.f) {
            h = w;
        } else if (w == 0.f && h != 0.f) {
            w = h;
        }
        _viewBox = NSMakeRect(0.f, 0.f, w, h);
    }

    IJSVGUnitLength* wl = [IJSVGUnitLength unitWithFloat:_viewBox.size.width];
    IJSVGUnitLength* hl = [IJSVGUnitLength unitWithFloat:_viewBox.size.height];
    if ([element attributeForName:IJSVGAttributeWidth] != nil) {
        wl = self.width;
    }
    if ([element attributeForName:IJSVGAttributeHeight] != nil) {
        hl = self.height;
    }

    // store the width and height
    _intrinsicSize = [IJSVGUnitSize sizeWithWidth:wl
                                           height:hl].retain;
}

- (void)computeAttributesFromElement:(NSXMLElement*)element
                              onNode:(IJSVGNode*)node
                   ignoredAttributes:(NSArray<NSString*>*)ignoredAttributes
{
    IJSVGStyle* styleSheet = nil;
    __block IJSVGStyle* nodeStyle = nil;
    
    // precache the attributes, this is quicker than asking for it each time
    CGRect computedBounds = CGRectZero;
    IJSVGUnitType unitType = [node contentUnitsWithReferencingNodeBounds:&computedBounds];
    NSMutableDictionary<NSString*, NSString*>* attributes = nil;
    attributes = [[[NSMutableDictionary alloc] initWithCapacity:element.attributes.count] autorelease];
    for(NSXMLNode* attributeNode in element.attributes) {
        attributes[attributeNode.name] = attributeNode.stringValue;
    }

    // helper for setting an attribute
    typedef void (^IJSVGAttributeParseBlock)(NSString*);
    void (^IJSVGAttributeParse)(const NSString*, IJSVGAttributeParseBlock) =
    ^(NSString* key, IJSVGAttributeParseBlock parseBlock) {
        if([ignoredAttributes containsObject:key] == YES) {
            return;
        }
        NSString* value = [nodeStyle property:key] ?: attributes[key];
        if(value != nil && value.length != 0) {
            parseBlock(value);
        }
    };
    
    // helper for settings attributes
    typedef id (^IJSVGAttributeComputableParseBlock)(NSString*);
    void (^IJSVGAttributesParse)(NSDictionary<NSString*, NSString*>*, IJSVGAttributeComputableParseBlock) =
    ^(NSDictionary<NSString*, NSString*>* dictionary, IJSVGAttributeComputableParseBlock parseBlock) {
        [dictionary enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, NSString * _Nonnull obj, BOOL * _Nonnull stop) {
            IJSVGAttributeParse(key, ^(NSString* value) {
                [node setValue:parseBlock(value)
                        forKey:obj];
            });
        }];
    };
    
    // identifier
    IJSVGAttributeParse(IJSVGAttributeID, ^(NSString* value) {
        node.identifier = value;
        [self detachElement:element withIdentifier:value];
    });
    
    // class list
    IJSVGAttributeParse(IJSVGAttributeClass, ^(NSString* value) {
        node.className = value;
        node.classNameList = [value ijsvg_componentsSeparatedByChars:" "];
    });
    
    
    // style
    if(_styleSheet != nil) {
        styleSheet = [_styleSheet styleForNode:node];
    }
    
    IJSVGAttributeParse(IJSVGAttributeStyle, ^(NSString* value) {
        nodeStyle = [IJSVGStyle parseStyleString:value];
    });
    
    if(styleSheet != nil) {
        nodeStyle = [styleSheet mergedStyle:nodeStyle];
    }
    
    
    // floating point numbers
    IJSVGAttributesParse(_IJSVGAttributeDictionaryFloats, ^id (NSString* value) {
        return [IJSVGUnitLength unitWithString:value];
    });
    
    // nodes
    IJSVGAttributesParse(_IJSVGAttributeDictionaryNodes, ^id (NSString* value) {
        NSString* identifier = [IJSVGUtils defURL:value];
        if(identifier != nil) {
            return [self computeDetachedNodeWithIdentifier:identifier
                                        referencingElement:element
                                           referencingNode:node];
        }
        return nil;
    });
    
    // units
    IJSVGAttributesParse(_IJSVGAttributeDictionaryUnits, ^id (NSString* value) {
        return @([IJSVGUtils unitTypeForString:value]);
    });
    
    // transforms
    IJSVGAttributesParse(_IJSVGAttributeDictionaryTransforms, ^id (NSString* value) {
        NSMutableArray<IJSVGTransform*>* transforms = [[[NSMutableArray alloc] init] autorelease];
        [transforms addObjectsFromArray:[IJSVGTransform transformsForString:value]];
        if(node.transforms != nil) {
            [transforms addObjectsFromArray:node.transforms];
        }
        return transforms;
    });
    
    // we need to change how transforms work if our unit space is not userSpaceOnUse
    for(IJSVGTransform* transform in node.transforms) {
        [transform applyBounds:computedBounds
              withContentUnits:unitType];
    }
    
    // unicode
    IJSVGAttributeParse(IJSVGAttributeUnicode, ^(NSString* value) {
        node.unicode = [NSString stringWithFormat:@"%04x", [value characterAtIndex:0]];
    });

    // linecap
    IJSVGAttributeParse(IJSVGAttributeStrokeLineCap, ^(NSString* value) {
        node.lineCapStyle = [IJSVGUtils lineCapStyleForString:value];
    });

    // line join
    IJSVGAttributeParse(IJSVGAttributeLineJoin, ^(NSString* value) {
        node.lineJoinStyle = [IJSVGUtils lineJoinStyleForString:value];
    });
    
    // stroke color
    IJSVGAttributeParse(IJSVGAttributeStroke, ^(NSString* value) {
        // todo
        NSString* fillIdentifier = [IJSVGUtils defURL:value];
        if(fillIdentifier != nil) {
            IJSVGNode* object = [self computeDetachedNodeWithIdentifier:fillIdentifier
                                                     referencingElement:element
                                                        referencingNode:node];
            switch(object.type) {
                case IJSVGNodeTypePattern: {
                    node.strokePattern = (IJSVGPattern*)object;
                    break;
                }
                case IJSVGNodeTypeLinearGradient:
                case IJSVGNodeTypeRadialGradient: {
                    node.strokeGradient = (IJSVGGradient*)object;
                    break;
                }
                default:
                    break;
            }
            return;
        }
        node.strokeColor = [IJSVGColor colorFromString:value];
    });

    // stroke dash array
    IJSVGAttributeParse(IJSVGAttributeStrokeDashArray, ^(NSString* value) {
        // nothing specified
        if ([value isEqualToString:@"none"]) {
            node.strokeDashArrayCount = 0;
            return;
        }
        NSInteger paramCount = 0;
        CGFloat* params = [IJSVGUtils commandParameters:value
                                                  count:&paramCount];
        node.strokeDashArray = params;
        node.strokeDashArrayCount = paramCount;
    });

    // fill - seems kinda complicated for what it actually is
    IJSVGAttributeParse(IJSVGAttributeFill, ^(NSString* value) {
        // todo
        NSString* fillIdentifier = [IJSVGUtils defURL:value];
        if(fillIdentifier != nil) {
            IJSVGNode* object = [self computeDetachedNodeWithIdentifier:fillIdentifier
                                                     referencingElement:element
                                                        referencingNode:node];
            switch(object.type) {
                case IJSVGNodeTypePattern: {
                    node.fillPattern = (IJSVGPattern*)object;
                    break;
                }
                case IJSVGNodeTypeLinearGradient:
                case IJSVGNodeTypeRadialGradient: {
                    node.fillGradient = (IJSVGGradient*)object;
                    break;
                }
                default:
                    break;
            }
            return;
        }
        node.fillColor = [IJSVGColor colorFromString:value];
    });
    
    // fill opacity
    IJSVGAttributeParse(IJSVGAttributeFillOpacity, ^(NSString* value) {
        if (node.fillOpacity.value != 1.f) {
            node.fillColor = [IJSVGColor changeAlphaOnColor:node.fillColor
                                                         to:node.fillOpacity.value];
        }
    });

    // blendmode
    IJSVGAttributeParse(IJSVGAttributeBlendMode, ^(NSString* value) {
        node.blendMode = [IJSVGUtils blendModeForString:value];
    });

    // fill rule
    IJSVGAttributeParse(IJSVGAttributeFillRule, ^(NSString* value) {
        node.windingRule = [IJSVGUtils windingRuleForString:value];
    });

    // display
    IJSVGAttributeParse(IJSVGAttributeDisplay, ^(NSString* value) {
        if ([value.lowercaseString isEqualToString:@"none"]) {
            node.shouldRender = NO;
        }
    });
    
    // offset
    IJSVGAttributeParse(IJSVGAttributeOffset, ^(NSString* value) {
        node.offset = [IJSVGUnitLength unitWithString:value];
    });
    
    // stop-opacity
    IJSVGAttributeParse(IJSVGAttributeStopOpacity, ^(NSString* value) {
        node.fillOpacity = [IJSVGUnitLength unitWithString:value];
    });
    
    // stop-color
    IJSVGAttributeParse(IJSVGAttributeStopColor, ^(NSString* value) {
        node.fillColor = [IJSVGColor colorFromString:value];
        if(node.fillOpacity.value != 1.f) {
            node.fillColor = [IJSVGColor changeAlphaOnColor:node.fillColor
                                                         to:node.fillOpacity.value];
        }
    });
    
    // overflow
    IJSVGAttributeParse(IJSVGAttributeOverflow, ^(NSString* value) {
        if([value.lowercaseString isEqualToString:@"hidden"]) {
            node.overflowVisibility = IJSVGOverflowVisibilityHidden;
        } else {
            node.overflowVisibility = IJSVGOverflowVisibilityVisible;
        }
    });
}

- (IJSVGNode*)parseElement:(NSXMLElement*)element
                parentNode:(IJSVGNode*)node
{
    NSString* name = element.localName;
    NSXMLNodeKind nodeKind = element.kind;
    IJSVGNodeType nodeType = [IJSVGNode typeForString:name
                                                 kind:nodeKind];
    
    IJSVGNode* computedNode = nil;
    switch(nodeType) {
        case IJSVGNodeTypeStyle: {
            [self parseStyleElement:element
                         parentNode:node];
            break;
        }
        case IJSVGNodeTypeNotFound:
        case IJSVGNodeTypeGroup: {
            computedNode = [self parseGroupElement:element
                                        parentNode:node];
            break;
        }
        case IJSVGNodeTypePath: {
            computedNode = [self parsePathElement:element
                                       parentNode:node];
            break;
        }
        case IJSVGNodeTypeCircle: {
            computedNode = [self parseCircleElement:element
                                         parentNode:node];
            break;
        }
        case IJSVGNodeTypeEllipse: {
            computedNode = [self parseEllipseElement:element
                                          parentNode:node];
            break;
        }
        case IJSVGNodeTypeRect: {
            computedNode = [self parseRectElement:element
                                       parentNode:node];
            break;
        }
        case IJSVGNodeTypePolygon: {
            computedNode = [self parsePolygonElement:element
                                          parentNode:node];
            break;
        }
        case IJSVGNodeTypePolyline: {
            computedNode = [self parsePolyLineElement:element
                                           parentNode:node];
            break;
        }
        case IJSVGNodeTypeLine: {
            computedNode = [self parseLineElement:element
                                       parentNode:node];
            break;
        }
        case IJSVGNodeTypeImage: {
            computedNode = [self parseImageElement:element
                                        parentNode:node];
            break;
        }
        case IJSVGNodeTypePattern: {
            computedNode = [self parsePatternElement:element
                                          parentNode:node];
            break;
        }
        case IJSVGNodeTypeClipPath: {
            computedNode = [self parseClipPathElement:element
                                           parentNode:node];
            break;
        }
        case IJSVGNodeTypeMask: {
            computedNode = [self parseMaskElement:element
                                       parentNode:node];
            break;
        }
        case IJSVGNodeTypeDef: {
            [self parseDefElement:element
                       parentNode:node];
            break;
        }
        case IJSVGNodeTypeUse: {
            computedNode = [self parseUseElement:element
                                      parentNode:node];
            break;
        }
        case IJSVGNodeTypeLinearGradient: {
            computedNode = [self parseLinearGradientElement:element
                                                 parentNode:node];
            break;
        }
        case IJSVGNodeTypeRadialGradient: {
            computedNode = [self parseRadialGradientElement:element
                                                 parentNode:node];
            break;
        }
        case IJSVGNodeTypeStop: {
            computedNode = [self parseStopElement:element
                                       parentNode:node];
            break;
        }
        case IJSVGNodeTypeTitle: {
            [self parseTitleElement:element
                         parentNode:node];
            break;
        }
        case IJSVGNodeTypeDesc: {
            [self parseDescElement:element
                        parentNode:node];
            break;
        }
        default:
            break;
    }
    
    // append to its parent
    if(computedNode != nil && computedNode.adoptable == YES) {
        if([node isKindOfClass:IJSVGGroup.class]) {
            [(IJSVGGroup*)node addChild:computedNode];
        }
    }
    return computedNode;
}

- (void)computeElement:(NSXMLElement*)element
            parentNode:(IJSVGNode*)node
{
    [self computeDefsForElement:element
                     parentNode:node];
    for(NSXMLElement* childElement in element.children) {
        [self parseElement:childElement parentNode:node];
    }
}

#pragma mark Detaching nodes
- (void)detachElement:(NSXMLElement*)element
       withIdentifier:(NSString*)identifier
{
    element = [element.copy autorelease];
    [element detach];
    
    // its important that we remove the ID attribute
    [element removeAttributeForName:IJSVGAttributeID];
    _detachedElements[identifier] = element;
}

- (NSXMLElement*)detachedElementWithIdentifier:(NSString*)identifier
{
    return [[_detachedElements[identifier] copy] autorelease];
}

- (IJSVGNode*)computeDetachedNodeWithIdentifier:(NSString*)identifier
                             referencingElement:(NSXMLElement*)element
                                referencingNode:(IJSVGNode*)node
{
    NSXMLElement* detachedElement = [self detachedElementWithIdentifier:identifier];
    if(detachedElement == nil) {
        return nil;
    }
    // we need to make sure once we are done, we detach this from its parent
    // or it can cause recursion down the line
    return [self parseElement:detachedElement
                   parentNode:node].detach;
}

- (NSXMLElement*)mergedElement:(NSXMLElement*)element
          withReferenceElement:(NSXMLElement*)reference
{
    NSXMLElement* copy = [[reference copy] autorelease];
    for (NSXMLNode* attribute in element.attributes) {
        [copy removeAttributeForName:attribute.name];
        attribute = [[attribute copy] autorelease];
        [copy addAttribute:attribute];
    }
    return copy;
}

#pragma mark Node Types

- (void)parseStyleElement:(NSXMLElement*)element
               parentNode:(IJSVGNode*)parentNode
{
    [_styleSheet parseStyleBlock:element.stringValue];
}

- (IJSVGNode*)parseLinearGradientElement:(NSXMLElement*)element
                              parentNode:(IJSVGNode*)parentNode
{
    IJSVGLinearGradient* node = [[[IJSVGLinearGradient alloc] init] autorelease];
    node.units = IJSVGUnitObjectBoundingBox;
    node.type = IJSVGNodeTypeLinearGradient;
    node.name = element.localName;
    NSString* xLinkID = [self resolveXLinkAttributeStringForElement:element];
    if(xLinkID != nil) {
        NSXMLElement* detachedElement = [self detachedElementWithIdentifier:xLinkID];
        element = [self mergedElement:element
                 withReferenceElement:detachedElement];
    }

    [self computeAttributesFromElement:element
                                onNode:node
                     ignoredAttributes:nil];
    [self computeElement:element
              parentNode:node];
    
    node.gradient = [IJSVGLinearGradient parseGradient:element
                                              gradient:node];
    return node;
}

- (IJSVGNode*)parseRadialGradientElement:(NSXMLElement*)element
                              parentNode:(IJSVGNode*)parentNode
{
    IJSVGRadialGradient* node = [[[IJSVGRadialGradient alloc] init] autorelease];
    node.units = IJSVGUnitObjectBoundingBox;
    node.type = IJSVGNodeTypeRadialGradient;
    node.name = element.localName;
    NSString* xLinkID = [self resolveXLinkAttributeStringForElement:element];
    if(xLinkID != nil) {
        NSXMLElement* detachedElement = [self detachedElementWithIdentifier:xLinkID];
        element = [self mergedElement:element
                 withReferenceElement:detachedElement];
    }
    [self computeAttributesFromElement:element
                                onNode:node
                     ignoredAttributes:nil];
    [self computeElement:element
              parentNode:node];
    node.gradient = [IJSVGRadialGradient parseGradient:element
                                              gradient:node];
    return node;
}

- (IJSVGNode*)parseStopElement:(NSXMLElement*)element
                    parentNode:(IJSVGNode*)parentNode
{
    IJSVGNode* node = [[[IJSVGNode alloc] init] autorelease];
    node.type = IJSVGNodeTypeStop;
    node.name = element.localName;
    node.adoptable = YES;
    [self computeAttributesFromElement:element
                                onNode:node
                     ignoredAttributes:nil];
    return node;
}

- (IJSVGNode*)parsePathElement:(NSXMLElement*)element
                    parentNode:(IJSVGNode*)parentNode
{
    IJSVGPath* node = [[[IJSVGPath alloc] init] autorelease];
    node.adoptable = YES;
    node.type = IJSVGNodeTypePath;
    node.name = element.localName;
    node.parentNode = parentNode;
    
    NSString* pathData = [element attributeForName:IJSVGAttributeD].stringValue;
    [self parsePathCommandData:pathData
                      intoPath:node];

    [self computeAttributesFromElement:element
                                onNode:node
                     ignoredAttributes:nil];
    return node;
}

- (IJSVGNode*)parseLineElement:(NSXMLElement*)element
                    parentNode:(IJSVGNode*)parentNode
{
    IJSVGPath* node = [[[IJSVGPath alloc] init] autorelease];
    node.type = IJSVGNodeTypeLine;
    node.adoptable = YES;
    node.primitiveType = kIJSVGPrimitivePathTypeLine;
    node.parentNode = parentNode;
    
    [self computeAttributesFromElement:element
                                onNode:node
                     ignoredAttributes:nil];
    
    // convert a line into a command,
    // basically MX1 Y1LX2 Y2
    CGFloat x1 = [element attributeForName:IJSVGAttributeX1].stringValue.floatValue;
    CGFloat y1 = [element attributeForName:IJSVGAttributeY1].stringValue.floatValue;
    CGFloat x2 = [element attributeForName:IJSVGAttributeX2].stringValue.floatValue;
    CGFloat y2 = [element attributeForName:IJSVGAttributeY2].stringValue.floatValue;

    // use sprintf as its quicker then stringWithFormat...
    char* buffer;
    asprintf(&buffer, "M%.2f %.2fL%.2f %.2f", x1, y1, x2, y2);
    [self parsePathCommandDataBuffer:buffer
                            intoPath:node];
    (void)free(buffer);
    return node;
}

- (IJSVGNode*)parsePolyLineElement:(NSXMLElement*)element
                        parentNode:(IJSVGNode*)parentNode
{
    IJSVGPath* node = [[[IJSVGPath alloc] init] autorelease];
    node.type = IJSVGNodeTypePolyline;
    node.adoptable = YES;
    node.primitiveType = kIJSVGPrimitivePathTypePolyLine;
    node.parentNode = parentNode;
    
    [self computeAttributesFromElement:element
                                onNode:node
                     ignoredAttributes:nil];
    
    NSString* pointsString = [element attributeForName:IJSVGAttributePoints].stringValue;
    [self parsePolyPoints:pointsString
                 intoPath:node
                closePath:YES];
    
    return node;
}

- (IJSVGNode*)parsePolygonElement:(NSXMLElement*)element
                       parentNode:(IJSVGNode*)parentNode
{
    IJSVGPath* node = [[[IJSVGPath alloc] init] autorelease];
    node.type = IJSVGNodeTypePolygon;
    node.adoptable = YES;
    node.primitiveType = kIJSVGPrimitivePathTypePolygon;
    node.parentNode = parentNode;
    
    [self computeAttributesFromElement:element
                                onNode:node
                     ignoredAttributes:nil];
    
    NSString* pointsString = [element attributeForName:IJSVGAttributePoints].stringValue;
    [self parsePolyPoints:pointsString
                 intoPath:node
                closePath:YES];
    
    return node;
}

- (IJSVGNode*)parseEllipseElement:(NSXMLElement*)element
                       parentNode:(IJSVGNode*)parentNode
{
    IJSVGPath* node = [[[IJSVGPath alloc] init] autorelease];
    node.name = element.localName;
    node.adoptable = YES;
    node.primitiveType = kIJSVGPrimitivePathTypeEllipse;
    node.type = IJSVGNodeTypeEllipse;
    
    CGRect computedBounds = CGRectZero;
    IJSVGUnitType contentUnits = [parentNode contentUnitsWithReferencingNodeBounds:&computedBounds];
    [self computeAttributesFromElement:element
                                onNode:node
                     ignoredAttributes:nil];
    
    NSString* cxString = [element attributeForName:IJSVGAttributeCX].stringValue;
    NSString* cyString = [element attributeForName:IJSVGAttributeCY].stringValue;
    NSString* rxString = [element attributeForName:IJSVGAttributeRX].stringValue;
    NSString* ryString = [element attributeForName:IJSVGAttributeRY].stringValue;
    
    IJSVGUnitLength* cXu;
    IJSVGUnitLength* cYu;
    IJSVGUnitLength* rXu;
    IJSVGUnitLength* rYu;
    if(contentUnits == IJSVGUnitObjectBoundingBox) {
        cXu = [IJSVGUnitLength unitWithString:cxString].lengthByMatchingPercentage;
        cYu = [IJSVGUnitLength unitWithString:cyString].lengthByMatchingPercentage;
        rXu = [IJSVGUnitLength unitWithString:rxString].lengthByMatchingPercentage;
        rYu = [IJSVGUnitLength unitWithString:ryString].lengthByMatchingPercentage;
    } else {
        cXu = [IJSVGUnitLength unitWithString:cxString];
        cYu = [IJSVGUnitLength unitWithString:cyString];
        rXu = [IJSVGUnitLength unitWithString:rxString];
        rYu = [IJSVGUnitLength unitWithString:ryString];
    }
    
    CGFloat cX = [cXu computeValue:computedBounds.size.width];
    CGFloat cY = [cYu computeValue:computedBounds.size.height];
    CGFloat rX = [rXu computeValue:computedBounds.size.width];
    CGFloat rY = [rYu computeValue:computedBounds.size.height];
    CGRect rect = CGRectMake(cX - rX, cY - rY, rX * 2, rY * 2);
    CGPathRef nPath = CGPathCreateWithEllipseInRect(rect, NULL);
    node.path = (CGMutablePathRef)nPath;
    CGPathRelease(nPath);
    return node;
}

- (IJSVGNode*)parseCircleElement:(NSXMLElement*)element
                      parentNode:(IJSVGNode*)parentNode
{
    IJSVGPath* node = [[[IJSVGPath alloc] init] autorelease];
    node.name = element.localName;
    node.adoptable = YES;
    node.primitiveType = kIJSVGPrimitivePathTypeCircle;
    node.type = IJSVGNodeTypeCircle;
    
    CGRect computedBounds = CGRectZero;
    IJSVGUnitType contentUnits = [parentNode contentUnitsWithReferencingNodeBounds:&computedBounds];
    [self computeAttributesFromElement:element
                                onNode:node
                     ignoredAttributes:nil];
    
    NSString* cxString = [element attributeForName:IJSVGAttributeCX].stringValue;
    NSString* cyString = [element attributeForName:IJSVGAttributeCY].stringValue;
    NSString* rString = [element attributeForName:IJSVGAttributeR].stringValue;
    
    IJSVGUnitLength* cXu = [IJSVGUnitLength unitWithString:cxString];
    IJSVGUnitLength* cYu = [IJSVGUnitLength unitWithString:cyString];
    IJSVGUnitLength* ru = [IJSVGUnitLength unitWithString:rString];
    
    if(contentUnits == IJSVGUnitObjectBoundingBox) {
        cXu = [cXu lengthWithUnitType:IJSVGUnitLengthTypePercentage];
        cYu = [cYu lengthWithUnitType:IJSVGUnitLengthTypePercentage];
        ru = [ru lengthWithUnitType:IJSVGUnitLengthTypePercentage];
    }
    
    CGFloat cX = [cXu computeValue:computedBounds.size.width];
    CGFloat cY = [cYu computeValue:computedBounds.size.height];
    CGFloat rX = [ru computeValue:computedBounds.size.width];
    CGFloat rY = [ru computeValue:computedBounds.size.height];
    CGRect rect = CGRectMake(cX - rX, cY - rY, rX * 2, rY * 2);
    CGPathRef nPath = CGPathCreateWithEllipseInRect(rect, NULL);
    node.path = (CGMutablePathRef)nPath;
    CGPathRelease(nPath);
    return node;
}

- (IJSVGNode*)parseGroupElement:(NSXMLElement*)element
                     parentNode:(IJSVGNode*)parentNode
{
    IJSVGGroup* node = [[[IJSVGGroup alloc] init] autorelease];
    node.adoptable = YES;
    node.type = IJSVGNodeTypeGroup;
    node.name = element.localName;
    node.parentNode = parentNode;
    [self computeAttributesFromElement:element
                                onNode:node
                     ignoredAttributes:nil];
    
    // recursively compute children
    [self computeElement:element
              parentNode:node];
    return node;
}

- (IJSVGNode*)parseRectElement:(NSXMLElement*)element
                    parentNode:(IJSVGNode*)parentNode
{
    IJSVGPath* node = [[[IJSVGPath alloc] init] autorelease];
    node.adoptable = YES;
    node.type = IJSVGNodeTypeRect;
    node.primitiveType = kIJSVGPrimitivePathTypeRect;
    node.name = element.localName;
    node.parentNode = parentNode;
    
    CGRect bounds = parentNode.bounds;
    CGRect proposedBounds = CGRectZero;
    IJSVGUnitType contentUnitType = [parentNode contentUnitsWithReferencingNodeBounds:&proposedBounds];
    
    NSString* widthString = [element attributeForName:IJSVGAttributeWidth].stringValue;
    NSString* heightString = [element attributeForName:IJSVGAttributeHeight].stringValue;
    NSString* xString = [element attributeForName:IJSVGAttributeX].stringValue;
    NSString* yString = [element attributeForName:IJSVGAttributeY].stringValue;
    NSString* rXString = [element attributeForName:IJSVGAttributeRX].stringValue;
    NSString* rYString = [element attributeForName:IJSVGAttributeRY].stringValue;
    
    // width and height
    IJSVGUnitLength* width = [IJSVGUnitLength unitWithString:widthString];
    IJSVGUnitLength* height = [IJSVGUnitLength unitWithString:heightString];

    // rect uses x and y as start of path, not move path object -_-
    IJSVGUnitLength* x = [IJSVGUnitLength unitWithString:xString];
    IJSVGUnitLength* y = [IJSVGUnitLength unitWithString:yString];

    // radius
    IJSVGUnitLength* rX = [IJSVGUnitLength unitWithString:rXString];
    IJSVGUnitLength* rY = [IJSVGUnitLength unitWithString:rYString];
    
    if(contentUnitType == IJSVGUnitObjectBoundingBox) {
        bounds = proposedBounds;
        width = [width lengthWithUnitType:IJSVGUnitLengthTypePercentage];
        height = [height lengthWithUnitType:IJSVGUnitLengthTypePercentage];
        x = [x lengthWithUnitType:IJSVGUnitLengthTypePercentage];
        y = [y lengthWithUnitType:IJSVGUnitLengthTypePercentage];
        rX = [rX lengthWithUnitType:IJSVGUnitLengthTypePercentage];
        rY = [rY lengthWithUnitType:IJSVGUnitLengthTypePercentage];
    }
    
    
    if(rY == nil) {
        rY = rX;
    }
    CGRect rect = CGRectMake([x computeValue:bounds.size.width],
                             [y computeValue:bounds.size.height],
                             [width computeValue:bounds.size.width],
                             [height computeValue:bounds.size.height]);
        
    CGPathRef nPath = CGPathCreateWithRoundedRect(rect, [rX computeValue:bounds.size.width],
                                                  [rY computeValue:bounds.size.height], NULL);
    node.path = (CGMutablePathRef)nPath;
    CGPathRelease(nPath);
    
    NSArray<NSString*>* ignoredAttributes = @[IJSVGAttributeX, IJSVGAttributeY];
    [self computeAttributesFromElement:element
                                onNode:node
                     ignoredAttributes:ignoredAttributes];
    return node;
}

- (IJSVGNode*)parseImageElement:(NSXMLElement*)element
                     parentNode:(IJSVGNode*)parentNode
{
    CGRect bounds = CGRectZero;
    IJSVGUnitType units = [parentNode contentUnitsWithReferencingNodeBounds:&bounds];
    IJSVGImage* image = [[[IJSVGImage alloc] init] autorelease];
    image.adoptable = YES;
    image.type = IJSVGNodeTypeImage;
    image.name = element.localName;
    image.parentNode = parentNode;
    
    [self computeAttributesFromElement:element
                                onNode:image
                     ignoredAttributes:nil];
    
    // load image from base64
    NSXMLNode* dataNode = [self resolveXLinkAttributeForElement:element];
    
    if(units == IJSVGUnitObjectBoundingBox) {
        image.width = [IJSVGUnitLength unitWithFloat:image.width.value*bounds.size.width];
        image.height = [IJSVGUnitLength unitWithFloat:image.height.value*bounds.size.height];
    }
    
    [image loadFromString:dataNode.stringValue];
    return image;
}

- (IJSVGNode*)parseUseElement:(NSXMLElement*)element
                   parentNode:(IJSVGNode*)parentNode
{
    NSString* xlink = [self resolveXLinkAttributeForElement:element].stringValue;
    NSString* xlinkID = [xlink substringFromIndex:1];
    if(xlinkID == nil) {
        return nil;
    }
    
    NSXMLElement* detachedElement = [self detachedElementWithIdentifier:xlinkID];
    
    // its important that we remove the xlink attribute or hell breaks loose
    NSXMLElement* elementWithoutXLink = [element.copy autorelease];
    [elementWithoutXLink removeAttributeForName:IJSVGAttributeXLink];
    NSXMLElement* shadowElement = [self mergedElement:elementWithoutXLink
                                 withReferenceElement:detachedElement];
    
    return [self parseElement:shadowElement
                   parentNode:parentNode];
}

- (IJSVGNode*)parsePatternElement:(NSXMLElement*)element
                       parentNode:(IJSVGNode*)parentNode
{
    IJSVGPattern* node = [[[IJSVGPattern alloc] init] autorelease];
    node.adoptable = NO;
    node.type = IJSVGNodeTypePattern;
    node.name = element.localName;
    node.parentNode = parentNode;
    node.units = IJSVGUnitObjectBoundingBox;
    node.contentUnits = IJSVGUnitUserSpaceOnUse;
    [self computeAttributesFromElement:element
                                onNode:node
                     ignoredAttributes:nil];
    [self computeElement:element
              parentNode:node];
    return node;
}

- (IJSVGNode*)parseClipPathElement:(NSXMLElement*)element
                        parentNode:(IJSVGNode*)parentNode
{
    IJSVGGroup* node = [[[IJSVGGroup alloc] init] autorelease];
    node.type = IJSVGNodeTypeClipPath;
    node.name = element.localName;
    node.parentNode = parentNode;
    node.adoptable = NO;
    node.units = IJSVGUnitObjectBoundingBox;
    node.contentUnits = IJSVGUnitUserSpaceOnUse;
    node.overflowVisibility = IJSVGOverflowVisibilityHidden;
    
    [self computeAttributesFromElement:element
                                onNode:node
                     ignoredAttributes:nil];
    
    [self computeElement:element
              parentNode:node];
    return node;
}

- (IJSVGNode*)parseMaskElement:(NSXMLElement*)element
                    parentNode:(IJSVGNode*)parentNode
{
    IJSVGGroup* node = [[[IJSVGGroup alloc] init] autorelease];
    node.type = IJSVGNodeTypeMask;
    node.name = element.localName;
    node.parentNode = parentNode;
    node.adoptable = NO;
    node.units = IJSVGUnitObjectBoundingBox;
    node.contentUnits = IJSVGUnitUserSpaceOnUse;
    node.overflowVisibility = IJSVGOverflowVisibilityHidden;
    
    [self computeAttributesFromElement:element
                                onNode:node
                     ignoredAttributes:nil];
    
    [self computeElement:element
              parentNode:node];
    return node;
}

- (void)parseDefElement:(NSXMLElement*)element
             parentNode:(IJSVGNode*)parentNode
{
    for(NSXMLElement* childElement in element.children) {
        NSString* identifier = [childElement attributeForName:IJSVGAttributeID].stringValue;
        if(identifier != nil) {
            [self detachElement:childElement
                 withIdentifier:identifier];
        }
        IJSVGNodeType type = [IJSVGNode typeForString:childElement.localName
                                                 kind:childElement.kind];
        // we always want style elements to be passed
        switch(type) {
            case IJSVGNodeTypeStyle: {
                [self parseElement:childElement
                        parentNode:parentNode];
                break;
            }
            default:
                break;
        }
    }
}

- (void)parseTitleElement:(NSXMLElement*)element
               parentNode:(IJSVGNode*)parentNode
{
    parentNode.title = element.stringValue;
}

- (void)parseDescElement:(NSXMLElement*)element
               parentNode:(IJSVGNode*)parentNode
{
    parentNode.desc = element.stringValue;
}

#pragma mark XLink

- (NSXMLNode*)resolveXLinkAttributeForElement:(NSXMLElement*)element
{
    NSString* const namespaceURI = @"http://www.w3.org/1999/xlink";
    NSXMLNode* attributeNode = [element attributeForLocalName:IJSVGAttributeHref
                                                          URI:namespaceURI];
    if (attributeNode == nil) {
        attributeNode = [element attributeForName:IJSVGAttributeXLink];
    }
    return attributeNode;
}

- (NSString*)resolveXLinkAttributeStringForElement:(NSXMLElement*)element
{
    NSXMLNode* node = [self resolveXLinkAttributeForElement:element];
    if(node != nil) {
        return [node.stringValue substringFromIndex:1];
    }
    return nil;
}

#pragma mark Command Parsing

- (void)parsePolyPoints:(NSString*)points
               intoPath:(IJSVGPath*)path
              closePath:(BOOL)closePath
{
    NSInteger count = 0;
    CGFloat* params = [IJSVGUtils commandParameters:points
                                              count:&count];

    // error occured, free the params
    if ((count % 2) != 0) {
        free(params);
        return;
    }
    
    const int defBufferSize = 10;
    char* buffer;
    asprintf(&buffer, "M%f %f L", params[0], params[1]);
    
    // compute a default buffer - bSize is strlen + 1 for null byte
    size_t bSize = strlen(buffer) + 1;
    size_t strLength = bSize - 1;
    
    // for every pair of coordinates
    for(int i = 2; i < count; i+= 2) {
        char* subbuf;
        asprintf(&subbuf, "%f %f ", params[i], params[i + 1]);
        size_t sSize = strlen(subbuf);
        
        // if the new size of the string is large than the buffer
        // increase the buffer up another def size - note, we always
        // plus 2 incase the close path needs to be appended on the end
        if((strLength + sSize + 2) > bSize) {
            size_t nLength = MAX(sSize, defBufferSize) + 2;
            buffer = realloc(buffer, sizeof(char)*(bSize+nLength));
            bSize += nLength;
        }
        
        // append the string onto the buffer, increment the
        // string length and free the subbuffer memory
        strcat(buffer, subbuf);
        strLength += sSize;
        (void)free(subbuf), subbuf = NULL;
    }
    
    // append the close path if required
    if(closePath == YES) {
        strcat(buffer, "z");
    }
    
    // actually perform the parse
    [self parsePathCommandDataBuffer:buffer
                            intoPath:path];
    
    // free the params
    (void)free(buffer), buffer = NULL;
    (void)free(params), params = NULL;
}


- (void)parsePathCommandDataBuffer:(const char*)buffer
                          intoPath:(IJSVGPath*)path
{
    NSUInteger len = strlen(buffer);
    NSUInteger lastIndex = len - 1;

    // make sure we plus 1 for the null byte
    char* charBuffer = (char*)malloc(sizeof(char)*(len + 1));
    NSInteger start = 0;
    IJSVGCommand* _currentCommand = nil;
    for (NSInteger i = 0; i < len; i++) {
        char nextChar = buffer[i + 1];
        BOOL atEnd = i == lastIndex;
        BOOL isStartCommand = IJSVGIsLegalCommandCharacter(nextChar);
        if (isStartCommand == YES || atEnd == YES) {

            // copy memory from current buffer
            NSInteger index = ((i + 1) - start);
            memcpy(&charBuffer[0], &buffer[start], sizeof(char)*index);
            charBuffer[index] = '\0';

            // create the command from the substring
            unsigned long length = index + 1;
            size_t mlength = sizeof(char)*length;
            char* commandString = (char*)malloc(mlength);
            memcpy(commandString, &charBuffer[0], mlength);

            // reset start position
            start = (i + 1);

            // previous command is actual subcommand
            IJSVGCommand* previousCommand = _currentCommand.subCommands.lastObject;
            IJSVGCommand* cCommand = [self parseCommandStringBuffer:commandString
                                                    previousCommand:previousCommand
                                                           intoPath:path];
            
            // free the memory as at this point, we are done with it
            (void)free(commandString), commandString = NULL;

            // retain the current one
            if (cCommand != nil) {
                _currentCommand = cCommand;
            }
        }
    }
    (void)free(charBuffer), charBuffer = NULL;
}

- (void)parsePathCommandData:(NSString*)command
                    intoPath:(IJSVGPath*)path
{
    // invalid command
    if (command == nil || command.length == 0) {
        return;
    }

    // allocate memory for the string buffer for reading
    const char* buffer = command.UTF8String;
    [self parsePathCommandDataBuffer:buffer
                            intoPath:path];
}

- (IJSVGCommand*)parseCommandStringBuffer:(const char*)buffer
                          previousCommand:(IJSVGCommand*)previousCommand
                                 intoPath:(IJSVGPath*)path
{
    // work out the last command - the reason this is so long is because the command
    // could be a series of the same commands, so work it out by the number of parameters
    // there is per command string
    IJSVGCommand* preCommand = nil;
    if (previousCommand) {
        preCommand = previousCommand;
    }

    // main commands
    //    Class commandClass = [IJSVGCommand classFor]
    Class commandClass = [IJSVGCommand commandClassForCommandChar:buffer[0]];
    IJSVGCommand* command = nil;
    command = (IJSVGCommand*)[[[commandClass alloc] initWithCommandStringBuffer:buffer
                                                                     dataStream:_commandDataStream] autorelease];
    for (IJSVGCommand* subCommand in command.subCommands) {
        [command.class runWithParams:subCommand.parameters
                          paramCount:subCommand.parameterCount
                             command:subCommand
                     previousCommand:preCommand
                                type:subCommand.type
                                path:path];
        preCommand = subCommand;
    }
    return command;
}


@end
