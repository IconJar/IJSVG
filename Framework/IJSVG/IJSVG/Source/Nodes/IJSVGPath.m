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
    BOOL _pathInitialized;
}
@synthesize path = _path;

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
    if (_pathInitialized) {
        node.path = _path;
    }
    node.markerPathData = self.markerPathData;
    node.pathUnits = _pathUnits;
    node.primitiveType = _primitiveType;
    node.pathLength = _pathLength;
    node.lastControlPoint = _lastControlPoint;
    return node;
}

- (NSString*)markerPathData
{
    return _markerSourcePath != NULL && CGPathEqualToPath(self.path, _markerSourcePath) ? _markerPathData : nil;
}

- (void)setMarkerPathData:(NSString*)data
{
    _markerPathData = data.copy;
    CGPathRelease(_markerSourcePath);
    _markerSourcePath = data == nil ? NULL : CGPathCreateCopy(self.path);
}

// A cache hit can assign geometry without first allocating an empty path.
// Explicitly assigning NULL still stays NULL until another assignment.
- (CGMutablePathRef)path
{
    if (!_pathInitialized) {
        _path = CGPathCreateMutable();
        _pathInitialized = YES;
    }
    return _path;
}

- (void)resetPathForParsing
{
    CGPathRelease(_path);
    _path = NULL;
    _pathInitialized = NO;
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
    _pathInitialized = YES;
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
    if (_pointSubpathSource == NULL || !CGPathEqualToPath(self.path, _pointSubpathSource)) {
        CGPathRelease(_pointSubpathSource);
        _pointSubpathSource = CGPathCreateCopy(_path);
        _hasPointSubpaths = IJSVGPathHasPointSubpaths(_pointSubpathSource);
    }
    return _hasPointSubpaths;
}

- (CGRect)pathBoundingBox
{
    return CGPathGetBoundingBox(self.path);
}

- (CGRect)controlPointBoundingBox
{
    return CGPathGetPathBoundingBox(self.path);
}

- (NSPoint)currentPoint
{
    return CGPathGetCurrentPoint(self.path);
}

- (void)close
{
    CGPathCloseSubpath(self.path);
}

#pragma mark Traits

- (void)computeTraits
{
    IJSVGNode* stroke = self.stroke;
    if (stroke != nil) {
        // by default we can just add this on
        [self addTraits:IJSVGNodeTraitStroked];

        // if we detect the stroke was a color, we need to check its alpha
        // component to then remove the trait if its 0.f
        if ([stroke isKindOfClass:IJSVGColorNode.class] == YES) {
            IJSVGColorNode* strokeColor = (IJSVGColorNode*)stroke;
            CGColorRef color = strokeColor.color;
            if (color == NULL || CGColorGetAlpha(color) == 0.f || strokeColor.isNoneOrTransparent == YES) {
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
