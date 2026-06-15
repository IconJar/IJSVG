//
//  IJSVGFilterEffectMerge.m
//  IJSVG
//

#import <IJSVG/IJSVGFilterEffectMerge.h>
#import <IJSVG/IJSVGFilterGraph.h>

@implementation IJSVGFilterEffectMerge

- (CIImage*)processWithGraph:(IJSVGFilterGraph*)graph
{
    NSString* lowerName = self.name.lowercaseString;

    if([lowerName isEqualToString:@"femergenode"]) {
        CIImage* input = [graph imageForInput:self.inputName];
        [graph setImage:input forResult:self.resultName];
        return input;
    }

    // feMerge: composite children (feMergeNode) in order
    CIImage* result = nil;
    for(IJSVGFilterEffect* child in self.children) {
        CIImage* childResult = [child processWithGraph:graph];
        if(result == nil) {
            result = childResult;
        } else {
            CIFilter* over = [CIFilter filterWithName:@"CISourceOverCompositing"];
            [over setDefaults];
            [over setValue:childResult forKey:kCIInputImageKey];
            [over setValue:result forKey:kCIInputBackgroundImageKey];
            result = [over valueForKey:kCIOutputImageKey];
        }
    }
    if(result == nil) result = [graph imageForInput:self.inputName];
    [graph setImage:result forResult:self.resultName];
    return result;
}

@end
