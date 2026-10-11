//
//  IJSVGNode.m
//  IJSVG
//
//  Created by Curtis Hard on 30/08/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGNode.h>
#import <IJSVG/IJSVGMarker.h>
#import <IJSVGQuartzRenderer.h>
#import <IJSVG/IJSVGGroup.h>
#import <IJSVG/IJSVGUtils.h>
#import <IJSVG/IJSVGRootNode.h>
#import <IJSVG/IJSVGThreadManager.h>

IJSVGNodeType IJSVGNodeTypeForString(NSString* string, NSXMLNodeKind kind)
{
    if(string == nil || kind != NSXMLElementKind) {
        return IJSVGNodeTypeNotFound;
    }

    NSUInteger length = string.length;
    if(length == 0 || length > 19) {
        return IJSVGNodeTypeUnknown;
    }
    unichar characters[19];
    char name[19];
    [string getCharacters:characters range:NSMakeRange(0, length)];
    for(NSUInteger index = 0; index < length; index++) {
        unichar character = characters[index];
        if(character > 127) {
            return IJSVGNodeTypeUnknown;
        }
        name[index] = character >= 'A' && character <= 'Z' ? character + ('a' - 'A') : character;
    }

    switch(length) {
        case 1:
            if(memcmp(name, "a", 1) == 0) {
                return IJSVGNodeTypeAnchor;
            }
            if(memcmp(name, "g", 1) == 0) {
                return IJSVGNodeTypeGroup;
            }
            break;
        case 3:
            if(memcmp(name, "svg", 3) == 0) {
                return IJSVGNodeTypeSVG;
            }
            if(memcmp(name, "use", 3) == 0) {
                return IJSVGNodeTypeUse;
            }
            break;
        case 4:
            if(memcmp(name, "path", 4) == 0) {
                return IJSVGNodeTypePath;
            }
            if(memcmp(name, "stop", 4) == 0) {
                return IJSVGNodeTypeStop;
            }
            if(memcmp(name, "defs", 4) == 0) {
                return IJSVGNodeTypeDef;
            }
            if(memcmp(name, "desc", 4) == 0) {
                return IJSVGNodeTypeDesc;
            }
            if(memcmp(name, "rect", 4) == 0) {
                return IJSVGNodeTypeRect;
            }
            if(memcmp(name, "line", 4) == 0) {
                return IJSVGNodeTypeLine;
            }
            if(memcmp(name, "mask", 4) == 0) {
                return IJSVGNodeTypeMask;
            }
            if(memcmp(name, "text", 4) == 0) {
                return IJSVGNodeTypeText;
            }
            break;
        case 5:
            if(memcmp(name, "style", 5) == 0) {
                return IJSVGNodeTypeStyle;
            }
            if(memcmp(name, "image", 5) == 0) {
                return IJSVGNodeTypeImage;
            }
            if(memcmp(name, "tspan", 5) == 0) {
                return IJSVGNodeTypeTextSpan;
            }
            if(memcmp(name, "title", 5) == 0) {
                return IJSVGNodeTypeTitle;
            }
            break;
        case 6:
            if(memcmp(name, "symbol", 6) == 0) {
                return IJSVGNodeTypeSymbol;
            }
            if(memcmp(name, "switch", 6) == 0) {
                return IJSVGNodeTypeSwitch;
            }
            if(memcmp(name, "circle", 6) == 0) {
                return IJSVGNodeTypeCircle;
            }
            if(memcmp(name, "marker", 6) == 0) {
                return IJSVGNodeTypeMarker;
            }
            if(memcmp(name, "fetile", 6) == 0) {
                return IJSVGNodeTypeFilterTile;
            }
            if(memcmp(name, "filter", 6) == 0) {
                return IJSVGNodeTypeFilter;
            }
            break;
        case 7:
            if(memcmp(name, "polygon", 7) == 0) {
                return IJSVGNodeTypePolygon;
            }
            if(memcmp(name, "pattern", 7) == 0) {
                return IJSVGNodeTypePattern;
            }
            if(memcmp(name, "ellipse", 7) == 0) {
                return IJSVGNodeTypeEllipse;
            }
            if(memcmp(name, "feblend", 7) == 0) {
                return IJSVGNodeTypeFilterBlend;
            }
            if(memcmp(name, "feflood", 7) == 0) {
                return IJSVGNodeTypeFilterFlood;
            }
            if(memcmp(name, "feimage", 7) == 0) {
                return IJSVGNodeTypeFilterImage;
            }
            if(memcmp(name, "femerge", 7) == 0) {
                return IJSVGNodeTypeFilterMerge;
            }
            if(memcmp(name, "fefuncr", 7) == 0) {
                return IJSVGNodeTypeFilterFuncR;
            }
            if(memcmp(name, "fefuncg", 7) == 0) {
                return IJSVGNodeTypeFilterFuncG;
            }
            if(memcmp(name, "fefuncb", 7) == 0) {
                return IJSVGNodeTypeFilterFuncB;
            }
            if(memcmp(name, "fefunca", 7) == 0) {
                return IJSVGNodeTypeFilterFuncA;
            }
            break;
        case 8:
            if(memcmp(name, "polyline", 8) == 0) {
                return IJSVGNodeTypePolyline;
            }
            if(memcmp(name, "clippath", 8) == 0) {
                return IJSVGNodeTypeClipPath;
            }
            if(memcmp(name, "textpath", 8) == 0) {
                return IJSVGNodeTypeTextPath;
            }
            if(memcmp(name, "feoffset", 8) == 0) {
                return IJSVGNodeTypeFilterOffset;
            }
            break;
        case 11:
            if(memcmp(name, "fecomposite", 11) == 0) {
                return IJSVGNodeTypeFilterComposite;
            }
            if(memcmp(name, "femergenode", 11) == 0) {
                return IJSVGNodeTypeFilterMergeNode;
            }
            if(memcmp(name, "fespotlight", 11) == 0) {
                return IJSVGNodeTypeFilterSpotLight;
            }
            break;
        case 12:
            if(memcmp(name, "femorphology", 12) == 0) {
                return IJSVGNodeTypeFilterMorphology;
            }
            if(memcmp(name, "feturbulence", 12) == 0) {
                return IJSVGNodeTypeFilterTurbulence;
            }
            if(memcmp(name, "fepointlight", 12) == 0) {
                return IJSVGNodeTypeFilterPointLight;
            }
            if(memcmp(name, "fedropshadow", 12) == 0) {
                return IJSVGNodeTypeFilterDropShadow;
            }
            break;
        case 13:
            if(memcmp(name, "fecolormatrix", 13) == 0) {
                return IJSVGNodeTypeFilterColorMatrix;
            }
            if(memcmp(name, "foreignobject", 13) == 0) {
                return IJSVGNodeTypeForeignObject;
            }
            break;
        case 14:
            if(memcmp(name, "radialgradient", 14) == 0) {
                return IJSVGNodeTypeRadialGradient;
            }
            if(memcmp(name, "lineargradient", 14) == 0) {
                return IJSVGNodeTypeLinearGradient;
            }
            if(memcmp(name, "fegaussianblur", 14) == 0) {
                return IJSVGNodeTypeFilterGaussianBlur;
            }
            if(memcmp(name, "fedistantlight", 14) == 0) {
                return IJSVGNodeTypeFilterDistantLight;
            }
            break;
        case 16:
            if(memcmp(name, "feconvolvematrix", 16) == 0) {
                return IJSVGNodeTypeFilterConvolveMatrix;
            }
            break;
        case 17:
            if(memcmp(name, "fediffuselighting", 17) == 0) {
                return IJSVGNodeTypeFilterDiffuseLighting;
            }
            if(memcmp(name, "fedisplacementmap", 17) == 0) {
                return IJSVGNodeTypeFilterDisplacementMap;
            }
            break;
        case 18:
            if(memcmp(name, "fespecularlighting", 18) == 0) {
                return IJSVGNodeTypeFilterSpecularLighting;
            }
            break;
        case 19:
            if(memcmp(name, "fecomponenttransfer", 19) == 0) {
                return IJSVGNodeTypeFilterComponentTransfer;
            }
            break;
    }
    return IJSVGNodeTypeUnknown;
}

