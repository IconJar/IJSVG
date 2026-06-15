//
//  IJSVGFilterEffectColorMatrix.m
//  IJSVG
//

#import <IJSVG/IJSVGFilterEffectColorMatrix.h>
#import <IJSVG/IJSVGFilterGraph.h>

@implementation IJSVGFilterEffectColorMatrix

- (instancetype)init
{
    if((self = [super init]) != nil) {
        _matrixType = IJSVGColorMatrixTypeMatrix;
    }
    return self;
}

- (void)parseEffectAttributes:(NSDictionary<NSString*, NSString*>*)attributes
{
    NSString* typeStr = attributes[@"type"];
    if(typeStr != nil) {
        NSString* lower = typeStr.lowercaseString;
        if([lower isEqualToString:@"matrix"]) _matrixType = IJSVGColorMatrixTypeMatrix;
        else if([lower isEqualToString:@"saturate"]) _matrixType = IJSVGColorMatrixTypeSaturate;
        else if([lower isEqualToString:@"huerotate"]) _matrixType = IJSVGColorMatrixTypeHueRotate;
        else if([lower isEqualToString:@"luminancetoalpha"]) _matrixType = IJSVGColorMatrixTypeLuminanceToAlpha;
    }
    NSString* valuesStr = attributes[@"values"];
    if(valuesStr != nil) {
        NSMutableArray<NSNumber*>* values = [NSMutableArray array];
        NSArray* components = [valuesStr componentsSeparatedByCharactersInSet:
                               [NSCharacterSet characterSetWithCharactersInString:@" ,\t\n\r"]];
        for(NSString* comp in components) {
            NSString* trimmed = [comp stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
            if(trimmed.length > 0) [values addObject:@(trimmed.doubleValue)];
        }
        _matrixValues = values;
    }
}

- (CIImage*)processWithGraph:(IJSVGFilterGraph*)graph
{
    CIImage* input = [graph imageForInput:self.inputName];
    CIImage* output = nil;
    switch(_matrixType) {
        case IJSVGColorMatrixTypeMatrix: output = [self applyMatrix:input]; break;
        case IJSVGColorMatrixTypeSaturate: output = [self applySaturate:input]; break;
        case IJSVGColorMatrixTypeHueRotate: output = [self applyHueRotate:input]; break;
        case IJSVGColorMatrixTypeLuminanceToAlpha: output = [self applyLuminanceToAlpha:input]; break;
    }
    if(output == nil) output = input;
    [graph setImage:output forResult:self.resultName];
    return output;
}

- (CIImage*)applyColorMatrix:(CIImage*)input
                      rVector:(CIVector*)rVec gVector:(CIVector*)gVec
                      bVector:(CIVector*)bVec aVector:(CIVector*)aVec
                   biasVector:(CIVector*)biasVec
{
    CIFilter* filter = [CIFilter filterWithName:@"CIColorMatrix"];
    [filter setDefaults];
    [filter setValue:input forKey:kCIInputImageKey];
    [filter setValue:rVec forKey:@"inputRVector"];
    [filter setValue:gVec forKey:@"inputGVector"];
    [filter setValue:bVec forKey:@"inputBVector"];
    [filter setValue:aVec forKey:@"inputAVector"];
    [filter setValue:biasVec forKey:@"inputBiasVector"];
    return [filter valueForKey:kCIOutputImageKey];
}

- (CIImage*)applyMatrix:(CIImage*)input
{
    if(_matrixValues.count < 20) return input;
    CGFloat* m = (CGFloat*)malloc(20 * sizeof(CGFloat));
    for(int i = 0; i < 20; i++) m[i] = _matrixValues[i].doubleValue;
    // CIColorMatrix: each vector is a ROW of the SVG matrix
    CIVector* rVec = [CIVector vectorWithX:m[0] Y:m[1] Z:m[2] W:m[3]];
    CIVector* gVec = [CIVector vectorWithX:m[5] Y:m[6] Z:m[7] W:m[8]];
    CIVector* bVec = [CIVector vectorWithX:m[10] Y:m[11] Z:m[12] W:m[13]];
    CIVector* aVec = [CIVector vectorWithX:m[15] Y:m[16] Z:m[17] W:m[18]];
    CIVector* biasVec = [CIVector vectorWithX:m[4] Y:m[9] Z:m[14] W:m[19]];
    free(m);
    return [self applyColorMatrix:input rVector:rVec gVector:gVec bVector:bVec aVector:aVec biasVector:biasVec];
}

- (CIImage*)applySaturate:(CIImage*)input
{
    CGFloat s = (_matrixValues.count > 0) ? _matrixValues[0].doubleValue : 1.0;
    CIVector* rVec = [CIVector vectorWithX:0.213+0.787*s Y:0.715-0.715*s Z:0.072-0.072*s W:0];
    CIVector* gVec = [CIVector vectorWithX:0.213-0.213*s Y:0.715+0.285*s Z:0.072-0.072*s W:0];
    CIVector* bVec = [CIVector vectorWithX:0.213-0.213*s Y:0.715-0.715*s Z:0.072+0.928*s W:0];
    CIVector* aVec = [CIVector vectorWithX:0 Y:0 Z:0 W:1];
    CIVector* biasVec = [CIVector vectorWithX:0 Y:0 Z:0 W:0];
    return [self applyColorMatrix:input rVector:rVec gVector:gVec bVector:bVec aVector:aVec biasVector:biasVec];
}

- (CIImage*)applyHueRotate:(CIImage*)input
{
    CGFloat angle = (_matrixValues.count > 0) ? _matrixValues[0].doubleValue : 0;
    CGFloat rad = angle * M_PI / 180.0;
    CGFloat c = cos(rad), s = sin(rad);
    CGFloat a00 = 0.213 + 0.787*c - 0.213*s, a01 = 0.715 - 0.715*c - 0.715*s, a02 = 0.072 - 0.072*c + 0.928*s;
    CGFloat a10 = 0.213 - 0.213*c + 0.143*s, a11 = 0.715 + 0.285*c + 0.140*s, a12 = 0.072 - 0.072*c - 0.283*s;
    CGFloat a20 = 0.213 - 0.213*c - 0.787*s, a21 = 0.715 - 0.715*c + 0.715*s, a22 = 0.072 + 0.928*c + 0.072*s;
    CIVector* rVec = [CIVector vectorWithX:a00 Y:a01 Z:a02 W:0];
    CIVector* gVec = [CIVector vectorWithX:a10 Y:a11 Z:a12 W:0];
    CIVector* bVec = [CIVector vectorWithX:a20 Y:a21 Z:a22 W:0];
    CIVector* aVec = [CIVector vectorWithX:0 Y:0 Z:0 W:1];
    CIVector* biasVec = [CIVector vectorWithX:0 Y:0 Z:0 W:0];
    return [self applyColorMatrix:input rVector:rVec gVector:gVec bVector:bVec aVector:aVec biasVector:biasVec];
}

- (CIImage*)applyLuminanceToAlpha:(CIImage*)input
{
    CIVector* rVec = [CIVector vectorWithX:0 Y:0 Z:0 W:0];
    CIVector* gVec = [CIVector vectorWithX:0 Y:0 Z:0 W:0];
    CIVector* bVec = [CIVector vectorWithX:0 Y:0 Z:0 W:0];
    CIVector* aVec = [CIVector vectorWithX:0.2126 Y:0.7152 Z:0.0722 W:0];
    CIVector* biasVec = [CIVector vectorWithX:0 Y:0 Z:0 W:0];
    return [self applyColorMatrix:input rVector:rVec gVector:gVec bVector:bVec aVector:aVec biasVector:biasVec];
}

@end
