//
//  IJSVGFilterPrimitive.m
//  IJSVG
//
//  Created on 29/09/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGFilterPrimitive.h>
#import <IJSVG/IJSVGParser.h>
#import <IJSVG/IJSVGParserUtils.h>
#import <IJSVG/IJSVGUtils.h>

typedef struct {
    const char* name;
    NSInteger value;
} IJSVGFilterKeyword;

static NSInteger IJSVGFilterKeywordValue(NSString* string, const IJSVGFilterKeyword* keywords,
    size_t count, NSInteger fallback)
{
    const char* value = string.UTF8String;
    if(value == NULL || strlen(value) != [string lengthOfBytesUsingEncoding:NSUTF8StringEncoding]) {
        return fallback;
    }
    for(size_t i = 0; i < count; i++) {
        if(strcmp(value, keywords[i].name) == 0) {
            return keywords[i].value;
        }
    }
    return fallback;
}

static IJSVGFilterCompositeOperator IJSVGFilterCompositeOperatorForString(NSString* value)
{
    static const IJSVGFilterKeyword keywords[] = {
        {"over", IJSVGFilterCompositeOperatorOver},
        {"in", IJSVGFilterCompositeOperatorIn},
        {"out", IJSVGFilterCompositeOperatorOut},
        {"atop", IJSVGFilterCompositeOperatorAtop},
        {"xor", IJSVGFilterCompositeOperatorXor},
        {"arithmetic", IJSVGFilterCompositeOperatorArithmetic},
        {"lighter", IJSVGFilterCompositeOperatorLighter}
    };
    return (IJSVGFilterCompositeOperator)IJSVGFilterKeywordValue(value, keywords,
        sizeof(keywords) / sizeof(*keywords), IJSVGFilterCompositeOperatorOver);
}

static IJSVGFilterEdgeMode IJSVGFilterEdgeModeForString(NSString* value)
{
    static const IJSVGFilterKeyword keywords[] = {
        {"none", IJSVGFilterEdgeModeNone},
        {"duplicate", IJSVGFilterEdgeModeDuplicate},
        {"wrap", IJSVGFilterEdgeModeWrap}
    };
    return (IJSVGFilterEdgeMode)IJSVGFilterKeywordValue(value, keywords,
        sizeof(keywords) / sizeof(*keywords), IJSVGFilterEdgeModeUnspecified);
}

static IJSVGFilterColorMatrixType IJSVGFilterColorMatrixTypeForString(NSString* value)
{
    static const IJSVGFilterKeyword keywords[] = {
        {"matrix", IJSVGFilterColorMatrixTypeMatrix},
        {"saturate", IJSVGFilterColorMatrixTypeSaturate},
        {"hueRotate", IJSVGFilterColorMatrixTypeHueRotate},
        {"luminanceToAlpha", IJSVGFilterColorMatrixTypeLuminanceToAlpha}
    };
    return (IJSVGFilterColorMatrixType)IJSVGFilterKeywordValue(value, keywords,
        sizeof(keywords) / sizeof(*keywords), IJSVGFilterColorMatrixTypeMatrix);
}

static IJSVGFilterTransferType IJSVGFilterTransferTypeForString(NSString* value)
{
    static const IJSVGFilterKeyword keywords[] = {
        {"identity", IJSVGFilterTransferTypeIdentity},
        {"table", IJSVGFilterTransferTypeTable},
        {"discrete", IJSVGFilterTransferTypeDiscrete},
        {"linear", IJSVGFilterTransferTypeLinear},
        {"gamma", IJSVGFilterTransferTypeGamma}
    };
    return (IJSVGFilterTransferType)IJSVGFilterKeywordValue(value, keywords,
        sizeof(keywords) / sizeof(*keywords), IJSVGFilterTransferTypeIdentity);
}

static IJSVGFilterMorphologyOperator IJSVGFilterMorphologyOperatorForString(NSString* value)
{
    static const IJSVGFilterKeyword keywords[] = {
        {"erode", IJSVGFilterMorphologyOperatorErode},
        {"dilate", IJSVGFilterMorphologyOperatorDilate}
    };
    return (IJSVGFilterMorphologyOperator)IJSVGFilterKeywordValue(value, keywords,
        sizeof(keywords) / sizeof(*keywords), IJSVGFilterMorphologyOperatorErode);
}

