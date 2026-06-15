//
//  IJSVGFilterGraph.h
//  IJSVG
//

#import <Foundation/Foundation.h>
#import <CoreImage/CoreImage.h>

NS_ASSUME_NONNULL_BEGIN

@interface IJSVGFilterGraph : NSObject

@property (nonatomic, readonly) CGRect sourceBounds;
@property (nonatomic, readonly) CGFloat scale;
@property (nonatomic, assign) CGPoint elementSVGOrigin; // SVG-space position of bitmap top-left

- (instancetype)initWithSourceGraphic:(CIImage*)sourceGraphic scale:(CGFloat)scale;
- (CIImage*)imageForInput:(nullable NSString*)inputName;
- (void)setImage:(CIImage*)image forResult:(nullable NSString*)resultName;
- (CIImage*)lastResult;

@end

NS_ASSUME_NONNULL_END
