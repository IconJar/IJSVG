//
//  IJSVGExporterPathInstruction.h
//  IconJar
//
//  Created by Curtis Hard on 08/01/2017.
//  Copyright © 2017 Curtis Hard. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
@interface IJSVGExporterPathInstruction : NSObject {

@private
    NSInteger _dataCount;
    char _instruction;
    CGFloat* _data;
}

+ (NSArray<IJSVGExporterPathInstruction*>*)instructionsFromPath:(CGPathRef)path;

- (id)initWithInstruction:(char)instruction
                dataCount:(NSInteger)floatCount;

- (void)setInstruction:(char)newInstruction;
- (char)instruction;
- (CGFloat*)data;
- (NSInteger)dataLength;

+ (void)convertInstructionsToRelativeCoordinates:(NSArray<IJSVGExporterPathInstruction*>*)instructions;
+ (NSString*)pathStringFromInstructions:(NSArray<IJSVGExporterPathInstruction*>*)instructions;
+ (NSString*)pathStringWithInstruction:(const char)instruction
                   previousInstruction:(const char)previousInstruction
                          instructions:(NSArray<NSArray<NSString*>*>* _Nullable)instructions;

@end
NS_ASSUME_NONNULL_END
