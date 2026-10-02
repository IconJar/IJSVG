//
//  IJSVGError.h
//  IJSVG
//
//  Created by Curtis Hard on 16/09/2015.
//  Copyright © 2015 Curtis Hard. All rights reserved.
//

#import <Foundation/Foundation.h>

static NSString* const IJSVGErrorDomain = @"IJSVGErrorDomain";

NS_ENUM(NSInteger){
    IJSVGErrorReadingFile,
    IJSVGErrorParsingFile,
    IJSVGErrorParsingSVG,
    IJSVGErrorDrawing,
    IJSVGErrorInvalidViewBox
};
