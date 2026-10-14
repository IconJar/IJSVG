//
//  IJSVGNode.m
//  IJSVG
//
//  Created by Curtis Hard on 30/08/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGGroup.h>
#import <IJSVG/IJSVGMarker.h>
#import <IJSVG/IJSVGNode.h>
#import <IJSVG/IJSVGRootNode.h>
#import <IJSVG/IJSVGThreadManager.h>
#import <IJSVG/IJSVGUtils.h>
#import <IJSVGNodeParsing.h>
#import <IJSVGQuartzRenderer.h>

IJSVGNodeType IJSVGNodeTypeForString(NSString* string, NSXMLNodeKind kind)
{
    if (string == nil || kind != NSXMLElementKind) {
        return IJSVGNodeTypeNotFound;
    }

    NSUInteger length = string.length;
    if (length == 0 || length > 19) {
        return IJSVGNodeTypeUnknown;
    }
    unichar characters[19];
    char name[19];
    [string getCharacters:characters range:NSMakeRange(0, length)];
    for (NSUInteger index = 0; index < length; index++) {
        unichar character = characters[index];
        if (character > 127) {
            return IJSVGNodeTypeUnknown;
        }
        name[index] = (char)character;
    }

    return IJSVGNodeTypeForBytes(name, length);
}

