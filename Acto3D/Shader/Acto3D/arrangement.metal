//
//  Acto3D
//
//  Created by Naoki Takeshita on 2022/08/06.
//

// This file contains kernels for processing pixel data,
// such as mapping the image data pixels from 16-bit to 8-bit
// and adjusting the arrangement of pixel data.


kernel void createTexture16bit(constant uint16_t                    *inputData      [[buffer(0)]],
                               constant VolumeData                  &meta           [[buffer(1)]],
                               constant uint8_t                     &imgCh          [[buffer(2)]],
                               constant uint16_t                    &zPos           [[buffer(3)]],
                               constant float                       *ranges         [[buffer(4)]],
                               constant uchar4                      &ignoreSaturate [[buffer(5)]],
                               texture3d<half, access::write>       tex             [[texture(0)]],
                               uint2                                position        [[thread_position_in_grid]]){
    
    uint imgX = meta.inputImageWidth;
    uint imgY = meta.inputImageHeight;
    
    if (position.x >= imgX || position.y >= imgY){
        return;
    }
    
    
    float4 outputData = float4(0, 0, 0, 0);
    float4 dr_min = float4(0, 0, 0, 0);
    float4 dr_max = float4((1<<16) - 1, (1<<16) - 1, (1<<16) - 1, (1<<16) - 1);
    
    for (int i = 0; i < imgCh; i++) {
        outputData[i] = inputData[imgX * imgY * i + position.y * imgX + position.x];
        
        dr_min[i] = ranges[i * 2];
        dr_max[i] = ranges[i * 2 + 1];
        
        if (ignoreSaturate[i] == 1 && outputData[i] > dr_max[i]) {
            outputData[i] = 0;
        }
        
    }
    
    float4 normalizedOutput = (outputData - dr_min) / (dr_max - dr_min);
    half4 clampedOutput = half4(clamp(normalizedOutput, 0.0h, 1.0h));
    
    tex.write(clampedOutput, ushort3(position.x, position.y, zPos));
}

kernel void createTexture8bit(constant uint8_t                *inputData [[buffer(0)]],
                              constant VolumeData            &meta [[buffer(1)]],
                              constant uint8_t                &imgCh [[buffer(2)]],
                              constant uint16_t                &zPos [[buffer(3)]],
                              constant float                 *ranges [[buffer(4)]],
                              constant uchar4              &ignoreSaturate [[buffer(5)]],
                              texture3d<half, access::write> tex [[texture(0)]],
                              uint2                           position [[thread_position_in_grid]]){
    
    
    uint imgX = meta.inputImageWidth;
    uint imgY = meta.inputImageHeight;
    
    if (position.x >= imgX || position.y >= imgY){
        return;
    }
    
    
    float4 outputData = float4(0, 0, 0, 0);
    float4 dr_min = float4(0, 0, 0, 0);
    float4 dr_max = float4((1<<8) - 1, (1<<8) - 1, (1<<8) - 1, (1<<8) - 1);
    
    for (int i = 0; i < imgCh; i++) {
        outputData[i] = inputData[imgX * imgY * i + position.y * imgX + position.x];
        
        dr_min[i] = ranges[i * 2];
        dr_max[i] = ranges[i * 2 + 1];
        
        if (ignoreSaturate[i] == 1 && outputData[i] > dr_max[i]) {
            outputData[i] = 0;
        }
    }
    
    float4 normalizedOutput = (outputData - dr_min) / (dr_max - dr_min);
    half4 clampedOutput = half4(clamp(normalizedOutput, 0.0h, 1.0h));
    
    tex.write(clampedOutput, ushort3(position.x, position.y, zPos));
    
}



