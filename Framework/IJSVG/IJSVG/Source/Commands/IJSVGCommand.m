//
//  IJSVGCommand.m
//  IJSVG
//
//  Created by Curtis Hard on 30/08/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGCommand.h>
#import <IJSVG/IJSVGUtils.h>
#import <IJSVG/IJSVGCommandClose.h>
#import <IJSVG/IJSVGCommandCurve.h>
#import <IJSVG/IJSVGCommandEllipticalArc.h>
#import <IJSVG/IJSVGCommandHorizontalLine.h>
#import <IJSVG/IJSVGCommandLineTo.h>
#import <IJSVG/IJSVGCommandMove.h>
#import <IJSVG/IJSVGCommandQuadraticCurve.h>
#import <IJSVG/IJSVGCommandSmoothCurve.h>
#import <IJSVG/IJSVGCommandSmoothQuadraticCurve.h>
#import <IJSVG/IJSVGCommandVerticalLine.h>
#import <IJSVG/IJSVGThreadManager.h>

@implementation IJSVGCommand

+ (BOOL)requiresCustomParameterParsing
{
    return NO;
}

+ (NSInteger)requiredParameterCount
{
    return 1;
}

+ (IJSVGPathDataSequence*)pathDataSequence
{
    return NULL;
}

+ (void)runWithParams:(CGFloat*)params
           paramCount:(NSInteger)count
              command:(IJSVGCommand*)currentCommand
      previousCommand:(IJSVGCommand*)command
                 type:(IJSVGCommandType)type
                 path:(CGMutablePathRef)path
{
}

+ (void)parseParams:(CGFloat*)params
         paramCount:(NSInteger)paramCount
          intoArray:(NSMutableArray<IJSVGCommand*>*)commands
      parentCommand:(IJSVGCommand*)parentCommand
{
}

+ (XPoint)readCoordinatePair:(CGFloat*)pairs
                        index:(NSInteger)index
{
    return NSMakePoint(pairs[index * 2], pairs[index * 2 + 1]);
}

+ (void)load
{
    // register here...
}

+ (Class)commandClassForCommandChar:(char)aChar
{
    aChar = tolower((unsigned char)aChar);
    switch (aChar) {
    case 'a':
        return IJSVGCommandEllipticalArc.class;
    case 'c':
        return IJSVGCommandCurve.class;
    case 'h':
        return IJSVGCommandHorizontalLine.class;
    case 'l':
        return IJSVGCommandLineTo.class;
    case 'm':
        return IJSVGCommandMove.class;
    case 'q':
        return IJSVGCommandQuadraticCurve.class;
    case 's':
        return IJSVGCommandSmoothCurve.class;
    case 't':
        return IJSVGCommandSmoothQuadraticCurve.class;
    case 'v':
        return IJSVGCommandVerticalLine.class;
    case 'z':
        return IJSVGCommandClose.class;
    }
    return nil;
}

+ (CGMutablePathRef)newPathForCommandsArray:(NSArray<IJSVGCommand*>*)commands
{
    CGMutablePathRef path = CGPathCreateMutable();
    // If there are some commands in the array and the first one is NOT a move
    // command then we need to implicitly moe the path to zero point or CG will
    // throw warnings at us.
    if(commands.count > 0 && ![commands.firstObject isKindOfClass:IJSVGCommandMove.class]) {
      CGPathMoveToPoint(path, NULL, 0, 0);
    }
  
    IJSVGCommand* preCommand = nil;
    for(IJSVGCommand* command in commands) {
        for (IJSVGCommand* subCommand in command.subCommands) {
            [command.class runWithParams:subCommand.parameters
                              paramCount:subCommand.parameterCount
                                 command:subCommand
                         previousCommand:preCommand
                                    type:subCommand.type
                                    path:path];
            preCommand = subCommand;
        }
    }
    return path;
}

