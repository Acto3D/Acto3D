//
//  segment3Dshader.metal
//  Acto3D
//
//  Created by Naoki Takeshita on 2023/01/05.
//

// This file contains kernels related to 3D segmentation.
// Generate MPR (Multi-Planar Reconstruction).
// Position the Texture and Mask images.
// Compute K-means clustering.


kernel void createMprForSegment(device uint8_t                  *outputData [[buffer(0)]],
                                constant VolumeData            &meta [[buffer(1)]],
                                constant RenderingParameters   &modelParameter [[buffer(2)]],
                                constant float4                 &quaternions [[buffer(3)]],
                                device uint8_t                  *outputDataBaseCh [[buffer(4)]],
                                constant uint8_t                  &channel [[buffer(5)]],
                                constant uint8_t                  &useMaskTexture [[buffer(6)]],
                                constant float                  &maskAlpha [[buffer(7)]],
                                constant float                  &edgeThreshold [[buffer(8)]],
                                texture3d<float, access::sample> tex [[texture(0)]],
                                texture3d<float, access::sample> maskTexture [[texture(1)]],
                                sampler smp                     [[sampler(0)]],
                                //                    texture3d<half, access::read_write> tex [[texture(0)]],
                                uint2                           position [[thread_position_in_grid]]){
    if (position.x >= meta.outputImageWidth || position.y >= meta.outputImageHeight){
        return;
    }
    
    // index for linear position
    uint index = (position.y * meta.outputImageWidth + position.x) * 3;
    uint indexInGray = position.y * meta.outputImageWidth + position.x;
    
    float4 curPos = float4(position.x, position.y, 0, 1);
    
    float scale = modelParameter.scale;
    float scaleMatRatio = 1.0 / scale;
    
    float scale_Z = modelParameter.zScale;
    
    float4x4 matrix_centering = float4x4(1, 0, 0, 0,
                                         0, 1, 0, 0,
                                         0, 0, 1, 0,
                                         -(meta.outputImageWidth) / 2.0, -(meta.outputImageHeight) / 2.0, 0, 1);
    
    float4x4 scaleMat = float4x4(scaleMatRatio, 0, 0, 0,
                                 0, scaleMatRatio, 0, 0,
                                 0, 0, 1.0, 0,
                                 0, 0, 0, 1.0);
    
    float4x4 matrix_centering_toView = float4x4(1, 0, 0, 0,
                                                0, 1, 0, 0,
                                                0, 0, 1, 0,
                                                (meta.inputImageWidth) / 2.0,
                                                (meta.inputImageHeight) / 2.0,
                                                (meta.inputImageDepth) * scale_Z / 2.0, 1);
    
    float4x4 transferMat = float4x4(1, 0, 0, 0,
                                    0, 1, 0, 0,
                                    0, 0, 1.0, 0,
                                    modelParameter.translationX, modelParameter.translationY, 0, 1.0);
    
    float4 directionVector = float4(0,0,1,0);
    float4 directionVector_rotate = float4(quatMul(quaternions, directionVector.xyz), 0);
    
    float3 pos = (transferMat * scaleMat * matrix_centering * curPos).xyz;
    
    float4 mappedXYZt = float4(quatMul(quaternions,  pos), 1);
    
    float radius = modelParameter.sliceMax / 2.0;
    
    if (length(mappedXYZt.xyz) > radius){
        outputData[index + 0] = 0;
        outputData[index + 1] = 0;
        outputData[index + 2] = 0;
        return;
    }
    
    
    float z_min = -meta.inputImageDepth * scale_Z / 2.0;
    float z_max = meta.inputImageDepth * scale_Z / 2.0;
    
    float t_far = (z_max - mappedXYZt.z) / directionVector_rotate.z;
    float t_near = (z_min - mappedXYZt.z) / directionVector_rotate.z;
    
    float x_far = mappedXYZt.x + t_far * directionVector_rotate.x;
    float x_near = mappedXYZt.x + t_near * directionVector_rotate.x;
    
    float y_far = mappedXYZt.y + t_far * directionVector_rotate.y;
    float y_near = mappedXYZt.y + t_near * directionVector_rotate.y;
    
    if ((x_far < -meta.inputImageWidth/2.0 && x_near < -meta.inputImageWidth/2.0) ||
        (x_far > meta.inputImageWidth/2.0 && x_near > meta.inputImageWidth/2.0) ||
        (y_far < -meta.inputImageHeight/2.0 && y_near < -meta.inputImageHeight/2.0) ||
        (y_far > meta.inputImageHeight/2.0 && y_near > meta.inputImageHeight/2.0) ){
        
        outputData[index + 0] = 0;
        outputData[index + 1] = 0;
        outputData[index + 2] = 0;
        return;
    }
    
    float ts = radius - modelParameter.sliceNo ;
    
    float3 current_mapped_pos = mappedXYZt.xyz + ts * directionVector_rotate.xyz;
    float4 currentPos = float4(current_mapped_pos, 1);
    float4 coordinatePos = matrix_centering_toView * currentPos;
    
    //TODO: consider FLIP
    float3 samplerPostion = float3(coordinatePos.x / (float(meta.inputImageWidth)),
                                   coordinatePos.y / (float(meta.inputImageHeight)),
                                   coordinatePos.z / ((meta.inputImageDepth) * scale_Z)) ;
    
    if (samplerPostion.x < modelParameter.trimX_min || samplerPostion.x > modelParameter.trimX_max ||
        samplerPostion.y < modelParameter.trimY_min || samplerPostion.y > modelParameter.trimY_max ||
        samplerPostion.z < modelParameter.trimZ_min || samplerPostion.z > modelParameter.trimZ_max){
        
        outputData[index + 0] = 0;
        outputData[index + 1] = 0;
        outputData[index + 2] = 0;
        outputDataBaseCh[indexInGray] = 0;
        
        return;
        
    }else{
        float4 Cvoxel = tex.sample(smp, samplerPostion);
        
        float4 CvoxelMask;
        
        // Areas to be reliably masked
        float3 c1 = float3(230, 159, 0) / 255.0f;
        
        // Boundary area
        float3 c2 = float3(86, 180, 233) / 255.0f;
        
        if(useMaskTexture == 1){
            // if Mask Texture is set, obtein mask for the coordinates from the mask texture
            CvoxelMask = maskTexture.sample(smp, samplerPostion);
            
            if(CvoxelMask.r > (1.0f - edgeThreshold)){
                // Areas to be reliably masked
                outputData[index + 0] = uint8_t((Cvoxel[channel] * (1.0 - maskAlpha) + c1[0] * (maskAlpha)) * 255.0f);
                outputData[index + 1] = uint8_t((Cvoxel[channel] * (1.0 - maskAlpha) + c1[1] * (maskAlpha)) * 255.0f);
                outputData[index + 2] = uint8_t((Cvoxel[channel] * (1.0 - maskAlpha) + c1[2] * (maskAlpha)) * 255.0f);
                
                outputDataBaseCh[indexInGray] = uint8_t(Cvoxel[channel] * 255.0);
                
            }else if(CvoxelMask.r > 0){
                // Boundary area
                outputData[index + 0] = uint8_t((Cvoxel[channel] * (1.0 - maskAlpha) + c2[0] * (maskAlpha)) * 255.0f);
                outputData[index + 1] = uint8_t((Cvoxel[channel] * (1.0 - maskAlpha) + c2[1] * (maskAlpha)) * 255.0f);
                outputData[index + 2] = uint8_t((Cvoxel[channel] * (1.0 - maskAlpha) + c2[2] * (maskAlpha)) * 255.0f);
                
                outputDataBaseCh[indexInGray] = uint8_t(Cvoxel[channel] * 255.0);
                
            }else{
                outputData[index + 0] = uint8_t( Cvoxel[channel] * 255.0 );
                outputData[index + 1] = uint8_t( Cvoxel[channel] * 255.0 );
                outputData[index + 2] = uint8_t( Cvoxel[channel] * 255.0 );
                
                outputDataBaseCh[indexInGray] = uint8_t(Cvoxel[channel] * 255.0);
            }
            
        }else{
            // if Mask Texture is not set, simply sample from original texture for specified channel
            outputData[index + 0] = uint8_t( Cvoxel[channel] * 255.0 );
            outputData[index + 1] = uint8_t( Cvoxel[channel] * 255.0 );
            outputData[index + 2] = uint8_t( Cvoxel[channel] * 255.0 );
            
            outputDataBaseCh[indexInGray] = uint8_t(Cvoxel[channel] * 255.0);
        }
        
        
        return;
    }
    
    
}


