//
//  IJSVGParser.m
//  IconJar
//
//  Created by Curtis Hard on 30/08/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import "IJSVGParser.h"
#import "IJSVG.h"

@implementation IJSVGParser

@synthesize viewBox;
@synthesize proposedViewSize;

+ (IJSVGParser *)groupForFileURL:(NSURL *)aURL
{
    return [[self class] groupForFileURL:aURL
                                   error:nil
                                delegate:nil];
}

+ (IJSVGParser *)groupForFileURL:(NSURL *)aURL
                        delegate:(id<IJSVGParserDelegate>)delegate
{
    return [[self class] groupForFileURL:aURL
                                   error:nil
                                delegate:delegate];
}

+ (IJSVGParser *)groupForFileURL:(NSURL *)aURL
                           error:(NSError **)error
                        delegate:(id<IJSVGParserDelegate>)delegate
{
    return [[[[self class] alloc] initWithFileURL:aURL
                                            error:error
                                         delegate:delegate] autorelease];
}

- (void)dealloc
{
    [_glyphs release], _glyphs = nil;
    [_styleSheet release], _styleSheet = nil;
    [_parsedNodes release], _parsedNodes = nil;
    [_defNodes release], _defNodes = nil;
    [_baseDefNodes release], _baseDefNodes = nil;
    [_svgs release], _svgs = nil;
    [super dealloc];
}

- (id)initWithSVGString:(NSString *)string
                  error:(NSError **)error
               delegate:(id<IJSVGParserDelegate>)delegate
{
    if( ( self = [super init] ) != nil )
    {
        _delegate = delegate;
        
        _respondsTo.handleForeignObject = [_delegate respondsToSelector:@selector(svgParser:handleForeignObject:document:)];
        _respondsTo.shouldHandleForeignObject = [_delegate respondsToSelector:@selector(svgParser:shouldHandleForeignObject:)];
        _respondsTo.handleSubSVG = [_delegate respondsToSelector:@selector(svgParser:foundSubSVG:withSVGString:)];
        
        _glyphs = [[NSMutableArray alloc] init];
        _parsedNodes = [[NSMutableArray alloc] init];
        _defNodes = [[NSMutableDictionary alloc] init];
        _baseDefNodes = [[NSMutableDictionary alloc] init];
        _svgs = [[NSMutableArray alloc] init];
        
        // load the document / file, assume its UTF8
        
        
        // use NSXMLDocument as its the easiest thing to do on OSX
        NSError * anError = nil;
        @try {
            _document = [[NSXMLDocument alloc] initWithXMLString:string
                                                         options:0
                                                           error:&anError];
        }
        @catch (NSException *exception) {
        }
        
        // error parsing the XML document
        if( anError != nil ) {
            return [self _handleErrorWithCode:IJSVGErrorParsingFile
                                        error:error];
        }
        
        // attempt to parse the file
        anError = nil;
        @try {
            [self _parse];
        }
        @catch (NSException *exception) {
            return [self _handleErrorWithCode:IJSVGErrorParsingSVG
                                        error:error];
        }
        
        
        // check the actual parsed SVG
        anError = nil;
        if( ![self _validateParse:&anError] ) {
            *error = anError;
            [_document release], _document = nil;
            [self release], self = nil;
            return nil;
        }
        
        // we have actually finished with the document at this point
        // so just get rid of it
        [_document release], _document = nil;
        
    }
    return self;
    
}

- (id)initWithFileURL:(NSURL *)aURL
                error:(NSError **)error
             delegate:(id<IJSVGParserDelegate>)delegate
{
    NSError * anError = nil;
    NSStringEncoding encoding;
    NSString * str = [NSString stringWithContentsOfFile:aURL.path
                                           usedEncoding:&encoding
                                                  error:&anError];
    
    // error reading file
    if(str == nil) {
        return [self _handleErrorWithCode:IJSVGErrorReadingFile
                                    error:error];
    }
    
    return [self initWithSVGString:str
                             error:error
                          delegate:delegate];
}

- (void *)_handleErrorWithCode:(NSUInteger)code
                         error:(NSError **)error
{
    if( error )
        *error = [[[NSError alloc] initWithDomain:IJSVGErrorDomain
                                             code:code
                                         userInfo:nil] autorelease];
    [_document release], _document = nil;
    [self release], self = nil;
    return nil;
}

- (BOOL)_validateParse:(NSError **)error
{
    // check is font
    if( self.isFont )
        return YES;
    
    // check the viewbox
    if( NSEqualRects( self.viewBox, NSZeroRect ) ||
       self.size.width == 0 || self.size.height == 0 )
    {
        if( error != NULL )
            *error = [[[NSError alloc] initWithDomain:IJSVGErrorDomain
                                                 code:IJSVGErrorInvalidViewBox
                                             userInfo:nil] autorelease];
        return NO;
    }
    return YES;
}

