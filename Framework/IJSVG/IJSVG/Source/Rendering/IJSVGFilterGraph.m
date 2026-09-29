//
//  IJSVGFilterGraph.m
//  IJSVG
//
//  Created on 29/09/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGFilterGraph.h>
#import <IJSVG/IJSVGFilterEffect.h>
#import <IJSVG/IJSVGParser.h>

@implementation IJSVGFilterGraph

- (CGRect)regionForNode:(IJSVGNode*)node
                  units:(IJSVGUnitType)units
          defaultRegion:(CGRect)region
{
    CGRect bounds = units == IJSVGUnitObjectBoundingBox ? self.boundingBox : self.viewPort;
    BOOL objectUnits = units == IJSVGUnitObjectBoundingBox;
    IJSVGUnitLength* lengths[] = { node.x, node.y, node.width, node.height };
    CGFloat values[] = { region.origin.x, region.origin.y, region.size.width, region.size.height };
    for(NSUInteger index = 0; index < 4; index++) {
        IJSVGUnitLength* length = lengths[index];
        if(length == nil) {
            continue;
        }
        if(objectUnits) {
            length = [length lengthWithUnitType:IJSVGUnitLengthTypePercentage];
        }
        values[index] = [length computeValue:index % 2 == 0 ? bounds.size.width : bounds.size.height];
        if(index < 2 && (objectUnits || length.type == IJSVGUnitLengthTypePercentage)) {
            values[index] += index == 0 ? bounds.origin.x : bounds.origin.y;
        }
    }
    return CGRectMake(values[0], values[1], values[2], values[3]);
}

- (BOOL)usesLinearRGB:(IJSVGNode*)node
{
    for(IJSVGNode* current = node; current != nil; current = current.parentNode) {
        if([current.filterColorInterpolation isEqualToString:IJSVGStringSRGB]) {
            return NO;
        }
        if([current.filterColorInterpolation isEqualToString:IJSVGStringLinearRGB]) {
            return YES;
        }
    }
    return YES;
}

- (CIImage*)inputNamed:(NSString*)name
              previous:(CIImage*)previous
               sources:(NSDictionary<NSString*, CIImage*>*)sources
               results:(NSDictionary<NSString*, CIImage*>*)results
{
    if(name.length == 0) {
        return previous;
    }
    return sources[name] ?: results[name] ?: previous;
}