kernel void createMaskTexture3D(constant VolumeData            &meta [[buffer(0)]],
                                constant RenderingParameters   &modelParameter [[buffer(1)]],
                                constant uint16_t               &sliceNo [[buffer(2)]],
                                constant float4                 &quaternions [[buffer(3)]],
                                constant float               &rectLeft [[buffer(4)]],
                                constant float               &rectTop [[buffer(5)]],
                                constant float               &viewScale [[buffer(6)]],
                                constant float               &frameWidth [[buffer(7)]],
                                constant float               &frameHeight [[buffer(8)]],
                                constant uint8_t               &sliceDir [[buffer(9)]],
                                texture3d<half, access::sample> maskTexture_in [[texture(0)]],
                                texture3d<half, access::write> maskTexture_out [[texture(1)]],
                                sampler        smp [[ sampler(0) ]],
                                ushort3                           position [[thread_position_in_grid]]){
    
    
    if (position.x >= maskTexture_in.get_width() ||
        position.y >= maskTexture_in.get_height() ||
        position.z >= maskTexture_in.get_depth()){
        return;
    }
    
    float pointXinMPRimg = (rectLeft + position.x ) - ((frameWidth) / 2.0) / viewScale;
    float pointYinMPRimg = (rectTop + position.y ) - ((frameHeight) / 2.0) / viewScale;
    
    float4 centeredPosition = float4(pointXinMPRimg, pointYinMPRimg, 0, 1);
    
    float4x4 transferMat = float4x4(1, 0, 0, 0,
                                    0, 1, 0, 0,
                                    0, 0, 1, 0,
                                    modelParameter.translationX, modelParameter.translationY, 0, 1.0);
    
    
    float scaleMatRatio = 1.0 / modelParameter.scale;
    float scale_Z = modelParameter.zScale;
    
    float4x4 scaleMat = float4x4(scaleMatRatio, 0, 0, 0,
                                 0, scaleMatRatio, 0, 0,
                                 0, 0, 1.0, 0,
                                 0, 0, 0, 1.0);
    
    
    
    // edit 20240206
    float4x4 matrix_centering_toView = float4x4(1, 0, 0, 0,
                                                0, 1, 0, 0,
                                                0, 0, 1, 0,
                                                (meta.inputImageWidth) / 2.0,
                                                (meta.inputImageHeight) / 2.0,
                                                (meta.inputImageDepth) * scale_Z / 2.0,
                                                1);
    
    
    float radius = modelParameter.sliceMax / 2.0;
    
    float ts;
    if(sliceDir == 0){
        ts = radius - sliceNo - (position.z) ;
    }else{
        ts = radius - sliceNo + (position.z) ;
    }
    
    float4 directionVector = float4(0,0,1,0);
    
    float4 directionVector_rotate = quatMul(quaternions, directionVector);
    
    float4 pos = transferMat * scaleMat * centeredPosition;
    
    float4 mappedXYZ = quatMul(quaternions, pos);
    float4 mappedPos = mappedXYZ + ts * directionVector_rotate;
    float4 coordPos = matrix_centering_toView * mappedPos;
    
    float3 samplerPostion = float3(coordPos.x / float(meta.inputImageWidth),
                                   (coordPos.y / float(meta.inputImageHeight)),
                                   (coordPos.z / ((meta.inputImageDepth) * scale_Z))
                                   ) ;
    
    
    if(all(samplerPostion >= 0) && all(samplerPostion <= 1.0)){
        float inputWidth = maskTexture_in.get_width();
        float inputHeight = maskTexture_in.get_height();
        float inputDepth = maskTexture_in.get_depth();
        
        
        half4 maskIntensity = maskTexture_in.sample(smp, float3(position.x / (inputWidth),
                                                                position.y / (inputHeight),
                                                                position.z / (inputDepth)));
        //        maskIntensity = maskTexture_in.read(position);
        
        
        ushort3 out_coord = ushort3((samplerPostion.x * (maskTexture_out.get_width())),
                                    (samplerPostion.y * (maskTexture_out.get_height())),
                                    (samplerPostion.z * (maskTexture_out.get_depth())));
        
        
        if(maskIntensity.r != 0){
            maskTexture_out.write(half4(1.0,0,0,0), out_coord);
            
            //            for(int l = -1; l == 1; l++){
            //                for(int m = -1; m == 1; m++){
            //                    for(int n = -1; n == 1; n++){
            //                        maskTexture_out.write(half4(1.0,0,0,0), out_coord + ushort3(l,m,n));
            //                    }
            //                }
            //            }
        }
    }
    
    
}



