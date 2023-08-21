//
//  calculateTextureHistogram.metal
//  Acto3D
//
//  Created by Naoki Takeshita on 2023/07/22.
//

#include <metal_stdlib>
using namespace metal;

kernel void computeColorHistogram(texture3d<float, access::read> inputTexture [[texture(0)]],
                                  constant uint8_t &channelCount [[buffer(0)]],
                                  device atomic_uint *histogramBuffer [[buffer(1)]],
                                  uint3 gid [[thread_position_in_grid]]
                                  )
{
    if (gid.x < inputTexture.get_width() && gid.y < inputTexture.get_height() && gid.z < inputTexture.get_depth()) {
        float4 pixelData = inputTexture.read(gid);
        
        // pixel values are 0 to 1.0. Map them into 0-255
        pixelData *= 255.0;
        
        for (int i=0; i<channelCount; i++){
            atomic_fetch_add_explicit(&histogramBuffer[(int)pixelData[i] + (256 * i)], 1, memory_order_relaxed);
        }
    }
}

kernel void computeColorHistogram2(texture3d<float, access::read> inputTexture [[texture(0)]],
                                  constant uint8_t &channelCount [[buffer(0)]],
                                   device atomic_uint *histogramBuffer0 [[buffer(1)]],
                                   device atomic_uint *histogramBuffer1 [[buffer(2)]],
                                   device atomic_uint *histogramBuffer2 [[buffer(3)]],
                                   device atomic_uint *histogramBuffer3 [[buffer(4)]],
                                  uint3 gid [[thread_position_in_grid]]
                                  )
{
    if (gid.x < inputTexture.get_width() && gid.y < inputTexture.get_height() && gid.z < inputTexture.get_depth()) {
        float4 pixelData = inputTexture.read(gid);
        
        // pixel values are 0 to 1.0. Map them into 0-255
        pixelData *= 255.0;
        
        atomic_fetch_add_explicit(&histogramBuffer0[(int)pixelData[0]], 1, memory_order_relaxed);
        atomic_fetch_add_explicit(&histogramBuffer1[(int)pixelData[1]], 1, memory_order_relaxed);
        atomic_fetch_add_explicit(&histogramBuffer2[(int)pixelData[2]], 1, memory_order_relaxed);
        atomic_fetch_add_explicit(&histogramBuffer3[(int)pixelData[3]], 1, memory_order_relaxed);
    }
}
