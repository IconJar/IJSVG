//
//  IJSVGInnerShadow.metal
//  IJSVG
//
//  Created on 30/09/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#include <metal_stdlib>

using namespace metal;

struct ShadowJob {
    uint4 geometry;
    float4 region;
    float4 offsets[4];
    float4 tints[4];
    uint4 config;
    float weights[128];
};

float coverage(float2 p, float4 r)
{
    float2 c = max(float2(0), min(p + .5f, r.zw) - max(p - .5f, r.xy));
    return c.x * c.y;
}

float4 pixel(device const uchar4* src, constant ShadowJob& job, int2 p)
{
    if(any(p < 0) || p.x >= int(job.geometry.x) || p.y >= int(job.geometry.y)) {
        return float4(0);
    }
    uint i = job.geometry.z + (job.geometry.y - 1 - p.y) * job.geometry.x + p.x;
    return float4(src[i]) / 255.0f;
}

float4 shiftedRegion(constant ShadowJob& job, uint stage)
{
    float2 offset = job.offsets[stage].xy;
    return float4(max(job.region.xy, job.region.xy + offset),
                  min(job.region.zw, job.region.zw + offset));
}

kernel void shadowHorizontal(device const uchar4* src [[buffer(0)]],
                             device float* horizontal [[buffer(1)]],
                             device float4* accumulated [[buffer(2)]],
                             device uchar4* result [[buffer(3)]],
                             device const uint* mapping [[buffer(4)]],
                             constant ShadowJob* jobs [[buffer(5)]],
                             constant uint& stage [[buffer(6)]],
                             uint i [[thread_position_in_grid]])
{
    constant ShadowJob& job = jobs[mapping[i]];
    if(stage >= job.config.x) {
        return;
    }
    uint local = i - job.geometry.z;
    float2 p = float2(local % job.geometry.x,
                     job.geometry.y - 1 - local / job.geometry.x) + .5f;
    int taps = int(job.offsets[stage].w), radius = taps / 2;
    float value = 0;
    float4 region = shiftedRegion(job, stage);

    // Adjacent taps share their two boundary samples. Keep the original
    // fractional coordinate calculation and clipping order for every tap.
    float topRight = 0, bottomRight = 0;
    int previousX = 0;
    for(int k = 0; k < taps; k++) {
        float2 q = p + float2(k - radius, 0);
        float2 samplePoint = q - job.offsets[stage].xy;
        float2 position = samplePoint - .5f;
        int2 lo = int2(floor(position));
        float2 fraction = fract(position);

        // Near an integer, float rounding can move a tap across a pixel boundary.
        bool adjacent = k > 0 && lo.x == previousX + 1;
        float topLeft = adjacent ? topRight : pixel(src, job, lo).a;
        float bottomLeft = adjacent ? bottomRight : pixel(src, job, lo + int2(0, 1)).a;
        previousX = lo.x;
        topRight = pixel(src, job, lo + int2(1, 0)).a;
        bottomRight = pixel(src, job, lo + int2(1, 1)).a;

        float alpha = mix(mix(topLeft, topRight, fraction.x),
                          mix(bottomLeft, bottomRight, fraction.x), fraction.y);
        alpha = clamp(alpha * coverage(samplePoint, job.region) * job.offsets[stage].z,
                      0.0f, 1.0f);
        value += alpha * coverage(q, region) * job.weights[stage * 32 + k];
    }
    horizontal[i] = value;
}

kernel void shadowVertical(device const uchar4* src [[buffer(0)]],
                           device const float* horizontal [[buffer(1)]],
                           device float4* accumulated [[buffer(2)]],
                           device uchar4* result [[buffer(3)]],
                           device const uint* mapping [[buffer(4)]],
                           constant ShadowJob* jobs [[buffer(5)]],
                           constant uint& stage [[buffer(6)]],
                           uint i [[thread_position_in_grid]])
{
    constant ShadowJob& job = jobs[mapping[i]];
    if(stage >= job.config.x) {
        return;
    }
    uint local = i - job.geometry.z;
    int x = int(local % job.geometry.x), y = int(local / job.geometry.x);
    float2 p = float2(x, int(job.geometry.y) - 1 - y) + .5f;
    int taps = int(job.offsets[stage].w), radius = taps / 2;
    float blurred = 0;
    for(int k = 0; k < taps; k++) {
        int row = y + k - radius;
        if(row >= 0 && row < int(job.geometry.y)) {
            blurred += horizontal[job.geometry.z + row * job.geometry.x + x]
                * job.weights[stage * 32 + k];
        }
    }

    float2 offset = job.offsets[stage].xy;
    float4 blurRegion = float4(max(job.region.xy, floor(job.region.xy + offset)),
                              min(job.region.zw, ceil(job.region.zw + offset)));
    blurred *= coverage(p, blurRegion);
    float crop = coverage(p, job.region);

    // p lies exactly at the centre of this source pixel, so interpolation is unnecessary.
    float4 source = float4(src[i]) / 255.0f;
    float hardAlpha = clamp(source.a * crop * job.offsets[stage].z, 0.0f, 1.0f) * crop;
    float shadow = clamp(hardAlpha - blurred, 0.0f, 1.0f) * crop * crop;
    float4 background = stage == 0 ? source * crop * crop : accumulated[i];
    float4 value = float4(job.tints[stage].rgb * shadow * background.a + background.rgb * (1 - shadow),
                         background.a) * crop;
    if(stage + 1 == job.config.x) {
        result[i] = uchar4(rint(clamp(value, 0.0f, 1.0f) * 255.0f));
    } else {
        accumulated[i] = value;
    }
}
