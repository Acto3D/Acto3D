// Label: Viridis (Quad)
// Author: Naoki Takeshita
// Description: (Sample) A shader for approximating the Viridis colormap. \nViridis is linear with respect to lightness but non-linear with respect to RGB, \nhence it is just an approximation. Scale bar will not be correct.


constant float3 colors_at_key_points[] = {
    // These values are obteined in matplotlib using `viridis([0,0.25,0.5,0.75,1.0])[:,:-1]`
    float3(0.267004, 0.004874, 0.329415),  // Viridis Start Color
    float3(0.229739, 0.322361, 0.545706),  // Viridis 25%
    float3(0.127568, 0.566949, 0.550556),  // Viridis 50%
    float3(0.369214, 0.788888, 0.382914),  // Viridis 75%
    float3(0.993248, 0.906157, 0.143936)   // Viridis End Color
};
constant float key_points[] = {0.0, 0.25, 0.5, 0.75, 1.0};

float3 interpolateColors(float value) {
    for (int i = 0; i < 4; ++i) {
        if (value <= key_points[i + 1]) {
            float fraction = (value - key_points[i]) / (key_points[i + 1] - key_points[i]);
            return mix(colors_at_key_points[i], colors_at_key_points[i + 1], fraction);
        }
    }
    return colors_at_key_points[4];
}


