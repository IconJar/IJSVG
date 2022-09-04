//
//  IJSVGParser.m
//  IconJar
//
//  Created by Curtis Hard on 30/08/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVG.h>
#import <IJSVG/IJSVGParser.h>
#import <IJSVG/IJSVGUnitRect.h>
#import <IJSVG/IJSVGUnitPoint.h>
#import <IJSVG/IJSVGThreadManager.h>

NSString* const IJSVGStringObjectBoundingBox = @"objectBoundingBox";
NSString* const IJSVGStringUserSpaceOnUse = @"userSpaceOnUse";
NSString* const IJSVGStringNone = @"none";
NSString* const IJSVGStringRound = @"round";
NSString* const IJSVGStringSquare = @"square";
NSString* const IJSVGStringBevel = @"bevel";
NSString* const IJSVGStringButt = @"butt";
NSString* const IJSVGStringMiter = @"miter";
NSString* const IJSVGStringInherit = @"inherit";
NSString* const IJSVGStringEvenOdd = @"evenodd";

NSString* const IJSVGAttributeVersion = @"version";
NSString* const IJSVGAttributeXMLNS = @"xmlns";
NSString* const IJSVGAttributeXMLNSXlink = @"xmlns:xlink";
NSString* const IJSVGAttributeViewBox = @"viewBox";
NSString* const IJSVGAttributePreserveAspectRatio = @"preserveAspectRatio";
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
NSString* const IJSVGAttributeClipPathUnits = @"clipPathUnits";
NSString* const IJSVGAttributeClipRule = @"clip-rule";
NSString* const IJSVGAttributeMask = @"mask";
NSString* const IJSVGAttributeGradientUnits = @"gradientUnits";
NSString* const IJSVGAttributePatternUnits = @"patternUnits";
NSString* const IJSVGAttributePatternContentUnits = @"patternContentUnits";
NSString* const IJSVGAttributePatternTransform = @"patternTransform";
NSString* const IJSVGAttributeMaskUnits = @"maskUnits";
NSString* const IJSVGAttributeMaskContentUnits = @"maskContentUnits";
NSString* const IJSVGAttributeTransform = @"transform";
NSString* const IJSVGAttributeGradientTransform = @"gradientTransform";
NSString* const IJSVGAttributeUnicode = @"unicode";
NSString* const IJSVGAttributeStrokeLineCap = @"stroke-linecap";
NSString* const IJSVGAttributeStrokeLineJoin = @"stroke-linejoin";
NSString* const IJSVGAttributeStroke = @"stroke";
NSString* const IJSVGAttributeStrokeDashArray = @"stroke-dasharray";
NSString* const IJSVGAttributeStrokeMiterLimit = @"stroke-miterlimit";
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
NSString* const IJSVGAttributeFR = @"fr";
NSString* const IJSVGAttributePoints = @"points";
NSString* const IJSVGAttributeOffset = @"offset";
NSString* const IJSVGAttributeStopColor = @"stop-color";
NSString* const IJSVGAttributeStopOpacity = @"stop-opacity";
NSString* const IJSVGAttributeHref = @"href";
NSString* const IJSVGAttributeOverflow = @"overflow";
NSString* const IJSVGAttributeFilter = @"filter";
NSString* const IJSVGAttributeStdDeviation = @"stdDeviation";
NSString* const IJSVGAttributeIn = @"in";
NSString* const IJSVGAttributeEdgeMode = @"edgeMode";
NSString* const IJSVGAttributeMarker = @"marker";

@implementation IJSVGParser

static NSDictionary* _IJSVGAttributeDictionaryFloats = nil;
static NSDictionary* _IJSVGAttributeDictionaryNodes = nil;
static NSDictionary* _IJSVGAttributeDictionaryUnits = nil;
static NSDictionary* _IJSVGAttributeDictionaryTransforms = nil;
static NSArray* _IJSVGUseElementOverwritingAttributes = nil;

IJSVGParserMallocBuffers* IJSVGParserMallocBuffersCreate(void)
{
    IJSVGParserMallocBuffers* buffers = NULL;
    buffers = (IJSVGParserMallocBuffers*)malloc(sizeof(IJSVGParserMallocBuffers));
    buffers->nodeType = (char*)malloc(sizeof(char)*15); // 14 + 1
    return buffers;
}

void IJSVGParserMallocBuffersFree(IJSVGParserMallocBuffers* buffers)
{
    (void)free(buffers->nodeType), buffers->nodeType = NULL;
    (void)free(buffers);
}

+ (void)load
{
    _IJSVGAttributeDictionaryFloats = @{
        IJSVGAttributeX : @"x",
        IJSVGAttributeY : @"y",
        IJSVGAttributeWidth : @"width",
        IJSVGAttributeHeight : @"height",
        IJSVGAttributeOpacity : @"opacity",
        IJSVGAttributeStrokeOpacity : @"strokeOpacity",
        IJSVGAttributeStrokeWidth : @"strokeWidth",
        IJSVGAttributeStrokeDashOffset : @"strokeDashOffset",
        IJSVGAttributeStrokeMiterLimit : @"strokeMiterLimit",
        IJSVGAttributeFillOpacity : @"fillOpacity" };
    _IJSVGAttributeDictionaryNodes = @{
        IJSVGAttributeClipPath : @"clipPath",
        IJSVGAttributeMask : @"mask" };
    _IJSVGAttributeDictionaryUnits = @{
        IJSVGAttributeGradientUnits : @"units",
        IJSVGAttributeMaskUnits : @"units",
        IJSVGAttributePatternUnits : @"units",
        IJSVGAttributeClipPathUnits: @"contentUnits",
        IJSVGAttributeMaskContentUnits : @"contentUnits",
        IJSVGAttributePatternContentUnits : @"contentUnits"
    };
    _IJSVGAttributeDictionaryTransforms = @{
        IJSVGAttributeTransform : @"transforms",
        IJSVGAttributeGradientTransform : @"transforms",
        IJSVGAttributePatternTransform : @"transforms"
    };
    _IJSVGUseElementOverwritingAttributes = @[IJSVGAttributeX, IJSVGAttributeY,
                                              IJSVGAttributeWidth, IJSVGAttributeHeight,
                                              IJSVGAttributeHref];
}

