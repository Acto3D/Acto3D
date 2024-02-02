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
                                texture3d<half, access::sample> tex [[texture(0)]],
                                texture3d<half, access::sample> maskTexture [[texture(1)]],
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
                                         -meta.outputImageWidth / 2.0, -meta.outputImageHeight / 2.0, 0, 1);
    
    float4x4 scaleMat = float4x4(scaleMatRatio, 0, 0, 0,
                                 0, scaleMatRatio, 0, 0,
                                 0, 0, 1.0, 0,
                                 0, 0, 0, 1.0);
    
    float4x4 matrix_centering_toView = float4x4(1, 0, 0, 0,
                                                0, 1, 0, 0,
                                                0, 0, 1, 0,
                                                meta.inputImageWidth / 2.0, meta.inputImageHeight / 2.0, meta.inputImageDepth * scale_Z / 2.0, 1);
    
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
    float3 samplerPostion = float3(coordinatePos.x / float(meta.inputImageWidth),
                                   coordinatePos.y / float(meta.inputImageHeight),
                                   coordinatePos.z / (meta.inputImageDepth * scale_Z)) ;
    
    if (samplerPostion.x < modelParameter.trimX_min || samplerPostion.x > modelParameter.trimX_max ||
        samplerPostion.y < modelParameter.trimY_min || samplerPostion.y > modelParameter.trimY_max ||
        samplerPostion.z < modelParameter.trimZ_min || samplerPostion.z > modelParameter.trimZ_max){
        
        outputData[index + 0] = 0;
        outputData[index + 1] = 0;
        outputData[index + 2] = 0;
        outputDataBaseCh[indexInGray] = 0;
        
        return;
        
    }else{
        half4 Cvoxel = tex.sample(smp, samplerPostion);
    
        half4 CvoxelMask;
        
        if(useMaskTexture == 1){
            // if Mask Texture is set, obtein mask for the coordinates from the mask texture
            CvoxelMask = maskTexture.sample(smp, samplerPostion);
            
            if(CvoxelMask.r == 0){
                outputData[index + 0] = uint8_t( Cvoxel[channel] * 255.0 );
                outputData[index + 1] = uint8_t( Cvoxel[channel] * 255.0 );
                outputData[index + 2] = uint8_t( Cvoxel[channel] * 255.0 );
                
                outputDataBaseCh[indexInGray] = uint8_t(Cvoxel[channel] * 255.0);

            }else{
                // show mask image in Green color
                outputData[index + 0] = 0;
                outputData[index + 1] = 255;
//                outputData[index + 1] = uint8_t( CvoxelMask.r * 255.0 );
                outputData[index + 2] = 0;
                
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
    
    // MPR画像(元画像のoriginal sizeと同じsize)でboxを表示した座標 + スレッド位置 を0-1.0で
    // Display box coordinates on the MPR image (same size as the original image) + thread position normalized to 0-1.0
//    float pointXinMPRimg = float(rectLeft + position.x - (frameWidth / 2.0)) / viewScale;
//    float pointYinMPRimg = -float(rectTop + position.y - (frameHeight / 2.0)) / viewScale;
//
//    pointXinMPRimg = float((rectLeft + position.x) * frameWidth / meta.inputImageWidth - (frameWidth / 2.0)) / viewScale;
//    pointYinMPRimg = -float((rectTop + position.y) * frameHeight / meta.inputImageHeight - (frameHeight / 2.0)) / viewScale;
//
//    pointXinMPRimg = (((rectLeft + position.x) * viewScale) - frameWidth / 2.0) / viewScale;
//    pointYinMPRimg = (((rectTop + position.y) * viewScale) - frameHeight / 2.0) / viewScale;
//
//    pointXinMPRimg = ((rectLeft - (frameWidth / 2.0)) * meta.outputImageWidth / frameWidth + position.x) / meta.outputImageWidth * frameWidth;
//    pointYinMPRimg = ((rectTop - (frameHeight / 2.0)) * meta.outputImageHeight / frameHeight + position.y) / meta.outputImageHeight * frameHeight;
//
    float pointXinMPRimg = ((rectLeft + position.x * viewScale) - frameWidth / 2.0) / viewScale;
    float pointYinMPRimg = ((rectTop + position.y * viewScale) - frameHeight / 2.0) / viewScale;
    
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
    
    
    float4x4 matrix_centering_toView = float4x4(1, 0, 0, 0,
                                                0, 1, 0, 0,
                                                0, 0, 1, 0,
                                                meta.inputImageWidth / 2.0, meta.inputImageHeight / 2.0, meta.inputImageDepth * scale_Z / 2.0, 1);
    
    
    float radius = modelParameter.sliceMax / 2.0;
    
    float ts;
    if(sliceDir == 0){
        ts = radius - sliceNo - position.z ;
    }else{
        ts = radius - sliceNo + position.z ;
    }
    
    float4 directionVector = float4(0,0,1,0);
    
    float4 directionVector_rotate = quatMul(quaternions, directionVector);
    
    float4 pos = transferMat * scaleMat * centeredPosition;
    
    float4 mappedXYZ = quatMul(quaternions, pos);
    float4 mappedPos = mappedXYZ + ts * directionVector_rotate;
    float4 coordPos = matrix_centering_toView * mappedPos;
    
    float3 samplerPostion = float3(coordPos.x / float(meta.inputImageWidth),
                                   (coordPos.y / float(meta.inputImageHeight)),
                                   (coordPos.z / (meta.inputImageDepth * scale_Z))
                                   ) ;
    
    
    if(all(samplerPostion >= 0) && all(samplerPostion <= 1.0)){
        float inputWidth = maskTexture_in.get_width();
        float inputHeight = maskTexture_in.get_height();
        float inputDepth = maskTexture_in.get_depth();
        
        
        half4 maskIntensity = maskTexture_in.sample(smp, float3(position.x / (inputWidth),
                                                                position.y / (inputHeight),
                                                                position.z / (inputDepth)));
//        maskIntensity = maskTexture_in.read(position);

        
        ushort3 out_coord = ushort3(round(samplerPostion.x * (maskTexture_out.get_width())),
                                    round(samplerPostion.y * (maskTexture_out.get_height())),
                                    round(samplerPostion.z * (maskTexture_out.get_depth())));
        
        if(maskIntensity.r != 0){
            maskTexture_out.write(half4(1.0,0,0,0), out_coord);
//            maskTexture_out.write(half4(maskIntensity.r,0,0,0), out_coord);
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


//
//kernel void transferMaskToMainTexture(texture3d<half, access::sample> texIn [[texture(0)]],
//                                      texture3d<half, access::read_write> texOut [[texture(1)]],
//                                      sampler        smp [[ sampler(0) ]],
//                                      ushort3                           position [[thread_position_in_grid]]){
//    float imageWidth = texIn.get_width();
//    float imageHeight = texIn.get_height();
//    float imageDepth = texIn.get_depth();
//
//    if (position.x >= imageWidth || position.y >= imageHeight || position.z >= imageDepth){
//        return;
//    }
//
//
//    half4 inputColor = inputColor = texIn.sample(smp, float3(position.x / imageWidth,
//                                                             position.y / imageHeight,
//                                                             position.z / imageDepth));
//
//    half4 outputColor = texOut.read(position);
//
//
//    if(inputColor.r != 0){
//        outputColor.g = 1.0;
//
//    }
//
//
//    texOut.write(outputColor, position);
//
//}
//


/// transfer mask image to the texture
/// if `binary` is `true`, only Zero value will set to zero
kernel void transferMaskToTexture2(texture3d<half, access::sample>       texIn [[texture(0)]],
                                   texture3d<half, access::read_write>   texOut [[texture(1)]],
                                   constant uint8_t  &channel [[buffer(0)]],
                                   constant bool     &binary [[buffer(1)]],
                                   sampler           smp [[ sampler(0) ]],
                                   ushort3           position [[thread_position_in_grid]]){
    
    float imageWidth = texIn.get_width();
    float imageHeight = texIn.get_height();
    float imageDepth = texIn.get_depth();
    
    if (position.x >= imageWidth || position.y >= imageHeight || position.z >= imageDepth){
        return;
    }
    
    // get color from mask texture
    
    // Due to rounding in floating-point calculations, there may be a slight deviation in the value of z.
    // If necessary, adjust z in the range from -2 to 0 (-2, -1, +0) to correct for this deviation.
    float eps = -1;
    half4 inputColor = texIn.sample(smp, float3(position.x / (imageWidth + eps),
                                                position.y / (imageHeight + eps),
                                                position.z / (imageDepth + eps)));
    
    half4 outputColor = texOut.read(position);
    
    if(binary == true){
        outputColor[channel] = inputColor.r != 0 ? 1.0 : 0.0;
//        outputColor[channel] = inputColor.r > 0.2 ? 1.0 : 0.0;
        
    }else{
        outputColor[channel] = inputColor.r ;
    }
    
    texOut.write(outputColor, position);
    
}





/// transfer mask image to the texture
/// if `binary` is `true`, only Zero value will set to zero
kernel void transferMaskToTexture(texture3d<half, access::sample>       texIn [[texture(0)]],
                                  texture3d<half, access::read_write>   texOut [[texture(1)]],
                                  constant uint8_t  &channel [[buffer(0)]],
                                  constant bool     &binary [[buffer(1)]],
                                  sampler           smp [[ sampler(0) ]],
                                  ushort3           position [[thread_position_in_grid]]){
    float imageWidth = texIn.get_width();
    float imageHeight = texIn.get_height();
    float imageDepth = texIn.get_depth();
    
    if (position.x >= imageWidth || position.y >= imageHeight || position.z >= imageDepth){
        return;
    }
    
    // get color from mask texture
    half4 inputColor = texIn.sample(smp, float3(position.x / (imageWidth-1),
                                                position.y / (imageHeight-1),
                                                position.z / (imageDepth-1)));
    // Due to rounding in floating-point calculations, there may be a slight deviation in the value of z.
    // If necessary, adjust z in the range from -2 to 0 (-2, -1, +0) to correct for this deviation.
    inputColor = texIn.read(position);
    half4 outputColor = texOut.read(position);
    
    if(binary == true){
//        outputColor[channel] = inputColor.r != 0 ? 1.0 : 0.0;
        outputColor[channel] = inputColor.r > 0.2 ? 1.0 : 0.0;
        
    }else{
        outputColor[channel] = inputColor.r ;
    }
    
    texOut.write(outputColor, position);
    
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
