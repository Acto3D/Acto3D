//
//  preset_MIP.metal
//  Acto3D
//
//  Created by Naoki Takeshita on 2023/06/24.
//

#include <metal_stdlib>
using namespace metal;

// Label: built-in MIP
// Author: Naoki Takeshita
// Description: Standard Maximum Intensity Projection (MIP)
kernel void preset_MIP(device RenderingArguments    &args       [[buffer(0)]],
                       uint2                        position    [[thread_position_in_grid]]){
    // output view size
    uint16_t viewSize = args.targetViewSize;
    
    if (position.x >= viewSize || position.y >= viewSize){
        return;
    }
    
    RenderingParameters modelParameter = args.params;
    
    uint16_t flags = args.flags;
    
    float4 quaternions = args.quaternions;
    
    
    float width = args.tex.get_width();
    float height = args.tex.get_height();
    float depth = args.tex.get_depth();
    
    float scaleRatio = 1.0 / modelParameter.scale;
    
    // Adjust scaleRatio if the model's view size and the target view size differ.
    // This situation occurs in circumstances:
    //   (1) when rendering a low-quality image (during a mouse drag),
    //   (2) when rendering a high-quality image (snapshot, animation),
    scaleRatio *= (float)modelParameter.viewSize / (float)args.targetViewSize;
    
    // index for output texture (output texture is 24 bits RGB image)
    uint index = (position.y * viewSize + position.x) * 3;
    float4 currentThreadPosition = float4(position.x, position.y, 0, 1);

    float scale_Z = modelParameter.zScale;
    
//    uint16_t pointSetCount = args.pointSetCount;
//    constant float3* pointSet = args.pointSet;
//    uint16_t pointSelectedIndex = args.pointSelectedIndex;
    
    
    // uniform matrix
    float4x4 centeringMatrix = float4x4(1, 0, 0, 0,
                                        0, 1, 0, 0,
                                        0, 0, 1, 0,
                                        -viewSize / 2.0, -viewSize / 2.0, 0, 1);
    
    float4x4 scaleMatix = float4x4(scaleRatio, 0, 0, 0,
                                   0, scaleRatio, 0, 0,
                                   0, 0, 1.0, 0,
                                   0, 0, 0, 1.0);
    
    
    float4x4 transferMatrix = float4x4(1, 0, 0, 0,
                                       0, 1, 0, 0,
                                       0, 0, 1.0, 0,
                                       modelParameter.translationX, modelParameter.translationY, 0, 1.0);
    
    float4x4 centeringToViewMatrix = float4x4(1, 0, 0, 0,
                                              0, 1, 0, 0,
                                              0, 0, 1, 0,
                                              width / 2.0, height / 2.0, depth * scale_Z / 2.0, 1);
    
    
    // directionVector is the normal vector with respect to the pre-rotation view,
    // and is set to (0, 0, 1, 0).
    // directionVector_rotate is the direction vector of the ray,
    // obtained by applying the current quaternion rotation to directionVector.
    float4 directionVector = float4(0,0,1,0);
    float4 directionVector_rotate = quatMul(quaternions, directionVector);
    
    float4 uniformedThreadPosition = transferMatrix * scaleMatix * centeringMatrix * currentThreadPosition;
    
    float4 mappedPosition = quatMul(quaternions, uniformedThreadPosition);
    
    float radius = modelParameter.sliceMax / 2.0;
    
    if (length(mappedPosition.xyz) > radius){
        args.outputData[index + 0] = modelParameter.backgroundColor.r * 255.0;
        args.outputData[index + 1] = modelParameter.backgroundColor.g * 255.0;
        args.outputData[index + 2] = modelParameter.backgroundColor.b * 255.0;
        return;
    }
    
    // This is a macro for MPR display.
    // You can terminate the process here when displaying MPR.
    if(flags & (1 << MPR)){
        SHOW_MPR
        return;
    }
    
    // Maximum and minimum coordinates of the texture
    float z_min = -depth * scale_Z / 2.0f;
    float z_max = depth * scale_Z / 2.0f;
    float x_min = -width / 2.0f;
    float x_max = width / 2.0f;
    float y_min = -height / 2.0f;
    float y_max = height / 2.0f;
    
    // Compute intersections of rays with the texture boundaries.
    // If a result for vertex of the cube, there will be one intersection, but we will ignore it.
    IntersectionResult intersectionResult = checkIntersection(mappedPosition, directionVector_rotate, x_min, x_max, y_min, y_max, z_min, z_max);
    
    if(intersectionResult.valid_intersection_count != 2){
        args.outputData[index + 0] = modelParameter.backgroundColor.r * 255.0;
        args.outputData[index + 1] = modelParameter.backgroundColor.g * 255.0;
        args.outputData[index + 2] = modelParameter.backgroundColor.b * 255.0;
        return;
    }
    
    float t_far = max(intersectionResult.t_1, intersectionResult.t_2);
    float t_near = min(intersectionResult.t_1, intersectionResult.t_2);
    
    
    float boundaryWidth = 0.01;
    
    float renderingStepAdditionalRatio = 1.0f;
    if(flags & (1 << ADAPTIVE)){
        renderingStepAdditionalRatio *= scaleRatio;
    }
    

    float3 channel_1 = modelParameter.color.ch1.rgb;
    float3 channel_2 = modelParameter.color.ch2.rgb;
    float3 channel_3 = modelParameter.color.ch3.rgb;
    float3 channel_4 = modelParameter.color.ch4.rgb;
    
    
    // The sampling coordinates along the ray direction are at the behind, inside, or in front of the volume.
    uint8_t state = BEHIND_VOLUME;
    
    // Accumulated color (C) and opacity (A) for volume rendering.
    float4 Cin = float4(modelParameter.backgroundColor, 0);
    float4 Cout = float4(modelParameter.backgroundColor, 0);
    
    
    for (float ts = t_far ; ts >=  max(t_near, radius - modelParameter.sliceNo) ; ts-= modelParameter.renderingStep * renderingStepAdditionalRatio ){
        float4 currentPos = float4((mappedPosition.xyz + ts * directionVector_rotate.xyz), 1);
        float4 coordinatePos = centeringToViewMatrix * currentPos;
        
        float3 texCoordinate = (flags & (1 << FLIP)) ?
        float3(coordinatePos.x / float(width),
               coordinatePos.y / float(height),
               1.0f - coordinatePos.z / (depth * scale_Z)) :
        float3(coordinatePos.x / float(width),
               coordinatePos.y / float(height),
               coordinatePos.z / (depth * scale_Z)) ;
        
        float4 Cvoxel;
        
        if (texCoordinate.x < modelParameter.trimX_min || texCoordinate.x > modelParameter.trimX_max ||
            texCoordinate.y < modelParameter.trimY_min || texCoordinate.y > modelParameter.trimY_max ||
            texCoordinate.z < modelParameter.trimZ_min || texCoordinate.z > modelParameter.trimZ_max){
            
            if (state == INSIDE_VOLUME){
                // If the sampling has exited the bounding box of the 3D texture from inside to outside,
                // then terminate the sampling and exit the loop.
                state = FRONT_VOLUME;
                break;
                
            }else{
                // Skip processing until the sampling point moves from behind to inside the volume.
                continue;
            }
            
        }else{
            // Render the bounding box when it is turned ON.
            if(flags & (1 << BOX)){
                if ((texCoordinate.x < boundaryWidth && texCoordinate.y < boundaryWidth) ||
                    (texCoordinate.x < boundaryWidth && texCoordinate.z < boundaryWidth) ||
                    
                    (texCoordinate.x < boundaryWidth && texCoordinate.y > (1.0 - boundaryWidth)) ||
                    (texCoordinate.x < boundaryWidth && texCoordinate.z > (1.0 - boundaryWidth)) ||
                    
                    (texCoordinate.x > (1.0 - boundaryWidth) && texCoordinate.y < boundaryWidth) ||
                    (texCoordinate.x > (1.0 - boundaryWidth) && texCoordinate.z < boundaryWidth) ||
                    
                    (texCoordinate.x > (1.0 - boundaryWidth) && texCoordinate.y > (1.0 - boundaryWidth)) ||
                    (texCoordinate.x > (1.0 - boundaryWidth) && texCoordinate.z > (1.0 - boundaryWidth)) ||
                    
                    (texCoordinate.y < boundaryWidth && texCoordinate.z < boundaryWidth) ||
                    (texCoordinate.y < boundaryWidth && texCoordinate.z > (1.0 - boundaryWidth)) ||
                    
                    (texCoordinate.y > (1.0 - boundaryWidth) && texCoordinate.z < boundaryWidth) ||
                    (texCoordinate.y > (1.0 - boundaryWidth) && texCoordinate.z > (1.0 - boundaryWidth))
                    
                    ){
                    
                    Cin = Cout;
                    
                    // Color and alpha definition for boundary box
                    Cvoxel = float4(0.85, 0.85, 0.85, 0.85);
                    float Alpha = 0.55;
                    
                    Cout = (1.0 - Alpha) * Cin + Alpha *  Cvoxel;
                    
                    continue;
                }
            }
            
            // When 'Crop' is ON, render only one side of the cutting plane.
            // If set to display the cutting surface, render both fragments and the cutting plane.
            if(flags & (1 << CROP_LOCK)){
                // geometorical transformation in cropped setting
                float3 directionVector_crop = quatMul(modelParameter.cropLockQuaternions, directionVector.xyz);
                float4 directionVector_crop_rotate = float4(directionVector_crop, 0);
                float4 mappedPosition_crop = quatMul(modelParameter.cropLockQuaternions, uniformedThreadPosition);
                
                float crop_ts =  radius - modelParameter.cropSliceNo ;
                
                float4 currentPos_crop = float4(mappedPosition_crop.xyz + crop_ts * directionVector_crop_rotate.xyz, 1);
                float4 coordinatePos_crop = centeringToViewMatrix * currentPos_crop;
                
                
                float3 _vec = coordinatePos.xyz - coordinatePos_crop.xyz;
                float t_crop = dot(_vec, directionVector_crop);
                
                
                if(flags & (1 << PLANE)){
                    float threath = 4.5;
                    
                    if(t_crop > threath){
                        // same side
                        
                    }else if (t_crop <= threath && t_crop >= -threath){
                        Cvoxel = float4(0.85, 0.85, 0.85, 0.85);
                        
                        Cin = Cout;
                        
                        float Alpha = 0.07;
                        
                        Cout = (1.0 - Alpha) * Cin + Alpha * Cvoxel;
                        
                        continue;
                        
                    }else if (t_crop < -threath){
                        // opposite side
                        
                    }
                    
                }else{
                    if (flags & (1 << CROP_TOGGLE)){
                        if(t_crop > 0){
                            Cvoxel = float4(0, 0, 0, 0);
                            
                            Cin = Cout;
                            
                            float Alpha = 0;
                            
                            Cout = (1.0 - Alpha) * Cin + Alpha * Cvoxel;
                            
                            continue;
                            
                        }else{
                            
                        }
                        
                    }else{
                        if(t_crop < 0){
                            Cvoxel = float4(0, 0, 0, 0);
                            
                            Cin = Cout;
                            
                            float Alpha = 0;
                            
                            Cout = (1.0 - Alpha) * Cin + Alpha * Cvoxel;
                            
                            continue;
                            
                        }else{
                            
                        }
                    }
                }
            }
            
        }
        
        //
        // Begin main sampling and compositing process.
        //
        
        state = INSIDE_VOLUME;
        
        Cin = Cout;
        
        Cvoxel = (float4)args.tex.sample(args.smp, texCoordinate);
        
        float4 intensityRatio = float4(modelParameter.intensityRatio[0],
                                       modelParameter.intensityRatio[1],
                                       modelParameter.intensityRatio[2],
                                       modelParameter.intensityRatio[3]);
        
        Cvoxel *= intensityRatio;
        
        Cout.r = max(Cin.r, Cvoxel.r);
        Cout.g = max(Cin.g, Cvoxel.g);
        Cout.b = max(Cin.b, Cvoxel.b);
        Cout.a = max(Cin.a, Cvoxel.a);
    }
    
    float3 lut_c1 = Cout.r * channel_1;
    float3 lut_c2 = Cout.g * channel_2;
    float3 lut_c3 = Cout.b * channel_3;
    float3 lut_c4 = Cout.a * channel_4;
    
    float cR = max(max(lut_c1.r, lut_c2.r), max(lut_c3.r, lut_c4.r));
    float cG = max(max(lut_c1.g, lut_c2.g), max(lut_c3.g, lut_c4.g));
    float cB = max(max(lut_c1.b, lut_c2.b), max(lut_c3.b, lut_c4.b));
    
    args.outputData[index + 0] = uint8_t(clamp(cR, 0.0f, 1.0f) * 255.0);
    args.outputData[index + 1] = uint8_t(clamp(cG, 0.0f, 1.0f) * 255.0);
    args.outputData[index + 2] = uint8_t(clamp(cB, 0.0f, 1.0f) * 255.0);
    
    return;
    
}