// A kernel function to compute the cluster membership of a grayscale pixel in a 2D image using the k-means algorithm.
kernel void calcKmeansCluster(constant uint8_t             *inputPixel [[buffer(0)]],
                              constant uint                &pixelCounts [[buffer(1)]],
                              constant float               *centers [[buffer(2)]],
                              constant uint8_t             &n_clusters [[buffer(3)]],
                              device uint8_t               *pixelCluster [[buffer(4)]],
                              volatile device atomic_uint  *clusterCounts  [[buffer(5)]],
                              volatile device atomic_uint  *clusterIntensity  [[buffer(6)]],
                              device uint8_t               *clusterImagePixel [[buffer(7)]],
                              uint                         position [[thread_position_in_grid]]){
    if(position >= pixelCounts){
        return;
    }
    
    // Temporary buffer to store distances of the current pixel to each cluster centroid.
    // Assuming a maximum of 20 clusters for simplicity, as dynamic array sizes are not supported in Metal.
    float distance[20];
    
    for (int k = 0; k < n_clusters; k++){
        distance[k] = abs(float(inputPixel[position]) - centers[k]);
    }
    
    int min = INT_MAX;
    int minIndex = 0;
    
    for (int i = 0; i < n_clusters; i++)
    {
        if (distance[i] < min) {
            min = distance[i];
            minIndex = i;
        }
        
    }
    
    // minIndex: 距離が最小だったクラスタ番号＝このピクセルが所属すべきクラスタ番号となる
    // Assign the current pixel to the cluster which is closest (by index).
    pixelCluster[position] = minIndex;
    clusterImagePixel[position] = uint8_t(float(minIndex) / float(n_clusters) * 255.0);
    
    // このクラスタに所属したピクセルの個数が1つ増えたことになる
    // Atomically increase the count of pixels that belong to the found cluster.
    atomic_fetch_add_explicit(&clusterCounts[minIndex], 1, memory_order_relaxed);
    
    // Atomically update the sum of pixel intensities for the found cluster.
    atomic_fetch_add_explicit(&clusterIntensity[minIndex], inputPixel[position], memory_order_relaxed);
    
}


