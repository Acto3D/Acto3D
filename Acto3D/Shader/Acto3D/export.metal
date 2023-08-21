//
//  export.metal
//  Acto3D
//
//  Created by Naoki Takeshita on 2023/06/14.
//

#include <metal_stdlib>
using namespace metal;



kernel void separateChannel(device uint8_t                  *outputData_0 [[buffer(0)]],
                            device uint8_t                  *outputData_1 [[buffer(1)]],
                            device uint8_t                  *outputData_2 [[buffer(2)]],
                            device uint8_t                  *outputData_3 [[buffer(3)]],
                            constant uint16_t               &sliceDepth [[buffer(4)]],
                            texture3d<half, access::read>   tex [[texture(0)]],
                            uint2                           position [[thread_position_in_grid]]){
    
    if (position.x >= tex.get_width() || position.y >= tex.get_height()){
        return;
    }
    
    uint index = (position.y * tex.get_width() + position.x);

    uint3 coord = uint3(position.x, position.y, sliceDepth);
    
    half4 cVoxel = tex.read(coord);
    
    outputData_0[index] = cVoxel.r * 255;
    outputData_1[index] = cVoxel.g * 255;
    outputData_2[index] = cVoxel.b * 255;
    outputData_3[index] = cVoxel.a * 255;
    
}


struct RenderingArguments_export {
    texture3d<half, access::sample> tex     [[id(0)]];
    constant RenderingParameters &params    [[id(1)]];
    device  uint8_t *outputData_0             [[id(2)]];
    device  uint8_t *outputData_1             [[id(3)]];
    device  uint8_t *outputData_2             [[id(4)]];
    device  uint8_t *outputData_3             [[id(5)]];
    sampler smp                             [[id(6)]];
};

kernel void separateChannel_MPR(device RenderingArguments_export        &args   [[buffer(0)]],
                                constant float4                         &quaternions [[buffer(1)]],
                                constant uint16_t                       &flags [[buffer(2)]],
                                uint2                                   position [[thread_position_in_grid]]){
   
    RenderingParameters modelParameter = args.params;
    uint16_t drawingViewSize = modelParameter.viewSize;
    
    if (position.x >= drawingViewSize || position.y >= drawingViewSize){
        return;
    }
    
    float width = args.tex.get_width();
    float height = args.tex.get_height();
    float depth = args.tex.get_depth();
    
    // position in linear array (RGB)
    uint index = position.y * drawingViewSize + position.x;
    
    float4 currentGridPosition = float4(position.x, position.y, 0, 1);
    
    const float scale = modelParameter.scale;
    float scaleMatRatio = 1.0 / scale;
    
    float scale_Z = modelParameter.zScale;
    
    /// matrix for centering
    float4x4 matrix_centering = float4x4(1, 0, 0, 0,
                                         0, 1, 0, 0,
                                         0, 0, 1, 0,
                                         -drawingViewSize / 2.0, -drawingViewSize / 2.0, 0, 1);
    
    float4x4 scaleMat = float4x4(scaleMatRatio, 0, 0, 0,
                                 0, scaleMatRatio, 0, 0,
                                 0, 0, 1.0, 0,
                                 0, 0, 0, 1.0);
    
    float4x4 matrix_centering_toView = float4x4(1, 0, 0, 0,
                                                0, 1, 0, 0,
                                                0, 0, 1, 0,
                                                width / 2.0, height / 2.0, depth * scale_Z / 2.0, 1);
    
    float4x4 transferMat = float4x4(1, 0, 0, 0,
                                    0, 1, 0, 0,
                                    0, 0, 1.0, 0,
                                    modelParameter.translationX, modelParameter.translationY, 0, 1.0);
    
    float4 directionVector = float4(0,0,1,0);
    float4 directionVector_rotate = quatMul(quaternions, directionVector);
    
    float4 pos = transferMat * scaleMat * matrix_centering * currentGridPosition;
    
    float4 mappedXYZt = quatMul(quaternions, pos);
    
    float radius = modelParameter.sliceMax / 2.0;
    
    if (length(mappedXYZt.xyz) > radius){
        args.outputData_0[index] = 0;
        args.outputData_1[index] = 0;
        args.outputData_2[index] = 0;
        args.outputData_3[index] = 0;
        return;
    }
    
    // maximum voxel size
    float z_min = -depth * scale_Z / 2.0f;
    float z_max = depth * scale_Z / 2.0f;
    float x_min = -width/2.0f;
    float x_max = width/2.0f;
    float y_min = -height/2.0f;
    float y_max = height/2.0f;
    
    IntersectionResult result = checkIntersection(mappedXYZt, directionVector_rotate, x_min, x_max, y_min, y_max, z_min, z_max);
    if(result.valid_intersection_count != 2){
        args.outputData_0[index] = 0;
        args.outputData_1[index] = 0;
        args.outputData_2[index] = 0;
        args.outputData_3[index] = 0;
        return;
    }
    
    
    
    float ts = radius - modelParameter.sliceNo ;
    
    float3 current_mapped_pos = mappedXYZt.xyz + ts * directionVector_rotate.xyz * scaleMatRatio;
    float4 currentPos = float4(current_mapped_pos, 1);
    float4 coordinatePos = matrix_centering_toView * currentPos;
    
    float3 samplerPostion;
    if (flags & (1 << FLIP)){
        samplerPostion = float3(coordinatePos.x / float(width),
                                coordinatePos.y / float(height),
                                1.0 - coordinatePos.z / (depth * scale_Z)) ;
    }else{
        samplerPostion = float3(coordinatePos.x / float(width),
                                coordinatePos.y / float(height),
                                coordinatePos.z / (depth * scale_Z)) ;
    }
    
    
    half4 Cvoxel;
    
    if (samplerPostion.x < modelParameter.trimX_min || samplerPostion.x > modelParameter.trimX_max ||
        samplerPostion.y < modelParameter.trimY_min || samplerPostion.y > modelParameter.trimY_max ||
        samplerPostion.z < modelParameter.trimZ_min || samplerPostion.z > modelParameter.trimZ_max){
        
        args.outputData_0[index] = 0;
        args.outputData_1[index] = 0;
        args.outputData_2[index] = 0;
        args.outputData_3[index] = 0;
        return;
        
    }else{
        
        Cvoxel = args.tex.sample(args.smp, samplerPostion);
        
        
        args.outputData_0[index] = Cvoxel.r * 255;
        args.outputData_1[index] = Cvoxel.g * 255;
        args.outputData_2[index] = Cvoxel.b * 255;
        args.outputData_3[index] = Cvoxel.a * 255;
        
        
        return;
    }
    
}

