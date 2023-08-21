//
//  struct.metal
//  Acto3D
//
//  Created by Naoki Takeshita on 2022/08/08.
//

struct VolumeData{
    uint16_t outputImageWidth;
    uint16_t outputImageHeight;
    uint16_t inputImageWidth;
    uint16_t inputImageHeight;
    uint16_t inputImageDepth;
    uint8_t numberOfComponent;
    
};

struct PackedColor{
    float4 ch1;
    float4 ch2;
    float4 ch3;
    float4 ch4;
};

struct RenderingParameters{
    float scale ;
    float zScale ;
    uint16_t sliceNo;
    uint16_t sliceMax;
    float trimX_min;
    float trimX_max;
    float trimY_min;
    float trimY_max;
    float trimZ_min;
    float trimZ_max;
    PackedColor color ;
    float4 cropLockQuaternions ;
    uint16_t cropSliceNo ;
    float eularX ;
    float eularY ;
    float eularZ ;
    float translationX ;
    float translationY ;
    uint16_t viewSize;
    float pointX ;
    float pointY ;
    uint8_t alphaPower;
    float renderingStep ;
    float4 intensityRatio;
    float light;
    float shade;
    
    /// 0:FtB, 1:BtF, 2:MIP
    uint8_t renderingMethod ;
    
    float3 backgroundColor;
};