kernel void copySliceImageToTexture(texture3d<float, access::sample>        texIn [[texture(0)]],
                                texture3d<float, access::read_write>    texOut [[texture(1)]],
                                constant VolumeData                     &meta [[buffer(0)]],
                                constant RenderingParameters            &modelParameter [[buffer(1)]],
                                constant float4                         &quaternions [[buffer(2)]],
                                constant uint8_t                        &channel [[buffer(3)]],
                                constant bool                           &binary [[buffer(4)]],
                                constant bool                           &countPixel [[buffer(5)]],
                                device atomic_uint                      &counter [[buffer(6)]],
                                    constant float                  &edgeThreshold [[buffer(7)]],
                                sampler                                 smp [[ sampler(0) ]],
                                ushort3                                 position [[thread_position_in_grid]]){
    
    if (position.x >= meta.inputImageWidth || position.y >= meta.inputImageHeight || position.z >= meta.inputImageDepth){
        return;
    }
    
    // index for linear position
//    uint index = (position.y * meta.outputImageWidth + position.x) * 3;
//    uint indexInGray = position.y * meta.outputImageWidth + position.x;
    
    float4 curPos = float4(position.x, position.y, 0, 1);
    
    float scaleMatRatio = 1.0;
    float scale_Z = modelParameter.zScale;
    
    
    float4x4 matrix_centering = float4x4(1, 0, 0, 0,
                                         0, 1, 0, 0,
                                         0, 0, 1, 0,
                                         -(meta.inputImageWidth) / 2.0, -(meta.inputImageHeight) / 2.0, 0, 1);
    
    float4x4 scaleMat = float4x4(scaleMatRatio, 0, 0, 0,
                                 0, scaleMatRatio, 0, 0,
                                 0, 0, 1.0, 0,
                                 0, 0, 0, 1.0);
    
    float4x4 matrix_centering_toView = float4x4(1, 0, 0, 0,
                                                0, 1, 0, 0,
                                                0, 0, 1, 0,
                                                (meta.inputImageWidth) / 2.0,
                                                (meta.inputImageHeight) / 2.0,
                                                (meta.inputImageDepth) * scale_Z / 2.0, 1);
    
    float4x4 transferMat = float4x4(1, 0, 0, 0,
                                    0, 1, 0, 0,
                                    0, 0, 1.0, 0,
                                    0, 0, 0, 1.0);
    
    float4 directionVector = float4(0,0,1,0);
    float4 directionVector_rotate = float4(quatMul(quaternions, directionVector.xyz), 0);
    
    float3 pos = (transferMat * scaleMat * matrix_centering * curPos).xyz;
    
    float4 mappedXYZt = float4(quatMul(quaternions,  pos), 1);
    
    float radius = modelParameter.sliceMax / 2.0;
    
    if (length(mappedXYZt.xyz) > radius){
//        outputData[index + 0] = 0;
//        outputData[index + 1] = 0;
//        outputData[index + 2] = 0;
        return;
    }
    
    
    float z_min = -meta.inputImageDepth * scale_Z / 2.0;
    float z_max = meta.inputImageDepth * scale_Z / 2.0;
    
    float t_far = (z_max - mappedXYZt.z) / directionVector_rotate.z;
    float t_near = (z_min - mappedXYZt.z) / directionVector_rotate.z;
    
    float x_far = mappedXYZt.x + t_far * directionVector_rotate.x;
    float x_near = mappedXYZt.x + t_near * directionVector_rotate.x;
    
    float y_far = mappedXYZt.y + t_far * directionVector_rotate.y;
    float y_near = mappedXYZt.y + t_near * directionVector_rotate.y;
    
    if ((x_far < -meta.inputImageWidth/2.0 && x_near < -meta.inputImageWidth/2.0) ||
        (x_far > meta.inputImageWidth/2.0 && x_near > meta.inputImageWidth/2.0) ||
        (y_far < -meta.inputImageHeight/2.0 && y_near < -meta.inputImageHeight/2.0) ||
        (y_far > meta.inputImageHeight/2.0 && y_near > meta.inputImageHeight/2.0) ){
        
//        outputData[index + 0] = 0;
//        outputData[index + 1] = 0;
//        outputData[index + 2] = 0;
        return;
    }
    
    float ts = radius - modelParameter.sliceMax/2.0f - (float(meta.inputImageDepth) - position.z * 2.0f) * scale_Z / 2.0f;
    
    float3 current_mapped_pos = mappedXYZt.xyz + ts * directionVector_rotate.xyz;
    float4 currentPos = float4(current_mapped_pos, 1);
    float4 coordinatePos = matrix_centering_toView * currentPos;
    
    //TODO: consider FLIP
    float3 samplerPostion = float3(coordinatePos.x / (float(meta.inputImageWidth)),
                                   coordinatePos.y / (float(meta.inputImageHeight)),
                                   coordinatePos.z / ((meta.inputImageDepth) * scale_Z)) ;
    
    if (samplerPostion.x < modelParameter.trimX_min || samplerPostion.x > modelParameter.trimX_max ||
        samplerPostion.y < modelParameter.trimY_min || samplerPostion.y > modelParameter.trimY_max ||
        samplerPostion.z < modelParameter.trimZ_min || samplerPostion.z > modelParameter.trimZ_max){
        
//        outputData[index + 0] = 0;
//        outputData[index + 1] = 0;
//        outputData[index + 2] = 0;
//        outputDataBaseCh[indexInGray] = 0;
        
        return;
        
    }else{
//        float4 Cvoxel = tex.sample(smp, samplerPostion);
        
        float4 outputColor = texOut.read(position);
        
        float4 CvoxelMask = texIn.sample(smp, samplerPostion);
        
        if(CvoxelMask.r > (1.0f - edgeThreshold)){
            outputColor[channel] = 1.0;
            // Areas to be reliably masked
            if(countPixel == true){
                atomic_fetch_add_explicit(&counter, 1, memory_order_relaxed);
            }
        }
        
        
        texOut.write(outputColor, position);
        return;
    }
    
    
}


