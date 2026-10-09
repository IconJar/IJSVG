//
//  IJSVGMarker.h
//  IJSVG
//
//  Created by Curtis Hard on 09/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGGroup.h>

NS_ASSUME_NONNULL_BEGIN


typedef NS_ENUM(NSUInteger, IJSVGMarkerUnits) {
    IJSVGMarkerUnitsStrokeWidth,
    IJSVGMarkerUnitsUserSpaceOnUse
};

typedef NS_ENUM(NSUInteger, IJSVGMarkerOrientType) {
    IJSVGMarkerOrientTypeAngle,
    IJSVGMarkerOrientTypeAuto,
    IJSVGMarkerOrientTypeAutoStartReverse
};

@interface IJSVGMarker : IJSVGGroup
@property (nonatomic, strong) IJSVGUnitLength* refX;
@property (nonatomic, strong) IJSVGUnitLength* refY;
@property (nonatomic, strong) IJSVGUnitLength* markerWidth;
@property (nonatomic, strong) IJSVGUnitLength* markerHeight;
@property (nonatomic, assign) IJSVGMarkerUnits markerUnits;
@property (nonatomic, assign) IJSVGMarkerOrientType orientType;
@property (nonatomic, assign) CGFloat orientAngle;

@end

typedef NS_ENUM(NSUInteger, IJSVGMarkerPositionType) {
    IJSVGMarkerPositionStart,
    IJSVGMarkerPositionMid,
    IJSVGMarkerPositionEnd
};

@interface IJSVGMarkerPosition : NSObject

@property (nonatomic, assign) CGPoint point;
@property (nonatomic, assign) CGFloat angle;
@property (nonatomic, assign) IJSVGMarkerPositionType type;

@end

// Source data preserves SVG vertices when an arc is represented by several CG curves.
NSArray<IJSVGMarkerPosition*>* IJSVGMarkerPositions(CGPathRef path,
                                                    NSString* _Nullable sourceData);

NS_ASSUME_NONNULL_END
