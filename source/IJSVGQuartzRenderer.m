//
//  IJSVGRenderer.m
//  IJSVGExample
//
//  Created by Curtis Hard on 31/01/2018.
//  Copyright © 2018 Curtis Hard. All rights reserved.
//

#import "IJSVGQuartzRenderer.h"
#import "IJSVG.h"
#import "IJSVGLayerTree.h"
#import "IJSVGGradientLayer.h"
#import "IJSVGStrokeLayer.h"

@implementation IJSVGQuartzRenderer

@synthesize scale, viewPort, backingScale;


- (void)renderLayer:(IJSVGLayer *)layer
          inContext:(CGContextRef)ctx
{
    // if layer is hidden, no need to continue
    // trying to render it, its useless!
    if(layer.hidden == YES) {
        return;
    }
    
    // check which layers can actually be rendered
    if(layer.class == IJSVGStrokeLayer.class ||
       layer.class == IJSVGGradientLayer.class) {
        return;
    }
    
    CGContextSaveGState(ctx);
    
    // apply any transfroms so children also transform too
    CGContextConcatCTM(ctx, layer.affineTransform);
    CGContextSetAlpha(ctx, layer.opacity);
    
    // is there a mask?!
    if(layer.mask != nil) {
        IJSVGLayer * maskLayer = (IJSVGLayer *)layer.mask;
        CGRect rect;
        CGImageRef maskImage = [self newMaskedImageForLayer:maskLayer
                                               proposedRect:&rect];
        CGRect maskRect = CGRectMake(0, 0, rect.size.width, rect.size.height);
        CGContextClipToMask(ctx, maskRect, maskImage);
        CGContextTranslateCTM(ctx, rect.origin.x, rect.origin.y);
        CGImageRelease(maskImage);
    }
    
    // render itself
    [self _renderLayer:layer
             inContext:ctx];
    
    // render the children recursively
    for(IJSVGLayer * sublayer in layer.sublayers) {
        [self renderLayer:sublayer
                inContext:ctx];
    }
    CGContextRestoreGState(ctx);
}

- (void)_renderLayer:(IJSVGLayer *)layer
           inContext:(CGContextRef)ctx
{
    // is a shape layer
    if(layer.class == IJSVGShapeLayer.class) {
        // move the path
        CGContextTranslateCTM(ctx, layer.frame.origin.x,
                              layer.frame.origin.y);
        
        // find the shape
        IJSVGShapeLayer * shape = (IJSVGShapeLayer *)layer;
        CGPathRef path = shape.path;
        
        // has just a plain fill color
        CGContextSaveGState(ctx); {
            
            CGContextAddPath(ctx, path);
            if([shape.fillRule isEqualToString:kCAFillRuleEvenOdd]) {
                CGContextEOClip(ctx);
            } else {
                CGContextClip(ctx);
            }
            
            CGContextAddPath(ctx, path);
            if(shape.gradientFillLayer == nil) {
                if(shape.fillColor != nil) {
                    CGContextSetFillColorWithColor(ctx, shape.fillColor);
                    CGContextFillPath(ctx);
                }
            // has a gradient fill
            } else if(shape.gradientFillLayer != nil) {
                CGContextSaveGState(ctx); {
                    CGContextSetAlpha(ctx, shape.gradientFillLayer.opacity);
                    [shape.gradientFillLayer drawInContext:ctx];
                } CGContextRestoreGState(ctx);
            }
        } CGContextRestoreGState(ctx);
        
        // stroke must be done outside of the fill due to
        // clipping path will cause it to render incorrectly
        CGContextSaveGState(ctx); {
            
            // any stroke?
            if(shape.strokeLayer != nil) {
                IJSVGStrokeLayer * strokeLayer = (IJSVGStrokeLayer *)shape.strokeLayer;
                if(strokeLayer.strokeColor != nil) {
                    CGContextSaveGState(ctx); {
                        
                        // set opacity
                        CGContextSetAlpha(ctx, strokeLayer.opacity);
                        
                        CGContextSetLineCap(ctx, [self.class lineCapFromLayer:strokeLayer]);
                        CGContextSetLineJoin(ctx, [self.class lineJoinFromLayer:strokeLayer]);
                        
                        // are there any line dashes?
                        NSArray * dash = strokeLayer.lineDashPattern;
                        CGFloat * lengths = (CGFloat *)malloc(sizeof(CGFloat)*dash.count);
                        NSInteger i = 0;
                        for(NSNumber * number in dash) {
                            lengths[i++] = number.floatValue;
                        }
                        CGContextSetLineDash(ctx, strokeLayer.lineDashPhase,
                                             lengths, dash.count);
                        free(lengths);
                        
                        // get bounding box of the current path
                        CGContextAddPath(ctx, strokeLayer.path);
                        CGContextSetLineWidth(ctx, strokeLayer.lineWidth);
                        CGContextSetStrokeColorWithColor(ctx, strokeLayer.strokeColor);
                        CGContextStrokePath(ctx);
                        
                    } CGContextRestoreGState(ctx);
                }
            } else {
                CGContextSetLineWidth(ctx, 0.f);
                CGContextStrokePath(ctx);
            }
        
        } CGContextRestoreGState(ctx);
        
    }
}