+ (NSArray<IJSVGCommand*>*)commandsForDataCharacters:(const char*)buffer
{
    IJSVGThreadManager* manager = IJSVGThreadManager.currentManager;
    NSArray<IJSVGCommand*>* commands = [self commandsForDataCharacters:buffer
                                                            dataStream:manager.pathDataStream];
    return commands;
}

+ (NSArray<IJSVGCommand*>*)commandsForDataCharacters:(const char*)buffer
                                          dataStream:(IJSVGPathDataStream*)dataStream
{
    NSMutableArray<IJSVGCommand*>* commands = [[NSMutableArray alloc] init];
    if(buffer == NULL) {
        return commands;
    }
    const char* cursor = buffer;
    while(*cursor != '\0') {
        Class commandClass = [self commandClassForCommandChar:*cursor];
        if(commandClass == Nil) {
            cursor++;
            continue;
        }
        const char* start = cursor++;
        while(*cursor != '\0' && !IJSVGIsLegalCommandCharacter(*cursor)) {
            cursor++;
        }
        NSUInteger length = (NSUInteger)(cursor - start);
        IJSVGCommand* command = [[commandClass alloc] initWithCommandStringBuffer:start
                                                                           length:length
                                                                       dataStream:dataStream];
        [commands addObject:command];
    }
    return commands;
}

+ (NSArray<IJSVGCommand*>*)convertCommands:(NSArray<IJSVGCommand*>*)commands
                                   toUnits:(IJSVGUnitType)unitType
                                    bounds:(CGRect)bounds
{
    NSMutableArray<IJSVGCommand*>* newCommands = nil;
    newCommands = [[NSMutableArray alloc] initWithCapacity:commands.count];
    for(IJSVGCommand* command in commands) {
        IJSVGCommand* nCommand = [command commandByConvertingToUnits:unitType
                                                         boundingBox:bounds];
        [newCommands addObject:nCommand];
    }
    return newCommands;
}

- (void)dealloc
{
    if(_parameters) {
        (void)(free(_parameters)), _parameters = nil;
    }
}

- (id)initWithCommandStringBuffer:(const char*)str
                       dataStream:(IJSVGPathDataStream*)dataStream
{
    NSUInteger length = str != NULL ? strlen(str) : 0;
    return [self initWithCommandStringBuffer:str length:length dataStream:dataStream];
}

- (id)initWithCommandStringBuffer:(const char*)str
                           length:(NSUInteger)length
                       dataStream:(IJSVGPathDataStream*)dataStream
{
    if((self = [super init]) != nil) {
        // work out the basics
        _currentIndex = 0;
        _command = length != 0 ? str[0] : '\0';
        _type = [IJSVGUtils typeForCommandChar:_command];
        NSInteger sets = 0;
        NSInteger paramCount = [self.class requiredParameterCount];
        IJSVGPathDataSequence* sequence = [self.class pathDataSequence];
        _parameters = IJSVGParsePathDataStreamSequence(str, length,
            dataStream, sequence, paramCount, &sets);

        if(paramCount != 0 && (_parameters == NULL || sets == 0)) {
            _subCommands = @[];
        } else if(sets <= 1) {
            CGFloat* subParams = [self parametersFromIndexOffset:0];
            IJSVGCommand* command = [self subcommandWithParameters:subParams
                                                        paramCount:paramCount
                                                   previousCommand:nil];
            _subCommands = @[ command ];
        } else {
            NSMutableArray<IJSVGCommand*>* subCommandArray = nil;
            subCommandArray = [[NSMutableArray alloc] initWithCapacity:sets];

            // interate over the sets
            IJSVGCommand* lastCommand = nil;
            for (NSInteger i = 0; i < sets; i++) {
                // memory for this will be handled by the created subcommand
                CGFloat* subParams = [self parametersFromIndexOffset:i];

                // generate the subcommand
                IJSVGCommand* command = [self subcommandWithParameters:subParams
                                                            paramCount:paramCount
                                                       previousCommand:lastCommand];

                // make sure we assign the last command or hell breaks
                // lose and the firey demons will run wild, namely, commands will break
                // if they are multiples of a set
                lastCommand = command;
                [subCommandArray addObject:command];
            }

            // store the retained value
            _subCommands = subCommandArray.copy;
        }
    }
    return self;
}