static void IJSVGNodeAddColorToStorage(IJSVGTraitedColorStorage* storage,
                                        NSColor* color,
                                        IJSVGColorUsageTraits traits)
{
    if(color == nil) {
        return;
    }
    IJSVGTraitedColor* traited = nil;
    traited = [IJSVGTraitedColor colorWithColor:color
                                         traits:traits];
    [storage addColor:traited];
}

IJSVGColorInterpolation IJSVGColorInterpolationForString(NSString* value)
{
    const char* bytes = value.UTF8String;
    if(bytes == NULL || strlen(bytes) != [value lengthOfBytesUsingEncoding:NSUTF8StringEncoding]) {
        return IJSVGColorInterpolationUnspecified;
    }
    char* token = IJSVGTimmedCharBufferCreate(bytes);
    if(token == NULL) {
        return IJSVGColorInterpolationUnspecified;
    }
    IJSVGColorInterpolation result = IJSVGColorInterpolationUnspecified;
    if(IJSVGCharBufferCaseInsensitiveCompare(token, "sRGB")) {
        result = IJSVGColorInterpolationSRGB;
    } else if(IJSVGCharBufferCaseInsensitiveCompare(token, "linearRGB") ||
              IJSVGCharBufferCaseInsensitiveCompare(token, "initial")) {
        result = IJSVGColorInterpolationLinearRGB;
    } else if(IJSVGCharBufferCaseInsensitiveCompare(token, "inherit") ||
              IJSVGCharBufferCaseInsensitiveCompare(token, "unset")) {
        result = IJSVGColorInterpolationInherit;
    } else if(IJSVGCharBufferCaseInsensitiveCompare(token, "auto")) {
        result = IJSVGColorInterpolationAuto;
    }
    free(token);
    return result;
}

NSString* IJSVGColorInterpolationString(IJSVGColorInterpolation value)
{
    switch(value) {
        case IJSVGColorInterpolationInherit:
            return @"inherit";
        case IJSVGColorInterpolationAuto:
            return @"auto";
        case IJSVGColorInterpolationSRGB:
            return @"sRGB";
        case IJSVGColorInterpolationLinearRGB:
            return @"linearRGB";
        case IJSVGColorInterpolationUnspecified:
            return nil;
    }
    return nil;
}

