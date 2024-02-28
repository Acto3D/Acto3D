// Label: Template for Front To Back Rendering
// Author: Naoki Takeshita
// Description: Template for standard front to back rendering
kernel void TEMPLATE_FTB(device RenderingArguments    &args       [[buffer(0)]],
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
        args.outputData[index + 0] = modelParameter.backgroundColor.r * 255.0;
        args.outputData[index + 1] = modelParameter.backgroundColor.g * 255.0;
        args.outputData[index + 2] = modelParameter.backgroundColor.b * 255.0;
        return;
    }
    
    // This is a macro for MPR display.
    // You can terminate the process here when displaying MPR.
    if(flags & (1 << MPR)){
        SHOW_MPR
        
        // ------------------------------------------------
        // If, you want to show plot even in MPR view, use the following code.
        float ballRadius = 10.0f;
        for (uint8_t p=0; p<pointSetCount; p++){
            float ts = radius - modelParameter.sliceNo ;
            float4 currentPos = float4(mappedPosition.xyz + ts * directionVector_rotate.xyz, 1);
            float4 coordinatePos = centeringToViewMatrix * currentPos;
            float3 _vec = coordinatePos.xyz - pointSet[p];
            
            float _length = length(_vec);
            
            if(_length < ballRadius && _length > ballRadius - 2){
                args.outputData[index + 0] = 255;
                args.outputData[index + 1] = 255;
                args.outputData[index + 2] = 255;
            }
        }
        // ------------------------------------------------
        
        return;
    }
    
    // Maximum and minimum coordinates of the texture
    float z_max = depth * scale_Z / 2.0f;
    float z_min = -z_max;
    float x_max = width / 2.0f;
    float x_min = -x_max;
    float y_max = height / 2.0f;
    float y_min = -y_max;
    
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
    
    // Accumulated color (C) and opacity (A) for volume rendering.
    float4 Cin = 0;
    float4 Cout = 0 ;
    float4 Ain = 0;
    float4 Aout = 0;
    
    for (float ts = max(t_near, radius - modelParameter.sliceNo) ; ts <=  t_far ; ts+= modelParameter.renderingStep * renderingStepAdditionalRatio){
        
        float4 currentPos = float4((mappedPosition.xyz + ts * directionVector_rotate.xyz), 1);
        float4 coordinatePos = centeringToViewMatrix * currentPos;
        
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
        
        
        // Cvoxel is of type float4, accessed like Cvoxel[0] or Cvoxel[3].
        // It stores pixel values at the sampled coordinates as float values ranging from 0 to 1.0.
        // Depending on the number of channels in the image, values for each channel are stored in [0]-[3].
        // Attempting to access a non-existent channel does not result in an error, but returns zero.
        // Cvoxel can be accessed using [0]-[3], as well as .r, .g, .b, .a, or .x, .y, .z, .w.
        Cvoxel = args.tex.sample(args.smp, texCoordinate);
 
        /* Get opacity for the voxel */
        /*
         float4 alpha = float4(pow(args.tone1[int(clamp(Cvoxel.r * 2550.0f, 0.0f, 2550.0f))] ,modelParameter.alphaPower),
                               pow(args.tone2[int(clamp(Cvoxel.g * 2550.0f, 0.0f, 2550.0f))] ,modelParameter.alphaPower),
                               pow(args.tone3[int(clamp(Cvoxel.b * 2550.0f, 0.0f, 2550.0f))] ,modelParameter.alphaPower),
                               pow(args.tone4[int(clamp(Cvoxel.a * 2550.0f, 0.0f, 2550.0f))] ,modelParameter.alphaPower));
        */
        
        // The intensityRatio stores the brightness levels for each channel as specified in the GUI, in float format.
        // The default value is 0.
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
        
        // args.tone1 to args.tone4 store opacity for each channel's pixel values as floats in the range 0 to 1.0.
        // For example, to access the opacity for a pixel value of 128,
        //   use args.tone1[1280].
        
        // Here, the pow function is used to exponentiate the opacity from 0 to 1.0.
        // modelParameter.alphaPower, specified in the GUI and defaulting to 2, squares the opacity.
        float4 alpha = float4(pow(args.tone1[int(clamp(Cvoxel[0] * 2550.0f, 0.0f, 2550.0f))] ,modelParameter.alphaPower),
                              pow(args.tone2[int(clamp(Cvoxel[1] * 2550.0f, 0.0f, 2550.0f))] ,modelParameter.alphaPower),
                              pow(args.tone3[int(clamp(Cvoxel[2] * 2550.0f, 0.0f, 2550.0f))] ,modelParameter.alphaPower),
                              pow(args.tone4[int(clamp(Cvoxel[3] * 2550.0f, 0.0f, 2550.0f))] ,modelParameter.alphaPower));
        
        // While different opacities are defined for the four channels,
        // applying the same transparency to a specific voxel ensures the depth is rendered accurately.
        // If you wish to apply distinct transparencies for each channel, the following section is unnecessary.
        float alphaMax = max(alpha);
        
        float4 light_intensity = modelParameter.light;
        
        if(flags & (1 << SHADE)){
            // Very simple light and shade
            
            float eps = 2;
            float3 gradient_diff[3] = {
                float3(1.0 / width, 0, 0) * eps,
                float3(0, 1.0 / height, 0) * eps,
                float3(0, 0, 1.0 / depth) * eps
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
            
            Cvoxel *= light_intensity;
            
        }
        
        
        Cvoxel *= light_intensity;
        
        Cout = Cin + Cvoxel * (1.0f - Ain) * alphaMax;
        Aout = Ain + (1.0f - Ain) * alphaMax;
        
        
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
        
        
        // Early termination for front-to-back rendering
        // If the accumulated opacity surpasses a certain threshold, further processing can be skipped.
        
        // Setting a higher opacityThreshold results in an image closer to back-to-front rendering,
        // but at the cost of increased computation.
        // A realistic range for the threshold is between 0.9 and 0.99.
        float opacityThreshold = 0.99;
        if(max(max(Aout.x, Aout.y), max(Aout.z, Aout.a)) > opacityThreshold){
            break;
        }

        
    }
    
    float3 lut_c1 = Cout[0] * modelParameter.color.ch1.rgb;
    float3 lut_c2 = Cout[1] * modelParameter.color.ch2.rgb;
    float3 lut_c3 = Cout[2] * modelParameter.color.ch3.rgb;
    float3 lut_c4 = Cout[3] * modelParameter.color.ch4.rgb;
    
    float cR = max(lut_c1.r, lut_c2.r, lut_c3.r, lut_c4.r);
    float cG = max(lut_c1.g, lut_c2.g, lut_c3.g, lut_c4.g);
    float cB = max(lut_c1.b, lut_c2.b, lut_c3.b, lut_c4.b);
    
    args.outputData[index + 0] = uint8_t(clamp(cR * 255.0f, 0.0f, 255.0f));
    args.outputData[index + 1] = uint8_t(clamp(cG * 255.0f, 0.0f, 255.0f));
    args.outputData[index + 2] = uint8_t(clamp(cB * 255.0f, 0.0f, 255.0f));
    
    return;
    
}