kernel void mapTextureToTexture(texture3d<float, access::sample>        texIn [[texture(0)]],
                                texture3d<float, access::read_write>    texOut [[texture(1)]],
                                constant VolumeData                     &meta [[buffer(0)]],
                                constant RenderingParameters            &modelParameter [[buffer(1)]],
                                constant float4                         &quaternions [[buffer(2)]],
                                constant uint8_t                        &channel [[buffer(3)]],
                                constant bool                           &binary [[buffer(4)]],
                                constant bool                           &countPixel [[buffer(5)]],
                                device atomic_uint                      &counter [[buffer(6)]],
                                sampler                                 smp [[ sampler(0) ]],
                                ushort3                                 position [[thread_position_in_grid]]){
    
    if (position.x >= meta.outputImageWidth || position.y >= meta.outputImageHeight){
        return;
    }
    
    uint dstTexWidth= texOut.get_width();
    uint dstTexHeight = texOut.get_height();
    uint dstTexDepth = texOut.get_depth();
    
    float4 curPos = float4(position.x, position.y, 0, 1);
    
    float scaleMatRatio = 1.0;
    
    float scale_Z = modelParameter.zScale;
    
    float4x4 matrix_centering = float4x4(1, 0, 0, 0,
                                         0, 1, 0, 0,
                                         0, 0, 1, 0,
                                         -(meta.outputImageWidth) / 2.0, -(meta.outputImageHeight) / 2.0, 0, 1);
    
    float4x4 scaleMat = float4x4(scaleMatRatio, 0, 0, 0,
                                 0, scaleMatRatio, 0, 0,
                                 0, 0, 1.0, 0,
                                 0, 0, 0, 1.0);
    
    float4x4 matrix_centering_toView = float4x4(1, 0, 0, 0,
                                                0, 1, 0, 0,
                                                0, 0, 1, 0,
                                                (meta.inputImageWidth) / 2.0,
                                                (meta.inputImageHeight) / 2.0,
                                                (meta.inputImageDepth) * scale_Z / 2.0,
                                                1);
    
    float4x4 transferMat = float4x4(1, 0, 0, 0,
                                    0, 1, 0, 0,
                                    0, 0, 1, 0,
                                    modelParameter.translationX, modelParameter.translationY, 0, 1.0);
    
    float4 directionVector = float4(0,0,1,0);
    float4 directionVector_rotate = float4(quatMul(quaternions, directionVector.xyz), 0);
    
    float3 pos = (transferMat * scaleMat * matrix_centering * curPos).xyz;
    
    float4 mappedXYZt = float4(quatMul(quaternions,  pos), 1);
    
    float radius = modelParameter.sliceMax / 2.0;
    
    if (length(mappedXYZt.xyz) > radius){
        return;
    }
    
    float z_min = -meta.inputImageDepth * scale_Z / 2.0;
    float z_max = meta.inputImageDepth * scale_Z / 2.0;
    
    float t_far = (z_max - mappedXYZt.z) / directionVector_rotate.z;
    float t_near = (z_min - mappedXYZt.z) / directionVector_rotate.z;
    
    float x_far = mappedXYZt.x + t_far * directionVector_rotate.x;
    float x_near = mappedXYZt.x + t_near * directionVector_rotate.x;
    
    float y_far = mappedXYZt.y + t_far * directionVector_rotate.y;
    float y_near = mappedXYZt.y + t_near * directionVector_rotate.y;
    
    if ((x_far < -meta.inputImageWidth/2.0 && x_near < -meta.inputImageWidth/2.0) ||
        (x_far > meta.inputImageWidth/2.0 && x_near > meta.inputImageWidth/2.0) ||
        (y_far < -meta.inputImageHeight/2.0 && y_near < -meta.inputImageHeight/2.0) ||
        (y_far > meta.inputImageHeight/2.0 && y_near > meta.inputImageHeight/2.0) ){
        
        return;
    }
    
    float ts = radius - position.z ;
    
    float4 currentPos = float4(mappedXYZt.xyz + ts * directionVector_rotate.xyz, 1);
    float4 coordinatePos = matrix_centering_toView * currentPos;
    
    
    float3 samplerPostion = float3(coordinatePos.x / (float(meta.inputImageWidth)),
                                   coordinatePos.y / (float(meta.inputImageHeight)),
                                   coordinatePos.z / ((meta.inputImageDepth) * scale_Z)) ;
    
    
    float4 CvoxelMask = texIn.sample(smp, samplerPostion);
    
    ushort3 writingPosition = ushort3(samplerPostion * float3(dstTexWidth ,
                                                              dstTexHeight,
                                                              dstTexDepth));
    
    float4 outputColor = texOut.read(writingPosition);
    
    // texIn: mask, texOut: outputTex
    
    if(outputColor[channel] != 1.0){
        if(binary == true){
            if(CvoxelMask.r > 0.5){
                outputColor[channel] = 1.0;
                if(countPixel == true){
                    atomic_fetch_add_explicit(&counter, 1, memory_order_relaxed);
                }
//            }else if (CvoxelMask.r > 0.5){
//                outputColor[channel] = 1.0;
//                if(countPixel == true){
//                    atomic_fetch_add_explicit(&counter, 1, memory_order_relaxed);
//                }
            }else{
                outputColor[channel] = 0;
            }
            
        }else{
            outputColor[channel] = CvoxelMask.r;
        }
        
        texOut.write(outputColor, writingPosition);
        
    }
    
}