IJSVGNodeType IJSVGNodeTypeForBytes(const char* bytes, NSUInteger length)
{
    if (bytes == NULL) {
        return IJSVGNodeTypeNotFound;
    }
    if (length == 0 || length > 19) {
        return IJSVGNodeTypeUnknown;
    }
    char name[19];
    for (NSUInteger index = 0; index < length; index++) {
        unsigned char character = bytes[index];
        if (character > 127) {
            return IJSVGNodeTypeUnknown;
        }
        name[index] = character >= 'A' && character <= 'Z' ? character + ('a' - 'A') : character;
    }

    switch (length) {
        case 1:
            if (memcmp(name, "a", 1) == 0) {
                return IJSVGNodeTypeAnchor;
            }
            if (memcmp(name, "g", 1) == 0) {
                return IJSVGNodeTypeGroup;
            }
            break;
        case 3:
            if (memcmp(name, "svg", 3) == 0) {
                return IJSVGNodeTypeSVG;
            }
            if (memcmp(name, "use", 3) == 0) {
                return IJSVGNodeTypeUse;
            }
            break;
        case 4:
            if (memcmp(name, "font", 4) == 0) {
                return IJSVGNodeTypeFont;
            }
            if (memcmp(name, "path", 4) == 0) {
                return IJSVGNodeTypePath;
            }
            if (memcmp(name, "stop", 4) == 0) {
                return IJSVGNodeTypeStop;
            }
            if (memcmp(name, "defs", 4) == 0) {
                return IJSVGNodeTypeDef;
            }
            if (memcmp(name, "desc", 4) == 0) {
                return IJSVGNodeTypeDesc;
            }
            if (memcmp(name, "rect", 4) == 0) {
                return IJSVGNodeTypeRect;
            }
            if (memcmp(name, "line", 4) == 0) {
                return IJSVGNodeTypeLine;
            }
            if (memcmp(name, "mask", 4) == 0) {
                return IJSVGNodeTypeMask;
            }
            if (memcmp(name, "text", 4) == 0) {
                return IJSVGNodeTypeText;
            }
            break;
        case 5:
            if (memcmp(name, "glyph", 5) == 0) {
                return IJSVGNodeTypeGlyph;
            }
            if (memcmp(name, "style", 5) == 0) {
                return IJSVGNodeTypeStyle;
            }
            if (memcmp(name, "image", 5) == 0) {
                return IJSVGNodeTypeImage;
            }
            if (memcmp(name, "tspan", 5) == 0) {
                return IJSVGNodeTypeTextSpan;
            }
            if (memcmp(name, "title", 5) == 0) {
                return IJSVGNodeTypeTitle;
            }
            break;
        case 6:
            if (memcmp(name, "symbol", 6) == 0) {
                return IJSVGNodeTypeSymbol;
            }
            if (memcmp(name, "switch", 6) == 0) {
                return IJSVGNodeTypeSwitch;
            }
            if (memcmp(name, "circle", 6) == 0) {
                return IJSVGNodeTypeCircle;
            }
            if (memcmp(name, "marker", 6) == 0) {
                return IJSVGNodeTypeMarker;
            }
            if (memcmp(name, "fetile", 6) == 0) {
                return IJSVGNodeTypeFilterTile;
            }
            if (memcmp(name, "filter", 6) == 0) {
                return IJSVGNodeTypeFilter;
            }
            break;
        case 7:
            if (memcmp(name, "polygon", 7) == 0) {
                return IJSVGNodeTypePolygon;
            }
            if (memcmp(name, "pattern", 7) == 0) {
                return IJSVGNodeTypePattern;
            }
            if (memcmp(name, "ellipse", 7) == 0) {
                return IJSVGNodeTypeEllipse;
            }
            if (memcmp(name, "feblend", 7) == 0) {
                return IJSVGNodeTypeFilterBlend;
            }
            if (memcmp(name, "feflood", 7) == 0) {
                return IJSVGNodeTypeFilterFlood;
            }
            if (memcmp(name, "feimage", 7) == 0) {
                return IJSVGNodeTypeFilterImage;
            }
            if (memcmp(name, "femerge", 7) == 0) {
                return IJSVGNodeTypeFilterMerge;
            }
            if (memcmp(name, "fefuncr", 7) == 0) {
                return IJSVGNodeTypeFilterFuncR;
            }
            if (memcmp(name, "fefuncg", 7) == 0) {
                return IJSVGNodeTypeFilterFuncG;
            }
            if (memcmp(name, "fefuncb", 7) == 0) {
                return IJSVGNodeTypeFilterFuncB;
            }
            if (memcmp(name, "fefunca", 7) == 0) {
                return IJSVGNodeTypeFilterFuncA;
            }
            break;
        case 8:
            if (memcmp(name, "polyline", 8) == 0) {
                return IJSVGNodeTypePolyline;
            }
            if (memcmp(name, "clippath", 8) == 0) {
                return IJSVGNodeTypeClipPath;
            }
            if (memcmp(name, "textpath", 8) == 0) {
                return IJSVGNodeTypeTextPath;
            }
            if (memcmp(name, "feoffset", 8) == 0) {
                return IJSVGNodeTypeFilterOffset;
            }
            break;
        case 11:
            if (memcmp(name, "fecomposite", 11) == 0) {
                return IJSVGNodeTypeFilterComposite;
            }
            if (memcmp(name, "femergenode", 11) == 0) {
                return IJSVGNodeTypeFilterMergeNode;
            }
            if (memcmp(name, "fespotlight", 11) == 0) {
                return IJSVGNodeTypeFilterSpotLight;
            }
            break;
        case 12:
            if (memcmp(name, "femorphology", 12) == 0) {
                return IJSVGNodeTypeFilterMorphology;
            }
            if (memcmp(name, "feturbulence", 12) == 0) {
                return IJSVGNodeTypeFilterTurbulence;
            }
            if (memcmp(name, "fepointlight", 12) == 0) {
                return IJSVGNodeTypeFilterPointLight;
            }
            if (memcmp(name, "fedropshadow", 12) == 0) {
                return IJSVGNodeTypeFilterDropShadow;
            }
            break;
        case 13:
            if (memcmp(name, "fecolormatrix", 13) == 0) {
                return IJSVGNodeTypeFilterColorMatrix;
            }
            if (memcmp(name, "foreignobject", 13) == 0) {
                return IJSVGNodeTypeForeignObject;
            }
            break;
        case 14:
            if (memcmp(name, "radialgradient", 14) == 0) {
                return IJSVGNodeTypeRadialGradient;
            }
            if (memcmp(name, "lineargradient", 14) == 0) {
                return IJSVGNodeTypeLinearGradient;
            }
            if (memcmp(name, "fegaussianblur", 14) == 0) {
                return IJSVGNodeTypeFilterGaussianBlur;
            }
            if (memcmp(name, "fedistantlight", 14) == 0) {
                return IJSVGNodeTypeFilterDistantLight;
            }
            break;
        case 16:
            if (memcmp(name, "feconvolvematrix", 16) == 0) {
                return IJSVGNodeTypeFilterConvolveMatrix;
            }
            break;
        case 17:
            if (memcmp(name, "fediffuselighting", 17) == 0) {
                return IJSVGNodeTypeFilterDiffuseLighting;
            }
            if (memcmp(name, "fedisplacementmap", 17) == 0) {
                return IJSVGNodeTypeFilterDisplacementMap;
            }
            break;
        case 18:
            if (memcmp(name, "fespecularlighting", 18) == 0) {
                return IJSVGNodeTypeFilterSpecularLighting;
            }
            break;
        case 19:
            if (memcmp(name, "fecomponenttransfer", 19) == 0) {
                return IJSVGNodeTypeFilterComponentTransfer;
            }
            break;
    }
    return IJSVGNodeTypeUnknown;
}