- (NSSize)size
{
    return viewBox.size;
}

- (void)_parse
{
    NSXMLElement * svgElement = [_document rootElement];
    
    // parse common attributes on the SVG element
    [self _parseElementForCommonAttributes:svgElement
                                      node:self];
    
    // find the sizebox!
    NSXMLNode * attribute = nil;
    if( ( attribute = [svgElement attributeForName:(NSString *)IJSVGAttributeViewBox] ) != nil ) {
        
        // we have a viewbox...
        CGFloat * box = [IJSVGUtils parseViewBox:[attribute stringValue]];
        viewBox = NSMakeRect( box[0], box[1], box[2], box[3]);
        free(box);
        
    } else {
        
        // there is no view box so find the width and height
        CGFloat w = [[[svgElement attributeForName:(NSString *)IJSVGAttributeWidth] stringValue] floatValue];
        CGFloat h = [[[svgElement attributeForName:(NSString *)IJSVGAttributeHeight] stringValue] floatValue];
        if( h == 0.f && w != 0.f )
            h = w;
        else if( w == 0.f && h != 0.f )
            w = h;
        viewBox = NSMakeRect( 0.f, 0.f, w, h );
    }
    
    // parse the width and height....
    CGFloat w = [[[svgElement attributeForName:(NSString *)IJSVGAttributeWidth] stringValue] floatValue];
    CGFloat h = [[[svgElement attributeForName:(NSString *)IJSVGAttributeHeight] stringValue] floatValue];
    if( w == 0.f && h == 0.f ) {
        w = viewBox.size.width;
        h = viewBox.size.height;
    } else if( w == 0 && h != 0.f ) {
        w = viewBox.size.width;
    } else if( h == 0 && w != 0.f ) {
        h = viewBox.size.height;
    }
    proposedViewSize = NSMakeSize( w, h );
    
    // the root element is SVG, so iterate over its children
    // recursively
    self.name = svgElement.name;
    [self _parseBlock:svgElement
            intoGroup:self
                  def:NO];
    
    // now everything has been done we need to compute the style tree
    for(NSDictionary * dict in _parsedNodes) {
        [self _postParseElementForCommonAttributes:dict[@"element"]
                                              node:dict[@"node"]];
    }
    
    // dont need the style sheet or the parsed nodes as this point
    [_styleSheet release], _styleSheet = nil;
    [_parsedNodes release], _parsedNodes = nil;
    [_defNodes release], _defNodes = nil;
}

