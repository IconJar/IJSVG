//
//  IJSVGImageRep.h
//  IJSVG
//
//  Created by Curtis Hard on 15/03/2019.
//  Copyright © 2019 Curtis Hard. All rights reserved.
//

#if __has_include(<Cocoa/Cocoa.h>)
#import <IJSVG/IJSVGParser.h>
#import <Cocoa/Cocoa.h>

@class IJSVG;

@interface IJSVGImageRep : XImageRep {

@private
    IJSVG* _svg;
}

- (instancetype)initWithData:(NSData*)data;

@property (nonatomic, readonly) CGRect viewBox;
@property (nonatomic, readonly) IJSVG* SVG;

@end
#endif