+ (CGLineJoin)lineJoinFromLayer:(IJSVGShapeLayer *)layer
{
    if([layer.lineJoin isEqualToString:kCALineJoinBevel]) {
        return kCGLineJoinBevel;
    } else if([layer.lineJoin isEqualToString:kCALineJoinMiter]) {
        return kCGLineJoinMiter;
    }
    return kCGLineJoinRound;
}

+ (CGLineCap)lineCapFromLayer:(IJSVGShapeLayer *)layer
{
    if([layer.lineCap isEqualToString:kCALineCapButt]) {
        return kCGLineCapButt;
    } else if([layer.lineCap isEqualToString:kCALineCapRound]) {
        return kCGLineCapRound;
    }
    return kCGLineCapSquare;
}

+ (CGRect)findFrameForLayer:(IJSVGLayer *)layer
{
    CGRect rect = layer.frame;
    return [self _recursivelyFindFrameForLayer:layer
                                          rect:rect];
}

+ (CGRect)_recursivelyFindFrameForLayer:(IJSVGLayer *)layer
                                   rect:(CGRect)rect
{
    CGRect frame = layer.frame;
    if(CGRectGetMinX(frame) < CGRectGetMinX(rect)) {
        rect.origin.x = CGRectGetMinX(frame);
    }
    if(CGRectGetMinY(frame) < CGRectGetMinY(rect)) {
        rect.origin.y = CGRectGetMinY(frame);
    }
    if(CGRectGetMaxX(frame) > CGRectGetMaxX(rect)) {
        rect.size.width = CGRectGetMaxX(frame);
    }
    if(CGRectGetMaxY(frame) > CGRectGetMaxY(rect)) {
        rect.size.height = CGRectGetMaxY(frame);
    }
    for(IJSVGLayer * sublayer in layer.sublayers) {
        rect = [self _recursivelyFindFrameForLayer:sublayer
                                              rect:rect];
    }
    return rect;
}

- (CGRect)convertLayerFrame:(CGRect)rect
{
    rect.size.width = fabs(rect.origin.x - rect.size.width);
    rect.size.height = fabs(rect.origin.y - rect.size.height);
    rect.origin.x = rect.origin.y = 0.f;
    return rect;
}

- (CGImageRef)newImageForLayer:(IJSVGLayer *)layer
                    colorSpace:(CGColorSpaceRef)colorSpace
                  proposedRect:(CGRect *)proposedRect
{
    // create color space and new context
    NSRect cRect = [self.class findFrameForLayer:layer];
    NSRect convertedSize = [self convertLayerFrame:cRect];
    CGSize size = cRect.size;
    *proposedRect = cRect;
    CGFloat actualScale = self.scale * self.backingScale;
    CGContextRef ctx = CGBitmapContextCreate(NULL, size.width * actualScale,
                                             size.height * actualScale,
                                             8, 0, colorSpace,
                                             kCGImageAlphaPremultipliedLast);
    
    CGContextScaleCTM(ctx, actualScale, actualScale);
    
    // render the layer tree into this context
    [self renderLayer:layer
            inContext:ctx];
    
    // grab image from it
    CGImageRef image = CGBitmapContextCreateImage(ctx);
    
    // clean memory
    CGContextRelease(ctx);
    return image;
}

- (CGImageRef)newMaskedImageForLayer:(IJSVGLayer *)layer
                        proposedRect:(CGRect *)proposedRect
{
    // create color space and new context
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceGray();
    CGImageRef image = [self newImageForLayer:layer
                                   colorSpace:colorSpace
                                 proposedRect:proposedRect];
    CGColorSpaceRelease(colorSpace);
    return image;
}

@end