- (CIImage*)imageByFilteringSource:(CIImage*)source
{
    IJSVGFilterContext* renderingContext = [[IJSVGFilterContext alloc] init];
    renderingContext.filter = self.filter;
    renderingContext.boundingBox = self.boundingBox;
    renderingContext.viewPort = self.viewPort;
    renderingContext.extent = self.extent;
    renderingContext.imageTransform = self.imageTransform;
    renderingContext.context = self.context;
    renderingContext.imageProvider = self.imageProvider;
    CGRect userRegion = [self regionForNode:self.filter
                                      units:self.filter.units
                              defaultRegion:CGRectZero];
    CGRect filterRegion = CGRectApplyAffineTransform(userRegion, self.imageTransform);
    if(!IJSVGFilterValidRect(filterRegion)) {
        return CIImage.emptyImage;
    }
    source = [source imageByCroppingToRect:filterRegion];

    NSSet<NSString*>* inputNames = self.filter.inputNames;
    NSMutableDictionary<NSString*, CIImage*>* sources = [@{
        IJSVGStringSourceGraphic: source,
        IJSVGStringBackgroundImage: CIImage.emptyImage,
        IJSVGStringBackgroundAlpha: CIImage.emptyImage
    } mutableCopy];

    // Ordinary blurs and drop shadows do not reference SourceAlpha in the graph.
    if([inputNames containsObject:IJSVGStringSourceAlpha]) {
        sources[IJSVGStringSourceAlpha] = [renderingContext alphaForImage:source];
    }

    if(self.backgroundProvider != nil
        && ([inputNames containsObject:IJSVGStringBackgroundImage] || [inputNames containsObject:IJSVGStringBackgroundAlpha])) {
        CIImage* background = [self.backgroundProvider() imageByCroppingToRect:filterRegion] ?: CIImage.emptyImage;
        sources[IJSVGStringBackgroundImage] = background;
        if([inputNames containsObject:IJSVGStringBackgroundAlpha]) {
            sources[IJSVGStringBackgroundAlpha] = [renderingContext alphaForImage:background];
        }
    }

    if(self.paintProvider != nil) {
        if([inputNames containsObject:IJSVGStringFillPaint]) {
            sources[IJSVGStringFillPaint] = [self.paintProvider(NO) imageByCroppingToRect:filterRegion] ?: CIImage.emptyImage;
        }
        if([inputNames containsObject:IJSVGStringStrokePaint]) {
            sources[IJSVGStringStrokePaint] =
                [self.paintProvider(YES) imageByCroppingToRect:filterRegion] ?: CIImage.emptyImage;
        }
    }

    NSMutableDictionary<NSString*, CIImage*>* results = [[NSMutableDictionary alloc] init];
    NSArray<IJSVGFilterPrimitive*>* primitives = self.filter.primitives;
    BOOL preserveInnerShadowCoverage = self.filter.preservesInnerShadowCoverage;
    NSMutableDictionary<NSString*, NSNumber*>* lastReferences = [[NSMutableDictionary alloc] init];

    for(NSUInteger index = 0; index < primitives.count; index++) {
        IJSVGFilterPrimitive* primitive = primitives[index];
        if(primitive.input != nil) {
            lastReferences[primitive.input] = @(index);
        }
        if(primitive.input2 != nil) {
            lastReferences[primitive.input2] = @(index);
        }
        for(IJSVGFilterPrimitive* child in primitive.children) {
            if(child.input != nil) {
                lastReferences[child.input] = @(index);
            }
        }
    }

    // Schedule the release of each named result once instead of scanning all live results per primitive.
    NSMutableDictionary<NSNumber*, NSMutableArray<NSString*>*>* expiredNames = [[NSMutableDictionary alloc] init];
    for(NSString* name in lastReferences) {
        NSNumber* index = lastReferences[name];
        NSMutableArray<NSString*>* names = expiredNames[index];
        if(names == nil) {
            names = [[NSMutableArray alloc] init];
            expiredNames[index] = names;
        }
        [names addObject:name];
    }

    CGAffineTransform inverseTransform = CGAffineTransformInvert(self.imageTransform);
    CIImage* output = source;
    for(NSUInteger index = 0; index < primitives.count; index++) {
        IJSVGFilterPrimitive* primitive = primitives[index];
        @autoreleasepool {
            renderingContext.linearRGB = [self usesLinearRGB:primitive];
            CIImage* input = [self inputNamed:primitive.input
                                     previous:output
                                      sources:sources
                                      results:results];
            CIImage* other = [self inputNamed:primitive.input2
                                     previous:output
                                      sources:sources
                                      results:results];
            CGRect defaultRegion = input.extent;
            BOOL generator = primitive.type == IJSVGNodeTypeFilterFlood
                || primitive.type == IJSVGNodeTypeFilterTurbulence || primitive.type == IJSVGNodeTypeFilterImage
                || primitive.type == IJSVGNodeTypeFilterTile;
            if(generator) {
                defaultRegion = filterRegion;
            } else if(primitive.type == IJSVGNodeTypeFilterBlend || primitive.type == IJSVGNodeTypeFilterComposite
                || primitive.type == IJSVGNodeTypeFilterDisplacementMap) {
                defaultRegion = CGRectUnion(defaultRegion, other.extent);
            }
            NSMutableArray<CIImage*>* mergeInputs = nil;
            if(primitive.type == IJSVGNodeTypeFilterMerge) {
                defaultRegion = CGRectNull;
                mergeInputs = [[NSMutableArray alloc] init];
                for(IJSVGFilterPrimitive* child in primitive.children) {
                    CIImage* image = [self inputNamed:child.input
                                             previous:output
                                              sources:sources
                                              results:results];
                    [mergeInputs addObject:image];
                    defaultRegion = CGRectUnion(defaultRegion, image.extent);
                }
            }
            // Empty inputs still allow operations such as arithmetic k4 or an
            // alpha transfer intercept to produce pixels in the filter region.
            if(!IJSVGFilterValidRect(defaultRegion)) {
                defaultRegion = filterRegion;
            }
            CGRect defaultUserRegion
                = CGRectApplyAffineTransform(defaultRegion, inverseTransform);
            CGRect primitiveRegion = [self regionForNode:primitive
                                                   units:self.filter.contentUnits
                                           defaultRegion:defaultUserRegion];
            CGRect pixelRegion = CGRectApplyAffineTransform(primitiveRegion, self.imageTransform);
            if(!IJSVGFilterValidRect(pixelRegion)) {
                output = CIImage.emptyImage;
            } else {
                if(preserveInnerShadowCoverage && index > 1
                   && primitive.type == IJSVGNodeTypeFilterBlend) {
                    // A hard alpha inner shadow must shade the foreground without
                    // making its partially covered edge pixels opaque. Source atop
                    // preserves the original outline through successive shadows.
                    output = [renderingContext applyFilter:@"CISourceAtopCompositing"
                                                   toImage:input
                                                parameters:@{
                      kCIInputBackgroundImageKey: [renderingContext imageInPrimitiveColorSpace:other]
                    }];
                } else {
                    IJSVGFilterEffect* effect = [IJSVGFilterEffect effectForType:primitive.type];
                    NSArray<CIImage*>* inputs = mergeInputs ?: @[input, other];
                    output = [effect outputImageForPrimitive:primitive
                                                      inputs:inputs
                                                      region:pixelRegion
                                                     context:renderingContext] ?: CIImage.emptyImage;
                }
                CGRect clip = CGRectIntersection(filterRegion, pixelRegion);
                output = IJSVGFilterValidRect(clip) ? [output imageByCroppingToRect:clip] : CIImage.emptyImage;
            }
            // Keep only named intermediates with future consumers. The previous
            // output remains available independently for implicit chaining.
            for(NSString* name in expiredNames[@(index)]) {
                [results removeObjectForKey:name];
            }
            if(primitive.result.length != 0 && lastReferences[primitive.result].unsignedIntegerValue > index) {
                results[primitive.result] = output;
            }
        }
    }
    return primitives.count == 0 ? CIImage.emptyImage : output;
}

@end
