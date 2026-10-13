//
//  IJSVGGradientStopData.h
//  IJSVG
//
//  Created by Curtis Hard on 13/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import "IJSVGXML.h"
#import <IJSVG/IJSVGStop.h>

typedef struct {
    CFTypeRef offset;
    CFTypeRef opacity;
    CFTypeRef color;
    BOOL hasFill;
    BOOL isNoneOrTransparent;
} IJSVGGradientStopData;

IJSVGGradientStopData IJSVGGradientStopDataCreate(IJSVGStop* stop, IJSVGXMLNode* element);
void IJSVGGradientStopDataRelease(IJSVGGradientStopData* data);
IJSVGStop* IJSVGGradientStopDataCreateStop(const IJSVGGradientStopData* data);
