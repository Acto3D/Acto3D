//
//  shader.metal
//  Acto3D
//
//  Created by Naoki Takeshita on 2021/12/19.
//


#include <metal_stdlib>

using namespace metal;

// OPTION SWITCH VALUES
#define SAMPLER_LINEAR      0       // 00000000 00000001
#define HQ                  1       // 00000000 00000010
#define ADAPTIVE            2       // 00000000 00000100
#define CROP_LOCK           3       // 00000000 00001000
#define FLIP                4       // 00000000 00010000
#define MPR                 5       // 00000000 00100000
#define CROP_TOGGLE         6       // 00000000 01000000
#define PREVIEW             7       // 00000000 10000000
#define SHADE               8       // 00000001 00000000
#define PLANE               9       // 00000010 00000000
#define BOX                10       // 00000100 00000000
#define POINT              11       // 00001000 00000000

#define FRONT_TO_BACK     0
#define BACK_TO_FRONT     1
#define MIP               2

#define BEHIND_VOLUME   0
#define INSIDE_VOLUME   1
#define FRONT_VOLUME    2

// Quaternion calculation
#include "quat.metal"

// Define Structs
#include "struct.metal"

#include "arrangement.metal"
#include "segment3Dshader.metal"
#include "imageProcessor.metal"

#include "macros.metal"

#include "mainRenderer.metal"
#include "export.metal"

#include "preset_MIP.metal"
#include "preset_BTF.metal"
#include "preset_FTB.metal"
#include "calculateTextureHistogram.metal"

