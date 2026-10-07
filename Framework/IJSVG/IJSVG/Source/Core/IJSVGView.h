//
//  IJSVGView.h
//  IJSVG
//
//  Created by Curtis Hard on 04/04/2017.
//  Copyright © 2017 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVG.h>
#import <IJSVG/IJSVGXEntities.h>

NS_ASSUME_NONNULL_BEGIN

IB_DESIGNABLE
@interface IJSVGView : XView {
    IBInspectable NSString* imageName;
    IBInspectable XColor* tintColor;

    IJSVG* SVG;
}

@property (nonatomic, strong, nullable) IJSVG* SVG;

+ (IJSVGView*)viewWithSVGNamed:(NSString*)name;
- (instancetype)initWithSVG:(IJSVG* _Nullable)anSvg;

@end

NS_ASSUME_NONNULL_END
