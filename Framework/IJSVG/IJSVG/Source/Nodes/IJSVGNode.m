//
//  IJSVGNode.m
//  IJSVG
//
//  Created by Curtis Hard on 30/08/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGNode.h>
#import <IJSVGQuartzRenderer.h>
#import <IJSVG/IJSVGGroup.h>
#import <IJSVG/IJSVGUtils.h>
#import <IJSVG/IJSVGRootNode.h>
#import <IJSVG/IJSVGThreadManager.h>

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

@implementation IJSVGNode

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
    if(string == nil || kind != NSXMLElementKind) {
        return IJSVGNodeTypeNotFound;
    }
    
    const char* nodeType = string.UTF8String;
    if(nodeType == NULL) {
        return IJSVGNodeTypeNotFound;
    }
    
    // quick path here, this checks the first char first and then does the
    // full string check, much faster than checking every length of string.
    switch(IJSVGCharToLower(nodeType[0])) {
        case 'a': {
            if(IJSVGCharBufferCaseInsensitiveCompare(nodeType, "a") == YES) {
                return IJSVGNodeTypeAnchor;
            }
            break;
        }
        case 'g': {
            if(IJSVGCharBufferCaseInsensitiveCompare(nodeType, "g") == YES) {
                return IJSVGNodeTypeGroup;
            }
            break;
        }
        case 'p': {
            if(IJSVGCharBufferCaseInsensitiveCompare(nodeType, "path") == YES) {
                return IJSVGNodeTypePath;
            }
            if(IJSVGCharBufferCaseInsensitiveCompare(nodeType, "polygon") == YES) {
                return IJSVGNodeTypePolygon;
            }
            if(IJSVGCharBufferCaseInsensitiveCompare(nodeType, "polyline") == YES) {
                return IJSVGNodeTypePolyline;
            }
            if(IJSVGCharBufferCaseInsensitiveCompare(nodeType, "pattern") == YES) {
                return IJSVGNodeTypePattern;
            }
            break;
        }
        case 's': {
            if(IJSVGCharBufferCaseInsensitiveCompare(nodeType, "style") == YES) {
                return IJSVGNodeTypeStyle;
            }
            if(IJSVGCharBufferCaseInsensitiveCompare(nodeType, "switch") == YES) {
                return IJSVGNodeTypeSwitch;
            }
            if(IJSVGCharBufferCaseInsensitiveCompare(nodeType, "stop") == YES) {
                return IJSVGNodeTypeStop;
            }
            if(IJSVGCharBufferCaseInsensitiveCompare(nodeType, "svg") == YES) {
                return IJSVGNodeTypeSVG;
            }
            break;
        }
        case 'd': {
            if(IJSVGCharBufferCaseInsensitiveCompare(nodeType, "defs") == YES) {
                return IJSVGNodeTypeDef;
            }
            if(IJSVGCharBufferCaseInsensitiveCompare(nodeType, "desc") == YES) {
                return IJSVGNodeTypeDesc;
            }
            break;
        }
        case 'r': {
            if(IJSVGCharBufferCaseInsensitiveCompare(nodeType, "rect") == YES) {
                return IJSVGNodeTypeRect;
            }
            if(IJSVGCharBufferCaseInsensitiveCompare(nodeType, "radialgradient") == YES) {
                return IJSVGNodeTypeRadialGradient;
            }
            break;
        }
        case 'l': {
            if(IJSVGCharBufferCaseInsensitiveCompare(nodeType, "line") == YES) {
                return IJSVGNodeTypeLine;
            }
            if(IJSVGCharBufferCaseInsensitiveCompare(nodeType, "lineargradient") == YES) {
                return IJSVGNodeTypeLinearGradient;
            }
            break;
        }
        case 'c': {
            if(IJSVGCharBufferCaseInsensitiveCompare(nodeType, "circle") == YES) {
                return IJSVGNodeTypeCircle;
            }
            if(IJSVGCharBufferCaseInsensitiveCompare(nodeType, "clippath") == YES) {
                return IJSVGNodeTypeClipPath;
            }
            break;
        }
        case 'e': {
            if(IJSVGCharBufferCaseInsensitiveCompare(nodeType, "ellipse") == YES) {
                return IJSVGNodeTypeEllipse;
            }
            break;
        }
        case 'u': {
            if(IJSVGCharBufferCaseInsensitiveCompare(nodeType, "use") == YES) {
                return IJSVGNodeTypeUse;
            }
            break;
        }
        case 'm': {
            if(IJSVGCharBufferCaseInsensitiveCompare(nodeType, "mask") == YES) {
                return IJSVGNodeTypeMask;
            }
            break;
        }
        case 'i': {
            if(IJSVGCharBufferCaseInsensitiveCompare(nodeType, "image") == YES) {
                return IJSVGNodeTypeImage;
            }
            break;
        }
        case 't': {
            if(IJSVGCharBufferCaseInsensitiveCompare(nodeType, "text") == YES) {
                return IJSVGNodeTypeText;
            }
            if(IJSVGCharBufferCaseInsensitiveCompare(nodeType, "textpath") == YES) {
                return IJSVGNodeTypeTextPath;
            }
            if(IJSVGCharBufferCaseInsensitiveCompare(nodeType, "tspan") == YES) {
                return IJSVGNodeTypeTextSpan;
            }
            if(IJSVGCharBufferCaseInsensitiveCompare(nodeType, "title") == YES) {
                return IJSVGNodeTypeTitle;
            }
            break;
        }
        case 'f': {
            if(IJSVGCharBufferCaseInsensitiveCompare(nodeType, "feBlend") == YES) {
                return IJSVGNodeTypeFilterBlend;
            }
            if(IJSVGCharBufferCaseInsensitiveCompare(nodeType, "feColorMatrix") == YES) {
                return IJSVGNodeTypeFilterColorMatrix;
            }
            if(IJSVGCharBufferCaseInsensitiveCompare(nodeType, "feComponentTransfer") == YES) {
                return IJSVGNodeTypeFilterComponentTransfer;
            }
            if(IJSVGCharBufferCaseInsensitiveCompare(nodeType, "feComposite") == YES) {
                return IJSVGNodeTypeFilterComposite;
            }
            if(IJSVGCharBufferCaseInsensitiveCompare(nodeType, "feConvolveMatrix") == YES) {
                return IJSVGNodeTypeFilterConvolveMatrix;
            }
            if(IJSVGCharBufferCaseInsensitiveCompare(nodeType, "feDiffuseLighting") == YES) {
                return IJSVGNodeTypeFilterDiffuseLighting;
            }
            if(IJSVGCharBufferCaseInsensitiveCompare(nodeType, "feDisplacementMap") == YES) {
                return IJSVGNodeTypeFilterDisplacementMap;
            }
            if(IJSVGCharBufferCaseInsensitiveCompare(nodeType, "feFlood") == YES) {
                return IJSVGNodeTypeFilterFlood;
            }
            if(IJSVGCharBufferCaseInsensitiveCompare(nodeType, "feGaussianBlur") == YES) {
                return IJSVGNodeTypeFilterGaussianBlur;
            }
            if(IJSVGCharBufferCaseInsensitiveCompare(nodeType, "feImage") == YES) {
                return IJSVGNodeTypeFilterImage;
            }
            if(IJSVGCharBufferCaseInsensitiveCompare(nodeType, "feMerge") == YES) {
                return IJSVGNodeTypeFilterMerge;
            }
            if(IJSVGCharBufferCaseInsensitiveCompare(nodeType, "feMorphology") == YES) {
                return IJSVGNodeTypeFilterMorphology;
            }
            if(IJSVGCharBufferCaseInsensitiveCompare(nodeType, "feOffset") == YES) {
                return IJSVGNodeTypeFilterOffset;
            }
            if(IJSVGCharBufferCaseInsensitiveCompare(nodeType, "feSpecularLighting") == YES) {
                return IJSVGNodeTypeFilterSpecularLighting;
            }
            if(IJSVGCharBufferCaseInsensitiveCompare(nodeType, "feTile") == YES) {
                return IJSVGNodeTypeFilterTile;
            }
            if(IJSVGCharBufferCaseInsensitiveCompare(nodeType, "feTurbulence") == YES) {
                return IJSVGNodeTypeFilterTurbulence;
            }
            if(IJSVGCharBufferCaseInsensitiveCompare(nodeType, "feMergeNode") == YES) {
                return IJSVGNodeTypeFilterMergeNode;
            }
            if(IJSVGCharBufferCaseInsensitiveCompare(nodeType, "feFuncR") == YES) {
                return IJSVGNodeTypeFilterFuncR;
            }
            if(IJSVGCharBufferCaseInsensitiveCompare(nodeType, "feFuncG") == YES) {
                return IJSVGNodeTypeFilterFuncG;
            }
            if(IJSVGCharBufferCaseInsensitiveCompare(nodeType, "feFuncB") == YES) {
                return IJSVGNodeTypeFilterFuncB;
            }
            if(IJSVGCharBufferCaseInsensitiveCompare(nodeType, "feFuncA") == YES) {
                return IJSVGNodeTypeFilterFuncA;
            }
            if(IJSVGCharBufferCaseInsensitiveCompare(nodeType, "feDistantLight") == YES) {
                return IJSVGNodeTypeFilterDistantLight;
            }
            if(IJSVGCharBufferCaseInsensitiveCompare(nodeType, "fePointLight") == YES) {
                return IJSVGNodeTypeFilterPointLight;
            }
            if(IJSVGCharBufferCaseInsensitiveCompare(nodeType, "feSpotLight") == YES) {
                return IJSVGNodeTypeFilterSpotLight;
            }
            if(IJSVGCharBufferCaseInsensitiveCompare(nodeType, "feDropShadow") == YES) {
                return IJSVGNodeTypeFilterDropShadow;
            }
            if(IJSVGCharBufferCaseInsensitiveCompare(nodeType, "filter") == YES) {
                return IJSVGNodeTypeFilter;
            }
            if(IJSVGCharBufferCaseInsensitiveCompare(nodeType, "foreignobject") == YES) {
                return IJSVGNodeTypeForeignObject;
            }
            break;
        }
        default:
            break;
    }

    return IJSVGNodeTypeUnknown;
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
    [storage setBit:IJSVGNodeAttributeColorInterpolationFilters];
    [storage setBit:IJSVGNodeAttributeEnableBackground];
    [storage setBit:IJSVGNodeAttributeClass];
    [storage setBit:IJSVGNodeAttributeTransform];
    [storage setBit:IJSVGNodeAttributeID];
    [storage setBit:IJSVGNodeAttributeUnicode];
    [storage setBit:IJSVGNodeAttributeTextRendering];
    [storage setBit:IJSVGNodeAttributeDisplay];
    // Text presentation attributes inherit through every ancestor element.
    for(IJSVGNodeAttribute attribute = IJSVGNodeAttributeFont;
        attribute <= IJSVGNodeAttributeXMLLang; attribute++) {
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
        self.opacity = [IJSVGUnitLength unitWithFloat:1.f];
        self.fillOpacity = [IJSVGUnitLength unitWithFloat:1.f];
        self.fillOpacity.inherit = YES;

        self.strokeDashArrayCount = IJSVGInheritedIntegerValue;
        self.strokeDashOffset = [IJSVGUnitLength unitWithFloat:0.f];
        self.shouldRender = YES;

        self.strokeOpacity = [IJSVGUnitLength unitWithFloat:1.f];
        self.strokeOpacity.inherit = YES;

        self.strokeWidth = [IJSVGUnitLength unitWithFloat:1.f];
        self.strokeWidth.inherit = YES;

        self.windingRule = IJSVGWindingRuleInherit;
        self.clipRule = IJSVGWindingRuleInherit;
        self.lineCapStyle = IJSVGLineCapStyleInherit;
        self.lineJoinStyle = IJSVGLineJoinStyleInherit;
        self.units = IJSVGUnitInherit;
        self.contentUnits = IJSVGUnitInherit;

        self.blendMode = IJSVGBlendModeNormal;
        self.overflowVisibility = IJSVGOverflowVisibilityVisible;
        
        // peform basic init
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
    
    self.name = node.name;
    self.type = node.type;
    self.className = node.className;
    self.classNameList = node.classNameList;
    
    self.viewBox = node.viewBox;
    self.viewBoxAlignment = node.viewBoxAlignment;
    self.viewBoxMeetOrSlice = node.viewBoxMeetOrSlice;

    self.x = node.x;
    self.y = node.y;
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
    self.windingRule = node.windingRule;
    self.clipRule = node.clipRule;
    self.lineCapStyle = node.lineCapStyle;
    self.lineJoinStyle = node.lineJoinStyle;
    self.parentNode = node.parentNode;

    self.shouldRender = node.shouldRender;
    self.blendMode = node.blendMode;
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
        IJSVGTraitedColorStorage* strokeStorage = nil;
        strokeStorage = [self.stroke colorsWithStyle:style
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

- (IJSVGNode*)styleParent
{
    return _styleParent ?: _parentNode;
}

// winding rule can inherit..
- (IJSVGWindingRule)windingRule
{
    if(_windingRule == IJSVGWindingRuleInherit && self.styleParent != nil) {
        return self.styleParent.windingRule;
    }
    return _windingRule;
}

- (IJSVGWindingRule)clipRule
{
    if(_clipRule == IJSVGWindingRuleInherit && self.styleParent != nil) {
        return self.styleParent.clipRule;
    }
    return _clipRule;
}

- (IJSVGLineCapStyle)lineCapStyle
{
    if(_lineCapStyle == IJSVGLineCapStyleInherit) {
        if(self.styleParent != nil) {
            return self.styleParent.lineCapStyle;
        }
    }
    return _lineCapStyle;
}

- (IJSVGLineJoinStyle)lineJoinStyle
{
    if(_lineJoinStyle == IJSVGLineJoinStyleInherit) {
        if(self.styleParent != nil) {
            return self.styleParent.lineJoinStyle;
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

- (IJSVGUnitLength*)opacity
{
    if(_opacity.inherit && self.styleParent != nil) {
        return self.styleParent.opacity;
    }
    return _opacity;
}

// these are all recursive, so go up the chain
// if they dont exist on this specific node
- (IJSVGUnitLength*)fillOpacity
{
    if(_fillOpacity.inherit && self.styleParent != nil) {
        return self.styleParent.fillOpacity;
    }
    return _fillOpacity;
}

// these are all recursive, so go up the chain
// if they dont exist on this specific node
- (IJSVGUnitLength*)strokeWidth
{
    if(_strokeWidth.inherit && self.styleParent != nil) {
        return self.styleParent.strokeWidth;
    }
    return _strokeWidth;
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
    if(_stroke == nil && self.styleParent != nil) {
        return self.styleParent.stroke;
    }
    return _stroke;
}

- (CGFloat*)strokeDashArray
{
    if(_strokeDashArray == NULL && self.styleParent != nil) {
        return self.styleParent.strokeDashArray;
    }
    return _strokeDashArray;
}

- (NSInteger)strokeDashArrayCount
{
    if(_strokeDashArrayCount == IJSVGInheritedIntegerValue && self.styleParent != nil) {
        return self.styleParent.strokeDashArrayCount;
    }
    return _strokeDashArrayCount;
}

- (IJSVGUnitLength *)strokeDashOffset
{
    if(_strokeDashOffset == nil && self.styleParent != nil) {
        return self.styleParent.strokeDashOffset;
    }
    return _strokeDashOffset;
}

- (IJSVGUnitLength*)strokeOpacity
{
    if(_strokeOpacity.inherit && self.styleParent != nil) {
        return self.styleParent.strokeOpacity;
    }
    return _strokeOpacity;
}

// even though the spec explicity states fill color
// must be on the path, it can also be on the
- (IJSVGNode*)fill
{
    if(_fill == nil && self.styleParent != nil) {
        return self.styleParent.fill;
    }
    return _fill;
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
    if(_strokeMiterLimit == nil && self.styleParent != nil) {
        return self.styleParent.strokeMiterLimit;
    }
    return _strokeMiterLimit;
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
