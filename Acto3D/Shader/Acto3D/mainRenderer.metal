//
//  mainRenderer.metal
//  Acto3D
//
//  Created by Naoki Takeshita on 2023/02/26.
//

#include <metal_stdlib>
using namespace metal;

//MARK: - Arguments for Argument Buffer
struct RenderingArguments {
    texture3d<float, access::sample> tex          [[id(0)]];
    constant RenderingParameters &params          [[id(1)]];
    device uint8_t *outputData                    [[id(2)]];
    device float* tone1                           [[id(3)]];
    device float* tone2                           [[id(4)]];
    device float* tone3                           [[id(5)]];
    device float* tone4                           [[id(6)]];
    constant uint16_t &flags                      [[id(7)]];
    constant float4 &quaternions                  [[id(8)]];
    constant uint16_t &targetViewSize             [[id(9)]];
    sampler smp                                   [[id(10)]];
    constant uint16_t &pointSetCount              [[id(11)]];
    constant uint16_t &pointSelectedIndex         [[id(12)]];
    constant float3* pointSet                     [[id(13)]];
};

/* // using 'half' version
struct RenderingArguments {
    texture3d<half, access::sample> tex           [[id(0)]];
    constant RenderingParameters &params          [[id(1)]];
    device  uint8_t *outputData                   [[id(2)]];
    device float* tone1                           [[id(3)]];
    device float* tone2                           [[id(4)]];
    device float* tone3                           [[id(5)]];
    device float* tone4                           [[id(6)]];
    constant uint16_t    &flags                   [[id(7)]];
    constant float4 &quaternions                  [[id(8)]];
    constant uint16_t &targetViewSize             [[id(9)]];
    sampler smp                                   [[id(10)]];
    constant uint16_t &pointSetCount              [[id(11)]];
    constant uint16_t &pointSelectedIndex         [[id(12)]];
    constant float3* pointSet                     [[id(13)]];
};
 */


//MARK: - Calculate the intersection between a ray and the edges of a texture
/// Calculate the intersection of a ray with the 12 edges of a 3D texture.
/// valid_intersection_count: the number of intersections (will be 2 for a valid ray)
struct IntersectionResult {
    float t_1;
    float t_2;
    uint valid_intersection_count;
};

IntersectionResult checkIntersection(float4 mappedXYZt,
                           float4 directionVector_rotate,
                           float x_min, float x_max,
                           float y_min, float y_max,
                           float z_min, float z_max);

