//
//  IJSVGColorType.h
//  IJSVG
//
//  Created by Curtis Hard on 20/04/2021.
//  Copyright © 2021 Curtis Hard. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

typedef NS_OPTIONS(NSInteger, IJSVGColorTypeMask) {
    IJSVGColorTypeMaskUnknown,
    IJSVGColorTypeMaskFill,
    IJSVGColorTypeMaskStroke,
    IJSVGColorTypeMaskStop
};

@interface IJSVGColorType : NSObject {
    
}

@property (nonatomic, retain) NSColor* color;
@property (nonatomic, assign) IJSVGColorTypeMask mask;

+ (IJSVGColorType*)typeWithColor:(NSColor*)color
                            mask:(IJSVGColorTypeMask)mask;

@end
