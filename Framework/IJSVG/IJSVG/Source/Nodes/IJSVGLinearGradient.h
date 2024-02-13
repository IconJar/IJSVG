//
//  IJSVGLinearGradient.h
//  IJSVG
//
//  Created by Curtis Hard on 03/09/2014.
//  Copyright (c) 2014 Curtis Hard. All rights reserved.
//

@import TouchXML;

#import <IJSVG/IJSVGGradient.h>
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface IJSVGLinearGradient : IJSVGGradient

+ (void)parseGradient:(CXMLElement*)element
             gradient:(IJSVGLinearGradient*)aGradient;

@end

NS_ASSUME_NONNULL_END
