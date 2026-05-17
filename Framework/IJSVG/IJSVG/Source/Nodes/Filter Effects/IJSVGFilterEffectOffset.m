//
//  IJSVGFilterEffectOffset.m
//  IJSVG
//

#import <IJSVG/IJSVGFilterEffectOffset.h>
#import <IJSVG/IJSVGFilterGraph.h>

@implementation IJSVGFilterEffectOffset

- (void)parseEffectAttributes:(NSDictionary<NSString*, NSString*>*)attributes
{
    NSString* dxStr = attributes[@"dx"];
    if(dxStr != nil) _dx = dxStr.doubleValue;
    NSString* dyStr = attributes[@"dy"];
    if(dyStr != nil) _dy = dyStr.doubleValue;
}

- (CIImage*)processWithGraph:(IJSVGFilterGraph*)graph
{
    CIImage* input = [graph imageForInput:self.inputName];
    CGFloat s = graph.scale;
    CIImage* output = [input imageByApplyingTransform:CGAffineTransformMakeTranslation(_dx * s, _dy * s)];
    [graph setImage:output forResult:self.resultName];
    return output;
}

@end
