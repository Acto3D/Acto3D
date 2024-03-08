//
//  imageProcessor.metal
//  Acto3D
//
//  Created by Naoki Takeshita on 2023/03/24.
//

#include <metal_stdlib>
using namespace metal;

//MARK: Gaussian 3D
kernel void applyFilter_gaussian3D(texture3d<float, access::sample> inputTexture [[texture(0)]],
                                   texture3d<float, access::write> outputTexture [[texture(1)]],
                                   constant float* kernel_weights [[buffer(0)]],
                                   constant uint8_t& k_size [[buffer(1)]],
                                   constant int &channel [[buffer(2)]],
                                   device atomic_int* globalCounter [[buffer(3)]],
                                   constant bool &isCanceled [[buffer(4)]],
                                   threadgroup atomic_int* localCounter [[threadgroup(0)]],
                                   uint3 gid [[thread_position_in_grid]],
                                   uint3 tid [[thread_position_in_threadgroup]])
{
    if(isCanceled == true){
        return;
    }
    // half size of the kernel size (Odd value)
    int half_kernel_size = k_size / 2;
    
    int width = inputTexture.get_width();
    int height = inputTexture.get_height();
    int depth = inputTexture.get_depth();
    
    float4 result = float4(0.0);
    for (int i = -half_kernel_size; i <= half_kernel_size; i++) {
        for (int j = -half_kernel_size; j <= half_kernel_size; j++) {
            for (int k = -half_kernel_size; k <= half_kernel_size; k++) {
                // check if gid is inside the texture area
                int adjusted_i = max(min(int(gid.x) + i, width - 1), 0);
                int adjusted_j = max(min(int(gid.y) + j, height - 1), 0);
                int adjusted_k = max(min(int(gid.z) + k, depth - 1), 0);
                uint3 adjusted_gid = uint3(adjusted_i, adjusted_j, adjusted_k);
                
                float4 value = inputTexture.read(adjusted_gid);
                int idx = (i + half_kernel_size) * k_size * k_size + (j + half_kernel_size) * k_size + (k + half_kernel_size);
                float weight = kernel_weights[idx];
                result += value * weight;
            }
        }
    }

    if(channel == -1){
        outputTexture.write(result, gid);
        
    }else{
        outputTexture.write(float4(result[channel], 0, 0, 0), gid);
        
    }
    
    
    // Add local counter on the first thread in thread groups
    if (tid.x == 0 && tid.y == 0 && tid.z == 0) {
        atomic_store_explicit(localCounter, 0, memory_order_relaxed);
        atomic_fetch_add_explicit(localCounter, 1, memory_order_relaxed);
    }

    threadgroup_barrier(mem_flags::mem_threadgroup);
    
    // Add global counter on the first thread in thread groups
    if (tid.x == 0 && tid.y == 0 && tid.z == 0) {
        atomic_fetch_add_explicit(globalCounter, atomic_load_explicit(localCounter, memory_order_relaxed), memory_order_relaxed);
    }
    
}



inline void sort_floatValues(float x[], int n) {
    for (int i = 0; i < n - 1; i++) {
        int j = i;
        for (int k = i; k < n; k++) {
            if (x[k] < x[j]) j = k;
        }
        if (i < j) {
            float v = x[i];
            x[i] = x[j]; x[j] = v;
        }
    }
    return;
}


//MARK: Median 3D

// Quick Select

void swap(thread float* arr, int i, int j) {
    float temp = arr[i];
    arr[i] = arr[j];
    arr[j] = temp;
}

int partition(thread float* arr, int left, int right, int pivotIndex) {
    float pivotValue = arr[pivotIndex];
    swap(arr, pivotIndex, right);
    int storeIndex = left;
    for (int i = left; i < right; i++) {
        if (arr[i] < pivotValue) {
            swap(arr, storeIndex, i);
            storeIndex++;
        }
    }
    swap(arr, right, storeIndex);
    return storeIndex;
}

float quickSelect(thread float* arr, int left, int right, int k) {
    if (left == right) {
        return arr[left];
    }

    int pivotIndex = (left + right) / 2;

    pivotIndex = partition(arr, left, right, pivotIndex);

    if (k == pivotIndex) {
        return arr[k];
    } else if (k < pivotIndex) {
        return quickSelect(arr, left, pivotIndex - 1, k);
    } else {
        return quickSelect(arr, pivotIndex + 1, right, k);
    }
}