- (void)_postParseElementForCommonAttributes:(NSXMLElement *)element
                                        node:(IJSVGNode *)node
{
    
    // first of all, compute a style sheet
    IJSVGStyle * sheetStyle = nil;
    __block IJSVGStyle * style = nil;
    
    // attribute helpers
    typedef void (^cp)(NSString *);
    void (^attr)(const NSString *, cp) = ^(NSString * key, cp block) {
        NSString * v = [element attributeForName:key].stringValue
        ?: [style property:key];
        if(v != nil && v.length != 0) {
            block(v);
        }
    };
    
    typedef id (^cap)(NSString *);
    void (^atts)(NSDictionary<NSString *, NSString *> *, cap) =
    ^(NSDictionary<NSString *, NSString *>* kv, cap block) {
        for(NSString * key in kv.allKeys) {
            attr(key, ^(NSString * value) {
                [node setValue:block(value)
                        forKey:kv[key]];
            });
        }
    };
    
    // id, this must be here for the style sheet to actually
    // render and parse, basically it relies on ID/CSS selectors so these
    // must be in place before its computed
    attr(IJSVGAttributeID, ^(NSString * value) {
        node.identifier = value;
        _defNodes[node.identifier] = element;
    });
    
    //
    attr(IJSVGAttributeClass, ^(NSString * value) {
        node.className = value;
        node.classNameList = [value componentsSeparatedByString:@" "];
    });
    
    // work out the style sheet
    if(_styleSheet != nil) {
        sheetStyle = [_styleSheet styleForNode:node];
    }
    
    // is there a
    attr(IJSVGAttributeStyle, ^(NSString * value) {
        style = [IJSVGStyle parseStyleString:value];
    });
    
    // merge to two together
    if(sheetStyle != nil) {
        style = [sheetStyle mergedStyle:style];
    }
    
    // floats
    atts(@{IJSVGAttributeX:@"x",
           IJSVGAttributeY:@"y",
           IJSVGAttributeWidth:@"width",
           IJSVGAttributeHeight:@"height",
           IJSVGAttributeOpacity:@"opacity",
           IJSVGAttributeStrokeOpacity:@"strokeOpacity",
           IJSVGAttributeStrokeWidth:@"strokeWidth",
           IJSVGAttributeStrokeDashOffset:@"strokeDashOffset",
           IJSVGAttributeFillOpacity:@"fillOpacity"}, ^id (NSString * value) {
        return [IJSVGUnitLength unitWithString:value];
    });
    
    // nodes
    atts(@{IJSVGAttributeClipPath:@"clipPath",
           IJSVGAttributeMask:@"mask"}, ^id (NSString * value) {
               NSString * url = [IJSVGUtils defURL:value];
               if(url != nil) {
                   return [self definedObjectForID:url];
               }
               return nil;
           });
    
    // units
    atts(@{IJSVGAttributeGradientUnits:@"units",
           IJSVGAttributeMaskUnits:@"units",
           IJSVGAttributeMaskContentUnits:@"contentUnits"}, ^id (NSString * value) {
               return @([IJSVGUtils unitTypeForString:value]);
           });
    
    // transforms
    atts(@{IJSVGAttributeTransform:@"transforms",
           IJSVGAttributeGradientTransform:@"transforms"}, ^(NSString * value) {
               NSMutableArray * tempTransforms = [[[NSMutableArray alloc] init] autorelease];
               [tempTransforms addObjectsFromArray:[IJSVGTransform transformsForString:value]];
               if(node.transforms != nil) {
                   [tempTransforms addObjectsFromArray:node.transforms];
               }
               return tempTransforms;
    });
    
#pragma mark attributes that require custom rules
    
    // unicode
    attr(IJSVGAttributeUnicode, ^(NSString * value) {
        node.unicode = [NSString stringWithFormat:@"%04x",[value characterAtIndex:0]];
    });
    
    // linecap
    attr(IJSVGAttributeStrokeLineCap, ^(NSString * value) {
        node.lineCapStyle = [IJSVGUtils lineCapStyleForString:value];
    });
    
    // line join
    attr(IJSVGAttributeLineJoin, ^(NSString * value) {
        node.lineJoinStyle = [IJSVGUtils lineJoinStyleForString:value];
    });
    
    // stroke color
    attr(IJSVGAttributeStroke, ^(NSString * value) {
        NSString * fillDefID = [IJSVGUtils defURL:value];
        if(fillDefID != nil) {
            // find the object
            id obj = [self definedObjectForID:fillDefID];
            
            // what type is it?
            if([obj isKindOfClass:[IJSVGGradient class]]) {
                node.strokeGradient = (IJSVGGradient *)obj;
            } else if([obj isKindOfClass:[IJSVGPattern class]]) {
                node.strokePattern = (IJSVGPattern *)obj;
            }
        } else {
            // its a color
            node.strokeColor = [IJSVGColor colorFromString:value];
        }

    });
    
    // stroke dash array
    attr(IJSVGAttributeStrokeDashArray, ^(NSString * value) {
        // nothing specified
        if([value isEqualToString:@"none"]) {
            node.strokeDashArrayCount = 0;
            return;
        }
        NSInteger paramCount = 0;
        CGFloat * params = [IJSVGUtils commandParameters:value
                                                   count:&paramCount];
        node.strokeDashArray = params;
        node.strokeDashArrayCount = paramCount;
    });
    
    // fill - seems kinda complicated for what it actually is
    attr(IJSVGAttributeFill, ^(NSString * value) {
        NSString * fillDefID = [IJSVGUtils defURL:value];
        if(fillDefID != nil) {
            // find the object
            id obj = [self definedObjectForID:fillDefID];
            
            // what type is it?
            if([obj isKindOfClass:[IJSVGGradient class]]) {
                node.fillGradient = (IJSVGGradient *)obj;
            } else if([obj isKindOfClass:[IJSVGPattern class]]) {
                node.fillPattern = (IJSVGPattern *)obj;
            }
        } else {
            // its a color
            node.fillColor = [IJSVGColor colorFromString:value];
            if(node.fillOpacity.value != 1.f) {
                node.fillColor = [IJSVGColor changeAlphaOnColor:node.fillColor
                                                             to:node.fillOpacity.value];
            }
        }
    });
    
    // blendmode
    attr(IJSVGAttributeBlendMode, ^(NSString * value) {
        node.blendMode = [IJSVGUtils blendModeForString:value];
    });
    
    // fill rule
    attr(IJSVGAttributeFillRule, ^(NSString * value) {
        node.windingRule = [IJSVGUtils windingRuleForString:value];
    });
    
    // display
    attr(IJSVGAttributeDisplay, ^(NSString * value) {
        if([value.lowercaseString isEqualToString:@"none"]) {
            node.shouldRender = NO;
        }
    });
}

- (id)definedObjectForID:(NSString *)anID
{
    // check base def nodes first, then check rest of document
    NSXMLElement * parseElement = _baseDefNodes[anID] ?: _defNodes[anID];
    if(parseElement != nil) {
        // parse the element
        IJSVGGroup * group = [[[IJSVGGroup alloc] init] autorelease];
        
        // parse the block
        [self _parseBaseBlock:parseElement
                    intoGroup:group
                          def:NO];
        return [group defForID:anID];
    }
    return nil;
}

