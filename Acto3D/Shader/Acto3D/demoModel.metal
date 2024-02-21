//
//  demoModel.metal
//  Acto3D
//
//  Created by Naoki Takeshita on 2024/02/19.
//

#include <metal_stdlib>
using namespace metal;



kernel void createDemoModel_Tori(texture3d<float, access::write> texture [[texture(0)]],
                                 constant int& radius1 [[buffer(0)]],
                                 constant int& radius2 [[buffer(1)]],
                                 constant int& linewidth [[buffer(2)]],
                                 constant int& edge_color [[buffer(3)]],
                                 constant int& inside_color [[buffer(4)]],
                                 constant int& outside_color [[buffer(5)]],
                                 uint3 gid [[thread_position_in_grid]])
{
    uint imageWidth = texture.get_width();
    uint imageHeight = texture.get_height();
    uint imageDepth = texture.get_depth();
    
    if (gid.x >= imageWidth || gid.y >= imageHeight || gid.z >= imageDepth){
        return;
    }
    
    float center_x = imageWidth / 2.0;
    float center_y = imageHeight / 2.0;
    float center_z = (imageDepth - 1) / 2.0;
    
    float left1 = pow(sqrt(pow(float(gid.x - center_x), 2) + pow(float(gid.z - center_z), 2)) - float(radius1), 2) + pow(float(gid.y) - center_y, 2);
    float left2 = pow(sqrt(pow(float(gid.y - center_y), 2) + pow(float(gid.z - center_z), 2)) - float(radius1), 2) + pow(float(gid.x) - center_x, 2);
    float right1 = pow(float(radius2), 2);
    float right2 = pow(float(radius2 + linewidth), 2);
    
    if(left1 <= right1 || left2 <= right1){
        texture.write(float4(inside_color / 255.0f ,0,0,0), gid);
    }else if(left1 <= right2 || left2 <= right2){
        texture.write(float4(edge_color / 255.0f ,0,0,0), gid);
    }else{
        texture.write(float4(outside_color / 255.0, 0,0,0), gid);
    }
}




kernel void createDemoModel_SphereInCube(texture3d<float, access::write> texture [[texture(0)]],
                                         constant int& ball_size [[buffer(0)]],
                                         constant int& square_size [[buffer(1)]],
                                         uint3 gid [[thread_position_in_grid]])
{
    uint imageWidth = texture.get_width();
    uint imageHeight = texture.get_height();
    uint imageDepth = texture.get_depth();
    
    if (gid.x >= imageWidth || gid.y >= imageHeight || gid.z >= imageDepth){
        return;
    }
    
    float center_x = imageWidth / 2.0;
    float center_y = imageHeight / 2.0;
    float center_z = imageDepth  / 2.0;
    
    uint8_t channel = 0;
    float4 result = float4(0);
    float value = 0;
    
    if((gid.x - center_x) > 4 && (gid.y - center_y) > 4){
        if(pow(float(gid.x - center_x),2) + pow(float(gid.y - center_y),2) + pow(float(gid.z - center_z),2) <= pow(float(ball_size), 2)){
            channel = 3;
            value = 128.0;
        }else if( abs(float(gid.x - center_x)) < square_size && abs(float(gid.y - center_y)) < square_size  && abs(float(gid.z - center_z)) < square_size   ){
            channel = 3;
            value = 200;
        }
    }
    
    if((gid.x - center_x) < -4 && (gid.y - center_y) > 4){
        if(pow(float(gid.x - center_x),2) + pow(float(gid.y - center_y),2) + pow(float(gid.z - center_z),2) <= pow(float(ball_size), 2)){
            channel = 2;
            value = 128.0;
        }else if( abs(float(gid.x - center_x)) < square_size && abs(float(gid.y - center_y)) < square_size  && abs(float(gid.z - center_z)) < square_size   ){
            channel = 2;
            value = 200;
        }
    }
    
    if((gid.x - center_x) > 4 && (gid.y - center_y) < -4){
        if(pow(float(gid.x - center_x),2) + pow(float(gid.y - center_y),2) + pow(float(gid.z - center_z),2) <= pow(float(ball_size), 2)){
            channel = 1;
            value = 128.0;
        }else if( abs(float(gid.x - center_x)) < square_size && abs(float(gid.y - center_y)) < square_size  && abs(float(gid.z - center_z)) < square_size   ){
            channel = 1;
            value = 200;
        }
    }
    
    if((gid.x - center_x) < -4 && (gid.y - center_y) < -4){
        if(pow(float(gid.x - center_x),2) + pow(float(gid.y - center_y),2) + pow(float(gid.z - center_z),2) <= pow(float(ball_size), 2)){
            channel = 0;
            value = 128.0;
        }else if( abs(float(gid.x - center_x)) < square_size && abs(float(gid.y - center_y)) < square_size  && abs(float(gid.z - center_z)) < square_size   ){
            channel = 0;
            value = 200;
        }
    }
    
    result[channel] = value / 255.0f;
    
    texture.write(result, gid);
    
}




