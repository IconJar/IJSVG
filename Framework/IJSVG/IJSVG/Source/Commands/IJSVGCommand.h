//
//  IJSVGCommand.h
//  IconJar
//
//  Created by Curtis Hard on 30/08/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import "IJSVGPath.h"
#import <Foundation/Foundation.h>

static const NSInteger IJSVGCustomVariableParameterCount = NSNotFound;

typedef NS_ENUM(NSInteger, IJSVGCommandType) {
    IJSVGCommandTypeAbsolute,
    IJSVGCommandTypeRelative
};

typedef NS_ENUM(NSUInteger, IJSVGPathDataSequence) {
    IJSVGPathDataSequenceTypeFloat,
    IJSVGPathDataSequenceTypeFlag
};

@interface IJSVGCommand : NSObject {
    NSString* commandString;
    NSString* command;
    CGFloat* parameters;
    NSInteger parameterCount;
    NSArray<IJSVGCommand*>* subCommands;
    NSInteger requiredParameters;
    IJSVGCommandType type;
    IJSVGCommand* previousCommand;
    NSInteger _currentIndex;
    BOOL isSubCommand;
}

@property (nonatomic, copy) NSString* commandString;
@property (nonatomic, copy) NSString* command;
@property (nonatomic, assign) CGFloat* parameters;
@property (nonatomic, assign) NSInteger parameterCount;
@property (nonatomic, assign) NSInteger requiredParameters;
@property (nonatomic, assign) IJSVGCommandType type;
@property (nonatomic, retain) NSArray<IJSVGCommand*>* subCommands;
@property (nonatomic, assign) IJSVGCommand* previousCommand;
@property (nonatomic, assign) BOOL isSubCommand;

+ (Class)commandClassForCommandChar:(char)aChar;
+ (NSInteger)requiredParameterCount;
+ (NSPoint)readCoordinatePair:(CGFloat*)pairs
                        index:(NSInteger)index;
+ (IJSVGPathDataSequence*)pathDataSequence;
+ (void)runWithParams:(CGFloat*)params
           paramCount:(NSInteger)count
              command:(IJSVGCommand*)currentCommand
      previousCommand:(IJSVGCommand*)command
                 type:(IJSVGCommandType)type
                 path:(IJSVGPath*)path;
+ (void)parseParams:(CGFloat*)params
         paramCount:(NSInteger)paramCount
          intoArray:(NSMutableArray<IJSVGCommand*>*)commands
      parentCommand:(IJSVGCommand*)parentCommand;

- (id)initWithCommandString:(NSString*)commandString;
- (IJSVGCommand*)subcommandWithParameters:(CGFloat*)subParams
                          previousCommand:(IJSVGCommand*)command;

- (CGFloat)readFloat;
- (NSPoint)readPoint;
- (BOOL)readBOOL;
- (void)resetRead;

@end
