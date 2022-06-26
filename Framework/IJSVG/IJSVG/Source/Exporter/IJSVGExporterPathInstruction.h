//
//  IJSVGExporterPathInstruction.h
//  IconJar
//
//  Created by Curtis Hard on 08/01/2017.
//  Copyright © 2017 Curtis Hard. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface IJSVGExporterPathInstructionCommand : NSObject {
}

@property (nonatomic, assign) char instruction;
@property (nonatomic, strong) NSArray<NSString*>* params;

@end

@interface IJSVGExporterPathInstruction : NSObject {

@private
    NSInteger _dataCount;
    CGFloat* _data;
    CGFloat* _base;
    CGFloat* _coords;
}

@property (nonatomic, assign) char instruction;

void IJSVGExporterPathInstructionRoundData(CGFloat* data, NSInteger length, IJSVGFloatingPointOptions options);
CGFloat IJSVGExporterPathFloatToFixed(CGFloat number, int precision);

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
+ (void)convertInstructionsToRelativeCoordinates:(NSArray<IJSVGExporterPathInstruction*>*)instructions
                            floatingPointOptions:(IJSVGFloatingPointOptions)floatingPointOptions;
+ (NSString*)pathStringFromInstructions:(NSArray<IJSVGExporterPathInstruction*>*)instructions
                   floatingPointOptions:(IJSVGFloatingPointOptions)floatingPointOptions;
+ (NSString*)pathStringWithInstructionSet:(NSArray<NSValue*>*)instructionSets
                     floatingPointOptions:(IJSVGFloatingPointOptions)floatingPointOptions;

@end
NS_ASSUME_NONNULL_END

static NSInteger const kIJSVGExporterPathInstructionFloatPrecision = 3;
static CGFloat const kIJSVGExporterPathInstructionErrorThreshold = 1e-2;

#define IJ_SVG_EXPORT_ROUND(value) IJSVGExporterPathFloatToFixed(value, kIJSVGExporterPathInstructionFloatPrecision)
