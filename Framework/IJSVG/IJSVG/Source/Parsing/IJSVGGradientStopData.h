//
//  IJSVGGradientStopData.h
//  IJSVG
//
//  Created by Curtis Hard on 13/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import "IJSVGXML.h"
#import <IJSVG/IJSVGStop.h>

@interface IJSVGGradientStopData : NSObject
- (instancetype)initWithStop:(IJSVGStop*)stop element:(IJSVGXMLNode*)element;
- (IJSVGStop*)newStop;
@end