+ (IJSVGParser*)parserForFileURL:(NSURL*)aURL
{
    return [self.class parserForFileURL:aURL
                                  error:nil];
}

+ (IJSVGParser*)parserForFileURL:(NSURL*)aURL
                           error:(NSError**)error
{
    return [[self.class alloc] initWithFileURL:aURL
                                         error:error];
}

- (id)initWithSVGString:(NSString*)string
                  error:(NSError**)error
{
    if((self = [super init]) != nil) {

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
        if(anError != nil) {
            return [self _handleErrorWithCode:IJSVGErrorParsingFile
                                        error:error];
        }

        // attempt to parse the file
        [self begin];

        // check the actual parsed SVG
        anError = nil;
        if([self _validateParse:&anError] == NO) {
            *error = anError;
            return nil;
        }

        // we have actually finished with the document at this point
        // so just get rid of it
        _document = nil;
    }
    return self;
}

+ (BOOL)isDataSVG:(NSData*)data
{
    @try {
        NSError* error;
        NSXMLDocument* doc = [[NSXMLDocument alloc] initWithData:data
                                                        options:0
                                                           error:&error];
        return doc != nil && error == nil;
    } @catch (NSException* exception) {
    }
    return NO;
}

- (id)initWithFileURL:(NSURL*)aURL
                error:(NSError**)error
{
    NSError* anError = nil;
    NSStringEncoding encoding;
    NSString* str = [NSString stringWithContentsOfFile:aURL.path
                                          usedEncoding:&encoding
                                                 error:&anError];

    // error reading file
    if(str == nil) {
        return [self _handleErrorWithCode:IJSVGErrorReadingFile
                                    error:error];
    }

    return [self initWithSVGString:str
                             error:error];
}

- (void*)_handleErrorWithCode:(NSUInteger)code
                        error:(NSError**)error
{
    if(error != nil) {
        *error = [[NSError alloc] initWithDomain:IJSVGErrorDomain
                                            code:code
                                        userInfo:nil];
    }
    return nil;
}

- (BOOL)_validateParse:(NSError**)error
{
    if(_rootNode.viewBox.size.isZeroSize == YES) {
        if(error != NULL) {
            *error = [[NSError alloc] initWithDomain:IJSVGErrorDomain
                                                code:IJSVGErrorParsingSVG
                                            userInfo:nil];
        }
        return NO;
    }
    return YES;
}

- (void)begin
{
    // setup basics to begin with
    _styleSheet = [[IJSVGStyleSheet alloc] init];
    IJSVGThreadManager* manager = IJSVGThreadManager.currentManager;
    _threadManager = manager;
    _commandDataStream = manager.pathDataStream;
    _detachedReferences = [[NSMutableDictionary alloc] init];
    _rootNode = [[IJSVGRootNode alloc] init];
    IJSVGNodeParserPostProcessBlock postProcessBlock = nil;
    [self parseSVGElement:_document.rootElement
                 ontoNode:_rootNode
               parentNode:nil
         postProcessBlock:&postProcessBlock];
    if(postProcessBlock != nil) {
        postProcessBlock();
    }
    [_rootNode postProcess];
    _detachedReferences = nil;
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
                   parentNode:_rootNode
                    recursive:YES];
    }
}

- (void)computeViewBoxForRootNode:(IJSVGRootNode*)node
{
    if(node.viewBox == nil) {
        CGFloat width = node.width.value;
        CGFloat height = node.height.value;
        
        if(height == 0.f && width != 0.f) {
            height = width;
        } else if(width == 0.f && height != 0.f) {
            width = height;
        }
        // nothing we can do, its a nil viewBox and has
        // no width or height
        if(width == 0.f && height == 0.f) {
            return;
        }
        node.viewBox = [IJSVGUnitRect rectWithX:0.f y:0.f
                                          width:width
                                         height:height];
    }

    IJSVGIntrinsicDimensions dimensions = IJSVGIntrinsicDimensionNone;
    IJSVGUnitLength* wl = node.viewBox.size.width;
    IJSVGUnitLength* hl = node.viewBox.size.height;
    if(node.width != nil) {
        dimensions|= IJSVGIntrinsicDimensionWidth;
        wl = node.width;
    }
    if(node.height != nil) {
        dimensions |= IJSVGIntrinsicDimensionHeight;
        hl = node.height;
    }

    // store the width and height
    node.intrinsicDimensions = dimensions;
    node.intrinsicSize = [IJSVGUnitSize sizeWithWidth:wl
                                               height:hl];
}