#define MAX_MEDIAN_KSIZE     7
// get pixel arrays
kernel void applyFilter_median3D(texture3d<float, access::sample> inputTexture [[texture(0)]],
                                 texture3d<float, access::write> outputTexture [[texture(1)]],
                                 constant uint8_t& k_size [[buffer(0)]],
                                 constant int &channel [[buffer(1)]],
                                 device atomic_int* globalCounter [[buffer(2)]],
                                 constant bool &isCanceled [[buffer(3)]],
                                 threadgroup atomic_int* localCounter [[threadgroup(0)]],
                                 uint3 gid [[thread_position_in_grid]],
                                 uint3 tid [[thread_position_in_threadgroup]])
{
    if(isCanceled == true){
        return;
    }
    
    int half_kernel_size = k_size / 2;
    
    float values0[MAX_MEDIAN_KSIZE * MAX_MEDIAN_KSIZE * MAX_MEDIAN_KSIZE];
    float values1[MAX_MEDIAN_KSIZE * MAX_MEDIAN_KSIZE * MAX_MEDIAN_KSIZE];
    float values2[MAX_MEDIAN_KSIZE * MAX_MEDIAN_KSIZE * MAX_MEDIAN_KSIZE];
    float values3[MAX_MEDIAN_KSIZE * MAX_MEDIAN_KSIZE * MAX_MEDIAN_KSIZE];
    
    int volumeSize = k_size * k_size * k_size;

    
    int idx = 0;
    
    for (int i = -half_kernel_size; i <= half_kernel_size; i++) {
        for (int j = -half_kernel_size; j <= half_kernel_size; j++) {
            for (int k = -half_kernel_size; k <= half_kernel_size; k++) {
                float4 val = inputTexture.read(gid + uint3(i, j, k));
                values0[idx] = val.r;
                values1[idx] = val.g;
                values2[idx] = val.b;
                values3[idx] = val.a;
                idx++;
            }
        }
    }
    
    
    float result_val;
    
    switch (channel){
        case -1:
            float4 result;
            result[0] = quickSelect(values0, 0, volumeSize - 1, (volumeSize - 1) / 2);
            result[1] = quickSelect(values1, 0, volumeSize - 1, (volumeSize - 1) / 2);
            result[2] = quickSelect(values2, 0, volumeSize - 1, (volumeSize - 1) / 2);
            result[3] = quickSelect(values3, 0, volumeSize - 1, (volumeSize - 1) / 2);
            outputTexture.write(result, gid);
            break;
            
        case 0:
            result_val = quickSelect(values0, 0, volumeSize - 1, (volumeSize - 1) / 2);
            outputTexture.write(float4(result_val, 0, 0, 0), gid);
            break;
            
        case 1:
            result_val = quickSelect(values1, 0, volumeSize - 1, (volumeSize - 1) / 2);
            outputTexture.write(float4(result_val, 0, 0, 0), gid);
            break;
            
        case 2:
            result_val = quickSelect(values2, 0, volumeSize - 1, (volumeSize - 1) / 2);
            outputTexture.write(float4(result_val, 0, 0, 0), gid);
            break;
            
        case 3:
            result_val = quickSelect(values3, 0, volumeSize - 1, (volumeSize - 1) / 2);
            outputTexture.write(float4(result_val, 0, 0, 0), gid);
            break;
    }
    
    
    if (tid.x == 0 && tid.y == 0 && tid.z == 0) {
        atomic_store_explicit(localCounter, 0, memory_order_relaxed);
        atomic_fetch_add_explicit(localCounter, 1, memory_order_relaxed);
    }

    threadgroup_barrier(mem_flags::mem_threadgroup);
    
    if (tid.x == 0 && tid.y == 0 && tid.z == 0) {
        atomic_fetch_add_explicit(globalCounter, atomic_load_explicit(localCounter, memory_order_relaxed), memory_order_relaxed);
    }
        
}


