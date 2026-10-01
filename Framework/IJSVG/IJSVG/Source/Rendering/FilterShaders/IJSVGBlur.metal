//
//  IJSVGBlur.metal
//  IJSVG
//
//  Created on 01/10/2026.
//  Copyright © 2026 Curtis Hard. All rights reserved.
//

#include <metal_stdlib>

using namespace metal;

struct BlurParameters {
    uint4 geometry; // width, height, taps, source crop count
    float4 region;  // min/max in Core Image coordinates
    uint4 config;   // linear RGB, first pixel in shared storage
    float4 shadowOffset;
    float4 shadowTint;
    float weights[76];
};

float blurCoverage(uint2 p, constant BlurParameters& job)
{
    float2 position = float2(p.x, job.geometry.y - 1 - p.y);
    float2 size = max(float2(0), min(position + 1, job.region.zw) - max(position, job.region.xy));
    return size.x * size.y;
}

kernel void blurPrepare(device const uchar4* source [[buffer(0)]],
                        device float4* prepared [[buffer(1)]],
                        device float4* horizontal [[buffer(2)]],
                        device uchar4* output [[buffer(3)]],
                        constant BlurParameters* jobs [[buffer(4)]],
                        device const uint* mapping [[buffer(5)]],
                        uint i [[thread_position_in_grid]])
{
    constant BlurParameters& job = jobs[mapping[i]];
    uint local = i - job.config.y;
    uint2 p = uint2(local % job.geometry.x, local / job.geometry.x);
    float4 value = float4(source[i]) / 255.0f;
    if(job.config.x != 0) {
        float3 straight = value.a > 0 ? clamp(value.rgb / value.a, 0.0f, 1.0f) : float3(0);
        value.rgb = select(pow((straight + .055f) / 1.055f, float3(2.4f)),
                           straight / 12.92f, straight <= .04045f) * value.a;
    }
    float crop = blurCoverage(p, job);
    if(job.geometry.w == 2) {
        crop *= crop;
    }
    prepared[i] = (job.config.z != 0 ? float4(0, 0, 0, value.a) : value) * crop;
}

kernel void blurHorizontal(device const uchar4* source [[buffer(0)]],
                           device const float4* prepared [[buffer(1)]],
                           device float4* horizontal [[buffer(2)]],
                           device uchar4* output [[buffer(3)]],
                           constant BlurParameters* jobs [[buffer(4)]],
                           device const uint* mapping [[buffer(5)]],
                           uint i [[thread_position_in_grid]])
{
    constant BlurParameters& job = jobs[mapping[i]];
    uint local = i - job.config.y;
    uint2 p = uint2(local % job.geometry.x, local / job.geometry.x);
    float4 value = 0;
    int radius = int(job.geometry.z / 2);
    for(uint k = 0; k < job.geometry.z; k++) {
        int x = int(p.x) + int(k) - radius;
        if(x >= 0 && x < int(job.geometry.x)) {
            value += prepared[job.config.y + p.y * job.geometry.x + x] * job.weights[k];
        }
    }
    horizontal[i] = value;
}

// Offset shadows may sample the blur halo outside the bitmap. Evaluate those
// horizontal halo samples from the source instead of clipping the convolution.
float shadowHorizontalAlpha(int x, int y, device const float4* prepared,
                            device const float4* horizontal, constant BlurParameters& job)
{
    if(y < 0 || y >= int(job.geometry.y)) return 0;
    if(x >= 0 && x < int(job.geometry.x))
        return horizontal[job.config.y + y * job.geometry.x + x].a;
    float value = 0;
    int radius = int(job.geometry.z / 2);
    for(uint k = 0; k < job.geometry.z; k++) {
        int sx = x + int(k) - radius;
        if(sx >= 0 && sx < int(job.geometry.x))
            value += prepared[job.config.y + y * job.geometry.x + sx].a * job.weights[k];
    }
    return value;
}

kernel void blurVertical(device const uchar4* source [[buffer(0)]],
                         device const float4* prepared [[buffer(1)]],
                         device const float4* horizontal [[buffer(2)]],
                         device uchar4* output [[buffer(3)]],
                         constant BlurParameters* jobs [[buffer(4)]],
                         device const uint* mapping [[buffer(5)]],
                         uint i [[thread_position_in_grid]])
{
    constant BlurParameters& job = jobs[mapping[i]];
    uint local = i - job.config.y;
    uint2 p = uint2(local % job.geometry.x, local / job.geometry.x);
    float4 value = 0;
    int radius = int(job.geometry.z / 2);
    for(uint k = 0; job.config.z == 0 && k < job.geometry.z; k++) {
        int y = int(p.y) + int(k) - radius;
        if(y >= 0 && y < int(job.geometry.y)) {
            value += horizontal[job.config.y + y * job.geometry.x + p.x] * job.weights[k];
        }
    }
    if(job.config.z != 0) {
        float2 q = float2(p) + float2(-job.shadowOffset.x, job.shadowOffset.y);
        int2 base = int2(floor(q));
        float2 fraction = q - float2(base);
        float alpha = 0;
        for(uint k = 0; k < job.geometry.z; k++) {
            int y = base.y + int(k) - radius;
            float a = mix(shadowHorizontalAlpha(base.x, y, prepared, horizontal, job),
                          shadowHorizontalAlpha(base.x + 1, y, prepared, horizontal, job), fraction.x);
            float b = mix(shadowHorizontalAlpha(base.x, y + 1, prepared, horizontal, job),
                          shadowHorizontalAlpha(base.x + 1, y + 1, prepared, horizontal, job), fraction.x);
            alpha += mix(a, b, fraction.y) * job.weights[k];
        }
        float4 foreground = float4(source[i]) / 255.0f;
        float3 tint = job.shadowTint.rgb;
        if(job.config.x != 0) {
            float3 straight = foreground.a > 0 ? clamp(foreground.rgb / foreground.a, 0.0f, 1.0f) : float3(0);
            foreground.rgb = select(pow((straight + .055f) / 1.055f, float3(2.4f)),
                straight / 12.92f, straight <= .04045f) * foreground.a;
            tint = select(pow((tint + .055f) / 1.055f, float3(2.4f)), tint / 12.92f, tint <= .04045f);
        }
        foreground *= blurCoverage(p, job);
        alpha = clamp(alpha, 0.0f, 1.0f) * job.shadowTint.a;
        value = foreground + float4(tint * alpha, alpha) * (1.0f - foreground.a);
    }
    if(job.config.x != 0) {
        float3 straight = value.a > 0 ? clamp(value.rgb / value.a, 0.0f, 1.0f) : float3(0);
        value.rgb = select(1.055f * pow(straight, float3(1.0f / 2.4f)) - .055f,
                           straight * 12.92f, straight <= .0031308f) * value.a;
    }
    value *= blurCoverage(p, job);
    output[i] = uchar4(rint(clamp(value, 0.0f, 1.0f) * 255.0f));
}
