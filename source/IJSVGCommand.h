//
//  IJSVGCommand.h
//  IconJar
//
//  Created by Curtis Hard on 30/08/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "IJSVGPath.h"

typedef NS_ENUM( NSInteger, IJSVGCommandType ) {
    IJSVGCommandTypeAbsolute,
    IJSVGCommandTypeRelative
};

@class IJSVGCommand;

@protocol IJSVGCommandProtocol <NSObject>

@required
+ (void)runWithParams:(CGFloat *)params
           paramCount:(NSInteger)count
              command:(IJSVGCommand *)currentCommand
      previousCommand:(IJSVGCommand *)command
                 type:(IJSVGCommandType)type
                 path:(IJSVGPath *)path;

+ (NSInteger)requiredParameterCount;

@end

@interface IJSVGCommand : NSObject {
    NSString * commandString;
    NSString * command;
    CGFloat * parameters;
    NSInteger parameterCount;
    NSMutableArray * subCommands;
    NSInteger requiredParameters;
    IJSVGCommandType type;
    IJSVGCommand * previousCommand;
    NSInteger _currentIndex;
    Class<IJSVGCommandProtocol> commandClass;
    BOOL isSubCommand;
}

@property ( nonatomic, copy ) NSString * commandString;
@property ( nonatomic, copy ) NSString * command;
@property ( nonatomic, assign ) CGFloat * parameters;
@property ( nonatomic, assign ) NSInteger parameterCount;
@property ( nonatomic, assign ) NSInteger requiredParameters;
@property ( nonatomic, assign ) IJSVGCommandType type;
@property ( nonatomic, retain ) NSMutableArray * subCommands;
@property ( nonatomic, assign ) Class<IJSVGCommandProtocol> commandClass;
@property ( nonatomic, assign ) IJSVGCommand * previousCommand;
@property ( nonatomic, assign ) BOOL isSubCommand;

- (id)initWithCommandString:(NSString *)commandString;

+ (NSPoint)readCoordinatePair:(CGFloat *)pairs
                        index:(NSInteger)index;

+ (void)registerClass:(Class)aClass
           forCommand:(NSString *)command;
+ (NSDictionary *)registeredCommandClasses;
+ (Class<IJSVGCommandProtocol>)commandClassForCommandLetter:(NSString *)str;

- (CGFloat)readFloat;
- (NSPoint)readPoint;
- (BOOL)readBOOL;
- (void)resetRead;

@end
