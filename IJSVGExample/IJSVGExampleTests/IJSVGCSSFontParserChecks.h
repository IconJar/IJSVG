//
//  IJSVGCSSFontParserChecks.h
//  IJSVGExampleTests
//
//  Created on 07/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

NSArray<NSString*>* IJSVGRunCSSFontParserChecks(void);
void IJSVGBenchmarkCSSFontParser(void);
NSArray<NSString*>* IJSVGTextRegressionCaseNames(void);
NSArray<NSString*>* IJSVGRunTextRegressionCase(NSString* name);

NSArray<NSString*>* IJSVGReferenceWebKitCaseNames(void);
void IJSVGRunReferenceWebKitCase(NSString* name, void (^completion)(NSArray<NSString*>*));

NS_ASSUME_NONNULL_END
