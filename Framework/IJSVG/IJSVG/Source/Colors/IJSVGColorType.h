//
//  IJSVGColorType.h
//  IJSVG
//
//  Created by Curtis Hard on 20/04/2021.
//  Copyright © 2021 Curtis Hard. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

typedef NS_OPTIONS(NSInteger, IJSVGColorTypeFlags) {
    IJSVGColorTypeNone = 0,
    IJSVGColorTypeFlagUnknown = 1 << 0,
    IJSVGColorTypeFlagFill = 1 << 1,
    IJSVGColorTypeFlagStroke = 1 << 2,
    IJSVGColorTypeFlagStop = 1 << 3,
    IJSVGColorTypeFlagAll = IJSVGColorTypeFlagFill | IJSVGColorTypeFlagStop |
        IJSVGColorTypeFlagStroke
};

@interface IJSVGColorType : NSObject {
    
}

@property (nonatomic, strong) NSColor* color;
@property (nonatomic, assign) IJSVGColorTypeFlags flags;

+ (IJSVGColorType*)typeWithColor:(NSColor*)color
                           flags:(IJSVGColorTypeFlags)mask;

@end
