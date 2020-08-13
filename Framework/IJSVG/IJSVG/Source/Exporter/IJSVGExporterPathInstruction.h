//
//  IJSVGExporterPathInstruction.h
//  IconJar
//
//  Created by Curtis Hard on 08/01/2017.
//  Copyright © 2017 Curtis Hard. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef struct {
    char instruction;
    NSArray<NSString*>* params;
} IJSVGExporterPathInstructionCommand;

typedef struct {
    CGPoint center;
    CGFloat radius;
} IJSVGExporterPathInstructionCircle;

@interface IJSVGExporterPathInstruction : NSObject {

@private
    NSInteger _dataCount;
    CGFloat* _data;
    CGFloat* _base;
    CGFloat* _coords;
}

@property (nonatomic, assign) char instruction;

void IJSVGExporterPathInstructionRoundData(CGFloat* data, NSInteger length);
CGFloat IJSVGExporterPathFloatToFixed(CGFloat number, int precision);
IJSVGExporterPathInstructionCommand* IJSVGExporterPathInstructionCommandCopy(IJSVGExporterPathInstructionCommand command);
void IJSVGExporterPathInstructionCommandFree(IJSVGExporterPathInstructionCommand* _Nullable command);

+ (NSArray<IJSVGExporterPathInstruction*>*)instructionsFromPath:(CGPathRef)path;

- (id)initWithInstruction:(char)instruction
                dataCount:(NSInteger)floatCount;

- (CGFloat*)data;
- (NSInteger)dataLength;

+ (NSArray<IJSVGExporterPathInstruction*>*)convertInstructionsCurves:(NSArray<IJSVGExporterPathInstruction*>*)instructions;
+ (void)convertInstructionsToMixedAbsoluteRelative:(NSArray<IJSVGExporterPathInstruction*>*)instructions;
+ (void)convertInstructionsDataToRounded:(NSArray<IJSVGExporterPathInstruction*>*)instructions;
+ (void)convertInstructionsToRelativeCoordinates:(NSArray<IJSVGExporterPathInstruction*>*)instructions;
+ (NSString*)pathStringFromInstructions:(NSArray<IJSVGExporterPathInstruction*>*)instructions;
+ (NSString*)pathStringWithInstructionSet:(NSArray<NSValue*>*)instructionSets;

@end
NS_ASSUME_NONNULL_END

static NSInteger const kIJSVGExporterPathInstructionFloatPrecision = 3;
static CGFloat const kIJSVGExporterPathInstructionErrorThreshold = 1e-2;

#define IJ_SVG_EXPORT_ROUND(value) IJSVGExporterPathFloatToFixed(value, kIJSVGExporterPathInstructionFloatPrecision)
