//
//  IJSVGFilterEffectBlend.m
//  IJSVG
//

#import <IJSVG/IJSVGFilterEffectBlend.h>
#import <IJSVG/IJSVGFilterGraph.h>

@implementation IJSVGFilterEffectBlend

- (void)parseEffectAttributes:(NSDictionary<NSString*, NSString*>*)attributes
{
    NSString* mode = attributes[@"mode"];
    if(mode != nil) {
        NSString* lower = mode.lowercaseString;
        if([lower isEqualToString:@"multiply"]) _filterBlendMode = IJSVGFilterBlendModeMultiply;
        else if([lower isEqualToString:@"screen"]) _filterBlendMode = IJSVGFilterBlendModeScreen;
        else if([lower isEqualToString:@"darken"]) _filterBlendMode = IJSVGFilterBlendModeDarken;
        else if([lower isEqualToString:@"lighten"]) _filterBlendMode = IJSVGFilterBlendModeLighten;
        else if([lower isEqualToString:@"overlay"]) _filterBlendMode = IJSVGFilterBlendModeOverlay;
    }
}

- (NSString*)ciFilterNameForBlendMode
{
    switch(_filterBlendMode) {
        case IJSVGFilterBlendModeNormal: return @"CISourceOverCompositing";
        case IJSVGFilterBlendModeMultiply: return @"CIMultiplyBlendMode";
        case IJSVGFilterBlendModeScreen: return @"CIScreenBlendMode";
        case IJSVGFilterBlendModeDarken: return @"CIDarkenBlendMode";
        case IJSVGFilterBlendModeLighten: return @"CILightenBlendMode";
        case IJSVGFilterBlendModeOverlay: return @"CIOverlayBlendMode";
    }
    return @"CISourceOverCompositing";
}

- (CIImage*)processWithGraph:(IJSVGFilterGraph*)graph
{
    CIImage* in1 = [graph imageForInput:self.inputName];
    CIImage* in2 = [graph imageForInput:self.inputName2];
    CIFilter* filter = [CIFilter filterWithName:[self ciFilterNameForBlendMode]];
    [filter setDefaults];
    [filter setValue:in1 forKey:kCIInputImageKey];
    [filter setValue:in2 forKey:kCIInputBackgroundImageKey];
    CIImage* output = [filter valueForKey:kCIOutputImageKey];
    [graph setImage:output forResult:self.resultName];
    return output;
}

@end