- (void)setSubCommands:(NSArray<IJSVGCommand*>*)subCommands
{
    _subCommands = subCommands;
}

- (id)copyWithZone:(NSZone *)zone
{
    IJSVGCommand* command = [[self.class alloc] init];
    command.type = self.type;
    command.command = self.command;
    command.isSubCommand = self.isSubCommand;
    command.parameterCount = self.parameterCount;
    size_t memsize = sizeof(CGFloat)*self.parameterCount;
    command.parameters = (CGFloat*)malloc(memsize);
    memcpy(command.parameters, self.parameters, memsize);
    
    
    IJSVGCommand* lastCommand = nil;
    NSMutableArray<IJSVGCommand*>* subcommands = nil;
    subcommands = [[NSMutableArray alloc] initWithCapacity:self.subCommands.count];
    for(IJSVGCommand* subcommand in self.subCommands) {
        IJSVGCommand* subCopy = subcommand.copy;
        subCopy.previousCommand = lastCommand;
        subCopy.isSubCommand = lastCommand != nil;
        [subcommands addObject:subCopy];
    }
    command.subCommands = subcommands;
    return command;
}

- (CGFloat*)parametersFromIndexOffset:(NSInteger)index
{
    CGFloat* subParams = 0;
    NSInteger req = [self.class requiredParameterCount];
    if(req != 0) {
        subParams = (CGFloat*)malloc(req * sizeof(CGFloat));
        memcpy(subParams, &self.parameters[index * req], sizeof(CGFloat) * req);
    }
    return subParams;
}

- (IJSVGCommand*)subcommandWithParameters:(CGFloat*)subParams
                               paramCount:(NSInteger)paramCount
                          previousCommand:(IJSVGCommand*)aPreviousCommand
{
    // create a subcommand per set
    IJSVGCommand* c = [[self.class alloc] init];
    c.parameterCount = paramCount;
    c.parameters = subParams;
    c.type = self.type;
    c.command = self.command;
    c.previousCommand = aPreviousCommand;
    c.isSubCommand = aPreviousCommand != nil;
    return c;
}

- (CGFloat)readFloat
{
    CGFloat f = _parameters[_currentIndex];
    _currentIndex++;
    return f;
}

- (XPoint)readPoint
{
    CGFloat x = _parameters[_currentIndex];
    CGFloat y = _parameters[_currentIndex + 1];
    _currentIndex += 2;
    return NSMakePoint(x, y);
}

- (BOOL)readBOOL
{
    return [self readFloat] == 1;
}

- (void)resetRead
{
    _currentIndex = 0;
}

- (void)convertToUnits:(IJSVGUnitType)units
           boundingBox:(CGRect)boundingBox
{
    for(IJSVGCommand* command in _subCommands) {
        [command convertToUnits:units
                    boundingBox:boundingBox];
    }
}

- (NSString *)description
{
    NSMutableString* str = [[NSMutableString alloc] init];
    [str appendFormat:@"%c ",_command];
    NSMutableArray* args = [[NSMutableArray alloc] initWithCapacity:_parameterCount];
    for(int i = 0; i < _parameterCount; i++) {
        [args addObject:[NSString stringWithFormat:@"%f",_parameters[i]]];
    }
    [str appendString:[args componentsJoinedByString:@", "]];
    return str;
}

- (IJSVGCommand*)commandByConvertingToUnits:(IJSVGUnitType)unitType
                                boundingBox:(CGRect)boundingBox
{
    IJSVGCommand* copy = self.copy;
    [copy convertToUnits:unitType
             boundingBox:boundingBox];
    return copy;
}

@end
