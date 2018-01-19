//
//  IJSVGFontConverter.h
//  IJSVGExample
//
//  Created by Curtis Hard on 21/05/2015.
//  Copyright (c) 2015 Curtis Hard. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "IJSVG.h"

@interface IJSVGFontConverter : NSObject {
    
@private
    NSURL * _url;
    NSFont * _font;
    NSMutableDictionary * _svgs;
}

- (id)initWithFontAtFileURL:(NSURL *)url;
- (NSDictionary<NSString *, IJSVG *> *)SVGs;
- (NSFont *)font;

+ (IJSVG *)convertPathToSVG:(CGPathRef)path;

@end
