#import "IJSVGTestSupport.h"

extern NSString* IJSVGFilterShaderSource(NSString* name);

NSString* IJSVGPackageShaderSource(NSString* name)
{
    return IJSVGFilterShaderSource(name);
}

#import <IJSVG/IJSVG.h>

@interface IJSVGPDFErrorFixture : IJSVG
@end

@implementation IJSVGPDFErrorFixture
- (NSData*)PDFData:(NSError**)error
{
    return [self PDFDataWithRect:CGRectZero error:error];
}

- (NSData*)PDFDataWithRect:(CGRect)rect error:(NSError**)error
{
    // Match the existing contract: drawing may report an error alongside data.
    if(error != NULL) {
        *error = [NSError errorWithDomain:@"IJSVGSwiftAnnotationTest" code:1 userInfo:nil];
    }
    return [NSData data];
}
@end

IJSVG* IJSVGWithPDFError(void)
{
    return [[IJSVGPDFErrorFixture alloc] init];
}