//MARK: Binarization
// The function binarizes the pixel values of the specified channel by the specified threshold value
kernel void applyFilter_binarizationWithThreshold(texture3d<float, access::sample> inputTexture [[texture(0)]],
                                                  texture3d<float, access::write> outputTexture [[texture(1)]],
                                                  constant uint8_t& threshold [[buffer(0)]],
                                                  constant int &channel [[buffer(1)]],
                                                  constant bool &invert [[buffer(2)]],
                                                  device atomic_int* globalCounter [[buffer(3)]],
                                                  constant bool &isCanceled [[buffer(4)]],
                                                  threadgroup atomic_int* localCounter [[threadgroup(0)]],
                                                  uint3 gid [[thread_position_in_grid]],
                                                  uint3 tid [[thread_position_in_threadgroup]])
{
    if(isCanceled == true){
        return;
    }
    
    float4 targetPixelValue = inputTexture.read(gid);
    
    if(invert){
        float outputPixelValue = targetPixelValue[channel] > (threshold / 255.0f) ? 0.0 : 1.0;
        outputTexture.write(float4(outputPixelValue, 0, 0, 0), gid);
    }else{
        float outputPixelValue = targetPixelValue[channel] > (threshold / 255.0f) ? 1.0 : 0.0;
        outputTexture.write(float4(outputPixelValue, 0, 0, 0), gid);
    }
    
    
    
    // Add local counter on the first thread in thread groups
    if (tid.x == 0 && tid.y == 0 && tid.z == 0) {
        atomic_store_explicit(localCounter, 0, memory_order_relaxed);
        atomic_fetch_add_explicit(localCounter, 1, memory_order_relaxed);
    }

    threadgroup_barrier(mem_flags::mem_threadgroup);
    
    // Add global counter on the first thread in thread groups
    if (tid.x == 0 && tid.y == 0 && tid.z == 0) {
        atomic_fetch_add_explicit(globalCounter, atomic_load_explicit(localCounter, memory_order_relaxed), memory_order_relaxed);
    }
}


// The function binarizes the pixel values of the specified channel by the specified threshold value
kernel void applyFilter_binarizationWithThresholdSeries(texture3d<float, access::sample> inputTexture [[texture(0)]],
                                                        texture3d<float, access::write> outputTexture [[texture(1)]],
                                                        constant uint8_t* threshold [[buffer(0)]],
                                                        constant uint8_t &channel [[buffer(1)]],
                                                        constant bool &invert [[buffer(2)]],
                                                        device atomic_int* globalCounter [[buffer(3)]],
                                                        constant bool &isCanceled [[buffer(4)]],
                                                        threadgroup atomic_int* localCounter [[threadgroup(0)]],
                                                        uint3 gid [[thread_position_in_grid]],
                                                        uint3 tid [[thread_position_in_threadgroup]])
{
    if(isCanceled == true){
        return;
    }
    
    float4 targetPixelValue = inputTexture.read(gid);
    
    if(invert){
        float outputPixelValue = targetPixelValue[channel] > (float(threshold[gid.z]) / 255.0f) ? 0.0 : 1.0;
        outputTexture.write(float4(outputPixelValue, 0, 0, 0), gid);
    }else{
        float outputPixelValue = targetPixelValue[channel] > (float(threshold[gid.z]) / 255.0f) ? 1.0 : 0.0;
        outputTexture.write(float4(outputPixelValue, 0, 0, 0), gid);
    }
    
    
    
    // Add local counter on the first thread in thread groups
    if (tid.x == 0 && tid.y == 0 && tid.z == 0) {
        atomic_store_explicit(localCounter, 0, memory_order_relaxed);
        atomic_fetch_add_explicit(localCounter, 1, memory_order_relaxed);
    }

    threadgroup_barrier(mem_flags::mem_threadgroup);
    
    // Add global counter on the first thread in thread groups
    if (tid.x == 0 && tid.y == 0 && tid.z == 0) {
        atomic_fetch_add_explicit(globalCounter, atomic_load_explicit(localCounter, memory_order_relaxed), memory_order_relaxed);
    }
}



kernel void computeHistogramSliceBySlice(texture3d<float, access::read> inputTexture [[texture(0)]],
                                         constant uint8_t &channel [[buffer(0)]],
                                         device atomic_uint *histogramBuffer [[buffer(1)]],
                                         uint3 gid [[thread_position_in_grid]]
                                         )
{
    if (gid.x < inputTexture.get_width() && gid.y < inputTexture.get_height() && gid.z < inputTexture.get_depth()) {
        float pixelData = inputTexture.read(gid)[channel];
        
        // pixel values are 0 to 1.0. Map them into 0-255
        uint pixelValue = uint(pixelData * 255.0);
        
        atomic_fetch_add_explicit(&histogramBuffer[pixelValue + (256 * gid.z)], 1, memory_order_relaxed);
        
    }
}



kernel void swapChannels(texture3d<float, access::read_write> inputTexture [[texture(0)]],
                         constant uint8_t &channel1 [[buffer(0)]],
                         constant uint8_t &channel2 [[buffer(1)]],
                         uint3 gid [[thread_position_in_grid]])
{
    float4 originalValue = inputTexture.read(gid);
    float tmpValue = originalValue[channel1];
    originalValue[channel1] = originalValue[channel2];
    originalValue[channel2] = tmpValue;
    inputTexture.write(originalValue, gid);
}
