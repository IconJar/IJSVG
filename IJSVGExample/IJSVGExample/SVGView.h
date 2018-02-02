//
//  SVGView.h
//  IJSVGExample
//
//  Created by Curtis Hard on 02/09/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "IJSVG.h"

@interface SVGView : NSView {
 
    IJSVG * svg;
    
}

- (IBAction)switchToCoreGraphics:(id)sender;
- (IBAction)switchToCoreAnimation:(id)sender;

@end