static NSString* IJSVGNodeNameForType(IJSVGNodeType type)
{
    switch(type) {
        case IJSVGNodeTypeGroup: return @"g";
        case IJSVGNodeTypePath: return @"path";
        case IJSVGNodeTypeDef: return @"defs";
        case IJSVGNodeTypePolygon: return @"polygon";
        case IJSVGNodeTypePolyline: return @"polyline";
        case IJSVGNodeTypeRect: return @"rect";
        case IJSVGNodeTypeLine: return @"line";
        case IJSVGNodeTypeCircle: return @"circle";
        case IJSVGNodeTypeEllipse: return @"ellipse";
        case IJSVGNodeTypeUse: return @"use";
        case IJSVGNodeTypeLinearGradient: return @"linearGradient";
        case IJSVGNodeTypeRadialGradient: return @"radialGradient";
        case IJSVGNodeTypeClipPath: return @"clipPath";
        case IJSVGNodeTypeFont: return @"font";
        case IJSVGNodeTypeGlyph: return @"glyph";
        case IJSVGNodeTypeMask: return @"mask";
        case IJSVGNodeTypeImage: return @"image";
        case IJSVGNodeTypePattern: return @"pattern";
        case IJSVGNodeTypeSVG: return @"svg";
        case IJSVGNodeTypeSymbol: return @"symbol";
        case IJSVGNodeTypeText: return @"text";
        case IJSVGNodeTypeTextSpan: return @"tspan";
        case IJSVGNodeTypeStyle: return @"style";
        case IJSVGNodeTypeSwitch: return @"switch";
        case IJSVGNodeTypeTitle: return @"title";
        case IJSVGNodeTypeDesc: return @"desc";
        case IJSVGNodeTypeStop: return @"stop";
        case IJSVGNodeTypeForeignObject: return @"foreignObject";
        case IJSVGNodeTypeFilter: return @"filter";
        case IJSVGNodeTypeTextPath: return @"textPath";
        case IJSVGNodeTypeAnchor: return @"a";
        case IJSVGNodeTypeFilterDropShadow: return @"feDropShadow";
        case IJSVGNodeTypeMarker:
            return @"marker";
        case IJSVGNodeTypeFilterBlend: return @"feBlend";
        case IJSVGNodeTypeFilterColorMatrix: return @"feColorMatrix";
        case IJSVGNodeTypeFilterComponentTransfer: return @"feComponentTransfer";
        case IJSVGNodeTypeFilterComposite: return @"feComposite";
        case IJSVGNodeTypeFilterConvolveMatrix: return @"feConvolveMatrix";
        case IJSVGNodeTypeFilterDiffuseLighting: return @"feDiffuseLighting";
        case IJSVGNodeTypeFilterDisplacementMap: return @"feDisplacementMap";
        case IJSVGNodeTypeFilterFlood: return @"feFlood";
        case IJSVGNodeTypeFilterGaussianBlur: return @"feGaussianBlur";
        case IJSVGNodeTypeFilterImage: return @"feImage";
        case IJSVGNodeTypeFilterMerge: return @"feMerge";
        case IJSVGNodeTypeFilterMorphology: return @"feMorphology";
        case IJSVGNodeTypeFilterOffset: return @"feOffset";
        case IJSVGNodeTypeFilterSpecularLighting: return @"feSpecularLighting";
        case IJSVGNodeTypeFilterTile: return @"feTile";
        case IJSVGNodeTypeFilterTurbulence: return @"feTurbulence";
        case IJSVGNodeTypeFilterMergeNode: return @"feMergeNode";
        case IJSVGNodeTypeFilterFuncR: return @"feFuncR";
        case IJSVGNodeTypeFilterFuncG: return @"feFuncG";
        case IJSVGNodeTypeFilterFuncB: return @"feFuncB";
        case IJSVGNodeTypeFilterFuncA: return @"feFuncA";
        case IJSVGNodeTypeFilterDistantLight: return @"feDistantLight";
        case IJSVGNodeTypeFilterPointLight: return @"fePointLight";
        case IJSVGNodeTypeFilterSpotLight: return @"feSpotLight";
        default: return nil;
    }
}

@implementation IJSVGNode {
    unsigned char _initializedDefaultLengths;
}

@synthesize opacity = _opacity;
@synthesize fillOpacity = _fillOpacity;
@synthesize strokeOpacity = _strokeOpacity;
@synthesize strokeWidth = _strokeWidth;
@synthesize strokeDashOffset = _strokeDashOffset;

@synthesize name = _name;

+ (IJSVGNodeType)defaultNodeType
{
    return IJSVGNodeTypeUnknown;
}

- (NSString*)name
{
    return _name ?: IJSVGNodeNameForType(self.type);
}

// Resolves current node properties without caching stale geometry or effects.
- (CGRect)extentWithViewPort:(CGRect)viewPort
                       style:(IJSVGStyle*)style
{
    IJSVGQuartzRenderer* renderer = [[IJSVGQuartzRenderer alloc] init];
    // A nil style means no overrides; keep the renderer's default stroke settings.
    if(style != nil) {
        renderer.style = style;
    }
    IJSVGRenderingOptions* options = [[IJSVGRenderingOptions alloc] init];
    options.filtersEnabled = YES;
    renderer.renderingOptions = options;
    return [renderer extentForNode:self
                        inViewPort:viewPort];
}

@synthesize styleParent = _styleParent;
@synthesize paintOrder = _paintOrder;

