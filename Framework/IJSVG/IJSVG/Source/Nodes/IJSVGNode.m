//
//  IJSVGNode.m
//  IconJar
//
//  Created by Curtis Hard on 30/08/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGNode.h>
#import <IJSVG/IJSVGGroup.h>
#import <IJSVG/IJSVGUtils.h>
#import <IJSVG/IJSVGRootNode.h>

@implementation IJSVGNode

@synthesize fill = _fill;
@synthesize stroke = _stroke;

- (void)dealloc
{
    (void)free(_strokeDashArray), _strokeDashArray = NULL;
}

+ (IJSVGNodeType)typeForString:(NSString*)string
                          kind:(NSXMLNodeKind)kind
{
    // possible fix for older os's that complain
    if(string == nil || kind != NSXMLElementKind) {
        return IJSVGNodeTypeNotFound;
    }
    
    const char* name = string.UTF8String;
    if(name == NULL) {
        return IJSVGNodeTypeNotFound;
    }
    
    char* dest = (char*)malloc(sizeof(char)*strlen(name)+1);
    strcpy(dest, name);
    IJSVGCharBufferToLower(dest);
    
    if(strcmp(dest, "style") == 0) {
        (void)free(dest), dest = NULL;
        return IJSVGNodeTypeStyle;
    }
    if(strcmp(dest, "switch") == 0) {
        (void)free(dest), dest = NULL;
        return IJSVGNodeTypeSwitch;
    }
    if(strcmp(dest, "defs") == 0) {
        (void)free(dest), dest = NULL;
        return IJSVGNodeTypeDef;
    }
    if(strcmp(dest, "g") == 0) {
        (void)free(dest), dest = NULL;
        return IJSVGNodeTypeGroup;
    }
    if(strcmp(dest, "path") == 0) {
        (void)free(dest), dest = NULL;
        return IJSVGNodeTypePath;
    }
    if(strcmp(dest, "polygon") == 0) {
        (void)free(dest), dest = NULL;
        return IJSVGNodeTypePolygon;
    }
    if(strcmp(dest, "polyline") == 0) {
        (void)free(dest), dest = NULL;
        return IJSVGNodeTypePolyline;
    }
    if(strcmp(dest, "rect") == 0) {
        (void)free(dest), dest = NULL;
        return IJSVGNodeTypeRect;
    }
    if(strcmp(dest, "line") == 0) {
        (void)free(dest), dest = NULL;
        return IJSVGNodeTypeLine;
    }
    if(strcmp(dest, "circle") == 0) {
        (void)free(dest), dest = NULL;
        return IJSVGNodeTypeCircle;
    }
    if(strcmp(dest, "ellipse") == 0) {
        (void)free(dest), dest = NULL;
        return IJSVGNodeTypeEllipse;
    }
    if(strcmp(dest, "use") == 0) {
        (void)free(dest), dest = NULL;
        return IJSVGNodeTypeUse;
    }
    if(strcmp(dest, "lineargradient") == 0) {
        (void)free(dest), dest = NULL;
        return IJSVGNodeTypeLinearGradient;
    }
    if(strcmp(dest, "radialgradient") == 0) {
        (void)free(dest), dest = NULL;
        return IJSVGNodeTypeRadialGradient;
    }
    if(strcmp(dest, "stop") == 0) {
        (void)free(dest), dest = NULL;
        return IJSVGNodeTypeStop;
    }
    if(strcmp(dest, "glyph") == 0) {
        (void)free(dest), dest = NULL;
        return IJSVGNodeTypeGlyph;
    }
    if(strcmp(dest, "font") == 0) {
        (void)free(dest), dest = NULL;
        return IJSVGNodeTypeFont;
    }
    if(strcmp(dest, "clippath") == 0) {
        (void)free(dest), dest = NULL;
        return IJSVGNodeTypeClipPath;
    }
    if(strcmp(dest, "mask") == 0) {
        (void)free(dest), dest = NULL;
        return IJSVGNodeTypeMask;
    }
    if(strcmp(dest, "image") == 0) {
        (void)free(dest), dest = NULL;
        return IJSVGNodeTypeImage;
    }
    if(strcmp(dest, "pattern") == 0) {
        (void)free(dest), dest = NULL;
        return IJSVGNodeTypePattern;
    }
    if(strcmp(dest, "svg") == 0) {
        (void)free(dest), dest = NULL;
        return IJSVGNodeTypeSVG;
    }
    if(strcmp(dest, "text") == 0) {
        (void)free(dest), dest = NULL;
        return IJSVGNodeTypeText;
    }
    if(strcmp(dest, "tspan") == 0 || kind == NSXMLTextKind) {
        (void)free(dest), dest = NULL;
        return IJSVGNodeTypeTextSpan;
    }
    if(strcmp(dest, "title") == 0) {
        (void)free(dest), dest = NULL;
        return IJSVGNodeTypeTitle;
    }
    if(strcmp(dest, "desc") == 0) {
        (void)free(dest), dest = NULL;
        return IJSVGNodeTypeDesc;
    }
    if(strcmp(dest, "foreignobject") == 0) {
        (void)free(dest), dest = NULL;
        return IJSVGNodeTypeForeignObject;
    }
    if(strcmp(dest, "filter") == 0) {
        (void)free(dest), dest = NULL;
        return IJSVGNodeTypeFilter;
    }
    if(strcmp(dest, "fegaussianblur") == 0) {
        (void)free(dest), dest = NULL;
        return IJSVGNodeTypeFilterEffect;
    }
    (void)free(dest), dest = NULL;
    return IJSVGNodeTypeUnknown;
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
    
    self.name = node.name;
    self.type = node.type;
    self.unicode = node.unicode;
    self.className = node.className;
    self.classNameList = node.classNameList;
    
    self.viewBox = node.viewBox;
    self.viewBoxAlignment = node.viewBoxAlignment;
    self.viewBoxMeetOrSlice = node.viewBoxMeetOrSlice;

    self.x = node.x;
    self.y = node.y;
    self.width = node.width;
    self.height = node.height;

    self.fill = node.fill;
    self.stroke = node.stroke;
    self.clipPath = node.clipPath;

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
    CGFloat* nStrokeDashArray = (CGFloat*)malloc(node.strokeDashArrayCount * sizeof(CGFloat));
    memcpy(self.strokeDashArray, nStrokeDashArray, node.strokeDashArrayCount * sizeof(CGFloat));
    self.strokeDashArray = nStrokeDashArray;
    self.strokeDashArrayCount = node.strokeDashArrayCount;
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

// winding rule can inherit..
- (IJSVGWindingRule)windingRule
{
    if(_windingRule == IJSVGWindingRuleInherit && _parentNode != nil) {
        return _parentNode.windingRule;
    }
    return _windingRule;
}

- (IJSVGWindingRule)clipRule
{
    if(_clipRule == IJSVGWindingRuleInherit && _parentNode != nil) {
        return _parentNode.clipRule;
    }
    return _clipRule;
}

- (IJSVGLineCapStyle)lineCapStyle
{
    if(_lineCapStyle == IJSVGLineCapStyleInherit) {
        if(_parentNode != nil) {
            return _parentNode.lineCapStyle;
        }
    }
    return _lineCapStyle;
}

- (IJSVGLineJoinStyle)lineJoinStyle
{
    if(_lineJoinStyle == IJSVGLineJoinStyleInherit) {
        if(_parentNode != nil) {
            return _parentNode.lineJoinStyle;
        }
    }
    return _lineJoinStyle;
}

// these are all recursive, so go up the chain
// if they dont exist on this specific node
- (IJSVGUnitLength*)opacity
{
    if(_opacity.inherit && _parentNode != nil) {
        return _parentNode.opacity;
    }
    return _opacity;
}

// these are all recursive, so go up the chain
// if they dont exist on this specific node
- (IJSVGUnitLength*)fillOpacity
{
    if(_fillOpacity.inherit && _parentNode != nil) {
        return _parentNode.fillOpacity;
    }
    return _fillOpacity;
}

// these are all recursive, so go up the chain
// if they dont exist on this specific node
- (IJSVGUnitLength*)strokeWidth
{
    if(_strokeWidth.inherit && _parentNode != nil) {
        return _parentNode.strokeWidth;
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
    if(_stroke == nil && _parentNode != nil) {
        return _parentNode.stroke;
    }
    return _stroke;
}

- (CGFloat*)strokeDashArray
{
    if(_strokeDashArray == NULL && _parentNode != nil) {
        return _parentNode.strokeDashArray;
    }
    return _strokeDashArray;
}

- (NSInteger)strokeDashArrayCount
{
    if(_strokeDashArrayCount == IJSVGInheritedIntegerValue && _parentNode != nil) {
        return _parentNode.strokeDashArrayCount;
    }
    return _strokeDashArrayCount;
}

- (IJSVGUnitLength *)strokeDashOffset
{
    if(_strokeDashOffset == nil && _parentNode != nil) {
        return _parentNode.strokeDashOffset;
    }
    return _strokeDashOffset;
}

- (IJSVGUnitLength*)strokeOpacity
{
    if(_strokeOpacity.inherit && _parentNode != nil) {
        return _parentNode.strokeOpacity;
    }
    return _strokeOpacity;
}

// even though the spec explicity states fill color
// must be on the path, it can also be on the
- (IJSVGNode*)fill
{
    if(_fill == nil && _parentNode != nil) {
        return _parentNode.fill;
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
    if(_strokeMiterLimit == nil && _parentNode != nil) {
        return _parentNode.strokeMiterLimit;
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

- (void)normalizeWithOffset:(CGPoint)offset
{
    // if an SVG has been asked to normalize, its root will give us an offset
    // to transform by to shift everything based on the viewBox's origin, we can
    // simply just create a translate transform and stick at first position.
    NSMutableArray* transforms = self.transforms ?
        self.transforms.mutableCopy : [[NSMutableArray alloc] init];
    IJSVGTransform* transform = [IJSVGTransform transformByTranslatingX:-offset.x
                                                                      y:-offset.y];
    [transforms insertObject:transform atIndex:0];
    self.transforms = transforms;
}

@end
