//
//  IJSVGGradientStopData.h
//  IJSVG
//
//  Created by Curtis Hard on 13/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#import <IJSVG/IJSVGStop.h>
#import <IJSVGXML.h>

@class IJSVGParser;

typedef struct {
    CFTypeRef offset;
    CFTypeRef opacity;
    CFTypeRef color;
    BOOL hasFill;
    BOOL isNoneOrTransparent;
} IJSVGGradientStopData;

IJSVGGradientStopData IJSVGGradientStopDataCreate(IJSVGStop* stop, IJSVGXMLNode* element, IJSVGParser* parser);
void IJSVGGradientStopDataRelease(IJSVGGradientStopData* data);
IJSVGStop* IJSVGGradientStopDataCreateStop(const IJSVGGradientStopData* data);