static IJSVGFilterTurbulenceType IJSVGFilterTurbulenceTypeForString(NSString* value)
{
    static const IJSVGFilterKeyword keywords[] = {
        {"turbulence", IJSVGFilterTurbulenceTypeTurbulence},
        {"fractalNoise", IJSVGFilterTurbulenceTypeFractalNoise}
    };
    return (IJSVGFilterTurbulenceType)IJSVGFilterKeywordValue(value, keywords,
        sizeof(keywords) / sizeof(*keywords), IJSVGFilterTurbulenceTypeTurbulence);
}

static IJSVGFilterColorChannel IJSVGFilterColorChannelForString(NSString* value)
{
    static const IJSVGFilterKeyword keywords[] = {
        {"R", IJSVGFilterColorChannelRed},
        {"G", IJSVGFilterColorChannelGreen},
        {"B", IJSVGFilterColorChannelBlue},
        {"A", IJSVGFilterColorChannelAlpha}
    };
    return (IJSVGFilterColorChannel)IJSVGFilterKeywordValue(value, keywords,
        sizeof(keywords) / sizeof(*keywords), IJSVGFilterColorChannelAlpha);
}

static IJSVGBlendMode IJSVGBlendModeForString(NSString* value)
{
    static const IJSVGFilterKeyword keywords[] = {
        {"normal", IJSVGBlendModeNormal},
        {"multiply", IJSVGBlendModeMultiply},
        {"screen", IJSVGBlendModeScreen},
        {"darken", IJSVGBlendModeDarken},
        {"lighten", IJSVGBlendModeLighten},
        {"overlay", IJSVGBlendModeOverlay},
        {"color-dodge", IJSVGBlendModeColorDodge},
        {"color-burn", IJSVGBlendModeColorBurn},
        {"hard-light", IJSVGBlendModeHardLight},
        {"soft-light", IJSVGBlendModeSoftLight},
        {"difference", IJSVGBlendModeDifference},
        {"exclusion", IJSVGBlendModeExclusion},
        {"hue", IJSVGBlendModeHue},
        {"saturation", IJSVGBlendModeSaturation},
        {"color", IJSVGBlendModeColor},
        {"luminosity", IJSVGBlendModeLuminosity}
    };
    return (IJSVGBlendMode)IJSVGFilterKeywordValue(value, keywords,
        sizeof(keywords) / sizeof(*keywords), IJSVGBlendModeNormal);
}

@implementation IJSVGFilterPrimitive {
    NSDictionary<NSString*, NSString*>* _parameters;
    NSMutableDictionary<NSString*, id>* _preparedValues;
    NSMutableDictionary<NSString*, NSArray<NSNumber*>*>* _parsedNumbers;
}

@synthesize parameters = _parameters;
@synthesize edgeMode = _edgeMode;

+ (IJSVGNodeType)defaultNodeType
{
    // A primitive needs a specific operation before it has an SVG element name.
    return IJSVGNodeTypeUnknown;
}

- (IJSVGFilterEdgeMode)edgeMode
{
    if(_edgeMode == IJSVGFilterEdgeModeUnspecified) {
        return self.type == IJSVGNodeTypeFilterConvolveMatrix ?
            IJSVGFilterEdgeModeDuplicate : IJSVGFilterEdgeModeNone;
    }
    return _edgeMode;
}