kernel void shrinkMask(texture3d<half, access::read> texIn [[texture(0)]],
                       texture3d<half, access::read_write> texOut [[texture(1)]],
                       constant uint8_t  &channelIn [[buffer(0)]],
                       constant uint8_t  &channelOut [[buffer(1)]],
                       constant bool     &countPixel [[buffer(2)]],
                       constant uint8_t  &expansionSize [[buffer(3)]],
                       device atomic_uint &counter [[buffer(4)]],
                       uint3 gid [[thread_position_in_grid]]) {
    uint width = texIn.get_width();
    uint height = texIn.get_height();
    uint depth = texIn.get_depth();
    
    half4 targetValue = texOut.read(gid);
    
    half checkVoxelCount = 26.0h - half(expansionSize);
    
    
    if(gid.x > 0 && gid.x < width - 1 && gid.y > 0 && gid.y < height - 1 && gid.z > 0 && gid.z < depth - 1) {
        half sum = 0.0;
        
        // check 26 voxel surrounded by the target voxel
        for(int i = -1; i <= 1; i++) {
            for(int j = -1; j <= 1; j++) {
                for(int k = -1; k <= 1; k++) {
                    if(i != 0 || j != 0 || k != 0) { // ignore voxel center
                        //                        sum += texIn.read(uint3(gid.x + i, gid.y + j, gid.z + k))[channelIn] != 0 ? 1.0 : 0.0;
                        sum += texIn.read(uint3(gid.x + i, gid.y + j, gid.z + k))[channelIn];
                    }
                }
            }
        }
        
        // Set the target voxel to 1.0 based on the values of surrounding voxels.
        // The sum equals 26.0 if all surrounding voxels are 1.0.
        if (sum >= checkVoxelCount){
            targetValue[channelOut] = 1.0;
            texOut.write(targetValue, gid);
            
            if(countPixel) atomic_fetch_add_explicit(&counter, 1, memory_order_relaxed);
            
        }else{
            targetValue[channelOut] = 0.0;
            texOut.write(targetValue, gid);
        }
        
    } else {
        float currentVoxel = texIn.read(gid)[channelIn];
        
        if (currentVoxel == 1.0){
            targetValue[channelOut] = 1.0;
            texOut.write(targetValue, gid);
            
            if(countPixel) atomic_fetch_add_explicit(&counter, 1, memory_order_relaxed);
            
        }else{
            targetValue[channelOut] = 0.0;
            texOut.write(targetValue, gid);
        }
        
    }
}


