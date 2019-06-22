//
//  IJSVGCommand.m
//  IconJar
//
//  Created by Curtis Hard on 30/08/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import "IJSVGCommand.h"
#import "IJSVGUtils.h"

#import "IJSVGCommandArc.h"
#import "IJSVGCommandMove.h"
#import "IJSVGCommandClose.h"
#import "IJSVGCommandCurve.h"
#import "IJSVGCommandLineTo.h"
#import "IJSVGCommandVerticalLine.h"
#import "IJSVGCommandHorizontalLine.h"
#import "IJSVGCommandSmoothCurve.h"
#import "IJSVGCommandQuadraticCurve.h"
#import "IJSVGCommandCommandSmoothQuadraticCurve.h"

@implementation IJSVGCommand

@synthesize commandString;
@synthesize command;
@synthesize parameterCount;
@synthesize parameters;
@synthesize subCommands;
@synthesize commandClass;
@synthesize requiredParameters;
@synthesize type;
@synthesize previousCommand;
@synthesize isSubCommand;

- (void)dealloc
{
    [commandString release], commandString = nil;
    [command release], command = nil;
    [subCommands release], subCommands = nil;
    free( parameters );
    [super dealloc];
}

- (id)initWithCommandString:(NSString *)str
{
    if( ( self = [super init] ) != nil )
    {
        // work out the basics
        _currentIndex = 0;
        command = [[str substringToIndex:1] copy];
        type = [IJSVGUtils typeForCommandString:self.command];
        commandClass = [self.class commandClassForCommandChar:[self.command characterAtIndex:0]];
        parameters = [IJSVGUtils commandParameters:str count:&parameterCount];
        requiredParameters = [self.commandClass requiredParameterCount];
        
        // now work out the sets of parameters we have
        // each command could have a series of subcommands
        // if there is a multiple of commands in a command
        // then we need to work those out...
        NSInteger sets = 1;
        if( self.requiredParameters != 0 ) {
            sets = self.parameterCount/self.requiredParameters;
        }
        
        subCommands = [[NSMutableArray alloc] initWithCapacity:sets];
        
        // interate over the sets
        for( NSInteger i = 0; i < sets; i++ ) {
            // memory for this will be handled by the created subcommand
            CGFloat * subParams = 0;
            if( self.requiredParameters != 0 ) {
                subParams = (CGFloat*)malloc(self.requiredParameters*sizeof(CGFloat));
                for( NSInteger p = 0; p < self.requiredParameters; p++ ) {
                    subParams[p] = self.parameters[i*self.requiredParameters+p];
                }
            }
            
            // create a subcommand per set
            IJSVGCommand * c = [[[self.class alloc] init] autorelease];
            c.parameterCount = self.requiredParameters;
            c.parameters = subParams;
            c.type = self.type;
            c.command = self.command;
            c.previousCommand = self.subCommands.lastObject;
            c.commandClass = self.commandClass;
            c.isSubCommand = i == 0 ? NO : YES;
            
            // add it to our tree
            [self.subCommands addObject:c];
        }
    }
    return self;
}

+ (NSPoint)readCoordinatePair:(CGFloat *)pairs
                        index:(NSInteger)index
{
    return NSMakePoint( pairs[index*2], pairs[index*2+1]);
}

+ (void)load
{
    // register here...
}

+ (Class<IJSVGCommandProtocol>)commandClassForCommandChar:(char)aChar
{
    aChar = tolower(aChar);
    switch(aChar) {
        case 'a': return IJSVGCommandArc.class;
        case 'c': return IJSVGCommandCurve.class;
        case 'h': return IJSVGCommandHorizontalLine.class;
        case 'l': return IJSVGCommandLineTo.class;
        case 'm': return IJSVGCommandMove.class;
        case 'q': return IJSVGCommandQuadraticCurve.class;
        case 's': return IJSVGCommandSmoothCurve.class;
        case 't': return IJSVGCommandCommandSmoothQuadraticCurve.class;
        case 'v': return IJSVGCommandVerticalLine.class;
        case 'z': return IJSVGCommandClose.class;
    }
    return nil;
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
    CGFloat y = parameters[_currentIndex+1];
    _currentIndex+=2;
    return NSMakePoint( x, y );
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