- (IJSVGPaintOrder)paintOrder
{
    if(_paintOrder == IJSVGPaintOrderInherit) {
        IJSVGNode* parent = self.styleParent;
        return parent != nil ? parent.paintOrder : IJSVGPaintOrderNormal;
    }
    return _paintOrder;
}

- (IJSVGVectorEffect)resolvedVectorEffect
{
    if(_vectorEffect == IJSVGVectorEffectInherit) {
        return (self.styleParent ?: self.parentNode).resolvedVectorEffect;
    }
    return _vectorEffect;
}

- (IJSVGFilter*)filter
{
    return self.filters.firstObject;
}

- (void)setFilter:(IJSVGFilter*)filter
{
    self.filters = filter == nil ? @[] : @[filter];
}

@synthesize fill = _fill;
@synthesize stroke = _stroke;
@synthesize markerStart = _markerStart, markerMid = _markerMid, markerEnd = _markerEnd;

- (void)dealloc
{
    if(_strokeDashArray != NULL) {
        (void)free(_strokeDashArray), _strokeDashArray = NULL;
    }
}

// Returns not found for absent names and non element nodes.
+ (IJSVGNodeType)typeForString:(NSString* _Nullable)string
                          kind:(NSXMLNodeKind)kind
{
    return IJSVGNodeTypeForString(string, kind);
}

+ (IJSVGBitFlags*)computedAllowedAttributes
{
    static NSMutableDictionary<Class, IJSVGBitFlags*>* computed = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        computed = [[NSMutableDictionary alloc] init];
    });
    
    @synchronized (computed) {
        IJSVGBitFlags* set = computed[self];
        if(set == nil) {
            set = [self allowedAttributes];
            computed[(id<NSCopying>)self] = set;
        }
        return set;
    }
}

+ (uint64_t)computedAllowedAttributeMask
{
    static NSMutableDictionary<Class, NSNumber*>* computed = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        computed = [[NSMutableDictionary alloc] init];
    });
    
    @synchronized (computed) {
        NSNumber* mask = computed[self];
        if(mask == nil) {
            mask = @([self computedAllowedAttributes].bitMask);
            computed[(id<NSCopying>)self] = mask;
        }
        return mask.unsignedLongLongValue;
    }
}

+ (IJSVGBitFlags*)allowedAttributes
{
    IJSVGBitFlags* storage = [[IJSVGBitFlags alloc] initWithLength:kIJSVGNodeAttributeStorageLength];
    [storage setBit:IJSVGNodeAttributeStyle];
    [storage setBit:IJSVGNodeAttributeIsolation];
    [storage setBit:IJSVGNodeAttributePaintOrder];
    [storage setBit:IJSVGNodeAttributeVectorEffect];
    [storage setBit:IJSVGNodeAttributeMarker];
    [storage setBit:IJSVGNodeAttributeMarkerStart];
    [storage setBit:IJSVGNodeAttributeMarkerMid];
    [storage setBit:IJSVGNodeAttributeMarkerEnd];
    [storage setBit:IJSVGNodeAttributeColorInterpolationFilters];
    [storage setBit:IJSVGNodeAttributeEnableBackground];
    [storage setBit:IJSVGNodeAttributeClass];
    [storage setBit:IJSVGNodeAttributeTransform];
    [storage setBit:IJSVGNodeAttributeTransformOrigin];
    [storage setBit:IJSVGNodeAttributeTransformBox];
    [storage setBit:IJSVGNodeAttributeID];
    [storage setBit:IJSVGNodeAttributeUnicode];
    [storage setBit:IJSVGNodeAttributeTextRendering];
    [storage setBit:IJSVGNodeAttributeColor];
    [storage setBit:IJSVGNodeAttributeVisibility];
    [storage setBit:IJSVGNodeAttributeDisplay];
    [storage setBit:IJSVGNodeAttributeClipRule];

    // Text presentation attributes inherit through every ancestor element.
    for(IJSVGNodeAttribute attribute = IJSVGNodeAttributeFont;
        attribute <= IJSVGNodeAttributeFontSizeAdjust; attribute++) {
        [storage setBit:(int)attribute];
    }
    return storage;
}

+ (BOOL)typeIsPathable:(IJSVGNodeType)type
{
    return type == IJSVGNodeTypePath || type == IJSVGNodeTypeRect ||
        type == IJSVGNodeTypeCircle || type == IJSVGNodeTypeEllipse ||
        type == IJSVGNodeTypePolygon || type == IJSVGNodeTypePolyline ||
        type == IJSVGNodeTypeLine;
}

+ (void)walkNodeTree:(IJSVGNode*)node
             handler:(IJSVGNodeWalkHandler)handler
{
    BOOL allowChildNodes = YES;
    BOOL stop = NO;
    [self _walkNodeTree:node
                handler:handler
        allowChildNodes:&allowChildNodes
                   stop:&stop];
}

+ (void)_walkNodeTree:(IJSVGNode*)node
              handler:(IJSVGNodeWalkHandler)handler
      allowChildNodes:(BOOL*)allowChildNodes
                 stop:(BOOL*)stop
{
    // run the handler and instantly stop
    // if stop is set
    handler(node, allowChildNodes, stop);
    if(*stop == YES) {
        return;
    }
    
    // child nodes only work for nodes
    // that are type group
    if(*allowChildNodes == NO ||
       [node isKindOfClass:IJSVGGroup.class] == NO) {
        *allowChildNodes = YES;
        return;
    }
    
    // iterate over the childnodes
    IJSVGGroup* group = (IJSVGGroup*)node;
    for(IJSVGNode* childNode in group.children) {
        [self _walkNodeTree:childNode
                    handler:handler
            allowChildNodes:allowChildNodes
                       stop:stop];
        if(*stop == YES) {
            return;
        }
    }
}

