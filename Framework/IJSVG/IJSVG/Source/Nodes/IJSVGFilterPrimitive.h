//
//  IJSVGFilterPrimitive.h
//  IJSVG
//
//  Created on 29/09/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGGroup.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, IJSVGFilterCompositeOperator) {
    IJSVGFilterCompositeOperatorOver,
    IJSVGFilterCompositeOperatorIn,
    IJSVGFilterCompositeOperatorOut,
    IJSVGFilterCompositeOperatorAtop,
    IJSVGFilterCompositeOperatorXor,
    IJSVGFilterCompositeOperatorArithmetic,
    IJSVGFilterCompositeOperatorLighter
};

typedef NS_ENUM(NSInteger, IJSVGFilterEdgeMode) {
    IJSVGFilterEdgeModeUnspecified = -1,
    IJSVGFilterEdgeModeNone,
    IJSVGFilterEdgeModeDuplicate,
    IJSVGFilterEdgeModeWrap
};

typedef NS_ENUM(NSInteger, IJSVGFilterColorMatrixType) {
    IJSVGFilterColorMatrixTypeMatrix,
    IJSVGFilterColorMatrixTypeSaturate,
    IJSVGFilterColorMatrixTypeHueRotate,
    IJSVGFilterColorMatrixTypeLuminanceToAlpha
};

typedef NS_ENUM(NSInteger, IJSVGFilterTransferType) {
    IJSVGFilterTransferTypeIdentity,
    IJSVGFilterTransferTypeTable,
    IJSVGFilterTransferTypeDiscrete,
    IJSVGFilterTransferTypeLinear,
    IJSVGFilterTransferTypeGamma
};

typedef NS_ENUM(NSInteger, IJSVGFilterMorphologyOperator) {
    IJSVGFilterMorphologyOperatorErode,
    IJSVGFilterMorphologyOperatorDilate
};

typedef NS_ENUM(NSInteger, IJSVGFilterTurbulenceType) {
    IJSVGFilterTurbulenceTypeTurbulence,
    IJSVGFilterTurbulenceTypeFractalNoise
};

typedef NS_ENUM(NSInteger, IJSVGFilterColorChannel) {
    IJSVGFilterColorChannelRed,
    IJSVGFilterColorChannelGreen,
    IJSVGFilterColorChannelBlue,
    IJSVGFilterColorChannelAlpha
};

@interface IJSVGFilterPrimitive : IJSVGGroup

@property (nonatomic, copy, nullable) NSString* input;
@property (nonatomic, copy, nullable) NSString* result;
@property (nonatomic, copy, nullable) NSString* input2;
// Primitive specific SVG attributes, retained for lossless vector export.
@property (nonatomic, copy, nullable) NSDictionary<NSString*, NSString*>* parameters;
@property (nonatomic, strong, nullable) IJSVGNode* imageNode;
@property (nonatomic, strong, nullable) NSImage* image;

@property (nonatomic, readonly) IJSVGFilterCompositeOperator compositeOperator;
@property (nonatomic, readonly) IJSVGFilterEdgeMode edgeMode;
@property (nonatomic, readonly) IJSVGFilterColorMatrixType colorMatrixType;
@property (nonatomic, readonly) IJSVGFilterTransferType transferType;
@property (nonatomic, readonly) IJSVGFilterMorphologyOperator morphologyOperator;
@property (nonatomic, readonly) IJSVGFilterTurbulenceType turbulenceType;
@property (nonatomic, readonly) IJSVGFilterColorChannel xChannel;
@property (nonatomic, readonly) IJSVGFilterColorChannel yChannel;
@property (nonatomic, readonly) IJSVGBlendMode filterBlendMode;
@property (nonatomic, readonly) BOOL preserveAlpha;
@property (nonatomic, readonly) BOOL stitchTiles;

+ (NSSet<NSString*>*)parameterNames;
+ (BOOL)isPrimitiveType:(IJSVGNodeType)type;
+ (BOOL)type:(IJSVGNodeType)parentType
    acceptsChildType:(IJSVGNodeType)childType;

// Immutable derived setup, discarded whenever parameters are replaced.
- (id _Nullable)preparedValueForKey:(NSString*)key
                  builder:(id _Nullable (^)(void))builder;
- (NSArray<NSNumber*>*)numbersForParameter:(NSString*)name;
- (CGFloat)numberForParameter:(NSString*)name
                 defaultValue:(CGFloat)value;
- (CGSize)pairForParameter:(NSString*)name
              defaultValue:(CGSize)value;

@end

NS_ASSUME_NONNULL_END
