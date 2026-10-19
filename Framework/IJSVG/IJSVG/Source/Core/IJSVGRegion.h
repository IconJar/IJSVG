//
//  IJSVGRegion.h
//  IJSVG
//
//  Created by Curtis Hard on 19/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <IJSVG/IJSVGNode.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, IJSVGRegionCoordinateSpace) {
    // Geometry before the node transform, including child transforms.
    // Ignores ancestor transforms and clipping. SVG viewports use their inner
    // user coordinates. Useful for measuring or editing individual nodes.
    IJSVGRegionCoordinateSpaceLocal,

    // Geometry in the outer SVG user coordinates, including the node transform,
    // ancestor transforms and nested viewport mappings. Useful for comparing
    // elements within the SVG before mapping into a drawing rectangle.
    IJSVGRegionCoordinateSpaceUser,

    // Geometry mapped into the supplied drawing rectangle, including viewBox
    // scaling, alignment and drawing offset. Clipped to that rectangle.
    // Useful for placing clickable overlays over the rendered image.
    IJSVGRegionCoordinateSpaceDestination
};

// Immutable metadata for a rectangular region of rendered content.
@interface IJSVGRegion : NSObject

@property (nonatomic, readonly) CGRect rect;
@property (nonatomic, readonly) IJSVGNodeType type;
@property (nonatomic, copy, readonly, nullable) NSString* value;
@property (nonatomic, copy, readonly, nullable) NSString* identifier;
@property (nonatomic, strong, readonly, nullable) IJSVGNode* node;
@property (nonatomic, readonly) IJSVGRegionCoordinateSpace coordinateSpace;

// Ordinal among rendered instances sharing this identifier or source node.
@property (nonatomic, readonly) NSUInteger instanceIndex;

- (instancetype)initWithRect:(CGRect)rect type:(IJSVGNodeType)type value:(nullable NSString*)value;
- (instancetype)initWithRect:(CGRect)rect type:(IJSVGNodeType)type value:(nullable NSString*)value node:(nullable IJSVGNode*)node coordinateSpace:(IJSVGRegionCoordinateSpace)coordinateSpace instanceIndex:(NSUInteger)instanceIndex NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