- (IJSVGNodeParserPostProcessBlock)computeAttributesFromElement:(NSXMLElement*)element
                                                         onNode:(IJSVGNode*)node
                                              ignoredAttributes:(NSArray<NSString*>*)ignoredAttributes
{
    IJSVGStyleSheetStyle* styleSheet = nil;
    __block IJSVGStyleSheetStyle* nodeStyle = nil;
    
    // precache the attributes, this is quicker than asking for it each time
    NSMutableDictionary<NSString*, NSString*>* attributes = nil;
    attributes = [[NSMutableDictionary alloc] initWithCapacity:element.attributes.count];
    for(NSXMLNode* attributeNode in element.attributes) {
        attributes[attributeNode.name] = attributeNode.stringValue;
    }
    
    CGRect bounds = CGRectZero;
    IJSVGUnitType units = [node.parentNode contentUnitsWithReferencingNodeBounds:&bounds];

    // helper for setting an attribute
    typedef void (^IJSVGAttributeParseBlock)(NSString*);
    BOOL (^IJSVGAttributeParse)(const NSString*, IJSVGAttributeParseBlock) =
    ^(NSString* key, IJSVGAttributeParseBlock parseBlock) {
        if([ignoredAttributes containsObject:key] == YES) {
            return NO;
        }
        NSString* value = [nodeStyle property:key] ?: attributes[key];
        if(value != nil && value.length != 0) {
            parseBlock(value);
            return YES;
        }
        return NO;
    };
    
    // helper for settings attributes
    typedef id (^IJSVGAttributeComputableParseBlock)(NSString*);
    void (^IJSVGAttributesParse)(NSDictionary<NSString*, NSString*>*, IJSVGAttributeComputableParseBlock) =
    ^(NSDictionary<NSString*, NSString*>* dictionary, IJSVGAttributeComputableParseBlock parseBlock) {
        [dictionary enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key,
                                                        NSString * _Nonnull obj,
                                                        BOOL * _Nonnull stop) {
            IJSVGAttributeParse(key, ^(NSString* value) {
                [node setValue:parseBlock(value)
                        forKey:obj];
            });
        }];
    };
    
    // identifier
    IJSVGAttributeParse(IJSVGAttributeID, ^(NSString* value) {
        node.identifier = value;
        [self detachElement:element
             withIdentifier:value];
    });
    
    // class list
    IJSVGAttributeParse(IJSVGAttributeClass, ^(NSString* value) {
        NSArray* list = [value ijsvg_componentsSeparatedByChars:" "];
        node.className = value;
        node.classNameList = [NSSet setWithArray:list];
    });
    
    
    // style
    if(_styleSheet != nil) {
        styleSheet = [_styleSheet styleForNode:node];
    }
    
    IJSVGAttributeParse(IJSVGAttributeStyle, ^(NSString* value) {
        nodeStyle = [IJSVGStyleSheetStyle parseStyleString:value];
    });
    
    if(styleSheet != nil) {
        nodeStyle = [styleSheet mergedStyle:nodeStyle];
    }
        
    // floating point numbers
    IJSVGAttributesParse(_IJSVGAttributeDictionaryFloats, ^id (NSString* value) {
        return [IJSVGUnitLength unitWithString:value];
    });
    
    // nodes
    IJSVGNodeParserPostProcessBlock postProcessBlock = ^{
        IJSVGAttributesParse(_IJSVGAttributeDictionaryNodes, ^id (NSString* value) {
            NSString* identifier = [IJSVGUtils defURL:value];
            if(identifier != nil) {
                return [self computeDetachedNodeWithIdentifier:identifier
                                               referencingNode:node];
            }
            return nil;
        });
    };
    
    // units
    IJSVGAttributesParse(_IJSVGAttributeDictionaryUnits, ^id (NSString* value) {
        return @([IJSVGUtils unitTypeForString:value]);
    });
    
    // transforms
    IJSVGAttributesParse(_IJSVGAttributeDictionaryTransforms, ^id (NSString* value) {
        NSMutableArray<IJSVGTransform*>* transforms = [[NSMutableArray alloc] init];
        [transforms addObjectsFromArray:[IJSVGTransform transformsForString:value
                                                                      units:units
                                                                     bounds:bounds]];
        if(node.transforms != nil) {
            [transforms addObjectsFromArray:node.transforms];
        }
        return transforms;
    });

    // unicode
    IJSVGAttributeParse(IJSVGAttributeUnicode, ^(NSString* value) {
        node.unicode = [NSString stringWithFormat:@"%04x", [value characterAtIndex:0]];
    });

    // linecap
    IJSVGAttributeParse(IJSVGAttributeStrokeLineCap, ^(NSString* value) {
        node.lineCapStyle = [IJSVGUtils lineCapStyleForString:value];
    });

    // line join
    IJSVGAttributeParse(IJSVGAttributeStrokeLineJoin, ^(NSString* value) {
        node.lineJoinStyle = [IJSVGUtils lineJoinStyleForString:value];
    });
    
    // stroke color
    IJSVGAttributeParse(IJSVGAttributeStroke, ^(NSString* value) {
        // todo
        NSString* fillIdentifier = [IJSVGUtils defURL:value];
        if(fillIdentifier != nil) {
            IJSVGNode* object = [self computeDetachedNodeWithIdentifier:fillIdentifier
                                                        referencingNode:node];
            node.stroke = object;
            return;
        }
        NSColor* color = [IJSVGColor colorFromString:value];
        IJSVGColorNode* colorNode = (IJSVGColorNode*)[IJSVGColorNode colorNodeWithColor:color];
        if(color == nil) {
            colorNode.isNoneOrTransparent = [IJSVGColor isNoneOrTransparent:value];
        }
        node.stroke = colorNode;
    });

    // stroke dash array
    IJSVGAttributeParse(IJSVGAttributeStrokeDashArray, ^(NSString* value) {
        // nothing specified
        if([value isEqualToString:IJSVGStringNone]) {
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
                                                        referencingNode:node];
            node.fill = object;
            return;
        }
        NSColor* color = [IJSVGColor colorFromString:value];
        IJSVGColorNode* colorNode = (IJSVGColorNode*)[IJSVGColorNode colorNodeWithColor:color];
        if(color == nil) {
            colorNode.isNoneOrTransparent = [IJSVGColor isNoneOrTransparent:value];
        }
        node.fill = colorNode;
    });
    
    // fill opacity
    IJSVGAttributeParse(IJSVGAttributeFillOpacity, ^(NSString* value) {
        node.fillOpacity = [IJSVGUnitLength unitWithString:value];
    });

    // blendmode
    IJSVGAttributeParse(IJSVGAttributeBlendMode, ^(NSString* value) {
        node.blendMode = [IJSVGUtils blendModeForString:value];
    });

    // fill rule
    IJSVGAttributeParse(IJSVGAttributeFillRule, ^(NSString* value) {
        node.windingRule = [IJSVGUtils windingRuleForString:value];
    });
    
    // clip rule
    IJSVGAttributeParse(IJSVGAttributeClipRule, ^(NSString* value) {
        node.clipRule = [IJSVGUtils windingRuleForString:value];
    });
    
    // display
    IJSVGAttributeParse(IJSVGAttributeDisplay, ^(NSString* value) {
        if([value.lowercaseString isEqualToString:IJSVGStringNone]) {
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
        NSColor* color = [IJSVGColor colorFromString:value];
        IJSVGColorNode* colorNode = (IJSVGColorNode*)[IJSVGColorNode colorNodeWithColor:color];
        if(color == nil) {
            colorNode.isNoneOrTransparent = [IJSVGColor isNoneOrTransparent:value];
        } else if(node.fillOpacity.value != 1.f) {
            color = [IJSVGColor changeAlphaOnColor:color
                                                to:node.fillOpacity.value];
            colorNode.color = color;
        }
        node.fill = colorNode;
    });
    
    // overflow
    IJSVGAttributeParse(IJSVGAttributeOverflow, ^(NSString* value) {
        if([value.lowercaseString isEqualToString:@"hidden"]) {
            node.overflowVisibility = IJSVGOverflowVisibilityHidden;
        } else {
            node.overflowVisibility = IJSVGOverflowVisibilityVisible;
        }
    });
    
    // viewBox because this somehow is a thing
    IJSVGAttributeParse(IJSVGAttributeViewBox, ^(NSString* value) {
        CGFloat* floats = [IJSVGUtils parseViewBox:value];
        node.viewBox = [IJSVGUnitRect rectWithX:floats[0]
                                              y:floats[1]
                                          width:floats[2]
                                         height:floats[3]];
        free(floats);
    });
    
    // preserveAspectRatio
    IJSVGAttributeParse(IJSVGAttributePreserveAspectRatio, ^(NSString* value) {
        IJSVGViewBoxMeetOrSlice meetOrSlice;
        IJSVGViewBoxAlignment alignment = [IJSVGViewBox alignmentForString:value
                                                               meetOrSlice:&meetOrSlice];
        node.viewBoxAlignment = alignment;
        node.viewBoxMeetOrSlice = meetOrSlice;
    });
        
    // filters
    IJSVGAttributeParse(IJSVGAttributeFilter, ^(NSString* value) {
        NSString* filterIdentifier = [IJSVGUtils defURL:value];
        if(filterIdentifier != nil) {
            IJSVGNode* filter = [self computeDetachedNodeWithIdentifier:filterIdentifier
                                                        referencingNode:node];
            node.filter = (IJSVGFilter*)filter;
        }
    });
    
    if(_threadManager.featureFlags.filters.enabled == YES &&
       node.type == IJSVGNodeTypeFilterEffect) {
        IJSVGFilterEffect* effect = (IJSVGFilterEffect*)node;
                
        // in
        IJSVGAttributeParse(IJSVGAttributeIn, ^(NSString* value) {
            effect.source = [IJSVGFilterEffect sourceForString:value];
            if(effect.source == IJSVGFilterEffectSourcePrimitiveReference) {
                effect.primitiveReference = value;
            }
        });
        
        // edge mode
        IJSVGAttributeParse(IJSVGAttributeEdgeMode, ^(NSString* value) {
            effect.edgeMode = [IJSVGFilterEffect edgeModeForString:value];
        });
        
        // deviation
        IJSVGAttributeParse(IJSVGAttributeStdDeviation, ^(NSString* value) {
            effect.stdDeviation = [IJSVGUnitLength unitWithString:value];
        });
    }
    
    return postProcessBlock;
}

