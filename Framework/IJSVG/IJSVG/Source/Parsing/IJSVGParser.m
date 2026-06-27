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
NSString* const IJSVGAttributeMarker = @"marker";

static inline BOOL IJSVGAttributeMaskContains(uint64_t mask, IJSVGNodeAttribute attribute)
{
    return (mask & (1ULL << attribute)) != 0;
}

@implementation IJSVGParser

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

- (BOOL)_prepareWithXMLDocument:(NSXMLDocument*)document
                        parseError:(NSError*)parseError
                            fileURL:(NSURL*)aURL
                              error:(NSError**)error
{
    // just some generic value to get it up n running.
    _fileURL = aURL;
    _document = document;

    // error parsing the XML document
    if(parseError != nil || _document == nil) {
        [self _handleErrorWithCode:IJSVGErrorParsingFile
                              error:error];
        return NO;
    }

    // check the actual parsed SVG
    NSError* anError = nil;
    if([self _validateParse:&anError] == NO) {
        if(error != NULL) {
            *error = anError;
        }
        return NO;
    }
    return YES;
}

- (id)initWithSVGString:(NSString*)string
                fileURL:(NSURL*)aURL
                  error:(NSError**)error
{
    if((self = [super init]) != nil) {
        NSError* anError = nil;
        NSXMLDocument* document = nil;
        @try {
            document = [[NSXMLDocument alloc] initWithXMLString:string
                                                        options:0
                                                          error:&anError];
        }
        @catch (NSException* exception) {
        }

        if([self _prepareWithXMLDocument:document
                              parseError:anError
                                  fileURL:aURL
                                    error:error] == NO) {
            return nil;
        }
    }
    return self;
}

