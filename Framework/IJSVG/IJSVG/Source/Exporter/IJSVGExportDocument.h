//
//  IJSVGExportDocument.h
//  IJSVG
//
//  Created by Curtis Hard on 16/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#pragma once
#import <Foundation/Foundation.h>
#import <IJSVG/IJSVGExportElement.h>

NS_ASSUME_NONNULL_BEGIN

@interface IJSVGExportDocument : NSObject
- (instancetype)init NS_UNAVAILABLE;
@property (nonatomic, readonly) IJSVGExportElement* rootElement;
@property (nonatomic, copy) NSString* version;
@property (nonatomic, copy) NSString* characterEncoding;
- (instancetype)initWithRootElement:(IJSVGExportElement*)root;
- (NSData*)XMLDataWithPrettyPrinting:(BOOL)prettyPrint;

/// Controls whether libxml emits the XML declaration.
- (NSData*)XMLDataWithPrettyPrinting:(BOOL)prettyPrint includeXMLDeclaration:(BOOL)includeXMLDeclaration;
- (NSString*)XMLStringWithPrettyPrinting:(BOOL)prettyPrint;
@end

NS_ASSUME_NONNULL_END
