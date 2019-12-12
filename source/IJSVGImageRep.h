//
//  IJSVGImageRep.h
//  IJSVGExample
//
//  Created by Curtis Hard on 15/03/2019.
//  Copyright © 2019 Curtis Hard. All rights reserved.
//

#import "IJSVGParser.h"
#import <Cocoa/Cocoa.h>

@class IJSVG;

@interface IJSVGImageRep : NSImageRep {

@private
    IJSVG* _svg;
}

@property (nonatomic, readonly) CGRect viewBox;

@end
