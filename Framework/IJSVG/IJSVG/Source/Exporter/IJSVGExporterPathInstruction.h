//
//  IJSVGExporterPathInstruction.h
//  IJSVG
//
//  Created by Curtis Hard on 08/01/2017.
//  Copyright © 2017 Curtis Hard. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <TargetConditionals.h>
#import <IJSVG/IJSVGUnitLength.h>

NS_ASSUME_NONNULL_BEGIN

#if TARGET_OS_OSX
@interface IJSVGExporterPathInstructionCommand : NSObject {
}

@property (nonatomic, assign) char instruction;
@property (nonatomic, strong) NSArray<NSString*>* params;

@end

@interface IJSVGExporterPathInstruction : NSObject {

@private
    NSInteger _dataCount;
    CGFloat* _data;
    CGFloat _inlineData[7];
    CGFloat _base[2];
    CGFloat _coords[2];
}

@property (nonatomic, assign) char instruction;

#endif

void IJSVGExporterPathInstructionRoundData(CGFloat* data, NSInteger length, IJSVGFloatingPointOptions options);
CGFloat IJSVGExporterPathFloatToFixed(CGFloat number, int precision);

#if TARGET_OS_OSX
+ (NSArray<IJSVGExporterPathInstruction*>*)instructionsFromPath:(CGPathRef)path
                                           floatingPointOptions:(IJSVGFloatingPointOptions)floatingPointOptions;

- (id)initWithInstruction:(char)instruction
                dataCount:(NSInteger)floatCount;

- (CGFloat*)data;
- (NSInteger)dataLength;

+ (NSArray<IJSVGExporterPathInstruction*>*)convertInstructionsCurves:(NSArray<IJSVGExporterPathInstruction*>*)instructions
                                                floatingPointOptions:(IJSVGFloatingPointOptions)floatingPointOptions;
+ (void)convertInstructionsToMixedAbsoluteRelative:(NSArray<IJSVGExporterPathInstruction*>*)instructions
                              floatingPointOptions:(IJSVGFloatingPointOptions)floatingPointOptions;
+ (void)convertInstructionsDataToRounded:(NSArray<IJSVGExporterPathInstruction*>*)instructions
                    floatingPointOptions:(IJSVGFloatingPointOptions)floatingPointOptions;
+ (void)convertInstructionsDataToRoundedAndRecalculateCoordinates:(NSArray<IJSVGExporterPathInstruction*>*)instructions
                                             floatingPointOptions:(IJSVGFloatingPointOptions)floatingPointOptions;
+ (void)convertInstructionsToRelativeCoordinates:(NSArray<IJSVGExporterPathInstruction*>*)instructions
                            floatingPointOptions:(IJSVGFloatingPointOptions)floatingPointOptions;
+ (NSString*)pathStringFromInstructions:(NSArray<IJSVGExporterPathInstruction*>*)instructions
                   floatingPointOptions:(IJSVGFloatingPointOptions)floatingPointOptions;
+ (NSString*)pathStringWithInstructionSet:(NSArray<NSValue*>*)instructionSets
                     floatingPointOptions:(IJSVGFloatingPointOptions)floatingPointOptions;

@end
#endif

NS_ASSUME_NONNULL_END

static NSInteger const kIJSVGExporterPathInstructionFloatPrecision = 3;
static CGFloat const kIJSVGExporterPathInstructionErrorThreshold = 1e-2;

#define IJ_SVG_EXPORT_ROUND(value) IJSVGExporterPathFloatToFixed(value, kIJSVGExporterPathInstructionFloatPrecision)
