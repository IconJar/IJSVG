//
//  IJSVGSubtract.metal
//  IJSVG
//
//  Created on 30/09/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#include <CoreImage/CoreImage.h>
extern "C" { namespace coreimage {
[[ stitchable ]] float4 ijsvgSubtract(sample_t first, sample_t second) {
    float4 result = clamp(float4(second) - float4(first), 0.0f, 1.0f);
    result.rgb = min(result.rgb, float3(result.a));
    return result;
}
}}
