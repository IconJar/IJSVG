//
//  IJSVGTestHelpers.h
//  IJSVGExampleTests
//
//  Created by Curtis Hard on 27/06/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <XCTest/XCTest.h>
#import <IJSVG/IJSVG.h>
#import <IJSVG/IJSVGClipPath.h>
#import <IJSVG/IJSVGColorNode.h>
#import <IJSVG/IJSVGExporter.h>
#import <IJSVG/IJSVGGroup.h>
#import <IJSVG/IJSVGLinearGradient.h>
#import <IJSVG/IJSVGMask.h>
#import <IJSVG/IJSVGNode.h>
#import <IJSVG/IJSVGParser.h>
#import <IJSVG/IJSVGPath.h>
#import <IJSVG/IJSVGRootNode.h>
#import <IJSVG/IJSVGStop.h>
#import <IJSVG/IJSVGStyleSheet.h>
#import <IJSVG/IJSVGStyleSheetStyle.h>
#import <IJSVG/IJSVGTransform.h>

NS_ASSUME_NONNULL_BEGIN

IJSVGNode* IJSVGTestNode(NSString* name, NSString* _Nullable identifier, NSArray<NSString*>* _Nullable classes);
IJSVGGroup* IJSVGTestGroup(NSString* _Nullable identifier, NSArray<NSString*>* _Nullable classes);
IJSVGStyleSheet* IJSVGTestStyleSheet(NSString* styleBlock);
NSString* IJSVGTestSVG(NSString* body);
IJSVG* IJSVGTestSVGObject(NSString* svgString);
NSXMLDocument* IJSVGTestXMLDocument(NSString* xmlString);
NSData* IJSVGTestRGBADataForSVG(NSString* svgString, CGSize size);
NSColor* IJSVGTestColorFromRGBAData(NSData* data, CGSize size, CGPoint point);
NSColor* IJSVGTestColorFromSVGAtPoint(NSString* svgString, CGPoint point);
void IJSVGAssertColorComponents(NSColor* color, CGFloat red, CGFloat green, CGFloat blue, CGFloat alpha);
void IJSVGAssertRenderedSVGMatchesMap(NSString* svgString,
                                      NSArray<NSString*>* rows,
                                      NSDictionary<NSString*, NSColor*>* palette);

NS_ASSUME_NONNULL_END
