//
//  IJSVGFilterEffectFlood.m
//  IJSVG
//

#import <IJSVG/IJSVGFilterEffectFlood.h>
#import <IJSVG/IJSVGFilterGraph.h>
#import <IJSVG/IJSVGColor.h>

@implementation IJSVGFilterEffectFlood

- (instancetype)init
{
    if((self = [super init]) != nil) {
        _floodColor = NSColor.blackColor;
        _floodOpacity = 1.0;
    }
    return self;
}

- (void)parseEffectAttributes:(NSDictionary<NSString*, NSString*>*)attributes
{
    NSString* colorStr = attributes[@"flood-color"];
    if(colorStr != nil) {
        _floodColor = [IJSVGColor colorFromString:colorStr];
        if(_floodColor == nil) {
            _floodColor = NSColor.blackColor;
        }
    }
    NSString* opacityStr = attributes[@"flood-opacity"];
    if(opacityStr != nil) {
        _floodOpacity = opacityStr.doubleValue;
    }
}

- (CIImage*)processWithGraph:(IJSVGFilterGraph*)graph
{
    CGFloat r = 0.f;
    CGFloat g = 0.f;
    CGFloat b = 0.f;
    CGFloat a = 0.f;
    NSColor* color = [IJSVGColor computeColorSpace:_floodColor];
    IJSVGColorGetRGBAComponents(color, &r, &g, &b, &a);
    a *= _floodOpacity;

    CIColor* ciColor = [CIColor colorWithRed:r green:g blue:b alpha:a];
    CIImage* flood = [CIImage imageWithColor:ciColor];
    CIImage* output = [flood imageByCroppingToRect:graph.sourceBounds];
    [graph setImage:output forResult:self.resultName];
    return output;
}

@end