+ (NSArray<IJSVGNode*>*)node:(IJSVGNode*)node
         nodesMatchingTraits:(IJSVGNodeTraits)traits
{
    NSMutableArray<IJSVGNode*>* nodes = [[NSMutableArray alloc] init];
    IJSVGNodeWalkHandler handler = ^(IJSVGNode* node,
                                     BOOL* allowChildNodes,
                                     BOOL* stop) {
        // dont compute nodes that are not designed
        // to be rendered
        if(node.shouldRender == NO) {
            *allowChildNodes = NO;
            return;
        }
        
        if([node matchesTraits:traits] == YES) {
            [nodes addObject:node];
        }
    };
    [IJSVGNode walkNodeTree:node
                    handler:handler];
    return nodes;
}

+ (BOOL)node:(IJSVGNode*)node
containsNodesMatchingTraits:(IJSVGNodeTraits)traits
{
    __block IJSVGNodeTraits matchedTraits = IJSVGNodeTraitNone;
    IJSVGNodeWalkHandler handler = ^(IJSVGNode* node,
                                     BOOL* allowChildNodes,
                                     BOOL* stop) {
        // dont compute nodes that are not designed
        // to be rendered
        if(node.shouldRender == NO) {
            *allowChildNodes = NO;
            return;
        }
        
        // check for stroke
        if((traits & IJSVGNodeTraitStroked) == IJSVGNodeTraitStroked &&
           [node matchesTraits:IJSVGNodeTraitStroked] == YES) {
            matchedTraits |= IJSVGNodeTraitStroked;
        }
        
        // check for pathed
        if((traits & IJSVGNodeTraitPathed) == IJSVGNodeTraitPathed &&
           [node matchesTraits:IJSVGNodeTraitPathed] == YES) {
            matchedTraits |= IJSVGNodeTraitPathed;
        }
        
        // check for paintable
        if((traits & IJSVGNodeTraitPaintable) == IJSVGNodeTraitPaintable &&
           [node matchesTraits:IJSVGNodeTraitPaintable] == YES) {
            matchedTraits |= IJSVGNodeTraitPaintable;
        }
                
        // simply check if masks equal, if they are, stop this loop
        // and return the evaluation
        if(matchedTraits == traits) {
            *stop = YES;
        }
    };
    [IJSVGNode walkNodeTree:node
                    handler:handler];
    return matchedTraits == traits;
}

- (id)init
{
    if((self = [super init]) != nil) {
        self.type = [self.class defaultNodeType];
        _strokeDashArrayCount = IJSVGInheritedIntegerValue;
        _shouldRender = YES;

        _windingRule = IJSVGWindingRuleInherit;
        _clipRule = IJSVGWindingRuleInherit;
        _lineCapStyle = IJSVGLineCapStyleInherit;
        _lineJoinStyle = IJSVGLineJoinStyleInherit;
        _units = IJSVGUnitInherit;
        _contentUnits = IJSVGUnitInherit;

        _blendMode = IJSVGBlendModeNormal;
        _paintOrder = IJSVGPaintOrderInherit;
        _overflowVisibility = IJSVGOverflowVisibilityVisible;

        // Apply defaults supplied by the node subclass.
        [self setDefaults];
    }
    return self;
}


- (void)applyPropertiesFromNode:(IJSVGNode*)node
{
    self.title = node.title;
    self.desc = node.desc;
    self.unicode = node.unicode;
    self.textStyle = node.textStyle;
    self.styleParent = node->_styleParent;
    self.markerStart = node->_markerStart.copy;
    self.markerMid = node->_markerMid.copy;
    self.markerEnd = node->_markerEnd.copy;

    // Preserve whether the name was explicit so copies still follow type changes.
    self.name = node->_name;
    self.type = node.type;
    self.className = node.className;
    self.classNameList = node.classNameList;
    
    self.viewBox = node.viewBox;
    self.viewBoxAlignment = node.viewBoxAlignment;
    self.viewBoxMeetOrSlice = node.viewBoxMeetOrSlice;

    self.x = node.x;
    self.y = node.y;
    self.geometryLengths = node.geometryLengths;
    self.width = node.width;
    self.height = node.height;
    self.offset = node.offset.copy;

    // Preserve explicit traits and whether derived traits have already been computed.
    _traits = node->_traits;
    _computedTraits = node->_computedTraits;

    self.fill = node.fill;
    self.stroke = node.stroke;
    self.clipPath = node.clipPath;
    self.mask = node.mask;
    self.filters = node.filters;
    self.filterColorInterpolation = node.filterColorInterpolation;
    self.backgroundEnabled = node.backgroundEnabled;
    self.backgroundBounds = node.backgroundBounds;

    self.units = node.units;
    self.contentUnits = node.contentUnits;

    self.opacity = node.opacity;
    self.strokeWidth = node.strokeWidth;
    self.fillOpacity = node.fillOpacity;
    self.strokeOpacity = node.strokeOpacity;
    self.strokeMiterLimit = node.strokeMiterLimit;

    self.identifier = node.identifier;

    self.transforms = node.transforms;
    self.transformOrigin = node.transformOrigin;
    self.transformBox = node.transformBox;
    self.windingRule = node.windingRule;
    self.clipRule = node.clipRule;
    self.lineCapStyle = node.lineCapStyle;
    self.lineJoinStyle = node.lineJoinStyle;
    self.parentNode = node.parentNode;

    self.shouldRender = node.shouldRender;
    self.visibility = node.visibility;
    self.currentColor = node->_currentColor;
    self.blendMode = node.blendMode;
    self.isolated = node.isolated;
    self.paintOrder = node->_paintOrder;
    self.vectorEffect = node.vectorEffect;
    self.overflowVisibility = node.overflowVisibility;

    // dash array needs physical memory copied
    NSInteger strokeDashArrayCount = node.strokeDashArrayCount;
    CGFloat* strokeDashArray = node.strokeDashArray;
    if(strokeDashArrayCount > 0 && strokeDashArray != NULL) {
        CGFloat* nStrokeDashArray = (CGFloat*)malloc(strokeDashArrayCount * sizeof(CGFloat));
        memcpy(nStrokeDashArray, strokeDashArray, strokeDashArrayCount * sizeof(CGFloat));
        self.strokeDashArray = nStrokeDashArray;
    }
    self.strokeDashArrayCount = strokeDashArrayCount;
    self.strokeDashLengths = node.strokeDashLengths;
    self.strokeDashOffset = node.strokeDashOffset;
}