IJSVGColorInterpolation IJSVGColorInterpolationForString(NSString* value)
{
    const char* bytes = value.UTF8String;
    if (bytes == NULL || strlen(bytes) != [value lengthOfBytesUsingEncoding:NSUTF8StringEncoding]) {
        return IJSVGColorInterpolationUnspecified;
    }
    char* token = IJSVGTimmedCharBufferCreate(bytes);
    if (token == NULL) {
        return IJSVGColorInterpolationUnspecified;
    }
    IJSVGColorInterpolation result = IJSVGColorInterpolationUnspecified;
    if (IJSVGCharBufferCaseInsensitiveCompare(token, "sRGB")) {
        result = IJSVGColorInterpolationSRGB;
    } else if (IJSVGCharBufferCaseInsensitiveCompare(token, "linearRGB") || IJSVGCharBufferCaseInsensitiveCompare(token, "initial")) {
        result = IJSVGColorInterpolationLinearRGB;
    } else if (IJSVGCharBufferCaseInsensitiveCompare(token, "inherit") || IJSVGCharBufferCaseInsensitiveCompare(token, "unset")) {
        result = IJSVGColorInterpolationInherit;
    } else if (IJSVGCharBufferCaseInsensitiveCompare(token, "auto")) {
        result = IJSVGColorInterpolationAuto;
    }
    free(token);
    return result;
}