kernel void createDemoModel_ThinLumen(texture3d<float, access::write> texture [[texture(0)]],
                                      constant float& radius [[buffer(0)]],
                                      constant float& coefficient [[buffer(1)]],
                                      constant int& linewidth [[buffer(2)]],
                                      constant int& edge_color [[buffer(3)]],
                                      constant int& inside_color [[buffer(4)]],
                                      constant int& outside_color [[buffer(5)]],
                                      uint3 gid [[thread_position_in_grid]])
{
    uint imageWidth = texture.get_width();
    uint imageHeight = texture.get_height();
    uint imageDepth = texture.get_depth();
    
    if (gid.x >= imageWidth || gid.y >= imageHeight || gid.z >= imageDepth){
        return;
    }
    
    float center_x = imageWidth / 2.0;
    float center_y = imageHeight / 2.0;
    float center_z = imageDepth / 2.0;
    
    float left = pow(float(gid.x - center_x), 2) + pow(float(gid.y - center_y), 2) ;
    float right1 = pow(coefficient * abs(float(gid.z - center_z)) + radius , 2);
    float right2 =  pow(coefficient * abs(float(gid.z - center_z)) + radius + linewidth, 2);
    
    if(left <= right1){
        texture.write(float4(0 / 255.0f ,0,0,0), gid);
    }else if(left <= right2){
        texture.write(float4(240.0f / 255.0f ,0,0,0), gid);
    }else{
        texture.write(float4(120.0f / 255.0, 0,0,0), gid);
    }
}



kernel void applyFilter_gaussian2D(texture3d<float, access::sample> inputTexture [[texture(0)]],
                                   texture3d<float, access::write> outputTexture [[texture(1)]],
                                   constant float* kernel_weights [[buffer(0)]],
                                   constant uint8_t& k_size [[buffer(1)]],
                                   constant int& inputChannel [[buffer(2)]],
                                   constant int& outputChannel [[buffer(3)]],
                                   uint3 gid [[thread_position_in_grid]])
{
    // half size of the kernel size (Odd value)
    int half_kernel_size = k_size / 2;
    
    float4 result = float4(0.0);
    float4 originalValue = inputTexture.read(gid);
    
    for (int i = -half_kernel_size; i <= half_kernel_size; i++) {
        for (int j = -half_kernel_size; j <= half_kernel_size; j++) {
                float4 value = inputTexture.read(gid + uint3(i, j, 0));
                int idx = (i + half_kernel_size) * k_size + (j + half_kernel_size);
                float weight = kernel_weights[idx];
                result += value * weight;
            
        }
    }
    
    if(inputChannel == -1){
        outputTexture.write(result, gid);
        
    }else{
        originalValue[outputChannel] = result[inputChannel];
        outputTexture.write(originalValue, gid);
        
    }
    
}

