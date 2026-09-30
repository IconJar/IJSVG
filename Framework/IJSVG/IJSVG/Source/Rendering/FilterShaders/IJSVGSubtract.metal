//
//  IJSVGSubtract.metal
//  IJSVG
//
//  Created on 30/09/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#include <CoreImage/CoreImage.h>

extern "C" {
    namespace coreimage {
        // General arithmetic includes the original inner shadow subtraction case.
        [[ stitchable ]] float4 ijsvgArithmetic(sample_t first, sample_t second,
                                               float4 coefficients)
        {
            float4 a = float4(first), b = float4(second);
            float4 result = coefficients.x * a * b + coefficients.y * a
                + coefficients.z * b + coefficients.w;
            result = select(float4(0.0f), result, isfinite(result));
            result = clamp(result, 0.0f, 1.0f);
            result.rgb = min(result.rgb, float3(result.a));
            return result;
        }
    }
}
