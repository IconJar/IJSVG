//
//  IJSVGImageRep.m
//  IJSVGExample
//
//  Created by Curtis Hard on 15/03/2019.
//  Copyright © 2019 Curtis Hard. All rights reserved.
//

#import "IJSVGImageRep.h"
#import "IJSVG.h"

@implementation IJSVGImageRep

@synthesize viewBox = _viewBox;

+ (void)load
{
    [NSBitmapImageRep registerImageRepClass:self];
}

+ (BOOL)canInitWithData:(NSData *)data
{
    return [IJSVGParser isDataSVG:data];
}

+ (NSArray<NSString *> *)imageTypes
{
    return @[(NSString *)kUTTypeScalableVectorGraphics, @"svg"];
}

+ (NSArray<NSString *> *)imageUnfilteredTypes
{
    return @[(NSString *)kUTTypeScalableVectorGraphics, @"svg"];
}

+ (NSArray<NSImageRep *> *)imageRepsWithData:(NSData *)data
{
    IJSVGImageRep * instance = [self imageRepWithData:data];
    if(instance == nil) {
        return @[];
    }
    return @[instance];
}

+ (instancetype)imageRepWithData:(NSData *)data
{
    return [[self alloc] initWithData:data];
}

- (void)dealloc
{
    [_svg release], _svg = nil;
    [super dealloc];
}

- (instancetype)initWithData:(NSData *)data
{
    if((self = [super init]) != nil) {
        // grab the string from the data
        // its more then likely UTF-8...
        NSString * string = [[[NSString alloc] initWithData:data
                                                   encoding:NSUTF8StringEncoding] autorelease];
        
        _svg = [[IJSVG alloc] initWithSVGString:string];
        
        // no valid SVG, just return nil;
        if(_svg == nil) {
            [self release];
            return nil;
        }
        
        // set default properties
        self.pixelsWide = _svg.viewBox.size.width;
        self.pixelsHigh = _svg.viewBox.size.height;
        self.size = _svg.viewBox.size;
    }
    return self;
}

- (BOOL)draw
{
    [_svg drawInRect:self.viewBox];
    return YES;
}

- (BOOL)drawAtPoint:(NSPoint)point
{
    [_svg drawAtPoint:point
                 size:_svg.viewBox.size];
    return YES;
}

- (BOOL)drawInRect:(NSRect)rect
{
    [_svg drawInRect:rect];
    return YES;
}

- (CGRect)viewBox
{
    return _svg.viewBox;
}

@end