- (id)initWithSVGData:(NSData*)data
              fileURL:(NSURL*)aURL
                error:(NSError**)error
{
    if((self = [super init]) != nil) {
        NSError* anError = nil;
        NSXMLDocument* document = nil;
        @try {
            document = [[NSXMLDocument alloc] initWithData:data
                                                   options:0
                                                     error:&anError];
        }
        @catch (NSException* exception) {
        }

        if([self _prepareWithXMLDocument:document
                              parseError:anError
                                  fileURL:aURL
                                    error:error] == NO) {
            return nil;
        }
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
    NSData* data = [NSData dataWithContentsOfURL:aURL
                                         options:NSDataReadingMappedIfSafe
                                           error:&anError];

    // error reading file
    if(data == nil) {
        return [self _handleErrorWithCode:IJSVGErrorReadingFile
                                    error:error];
    }

    return [self initWithSVGData:data
                         fileURL:aURL
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

- (IJSVGRootNode*)rootNodeWithSize:(CGSize)size
{
  __weak IJSVGParser* weakSelf = self;
  [self beginWithSetup:^{
      IJSVGParser* strongSelf = weakSelf;
      strongSelf->_rootSize = CGSizeEqualToSize(CGSizeZero, size) == YES ?
          IJSVG_SIZE_DEFAULT_CLIENT : size;
  }];
  return _rootNode;
}

- (void)beginWithSetup:(dispatch_block_t __nullable)setup
{
    // setup basics to begin with
    _styleSheet = [[IJSVGStyleSheet alloc] init];
    IJSVGThreadManager* manager = IJSVGThreadManager.currentManager;
    _threadManager = manager;
    _commandDataStream = manager.pathDataStream;
    _detachedReferences = [[NSMutableDictionary alloc] init];
    if(setup != nil) {
      setup();
    }
    _rootNode = [[IJSVGRootNode alloc] init];
    _rootNode.clientSize = _rootSize;
    IJSVGNodeParserPostProcessBlock postProcessBlock = nil;
    [self parseSVGElement:_document.rootElement
                 ontoNode:_rootNode
               parentNode:nil
         postProcessBlock:&postProcessBlock
                recursive:YES];
    if(postProcessBlock != nil) {
        postProcessBlock();
    }
    [_rootNode postProcess];
    _detachedReferences = nil;
}

- (IJSVGRootNode*)rootNode:(BOOL)recursive
{
    IJSVGNodeParserPostProcessBlock postProcessBlock = nil;
    IJSVGRootNode* node = [[IJSVGRootNode alloc] init];
    node.clientSize = _rootSize;
    [self parseSVGElement:_document.rootElement
                 ontoNode:node
               parentNode:nil
         postProcessBlock:&postProcessBlock
                recursive:recursive];
    if(postProcessBlock != nil) {
        postProcessBlock();
    }
    [node postProcess];
    return node;
}

- (void)computeDefsForElement:(NSXMLElement*)element
                   parentNode:(IJSVGNode*)parentNode
{
    if(element.childCount == 0) {
        return;
    }
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

- (void)inferDefaultIntrinsicSizeAndViewBoxForRootNode:(IJSVGRootNode*)node {
    if(node.intrinsicSize != nil) {
      return;
    }
  
    IJSVGUnitLength* width = node.width;
    IJSVGUnitLength* height = node.height;
  
    // We already have a width and a height, use those.
    if(width != nil && height != nil) {
        node.intrinsicSize = [IJSVGUnitSize sizeWithWidth:width
                                                   height:height];
        return;
    }
  
    CGSize defaultSize = IJSVG_SIZE_DEFAULT_CLIENT;
    CGFloat ratio = defaultSize.width / defaultSize.height;
  
    if(width != nil && height == nil) {
      height = [IJSVGUnitLength unitWithFloat:width.value*ratio];
    } else if(width == nil && height != nil) {
      width = [IJSVGUnitLength unitWithFloat:height.value*ratio];
    } else {
      width = [IJSVGUnitLength unitWithFloat:defaultSize.width];
      height = [IJSVGUnitLength unitWithFloat:defaultSize.height];
    }
    node.intrinsicSize = [IJSVGUnitSize sizeWithWidth:width
                                               height:height];
    if(node.viewBox == nil) {
        node.viewBox = [IJSVGUnitRect rectWithOrigin:IJSVGUnitPoint.zeroPoint
                                                size:node.intrinsicSize.copy];
    }
}

- (void)computeViewBoxForRootNode:(IJSVGRootNode*)node
{
    if(node.viewBox == nil && (node.width != nil || node.height != nil)) {
        IJSVGUnitLength* width = node.width ?: node.height;
        IJSVGUnitLength* height = node.height ?: node.width;
        IJSVGUnitSize* size = [IJSVGUnitSize sizeWithWidth:width
                                                    height:height];
        node.viewBox = [IJSVGUnitRect rectWithOrigin:IJSVGUnitPoint.zeroPoint
                                                size:size];
    }
  
    if(node.viewBox == nil) {
      return;
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
    
    node.intrinsicDimensions = dimensions;
    node.intrinsicSize = [IJSVGUnitSize sizeWithWidth:wl
                                              height:hl];
}

- (IJSVGNodeParserPostProcessBlock)computeAttributesFromElement:(NSXMLElement*)element
                                                         onNode:(IJSVGNode*)node
                                              ignoredAttributes:(IJSVGBitFlags*)ignoringAttributes
{
    IJSVGStyleSheetStyle* styleSheet = nil;
    __block IJSVGStyleSheetStyle* nodeStyle = nil;
    NSArray<NSXMLNode*>* elementAttributes = element.attributes;
    NSUInteger attributeCount = elementAttributes.count;
    BOOL hasStyleSheetRules = _styleSheet.ruleCount != 0;
    if(attributeCount == 0 && hasStyleSheetRules == NO) {
        return nil;
    }
    uint64_t activeAttributes = [node.class computedAllowedAttributeMask];
    if(ignoringAttributes != nil) {
        activeAttributes &= ~ignoringAttributes.bitMask;
    }
    // precache the attributes, this is quicker than asking for it each time
    NSMutableDictionary<NSString*, NSString*>* attributes = nil;
    attributes = [[NSMutableDictionary alloc] initWithCapacity:attributeCount];
    for(NSXMLNode* attributeNode in elementAttributes) {
        attributes[attributeNode.name] = attributeNode.stringValue;
    }
    
    void (^applyTransform)(NSString*) = ^(NSString* value) {
        NSMutableArray<IJSVGTransform*>* transforms = [[NSMutableArray alloc] init];
        [transforms addObjectsFromArray:[IJSVGTransform transformsForString:value]];
        if(node.transforms != nil) {
            [transforms addObjectsFromArray:node.transforms];
        }
        node.transforms = transforms;
    };

    // helper for setting an attribute
    typedef void (^IJSVGAttributeParseBlock)(NSString*);
    BOOL (^IJSVGAttributeParse)(const NSString*, IJSVGAttributeParseBlock) =
    ^(NSString* key, IJSVGAttributeParseBlock parseBlock) {
        NSString* value = [nodeStyle property:key] ?: attributes[key];
        if(value != nil && value.length != 0) {
            parseBlock(value);
            return YES;
        }
        return NO;
    };
    
    // identifier
    if(IJSVGAttributeMaskContains(activeAttributes, IJSVGNodeAttributeID)) {
        IJSVGAttributeParse(IJSVGAttributeID, ^(NSString* value) {
            node.identifier = value;
            [self detachElement:element
                 withIdentifier:value];
        });
    }
    
    // class list
    if(IJSVGAttributeMaskContains(activeAttributes, IJSVGNodeAttributeClass)) {
        IJSVGAttributeParse(IJSVGAttributeClass, ^(NSString* value) {
            NSArray* list = [value ijsvg_componentsSeparatedByChars:" "];
            node.className = value;
            node.classNameList = [NSSet setWithArray:list];
        });
    }
    
    
    // style
    if(hasStyleSheetRules == YES) {
        styleSheet = [_styleSheet styleForNode:node];
    }
    
    if(IJSVGAttributeMaskContains(activeAttributes, IJSVGNodeAttributeStyle)) {
        IJSVGAttributeParse(IJSVGAttributeStyle, ^(NSString* value) {
            nodeStyle = [IJSVGStyleSheetStyle parseStyleString:value];
        });
    }
    
    if(styleSheet != nil) {
        nodeStyle = nodeStyle == nil ? styleSheet : [styleSheet mergedStyle:nodeStyle];
    }
            
    // x
    if(IJSVGAttributeMaskContains(activeAttributes, IJSVGNodeAttributeX)) {
        IJSVGAttributeParse(IJSVGAttributeX, ^(NSString* value) {
            node.x = [IJSVGUnitLength unitWithString:value];
        });
    }
    
    // y
    if(IJSVGAttributeMaskContains(activeAttributes, IJSVGNodeAttributeY)) {
        IJSVGAttributeParse(IJSVGAttributeY, ^(NSString* value) {
            node.y = [IJSVGUnitLength unitWithString:value];
        });
    }
    
    // width
    if(IJSVGAttributeMaskContains(activeAttributes, IJSVGNodeAttributeWidth)) {
        IJSVGAttributeParse(IJSVGAttributeWidth, ^(NSString* value) {
            node.width = [IJSVGUnitLength unitWithString:value];
        });
    }
    
    // height
    if(IJSVGAttributeMaskContains(activeAttributes, IJSVGNodeAttributeHeight)) {
        IJSVGAttributeParse(IJSVGAttributeHeight, ^(NSString* value) {
            node.height = [IJSVGUnitLength unitWithString:value];
        });
    }
    
    // opacity
    if(IJSVGAttributeMaskContains(activeAttributes, IJSVGNodeAttributeOpacity)) {
        IJSVGAttributeParse(IJSVGAttributeOpacity, ^(NSString* value) {
            node.opacity = [IJSVGUnitLength unitWithString:value];
        });
    }
    
    // stroke opacity
    if(IJSVGAttributeMaskContains(activeAttributes, IJSVGNodeAttributeStrokeOpacity)) {
        IJSVGAttributeParse(IJSVGAttributeStrokeOpacity, ^(NSString* value) {
            node.strokeOpacity = [IJSVGUnitLength unitWithString:value];
        });
    }
    
    // stroke width
    if(IJSVGAttributeMaskContains(activeAttributes, IJSVGNodeAttributeStrokeWidth)) {
        IJSVGAttributeParse(IJSVGAttributeStrokeWidth, ^(NSString* value) {
            node.strokeWidth = [IJSVGUnitLength unitWithString:value];
        });
    }
    
    // stroke dash offset
    if(IJSVGAttributeMaskContains(activeAttributes, IJSVGNodeAttributeStrokeDashOffset)) {
        IJSVGAttributeParse(IJSVGAttributeStrokeDashOffset, ^(NSString* value) {
            node.strokeDashOffset = [IJSVGUnitLength unitWithString:value];
        });
    }
    
    // stroke miter limit
    if(IJSVGAttributeMaskContains(activeAttributes, IJSVGNodeAttributeStrokeMiterLimit)) {
        IJSVGAttributeParse(IJSVGAttributeStrokeMiterLimit, ^(NSString* value) {
            node.strokeMiterLimit = [IJSVGUnitLength unitWithString:value];
        });
    }

    IJSVGNodeParserPostProcessBlock postProcessBlock = ^{
        // mask
        if(IJSVGAttributeMaskContains(activeAttributes, IJSVGNodeAttributeMask)) {
            IJSVGAttributeParse(IJSVGAttributeMask, ^(NSString* value) {
                NSString* identifier = [IJSVGUtils defURL:value];
                if(identifier != nil) {
                    node.mask = (id)[self computeDetachedNodeWithIdentifier:identifier
                                                            referencingNode:node
                                                                    element:element];
                }
            });
        }
        
        // clip path
        if(IJSVGAttributeMaskContains(activeAttributes, IJSVGNodeAttributeClipPath)) {
            IJSVGAttributeParse(IJSVGAttributeClipPath, ^(NSString* value) {
                NSString* identifier = [IJSVGUtils defURL:value];
                if(identifier != nil) {
                    node.clipPath = (id)[self computeDetachedNodeWithIdentifier:identifier
                                                                referencingNode:node
                                                                        element:element];
                }
            });
        }
    };
    
    // gradient units
    if(IJSVGAttributeMaskContains(activeAttributes, IJSVGNodeAttributeGradientUnits)) {
        IJSVGAttributeParse(IJSVGAttributeGradientUnits, ^(NSString* value) {
            node.units = [IJSVGUtils unitTypeForString:value];
        });
    }
    
    // mask units
    if(IJSVGAttributeMaskContains(activeAttributes, IJSVGNodeAttributeMaskUnits)) {
        IJSVGAttributeParse(IJSVGAttributeMaskUnits, ^(NSString* value) {
            node.units = [IJSVGUtils unitTypeForString:value];
        });
    }
    
    // pattern units
    if(IJSVGAttributeMaskContains(activeAttributes, IJSVGNodeAttributePatternUnits)) {
        IJSVGAttributeParse(IJSVGAttributePatternUnits, ^(NSString* value) {
            node.units = [IJSVGUtils unitTypeForString:value];
        });
    }
    
    // mask content units
    if(IJSVGAttributeMaskContains(activeAttributes, IJSVGNodeAttributeMaskContentUnits)) {
        IJSVGAttributeParse(IJSVGAttributeMaskContentUnits, ^(NSString* value) {
            node.contentUnits = [IJSVGUtils unitTypeForString:value];
        });
    }
    
    // pattern content units
    if(IJSVGAttributeMaskContains(activeAttributes, IJSVGNodeAttributePatternContentUnits)) {
        IJSVGAttributeParse(IJSVGAttributePatternContentUnits, ^(NSString* value) {
            node.contentUnits = [IJSVGUtils unitTypeForString:value];
        });
    }
    
    // clip path units
    if(IJSVGAttributeMaskContains(activeAttributes, IJSVGNodeAttributeClipPathUnits)) {
        IJSVGAttributeParse(IJSVGAttributeClipPathUnits, ^(NSString* value) {
            node.contentUnits = [IJSVGUtils unitTypeForString:value];
        });
    }
    
    // transform
    if(IJSVGAttributeMaskContains(activeAttributes, IJSVGNodeAttributeTransform)) {
        IJSVGAttributeParse(IJSVGAttributeTransform, applyTransform);
    }

    // gradient transform
    if(IJSVGAttributeMaskContains(activeAttributes, IJSVGNodeAttributeGradientTransform)) {
        IJSVGAttributeParse(IJSVGAttributeGradientTransform, applyTransform);
    }

    // pattern transform
    if(IJSVGAttributeMaskContains(activeAttributes, IJSVGNodeAttributePatternTransform)) {
        IJSVGAttributeParse(IJSVGAttributePatternTransform, applyTransform);
    }

    // unicode
    if(IJSVGAttributeMaskContains(activeAttributes, IJSVGNodeAttributeUnicode)) {
        IJSVGAttributeParse(IJSVGAttributeUnicode, ^(NSString* value) {
            node.unicode = [NSString stringWithFormat:@"%04x", [value characterAtIndex:0]];
        });
    }

    // linecap
    if(IJSVGAttributeMaskContains(activeAttributes, IJSVGNodeAttributeStrokeLineCap)) {
        IJSVGAttributeParse(IJSVGAttributeStrokeLineCap, ^(NSString* value) {
            node.lineCapStyle = [IJSVGUtils lineCapStyleForString:value];
        });
    }

    // line join
    if(IJSVGAttributeMaskContains(activeAttributes, IJSVGNodeAttributeStrokeLineJoin)) {
        IJSVGAttributeParse(IJSVGAttributeStrokeLineJoin, ^(NSString* value) {
            node.lineJoinStyle = [IJSVGUtils lineJoinStyleForString:value];
        });
    }
    
    // stroke color
    if(IJSVGAttributeMaskContains(activeAttributes, IJSVGNodeAttributeStroke)) {
        IJSVGAttributeParse(IJSVGAttributeStroke, ^(NSString* value) {
            // todo
            NSString* fillIdentifier = [IJSVGUtils defURL:value];
            if(fillIdentifier != nil) {
                IJSVGNode* object = [self computeDetachedNodeWithIdentifier:fillIdentifier
                                                            referencingNode:node
                                                                    element:element];
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
    }

    // stroke dash array
    if(IJSVGAttributeMaskContains(activeAttributes, IJSVGNodeAttributeStrokeDashArray)) {
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
    }

    // fill - seems kinda complicated for what it actually is
    if(IJSVGAttributeMaskContains(activeAttributes, IJSVGNodeAttributeFill)) {
        IJSVGAttributeParse(IJSVGAttributeFill, ^(NSString* value) {
            // todo
            NSString* fillIdentifier = [IJSVGUtils defURL:value];
            if(fillIdentifier != nil) {
                IJSVGNode* object = [self computeDetachedNodeWithIdentifier:fillIdentifier
                                                            referencingNode:node
                                                                    element:element];
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
    }
    
    // fill opacity
    if(IJSVGAttributeMaskContains(activeAttributes, IJSVGNodeAttributeFillOpacity)) {
        IJSVGAttributeParse(IJSVGAttributeFillOpacity, ^(NSString* value) {
            node.fillOpacity = [IJSVGUnitLength unitWithString:value];
        });
    }

    // blendmode
    if(IJSVGAttributeMaskContains(activeAttributes, IJSVGNodeAttributeBlendMode)) {
        IJSVGAttributeParse(IJSVGAttributeBlendMode, ^(NSString* value) {
            node.blendMode = [IJSVGUtils blendModeForString:value];
        });
    }

    // fill rule
    if(IJSVGAttributeMaskContains(activeAttributes, IJSVGNodeAttributeFillRule)) {
        IJSVGAttributeParse(IJSVGAttributeFillRule, ^(NSString* value) {
            node.windingRule = [IJSVGUtils windingRuleForString:value];
        });
    }
    
    // clip rule
    if(IJSVGAttributeMaskContains(activeAttributes, IJSVGNodeAttributeClipRule)) {
        IJSVGAttributeParse(IJSVGAttributeClipRule, ^(NSString* value) {
            node.clipRule = [IJSVGUtils windingRuleForString:value];
        });
    }
    
    // display
    if(IJSVGAttributeMaskContains(activeAttributes, IJSVGNodeAttributeDisplay)) {
        IJSVGAttributeParse(IJSVGAttributeDisplay, ^(NSString* value) {
            if([value.lowercaseString isEqualToString:IJSVGStringNone]) {
                node.shouldRender = NO;
            }
        });
    }
    
    // offset
    if(IJSVGAttributeMaskContains(activeAttributes, IJSVGNodeAttributeOffset)) {
        IJSVGAttributeParse(IJSVGAttributeOffset, ^(NSString* value) {
            node.offset = [IJSVGUnitLength unitWithString:value];
        });
    }
    
    // stop-opacity
    if(IJSVGAttributeMaskContains(activeAttributes, IJSVGNodeAttributeStopOpacity)) {
        IJSVGAttributeParse(IJSVGAttributeStopOpacity, ^(NSString* value) {
            node.fillOpacity = [IJSVGUnitLength unitWithString:value];
        });
    }
    
    // stop-color
    if(IJSVGAttributeMaskContains(activeAttributes, IJSVGNodeAttributeStopColor)) {
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
    }
    
    // overflow
    if(IJSVGAttributeMaskContains(activeAttributes, IJSVGNodeAttributeOverflow)) {
        IJSVGAttributeParse(IJSVGAttributeOverflow, ^(NSString* value) {
            if([value.lowercaseString isEqualToString:@"hidden"]) {
                node.overflowVisibility = IJSVGOverflowVisibilityHidden;
            } else {
                node.overflowVisibility = IJSVGOverflowVisibilityVisible;
            }
        });
    }
    
    // viewBox because this somehow is a thing
    if(IJSVGAttributeMaskContains(activeAttributes, IJSVGNodeAttributeViewBox)) {
        IJSVGAttributeParse(IJSVGAttributeViewBox, ^(NSString* value) {
            CGFloat* floats = [IJSVGUtils parseViewBox:value];
            node.viewBox = [IJSVGUnitRect rectWithX:floats[0]
                                                  y:floats[1]
                                              width:floats[2]
                                             height:floats[3]];
            ((void)free(floats)), floats = NULL;
        });
    }
    
    // preserveAspectRatio
    if(IJSVGAttributeMaskContains(activeAttributes, IJSVGNodeAttributePreserveAspectRatio)) {
        IJSVGAttributeParse(IJSVGAttributePreserveAspectRatio, ^(NSString* value) {
            IJSVGViewBoxMeetOrSlice meetOrSlice;
            IJSVGViewBoxAlignment alignment = [IJSVGViewBox alignmentForString:value
                                                                   meetOrSlice:&meetOrSlice];
            node.viewBoxAlignment = alignment;
            node.viewBoxMeetOrSlice = meetOrSlice;
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
    if(element.childCount == 0) {
        return;
    }
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
                                        element:(NSXMLElement*)element
{
    NSXMLElement* detachedElement = [self detachedElementWithIdentifier:identifier];
    if(detachedElement == nil) {
        return nil;
    }
  
    // if we are recursive, we must return nil to prevent crashing.
    if([self isElement:element decedentOf:detachedElement]) {
      [self recursionDetectedOn:element
                    decendentOf:detachedElement
                     identifier:identifier];
      return nil;
    }
  
    // we need to make sure once we are done, we detach this from its parent
    // or it can cause recursion down the line
    return [self parseElement:detachedElement
                   parentNode:node].detach;
}

- (void)recursionDetectedOn:(NSXMLElement*)element
                decendentOf:(NSXMLElement*)parent
                 identifier:(NSString*)identifier
{
  // For now, we only want to log these for debug builds whilst we fix any
  // SVG's that are problematic.
#if DEBUG
  NSLog(@"<%@> Recursion detected in file: \"%@\", with identifer: \"%@\"",
        self.className, _fileURL ?: @"Unknown", identifier);
#endif
}

- (BOOL)isElement:(NSXMLElement*)element
       decedentOf:(NSXMLElement*)parentElement {
    NSXMLElement* parent = (NSXMLElement*)element.parent;
    while(parent != nil) {
      if(parentElement == parent) {
        return YES;
      }
      parent = (NSXMLElement*)parent.parent;
    }
    return NO;
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
  
    // if we merge an element, we need to also maintain its children, if the
    // reference element has children and the referencing element does not,
    // use those else use the referencing element children.
    if (element.childCount != 0) {
      // remove any old children - iterate back to front so we don't mutate
      // the collection we are enumerating (removing by index whilst fast
      // enumerating shifts indexes and is undefined behaviour)
      for(NSUInteger i = copy.childCount; i > 0; i--) {
        [copy removeChildAtIndex:i - 1];
      }

      // add the new ones from the copy
      for(__strong NSXMLElement* child in element.children) {
        [copy addChild:child.copy];
      }
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
    IJSVGStop* node = [[IJSVGStop alloc] init];
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
    
    node.x1 = [IJSVGUnitLength unitWithString:[element attributeForName:IJSVGAttributeX1].stringValue];
    node.y1 = [IJSVGUnitLength unitWithString:[element attributeForName:IJSVGAttributeY1].stringValue];
    node.x2 = [IJSVGUnitLength unitWithString:[element attributeForName:IJSVGAttributeX2].stringValue];
    node.y2 = [IJSVGUnitLength unitWithString:[element attributeForName:IJSVGAttributeY2].stringValue];
    return node;
}

- (IJSVGNode*)parsePolyLineElement:(NSXMLElement*)element
                        parentNode:(IJSVGNode*)parentNode
                  postProcessBlock:(IJSVGNodeParserPostProcessBlock*)postProcessBlock
{
    IJSVGPath* node = [[IJSVGPath alloc] init];
    node.type = IJSVGNodeTypePolyline;
    node.name = element.localName;
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
    node.name = element.localName;
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
    
    *postProcessBlock = [self computeAttributesFromElement:element
                                                    onNode:node
                                         ignoredAttributes:nil];
    
    node.cx = [IJSVGUnitLength unitWithString:[element attributeForName:IJSVGAttributeCX].stringValue];
    node.cy = [IJSVGUnitLength unitWithString:[element attributeForName:IJSVGAttributeCY].stringValue];
    node.rx = [IJSVGUnitLength unitWithString:[element attributeForName:IJSVGAttributeRX].stringValue];
    node.ry = [IJSVGUnitLength unitWithString:[element attributeForName:IJSVGAttributeRY].stringValue];
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
    
    node.cx = [IJSVGUnitLength unitWithString:[element attributeForName:IJSVGAttributeCX].stringValue];
    node.cy = [IJSVGUnitLength unitWithString:[element attributeForName:IJSVGAttributeCY].stringValue];
    node.r = [IJSVGUnitLength unitWithString:[element attributeForName:IJSVGAttributeR].stringValue];
    
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
              recursive:(BOOL)recursive
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
    
    // if we are the root node and not a nested SVG, disable transforms
    IJSVGBitFlags* ignored = nil;
    if(parentNode == nil) {
        ignored = [[IJSVGBitFlags64 alloc] init];
        [ignored setBit:IJSVGNodeAttributeTransform];
    }
    
    *postProcessBlock = [self computeAttributesFromElement:element
                                                    onNode:node
                                         ignoredAttributes:ignored];
  
    // make sure we compute the viewbox
    [self computeViewBoxForRootNode:node];
    [self inferDefaultIntrinsicSizeAndViewBoxForRootNode:node];
    
    // recursively compute children
    if(recursive == YES) {
      [self computeElement:element
                parentNode:node];
    }
  
}

- (IJSVGNode*)parseSVGElement:(NSXMLElement*)element
                   parentNode:(IJSVGNode*)parentNode
             postProcessBlock:(IJSVGNodeParserPostProcessBlock*)postProcessBlock
{
    IJSVGRootNode* node = [[IJSVGRootNode alloc] init];
    [self parseSVGElement:element
                 ontoNode:node
               parentNode:parentNode
         postProcessBlock:postProcessBlock
                recursive:YES];
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
    
    node.x = [IJSVGUnitLength unitWithString:[element attributeForName:IJSVGAttributeX].stringValue];
    node.y = [IJSVGUnitLength unitWithString:[element attributeForName:IJSVGAttributeY].stringValue];
    node.width = [IJSVGUnitLength unitWithString:[element attributeForName:IJSVGAttributeWidth].stringValue];
    node.height = [IJSVGUnitLength unitWithString:[element attributeForName:IJSVGAttributeHeight].stringValue];
    node.rx = [IJSVGUnitLength unitWithString:[element attributeForName:IJSVGAttributeRX].stringValue];
    node.ry = [IJSVGUnitLength unitWithString:[element attributeForName:IJSVGAttributeRY].stringValue];
    
    IJSVGBitFlags64* flags = [[IJSVGBitFlags64 alloc] init];
    [flags setBit:IJSVGNodeAttributeX];
    [flags setBit:IJSVGNodeAttributeY];
    [flags setBit:IJSVGNodeAttributeWidth];
    [flags setBit:IJSVGNodeAttributeHeight];
    
    *postProcessBlock = [self computeAttributesFromElement:element
                                                    onNode:node
                                         ignoredAttributes:flags];
    
    return node;
}

- (IJSVGNode*)parseImageElement:(NSXMLElement*)element
                     parentNode:(IJSVGNode*)parentNode
               postProcessBlock:(IJSVGNodeParserPostProcessBlock*)postProcessBlock
{
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
  
    // We are trying to use an element that is a decedent of itself.
    if([self isElement:element decedentOf:detachedElement]) {
      [self recursionDetectedOn:element
                    decendentOf:detachedElement
                     identifier:xlinkID];
      return nil;
    }

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
    if(element.childCount == 0) {
        return;
    }
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
        // string length and free the subbuffer memory.
        memcpy(buffer + strLength, subbuf, sSize + 1);
        strLength += sSize;
        (void)free(subbuf), subbuf = NULL;
    }

    // append the close path if required
    if(closePath == YES) {
        // make sure there is room for 'z' plus the null terminator, the loop
        // reserves this, but a degenerate single-point poly skips the loop.
        if((strLength + 2) > bSize) {
            buffer = realloc(buffer, sizeof(char) * (strLength + 2));
            bSize = strLength + 2;
        }
        buffer[strLength] = 'z';
        buffer[strLength + 1] = '\0';
        strLength += 1;
    }
    
    NSArray<IJSVGCommand*>* commands = [IJSVGCommand commandsForDataCharacters:buffer
                                                                    dataStream:_commandDataStream];
    IJSVGNode* referencingNode = nil;
    path.pathUnits = [path contentUnitsWithReferencingNode:&referencingNode];
    
    CGMutablePathRef nPath = [IJSVGCommand newPathForCommandsArray:commands];
    path.path = nPath;
    CGPathRelease(nPath);
    
    // free the params
    (void)free(buffer), buffer = NULL;
    (void)free(params), params = NULL;
}

@end