/// transfer mask image to the texture
/// if `binary` is `true`, only Zero value will set to zero
kernel void transferTextureToTexture(texture3d<half, access::read>       texIn [[texture(0)]],
                                     texture3d<half, access::read_write>   texOut [[texture(1)]],
                                     constant uint8_t  &channelIn [[buffer(0)]],
                                     constant uint8_t  &channelOut [[buffer(1)]],
                                     ushort3           position [[thread_position_in_grid]]){
    float imageWidth = texIn.get_width();
    float imageHeight = texIn.get_height();
    float imageDepth = texIn.get_depth();
    
    if (position.x >= imageWidth || position.y >= imageHeight || position.z >= imageDepth){
        return;
    }
    
    half inValue = texIn.read(position)[channelIn];
    half4 outValue = texOut.read(position);
    
    outValue[channelOut] = inValue;
    
    texOut.write(outValue, position);
    
}

kernel void transferChannelToMask(texture3d<half, access::read> texIn [[texture(0)]],
                                  texture3d<half, access::write> texOut [[texture(1)]],
                                  constant  uint8_t &channel [[buffer(0)]],
                                  //                                  sampler   smp [[ sampler(0) ]],
                                  ushort3   position [[thread_position_in_grid]]){
    float imageWidth = texIn.get_width();
    float imageHeight = texIn.get_height();
    float imageDepth = texIn.get_depth();
    
    if (position.x >= imageWidth || position.y >= imageHeight || position.z >= imageDepth){
        return;
    }
    
    
    half4 inputColor = texIn.read(position);
    texOut.write(half4(inputColor[channel],0,0,0), position);
    
}


