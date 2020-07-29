//
//  IJSVGExporter.h
//  IJSVGExample
//
//  Created by Curtis Hard on 06/01/2017.
//  Copyright © 2017 Curtis Hard. All rights reserved.
//

#import <Foundation/Foundation.h>

@class IJSVG;

typedef void (^IJSVGCGPathHandler)(const CGPathElement* pathElement);
typedef void (^IJSVGPathElementEnumerationBlock)(const CGPathElement* pathElement, CGPoint currentPoint);

void IJSVGExporterPathCaller(void* info, const CGPathElement* pathElement);

typedef NS_OPTIONS(NSInteger, IJSVGExporterOptions) {
    IJSVGExporterOptionNone = 1 << 0,
    IJSVGExporterOptionRemoveUselessGroups = 1 << 1,
    IJSVGExporterOptionRemoveUselessDef = 1 << 2,
    IJSVGExporterOptionMoveAttributesToGroup = 1 << 3,
    IJSVGExporterOptionCreateUseForPaths = 1 << 4,
    IJSVGExporterOptionSortAttributes = 1 << 5,
    IJSVGExporterOptionCollapseGroups = 1 << 6,
    IJSVGExporterOptionCleanupPaths = 1 << 7,
    IJSVGExporterOptionRemoveHiddenElements = 1 << 8,
    IJSVGExporterOptionScaleToSizeIfNecessary = 1 << 9,
    IJSVGExporterOptionCompressOutput = 1 << 10,
    IJSVGExporterOptionCollapseGradients = 1 << 11,
    IJSVGExporterOptionCreateClasses = 1 << 12,
    IJSVGExporterOptionRemoveWidthHeightAttributes = 1 << 13,
    IJSVGExporterOptionColorAllowRRGGBBAA = 1 << 14,
    IJSVGExporterOptionRemoveComments = 1 << 15,
    IJSVGExporterOptionCenterWithinViewBox = 1 << 16,
    IJSVGExporterOptionRemoveXMLDeclaration = 1 << 17,
    IJSVGExporterOptionAll = IJSVGExporterOptionRemoveUselessDef | IJSVGExporterOptionRemoveUselessGroups | IJSVGExporterOptionCreateUseForPaths | IJSVGExporterOptionMoveAttributesToGroup | IJSVGExporterOptionSortAttributes | IJSVGExporterOptionCollapseGroups | IJSVGExporterOptionCleanupPaths | IJSVGExporterOptionRemoveHiddenElements | IJSVGExporterOptionScaleToSizeIfNecessary | IJSVGExporterOptionCompressOutput | IJSVGExporterOptionCollapseGradients | IJSVGExporterOptionRemoveWidthHeightAttributes | IJSVGExporterOptionColorAllowRRGGBBAA | IJSVGExporterOptionRemoveComments | IJSVGExporterOptionCenterWithinViewBox | IJSVGExporterOptionRemoveXMLDeclaration
};

BOOL IJSVGExporterHasOption(IJSVGExporterOptions options, NSInteger option);
void IJSVGEnumerateCGPathElements(CGPathRef path, IJSVGPathElementEnumerationBlock enumBlock);
const NSArray* IJSVGShortCharacterArray(void);

@interface IJSVGExporter : NSObject {

@private
    IJSVG* _svg;
    CGSize _size;
    IJSVGExporterOptions _options;
    NSXMLDocument* _dom;
    NSXMLElement* _defElement;
    NSInteger _idCount;
    NSInteger _shortIdCount;
}

@property (nonatomic, copy) NSString* title;
@property (nonatomic, copy) NSString* description;

- (id)initWithSVG:(IJSVG*)svg
             size:(CGSize)size
          options:(IJSVGExporterOptions)options;
- (NSString*)SVGString;
- (NSData*)SVGData;

@end