kernel void SAMPLE_QUAD_CHANNEL_RENDER_VIRIDIS_CM(device RenderingArguments    &args  [[buffer(0)]],
                                                  uint2                     position  [[thread_position_in_grid]]){
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
    
    
    uint halfViewSize = viewSize / 2;
    uint2 scaledPosition = uint2(float2(position) / 2.0f);
    uint2 scaledPosition_for_c0 = scaledPosition;
    uint2 scaledPosition_for_c1 = scaledPosition + uint2(halfViewSize, 0);
    uint2 scaledPosition_for_c2 = scaledPosition + uint2(0, halfViewSize);
    uint2 scaledPosition_for_c3 = scaledPosition + halfViewSize;
    
    uint index_0 = (scaledPosition_for_c0.y * viewSize + scaledPosition_for_c0.x) * 3;
    uint index_1 = (scaledPosition_for_c1.y * viewSize + scaledPosition_for_c1.x) * 3;
    uint index_2 = (scaledPosition_for_c2.y * viewSize + scaledPosition_for_c2.x) * 3;
    uint index_3 = (scaledPosition_for_c3.y * viewSize + scaledPosition_for_c3.x) * 3;
    
    
    float4 currentThreadPosition = float4(position.x, position.y, 0, 1);
    
    float scale_Z = modelParameter.zScale;
    
    uint16_t pointSetCount = args.pointSetCount;
    constant float3* pointSet = args.pointSet;
    uint16_t pointSelectedIndex = args.pointSelectedIndex;
    
    
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
        for(int c=0; c<3; c++){
            args.outputData[index_0 + c] =  modelParameter.backgroundColor[c] * 255.0;
            args.outputData[index_1 + c] =  modelParameter.backgroundColor[c] * 255.0;
            args.outputData[index_2 + c] =  modelParameter.backgroundColor[c] * 255.0;
            args.outputData[index_3 + c] =  modelParameter.backgroundColor[c] * 255.0;
        }
        return;
    }
    
    // This is a macro for MPR display.
    // You can terminate the process here when displaying MPR.
    if(flags & (1 << MPR)){
        
        float ts = radius - modelParameter.sliceNo ;
        float4 currentPos = float4(mappedPosition.xyz + ts * directionVector_rotate.xyz, 1);
        float4 coordinatePos = centeringToViewMatrix * currentPos;
        float width = args.tex.get_width();
        float height = args.tex.get_height();
        float depth = args.tex.get_depth();
        float3 texCoordinate = (flags & (1 << FLIP)) ?
        float3(coordinatePos.x / float(width),
               coordinatePos.y / float(height),
               1.0f - coordinatePos.z / ((depth) * scale_Z)) :
        float3(coordinatePos.x / float(width),
               coordinatePos.y / float(height),
               coordinatePos.z / ((depth) * scale_Z)) ;
        
        float4 Cvoxel;
        
        if (texCoordinate.x < modelParameter.trimX_min || texCoordinate.x > modelParameter.trimX_max ||
            texCoordinate.y < modelParameter.trimY_min || texCoordinate.y > modelParameter.trimY_max ||
            texCoordinate.z < modelParameter.trimZ_min || texCoordinate.z > modelParameter.trimZ_max){
            for(int c=0; c<3; c++){
                args.outputData[index_0 + c] =  modelParameter.backgroundColor[c] * 255.0;
                args.outputData[index_1 + c] =  modelParameter.backgroundColor[c] * 255.0;
                args.outputData[index_2 + c] =  modelParameter.backgroundColor[c] * 255.0;
                args.outputData[index_3 + c] =  modelParameter.backgroundColor[c] * 255.0;
            }
        }else{
            Cvoxel = (float4)args.tex.sample(args.smp, texCoordinate);
            Cvoxel *= float4(modelParameter.intensityRatio[0],
                             modelParameter.intensityRatio[1],
                             modelParameter.intensityRatio[2],
                             modelParameter.intensityRatio[3]);
            
            
            
            float3 lut_c1 = interpolateColors(Cvoxel[0]);
            float3 lut_c2 = interpolateColors(Cvoxel[1]);
            float3 lut_c3 = interpolateColors(Cvoxel[2]);
            float3 lut_c4 = interpolateColors(Cvoxel[3]);
            
            for(int c=0; c<3; c++){
                args.outputData[index_0 + c] = uint8_t(clamp(lut_c1[c] * 255.0f, 0.0f, 255.0f));
                args.outputData[index_1 + c] = uint8_t(clamp(lut_c2[c] * 255.0f, 0.0f, 255.0f));
                args.outputData[index_2 + c] = uint8_t(clamp(lut_c3[c] * 255.0f, 0.0f, 255.0f));
                args.outputData[index_3 + c] = uint8_t(clamp(lut_c4[c] * 255.0f, 0.0f, 255.0f));
            }
            
            
        }
        
        
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
        for(int c=0; c<3; c++){
            args.outputData[index_0 + c] =  modelParameter.backgroundColor[c] * 255.0;
            args.outputData[index_1 + c] =  modelParameter.backgroundColor[c] * 255.0;
            args.outputData[index_2 + c] =  modelParameter.backgroundColor[c] * 255.0;
            args.outputData[index_3 + c] =  modelParameter.backgroundColor[c] * 255.0;
        }
        
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
    
    
    // Accumulated color (C) and opacity (A) for volume rendering.
    float4 Cin = 0;
    float4 Cout = 0 ;
    float4 Ain = 0;
    float4 Aout = 0;
    
    
    for (float ts = max(t_near, radius - modelParameter.sliceNo) ; ts <=  t_far  ; ts+= modelParameter.renderingStep * renderingStepAdditionalRatio){
        
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
            
            // If trimming is applied in the XYZ directions using the GUI slider, areas outside the specified range are not processed.
            continue;
            
        }else{
            // Render the bounding box when it is turned ON.
            if(flags & (1 << BOX)){
                if(isOnBoundaryEdge(texCoordinate, boundaryWidth)){
                    
                    Cin = Cout;
                    Ain = Aout;
                    
                    // Color and alpha definition for boundary box
                    Cvoxel = float4(0.85, 0.85, 0.85, 0.85);
                    float Alpha = 0.55;
                    
                    Cout = Cin + Cvoxel * (1.0 - Ain) * Alpha;
                    Aout = Ain + (1.0 - Ain) * Alpha;
                    
                    continue;
                }
            }
            
            // When 'Crop' is ON, render only one side of the cutting plane.
            // If set to display the cutting surface, render both fragments and the cutting plane.
            if(flags & (1 << CROP_LOCK)){
                // Geometorical transformation in cropped setting
                float3 directionVector_crop = quatMul(modelParameter.cropLockQuaternions, directionVector.xyz);
                float4 directionVector_crop_rotate = float4(directionVector_crop, 0);
                float4 mappedPosition_crop = quatMul(modelParameter.cropLockQuaternions, uniformedThreadPosition);
                
                float crop_ts =  radius - modelParameter.cropSliceNo ;
                
                float4 currentPos_crop = float4(mappedPosition_crop.xyz + crop_ts * directionVector_crop_rotate.xyz, 1);
                float4 coordinatePos_crop = centeringToViewMatrix * currentPos_crop;
                
                
                float3 _vec = coordinatePos.xyz - coordinatePos_crop.xyz;
                float t_crop = dot(_vec, directionVector_crop);
                
                if(flags & (1 << PLANE)){
                    float threshold_plane_thickness = 4.5;
                    
                    if(t_crop > threshold_plane_thickness){
                        // same side
                        
                    }else if (abs(t_crop) <= threshold_plane_thickness){
                        Cin = Cout;
                        Ain = Aout;
                        
                        Cvoxel = float4(0.85, 0.85, 0.85, 0.85);
                        float Alpha = 0.07;
                        
                        Cout = Cin + Cvoxel * (1.0 - Ain) * Alpha;
                        Aout = Ain + (1.0 - Ain) * Alpha;
                        
                        continue;
                        
                    }else if (t_crop < -threshold_plane_thickness){
                        // opposite side
                        
                    }
                    
                }else{
                    if (flags & (1 << CROP_TOGGLE)){
                        if(t_crop > 0){
                            Cin = Cout;
                            Ain = Aout;
                            
                            Cvoxel = float4(0, 0, 0, 0);
                            float Alpha = 0;
                            
                            Cout = Cin + Cvoxel * (1.0 - Ain) * Alpha;
                            Aout = Ain + (1.0 - Ain) * Alpha;
                            
                            continue;
                            
                        }else{
                            
                        }
                        
                    }else{
                        if(t_crop < 0){
                            Cin = Cout;
                            Ain = Aout;
                            
                            Cvoxel = float4(0, 0, 0, 0);
                            half Alpha = 0;
                            
                            Cout = Cin + Cvoxel * (1.0 - Ain) * Alpha;
                            Aout = Ain + (1.0 - Ain) * Alpha;
                            
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
        
        Cin = Cout;
        Ain = Aout;
        
        Cvoxel = args.tex.sample(args.smp, texCoordinate);
        
        float4 intensityRatio = float4(modelParameter.intensityRatio[0],
                                       modelParameter.intensityRatio[1],
                                       modelParameter.intensityRatio[2],
                                       modelParameter.intensityRatio[3]);
        
        
        
        // Multiply the color by its intensity.
        Cvoxel *= intensityRatio;
        
        // Get opacity for the voxel
        
        // Although the texture is 8-bit with pixel values ranging from 0-255 for which we define opacity,
        // we're transferring to the GPU a transfer function with ten times the precision (to the first decimal place) for smoother results.
        // Hence, calculations are performed in the range of 0-2550 instead of 0-255.
        
        // When using the pixel value (C) that has considered the above intensity,
        // there are cases where the luminance value may exceed 2550, so it is clamped to 2550.
        // (No need to consider this if fetching opacity before multiplying pixel value with intensity.)
        
        float4 alpha = float4(pow(args.tone1[int(clamp(Cvoxel[0] * 2550.0f, 0.0f, 2550.0f))] ,modelParameter.alphaPower),
                              pow(args.tone2[int(clamp(Cvoxel[1] * 2550.0f, 0.0f, 2550.0f))] ,modelParameter.alphaPower),
                              pow(args.tone3[int(clamp(Cvoxel[2] * 2550.0f, 0.0f, 2550.0f))] ,modelParameter.alphaPower),
                              pow(args.tone4[int(clamp(Cvoxel[3] * 2550.0f, 0.0f, 2550.0f))] ,modelParameter.alphaPower));
        
        
        float4 light_intensity = modelParameter.light;
        
        if(flags & (1 << SHADE)){
            // Very simple light and shade
            
            float eps = 2;
            float3 gradient_diff[3] = {
                float3(1.0 / width, 0, 0) * eps,
                float3(0, 1.0 / height, 0)* eps,
                float3(0, 0, 1.0 / depth)* eps
            };
            
            // Calculate the gradient
            float4 gradient_x = Cvoxel - intensityRatio * args.tex.sample(args.smp, texCoordinate - gradient_diff[0]);
            float4 gradient_y = Cvoxel - intensityRatio * args.tex.sample(args.smp, texCoordinate - gradient_diff[1]);
            float4 gradient_z = Cvoxel - intensityRatio * args.tex.sample(args.smp, texCoordinate - gradient_diff[2]);
            
            float3 grad_0 = float3(gradient_x[0], gradient_y[0], gradient_z[0]);
            float3 grad_1 = float3(gradient_x[1], gradient_y[1], gradient_z[1]);
            float3 grad_2 = float3(gradient_x[2], gradient_y[2], gradient_z[2]);
            float3 grad_3 = float3(gradient_x[3], gradient_y[3], gradient_z[3]);
            
            float diffuse_ratio = modelParameter.shade;
            
            // The vector used for shading calculations is currently fixed at (1,1,0).
            float diffuse0 = diffuse_ratio * max(0.0f, dot(normalize(grad_0), normalize(float3(1,1,0))));
            float diffuse1 = diffuse_ratio * max(0.0f, dot(normalize(grad_1), normalize(float3(1,1,0))));
            float diffuse2 = diffuse_ratio * max(0.0f, dot(normalize(grad_2), normalize(float3(1,1,0))));
            float diffuse3 = diffuse_ratio * max(0.0f, dot(normalize(grad_3), normalize(float3(1,1,0))));
            
            light_intensity = float4(
                                     max(0.0f, light_intensity[0] - diffuse0),
                                     max(0.0f, light_intensity[1] - diffuse1),
                                     max(0.0f, light_intensity[2] - diffuse2),
                                     max(0.0f, light_intensity[3] - diffuse3)
                                     );
            
        }
        
        Cout = Cin + Cvoxel * light_intensity * (1.0f - Ain) * alpha;
        Aout = Ain + (1.0f - Ain) * alpha;
        
        
        
        // Render a small sphere at the specified coordinate if it's marked within the space.
        // Note: Processing speed may be affected if there are many registered coordinates.
        
        // Sphere radius definition
        float ballRadius = 20.0f;
        
        for (uint8_t p=0; p<pointSetCount; p++){
            Cin = Cout;
            Ain = Aout;
            
            float3 _vec = coordinatePos.xyz - pointSet[p];
            float _length = length(_vec);
            
            if(_length < ballRadius){
                float _ballColor = pow(1.0f - (_length / ballRadius) * 0.3, 2);
                float _ballAlpha = 1.0f - (_length / ballRadius);
                
                // For more soft rendering result, use the following code.
                // float _ballAlpha = pow(1.0f - (_length / ballRadius), 2);
                
                if(p == pointSelectedIndex){
                    // Brighter for currently selected point
                    _ballColor += 0.25;
                }
                
                Cout = Cin + (1.0 - Ain) * _ballColor * _ballAlpha;
                Aout = Ain + (1.0 - Ain) * _ballAlpha;
            }
        }
        
        
    }
    
    float3 lut_c1 = interpolateColors(Cout[0]);
    float3 lut_c2 = interpolateColors(Cout[1]);
    float3 lut_c3 = interpolateColors(Cout[2]);
    float3 lut_c4 = interpolateColors(Cout[3]);
    
    for(int c=0; c<3; c++){
        args.outputData[index_0 + c] = uint8_t(clamp(lut_c1[c] * 255.0f, 0.0f, 255.0f));
        args.outputData[index_1 + c] = uint8_t(clamp(lut_c2[c] * 255.0f, 0.0f, 255.0f));
        args.outputData[index_2 + c] = uint8_t(clamp(lut_c3[c] * 255.0f, 0.0f, 255.0f));
        args.outputData[index_3 + c] = uint8_t(clamp(lut_c4[c] * 255.0f, 0.0f, 255.0f));
    }
    
    
    return;
    
}