kernel void clear3DTexture(texture3d<half, access::write> outTexture [[texture(0)]],
                           uint3 gid [[thread_position_in_grid]]) {
    float imageWidth = outTexture.get_width();
    float imageHeight = outTexture.get_height();
    float imageDepth = outTexture.get_depth();
    
    if (gid.x >= imageWidth || gid.y >= imageHeight || gid.z >= imageDepth){
        return;
    }
    
    half4 zeroColor = half4(0.0, 0.0, 0.0, 0.0);
    outTexture.write(zeroColor, gid);
}


kernel void moment(constant uint8_t                *inputData [[buffer(0)]],
                   volatile device atomic_uint                 &m00 [[buffer(1)]],
                   volatile device atomic_uint                 &m10 [[buffer(2)]],
                   volatile device atomic_uint                 &m01 [[buffer(3)]],
                   constant uint16_t &imgWidth [[buffer(4)]],
                   constant uint16_t &imgHeight [[buffer(5)]],
                   uint2                           position [[thread_position_in_grid]]){
    
    
    
    if (position.x >= imgWidth || position.y >= imgHeight){
        return;
    }
    
    uint pos = position.y * imgWidth + position.x;
    
    if(inputData[pos] == 255){
        atomic_fetch_add_explicit(&m00, 1, memory_order_relaxed);
        atomic_fetch_add_explicit(&m10, position.x, memory_order_relaxed);
        atomic_fetch_add_explicit(&m01, position.y, memory_order_relaxed);
        
    }
    
}
