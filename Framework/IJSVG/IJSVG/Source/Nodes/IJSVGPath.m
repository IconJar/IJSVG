//
//  IJSVGPath.m
//  IJSVG
//
//  Created by Curtis Hard on 30/08/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGGroup.h>
#import <IJSVG/IJSVGPath.h>
#import <IJSVG/IJSVGUtils.h>
#import <IJSVGNodeParsing.h>

@implementation IJSVGPath {
    NSString* _markerPathData;
    CGPathRef _markerSourcePath;
    CGPathRef _pointSubpathSource;
    BOOL _hasPointSubpaths;
}

+ (IJSVGNodeType)defaultNodeType
{
    return IJSVGNodeTypePath;
}

+ (void)recursivelyAddPathedNodesPaths:(NSArray<IJSVGNode*>*)nodes transform:(CGAffineTransform)transform toPath:(CGMutablePathRef)mutPath
{
    for (IJSVGPath* pathNode in nodes) {
        // just a pathed node
        if ([pathNode matchesTraits:IJSVGNodeTraitPathed] == YES) {
            CGPathAddPath(mutPath, &transform, pathNode.path);
            continue;
        }

        // could be a use group
        if ([pathNode isKindOfClass:IJSVGGroup.class] == YES) {
            IJSVGGroup* useGroup = (IJSVGGroup*)pathNode;
            [self recursivelyAddPathedNodesPaths:useGroup.children transform:transform toPath:mutPath];
        }
    }
}

- (void)dealloc
{
    CGPathRelease(_markerSourcePath);
    CGPathRelease(_pointSubpathSource);
    if (_path != NULL) {
        (void)CGPathRelease(_path), _path = NULL;
    }
}

- (id)init
{
    if ((self = [super init]) != nil) {
        _primitiveType = kIJSVGPrimitivePathTypePath;
        _pathUnits = IJSVGUnitInherit;
        _path = CGPathCreateMutable();
    }
    return self;
}

- (void)setDefaults
{
    [super setDefaults];
    [self addTraits:IJSVGNodeTraitPathed];
}

- (CGRect)bounds
{
    return self.pathBoundingBox;
}

- (id)copyWithZone:(NSZone*)zone
{
    IJSVGPath* node = [super copyWithZone:zone];
    node.path = _path;
    node.markerPathData = self.markerPathData;
    node.pathUnits = _pathUnits;
    node.primitiveType = _primitiveType;
    node.pathLength = _pathLength;
    node.lastControlPoint = _lastControlPoint;
    return node;
}

- (NSString*)markerPathData
{
    return _markerSourcePath != NULL && CGPathEqualToPath(_path, _markerSourcePath) ? _markerPathData : nil;
}

- (void)setMarkerPathData:(NSString*)data
{
    _markerPathData = data.copy;
    CGPathRelease(_markerSourcePath);
    _markerSourcePath = data == nil ? NULL : CGPathCreateCopy(_path);
}

- (void)setPath:(CGMutablePathRef)path
{
    // this will automatically copy any path into a mutable path
    // regardless of if it was a mutable path to begin with
    CGMutablePathRef copy = CGPathCreateMutableCopy(path);
    if (_path != NULL) {
        CGPathRelease(_path);
    }
    _path = copy;
}

- (void)cachePointSubpaths:(BOOL)hasPointSubpaths forPath:(CGPathRef)path
{
    CGPathRef snapshot = CGPathCreateCopy(path);
    CGPathRelease(_pointSubpathSource);
    _pointSubpathSource = snapshot;
    _hasPointSubpaths = hasPointSubpaths;
}

- (BOOL)hasPointSubpaths
{
    if (_pointSubpathSource == NULL || !CGPathEqualToPath(_path, _pointSubpathSource)) {
        CGPathRelease(_pointSubpathSource);
        _pointSubpathSource = CGPathCreateCopy(_path);
        _hasPointSubpaths = IJSVGPathHasPointSubpaths(_pointSubpathSource);
    }
    return _hasPointSubpaths;
}

- (CGRect)pathBoundingBox
{
    return CGPathGetBoundingBox(_path);
}

- (CGRect)controlPointBoundingBox
{
    return CGPathGetPathBoundingBox(_path);
}

- (NSPoint)currentPoint
{
    return CGPathGetCurrentPoint(_path);
}

- (void)close
{
    CGPathCloseSubpath(_path);
}

#pragma mark Traits

- (void)computeTraits
{
    if (self.stroke != nil) {
        // by default we can just add this on
        [self addTraits:IJSVGNodeTraitStroked];

        // if we detect the stroke was a color, we need to check its alpha
        // component to then remove the trait if its 0.f
        if ([self.stroke isKindOfClass:IJSVGColorNode.class] == YES) {
            IJSVGColorNode* strokeColor = (IJSVGColorNode*)self.stroke;
            if (strokeColor.color.alphaComponent == 0.f || strokeColor.isNoneOrTransparent == YES) {
                [self removeTraits:IJSVGNodeTraitStroked];
            }
        }
    }
}

@end

#pragma mark - Parsing

@implementation IJSVGPath (Parsing)

+ (IJSVGBitFlags*)allowedAttributes
{
    IJSVGBitFlags* attributes = IJSVGGraphicsAttributes();
    [attributes setBit:IJSVGNodeAttributeD];
    [attributes setBit:IJSVGNodeAttributePathLength];
    return attributes;
}

- (void)consumeAttributes:(IJSVGNodeParsingContext*)context
{
    IJSVGParseColorAttributes(self, context);
    IJSVGParseTextStyleAttributes(self, context);
    IJSVGParseGeometryInheritance(self, context);
    IJSVGParsePathAttributes(self, context);
    IJSVGParsePathLengthAttributes(self, context);
    IJSVGParseBackgroundAttributes(self, context);
    IJSVGParseFilterColorInterpolation(self, context);
    IJSVGParsePaintAttributes(self, context);
    IJSVGParseEffectsAttributes(self, context);
    IJSVGParseTransformAttributes(self, context);
    IJSVGParseDisplayAttributes(self, context);
    IJSVGParseMarkersAttributes(self, context);
}

@end
