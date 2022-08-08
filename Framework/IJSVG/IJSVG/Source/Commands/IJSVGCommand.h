//
//  IJSVGCommand.h
//  IconJar
//
//  Created by Curtis Hard on 30/08/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGCommandParser.h>
#import <IJSVG/IJSVGPath.h>
#import <Foundation/Foundation.h>

static const NSInteger IJSVGCustomVariableParameterCount = NSNotFound;

typedef NS_ENUM(NSInteger, IJSVGCommandType) {
    kIJSVGCommandTypeAbsolute,
    kIJSVGCommandTypeRelative
};

@interface IJSVGCommand : NSObject <NSCopying> {
@private
    NSInteger _currentIndex;
}

@property (nonatomic, assign) char command;
@property (nonatomic, assign) CGFloat* parameters;
@property (nonatomic, assign) NSInteger parameterCount;
@property (nonatomic, assign) IJSVGCommandType type;
@property (nonatomic, strong) NSArray<IJSVGCommand*>* subCommands;
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
                 path:(CGMutablePathRef)path;
+ (void)parseParams:(CGFloat*)params
         paramCount:(NSInteger)paramCount
          intoArray:(NSMutableArray<IJSVGCommand*>*)commands
      parentCommand:(IJSVGCommand*)parentCommand;

+ (NSArray<IJSVGCommand*>*)commandsForDataCharacters:(const char*)buffer;
+ (NSArray<IJSVGCommand*>*)commandsForDataCharacters:(const char*)buffer
                                          dataStream:(IJSVGPathDataStream*)dataStream;
+ (CGMutablePathRef)newPathForCommandsArray:(NSArray<IJSVGCommand*>*)commands;

+ (NSArray<IJSVGCommand*>*)convertCommands:(NSArray<IJSVGCommand*>*)commands
                                   toUnits:(IJSVGUnitType)unitType
                                    bounds:(CGRect)bounds;

- (id)initWithCommandStringBuffer:(const char*)str
                       dataStream:(IJSVGPathDataStream*)dataStream;
- (IJSVGCommand*)subcommandWithParameters:(CGFloat*)subParams
                               paramCount:(NSInteger)paramCount
                          previousCommand:(IJSVGCommand*)command;
- (void)convertToUnits:(IJSVGUnitType)units
           boundingBox:(CGRect)boundingBox;
- (IJSVGCommand*)commandByConvertingToUnits:(IJSVGUnitType)unitType
                                boundingBox:(CGRect)boundingBox;

- (CGFloat)readFloat;
- (NSPoint)readPoint;
- (BOOL)readBOOL;
- (void)resetRead;

@end
