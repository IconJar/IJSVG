//
//  IJSVGCommand.m
//  IconJar
//
//  Created by Curtis Hard on 30/08/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import "IJSVGCommand.h"
#import "IJSVGUtils.h"

#import "IJSVGCommandClose.h"
#import "IJSVGCommandCurve.h"
#import "IJSVGCommandEllipticalArc.h"
#import "IJSVGCommandHorizontalLine.h"
#import "IJSVGCommandLineTo.h"
#import "IJSVGCommandMove.h"
#import "IJSVGCommandQuadraticCurve.h"
#import "IJSVGCommandSmoothCurve.h"
#import "IJSVGCommandSmoothQuadraticCurve.h"
#import "IJSVGCommandVerticalLine.h"

@implementation IJSVGCommand

@synthesize commandString;
@synthesize command;
@synthesize parameterCount;
@synthesize parameters;
@synthesize subCommands;
@synthesize requiredParameters;
@synthesize type;
@synthesize previousCommand;
@synthesize isSubCommand;

+ (BOOL)requiresCustomParameterParsing
{
    return NO;
}

+ (NSInteger)requiredParameterCount
{
    return 1;
}

+ (void)runWithParams:(CGFloat*)params
           paramCount:(NSInteger)count
              command:(IJSVGCommand*)currentCommand
      previousCommand:(IJSVGCommand*)command
                 type:(IJSVGCommandType)type
                 path:(IJSVGPath*)path
{
}

+ (void)parseParams:(CGFloat*)params
         paramCount:(NSInteger)paramCount
          intoArray:(NSMutableArray<IJSVGCommand*>*)commands
      parentCommand:(IJSVGCommand*)parentCommand
{
}

+ (NSPoint)readCoordinatePair:(CGFloat*)pairs
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
    aChar = tolower(aChar);
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

- (void)dealloc
{
    (void)([commandString release]), commandString = nil;
    (void)([command release]), command = nil;
    (void)([subCommands release]), subCommands = nil;
    (void)(free(parameters)), parameters = nil;
    [super dealloc];
}

- (id)initWithCommandString:(NSString*)str
{
    if ((self = [super init]) != nil) {
        // work out the basics
        _currentIndex = 0;
        command = [[str substringToIndex:1] copy];
        type = [IJSVGUtils typeForCommandString:self.command];
        parameters = [IJSVGUtils commandParameters:str
                                             count:&parameterCount];
        requiredParameters = [self.class requiredParameterCount];

        // check what required params we need
        if (requiredParameters == IJSVGCustomVariableParameterCount) {
            // looks like we require variable params
            NSMutableArray<IJSVGCommand*>* subCommandArray = [[NSMutableArray alloc] init];
            // parse the custom params
            [self.class parseParams:parameters
                         paramCount:parameterCount
                          intoArray:subCommandArray
                      parentCommand:self];
            subCommands = [subCommandArray.copy autorelease];
        } else {
            // now work out the sets of parameters we have
            // each command could have a series of subcommands
            // if there is a multiple of commands in a command
            // then we need to work those out...
            NSInteger sets = 1;
            if (self.requiredParameters != 0) {
                sets = (self.parameterCount / self.requiredParameters);
            }

            if (sets == 1) {
                CGFloat* subParams = [self parametersFromIndexOffset:0];
                IJSVGCommand* command = [self subcommandWithParameters:subParams
                                                       previousCommand:nil];
                subCommands = @[ command ].retain;
            } else {

                NSMutableArray<IJSVGCommand*>* subCommandArray = nil;
                subCommandArray = [[NSMutableArray alloc] initWithCapacity:sets].autorelease;

                // interate over the sets
                IJSVGCommand* lastCommand = nil;
                for (NSInteger i = 0; i < sets; i++) {
                    // memory for this will be handled by the created subcommand
                    CGFloat* subParams = [self parametersFromIndexOffset:i];

                    // generate the subcommand
                    IJSVGCommand* command = [self subcommandWithParameters:subParams
                                                           previousCommand:lastCommand];

                    // make sure we assign the last command or hell breaks
                    // lose and the firey demons will run wild, namely, commands will break
                    // if they are multiples of a set
                    lastCommand = command;
                    [subCommandArray addObject:command];
                }

                // store the retained value
                subCommands = subCommandArray.copy;
            }
        }
    }
    return self;
}

- (CGFloat*)parametersFromIndexOffset:(NSInteger)index
{
    CGFloat* subParams = 0;
    NSInteger req = self.requiredParameters;
    if (req != 0) {
        subParams = (CGFloat*)malloc(req * sizeof(CGFloat));
        memcpy(subParams, &self.parameters[index * req], sizeof(CGFloat) * req);
    }
    return subParams;
}

- (IJSVGCommand*)subcommandWithParameters:(CGFloat*)subParams
                          previousCommand:(IJSVGCommand*)aPreviousCommand
{
    // create a subcommand per set
    IJSVGCommand* c = [[[self.class alloc] init] autorelease];
    c.parameterCount = self.requiredParameters;
    c.parameters = subParams;
    c.type = self.type;
    c.command = self.command;
    c.previousCommand = aPreviousCommand;
    c.isSubCommand = aPreviousCommand != nil;
    return c;
}

- (CGFloat)readFloat
{
    CGFloat f = parameters[_currentIndex];
    _currentIndex++;
    return f;
}

- (NSPoint)readPoint
{
    CGFloat x = parameters[_currentIndex];
    CGFloat y = parameters[_currentIndex + 1];
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

@end