- (void)setParameters:(NSDictionary<NSString*, NSString*>*)parameters
{
    @synchronized(self) {
        _parameters = parameters.copy;
        _preparedValues = nil;
        _parsedNumbers = nil;
        _compositeOperator = IJSVGFilterCompositeOperatorForString(_parameters[IJSVGAttributeOperator]);
        _edgeMode = IJSVGFilterEdgeModeForString(_parameters[IJSVGAttributeEdgeMode]);
        _colorMatrixType = IJSVGFilterColorMatrixTypeForString(_parameters[IJSVGAttributeType]);
        _transferType = IJSVGFilterTransferTypeForString(_parameters[IJSVGAttributeType]);
        _morphologyOperator = IJSVGFilterMorphologyOperatorForString(_parameters[IJSVGAttributeOperator]);
        _turbulenceType = IJSVGFilterTurbulenceTypeForString(_parameters[IJSVGAttributeType]);
        _xChannel = IJSVGFilterColorChannelForString(_parameters[IJSVGAttributeXChannelSelector]);
        _yChannel = IJSVGFilterColorChannelForString(_parameters[IJSVGAttributeYChannelSelector]);
        _filterBlendMode = IJSVGBlendModeForString(_parameters[IJSVGAttributeMode]);
        _preserveAlpha = [_parameters[IJSVGAttributePreserveAlpha] isEqualToString:IJSVGStringTrue];
        _stitchTiles = [_parameters[IJSVGAttributeStitchTiles] isEqualToString:IJSVGStringStitch];
    }
}

- (id)preparedValueForKey:(NSString*)key builder:(id (^)(void))builder
{
    // Builders may read numeric parameters recursively. Synchronizing the
    // whole preparation also prevents a replacement from publishing stale data.
    @synchronized(self) {
        id value = _preparedValues[key];
        if(value == nil) {
            value = builder();
            if(value != nil) {
                if(_preparedValues == nil) {
                    _preparedValues = [[NSMutableDictionary alloc] init];
                }
                _preparedValues[key] = value;
            }
        }
        return value;
    }
}

+ (NSSet<NSString*>*)filterParameterNames
{
    return [NSSet setWithArray:@[
        IJSVGAttributeIn2, IJSVGAttributeMode, IJSVGAttributeType, IJSVGAttributeValues, IJSVGAttributeOperator,
        IJSVGAttributeK1, IJSVGAttributeK2, IJSVGAttributeK3, IJSVGAttributeK4, IJSVGAttributeOrder,
        IJSVGAttributeKernelMatrix, IJSVGAttributeDivisor, IJSVGAttributeBias, IJSVGAttributeTargetX,
        IJSVGAttributeTargetY, IJSVGAttributeEdgeMode, IJSVGAttributeKernelUnitLength, IJSVGAttributePreserveAlpha,
        IJSVGAttributeSurfaceScale, IJSVGAttributeDiffuseConstant, IJSVGAttributeSpecularConstant,
        IJSVGAttributeSpecularExponent, IJSVGAttributeLightingColor, IJSVGAttributeScale,
        IJSVGAttributeXChannelSelector, IJSVGAttributeYChannelSelector, IJSVGAttributeFloodColor,
        IJSVGAttributeFloodOpacity, IJSVGAttributeStdDeviation, IJSVGAttributeRadius, IJSVGAttributeDX,
        IJSVGAttributeDY, IJSVGAttributeBaseFrequency, IJSVGAttributeNumOctaves, IJSVGAttributeSeed,
        IJSVGAttributeStitchTiles, IJSVGAttributeTableValues, IJSVGAttributeSlope, IJSVGAttributeIntercept,
        IJSVGAttributeAmplitude, IJSVGAttributeExponent, IJSVGAttributeOffset, IJSVGAttributeAzimuth,
        IJSVGAttributeElevation, IJSVGAttributeX, IJSVGAttributeY, IJSVGAttributeZ, IJSVGAttributePointsAtX,
        IJSVGAttributePointsAtY, IJSVGAttributePointsAtZ, IJSVGAttributeLimitingConeAngle, IJSVGAttributeHref,
        IJSVGAttributeXLink, IJSVGAttributePreserveAspectRatio
    ]];
}

+ (IJSVGBitFlags*)allowedAttributes
{
    IJSVGBitFlags* storage = [[IJSVGBitFlags alloc] initWithLength:kIJSVGNodeAttributeStorageLength];
    [storage addBits:[IJSVGNode allowedAttributes]];
    [storage setBit:IJSVGNodeAttributeX];
    [storage setBit:IJSVGNodeAttributeY];
    [storage setBit:IJSVGNodeAttributeWidth];
    [storage setBit:IJSVGNodeAttributeHeight];
    [storage setBit:IJSVGNodeAttributeIn];
    [storage setBit:IJSVGNodeAttributeResult];
    [storage setBit:IJSVGNodeAttributePreserveAspectRatio];
    for(NSString* name in self.parameterNames) {
        NSUInteger attribute = IJSVGNodeAttributeForName(name);
        if(attribute != NSNotFound) {
            [storage setBit:(int)attribute];
        }
    }
    return storage;
}

