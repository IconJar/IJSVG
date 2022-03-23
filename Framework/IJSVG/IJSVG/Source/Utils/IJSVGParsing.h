//
//  IJSVGParsing.h
//  IJSVG
//
//  Created by Curtis Hard on 04/02/2021.
//  Copyright © 2021 Curtis Hard. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef struct {
    char* name;
    char* parameters;
} IJSVGParsingStringMethod;

IJSVGParsingStringMethod* IJSVGParsingStringMethodCreate(void);
void IJSVGParsingStringMethodRelease(IJSVGParsingStringMethod* stringMethod);
IJSVGParsingStringMethod** IJSVGParsingMethodParseString(const char* string,
                                                         NSUInteger* count);
void IJSVGParsingStringMethodsRelease(IJSVGParsingStringMethod** methods,
                                      NSUInteger count);

@interface IJSVGParsing : NSObject

@end