// write data to 3D texture from rgba slice image
kernel void createTextureFromStacks8bit(constant uint8_t                *inputData [[buffer(0)]],
                                        constant VolumeData            &meta [[buffer(1)]],
                                        constant uint8_t                &imgCh [[buffer(2)]],
                                        constant uint16_t                &zPos [[buffer(3)]],
                                        constant float                 *ranges [[buffer(4)]],
                                        constant uchar4              &ignoreSaturate [[buffer(5)]],
                                        constant bool       &needBitsAdjust [[buffer(6)]],
                                        texture3d<half, access::write> tex [[texture(0)]],
                                        uint2                           position [[thread_position_in_grid]]){
    
    uint imgX = meta.inputImageWidth;
    uint imgY = meta.inputImageHeight;
    
    if (position.x >= imgX || position.y >= imgY){
        return;
    }
    
    
    float4 outputData = float4(0, 0, 0, 0);
    float4 dr_min = float4(0, 0, 0, 0);
    float4 dr_max = float4((1<<8) - 1, (1<<8) - 1, (1<<8) - 1, (1<<8) - 1);
    
    
    for (int i = 0; i < 4; i++) {
        if (i < imgCh) {
            if(imgCh == 3){
                if(needBitsAdjust){
                    outputData[i] = inputData[(imgX * position.y + position.x) * 4 + i];
                }else{
                    outputData[i] = inputData[(imgX * position.y + position.x) * 3 + i];
                }
            }else{
                outputData[i] = inputData[(imgX * position.y + position.x) * imgCh + i];
            }
            
            dr_min[i] = ranges[i * 2];
            dr_max[i] = ranges[i * 2 + 1];
            
            if (ignoreSaturate[i] == 1 && outputData[i] > dr_max[i]) {
                outputData[i] = 0;
            }
            
        } else {
            outputData[i] = 0;
        }
    }
    
    
    
    float4 normalizedOutput = (outputData - dr_min) / (dr_max - dr_min);
    half4 clampedOutput = half4(clamp(normalizedOutput, 0.0h, 1.0h));
    
    tex.write(clampedOutput, ushort3(position.x, position.y, zPos));
    
}

kernel void createTextureFromStacks16bit(constant uint16_t                *inputData [[buffer(0)]],
                                         constant VolumeData            &meta [[buffer(1)]],
                                         constant uint8_t                &imgCh [[buffer(2)]],
                                         constant uint16_t                &zPos [[buffer(3)]],
                                         constant float                 *ranges [[buffer(4)]],
                                         constant uchar4              &ignoreSaturate [[buffer(5)]],
                                         constant bool       &needBitsAdjust [[buffer(6)]],
                                         texture3d<half, access::write> tex [[texture(0)]],
                                         uint2                           position [[thread_position_in_grid]]){
    
    
    uint imgX = meta.inputImageWidth;
    uint imgY = meta.inputImageHeight;
    
    if (position.x >= imgX || position.y >= imgY){
        return;
    }
    
    
    float4 outputData = float4(0, 0, 0, 0);
    float4 dr_min = float4(0, 0, 0, 0);
    float4 dr_max = float4((1<<16) - 1, (1<<16) - 1, (1<<16) - 1, (1<<16) - 1);
    
    
    for (int i = 0; i < 4; i++) {
        if (i < imgCh) {
            if(imgCh == 3){
                if(needBitsAdjust){
                    outputData[i] = inputData[(imgX * position.y + position.x) * 4 + i];
                }else{
                    outputData[i] = inputData[(imgX * position.y + position.x) * 3 + i];
                }
            }else{
                outputData[i] = inputData[(imgX * position.y + position.x) * imgCh + i];
            }
            
            dr_min[i] = ranges[i * 2];
            dr_max[i] = ranges[i * 2 + 1];
            
            if (ignoreSaturate[i] == 1 && outputData[i] > dr_max[i]) {
                outputData[i] = 0;
            }
            
        } else {
            outputData[i] = 0;
        }
    }
    
    
    float4 normalizedOutput = (outputData - dr_min) / (dr_max - dr_min);
    half4 clampedOutput = half4(clamp(normalizedOutput, 0.0h, 1.0h));
    
    tex.write(clampedOutput, ushort3(position.x, position.y, zPos));
    
}





