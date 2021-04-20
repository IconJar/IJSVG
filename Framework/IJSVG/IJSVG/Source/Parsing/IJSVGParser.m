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
        IJSVGAttributeMaskContentUnits : @"contentUnits"} retain];
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
    (void)([_glyphs release]), _glyphs = nil;
    (void)([_styleSheet release]), _styleSheet = nil;
    (void)([_defNodes release]), _defNodes = nil;
    (void)([_baseDefNodes release]), _baseDefNodes = nil;
    (void)([_svgs release]), _svgs = nil;
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

        _commandDataStream = IJSVGPathDataStreamCreateDefault();
        _defNodes = [[NSMutableDictionary alloc] init];

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
            [self _parse];
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
    if (self.isFont)
        return YES;

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

- (void)_parse
{
    NSXMLElement* svgElement = [_document rootElement];

    // parse common attributes on the SVG element
    [self _parseElementForCommonAttributes:svgElement
                                      node:self
                          ignoreAttributes:nil];

    // find the sizebox!
    NSXMLNode* attribute = nil;
    if ((attribute = [svgElement attributeForName:IJSVGAttributeViewBox]) != nil) {
        // we have a viewbox...
        CGFloat* box = [IJSVGUtils parseViewBox:attribute.stringValue];
        _viewBox = NSMakeRect(box[0], box[1], box[2], box[3]);
        (void)free(box);
    } else {
        // there is no view box so find the width and height
        NSString* wAtt = [svgElement attributeForName:IJSVGAttributeWidth].stringValue;
        NSString* hAtt = [svgElement attributeForName:IJSVGAttributeHeight].stringValue;
        IJSVGUnitLength* wLength = [IJSVGUnitLength unitWithString:wAtt];
        IJSVGUnitLength* hLength = [IJSVGUnitLength unitWithString:hAtt];
        
        // its possible wlength or hlength are nil
        CGFloat w = wLength ? wLength.value : 0.f;
        CGFloat h = hLength ? hLength.value : 0.f;
        
        if (h == 0.f && w != 0.f) {
            h = w;
        } else if (w == 0.f && h != 0.f) {
            w = h;
        }
        _viewBox = NSMakeRect(0.f, 0.f, w, h);
    }

    // parse the width and height....
    NSString* w = [svgElement attributeForName:IJSVGAttributeWidth].stringValue;
    NSString* h = [svgElement attributeForName:IJSVGAttributeHeight].stringValue;

    // by default just the the width and height from the viewbox unless
    // specified otherwise
    IJSVGUnitLength* wl = [IJSVGUnitLength unitWithFloat:_viewBox.size.width];
    IJSVGUnitLength* hl = [IJSVGUnitLength unitWithFloat:_viewBox.size.height];
    if (w != nil) {
        wl = [IJSVGUnitLength unitWithString:w];
    }
    if (h != nil) {
        hl = [IJSVGUnitLength unitWithString:h];
    }

    // store the width and height
    _intrinsicSize = [IJSVGUnitSize sizeWithWidth:wl height:hl].retain;

    // the root element is SVG, so iterate over its children
    // recursively
    self.name = svgElement.name;
    [self _parseBlock:svgElement
            intoGroup:self
                  def:NO];

    // dont need the style sheet or the parsed nodes as this point
    (void)([_styleSheet release]), _styleSheet = nil;
    (void)([_defNodes release]), _defNodes = nil;
    (void)IJSVGPathDataStreamRelease(_commandDataStream), _commandDataStream = NULL;
}