- (id)copyWithZone:(NSZone*)zone
{
    IJSVGNode* node = [self.class allocWithZone:zone];
    [node applyPropertiesFromNode:self];
    return node;
}

- (void)postProcess
{
}

- (BOOL)containsRelativeUnits
{
    return _x.isRelativeUnit == YES || _y.isRelativeUnit == YES ||
        _width.isRelativeUnit == YES || _height.isRelativeUnit == YES;
}

- (IJSVGTraitedColorStorage*)colorsWithStyle:(IJSVGStyle*)style
{
    IJSVGTraitedColorStorage* storage = [[IJSVGTraitedColorStorage alloc] init];
    if(self.shouldRender == NO || [self matchesTraits:IJSVGNodeTraitPathed] == NO) {
        return storage;
    }

    IJSVGNode* fill = self.fill;
    if([fill isKindOfClass:IJSVGColorNode.class] && ((IJSVGColorNode*)fill).usesCurrentColor) {
        fill = [IJSVGColorNode colorNodeWithColor:self.currentColor];
    }
    if(fill == nil) {
        IJSVGNodeAddColorToStorage(storage,
                                   style.fillColor ?: NSColor.blackColor,
                                   IJSVGColorUsageTraitFill);
    } else {
        IJSVGTraitedColorStorage* fillStorage = nil;
        fillStorage = [fill colorsWithStyle:style
                             matchingTraits:IJSVGColorUsageTraitFill];
        [storage unionColorStorage:fillStorage];
    }

    if([self matchesTraits:IJSVGNodeTraitStroked] == YES) {
        IJSVGNode* stroke = self.stroke;
        if([stroke isKindOfClass:IJSVGColorNode.class] && ((IJSVGColorNode*)stroke).usesCurrentColor) {
            stroke = [IJSVGColorNode colorNodeWithColor:self.currentColor];
        }
        IJSVGTraitedColorStorage* strokeStorage = nil;
        strokeStorage = [stroke colorsWithStyle:style
                                      matchingTraits:IJSVGColorUsageTraitStroke];
        [storage unionColorStorage:strokeStorage];
    }
    return storage;
}

- (IJSVGTraitedColorStorage*)colorsWithStyle:(IJSVGStyle*)style
                              matchingTraits:(IJSVGColorUsageTraits)traits
{
    return [[IJSVGTraitedColorStorage alloc] init];
}

- (void)setFill:(IJSVGNode*)fill
{
    NSAssert([fill matchesTraits:IJSVGNodeTraitPaintable] || fill == nil, @"Fill must a paintable node.");
    _fill = fill;
}

- (void)setStroke:(IJSVGNode*)stroke
{
    NSAssert([stroke matchesTraits:IJSVGNodeTraitPaintable]|| stroke == nil, @"Stroke must be a paintable node.");
    _stroke = stroke;
}

- (IJSVGColorInterpolation)resolvedFilterColorInterpolation
{
    for(IJSVGNode* node = self; node != nil; node = node.styleParent) {
        switch(node.filterColorInterpolation) {
            case IJSVGColorInterpolationSRGB:
                return IJSVGColorInterpolationSRGB;
            case IJSVGColorInterpolationAuto:
            case IJSVGColorInterpolationLinearRGB:
                return IJSVGColorInterpolationLinearRGB;
            case IJSVGColorInterpolationUnspecified:
            case IJSVGColorInterpolationInherit:
                break;
        }
    }
    return IJSVGColorInterpolationLinearRGB;
}

- (IJSVGMarker*)markerStart
{
    return _markerStart ?: self.styleParent.markerStart;
}

- (IJSVGMarker*)markerMid
{
    return _markerMid ?: self.styleParent.markerMid;
}

- (IJSVGMarker*)markerEnd
{
    return _markerEnd ?: self.styleParent.markerEnd;
}

- (NSColor*)currentColor
{
    return _currentColor ?: self.styleParent.currentColor ?: NSColor.blackColor;
}

