//
//  IJSVGImage.h
//  IconJar
//
//  Created by Curtis Hard on 30/08/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "IJSVGParser.h"
#import "IJSVGBezierPathAdditions.h"

@interface IJSVG : NSObject {
    
@private
    IJSVGParser * _group;
    CGFloat _scale;
    NSMutableArray * _colors;
    
}

+ (NSColor *)baseColor;
+ (void)setBaseColor:(NSColor *)color;

- (id)initWithFile:(NSString *)file;
- (id)initWithFilePathURL:(NSURL *)aURL;
- (NSImage *)imageWithSize:(NSSize)aSize;
- (void)drawAtPoint:(NSPoint)point
               size:(NSSize)size;
- (void)drawInRect:(NSRect)rect;
- (NSArray *)colors;

@end
