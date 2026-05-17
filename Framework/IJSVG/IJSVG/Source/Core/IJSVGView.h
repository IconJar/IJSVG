//
//  IJSVGView.h
//  IconJar
//
//  Created by Curtis Hard on 04/04/2017.
//  Copyright © 2017 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVG.h>
#import <Foundation/Foundation.h>

IB_DESIGNABLE
@interface IJSVGView : NSView {
    IBInspectable NSString* imageName;
    IBInspectable NSColor* tintColor;

    IJSVG* SVG;
}

@property (nonatomic, strong) IJSVG* SVG;

+ (IJSVGView*)viewWithSVGNamed:(NSString*)name;
- (id)initWithSVG:(IJSVG*)anSvg;

@end