- (BOOL)visibilityHidden
{
    if(self.visibility == IJSVGVisibilityInherit) {
        return self.styleParent.visibilityHidden;
    }
    return self.visibility == IJSVGVisibilityHidden;
}

- (IJSVGNode*)styleParent
{
    return _styleParent ?: _parentNode;
}

// winding rule can inherit..
- (IJSVGWindingRule)windingRule
{
    if(_windingRule == IJSVGWindingRuleInherit) {
        IJSVGNode* parent = self.styleParent;
        if(parent != nil) {
            return parent.windingRule;
        }
    }
    return _windingRule;
}

- (IJSVGWindingRule)clipRule
{
    if(_clipRule == IJSVGWindingRuleInherit) {
        IJSVGNode* parent = self.styleParent;
        if(parent != nil) {
            return parent.clipRule;
        }
    }
    return _clipRule;
}

- (IJSVGLineCapStyle)lineCapStyle
{
    if(_lineCapStyle == IJSVGLineCapStyleInherit) {
        IJSVGNode* parent = self.styleParent;
        if(parent != nil) {
            return parent.lineCapStyle;
        }
    }
    return _lineCapStyle;
}

- (IJSVGLineJoinStyle)lineJoinStyle
{
    if(_lineJoinStyle == IJSVGLineJoinStyleInherit) {
        IJSVGNode* parent = self.styleParent;
        if(parent != nil) {
            return parent.lineJoinStyle;
        }
    }
    return _lineJoinStyle;
}

// these are all recursive, so go up the chain
// if they dont exist on this specific node
- (CGRect)backgroundRect
{
    if(![self isKindOfClass:IJSVGGroup.class]) {
        return CGRectNull;
    }
    if(self.backgroundEnabled == IJSVGBackgroundEnabledInherit) {
        return self.parentNode != nil ? self.parentNode.backgroundRect : CGRectNull;
    }
    return self.backgroundEnabled == IJSVGBackgroundEnabledNew ? self.backgroundBounds : CGRectNull;
}

- (void)setOpacity:(IJSVGUnitLength*)value
{
    _initializedDefaultLengths |= 1;
    _opacity = value;
}

- (IJSVGUnitLength*)opacity
{
    if((_initializedDefaultLengths & 1) == 0) {
        _initializedDefaultLengths |= 1;
        _opacity = IJSVGOneUnitLength;
    }
    if(_opacity.inherit) {
        IJSVGNode* parent = self.styleParent;
        if(parent != nil) {
            return parent.opacity;
        }
    }
    return _opacity;
}

// these are all recursive, so go up the chain
// if they dont exist on this specific node
- (void)setFillOpacity:(IJSVGUnitLength*)value
{
    _initializedDefaultLengths |= 2;
    _fillOpacity = value;
}

// Inherited defaults only need storage at the node that supplies the value.
// Keep resolution live so reparenting and later parent edits still take effect.
- (IJSVGUnitLength*)fillOpacity
{
    BOOL needsDefault = (_initializedDefaultLengths & 2) == 0;
    if(needsDefault || _fillOpacity.inherit) {
        IJSVGNode* parent = self.styleParent;
        if(parent != nil) {
            return parent.fillOpacity;
        }
    }
    if(needsDefault) {
        _initializedDefaultLengths |= 2;
        _fillOpacity = IJSVGInheritedOneUnitLength;
    }
    return _fillOpacity;
}

// these are all recursive, so go up the chain
// if they dont exist on this specific node
- (void)setStrokeWidth:(IJSVGUnitLength*)value
{
    _initializedDefaultLengths |= 8;
    _strokeWidth = value;
}

- (IJSVGUnitLength*)strokeWidth
{
    BOOL needsDefault = (_initializedDefaultLengths & 8) == 0;
    if(needsDefault || _strokeWidth.inherit) {
        IJSVGNode* parent = self.styleParent;
        if(parent != nil) {
            return parent.strokeWidth;
        }
    }
    if(needsDefault) {
        _initializedDefaultLengths |= 8;
        _strokeWidth = IJSVGInheritedOneUnitLength;
    }
    return _strokeWidth;
}

- (NSArray<IJSVGUnitLength*>*)strokeDashLengths
{
    if(_strokeDashLengths == nil && _strokeDashArrayCount == IJSVGInheritedIntegerValue) {
        return self.styleParent.strokeDashLengths;
    }
    return _strokeDashLengths;
}

- (NSArray<NSNumber*>*)lineDashPattern
{
    NSMutableArray* arr = [[NSMutableArray alloc] initWithCapacity:self.strokeDashArrayCount];
    for (NSInteger i = 0; i < self.strokeDashArrayCount; i++) {
        [arr addObject:@((CGFloat)self.strokeDashArray[i])];
    }
    return arr;
}

// these are all recursive, so go up the chain
// if they dont exist on this specific node
- (IJSVGNode*)stroke
{
    return _stroke ?: self.styleParent.stroke;
}

- (CGFloat*)strokeDashArray
{
    return _strokeDashArray ?: self.styleParent.strokeDashArray;
}

- (NSInteger)strokeDashArrayCount
{
    if(_strokeDashArrayCount == IJSVGInheritedIntegerValue) {
        IJSVGNode* parent = self.styleParent;
        if(parent != nil) {
            return parent.strokeDashArrayCount;
        }
    }
    return _strokeDashArrayCount;
}