- (BOOL)isFont
{
    return [_glyphs count] != 0;
}

- (NSArray *)glyphs
{
    return _glyphs;
}

- (void)addSubSVG:(IJSVG *)anSVG
{
    [_svgs addObject:anSVG];
}

- (NSArray<IJSVG *> *)subSVGs:(BOOL)recursive
{
    if(recursive == NO) {
        return _svgs;
    }
    NSMutableArray * svgs = [[[NSMutableArray alloc] init] autorelease];
    for(IJSVG * anSVG in svgs) {
        [svgs addObject:anSVG];
        [svgs addObjectsFromArray:[anSVG subSVGs:recursive]];
    }
    return svgs;
}

- (void)addGlyph:(IJSVGNode *)glyph
{
    [_glyphs addObject:glyph];
}

- (void)_parseElementForCommonAttributes:(NSXMLElement *)element
                                    node:(IJSVGNode *)node
{
    [self _postParseElementForCommonAttributes:element
                                          node:node];
}

- (void)_setupDefaultsForNode:(IJSVGNode *)node
{
    switch(node.type) {
        // mask
        case IJSVGNodeTypeMask :{
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

- (void)parseDefsForElement:(NSXMLElement *)anElement
{
    // nothing found
    if(anElement.childCount == 0) {
        return;
    }
    
    for(NSXMLElement * element in anElement.children) {
        // not a def
        if([IJSVGNode typeForString:element.name
                               kind:element.kind] != IJSVGNodeTypeDef) {
            continue;
        }
        
        // store each object
        for(NSXMLElement * childDef in element.children) {
            // is there any stylesheets within this?
            IJSVGNodeType childType = [IJSVGNode typeForString:childDef.name
                                                          kind:element.kind];
            
            switch(childType) {
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
                    NSString * defID = [childDef attributeForName:@"id"].stringValue;
                    if(defID != nil) {
                        _baseDefNodes[defID] = childDef;
                    }
                }
            }
        }
    }
}

- (void)_parseBaseBlock:(NSXMLElement *)element
              intoGroup:(IJSVGGroup *)parentGroup
                    def:(BOOL)flag
{
    NSString * subName = element.name;
    NSXMLNodeKind nodeKind = element.kind;
    IJSVGNodeType aType = [IJSVGNode typeForString:subName
                                              kind:nodeKind];
    switch( aType ) {
            
        // do nothing
        default:
        case IJSVGNodeTypeNotFound: {
            break;
        }
            
        // style
        case IJSVGNodeTypeStyle: {
            // create the sheet
            if(_styleSheet == nil) {
                _styleSheet = [[IJSVGStyleSheet alloc] init];
            }
            
            // append the string
            [_styleSheet parseStyleBlock:element.stringValue];
            break;
        }
            
         // sub SVG
        case IJSVGNodeTypeSVG: {
            
            IJSVGPath * path = [[[IJSVGPath alloc] init] autorelease];
            path.type = aType;
            path.name = subName;
            path.parentNode = parentGroup;
            
            // grab common attributes
            [self _setupDefaultsForNode:path];
            [self _parseElementForCommonAttributes:element
                                              node:path];
                        
            // work out the SVG
            NSError * error = nil;
            NSString * SVGString = element.XMLString;
            IJSVG * anSVG = [[[IJSVG alloc] initWithSVGString:SVGString
                                                        error:&error
                                                     delegate:nil] autorelease];
            
            // handle sub SVG
            if(error == nil && _respondsTo.handleSubSVG == 1) {
                [_delegate svgParser:self
                         foundSubSVG:anSVG
                       withSVGString:SVGString];
            }
            
            // any error?
            if(anSVG != nil && error == nil) {
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
            if( [element attributeForName:(NSString *)IJSVGAttributeD] == nil ||
               [[element attributeForName:(NSString *)IJSVGAttributeD] stringValue].length == 0 ) {
                break;
            }
            
            IJSVGPath * path = [[[IJSVGPath alloc] init] autorelease];
            path.type = aType;
            path.name = subName;
            path.parentNode = parentGroup;
            
            // find common attributes
            [self _setupDefaultsForNode:path];
            [self _parseElementForCommonAttributes:element
                                              node:path];
            
            // pass the commands for it
            [self _parsePathCommandData:[[element attributeForName:(NSString *)IJSVGAttributeD] stringValue]
                               intoPath:path];
            
            // check the size...
            if( NSIsEmptyRect([path path].controlPointBounds) ) {
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
            IJSVGGroup * group = [[[IJSVGGroup alloc] init] autorelease];
            group.type = aType;
            group.name = subName;
            group.parentNode = parentGroup;
            
            // only groups get added to parent, rest is added as a def -
            // also addition of switches
            if(!flag && ((aType == IJSVGNodeTypeGroup) ||
                         (aType == IJSVGNodeTypeSwitch))) {
                [parentGroup addChild:group];
            }
            
            // find common attributes
            [self _setupDefaultsForNode:group];
            [self _parseElementForCommonAttributes:element
                                              node:group];
            
            // recursively parse blocks
            [self _parseBlock:element
                    intoGroup:group
                          def:NO];
            
            [parentGroup addDef:group];
            break;
        }
            
            
            // path
        case IJSVGNodeTypePath: {
            IJSVGPath * path = [[[IJSVGPath alloc] init] autorelease];
            path.type = aType;
            path.name = subName;
            path.parentNode = parentGroup;
            
            if( !flag ) {
                [parentGroup addChild:path];
            }
            
            // find common attributes
            [self _setupDefaultsForNode:path];
            [self _parseElementForCommonAttributes:element
                                              node:path];
            [self _parsePathCommandData:[[element attributeForName:(NSString *)IJSVGAttributeD] stringValue]
                               intoPath:path];
            
            [parentGroup addDef:path];
            break;
        }
            
            // polygon
        case IJSVGNodeTypePolygon: {
            IJSVGPath * path = [[[IJSVGPath alloc] init] autorelease];
            path.type = aType;
            path.name = subName;
            path.parentNode = parentGroup;
            
            if( !flag ) {
                [parentGroup addChild:path];
            }
            
            // find common attributes
            [self _setupDefaultsForNode:path];
            [self _parseElementForCommonAttributes:element
                                              node:path];
            [self _parsePolygon:element
                       intoPath:path];
            [parentGroup addDef:path];
            break;
        }
            
            // polyline
        case IJSVGNodeTypePolyline: {
            IJSVGPath * path = [[[IJSVGPath alloc] init] autorelease];
            path.type = aType;
            path.name = subName;
            path.parentNode = parentGroup;
            
            
            if( !flag ) {
                [parentGroup addChild:path];
            }
            
            // find common attributes
            [self _setupDefaultsForNode:path];
            [self _parseElementForCommonAttributes:element
                                              node:path];
            [self _parsePolyline:element
                        intoPath:path];
            [parentGroup addDef:path];
            break;
        }
            
            // rect
        case IJSVGNodeTypeRect: {
            IJSVGPath * path = [[[IJSVGPath alloc] init] autorelease];
            path.type = aType;
            path.name = subName;
            path.parentNode = parentGroup;
            
            if( !flag ) {
                [parentGroup addChild:path];
            }
            
            // find common attributes
            [self _parseRect:element
                    intoPath:path];
            
            [self _setupDefaultsForNode:path];
            [self _parseElementForCommonAttributes:element
                                              node:path];
            [parentGroup addDef:path];
            break;
        }
            
            // line
        case IJSVGNodeTypeLine: {
            IJSVGPath * path = [[[IJSVGPath alloc] init] autorelease];
            path.type = aType;
            path.name = subName;
            path.parentNode = parentGroup;
            
            
            [parentGroup addChild:path];
            
            // find common attributes
            [self _setupDefaultsForNode:path];
            [self _parseElementForCommonAttributes:element
                                              node:path];
            [self _parseLine:element
                    intoPath:path];
            [parentGroup addDef:path];
            break;
        }
            
            // circle
        case IJSVGNodeTypeCircle: {
            IJSVGPath * path = [[[IJSVGPath alloc] init] autorelease];
            path.type = aType;
            path.name = subName;
            path.parentNode = parentGroup;
            
            
            if( !flag ) {
                [parentGroup addChild:path];
            }
            
            // find common attributes
            [self _setupDefaultsForNode:path];
            [self _parseElementForCommonAttributes:element
                                              node:path];
            [self _parseCircle:element
                      intoPath:path];
            [parentGroup addDef:path];
            break;
        }
            
            // ellipse
        case IJSVGNodeTypeEllipse: {
            IJSVGPath * path = [[[IJSVGPath alloc] init] autorelease];
            path.type = aType;
            path.name = subName;
            path.parentNode = parentGroup;
            
            if( !flag ) {
                [parentGroup addChild:path];
            }
            
            // find common attributes
            [self _setupDefaultsForNode:path];
            [self _parseElementForCommonAttributes:element
                                              node:path];
            [self _parseEllipse:element
                       intoPath:path];
            [parentGroup addDef:path];
            break;
        }
            
            // use
        case IJSVGNodeTypeUse: {
            
            NSString * xlink = [[element attributeForName:(NSString *)IJSVGAttributeXLink] stringValue];
            NSString * xlinkID = [xlink substringFromIndex:1];
            IJSVGNode * node = [self definedObjectForID:xlinkID];
            
            // due to this being a carbon clone, we need to clear the ID
            if([element attributeForName:(NSString *)IJSVGAttributeID] == nil) {
                node.identifier = nil;
            }
            
            node.parentNode = parentGroup;
            if(!flag) {
                [parentGroup addChild:node];
            }
            
            [self _parseElementForCommonAttributes:element
                                              node:node];
            
            [parentGroup addDef:node];
            break;
        }
            
            // linear gradient
        case IJSVGNodeTypeLinearGradient: {
            
            NSString * xlink = [[element attributeForName:(NSString *)IJSVGAttributeXLink] stringValue];
            NSString * xlinkID = [xlink substringFromIndex:1];
            IJSVGNode * node = [self definedObjectForID:xlinkID];
            if( node != nil ) {
                // we are a clone
                IJSVGLinearGradient * grad = [[[IJSVGLinearGradient alloc] init] autorelease];
                grad.type = aType;
                [grad applyPropertiesFromNode:node];
                
                grad.gradient = [[[(IJSVGGradient *)node gradient] copy] autorelease];
                CGPoint startPoint, endPoint;
                [IJSVGLinearGradient parseGradient:element
                                          gradient:grad
                                        startPoint:&startPoint
                                          endPoint:&endPoint];
                
                [self _setupDefaultsForNode:grad];
                [self _parseElementForCommonAttributes:element
                                                  node:grad];
                grad.startPoint = startPoint;
                grad.endPoint = endPoint;
                [parentGroup addDef:grad];
                break;
            }
            
            IJSVGLinearGradient * gradient = [[[IJSVGLinearGradient alloc] init] autorelease];
            gradient.type = aType;
            
            CGPoint startPoint, endPoint;
            gradient.gradient = [IJSVGLinearGradient parseGradient:element
                                                          gradient:gradient
                                                        startPoint:&startPoint
                                                          endPoint:&endPoint];
            
            [self _setupDefaultsForNode:gradient];
            [self _parseElementForCommonAttributes:element
                                              node:gradient];
            gradient.startPoint = startPoint;
            gradient.endPoint = endPoint;
            [parentGroup addDef:gradient];
            break;
        }
            
            // radial gradient
        case IJSVGNodeTypeRadialGradient: {
            
            NSString * xlink = [[element attributeForName:(NSString *)IJSVGAttributeXLink] stringValue];
            NSString * xlinkID = [xlink substringFromIndex:1];
            IJSVGNode * node = [self definedObjectForID:xlinkID];
            if( node != nil )
            {
                // we are a clone
                IJSVGRadialGradient * grad = [[[IJSVGRadialGradient alloc] init] autorelease];
                grad.type = aType;
                [grad applyPropertiesFromNode:node];
                grad.gradient = [[[(IJSVGGradient *)node gradient] copy] autorelease];
                
                CGPoint startPoint, endPoint;
                [IJSVGRadialGradient parseGradient:element
                                          gradient:grad
                                        startPoint:&startPoint
                                          endPoint:&endPoint];
                
                [self _setupDefaultsForNode:grad];
                [self _parseElementForCommonAttributes:element
                                                  node:grad];
                grad.startPoint = startPoint;
                grad.endPoint = endPoint;
                [parentGroup addDef:grad];
                break;
            }
            
            IJSVGRadialGradient * gradient = [[[IJSVGRadialGradient alloc] init] autorelease];
            gradient.type = aType;
            
            CGPoint startPoint, endPoint;
            gradient.gradient = [IJSVGRadialGradient parseGradient:element
                                                          gradient:gradient
                                                        startPoint:&startPoint
                                                          endPoint:&endPoint];
            gradient.startPoint = startPoint;
            gradient.endPoint = endPoint;
            
            [self _setupDefaultsForNode:gradient];
            [self _parseElementForCommonAttributes:element
                                              node:gradient];
            [parentGroup addDef:gradient];
            break;
        }
            
            // clippath
        case IJSVGNodeTypeClipPath: {
            
            IJSVGGroup * group = [[[IJSVGGroup alloc] init] autorelease];
            group.type = aType;
            group.name = subName;
            group.parentNode = parentGroup;
            
            [self _setupDefaultsForNode:group];
            
            // find common attributes
            [self _parseElementForCommonAttributes:element
                                              node:group];
            
            // recursively parse blocks
            [self _parseBlock:element
                    intoGroup:group
                          def:NO];
            [parentGroup addDef:group];
            break;
        }
            
        // pattern
        case IJSVGNodeTypePattern: {
            IJSVGPattern * pattern = [[[IJSVGPattern alloc] init] autorelease];
            
            [self _setupDefaultsForNode:pattern];
            
            // find common attributes
            [self _parseElementForCommonAttributes:element
                                              node:pattern];
            
            // pattern has children
            [self _parseBlock:element
                    intoGroup:pattern
                          def:NO];
            
            [parentGroup addDef:pattern];
            break;
        }
            
        // image
        case IJSVGNodeTypeImage: {            
            IJSVGImage * image = [[[IJSVGImage alloc] init] autorelease];
            
            [self _setupDefaultsForNode:image];
            
            // find common attributes
            [self _parseElementForCommonAttributes:element
                                              node:image];
            
            // from base64
            [image loadFromBase64EncodedString:[[element attributeForName:(NSString *)IJSVGAttributeXLink] stringValue]];
            
            // add to parent
            [parentGroup addChild:image];
            [parentGroup addDef:image];
            break;
        }
            
    }
}

- (void)_parseBlock:(NSXMLElement *)anElement
          intoGroup:(IJSVGGroup*)parentGroup
                def:(BOOL)flag
{
    // parse the defs
    [self parseDefsForElement:anElement];
    
    // parse the children
    for( NSXMLElement * element in [anElement children] ) {
        [self _parseBaseBlock:element
                    intoGroup:parentGroup
                          def:flag];
    }
}

#pragma mark Parser stuff!

- (void)_parsePathCommandData:(NSString *)command
                     intoPath:(IJSVGPath *)path
{
    // invalid command
    
    if( command == nil || command.length == 0 ) {
        return;
    }
    
    NSUInteger len = [command length];
    
    // allocate memory for the string buffer for reading
    unichar * buffer = (unichar *)calloc( len+1, sizeof(unichar));
    [command getCharacters:buffer
                     range:NSMakeRange(0, len)];
    
    int defaultBufferSize = 200;
    int currentBufferSize = 0;
    int currentSize = defaultBufferSize;
    
    unichar * commandBuffer = NULL;
    if( len != 0 ) {
        commandBuffer = (unichar *)calloc(defaultBufferSize,sizeof(unichar));
    }
    
    IJSVGCommand * _currentCommand = nil;
    for( int i = 0; i < len; i++ ) {
        unichar currentChar = buffer[i];
        unichar nextChar = buffer[i+1];
        BOOL atEnd = i == len-1;
        BOOL isStartCommand = IJSVGIsLegalCommandCharacter(nextChar);
        if( ( currentBufferSize + 1 ) == currentSize ) {
            currentSize += defaultBufferSize;
            commandBuffer = (unichar *)realloc( commandBuffer, sizeof(unichar)*currentSize);
        }
        commandBuffer[currentBufferSize++] = currentChar;
        if( isStartCommand || atEnd ) {
            NSString * commandString = [NSString stringWithCharacters:commandBuffer
                                                               length:currentBufferSize];
         
            // previous command is actual subcommand
            IJSVGCommand * previousCommand = [_currentCommand subCommands].lastObject;
            IJSVGCommand * cCommand = [self _parseCommandString:commandString
                                                previousCommand:previousCommand
                                                       intoPath:path];
            
            // retain the current one
            if(cCommand != nil) {
                _currentCommand  = cCommand;
            }
            
            free(commandBuffer);
            commandBuffer = NULL;
            
            if( !atEnd ) {
                currentBufferSize = 0;
                currentSize = defaultBufferSize;
                commandBuffer = (unichar *)calloc(defaultBufferSize,sizeof(unichar));
            }
        }
    }
    
    // free the buffer
    free(buffer);
}

- (IJSVGCommand *)_parseCommandString:(NSString *)string
                      previousCommand:(IJSVGCommand *)previousCommand
                             intoPath:(IJSVGPath *)path
{
    // work out the last command - the reason this is so long is because the command
    // could be a series of the same commands, so work it out by the number of parameters
    // there is per command string
    IJSVGCommand * preCommand = nil;
    if( previousCommand ) {
        preCommand = previousCommand;
    }
    
    // main commands
    IJSVGCommand * command = [[[IJSVGCommand alloc] initWithCommandString:string] autorelease];
    for( IJSVGCommand * subCommand in [command subCommands] ) {
        [subCommand.commandClass runWithParams:subCommand.parameters
                                    paramCount:subCommand.parameterCount
                                       command:subCommand
                               previousCommand:preCommand
                                          type:subCommand.type
                                          path:path];
        preCommand = subCommand;
    }
    return command;
}

- (void)_parseLine:(NSXMLElement *)element
          intoPath:(IJSVGPath *)path
{
    // convert a line into a command,
    // basically MX1 Y1LX2 Y2
    CGFloat x1 = [[[element attributeForName:(NSString *)IJSVGAttributeX1] stringValue] floatValue];
    CGFloat y1 = [[[element attributeForName:(NSString *)IJSVGAttributeY1] stringValue] floatValue];
    CGFloat x2 = [[[element attributeForName:(NSString *)IJSVGAttributeX2] stringValue] floatValue];
    CGFloat y2 = [[[element attributeForName:(NSString *)IJSVGAttributeY2] stringValue] floatValue];
    
    // use sprintf as its quicker then stringWithFormat...
    char buffer[50];
    sprintf( buffer, "M%.2f %.2fL%.2f %.2f",x1,y1,x2,y2);
    NSString * command = [NSString stringWithCString:buffer
                                            encoding:NSUTF8StringEncoding];
    [self _parsePathCommandData:command
                       intoPath:path];
}

- (void)_parseCircle:(NSXMLElement *)element
            intoPath:(IJSVGPath *)path
{
    CGFloat cX = [[[element attributeForName:(NSString *)IJSVGAttributeCX] stringValue] floatValue];
    CGFloat cY = [[[element attributeForName:(NSString *)IJSVGAttributeCY] stringValue] floatValue];
    CGFloat r = [[[element attributeForName:(NSString *)IJSVGAttributeR] stringValue] floatValue];
    NSRect rect = NSMakeRect( cX - r, cY - r, r*2, r*2);
    [path overwritePath:[NSBezierPath bezierPathWithOvalInRect:rect]];
}

- (void)_parseEllipse:(NSXMLElement *)element
             intoPath:(IJSVGPath *)path
{
    CGFloat cX = [[[element attributeForName:(NSString *)IJSVGAttributeCX] stringValue] floatValue];
    CGFloat cY = [[[element attributeForName:(NSString *)IJSVGAttributeCY] stringValue] floatValue];
    CGFloat rX = [[[element attributeForName:(NSString *)IJSVGAttributeRX] stringValue] floatValue];
    CGFloat rY = [[[element attributeForName:(NSString *)IJSVGAttributeRY] stringValue] floatValue];
    NSRect rect = NSMakeRect( cX-rX, cY-rY, rX*2, rY*2);
    [path overwritePath:[NSBezierPath bezierPathWithOvalInRect:rect]];
}

- (void)_parsePolyline:(NSXMLElement *)element
              intoPath:(IJSVGPath *)path
{
    [self _parsePoly:element
            intoPath:path
           closePath:NO];
}

- (void)_parsePolygon:(NSXMLElement *)element
             intoPath:(IJSVGPath *)path
{
    [self _parsePoly:element
            intoPath:path
           closePath:YES];
}

- (void)_parsePoly:(NSXMLElement *)element
          intoPath:(IJSVGPath *)path
         closePath:(BOOL)closePath
{
    NSString * points = [[element attributeForName:(NSString *)IJSVGAttributePoints] stringValue];
    NSInteger count = 0;
    CGFloat * params = [IJSVGUtils commandParameters:points
                                               count:&count];
    if( (count % 2) != 0 )
    {
        // error occured, free the params
        free(params);
        return;
    }
    
    // construct a command
    NSMutableString * str = [[[NSMutableString alloc] init] autorelease];
    [str appendFormat:@"M%f,%f L",params[0],params[1]];
    for( NSInteger i = 2; i < count; i+=2 )
    {
        [str appendFormat:@"%f,%f ",params[i],params[i+1]];
    }
    if( closePath )
        [str appendString:@"z"];
    [self _parsePathCommandData:str
                       intoPath:path];
    free(params);
    
}

- (void)_parseRect:(NSXMLElement *)element
          intoPath:(IJSVGPath *)path
{
    
    // width and height
    CGFloat width = [IJSVGUtils floatValue:[[element attributeForName:(NSString *)IJSVGAttributeWidth] stringValue]
                        fallBackForPercent:self.viewBox.size.width];
    

    CGFloat height = [IJSVGUtils floatValue:[[element attributeForName:(NSString *)IJSVGAttributeHeight] stringValue]
                          fallBackForPercent:self.viewBox.size.height];
    
    // radius
    CGFloat rX = [element attributeForName:(NSString *)IJSVGAttributeRX].stringValue.floatValue;
    CGFloat rY = [element attributeForName:(NSString *)IJSVGAttributeRY].stringValue.floatValue;
    if([element attributeForName:(NSString *)IJSVGAttributeRY] == nil) {
        rY = rX;
    }
    
    NSBezierPath * newPath = [NSBezierPath bezierPathWithRoundedRect:NSMakeRect( 0.f, 0.f, width, height)
                                                             xRadius:rX
                                                             yRadius:rY];
    [path overwritePath:newPath];
}

- (NSString *)namespacedAttribute:(NSString *)key
                          element:(NSXMLElement *)element
{
    key = [NSString stringWithFormat:@"ij-svg:%@",key];
    if([element attributeForName:key] != nil) {
        return [[element attributeForName:key] stringValue];
    }
    return nil;
}

- (void)applyNamespacedAttribute:(NSString *)key
                           value:(NSString *)value
                         element:(NSXMLElement *)element
{
    key = [NSString stringWithFormat:@"ij-svg:%@",key];
    NSXMLNode * node = [[[NSXMLNode alloc] initWithKind:NSXMLAttributeKind] autorelease];
    node.name = key;
    node.stringValue= value;
    [element addAttribute:node];
}

@end
