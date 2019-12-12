//
//  IJSVGView.h
//  IconJar
//
//  Created by Curtis Hard on 04/04/2017.
//  Copyright © 2017 Curtis Hard. All rights reserved.
//

#import "IJSVG.h"
#import <Cocoa/Cocoa.h>

IB_DESIGNABLE
@interface IJSVGView : NSView {
    IBInspectable NSString* imageName;
    IBInspectable NSColor* tintColor;

    IJSVG* SVG;
}

@property (nonatomic, retain) IJSVG* SVG;

+ (IJSVGView*)viewWithSVGNamed:(NSString*)name;
- (id)initWithSVG:(IJSVG*)anSvg;

@end