- (void)setStrokeDashOffset:(IJSVGUnitLength*)value
{
    _initializedDefaultLengths |= 16;
    _strokeDashOffset = value;
}

- (IJSVGUnitLength*)strokeDashOffset
{
    BOOL needsDefault = (_initializedDefaultLengths & 16) == 0;
    if(needsDefault || _strokeDashOffset.inherit || _strokeDashOffset == nil) {
        IJSVGNode* parent = self.styleParent;
        if(parent != nil) {
            return parent.strokeDashOffset;
        }
    }
    if(needsDefault) {
        _initializedDefaultLengths |= 16;
        _strokeDashOffset = IJSVGInheritedZeroUnitLength;
    }
    return _strokeDashOffset;
}

- (void)setStrokeOpacity:(IJSVGUnitLength*)value
{
    _initializedDefaultLengths |= 4;
    _strokeOpacity = value;
}

- (IJSVGUnitLength*)strokeOpacity
{
    BOOL needsDefault = (_initializedDefaultLengths & 4) == 0;
    if(needsDefault || _strokeOpacity.inherit) {
        IJSVGNode* parent = self.styleParent;
        if(parent != nil) {
            return parent.strokeOpacity;
        }
    }
    if(needsDefault) {
        _initializedDefaultLengths |= 4;
        _strokeOpacity = IJSVGInheritedOneUnitLength;
    }
    return _strokeOpacity;
}

// even though the spec explicity states fill color
// must be on the path, it can also be on the
- (IJSVGNode*)fill
{
    return _fill ?: self.styleParent.fill;
}

- (IJSVGUnitType)units
{
    if(_units == IJSVGUnitInherit && _parentNode != nil) {
        return _parentNode.units;
    }
    return _units;
}

- (IJSVGUnitType)contentUnits
{
    if(_contentUnits == IJSVGUnitInherit && _parentNode != nil) {
        return _parentNode.contentUnits;
    }
    return _contentUnits;
}

- (IJSVGUnitLength*)strokeMiterLimit
{
    return _strokeMiterLimit ?: self.styleParent.strokeMiterLimit;
}

- (IJSVGUnitType)contentUnitsWithReferencingNodeBounds:(CGRect*)bounds
{
    IJSVGNode* node = nil;
    IJSVGUnitType type = [self contentUnitsWithReferencingNode:&node];
    *bounds = node.parentNode.bounds;
    return type;
}

- (IJSVGUnitType)contentUnitsWithReferencingNode:(IJSVGNode**)referencingNode
{
    if(_contentUnits == IJSVGUnitInherit && _parentNode != nil) {
        return [_parentNode contentUnitsWithReferencingNode:referencingNode];
    }
    *referencingNode = self;
    return _contentUnits;
}

- (IJSVGNodeTraits)traits
{
    if(_computedTraits == NO) {
        _computedTraits = YES;
        [self computeTraits];
    }
    return _traits;
}

- (void)addTraits:(IJSVGNodeTraits)traits
{
    _traits |= traits;
}

- (void)removeTraits:(IJSVGNodeTraits)traits
{
    _traits = _traits & ~traits;
}

- (BOOL)matchesTraits:(IJSVGNodeTraits)traits
{
    return (self.traits & traits) == traits;
}

- (void)computeTraits
{
    // by default this does nothing
}

- (void)setDefaults
{
}

- (instancetype)detach
{
    self.parentNode = nil;
    return self;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"%@ %@ %@ %@",NSStringFromClass(self.class),
            self.name,self.classNameList,self.identifier];
}

- (BOOL)detachedFromParentNode
{
    return self.type == IJSVGNodeTypeClipPath ||
        self.type == IJSVGNodeTypeMask;
}

- (IJSVGRootNode*)rootNode
{
    IJSVGNode* parent = self;
    while([parent isKindOfClass:IJSVGRootNode.class] == NO) {
        parent = parent.parentNode;
        if(parent == nil) {
            return nil;
        }
    }
    return (IJSVGRootNode*)parent;
}

- (NSSet<IJSVGNode*>*)nodesMatchingTypes:(NSIndexSet*)types
{
    NSMutableSet<IJSVGNode*>* nodes = [[NSMutableSet alloc] init];
    IJSVGNodeWalkHandler handler = ^(IJSVGNode* node,
                                     BOOL* allowChildNodes,
                                     BOOL* stop) {
        if([types containsIndex:node.type] == YES) {
            [nodes addObject:node];
        }
    };
    [self.class walkNodeTree:self
                     handler:handler];
    return nodes.copy;
}

- (instancetype)parentNodeMatchingClass:(Class)class
{
    IJSVGNode* parent = self.parentNode;
    if([parent isKindOfClass:class] == YES) {
        return parent;
    }
    return [parent parentNodeMatchingClass:class];
}

- (instancetype)rootNodeMatchingClass:(Class)class
{
    IJSVGRootNode* rootNode = self.rootNode;
    IJSVGNode* parentNode = self.parentNode;
    IJSVGNode* foundNode = nil;
    while(parentNode != nil) {
        // break on root node or if its matching
        if(parentNode == rootNode || parentNode == nil) {
            break;
        }
        if([parentNode isKindOfClass:class] == YES) {
            foundNode = parentNode;
        }
        parentNode = parentNode.parentNode;
    }
    return foundNode;
}

@end