- (void)setDefaults
{
    [super setDefaults];
    self.shouldRender = NO;
    self.parameters = nil;
}

/// Copies filter inputs and image references.
- (void)applyPropertiesFromNode:(IJSVGNode*)node
{
    [super applyPropertiesFromNode:node];
    if([node isKindOfClass:IJSVGFilterPrimitive.class]) {
        IJSVGFilterPrimitive* primitive = (IJSVGFilterPrimitive*)node;
        self.input = primitive.input;
        self.result = primitive.result;
        self.input2 = primitive.input2;
        self.parameters = primitive.parameters;
        self.imageNode = primitive.imageNode.copy;
        self.image = primitive.image;
    }
}

+ (NSSet<NSString*>*)parameterNames
{
    static NSSet<NSString*>* names;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        names = [self filterParameterNames];
    });
    return names;
}

+ (BOOL)isPrimitiveType:(IJSVGNodeType)type
{
    return type == IJSVGNodeTypeFilterDropShadow
        || (type >= IJSVGNodeTypeFilterBlend && type <= IJSVGNodeTypeFilterTurbulence);
}

+ (BOOL)type:(IJSVGNodeType)parentType
    acceptsChildType:(IJSVGNodeType)childType
{
    if(parentType == IJSVGNodeTypeFilter) {
        return [self isPrimitiveType:childType];
    }
    if(parentType == IJSVGNodeTypeFilterMerge) {
        return childType == IJSVGNodeTypeFilterMergeNode;
    }
    if(parentType == IJSVGNodeTypeFilterComponentTransfer) {
        return childType >= IJSVGNodeTypeFilterFuncR && childType <= IJSVGNodeTypeFilterFuncA;
    }
    if(parentType == IJSVGNodeTypeFilterDiffuseLighting || parentType == IJSVGNodeTypeFilterSpecularLighting) {
        return childType >= IJSVGNodeTypeFilterDistantLight && childType <= IJSVGNodeTypeFilterSpotLight;
    }
    return NO;
}

- (NSArray<NSNumber*>*)numbersForParameter:(NSString*)name
{
    @synchronized(self) {
        NSString* string = _parameters[name];
        if(string.length == 0) {
            return @[];
        }
      
        // Mesh composites overwhelmingly use these constants. Share them even
        // on the first draw, without allocating a cache for each triangle.
        if([string isEqualToString:@"0"] || [string isEqualToString:@"1"]) {
            static NSArray<NSNumber*>* constants[2];
            static dispatch_once_t once;
            dispatch_once(&once, ^{
                constants[0] = @[@0];
                constants[1] = @[@1];
            });
            return constants[[string isEqualToString:@"1"] ? 1 : 0];
        }
        NSArray<NSNumber*>* numbers = _parsedNumbers[name];
        if(numbers == nil) {
            numbers = [[IJSVGUtils numbersFromString:string] copy];
            if(_parsedNumbers == nil) {
                _parsedNumbers = [[NSMutableDictionary alloc] init];
            }
            _parsedNumbers[name] = numbers;
        }
        return numbers;
    }
}

- (CGFloat)numberForParameter:(NSString*)name
                 defaultValue:(CGFloat)value
{
    NSArray<NSNumber*>* numbers = [self numbersForParameter:name];
    return numbers.count == 1 ? numbers[0].doubleValue : value;
}

- (CGSize)pairForParameter:(NSString*)name
              defaultValue:(CGSize)value
{
    NSArray<NSNumber*>* numbers = [self numbersForParameter:name];
    if(numbers.count == 1 || numbers.count == 2) {
        return CGSizeMake(numbers[0].doubleValue, numbers.lastObject.doubleValue);
    }
    return value;
}

@end
