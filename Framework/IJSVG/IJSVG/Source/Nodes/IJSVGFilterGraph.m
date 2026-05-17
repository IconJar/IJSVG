//
//  IJSVGFilterGraph.m
//  IJSVG
//

#import <IJSVG/IJSVGFilterGraph.h>

@implementation IJSVGFilterGraph {
    NSMutableDictionary<NSString*, CIImage*>* _buffers;
    CIImage* _lastResult;
}

- (instancetype)initWithSourceGraphic:(CIImage*)sourceGraphic scale:(CGFloat)scale
{
    if((self = [super init]) != nil) {
        _sourceBounds = sourceGraphic.extent;
        _scale = scale;
        _buffers = [NSMutableDictionary dictionary];
        _buffers[@"SourceGraphic"] = sourceGraphic;
        _buffers[@"SourceAlpha"] = [self extractAlphaFromImage:sourceGraphic];
        _lastResult = sourceGraphic;
    }
    return self;
}

- (CIImage*)extractAlphaFromImage:(CIImage*)image
{
    CIFilter* colorMatrix = [CIFilter filterWithName:@"CIColorMatrix"];
    [colorMatrix setDefaults];
    [colorMatrix setValue:image forKey:kCIInputImageKey];
    [colorMatrix setValue:[CIVector vectorWithX:0 Y:0 Z:0 W:0] forKey:@"inputRVector"];
    [colorMatrix setValue:[CIVector vectorWithX:0 Y:0 Z:0 W:0] forKey:@"inputGVector"];
    [colorMatrix setValue:[CIVector vectorWithX:0 Y:0 Z:0 W:0] forKey:@"inputBVector"];
    [colorMatrix setValue:[CIVector vectorWithX:0 Y:0 Z:0 W:1] forKey:@"inputAVector"];
    [colorMatrix setValue:[CIVector vectorWithX:0 Y:0 Z:0 W:0] forKey:@"inputBiasVector"];
    return [colorMatrix valueForKey:kCIOutputImageKey];
}

- (CIImage*)imageForInput:(NSString*)inputName
{
    if(inputName == nil || inputName.length == 0) {
        return _lastResult;
    }
    NSString* lower = inputName.lowercaseString;
    if([lower isEqualToString:@"sourcegraphic"]) {
        return _buffers[@"SourceGraphic"];
    }
    if([lower isEqualToString:@"sourcealpha"]) {
        return _buffers[@"SourceAlpha"];
    }
    CIImage* result = _buffers[inputName];
    if(result != nil) {
        return result;
    }
    return _lastResult;
}

- (void)setImage:(CIImage*)image forResult:(NSString*)resultName
{
    _lastResult = image;
    if(resultName != nil && resultName.length > 0) {
        _buffers[resultName] = image;
    }
}

- (CIImage*)lastResult
{
    return _lastResult;
}

@end
