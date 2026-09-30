#import <IJSVGTestHelpers.h>
#import <IJSVG/IJSVGShapeLayer.h>
#import <IJSVG/IJSVGThreadManager.h>

@interface XCTestCase (IJSVGFilterTestHelpers)
- (CGContextRef)newBitmapWithSize:(NSUInteger)size flipped:(BOOL)flipped CF_RETURNS_RETAINED;
- (NSData*)renderDocument:(NSString*)document flipped:(BOOL)flipped;
- (NSData*)renderDocument:(NSString*)document flipped:(BOOL)flipped
                 clipped:(BOOL)clipped generalTransparency:(BOOL)generalTransparency;
- (NSData*)compositeDocuments:(NSArray<NSString*>*)documents flipped:(BOOL)flipped clipped:(BOOL)clipped;
- (NSInteger)maximumDifference:(NSData*)first other:(NSData*)second;
- (BOOL)containsPaintedPixels:(NSData*)pixels;
- (void)runWorkers:(NSUInteger)count freshThreads:(BOOL)freshThreads
             block:(void (^)(NSUInteger index))block;
- (void)assertFilterOptionsForDocument:(NSString*)document flipped:(BOOL)flipped exportImage:(BOOL)exportImage;
@end