- (void)_postParseElementForCommonAttributes:(NSXMLElement*)element
                                        node:(IJSVGNode*)node
                            ignoreAttributes:(NSArray*)ignoredAttributes
{

    // first of all, compute a style sheet
    IJSVGStyle* sheetStyle = nil;
    __block IJSVGStyle* style = nil;

    // attribute helpers
    typedef void (^cp)(NSString*);

    // precaching the attributes is alot faster then asking for attribute for
    // name each time we want to grab a value ... weird
    NSArray<NSXMLNode*>* origAttributes = element.attributes;
    NSMutableDictionary<NSString*, NSString*>* attributes = nil;
    attributes = [[[NSMutableDictionary alloc] initWithCapacity:origAttributes.count] autorelease];
    for (NSXMLNode* node in origAttributes) {
        attributes[node.name] = node.stringValue;
    }

    void (^attr)(const NSString*, cp) = ^(NSString* key, cp block) {
        if ([ignoredAttributes containsObject:key]) {
            return;
        }
        NSString* v = [style property:key] ?: attributes[key];
        if (v != nil && v.length != 0) {
            block(v);
        }
    };

    typedef id (^cap)(NSString*);
    void (^atts)(NSDictionary<NSString*, NSString*>*, cap) = ^(NSDictionary<NSString*, NSString*>* kv, cap block) {
        for (NSString* key in kv.allKeys) {
            attr(key, ^(NSString* value) {
                [node setValue:block(value)
                        forKey:kv[key]];
            });
        }
    };

    // id, this must be here for the style sheet to actually
    // render and parse, basically it relies on ID/CSS selectors so these
    // must be in place before its computed
    attr(IJSVGAttributeID, ^(NSString* value) {
        node.identifier = value;
        _defNodes[node.identifier] = element;
    });

    //
    attr(IJSVGAttributeClass, ^(NSString* value) {
        node.className = value;
        node.classNameList = [value componentsSeparatedByString:@" "];
    });

    // work out the style sheet
    if (_styleSheet != nil) {
        sheetStyle = [_styleSheet styleForNode:node];
    }

    // is there a
    attr(IJSVGAttributeStyle, ^(NSString* value) {
        style = [IJSVGStyle parseStyleString:value];
    });

    // merge to two together
    if (sheetStyle != nil) {
        style = [sheetStyle mergedStyle:style];
    }

    // floats
    atts(_IJSVGAttributeDictionaryFloats,
        ^id(NSString* value) {
            return [IJSVGUnitLength unitWithString:value];
        });

    // nodes
    atts(_IJSVGAttributeDictionaryNodes,
        ^id(NSString* value) {
            NSString* url = [IJSVGUtils defURL:value];
            if (url != nil) {
                return [self definedObjectForID:url];
            }
            return nil;
        });

    // units
    atts(_IJSVGAttributeDictionaryUnits,
        ^id(NSString* value) {
            return @([IJSVGUtils unitTypeForString:value]);
        });

    // transforms
    atts(_IJSVGAttributeDictionaryTransforms,
        ^(NSString* value) {
            NSMutableArray* tempTransforms = [[[NSMutableArray alloc] init] autorelease];
            [tempTransforms addObjectsFromArray:[IJSVGTransform transformsForString:value]];
            if (node.transforms != nil) {
                [tempTransforms addObjectsFromArray:node.transforms];
            }
            return tempTransforms;
        });

#pragma mark attributes that require custom rules

    // unicode
    attr(IJSVGAttributeUnicode, ^(NSString* value) {
        node.unicode = [NSString stringWithFormat:@"%04x", [value characterAtIndex:0]];
    });

    // linecap
    attr(IJSVGAttributeStrokeLineCap, ^(NSString* value) {
        node.lineCapStyle = [IJSVGUtils lineCapStyleForString:value];
    });

    // line join
    attr(IJSVGAttributeLineJoin, ^(NSString* value) {
        node.lineJoinStyle = [IJSVGUtils lineJoinStyleForString:value];
    });

    // stroke color
    attr(IJSVGAttributeStroke, ^(NSString* value) {
        NSString* fillDefID = [IJSVGUtils defURL:value];
        if (fillDefID != nil) {
            // find the object
            id obj = [self definedObjectForID:fillDefID];

            // what type is it?
            if ([obj isKindOfClass:[IJSVGGradient class]]) {
                node.strokeGradient = (IJSVGGradient*)obj;
            } else if ([obj isKindOfClass:[IJSVGPattern class]]) {
                node.strokePattern = (IJSVGPattern*)obj;
            }
        } else {
            // its a color
            node.strokeColor = [IJSVGColor colorFromString:value];
        }

    });

    // stroke dash array
    attr(IJSVGAttributeStrokeDashArray, ^(NSString* value) {
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
    attr(IJSVGAttributeFill, ^(NSString* value) {
        NSString* fillDefID = [IJSVGUtils defURL:value];
        if (fillDefID != nil) {
            // find the object
            id obj = [self definedObjectForID:fillDefID];
            // what type is it?
            if ([obj isKindOfClass:[IJSVGGradient class]]) {
                node.fillGradient = (IJSVGGradient*)obj;
            } else if ([obj isKindOfClass:[IJSVGPattern class]]) {
                node.fillPattern = (IJSVGPattern*)obj;
            }
        } else {
            node.fillColor = [IJSVGColor colorFromString:value];
        }
    });

    // fill opacity
    attr(IJSVGAttributeFillOpacity, ^(NSString* value) {
        if (node.fillOpacity.value != 1.f) {
            node.fillColor = [IJSVGColor changeAlphaOnColor:node.fillColor
                                                         to:node.fillOpacity.value];
        }
    });

    // blendmode
    attr(IJSVGAttributeBlendMode, ^(NSString* value) {
        node.blendMode = [IJSVGUtils blendModeForString:value];
    });

    // fill rule
    attr(IJSVGAttributeFillRule, ^(NSString* value) {
        node.windingRule = [IJSVGUtils windingRuleForString:value];
    });

    // display
    attr(IJSVGAttributeDisplay, ^(NSString* value) {
        if ([value.lowercaseString isEqualToString:@"none"]) {
            node.shouldRender = NO;
        }
    });
    
    // offset
    attr(IJSVGAttributeOffset, ^(NSString* value) {
        node.offset = [IJSVGUnitLength unitWithString:value];
    });
    
    // stop-opacity
    attr(IJSVGAttributeStopOpacity, ^(NSString* value) {
        node.fillOpacity = [IJSVGUnitLength unitWithString:value];
    });
    
    // stop-color
    attr(IJSVGAttributeStopColor, ^(NSString* value) {
        node.fillColor = [IJSVGColor colorFromString:value];
        if(node.fillOpacity.value != 1.f) {
            node.fillColor = [IJSVGColor changeAlphaOnColor:node.fillColor
                                                         to:node.fillOpacity.value];
        }
    });
    
    // is there a title or desc?
    for(NSXMLElement* childElement in element.children) {
        IJSVGNodeType type = [IJSVGNode typeForString:childElement.localName
                                                 kind:childElement.kind];
        switch(type) {
            case IJSVGNodeTypeTitle: {
                node.title = childElement.stringValue;
                break;
            }
            case IJSVGNodeTypeDesc: {
                node.desc = childElement.stringValue;
                break;
            }
            default: {
            }
        }
    }
}

- (id)definedObjectForID:(NSString*)anID
              xmlElement:(NSXMLElement**)element
{
    // check base def nodes first, then check rest of document
    NSXMLElement* parseElement = _baseDefNodes[anID] ?: _defNodes[anID];
    if (parseElement != nil) {
        // parse the block
        if (element != nil && element != NULL) {
            *element = parseElement;
        }
        IJSVGGroup* group = [[[IJSVGGroup alloc] init] autorelease];
        [self _parseBaseBlock:parseElement
                    intoGroup:group
                          def:NO];
        return [group defForID:anID];
    }
    return nil;
}

- (id)definedObjectForID:(NSString*)anID
{
    return [self definedObjectForID:anID
                         xmlElement:nil];
}

- (BOOL)isFont
{
    return _glyphs != nil && [_glyphs count] != 0;
}

- (NSArray*)glyphs
{
    return _glyphs ?: @[];
}

- (void)addSubSVG:(IJSVG*)anSVG
{
    if (_svgs == nil) {
        _svgs = [[NSMutableArray alloc] init];
    }
    [_svgs addObject:anSVG];
}

- (NSArray<IJSVG*>*)subSVGs:(BOOL)recursive
{
    if (recursive == NO) {
        return _svgs ?: @[];
    }
    NSMutableArray<IJSVG*>* svgs = [[[NSMutableArray alloc] init] autorelease];
    for (IJSVG* anSVG in svgs) {
        [svgs addObject:anSVG];
        [svgs addObjectsFromArray:[anSVG subSVGs:recursive]];
    }
    return svgs;
}

- (void)addGlyph:(IJSVGPath*)glyph
{
    if (_glyphs == nil) {
        _glyphs = [[NSMutableArray alloc] init];
    }
    [_glyphs addObject:glyph];
}

- (void)_parseElementForCommonAttributes:(NSXMLElement*)element
                                    node:(IJSVGNode*)node
                        ignoreAttributes:(NSArray*)ignoredAttributes
{
    [self _postParseElementForCommonAttributes:element
                                          node:node
                              ignoreAttributes:ignoredAttributes];
}

- (void)_setupDefaultsForNode:(IJSVGNode*)node
{
    switch (node.type) {
    // mask
    case IJSVGNodeTypeMask: {
        node.units = IJSVGUnitObjectBoundingBox;
        break;
    }

    // gradient
    case IJSVGNodeTypeRadialGradient:
    case IJSVGNodeTypeLinearGradient: {
        node.units = IJSVGUnitObjectBoundingBox;
        break;
    }

    default: {
    }
    }
}

- (void)parseDefsForElement:(NSXMLElement*)anElement
{
    // nothing found
    if (anElement.childCount == 0) {
        return;
    }

    for (NSXMLElement* element in anElement.children) {
        // not a def
        if ([IJSVGNode typeForString:element.localName
                                kind:element.kind]
            != IJSVGNodeTypeDef) {
            continue;
        }

        // store each object
        for (NSXMLElement* childDef in element.children) {
            // is there any stylesheets within this?
            IJSVGNodeType childType = [IJSVGNode typeForString:childDef.localName
                                                          kind:element.kind];

            switch (childType) {
            case IJSVGNodeTypeStyle:
            case IJSVGNodeTypeGlyph:
            case IJSVGNodeTypeFont: {
                [self _parseBaseBlock:childDef
                            intoGroup:self
                                  def:NO];
                break;
            }
            case IJSVGNodeTypeNotFound: {
                // ignore, this is insanely important - specially if its a comment
                break;
            }
            default: {
                // just a default def, continue on, as we are a def element,
                // store these seperately to the default ID string ones
                if (_baseDefNodes == nil) {
                    _baseDefNodes = [[NSMutableDictionary alloc] init];
                }
                NSString* defID = [childDef attributeForName:IJSVGAttributeID].stringValue;
                if (defID != nil) {
                    _baseDefNodes[defID] = childDef;
                }
            }
            }
        }
    }
}

- (void)_parseBaseBlock:(NSXMLElement*)element
              intoGroup:(IJSVGGroup*)parentGroup
                    def:(BOOL)flag
{
    NSString* subName = element.localName;
    NSXMLNodeKind nodeKind = element.kind;
    IJSVGNodeType aType = [IJSVGNode typeForString:subName
                                              kind:nodeKind];
    switch (aType) {

    // do nothing
    default:
    case IJSVGNodeTypeNotFound: {
        break;
    }

    // style
    case IJSVGNodeTypeStyle: {
        // create the sheet
        if (_styleSheet == nil) {
            _styleSheet = [[IJSVGStyleSheet alloc] init];
        }

        // append the string
        [_styleSheet parseStyleBlock:element.stringValue];
        break;
    }

        // sub SVG
    case IJSVGNodeTypeSVG: {

        IJSVGGroup* path = [[[IJSVGGroup alloc] init] autorelease];
        path.type = aType;
        path.name = subName;

        // grab common attributes
        [self _setupDefaultsForNode:path];
        [self _parseElementForCommonAttributes:element
                                          node:path
                              ignoreAttributes:nil];

        // if its a sub svg, we can remove the attributes for x and y
        // this is required or it could go out of bounds before the exporter
        // hits the layers from the groups :)
        [element removeAttributeForName:IJSVGAttributeX];
        [element removeAttributeForName:IJSVGAttributeY];

        // work out the SVG
        NSError* error = nil;
        NSString* SVGString = element.XMLString;
        IJSVG* anSVG = [[[IJSVG alloc] initWithSVGString:SVGString
                                                   error:&error
                                                delegate:nil] autorelease];

        // handle sub SVG
        if (error == nil && _respondsTo.handleSubSVG == 1) {
            [_delegate svgParser:self
                     foundSubSVG:anSVG
                   withSVGString:SVGString];
        }

        // any error?
        if (anSVG != nil && error == nil) {
            path.svg = anSVG;
            [parentGroup addChild:path];
            [parentGroup addDef:path];

            // make sure we add this
            [self addSubSVG:anSVG];
        }
        break;
    }

        // glyph
    case IJSVGNodeTypeGlyph: {

        // no path data
        if ([element attributeForName:IJSVGAttributeD] == nil ||
            [[element attributeForName:IJSVGAttributeD] stringValue].length == 0) {
            break;
        }

        IJSVGPath* path = [[[IJSVGPath alloc] init] autorelease];
        path.type = aType;
        path.name = subName;
        path.parentNode = parentGroup;

        // find common attributes
        [self _setupDefaultsForNode:path];
        [self _parseElementForCommonAttributes:element
                                          node:path
                              ignoreAttributes:nil];

        // pass the commands for it
        [self _parsePathCommandData:[[element attributeForName:IJSVGAttributeD] stringValue]
                           intoPath:path];

        // check the size...
        if (CGRectIsEmpty(path.controlPointBoundingBox) == YES) {
            break;
        }
        
        // add the glyph
        [self addGlyph:path];
        break;
    }

        // group
    case IJSVGNodeTypeSwitch:
    case IJSVGNodeTypeFont:
    case IJSVGNodeTypeMask:
    case IJSVGNodeTypeGroup: {

        // parse the defs
        [self parseDefsForElement:element];

        // create a new group
        IJSVGGroup* group = [[[IJSVGGroup alloc] init] autorelease];
        group.type = aType;
        group.name = subName;
        group.parentNode = parentGroup;

        // only groups get added to parent, rest is added as a def -
        // also addition of switches
        if (!flag && ((aType == IJSVGNodeTypeGroup) || (aType == IJSVGNodeTypeSwitch))) {
            [parentGroup addChild:group];
        }

        // find common attributes
        [self _setupDefaultsForNode:group];
        [self _parseElementForCommonAttributes:element
                                          node:group
                              ignoreAttributes:nil];

        // recursively parse blocks
        [self _parseBlock:element
                intoGroup:group
                      def:NO];

        [parentGroup addDef:group];
        break;
    }

        // path
    case IJSVGNodeTypePath: {
        IJSVGPath* path = [[[IJSVGPath alloc] init] autorelease];
        path.type = aType;
        path.name = subName;
        path.parentNode = parentGroup;

        if (!flag) {
            [parentGroup addChild:path];
        }

        // find common attributes
        [self _setupDefaultsForNode:path];
        [self _parseElementForCommonAttributes:element
                                          node:path
                              ignoreAttributes:nil];
        [self _parsePathCommandData:[[element attributeForName:IJSVGAttributeD] stringValue]
                           intoPath:path];

        [parentGroup addDef:path];
        break;
    }

        // polygon
    case IJSVGNodeTypePolygon: {
        IJSVGPath* path = [[[IJSVGPath alloc] init] autorelease];
        path.type = aType;
        path.name = subName;
        path.parentNode = parentGroup;

        if (!flag) {
            [parentGroup addChild:path];
        }

        // find common attributes
        [self _setupDefaultsForNode:path];
        [self _parseElementForCommonAttributes:element
                                          node:path
                              ignoreAttributes:nil];
        [self _parsePolygon:element
                   intoPath:path];
        [parentGroup addDef:path];
        break;
    }

        // polyline
    case IJSVGNodeTypePolyline: {
        IJSVGPath* path = [[[IJSVGPath alloc] init] autorelease];
        path.type = aType;
        path.name = subName;
        path.parentNode = parentGroup;

        if (!flag) {
            [parentGroup addChild:path];
        }

        // find common attributes
        [self _setupDefaultsForNode:path];
        [self _parseElementForCommonAttributes:element
                                          node:path
                              ignoreAttributes:nil];
        [self _parsePolyline:element
                    intoPath:path];
        [parentGroup addDef:path];
        break;
    }

        // rect
    case IJSVGNodeTypeRect: {
        IJSVGPath* path = [[[IJSVGPath alloc] init] autorelease];
        path.type = aType;
        path.name = subName;
        path.parentNode = parentGroup;

        if (!flag) {
            [parentGroup addChild:path];
        }

        // find common attributes
        [self _parseRect:element
                intoPath:path];

        [self _setupDefaultsForNode:path];
        [self _parseElementForCommonAttributes:element
                                          node:path
                              ignoreAttributes:@[ IJSVGAttributeX, IJSVGAttributeY ]];
        [parentGroup addDef:path];
        break;
    }

        // line
    case IJSVGNodeTypeLine: {
        IJSVGPath* path = [[[IJSVGPath alloc] init] autorelease];
        path.type = aType;
        path.name = subName;
        path.parentNode = parentGroup;

        [parentGroup addChild:path];

        // find common attributes
        [self _setupDefaultsForNode:path];
        [self _parseElementForCommonAttributes:element
                                          node:path
                              ignoreAttributes:nil];
        [self _parseLine:element
                intoPath:path];
        [parentGroup addDef:path];
        break;
    }

        // circle
    case IJSVGNodeTypeCircle: {
        IJSVGPath* path = [[[IJSVGPath alloc] init] autorelease];
        path.type = aType;
        path.name = subName;
        path.parentNode = parentGroup;

        if (!flag) {
            [parentGroup addChild:path];
        }

        // find common attributes
        [self _setupDefaultsForNode:path];
        [self _parseElementForCommonAttributes:element
                                          node:path
                              ignoreAttributes:nil];
        [self _parseCircle:element
                  intoPath:path];
        [parentGroup addDef:path];
        break;
    }

        // ellipse
    case IJSVGNodeTypeEllipse: {
        IJSVGPath* path = [[[IJSVGPath alloc] init] autorelease];
        path.type = aType;
        path.name = subName;
        path.parentNode = parentGroup;

        if (!flag) {
            [parentGroup addChild:path];
        }

        // find common attributes
        [self _setupDefaultsForNode:path];
        [self _parseElementForCommonAttributes:element
                                          node:path
                              ignoreAttributes:nil];
        [self _parseEllipse:element
                   intoPath:path];
        [parentGroup addDef:path];
        break;
    }

        // use
    case IJSVGNodeTypeUse: {

        NSString* xlink = [[self resolveXLinkAttributeForElement:element] stringValue];
        NSString* xlinkID = [xlink substringFromIndex:1];
        IJSVGNode* node = [self definedObjectForID:xlinkID];

        // there was no specified link ID, well, not that we could find,
        // so just break
        if (node == nil) {
            break;
        }

        // due to this being a carbon clone, we need to clear the ID
        if ([element attributeForName:IJSVGAttributeID] == nil) {
            node.identifier = nil;
        }

        // at this point, we need to create another group!
        IJSVGGroup* subGroup = [[[IJSVGGroup alloc] init] autorelease];
        subGroup.parentNode = parentGroup;
        [subGroup addChild:node];
        node.parentNode = subGroup;
        node.intermediateParentNode = subGroup;

        // is there a width and height?
        CGFloat x = [element attributeForName:IJSVGAttributeX].stringValue.floatValue;
        CGFloat y = [element attributeForName:IJSVGAttributeY].stringValue.floatValue;

        // we need to add a transform to the subgroup
        subGroup.transforms = @[ [IJSVGTransform transformByTranslatingX:x y:y] ];

        if (!flag) {
            [parentGroup addChild:subGroup];
        }

        // parse attributes from element onto group - but spec
        // says ignore x, y, width, height and xlink:href...
        [self _parseElementForCommonAttributes:element
                                          node:node
                              ignoreAttributes:@[IJSVGAttributeX, IJSVGAttributeY,
                                                 IJSVGAttributeWidth, IJSVGAttributeHeight,
                                                 IJSVGAttributeXLink]];

        [parentGroup addDef:node];
        break;
    }
     
        // stop color
    case IJSVGNodeTypeStop: {
        IJSVGNode* node = [[[IJSVGNode alloc] init] autorelease];
        node.type = IJSVGNodeTypeStop;
        [self _setupDefaultsForNode:node];
        [self _parseElementForCommonAttributes:element
                                          node:node
                              ignoreAttributes:nil];
        [parentGroup addChild:node];
        break;
    }

        // linear gradient
    case IJSVGNodeTypeLinearGradient: {

        NSString* xlink = [[self resolveXLinkAttributeForElement:element] stringValue];
        NSString* xlinkID = [xlink substringFromIndex:1];
        NSXMLElement* referenceElement;
        IJSVGNode* node = [self definedObjectForID:xlinkID
                                        xmlElement:&referenceElement];
        if (node != nil) {
            // we are a clone
            NSXMLElement* elementCopy = [self mergedElement:element
                                       withReferenceElement:referenceElement];

            IJSVGLinearGradient* grad = [[[IJSVGLinearGradient alloc] init] autorelease];
            grad.type = aType;
            [self _setupDefaultsForNode:grad];
            [self _parseElementForCommonAttributes:elementCopy
                                              node:grad
                                  ignoreAttributes:nil];
            [self _parseBlock:elementCopy
                    intoGroup:grad
                          def:NO];
            grad.gradient = [IJSVGLinearGradient parseGradient:elementCopy
                                                      gradient:grad];
            [parentGroup addDef:grad];
            break;
        }

        IJSVGLinearGradient* gradient = [[[IJSVGLinearGradient alloc] init] autorelease];
        gradient.type = aType;
        [self _setupDefaultsForNode:gradient];
        [self _parseElementForCommonAttributes:element
                                          node:gradient
                              ignoreAttributes:nil];
        [self _parseBlock:element
                intoGroup:gradient
                      def:NO];
        gradient.gradient = [IJSVGLinearGradient parseGradient:element
                                                      gradient:gradient];
        [parentGroup addDef:gradient];
        break;
    }

        // radial gradient
    case IJSVGNodeTypeRadialGradient: {

        NSString* xlink = [[self resolveXLinkAttributeForElement:element] stringValue];
        NSString* xlinkID = [xlink substringFromIndex:1];
        NSXMLElement* referenceElement;
        IJSVGNode* node = [self definedObjectForID:xlinkID
                                        xmlElement:&referenceElement];
        if (node != nil) {
            // we are a clone
            IJSVGRadialGradient* grad = [[[IJSVGRadialGradient alloc] init] autorelease];
            grad.type = aType;

            NSXMLElement* elementCopy = [self mergedElement:element
                                       withReferenceElement:referenceElement];
            [self _setupDefaultsForNode:grad];
            [self _parseElementForCommonAttributes:elementCopy
                                              node:grad
                                  ignoreAttributes:nil];
            [self _parseBlock:elementCopy
                    intoGroup:grad
                          def:NO];
            grad.gradient = [IJSVGRadialGradient parseGradient:elementCopy
                                                      gradient:grad];
            [parentGroup addDef:grad];
            break;
        }

        IJSVGRadialGradient* gradient = [[[IJSVGRadialGradient alloc] init] autorelease];
        gradient.type = aType;
        [self _setupDefaultsForNode:gradient];
        [self _parseElementForCommonAttributes:element
                                          node:gradient
                              ignoreAttributes:nil];
        [self _parseBlock:element
                intoGroup:gradient
                      def:NO];
        gradient.gradient = [IJSVGRadialGradient parseGradient:element
                                                      gradient:gradient];
        [parentGroup addDef:gradient];
        break;
    }

        // clippath
    case IJSVGNodeTypeClipPath: {

        IJSVGGroup* group = [[[IJSVGGroup alloc] init] autorelease];
        group.type = aType;
        group.name = subName;
        group.parentNode = parentGroup;

        [self _setupDefaultsForNode:group];

        // find common attributes
        [self _parseElementForCommonAttributes:element
                                          node:group
                              ignoreAttributes:nil];

        // recursively parse blocks
        [self _parseBlock:element
                intoGroup:group
                      def:NO];
        [parentGroup addDef:group];
        break;
    }

    // pattern
    case IJSVGNodeTypePattern: {
        IJSVGPattern* pattern = [[[IJSVGPattern alloc] init] autorelease];

        [self _setupDefaultsForNode:pattern];

        // find common attributes
        [self _parseElementForCommonAttributes:element
                                          node:pattern
                              ignoreAttributes:nil];

        // pattern has children
        [self _parseBlock:element
                intoGroup:pattern
                      def:NO];

        [parentGroup addDef:pattern];
        break;
    }

    // image
    case IJSVGNodeTypeImage: {
        IJSVGImage* image = [[[IJSVGImage alloc] init] autorelease];

        [self _setupDefaultsForNode:image];

        // find common attributes
        [self _parseElementForCommonAttributes:element
                                          node:image
                              ignoreAttributes:nil];

        // from base64
        NSXMLNode* attributeNode = [self resolveXLinkAttributeForElement:element] ?:
            [element attributeForName:IJSVGAttributeHref];
        [image loadFromString:attributeNode.stringValue];

        // add to parent
        [parentGroup addChild:image];
        [parentGroup addDef:image];
        break;
    }
    }
}

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

- (void)_parseBlock:(NSXMLElement*)anElement
          intoGroup:(IJSVGGroup*)parentGroup
                def:(BOOL)flag
{
    // parse the defs
    [self parseDefsForElement:anElement];

    // parse the children
    for (NSXMLElement* element in [anElement children]) {
        [self _parseBaseBlock:element
                    intoGroup:parentGroup
                          def:flag];
    }
}

#pragma mark Parser stuff!

- (void)_parsePathCommandDataBuffer:(const char*)buffer
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
            IJSVGCommand* cCommand = [self _parseCommandStringBuffer:commandString
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

- (void)_parsePathCommandData:(NSString*)command
                     intoPath:(IJSVGPath*)path
{
    // invalid command
    if (command == nil || command.length == 0) {
        return;
    }

    // allocate memory for the string buffer for reading
    const char* buffer = command.UTF8String;
    [self _parsePathCommandDataBuffer:buffer
                             intoPath:path];
}

- (IJSVGCommand*)_parseCommandStringBuffer:(const char*)buffer
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

- (void)_parseLine:(NSXMLElement*)element
          intoPath:(IJSVGPath*)path
{
    // convert a line into a command,
    // basically MX1 Y1LX2 Y2
    path.primitiveType = kIJSVGPrimitivePathTypeLine;
    CGFloat x1 = [element attributeForName:IJSVGAttributeX1].stringValue.floatValue;
    CGFloat y1 = [element attributeForName:IJSVGAttributeY1].stringValue.floatValue;
    CGFloat x2 = [element attributeForName:IJSVGAttributeX2].stringValue.floatValue;
    CGFloat y2 = [element attributeForName:IJSVGAttributeY2].stringValue.floatValue;

    // use sprintf as its quicker then stringWithFormat...
    char* buffer;
    asprintf(&buffer, "M%.2f %.2fL%.2f %.2f", x1, y1, x2, y2);
    [self _parsePathCommandDataBuffer:buffer
                             intoPath:path];
    (void)free(buffer);
}

- (void)_parseCircle:(NSXMLElement*)element
            intoPath:(IJSVGPath*)path
{
    path.primitiveType = kIJSVGPrimitivePathTypeCircle;
    CGFloat cX = [element attributeForName:IJSVGAttributeCX].stringValue.floatValue;
    CGFloat cY = [element attributeForName:IJSVGAttributeCY].stringValue.floatValue;
    CGFloat r = [element attributeForName:IJSVGAttributeR].stringValue.floatValue;
    CGRect rect = CGRectMake(cX - r, cY - r, r * 2, r * 2);
    CGPathRef nPath = CGPathCreateWithEllipseInRect(rect, NULL);
    path.path = (CGMutablePathRef)nPath;
    CGPathRelease(nPath);
}

- (void)_parseEllipse:(NSXMLElement*)element
             intoPath:(IJSVGPath*)path
{
    path.primitiveType = kIJSVGPrimitivePathTypeEllipse;
    CGFloat cX = [element attributeForName:IJSVGAttributeCX].stringValue.floatValue;
    CGFloat cY = [element attributeForName:IJSVGAttributeCY].stringValue.floatValue;
    CGFloat rX = [element attributeForName:IJSVGAttributeRX].stringValue.floatValue;
    CGFloat rY = [element attributeForName:IJSVGAttributeRY].stringValue.floatValue;
    NSRect rect = NSMakeRect(cX - rX, cY - rY, rX * 2, rY * 2);
    CGPathRef nPath = CGPathCreateWithEllipseInRect(rect, NULL);
    path.path = (CGMutablePathRef)nPath;
    CGPathRelease(nPath);
}

- (void)_parsePolyline:(NSXMLElement*)element
              intoPath:(IJSVGPath*)path
{
    path.primitiveType = kIJSVGPrimitivePathTypePolyLine;
    [self _parsePoly:element
            intoPath:path
           closePath:NO];
}

- (void)_parsePolygon:(NSXMLElement*)element
             intoPath:(IJSVGPath*)path
{
    path.primitiveType = kIJSVGPrimitivePathTypePolygon;
    [self _parsePoly:element
            intoPath:path
           closePath:YES];
}

- (void)_parsePoly:(NSXMLElement*)element
          intoPath:(IJSVGPath*)path
         closePath:(BOOL)closePath
{
    NSString* points = [element attributeForName:IJSVGAttributePoints].stringValue;
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
    [self _parsePathCommandDataBuffer:buffer
                             intoPath:path];
    
    // free the params
    (void)free(buffer), buffer = NULL;
    (void)free(params), params = NULL;
}

- (void)_parseRect:(NSXMLElement*)element
          intoPath:(IJSVGPath*)path
{
    path.primitiveType = kIJSVGPrimitivePathTypeRect;
    // width and height
    CGFloat width = [IJSVGUtils floatValue:[element attributeForName:IJSVGAttributeWidth].stringValue
                        fallBackForPercent:self.viewBox.size.width];

    CGFloat height = [IJSVGUtils floatValue:[element attributeForName:IJSVGAttributeHeight].stringValue
                         fallBackForPercent:self.viewBox.size.height];

    // rect uses x and y as start of path, not move path object -_-
    CGFloat x = [IJSVGUtils floatValue:[element attributeForName:IJSVGAttributeX].stringValue
                    fallBackForPercent:self.viewBox.size.width];
    CGFloat y = [IJSVGUtils floatValue:[element attributeForName:IJSVGAttributeY].stringValue
                    fallBackForPercent:self.viewBox.size.height];

    // radius
    CGFloat rX = [element attributeForName:IJSVGAttributeRX].stringValue.floatValue;
    CGFloat rY = [element attributeForName:IJSVGAttributeRY].stringValue.floatValue;
    if ([element attributeForName:IJSVGAttributeRY] == nil) {
        rY = rX;
    }
    CGRect rect = CGRectMake(x, y, width, height);
    CGPathRef nPath = CGPathCreateWithRoundedRect(rect, rX, rY, NULL);
    path.path = (CGMutablePathRef)nPath;
    CGPathRelease(nPath);
}

@end