- (IJSVGNode*)parseElement:(NSXMLElement*)element
                parentNode:(IJSVGNode*)node
{
    NSString* name = element.localName;
    NSXMLNodeKind nodeKind = element.kind;
    IJSVGNodeType nodeType = [IJSVGNode typeForString:name
                                                 kind:nodeKind];
        
    [self parseDefElement:element
               parentNode:node
                recursive:NO];
    
    IJSVGNodeParserPostProcessBlock postProcessBlock = nil;
    IJSVGNode* computedNode = nil;
    switch(nodeType) {
        case IJSVGNodeTypeForeignObject: {
            // do nothing for foreign objects, we dont support them
            break;
        }
            
        case IJSVGNodeTypeStyle: {
            [self parseStyleElement:element
                         parentNode:node];
            break;
        }
            
        // we can treat unkown element as groups, as some people
        // thought it was a good idea to stick HTML within the markup
        case IJSVGNodeTypeUnknown:
        case IJSVGNodeTypeSwitch:
        case IJSVGNodeTypeGroup: {
            computedNode = [self parseGroupElement:element
                                        parentNode:node
                                          nodeType:nodeType
                                  postProcessBlock:&postProcessBlock];
            break;
        }
        case IJSVGNodeTypeSVG: {
            computedNode = [self parseSVGElement:element
                                      parentNode:node
                                postProcessBlock:&postProcessBlock];
            break;
        }
        case IJSVGNodeTypePath: {
            computedNode = [self parsePathElement:element
                                       parentNode:node
                                 postProcessBlock:&postProcessBlock];
            break;
        }
        case IJSVGNodeTypeCircle: {
            computedNode = [self parseCircleElement:element
                                         parentNode:node
                                   postProcessBlock:&postProcessBlock];
            break;
        }
        case IJSVGNodeTypeEllipse: {
            computedNode = [self parseEllipseElement:element
                                          parentNode:node
                                    postProcessBlock:&postProcessBlock];
            break;
        }
        case IJSVGNodeTypeRect: {
            computedNode = [self parseRectElement:element
                                       parentNode:node
                                 postProcessBlock:&postProcessBlock];
            break;
        }
        case IJSVGNodeTypePolygon: {
            computedNode = [self parsePolygonElement:element
                                          parentNode:node
                                    postProcessBlock:&postProcessBlock];
            break;
        }
        case IJSVGNodeTypePolyline: {
            computedNode = [self parsePolyLineElement:element
                                           parentNode:node
                                     postProcessBlock:&postProcessBlock];
            break;
        }
        case IJSVGNodeTypeLine: {
            computedNode = [self parseLineElement:element
                                       parentNode:node
                                 postProcessBlock:&postProcessBlock];
            break;
        }
        case IJSVGNodeTypeImage: {
            computedNode = [self parseImageElement:element
                                        parentNode:node
                                  postProcessBlock:&postProcessBlock];
            break;
        }
        case IJSVGNodeTypePattern: {
            computedNode = [self parsePatternElement:element
                                          parentNode:node
                                    postProcessBlock:&postProcessBlock];
            break;
        }
        case IJSVGNodeTypeClipPath: {
            computedNode = [self parseClipPathElement:element
                                           parentNode:node
                                     postProcessBlock:&postProcessBlock];
            break;
        }
        case IJSVGNodeTypeMask: {
            computedNode = [self parseMaskElement:element
                                       parentNode:node
                                 postProcessBlock:&postProcessBlock];
            break;
        }
        case IJSVGNodeTypeUse: {
            computedNode = [self parseUseElement:element
                                      parentNode:node
                                postProcessBlock:&postProcessBlock];
            break;
        }
        case IJSVGNodeTypeLinearGradient: {
            computedNode = [self parseLinearGradientElement:element
                                                 parentNode:node
                                           postProcessBlock:&postProcessBlock];
            break;
        }
        case IJSVGNodeTypeRadialGradient: {
            computedNode = [self parseRadialGradientElement:element
                                                 parentNode:node
                                           postProcessBlock:&postProcessBlock];
            break;
        }
        case IJSVGNodeTypeStop: {
            computedNode = [self parseStopElement:element
                                       parentNode:node
                                 postProcessBlock:&postProcessBlock];
            break;
        }
        case IJSVGNodeTypeTitle: {
            [self parseTitleElement:element
                         parentNode:node
                   postProcessBlock:&postProcessBlock];
            break;
        }
        case IJSVGNodeTypeDesc: {
            [self parseDescElement:element
                        parentNode:node
                  postProcessBlock:&postProcessBlock];
            break;
        }
        case IJSVGNodeTypeFilter: {
            if(_threadManager.featureFlags.filters.enabled == YES) {
                computedNode = [self parseFilterElement:element
                                             parentNode:node
                                       postProcessBlock:&postProcessBlock];
            }
            break;
        }
        case IJSVGNodeTypeFilterEffect: {
            if(_threadManager.featureFlags.filters.enabled == YES) {
                computedNode = [self parseFilterEffectElement:element
                                                   parentNode:node
                                             postProcessBlock:&postProcessBlock];
            }
            break;
        }
        case IJSVGNodeTypeDef: {
            // defs have already been handled by the parseDefElement
            // call further up
            break;
        }
        default:
            break;
    }
    
    // some nodes require post processing once their tree has been worked out
    if(postProcessBlock != nil) {
        postProcessBlock();
    }
    
    // perform any post processing
    [computedNode postProcess];
    
    return computedNode;
}

