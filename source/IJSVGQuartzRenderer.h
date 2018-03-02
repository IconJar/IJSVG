//
//  IJSVGRenderer.h
//  IJSVGExample
//
//  Created by Curtis Hard on 31/01/2018.
//  Copyright © 2018 Curtis Hard. All rights reserved.
//

#import <Foundation/Foundation.h>

@class IJSVGLayer;

@interface IJSVGQuartzRenderer : NSObject {
    
}

@property (nonatomic, assign) CGFloat scale;
@property (nonatomic, assign) CGFloat backingScale;
@property (nonatomic, assign) CGRect viewPort;

- (void)renderLayer:(IJSVGLayer *)layer
          inContext:(CGContextRef)context;

@end