NSString* IJSVGColorInterpolationString(IJSVGColorInterpolation value)
{
    switch (value) {
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
    switch (type) {
        case IJSVGNodeTypeGroup:
            return @"g";
        case IJSVGNodeTypePath:
            return @"path";
        case IJSVGNodeTypeDef:
            return @"defs";
        case IJSVGNodeTypePolygon:
            return @"polygon";
        case IJSVGNodeTypePolyline:
            return @"polyline";
        case IJSVGNodeTypeRect:
            return @"rect";
        case IJSVGNodeTypeLine:
            return @"line";
        case IJSVGNodeTypeCircle:
            return @"circle";
        case IJSVGNodeTypeEllipse:
            return @"ellipse";
        case IJSVGNodeTypeUse:
            return @"use";
        case IJSVGNodeTypeLinearGradient:
            return @"linearGradient";
        case IJSVGNodeTypeRadialGradient:
            return @"radialGradient";
        case IJSVGNodeTypeClipPath:
            return @"clipPath";
        case IJSVGNodeTypeFont:
            return @"font";
        case IJSVGNodeTypeGlyph:
            return @"glyph";
        case IJSVGNodeTypeMask:
            return @"mask";
        case IJSVGNodeTypeImage:
            return @"image";
        case IJSVGNodeTypePattern:
            return @"pattern";
        case IJSVGNodeTypeSVG:
            return @"svg";
        case IJSVGNodeTypeSymbol:
            return @"symbol";
        case IJSVGNodeTypeText:
            return @"text";
        case IJSVGNodeTypeTextSpan:
            return @"tspan";
        case IJSVGNodeTypeStyle:
            return @"style";
        case IJSVGNodeTypeSwitch:
            return @"switch";
        case IJSVGNodeTypeTitle:
            return @"title";
        case IJSVGNodeTypeDesc:
            return @"desc";
        case IJSVGNodeTypeStop:
            return @"stop";
        case IJSVGNodeTypeForeignObject:
            return @"foreignObject";
        case IJSVGNodeTypeFilter:
            return @"filter";
        case IJSVGNodeTypeTextPath:
            return @"textPath";
        case IJSVGNodeTypeAnchor:
            return @"a";
        case IJSVGNodeTypeFilterDropShadow:
            return @"feDropShadow";
        case IJSVGNodeTypeMarker:
            return @"marker";
        case IJSVGNodeTypeFilterBlend:
            return @"feBlend";
        case IJSVGNodeTypeFilterColorMatrix:
            return @"feColorMatrix";
        case IJSVGNodeTypeFilterComponentTransfer:
            return @"feComponentTransfer";
        case IJSVGNodeTypeFilterComposite:
            return @"feComposite";
        case IJSVGNodeTypeFilterConvolveMatrix:
            return @"feConvolveMatrix";
        case IJSVGNodeTypeFilterDiffuseLighting:
            return @"feDiffuseLighting";
        case IJSVGNodeTypeFilterDisplacementMap:
            return @"feDisplacementMap";
        case IJSVGNodeTypeFilterFlood:
            return @"feFlood";
        case IJSVGNodeTypeFilterGaussianBlur:
            return @"feGaussianBlur";
        case IJSVGNodeTypeFilterImage:
            return @"feImage";
        case IJSVGNodeTypeFilterMerge:
            return @"feMerge";
        case IJSVGNodeTypeFilterMorphology:
            return @"feMorphology";
        case IJSVGNodeTypeFilterOffset:
            return @"feOffset";
        case IJSVGNodeTypeFilterSpecularLighting:
            return @"feSpecularLighting";
        case IJSVGNodeTypeFilterTile:
            return @"feTile";
        case IJSVGNodeTypeFilterTurbulence:
            return @"feTurbulence";
        case IJSVGNodeTypeFilterMergeNode:
            return @"feMergeNode";
        case IJSVGNodeTypeFilterFuncR:
            return @"feFuncR";
        case IJSVGNodeTypeFilterFuncG:
            return @"feFuncG";
        case IJSVGNodeTypeFilterFuncB:
            return @"feFuncB";
        case IJSVGNodeTypeFilterFuncA:
            return @"feFuncA";
        case IJSVGNodeTypeFilterDistantLight:
            return @"feDistantLight";
        case IJSVGNodeTypeFilterPointLight:
            return @"fePointLight";
        case IJSVGNodeTypeFilterSpotLight:
            return @"feSpotLight";
        default:
            return nil;
    }
}

@implementation IJSVGNode
@synthesize currentColor = _currentColor;

- (void)setCurrentColor:(CGColorRef)value
{
    CGColorRef retained = CGColorRetain(value);
    CGColorRelease(_currentColor);
    _currentColor = retained;
}

- (void)dealloc
{
    CGColorRelease(_currentColor);
}

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
- (CGRect)extentWithViewPort:(CGRect)viewPort style:(IJSVGStyle*)style
{
    IJSVGQuartzRenderer* renderer = [[IJSVGQuartzRenderer alloc] init];

    // A nil style means no overrides, keep the renderer default stroke settings.
    if (style != nil) {
        renderer.style = style;
    }
    IJSVGRenderingOptions* options = [[IJSVGRenderingOptions alloc] init];
    options.filtersEnabled = YES;
    renderer.renderingOptions = options;
    return [renderer extentForNode:self inViewPort:viewPort];
}

@synthesize styleParent = _styleParent;

// Returns not found for absent names and non element nodes.
+ (IJSVGNodeType)typeForString:(NSString* _Nullable)string kind:(NSXMLNodeKind)kind
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

    @synchronized(computed) {
        IJSVGBitFlags* set = computed[self];
        if (set == nil) {
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

    @synchronized(computed) {
        NSNumber* mask = computed[self];
        if (mask == nil) {
            mask = @([self computedAllowedAttributes].bitMask);
            computed[(id<NSCopying>)self] = mask;
        }
        return mask.unsignedLongLongValue;
    }
}

+ (BOOL)typeIsPathable:(IJSVGNodeType)type
{
    return type == IJSVGNodeTypePath || type == IJSVGNodeTypeRect || type == IJSVGNodeTypeCircle || type == IJSVGNodeTypeEllipse || type == IJSVGNodeTypePolygon || type == IJSVGNodeTypePolyline || type == IJSVGNodeTypeLine;
}

+ (void)walkNodeTree:(IJSVGNode*)node handler:(IJSVGNodeWalkHandler)handler
{
    BOOL allowChildNodes = YES;
    BOOL stop = NO;
    [self _walkNodeTree:node handler:handler allowChildNodes:&allowChildNodes stop:&stop];
}

+ (void)_walkNodeTree:(IJSVGNode*)node handler:(IJSVGNodeWalkHandler)handler allowChildNodes:(BOOL*)allowChildNodes stop:(BOOL*)stop
{
    // run the handler and instantly stop
    // if stop is set
    handler(node, allowChildNodes, stop);
    if (*stop == YES) {
        return;
    }

    // child nodes only work for nodes
    // that are type group
    if (*allowChildNodes == NO || [node isKindOfClass:IJSVGGroup.class] == NO) {
        *allowChildNodes = YES;
        return;
    }

    // iterate over the childnodes
    IJSVGGroup* group = (IJSVGGroup*)node;
    for (IJSVGNode* childNode in group.children) {
        [self _walkNodeTree:childNode handler:handler allowChildNodes:allowChildNodes stop:stop];
        if (*stop == YES) {
            return;
        }
    }
}

+ (NSArray<IJSVGNode*>*)node:(IJSVGNode*)node nodesMatchingTraits:(IJSVGNodeTraits)traits
{
    NSMutableArray<IJSVGNode*>* nodes = [[NSMutableArray alloc] init];
    IJSVGNodeWalkHandler handler = ^(IJSVGNode* node, BOOL* allowChildNodes, BOOL* stop) {
        // dont compute nodes that are not designed
        // to be rendered
        if (node.shouldRender == NO) {
            *allowChildNodes = NO;
            return;
        }

        if ([node matchesTraits:traits] == YES) {
            [nodes addObject:node];
        }
    };
    [IJSVGNode walkNodeTree:node handler:handler];
    return nodes;
}

+ (BOOL)node:(IJSVGNode*)node containsNodesMatchingTraits:(IJSVGNodeTraits)traits
{
    __block IJSVGNodeTraits matchedTraits = IJSVGNodeTraitNone;
    IJSVGNodeWalkHandler handler = ^(IJSVGNode* node, BOOL* allowChildNodes, BOOL* stop) {
        // dont compute nodes that are not designed
        // to be rendered
        if (node.shouldRender == NO) {
            *allowChildNodes = NO;
            return;
        }

        // check for stroke
        if ((traits & IJSVGNodeTraitStroked) == IJSVGNodeTraitStroked && [node matchesTraits:IJSVGNodeTraitStroked] == YES) {
            matchedTraits |= IJSVGNodeTraitStroked;
        }

        // check for pathed
        if ((traits & IJSVGNodeTraitPathed) == IJSVGNodeTraitPathed && [node matchesTraits:IJSVGNodeTraitPathed] == YES) {
            matchedTraits |= IJSVGNodeTraitPathed;
        }

        // check for paintable
        if ((traits & IJSVGNodeTraitPaintable) == IJSVGNodeTraitPaintable && [node matchesTraits:IJSVGNodeTraitPaintable] == YES) {
            matchedTraits |= IJSVGNodeTraitPaintable;
        }

        // simply check if masks equal, if they are, stop this loop
        // and return the evaluation
        if (matchedTraits == traits) {
            *stop = YES;
        }
    };
    [IJSVGNode walkNodeTree:node handler:handler];
    return matchedTraits == traits;
}

- (id)init
{
    if ((self = [super init]) != nil) {
        self.type = [self.class defaultNodeType];
        _shouldRender = YES;
        [self setDefaults];
    }
    return self;
}

- (void)applyPropertiesFromNode:(IJSVGNode*)node
{
    self.title = node.title;
    self.desc = node.desc;
    self.textStyle = node.textStyle;
    self.styleParent = node->_styleParent;
    self.name = node->_name;
    self.type = node.type;
    self.className = node.className;
    self.classNameList = node.classNameList;
    _traits = node->_traits;
    _computedTraits = node->_computedTraits;
    self.identifier = node.identifier;
    self.parentNode = node.parentNode;
    self.shouldRender = node.shouldRender;
    self.visibility = node.visibility;
    self.currentColor = node->_currentColor;
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

- (IJSVGTraitedColorStorage*)colorsWithStyle:(IJSVGStyle*)style matchingTraits:(IJSVGColorUsageTraits)traits
{
    return [[IJSVGTraitedColorStorage alloc] init];
}

- (CGColorRef)currentColor
{
    return _currentColor ?: self.styleParent.currentColor ?
                                                          : IJSVGColor.blackColor;
}

- (BOOL)visibilityHidden
{
    if (self.visibility == IJSVGVisibilityInherit) {
        return self.styleParent.visibilityHidden;
    }
    return self.visibility == IJSVGVisibilityHidden;
}

- (IJSVGGraphicsNode*)styleParent
{
    return _styleParent ?: _parentNode;
}

- (IJSVGNodeTraits)traits
{
    if (_computedTraits == NO) {
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

- (NSString*)description
{
    return [NSString stringWithFormat:@"%@ %@ %@ %@", NSStringFromClass(self.class), self.name, self.classNameList, self.identifier];
}

- (BOOL)detachedFromParentNode
{
    return self.type == IJSVGNodeTypeClipPath || self.type == IJSVGNodeTypeMask;
}

- (IJSVGRootNode*)rootNode
{
    IJSVGNode* parent = self;
    while ([parent isKindOfClass:IJSVGRootNode.class] == NO) {
        parent = parent.parentNode;
        if (parent == nil) {
            return nil;
        }
    }
    return (IJSVGRootNode*)parent;
}

- (NSSet<IJSVGNode*>*)nodesMatchingTypes:(NSIndexSet*)types
{
    NSMutableSet<IJSVGNode*>* nodes = [[NSMutableSet alloc] init];
    IJSVGNodeWalkHandler handler = ^(IJSVGNode* node, BOOL* allowChildNodes, BOOL* stop) {
        if ([types containsIndex:node.type] == YES) {
            [nodes addObject:node];
        }
    };
    [self.class walkNodeTree:self handler:handler];
    return nodes.copy;
}

- (instancetype)parentNodeMatchingClass:(Class)class
{
    IJSVGNode* parent = self.parentNode;
    if ([parent isKindOfClass:class] == YES) {
        return parent;
    }
    return [parent parentNodeMatchingClass:class];
}

- (instancetype)rootNodeMatchingClass:(Class)class
{
    IJSVGRootNode* rootNode = self.rootNode;
    IJSVGNode* parentNode = self.parentNode;
    IJSVGNode* foundNode = nil;
    while (parentNode != nil) {
        // break on root node or if its matching
        if (parentNode == rootNode || parentNode == nil) {
            break;
        }
        if ([parentNode isKindOfClass:class] == YES) {
            foundNode = parentNode;
        }
        parentNode = parentNode.parentNode;
    }
    return foundNode;
}

- (BOOL)containsRelativeUnits
{
    return NO;
}

- (IJSVGTraitedColorStorage*)colorsWithStyle:(IJSVGStyle*)style
{
    return [[IJSVGTraitedColorStorage alloc] init];
}

@end

#pragma mark - Parsing

@implementation IJSVGNode (Parsing)

+ (IJSVGBitFlags*)allowedAttributes
{
    IJSVGBitFlags* attributes = IJSVGCommonAttributes();
    return attributes;
}

- (void)consumeAttributes:(IJSVGNodeParsingContext*)context
{
    IJSVGParseColorAttributes(self, context);
}

@end

@implementation IJSVGNode (Rendering)

- (void)addSpecifiedPaintPropertiesToStyle:(IJSVGResolvedPaintStyle*)style atRoot:(BOOL)atRoot
{
    style->currentColor = style->currentColor ?: _currentColor;
    if (style->visibility == IJSVGVisibilityInherit) {
        style->visibility = _visibility;
    }
}

@end
