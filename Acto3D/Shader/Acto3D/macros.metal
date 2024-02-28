//
//  macros.metal
//  Acto3D
//
//  Created by Naoki Takeshita on 2023/08/17.
//

#include <metal_stdlib>
using namespace metal;


#define SHOW_MPR \
{\
    float ts = radius - modelParameter.sliceNo ; \
    float4 currentPos = float4(mappedPosition.xyz + ts * directionVector_rotate.xyz, 1); \
    float4 coordinatePos = centeringToViewMatrix * currentPos; \
    float width = args.tex.get_width(); \
    float height = args.tex.get_height(); \
    float depth = args.tex.get_depth(); \
    float3 texCoordinate = (flags & (1 << FLIP)) ? \
    float3(coordinatePos.x / float(width), \
           coordinatePos.y / float(height), \
           1.0f - coordinatePos.z / ((depth) * scale_Z)) : \
    float3(coordinatePos.x / float(width), \
           coordinatePos.y / float(height), \
           coordinatePos.z / ((depth) * scale_Z)) ; \
    \
    float4 Cvoxel; \
    \
    if (texCoordinate.x < modelParameter.trimX_min || texCoordinate.x > modelParameter.trimX_max || \
        texCoordinate.y < modelParameter.trimY_min || texCoordinate.y > modelParameter.trimY_max || \
        texCoordinate.z < modelParameter.trimZ_min || texCoordinate.z > modelParameter.trimZ_max){ \
        args.outputData[index + 0] = 0; \
        args.outputData[index + 1] = 0; \
        args.outputData[index + 2] = 0; \
    }else{ \
        Cvoxel = (float4)args.tex.sample(args.smp, texCoordinate); \
        Cvoxel *= float4(modelParameter.intensityRatio[0], \
                         modelParameter.intensityRatio[1], \
                         modelParameter.intensityRatio[2], \
                         modelParameter.intensityRatio[3]); \
        float3 lut_c1 = Cvoxel[0] * modelParameter.color.ch1.rgb; \
        float3 lut_c2 = Cvoxel[1] * modelParameter.color.ch2.rgb; \
        float3 lut_c3 = Cvoxel[2] * modelParameter.color.ch3.rgb; \
        float3 lut_c4 = Cvoxel[3] * modelParameter.color.ch4.rgb; \
        float cR = max(lut_c1.r, lut_c2.r, lut_c3.r, lut_c4.r); \
        float cG = max(lut_c1.g, lut_c2.g, lut_c3.g, lut_c4.g); \
        float cB = max(lut_c1.b, lut_c2.b, lut_c3.b, lut_c4.b); \
        args.outputData[index + 0] = uint8_t(clamp(cR * 255.0f, 0.0f, 255.0f)); \
        args.outputData[index + 1] = uint8_t(clamp(cG * 255.0f, 0.0f, 255.0f)); \
        args.outputData[index + 2] = uint8_t(clamp(cB * 255.0f, 0.0f, 255.0f)); \
    } \
}\
