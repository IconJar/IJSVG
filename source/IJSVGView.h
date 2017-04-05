//
//  IJSVGView.h
//  IconJar
//
//  Created by Curtis Hard on 04/04/2017.
//  Copyright © 2017 Curtis Hard. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "IJSVG.h"

IB_DESIGNABLE
@interface IJSVGView : NSView {
    
    IBInspectable NSString * imageName;
    IJSVG * SVG;  
    
}

@property (nonatomic, retain) IJSVG * SVG;

+ (IJSVGView *)viewWithSVGNamed:(NSString *)name;
- (id)initWithSVG:(IJSVG *)anSvg;

@end