- (void)computeElement:(NSXMLElement*)element
            parentNode:(IJSVGNode*)node
{
    [self computeDefsForElement:element
                     parentNode:node];
    for(NSXMLElement* childElement in element.children) {
        [self parseElement:childElement
                parentNode:node];
    }
}

#pragma mark Detaching nodes
- (void)detachElement:(NSXMLElement*)element
       withIdentifier:(NSString*)identifier
{
    // we can just store the reference for later, we used to copy at this point
    // but realised there can be a lot of elements with IDs that dont actually ever
    // get used, so just store reference and let the usage deal with copy and detach
    _detachedReferences[identifier] = element;
}

- (NSXMLElement*)detachedElementWithIdentifier:(NSString*)identifier
{
    return _detachedReferences[identifier];
}

- (IJSVGNode*)computeDetachedNodeWithIdentifier:(NSString*)identifier
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
    NSXMLElement* copy = reference.copy;
    for (__strong NSXMLNode* attribute in element.attributes) {
        [copy removeAttributeForName:attribute.name];
        attribute = attribute.copy;
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

- (IJSVGNode*)parseFilterElement:(NSXMLElement*)element
                      parentNode:(IJSVGNode*)parentNode
                postProcessBlock:(IJSVGNodeParserPostProcessBlock*)postProcessBlock
{
    IJSVGFilter* node = [[IJSVGFilter alloc] init];
    node.type = IJSVGNodeTypeFilter;
    node.name = element.localName;
    
    *postProcessBlock = [self computeAttributesFromElement:element
                                                    onNode:node
                                         ignoredAttributes:nil];
    
    [self computeElement:element
              parentNode:node];
    return node;
}

- (IJSVGNode*)parseFilterEffectElement:(NSXMLElement*)element
                            parentNode:(IJSVGNode*)parentNode
                      postProcessBlock:(IJSVGNodeParserPostProcessBlock*)postProcessBlock
{
    Class effectClass = [IJSVGFilterEffect effectClassForElementName:element.localName];
    IJSVGFilterEffect* node = [[effectClass alloc] init];
    node.type = IJSVGNodeTypeFilterEffect;
    node.name = element.localName;

    if([parentNode isKindOfClass:IJSVGGroup.class] == YES) {
        IJSVGGroup* group = (IJSVGGroup*)parentNode;
        [group addChild:node];
    }
    
    *postProcessBlock = [self computeAttributesFromElement:element
                                                    onNode:node
                                         ignoredAttributes:nil];
    
    [self computeElement:element
              parentNode:node];
    return node;
}

- (IJSVGNode*)parseLinearGradientElement:(NSXMLElement*)element
                              parentNode:(IJSVGNode*)parentNode
                        postProcessBlock:(IJSVGNodeParserPostProcessBlock*)postProcessBlock
{
    IJSVGLinearGradient* node = [[IJSVGLinearGradient alloc] init];
    node.units = IJSVGUnitObjectBoundingBox;
    node.type = IJSVGNodeTypeLinearGradient;
    node.name = element.localName;
    [node addTraits:IJSVGNodeTraitPaintable];
    
    NSString* xLinkID = [self resolveXLinkAttributeStringForElement:element];
    if(xLinkID != nil) {
        NSXMLElement* detachedElement = [self detachedElementWithIdentifier:xLinkID];
        element = [self mergedElement:element
                 withReferenceElement:detachedElement];
    }
    
    *postProcessBlock = [self computeAttributesFromElement:element
                                                    onNode:node
                                         ignoredAttributes:nil];
    [self computeElement:element
              parentNode:node];
    [IJSVGLinearGradient parseGradient:element
                              gradient:node];
    return node;
}

- (IJSVGNode*)parseRadialGradientElement:(NSXMLElement*)element
                              parentNode:(IJSVGNode*)parentNode
                        postProcessBlock:(IJSVGNodeParserPostProcessBlock*)postProcessBlock
{
    IJSVGRadialGradient* node = [[IJSVGRadialGradient alloc] init];
    node.units = IJSVGUnitObjectBoundingBox;
    node.type = IJSVGNodeTypeRadialGradient;
    node.name = element.localName;
    [node addTraits:IJSVGNodeTraitPaintable];
    
    NSString* xLinkID = [self resolveXLinkAttributeStringForElement:element];
    if(xLinkID != nil) {
        NSXMLElement* detachedElement = [self detachedElementWithIdentifier:xLinkID];
        element = [self mergedElement:element
                 withReferenceElement:detachedElement];
    }
    
    *postProcessBlock = [self computeAttributesFromElement:element
                                                    onNode:node
                                         ignoredAttributes:nil];
    [self computeElement:element
              parentNode:node];
    [IJSVGRadialGradient parseGradient:element
                              gradient:node];
    return node;
}

- (IJSVGNode*)parseStopElement:(NSXMLElement*)element
                    parentNode:(IJSVGNode*)parentNode
              postProcessBlock:(IJSVGNodeParserPostProcessBlock*)postProcessBlock
{
    IJSVGNode* node = [[IJSVGNode alloc] init];
    node.type = IJSVGNodeTypeStop;
    node.name = element.localName;
    
    if([parentNode isKindOfClass:IJSVGGroup.class] == YES) {
        IJSVGGroup* group = (IJSVGGroup*)parentNode;
        [group addChild:node];
    }
    *postProcessBlock = [self computeAttributesFromElement:element
                                                    onNode:node
                                         ignoredAttributes:nil];
    return node;
}

- (IJSVGNode*)parsePathElement:(NSXMLElement*)element
                    parentNode:(IJSVGNode*)parentNode
              postProcessBlock:(IJSVGNodeParserPostProcessBlock*)postProcessBlock
{
    IJSVGPath* node = [[IJSVGPath alloc] init];
    node.type = IJSVGNodeTypePath;
    node.name = element.localName;
    node.parentNode = parentNode;
    
    if([parentNode isKindOfClass:IJSVGGroup.class] == YES) {
        IJSVGGroup* group = (IJSVGGroup*)parentNode;
        [group addChild:node];
    }
    
    CGMutablePathRef path = NULL;
    NSString* pathData = [element attributeForName:IJSVGAttributeD].stringValue;
    if(pathData != nil) {
        NSArray<IJSVGCommand*>* commands = [IJSVGCommand commandsForDataCharacters:pathData.UTF8String
                                                                        dataStream:_commandDataStream];
        path = [IJSVGCommand newPathForCommandsArray:commands];
    } else {
        path = CGPathCreateMutable();
    }
    node.path = path;
    CGPathRelease(path);

    *postProcessBlock = [self computeAttributesFromElement:element
                                                    onNode:node
                                         ignoredAttributes:nil];
    return node;
}

- (IJSVGNode*)parseLineElement:(NSXMLElement*)element
                    parentNode:(IJSVGNode*)parentNode
              postProcessBlock:(IJSVGNodeParserPostProcessBlock*)postProcessBlock
{
    IJSVGPath* node = [[IJSVGPath alloc] init];
    node.type = IJSVGNodeTypeLine;
    node.primitiveType = kIJSVGPrimitivePathTypeLine;
    node.parentNode = parentNode;
    node.name = element.localName;
    
    if([parentNode isKindOfClass:IJSVGGroup.class] == YES) {
        IJSVGGroup* group = (IJSVGGroup*)parentNode;
        [group addChild:node];
    }
    
    *postProcessBlock = [self computeAttributesFromElement:element
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
    NSArray<IJSVGCommand*>* commands = [IJSVGCommand commandsForDataCharacters:buffer
                                                                    dataStream:_commandDataStream];
    CGMutablePathRef nPath = [IJSVGCommand newPathForCommandsArray:commands];
    node.path = nPath;
    CGPathRelease(nPath);
    
    (void)free(buffer);
    return node;
}

- (IJSVGNode*)parsePolyLineElement:(NSXMLElement*)element
                        parentNode:(IJSVGNode*)parentNode
                  postProcessBlock:(IJSVGNodeParserPostProcessBlock*)postProcessBlock
{
    IJSVGPath* node = [[IJSVGPath alloc] init];
    node.type = IJSVGNodeTypePolyline;
    node.primitiveType = kIJSVGPrimitivePathTypePolyLine;
    node.parentNode = parentNode;
    
    if([parentNode isKindOfClass:IJSVGGroup.class] == YES) {
        IJSVGGroup* group = (IJSVGGroup*)parentNode;
        [group addChild:node];
    }
    
    *postProcessBlock = [self computeAttributesFromElement:element
                                                    onNode:node
                                        ignoredAttributes:nil];
    
    NSString* pointsString = [element attributeForName:IJSVGAttributePoints].stringValue;
    [self parsePolyPoints:pointsString
                 intoPath:node
                closePath:NO];
    
    return node;
}

- (IJSVGNode*)parsePolygonElement:(NSXMLElement*)element
                       parentNode:(IJSVGNode*)parentNode
                 postProcessBlock:(IJSVGNodeParserPostProcessBlock*)postProcessBlock
{
    IJSVGPath* node = [[IJSVGPath alloc] init];
    node.type = IJSVGNodeTypePolygon;
    node.primitiveType = kIJSVGPrimitivePathTypePolygon;
    node.parentNode = parentNode;
    
    if([parentNode isKindOfClass:IJSVGGroup.class] == YES) {
        IJSVGGroup* group = (IJSVGGroup*)parentNode;
        [group addChild:node];
    }
    
    *postProcessBlock = [self computeAttributesFromElement:element
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
                 postProcessBlock:(IJSVGNodeParserPostProcessBlock*)postProcessBlock
{
    IJSVGPath* node = [[IJSVGPath alloc] init];
    node.name = element.localName;
    node.primitiveType = kIJSVGPrimitivePathTypeEllipse;
    node.type = IJSVGNodeTypeEllipse;
    
    if([parentNode isKindOfClass:IJSVGGroup.class] == YES) {
        IJSVGGroup* group = (IJSVGGroup*)parentNode;
        [group addChild:node];
    }
    
    CGRect computedBounds = CGRectZero;
    IJSVGUnitType contentUnits = [parentNode contentUnitsWithReferencingNodeBounds:&computedBounds];
    *postProcessBlock = [self computeAttributesFromElement:element
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
                postProcessBlock:(IJSVGNodeParserPostProcessBlock*)postProcessBlock
{
    IJSVGPath* node = [[IJSVGPath alloc] init];
    node.name = element.localName;
    node.primitiveType = kIJSVGPrimitivePathTypeCircle;
    node.type = IJSVGNodeTypeCircle;
    
    if([parentNode isKindOfClass:IJSVGGroup.class] == YES) {
        IJSVGGroup* group = (IJSVGGroup*)parentNode;
        [group addChild:node];
    }
    
    CGRect computedBounds = CGRectZero;
    IJSVGUnitType contentUnits = [parentNode contentUnitsWithReferencingNodeBounds:&computedBounds];
    
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
    
    // if rX and rY dont match, we are not a circle but an ellipsis, this is
    // insanely important when it comes to exporting
    if(rX != rY) {
        node.primitiveType = kIJSVGPrimitivePathTypeEllipse;
        node.type = IJSVGNodeTypeEllipse;
    }
    
    CGRect rect = CGRectMake(cX - rX, cY - rY, rX * 2, rY * 2);
    CGPathRef nPath = CGPathCreateWithEllipseInRect(rect, NULL);
    node.path = (CGMutablePathRef)nPath;
    CGPathRelease(nPath);
    
    *postProcessBlock = [self computeAttributesFromElement:element
                                                    onNode:node
                                         ignoredAttributes:nil];
    
    return node;
}

- (IJSVGNode*)parseGroupElement:(NSXMLElement*)element
                     parentNode:(IJSVGNode*)parentNode
                       nodeType:(IJSVGNodeType)nodeType
               postProcessBlock:(IJSVGNodeParserPostProcessBlock*)postProcessBlock
{
    IJSVGGroup* node = [[IJSVGGroup alloc] init];
    node.type = nodeType;
    node.name = element.localName;
    node.parentNode = parentNode;
    
    if([parentNode isKindOfClass:IJSVGGroup.class] == YES) {
        IJSVGGroup* group = (IJSVGGroup*)parentNode;
        [group addChild:node];
    }
    *postProcessBlock = [self computeAttributesFromElement:element
                                                    onNode:node
                                         ignoredAttributes:nil];
    
    // recursively compute children
    [self computeElement:element
              parentNode:node];
    return node;
}

- (void)parseSVGElement:(NSXMLElement*)element
               ontoNode:(IJSVGRootNode*)node
             parentNode:(IJSVGNode*)parentNode
       postProcessBlock:(IJSVGNodeParserPostProcessBlock*)postProcessBlock
{
    node.type = IJSVGNodeTypeSVG;
    node.name = element.localName;
    node.parentNode = parentNode;
    
    if([parentNode isKindOfClass:IJSVGGroup.class] == YES) {
        IJSVGGroup* group = (IJSVGGroup*)parentNode;
        [group addChild:node];
    }
    
    [self parseDefElement:element
               parentNode:node
                recursive:NO];
    
    *postProcessBlock = [self computeAttributesFromElement:element
                                                    onNode:node
                                         ignoredAttributes:nil];

    // make sure we compute the viewbox
    [self computeViewBoxForRootNode:node];
    
    // recursively compute children
    [self computeElement:element
              parentNode:node];
}

- (IJSVGNode*)parseSVGElement:(NSXMLElement*)element
                   parentNode:(IJSVGNode*)parentNode
             postProcessBlock:(IJSVGNodeParserPostProcessBlock*)postProcessBlock
{
    IJSVGRootNode* node = [[IJSVGRootNode alloc] init];
    [self parseSVGElement:element
                 ontoNode:node
               parentNode:parentNode
         postProcessBlock:postProcessBlock];
    return node;
}

- (IJSVGNode*)parseRectElement:(NSXMLElement*)element
                    parentNode:(IJSVGNode*)parentNode
              postProcessBlock:(IJSVGNodeParserPostProcessBlock*)postProcessBlock
{
    IJSVGPath* node = [[IJSVGPath alloc] init];
    node.type = IJSVGNodeTypeRect;
    node.primitiveType = kIJSVGPrimitivePathTypeRect;
    node.name = element.localName;
    node.parentNode = parentNode;
    
    if([parentNode isKindOfClass:IJSVGGroup.class] == YES) {
        IJSVGGroup* group = (IJSVGGroup*)parentNode;
        [group addChild:node];
    }
    
    CGRect bounds = parentNode.bounds;
    CGRect proposedBounds = CGRectZero;
    IJSVGUnitType contentUnitType = [parentNode contentUnitsWithReferencingNodeBounds:&proposedBounds];
    
    // could not compute a value, so just use the bounds
    if(contentUnitType == IJSVGUnitInherit) {
        proposedBounds = bounds;
    }
    
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
    
    bounds = proposedBounds;
    if(contentUnitType == IJSVGUnitObjectBoundingBox) {
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
    *postProcessBlock = [self computeAttributesFromElement:element
                                                    onNode:node
                                         ignoredAttributes:ignoredAttributes];
    return node;
}

- (IJSVGNode*)parseImageElement:(NSXMLElement*)element
                     parentNode:(IJSVGNode*)parentNode
               postProcessBlock:(IJSVGNodeParserPostProcessBlock*)postProcessBlock
{
    CGRect bounds = CGRectZero;
    IJSVGUnitType units = [parentNode contentUnitsWithReferencingNodeBounds:&bounds];
    IJSVGImage* node = [[IJSVGImage alloc] init];
    node.type = IJSVGNodeTypeImage;
    node.name = element.localName;
    node.parentNode = parentNode;
    
    if([parentNode isKindOfClass:IJSVGGroup.class] == YES) {
        IJSVGGroup* group = (IJSVGGroup*)parentNode;
        [group addChild:node];
    }
    
    *postProcessBlock = [self computeAttributesFromElement:element
                                                    onNode:node
                                         ignoredAttributes:nil];
    
    // load image from base64
    NSXMLNode* dataNode = [self resolveXLinkAttributeForElement:element];
    
    if(units == IJSVGUnitObjectBoundingBox) {
        node.width = [IJSVGUnitLength unitWithFloat:node.width.value*bounds.size.width];
        node.height = [IJSVGUnitLength unitWithFloat:node.height.value*bounds.size.height];
    }
    
    [node loadFromString:dataNode.stringValue];
    return node;
}

- (IJSVGNode*)parseUseElement:(NSXMLElement*)element
                   parentNode:(IJSVGNode*)parentNode
             postProcessBlock:(IJSVGNodeParserPostProcessBlock*)postProcessBlock
{
    NSString* xlink = [self resolveXLinkAttributeForElement:element].stringValue;
    NSString* xlinkID = [xlink substringFromIndex:1];
    if(xlinkID == nil) {
        return nil;
    }
    
    // its important that we remove the xlink attribute or hell breaks loose
    NSXMLElement* detachedElement = [self detachedElementWithIdentifier:xlinkID];

    IJSVGGroup* node = (IJSVGGroup*)[self parseGroupElement:element
                                                 parentNode:parentNode
                                                   nodeType:IJSVGNodeTypeUse
                                           postProcessBlock:postProcessBlock];
        
    IJSVGNode* shadowNode = [self parseElement:detachedElement
                                    parentNode:node];
    if(shadowNode != nil) {
        [node addChild:shadowNode];
    }
    return node;
}

- (void)replaceAttributes:(NSArray<NSString*>*)attributes
                onElement:(NSXMLElement*)onElement
              fromElement:(NSXMLElement*)fromElement
{
    for(NSString* collpaseAttribute in attributes) {
        NSXMLNode* attribute = nil;
        if((attribute = [fromElement attributeForName:collpaseAttribute]) != nil &&
           [onElement attributeForName:collpaseAttribute] != nil) {
            [attribute detach];
            [onElement removeAttributeForName:collpaseAttribute];
            [onElement addAttribute:attribute];
        }
    }
}

- (IJSVGNode*)parsePatternElement:(NSXMLElement*)element
                       parentNode:(IJSVGNode*)parentNode
                 postProcessBlock:(IJSVGNodeParserPostProcessBlock*)postProcessBlock
{
    IJSVGPattern* node = [[IJSVGPattern alloc] init];
    node.type = IJSVGNodeTypePattern;
    node.name = element.localName;
    node.parentNode = parentNode;
    node.units = IJSVGUnitObjectBoundingBox;
    node.contentUnits = IJSVGUnitUserSpaceOnUse;
    [node addTraits:IJSVGNodeTraitPaintable];
    NSString* xLinkID = [self resolveXLinkAttributeStringForElement:element];
    if(xLinkID != nil) {
        NSXMLElement* detachedElement = [self detachedElementWithIdentifier:xLinkID];
        element = [self mergedElement:element
                 withReferenceElement:detachedElement];
    }
    *postProcessBlock = [self computeAttributesFromElement:element
                                                    onNode:node
                                         ignoredAttributes:nil];
    [self computeElement:element
              parentNode:node];
    return node;
}

- (IJSVGNode*)parseClipPathElement:(NSXMLElement*)element
                        parentNode:(IJSVGNode*)parentNode
                  postProcessBlock:(IJSVGNodeParserPostProcessBlock*)postProcessBlock
{
    IJSVGClipPath* node = [[IJSVGClipPath alloc] init];
    node.type = IJSVGNodeTypeClipPath;
    node.name = element.localName;
    node.parentNode = parentNode;
    
    *postProcessBlock = [self computeAttributesFromElement:element
                                                    onNode:node
                                         ignoredAttributes:nil];
    
    [self computeElement:element
              parentNode:node];
    
    return node;
}

- (IJSVGNode*)parseMaskElement:(NSXMLElement*)element
                    parentNode:(IJSVGNode*)parentNode
              postProcessBlock:(IJSVGNodeParserPostProcessBlock*)postProcessBlock
{
    IJSVGMask* node = [[IJSVGMask alloc] init];
    node.type = IJSVGNodeTypeMask;
    node.name = element.localName;
    node.parentNode = parentNode;
    
    *postProcessBlock = [self computeAttributesFromElement:element
                                                    onNode:node
                                         ignoredAttributes:nil];
    
    [self computeElement:element
              parentNode:node];
    return node;
}

- (void)parseDefElement:(NSXMLElement*)element
             parentNode:(IJSVGNode*)parentNode
              recursive:(BOOL)recursive
{
    for(NSXMLElement* childElement in element.children) {
        IJSVGNodeType type = [IJSVGNode typeForString:childElement.localName
                                                 kind:childElement.kind];
        
        // we can exit early, not a node we know of
        if(type == IJSVGNodeTypeNotFound) {
            continue;
        }
        
        // we always want style elements to be passed
        NSString* identifier = [childElement attributeForName:IJSVGAttributeID].stringValue;
        if(identifier != nil) {
            [self detachElement:childElement
                 withIdentifier:identifier];
        }
        
        if(type == IJSVGNodeTypeStyle) {
            [self parseStyleElement:childElement
                         parentNode:parentNode];
        } else {
            // only run this if recursive or it can be slow or incorrect
            // when parsing the tree with ids that are the same
            if(recursive == YES && childElement.childCount != 0) {
                [self parseDefElement:childElement
                           parentNode:parentNode
                            recursive:recursive];
            }
        }
    }
}

- (void)parseTitleElement:(NSXMLElement*)element
               parentNode:(IJSVGNode*)parentNode
         postProcessBlock:(IJSVGNodeParserPostProcessBlock*)postProcessBlock
{
    parentNode.title = element.stringValue;
}

- (void)parseDescElement:(NSXMLElement*)element
              parentNode:(IJSVGNode*)parentNode
        postProcessBlock:(IJSVGNodeParserPostProcessBlock*)postProcessBlock
{
    parentNode.desc = element.stringValue;
}

#pragma mark XLink

- (NSXMLNode*)resolveXLinkAttributeForElement:(NSXMLElement*)element
{
    NSString* const namespaceURI = @"http://www.w3.org/1999/xlink";
    NSXMLNode* attributeNode = [element attributeForLocalName:IJSVGAttributeHref
                                                          URI:namespaceURI];
    if(attributeNode == nil) {
        attributeNode = [element attributeForName:IJSVGAttributeHref];
        if(attributeNode == nil) {
            attributeNode = [element attributeForName:IJSVGAttributeXLink];
        }
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
    if((count % 2) != 0) {
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
    
    NSArray<IJSVGCommand*>* commands = [IJSVGCommand commandsForDataCharacters:buffer
                                                                    dataStream:_commandDataStream];
    
    CGRect bounds;
    if([path contentUnitsWithReferencingNodeBounds:&bounds] == IJSVGUnitObjectBoundingBox) {
        commands = [IJSVGCommand convertCommands:commands
                                         toUnits:IJSVGUnitObjectBoundingBox
                                          bounds:bounds];
    }
    
    CGMutablePathRef nPath = [IJSVGCommand newPathForCommandsArray:commands];
    path.path = nPath;
    CGPathRelease(nPath);
    
    // free the params
    (void)free(buffer), buffer = NULL;
    (void)free(params), params = NULL;
}

@end
