//
//  IJSVGImageRep.h
//  IJSVGExample
//
//  Created by Curtis Hard on 15/03/2019.
//  Copyright © 2019 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGParser.h>
#import <Foundation/Foundation.h>

@class IJSVG;

#if TARGET_OS_IOS
@interface IJSVGImageRep : NSObject {
#else
@interface IJSVGImageRep : NSImageRep {
#endif

@private
    IJSVG* _svg;
}

- (instancetype)initWithData:(NSData*)data;

@property (nonatomic, readonly) CGRect viewBox;
@property (nonatomic, readonly) IJSVG* SVG;

@end
