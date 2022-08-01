//
//  IJSVGPath.m
//  IconJar
//
//  Created by Curtis Hard on 30/08/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGPath.h>
#import <IJSVG/IJSVGGroup.h>

@implementation IJSVGPath

+ (void)recursivelyAddPathedNodesPaths:(NSArray<IJSVGNode*>*)nodes
                             transform:(CGAffineTransform)transform
                                toPath:(CGMutablePathRef)mutPath
{
    for(IJSVGPath* pathNode in nodes) {
        // just a pathed node
        if([pathNode matchesTraits:IJSVGNodeTraitPathed] == YES) {
            CGPathAddPath(mutPath, &transform, pathNode.path);
            continue;
        }
        
        // could be a use group
        if([pathNode isKindOfClass:IJSVGGroup.class] == YES) {
            IJSVGGroup* useGroup = (IJSVGGroup*)pathNode;
            [self recursivelyAddPathedNodesPaths:useGroup.children
                                       transform:transform
                                          toPath:mutPath];
        }
    }
}

- (void)dealloc
{
    if(_path != NULL) {
        (void)CGPathRelease(_path), _path = NULL;
    }
}

- (id)init
{
    if((self = [super init]) != nil) {
        _primitiveType = kIJSVGPrimitivePathTypePath;
        _path = CGPathCreateMutable();
    }
    return self;
}

- (void)setDefaults
{
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
    return node;
}

- (void)setPath:(CGMutablePathRef)path
{
    // this will automatically copy any path into a mutable path
    // regardless of if it was a mutable path to begin with
    if(_path != NULL) {
        (void)CGPathRelease(_path), _path = NULL;
    }
    _path = CGPathCreateMutableCopy(path);
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
    if(self.stroke != nil) {
        // by default we can just add this on
        [self addTraits:IJSVGNodeTraitStroked];
        
        // if we detect the stroke was a color, we need to check its alpha
        // component to then remove the trait if its 0.f
        if([self.stroke isKindOfClass:IJSVGColorNode.class] == YES) {
            IJSVGColorNode* strokeColor = (IJSVGColorNode*)self.stroke;
            if(strokeColor.color.alphaComponent == 0.f ||
               strokeColor.isNoneOrTransparent == YES) {
                [self removeTraits:IJSVGNodeTraitStroked];
            }
        }
    }
}

@end
