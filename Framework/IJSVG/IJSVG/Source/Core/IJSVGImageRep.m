//
//  IJSVGImageRep.m
//  IJSVGExample
//
//  Created by Curtis Hard on 15/03/2019.
//  Copyright © 2019 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVG.h>
#import <IJSVG/IJSVGImageRep.h>

@implementation IJSVGImageRep

+ (void)load
{
    [NSBitmapImageRep registerImageRepClass:self];
}

+ (BOOL)canInitWithData:(NSData*)data
{
    return [IJSVGParser isDataSVG:data];
}

+ (NSArray<NSString*>*)imageTypes
{
    if(@available(macOS 10.10, *)) {
        return @[ (NSString*)kUTTypeScalableVectorGraphics, @"svg" ];
    } else {
        return @[ @"public.svg-image", @"svg" ];
    }
}

+ (NSArray<NSString*>*)imageUnfilteredTypes
{
    if(@available(macOS 10.10, *)) {
        return @[ (NSString*)kUTTypeScalableVectorGraphics, @"svg" ];
    } else {
        return @[ @"public.svg-image", @"svg" ];
    }
}

+ (NSArray<NSImageRep*>*)imageRepsWithData:(NSData*)data
{
    IJSVGImageRep* instance = [self imageRepWithData:data];
    if(instance == nil) {
        return @[];
    }
    return @[ instance ];
}

+ (instancetype)imageRepWithData:(NSData*)data
{
    return [[self alloc] initWithData:data];
}

- (instancetype)initWithData:(NSData*)data
{
    if((self = [super init]) != nil) {
        // grab the string from the data
        // its more then likely UTF-8...
        NSString* string = [[NSString alloc] initWithData:data
                                                 encoding:NSUTF8StringEncoding];

        _svg = [[IJSVG alloc] initWithSVGString:string];

        // no valid SVG, just return nil;
        if(_svg == nil) {
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

- (IJSVG*)SVG
{
    return _svg;
}

@end
