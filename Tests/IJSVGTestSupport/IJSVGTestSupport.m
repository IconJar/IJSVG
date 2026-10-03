#import "IJSVGTestSupport.h"

extern NSString* IJSVGFilterShaderSource(NSString* name);

NSString* IJSVGPackageShaderSource(NSString* name)
{
    return IJSVGFilterShaderSource(name);
}
