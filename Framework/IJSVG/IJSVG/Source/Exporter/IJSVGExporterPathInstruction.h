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

@interface IJSVGExporterPathInstruction : NSObject {

@private
    NSInteger _dataCount;
    CGFloat* _data;
}

@property (nonatomic, assign) char instruction;

IJSVGExporterPathInstructionCommand* IJSVGExporterPathInstructionCommandCopy(IJSVGExporterPathInstructionCommand command);
void IJSVGExporterPathInstructionCommandFree(IJSVGExporterPathInstructionCommand* _Nullable command);

+ (NSArray<IJSVGExporterPathInstruction*>*)instructionsFromPath:(CGPathRef)path;

- (id)initWithInstruction:(char)instruction
                dataCount:(NSInteger)floatCount;

- (CGFloat*)data;
- (NSInteger)dataLength;

+ (NSArray<IJSVGExporterPathInstruction*>*)convertInstructionsCurves:(NSArray<IJSVGExporterPathInstruction*>*)instructions;
+ (void)convertInstructionsToRelativeCoordinates:(NSArray<IJSVGExporterPathInstruction*>*)instructions;
+ (NSString*)pathStringFromInstructions:(NSArray<IJSVGExporterPathInstruction*>*)instructions;
+ (NSString*)pathStringWithInstructionSet:(NSArray<NSValue*>*)instructionSets;

@end
NS_ASSUME_NONNULL_END
