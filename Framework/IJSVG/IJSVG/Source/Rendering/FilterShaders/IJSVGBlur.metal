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
    prepared[i] = value * crop;
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
    for(uint k = 0; k < job.geometry.z; k++) {
        int y = int(p.y) + int(k) - radius;
        if(y >= 0 && y < int(job.geometry.y)) {
            value += horizontal[job.config.y + y * job.geometry.x + p.x] * job.weights[k];
        }
    }
    if(job.config.x != 0) {
        float3 straight = value.a > 0 ? clamp(value.rgb / value.a, 0.0f, 1.0f) : float3(0);
        value.rgb = select(1.055f * pow(straight, float3(1.0f / 2.4f)) - .055f,
                           straight * 12.92f, straight <= .0031308f) * value.a;
    }
    value *= blurCoverage(p, job);
    output[i] = uchar4(rint(clamp(value, 0.0f, 1.0f) * 255.0f));
}