kernel void createRGBAarray24To32bit(device uint8_t                  *outputData [[buffer(0)]],
                                     constant uint8_t                *inputData [[buffer(1)]],
                                     constant VolumeData            &meta [[buffer(2)]],
                                     constant uint8_t                &imgCh [[buffer(3)]],
                                     uint3                           position [[thread_position_in_grid]]){
    
    uint imgX = meta.inputImageWidth;
    uint imgY = meta.inputImageHeight;
    uint imgZ = meta.inputImageDepth;
    
    if (position.x >= imgX || position.y >= imgY || position.z >= imgZ){
        return;
    }
    
    // RGB RGB RGB ...  --> RGBA RGBA RGBA ...
    
    if(imgCh == 3){
        int pos_linear = imgX * imgY * 4 * position.z + imgX * position.y * 4 + position.x * 4 ;
        outputData[pos_linear + 0] = inputData[imgX * imgY * position.z * 3 + imgX * position.y * 3 + position.x * 3 + 0] ;
        outputData[pos_linear + 1] = inputData[imgX * imgY * position.z * 3 + imgX * position.y * 3 + position.x * 3 + 1] ;
        outputData[pos_linear + 2] = inputData[imgX * imgY * position.z * 3 + imgX * position.y * 3 + position.x * 3 + 2] ;
        outputData[pos_linear + 3] = 0 ;
    }else if(imgCh == 1){
        int pos_linear = imgX * imgY * 4 * position.z + imgX * position.y * 4 + position.x * 4 ;
        outputData[pos_linear + 0] = inputData[imgX * imgY * position.z * 1 + imgX * position.y * 1 + position.x * 1 + 0] ;
        outputData[pos_linear + 1] = 0 ;
        outputData[pos_linear + 2] = 0 ;
        outputData[pos_linear + 3] = 0 ;
    }
    
    //    return;
    
}



// changeRangeEncoder16bit is a kernel function that rescales and clips input 16-bit image data to a range between 0 and 255.
// changeRangeEncoder8bit operates on 8-bit image data.
kernel void changeRangeEncoder16bit(constant uint16_t                *inputData [[buffer(0)]],
                                    constant float                 *ranges [[buffer(1)]],
                                    constant uint16_t &imgWidth [[buffer(2)]],
                                    constant uint16_t &imgHeight [[buffer(3)]],
                                    device uint8_t  *outputData  [[buffer(4)]],
                                    volatile device atomic_uint  *intensityCount  [[buffer(5)]],
                                    constant uint8_t &ignoreSaturate [[buffer(6)]],
                                    uint2                           position [[thread_position_in_grid]]){
    
    
    
    if (position.x >= imgWidth || position.y >= imgHeight){
        return;
    }
    
    uint pos = position.y * imgWidth + position.x;
    
    uint16_t pixelValue = inputData[pos];
    
    if(ignoreSaturate == 1 && pixelValue > ranges[1]){
        pixelValue = 0;
    }
    half outValue = (pixelValue - ranges[0]) / (ranges[1] - ranges[0]);
    half clampedValue = clamp(outValue, 0.0h, 1.0h);
    outputData[pos] = uint8_t(clampedValue * 255);
    
    atomic_fetch_add_explicit(&intensityCount[inputData[pos]], 1, memory_order_relaxed);
    
    
}
kernel void changeRangeEncoder8bit(constant uint8_t                *inputData [[buffer(0)]],
                                   constant float                 *ranges [[buffer(1)]],
                                   constant uint16_t &imgWidth [[buffer(2)]],
                                   constant uint16_t &imgHeight [[buffer(3)]],
                                   device uint8_t  *outputData  [[buffer(4)]],
                                   volatile device atomic_uint  *intensityCount  [[buffer(5)]],
                                   constant uint8_t &ignoreSaturate [[buffer(6)]],
                                   uint2                           position [[thread_position_in_grid]]){
    
    
    
    if (position.x >= imgWidth || position.y >= imgHeight){
        return;
    }
    
    uint pos = position.y * imgWidth + position.x;
    uint8_t pixelValue = inputData[pos];
    
    if(ignoreSaturate == 1 && pixelValue > ranges[1]){
        pixelValue = 0;
    }
    
    half outValue = (pixelValue - ranges[0]) / (ranges[1] - ranges[0]);
    half clampedValue = clamp(outValue, 0.0h, 1.0h);
    outputData[pos] = uint8_t(clampedValue * 255);
    
    
    
    atomic_fetch_add_explicit(&intensityCount[inputData[pos]], 1, memory_order_relaxed);
    
}