IntersectionResult checkIntersection(float4 mappedXYZt,
                           float4 directionVector_rotate,
                           float x_min, float x_max,
                           float y_min, float y_max,
                           float z_min, float z_max){
    
    // Exclude areas where computation is unnecessary.
    // Calculate distance constants such that the ray fits within a texel.
    // Ideally, only compute when t_near < t < t_far.
    
    // The intersection points between a texel and a ray will be 0 if completely outside the region,
    // 2 points if within the texel, and 1 if the ray intersects only a single vertex.
    IntersectionResult result;
    
    result.valid_intersection_count = 0;
    
    
    // Calculate 6 planes
    // Zn = z_min, Zf = z_max
    // Xn = -width/2.0, Xf = width/2.0
    // Yn = -height/2.0, Yf = height/2.0
    
    // Zn
    float t_zn = (z_min - mappedXYZt.z) / directionVector_rotate.z;
    float zn_x = mappedXYZt.x + t_zn * directionVector_rotate.x;
    float zn_y = mappedXYZt.y + t_zn * directionVector_rotate.y;
    if(abs(zn_x) < x_max && abs(zn_y) < y_max){
        // At this t, it intersects with plane Zn within the region.
        result.valid_intersection_count += 1;
        
        if(result.valid_intersection_count == 1){
            result.t_1 = t_zn;
        }
    }
    
    // Zf
    float t_zf = (z_max - mappedXYZt.z) / directionVector_rotate.z;
    float zf_x = mappedXYZt.x + t_zf * directionVector_rotate.x;
    float zf_y = mappedXYZt.y + t_zf * directionVector_rotate.y;
    if(abs(zf_x) < x_max && abs(zf_y) < y_max){
        // At this t, it intersects with plane Zf within the region.
        result.valid_intersection_count += 1;
        
        if(result.valid_intersection_count == 1){
            result.t_1 = t_zf;
        }else if(result.valid_intersection_count == 2){
            result.t_2 = t_zf;
        }
    }
    
    if(result.valid_intersection_count != 2){
        // Xn
        float t_xn = (x_min - mappedXYZt.x) / directionVector_rotate.x;
        float xn_z = mappedXYZt.z + t_xn * directionVector_rotate.z;
        float xn_y = mappedXYZt.y + t_xn * directionVector_rotate.y;
        if(abs(xn_z) < z_max && abs(xn_y) < y_max){
            // At this t, it intersects with plane Xn within the region.
            result.valid_intersection_count += 1;
            
            if(result.valid_intersection_count == 1){
                result.t_1 = t_xn;
            }else if(result.valid_intersection_count == 2){
                result.t_2 = t_xn;
            }
        }
    }
    
    if(result.valid_intersection_count != 2){
        // Xf
        float t_xf = (x_max - mappedXYZt.x) / directionVector_rotate.x;
        float xf_z = mappedXYZt.z + t_xf * directionVector_rotate.z;
        float xf_y = mappedXYZt.y + t_xf * directionVector_rotate.y;
        if(abs(xf_z) < z_max && abs(xf_y) < y_max){
            // At this t, it intersects with plane Xf within the region.
            result.valid_intersection_count += 1;
            
            if(result.valid_intersection_count == 1){
                result.t_1 = t_xf;
            }else if(result.valid_intersection_count == 2){
                result.t_2 = t_xf;
            }
        }
    }
    
    if(result.valid_intersection_count != 2){
        // Yn
        float t_yn = (y_min - mappedXYZt.y) / directionVector_rotate.y;
        float yn_z = mappedXYZt.z + t_yn * directionVector_rotate.z;
        float yn_x = mappedXYZt.x + t_yn * directionVector_rotate.x;
        if(abs(yn_z) < z_max && abs(yn_x) < x_max){
            // At this t, it intersects with plane Yn within the region.
            result.valid_intersection_count += 1;
            
            if(result.valid_intersection_count == 1){
                result.t_1 = t_yn;
            }else if(result.valid_intersection_count == 2){
                result.t_2 = t_yn;
            }
        }
    }
    
    if(result.valid_intersection_count != 2){
        // Xf
        float t_yf = (y_max - mappedXYZt.y) / directionVector_rotate.y;
        float yf_z = mappedXYZt.z + t_yf * directionVector_rotate.z;
        float yf_x = mappedXYZt.x + t_yf * directionVector_rotate.x;
        if(abs(yf_z) < z_max && abs(yf_x) < x_max){
            // At this t, it intersects with plane Yf within the region.
            result.valid_intersection_count += 1;
            
            if(result.valid_intersection_count == 1){
                result.t_1 = t_yf;
            }else if(result.valid_intersection_count == 2){
                result.t_2 = t_yf;
            }
        }
    }

    return  result;
}


/// check whether the coords are on the edge of the volume
inline bool isOnBoundaryEdge(float3 coord, float boundaryWidth) {
    if ((coord.x < boundaryWidth && coord.y < boundaryWidth) ||
        (coord.x < boundaryWidth && coord.z < boundaryWidth) ||
        
        (coord.x < boundaryWidth && coord.y > (1.0 - boundaryWidth)) ||
        (coord.x < boundaryWidth && coord.z > (1.0 - boundaryWidth)) ||
        
        (coord.x > (1.0 - boundaryWidth) && coord.y < boundaryWidth) ||
        (coord.x > (1.0 - boundaryWidth) && coord.z < boundaryWidth) ||
        
        (coord.x > (1.0 - boundaryWidth) && coord.y > (1.0 - boundaryWidth)) ||
        (coord.x > (1.0 - boundaryWidth) && coord.z > (1.0 - boundaryWidth)) ||
        
        (coord.y < boundaryWidth && coord.z < boundaryWidth) ||
        (coord.y < boundaryWidth && coord.z > (1.0 - boundaryWidth)) ||
        
        (coord.y > (1.0 - boundaryWidth) && coord.z < boundaryWidth) ||
        (coord.y > (1.0 - boundaryWidth) && coord.z > (1.0 - boundaryWidth))
        
        ){
        return true;
    }
    return false;
}


inline float max(float4 value){
    return max(max(value.x, value.y), max(value.z, value.w));
}


inline float max(float x, float y, float z, float w){
    return max(max(x, y), max(z, w));
}
