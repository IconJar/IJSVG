//
//  IJSVGColorType.h
//  IJSVG
//
//  Created by Curtis Hard on 20/04/2021.
//  Copyright © 2021 Curtis Hard. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

typedef NS_OPTIONS(NSInteger, IJSVGColorUsageTraits) {
    IJSVGColorUsageTraitNone = 0,
    IJSVGColorUsageTraitUnknown = 1 << 0,
    IJSVGColorUsageTraitFill = 1 << 1,
    IJSVGColorUsageTraitStroke = 1 << 2,
    IJSVGColorUsageTraitGradientStop = 1 << 3,
    IJSVGColorUsageTraitAll = IJSVGColorUsageTraitFill | IJSVGColorUsageTraitGradientStop |
        IJSVGColorUsageTraitStroke
};

@interface IJSVGTraitedColor : NSObject {
    
}

@property (nonatomic, strong) NSColor* color;
@property (nonatomic, assign) IJSVGColorUsageTraits traits;

+ (IJSVGTraitedColor*)typeWithColor:(NSColor*)color
                          traits:(IJSVGColorUsageTraits)mask;

@end