// RGBA image to grayscale image for each channel
kernel void splitChannelEncoder8bit(constant uint8_t    *inputData          [[buffer(0)]],
                                    constant uint8_t    &imgChannelCount    [[buffer(1)]],
                                    constant uint16_t   &imgWidth           [[buffer(2)]],
                                    constant uint16_t   &imgHeight          [[buffer(3)]],
                                    device uint8_t      *outputData         [[buffer(4)]],
                                    constant bool       &needBitsAdjust [[buffer(5)]],
                                    uint2               position            [[thread_position_in_grid]]){
    
    
    if (position.x >= imgWidth || position.y >= imgHeight){
        return;
    }
    
    uint pos = position.y * imgWidth + position.x;
    
    for(int c=0; c<imgChannelCount; c++){
        if(imgChannelCount == 3){
            // if original image was 24 bits, provided Data from cgImage would be 32 bits
            if(needBitsAdjust == true){
                outputData[pos + imgWidth * imgHeight * c] = inputData[(position.y * imgWidth + position.x) * 4 + c];
            }else{
                outputData[pos + imgWidth * imgHeight * c] = inputData[(position.y * imgWidth + position.x) * 3 + c];
            }
        }else{
            outputData[pos + imgWidth * imgHeight * c] = inputData[(position.y * imgWidth + position.x) * imgChannelCount + c];
        }
    }
}

kernel void splitChannelEncoder16bit(constant uint16_t   *inputData          [[buffer(0)]],
                                     constant uint8_t    &imgChannelCount    [[buffer(1)]],
                                     constant uint16_t   &imgWidth           [[buffer(2)]],
                                     constant uint16_t   &imgHeight          [[buffer(3)]],
                                     device uint16_t      *outputData         [[buffer(4)]],
                                     constant bool       &needBitsAdjust [[buffer(5)]],
                                     uint2               position            [[thread_position_in_grid]]){
    
    
    if (position.x >= imgWidth || position.y >= imgHeight){
        return;
    }
    
    uint pos = position.y * imgWidth + position.x;
    
    for(int c=0; c<imgChannelCount; c++){
        outputData[pos + imgWidth * imgHeight * c] = inputData[position.y * imgWidth * imgChannelCount + position.x * imgChannelCount + c];
    }
}


// Write data to 3D texture from rgba slice image
kernel void createTextureFromCYX_8bit(constant uint8_t                *inputData [[buffer(0)]],
                                      constant VolumeData            &meta [[buffer(1)]],
                                      constant uint8_t                &originalImgCh [[buffer(2)]],
                                      constant uint16_t                &zPos [[buffer(3)]],
                                      texture3d<float, access::write> tex [[texture(0)]],
                                      uint2                           position [[thread_position_in_grid]]){
    uint imgX = meta.inputImageWidth;
    uint imgY = meta.inputImageHeight;
    
    if (position.x >= imgX || position.y >= imgY){
        return;
    }
    
    float4 outputData = float4(0, 0, 0, 0);
//    float4 dr_min = float4(0, 0, 0, 0);
//    float4 dr_max = float4((1<<8) - 1, (1<<8) - 1, (1<<8) - 1, (1<<8) - 1);
    
    uint bytePerChannel = imgX * imgY;
    
    for (int i = 0; i < originalImgCh; i++) {
        outputData[i] = inputData[bytePerChannel * i + (imgX * position.y + position.x) ] / 255.0f;
    }
    
    tex.write(outputData, ushort3(position.x, position.y, zPos));
}

