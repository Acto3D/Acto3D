//
//  Types.swift
//  Acto3D
//
//  Created by Naoki Takeshita on 2021/12/25.
//

import Foundation
import Cocoa

import simd

struct VolumeData{
    var outputImageWidth:UInt16 = 512
    var outputImageHeight:UInt16 = 512
    var inputImageWidth:UInt16 = 0
    var inputImageHeight:UInt16 = 0
    var inputImageDepth:UInt16 = 0
    var numberOfComponent:UInt8 = 0
}

enum FileType {
    case none
    case multiFileStacks
    case singleFileMultiPage
}

struct PackedColor: Codable{
    var ch1_color:float4 = float4(1, 0, 0, 0)
    var ch2_color:float4 = float4(0, 1, 0, 0)
    var ch3_color:float4 = float4(0, 0, 1, 0)
    var ch4_color:float4 = float4(1, 1, 1, 0)
}

struct RenderingParameters: Codable{
    var scale:Float = 0.4
    var zScale:Float = 1.0
    var sliceNo:UInt16 = 0
    var sliceMax:UInt16 = 0
    var trimX_min:Float = 0
    var trimX_max:Float = 1.0
    var trimY_min:Float = 0
    var trimY_max:Float = 1.0
    var trimZ_min:Float = 0
    var trimZ_max:Float = 1.0
    var color:PackedColor = PackedColor()
    var cropLockQuaternions:simd_quatf = simd_quatf(float4x4(1))
    var cropSliceNo:uint16 = 0
    var eularX:Float = 0
    var eularY:Float = 0
    var eularZ:Float = 0
    var translationX:Float = 0
    var translationY:Float = 0
    var viewSize:UInt16 = 512
    var pointX:Float = 0
    var pointY:Float = 0
    var alphaPower:uint8 = 2
    var renderingStep:Float = 1.6
    var intensityRatio:float4 = float4(1.0, 1.0, 1.0, 1.0)
    var light:Float = 1.0
    var shade:Float = 0.3
    
    /// 0:FtB, 1:BtF, 2:MIP
    var renderingMethod:UInt8 = 0
    
    var backgroundColor:float3? = float3(0, 0, 0)
    
    
    enum CodingKeys: CodingKey {
        case scale, zScale, sliceNo, sliceMax, trimX_min, trimX_max, trimY_min, trimY_max, trimZ_min, trimZ_max, color, cropLockQuaternions, cropSliceNo
        case eularX, eularY, eularZ, translationX, translationY, viewSize, pointX, pointY, alphaPower, renderingStep
        case intensityRatio, light, shade, renderingMethod, backgroundColor, renderingMode
    }
    

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encodeIfPresent(scale, forKey: .scale)
        try container.encodeIfPresent(zScale, forKey: .zScale)
        try container.encodeIfPresent(sliceNo, forKey: .sliceNo)
        try container.encodeIfPresent(sliceMax, forKey: .sliceMax)
        try container.encodeIfPresent(trimX_min, forKey: .trimX_min)
        try container.encodeIfPresent(trimX_max, forKey: .trimX_max)
        try container.encodeIfPresent(trimY_min, forKey: .trimY_min)
        try container.encodeIfPresent(trimY_max, forKey: .trimY_max)
        try container.encodeIfPresent(trimZ_min, forKey: .trimZ_min)
        try container.encodeIfPresent(trimZ_max, forKey: .trimZ_max)
        try container.encodeIfPresent(color, forKey: .color)
        try container.encodeIfPresent(cropLockQuaternions, forKey: .cropLockQuaternions)
        try container.encodeIfPresent(cropSliceNo, forKey: .cropSliceNo)
        try container.encodeIfPresent(eularX, forKey: .eularX)
        try container.encodeIfPresent(eularY, forKey: .eularY)
        try container.encodeIfPresent(eularZ, forKey: .eularZ)
        try container.encodeIfPresent(translationX, forKey: .translationX)
        try container.encodeIfPresent(translationY, forKey: .translationY)
        try container.encodeIfPresent(viewSize, forKey: .viewSize)
        try container.encodeIfPresent(pointX, forKey: .pointX)
        try container.encodeIfPresent(pointY, forKey: .pointY)
        try container.encodeIfPresent(alphaPower, forKey: .alphaPower)
        try container.encodeIfPresent(renderingStep, forKey: .renderingStep)
        try container.encodeIfPresent(renderingMethod, forKey: .renderingMethod)
        try container.encodeIfPresent(backgroundColor, forKey: .backgroundColor)
        try container.encodeIfPresent(intensityRatio, forKey: .intensityRatio)
        try container.encodeIfPresent(light, forKey: .light)
        try container.encodeIfPresent(shade, forKey: .shade)
    }
    
    init() {
        
    }
    
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        scale = try container.decodeIfPresent(Float.self, forKey: .scale) ?? 0.4
        zScale = try container.decodeIfPresent(Float.self, forKey: .zScale) ?? 1.0
        sliceNo = try container.decodeIfPresent(UInt16.self, forKey: .sliceNo) ?? 0
        sliceMax = try container.decodeIfPresent(UInt16.self, forKey: .sliceMax) ?? 0
        trimX_min = try container.decodeIfPresent(Float.self, forKey: .trimX_min) ?? 0
        trimX_max = try container.decodeIfPresent(Float.self, forKey: .trimX_max) ?? 1.0
        trimY_min = try container.decodeIfPresent(Float.self, forKey: .trimY_min) ?? 0
        trimY_max = try container.decodeIfPresent(Float.self, forKey: .trimY_max) ?? 1.0
        trimZ_min = try container.decodeIfPresent(Float.self, forKey: .trimZ_min) ?? 0
        trimZ_max = try container.decodeIfPresent(Float.self, forKey: .trimZ_max) ?? 1.0
        color = try container.decodeIfPresent(PackedColor.self, forKey: .color) ?? PackedColor()
        cropLockQuaternions = try container.decodeIfPresent(simd_quatf.self, forKey: .cropLockQuaternions) ?? simd_quatf(float4x4(1))
        cropSliceNo = try container.decodeIfPresent(UInt16.self, forKey: .cropSliceNo) ?? 0
        eularX = try container.decodeIfPresent(Float.self, forKey: .eularX) ?? 0
        eularY = try container.decodeIfPresent(Float.self, forKey: .eularY) ?? 0
        eularZ = try container.decodeIfPresent(Float.self, forKey: .eularZ) ?? 0
        translationX = try container.decodeIfPresent(Float.self, forKey: .translationX) ?? 0
        translationY = try container.decodeIfPresent(Float.self, forKey: .translationY) ?? 0
        viewSize = try container.decodeIfPresent(UInt16.self, forKey: .viewSize) ?? 512
        pointX = try container.decodeIfPresent(Float.self, forKey: .pointX) ?? 0
        pointY = try container.decodeIfPresent(Float.self, forKey: .pointY) ?? 0
        alphaPower = try container.decodeIfPresent(UInt8.self, forKey: .alphaPower) ?? 2
        renderingStep = try container.decodeIfPresent(Float.self, forKey: .renderingStep) ?? 1.6
        intensityRatio = try container.decodeIfPresent(float4.self, forKey: .intensityRatio) ?? float4(1.0, 1.0, 1.0, 1.0)
        light = try container.decodeIfPresent(Float.self, forKey: .light) ?? 1.0
        shade = try container.decodeIfPresent(Float.self, forKey: .shade) ?? 0.3
        renderingMethod = try container.decodeIfPresent(UInt8.self, forKey: .renderingMethod) ?? 0
        backgroundColor = try container.decodeIfPresent(float3.self, forKey: .backgroundColor) ?? float3(0, 0, 0)
    }
    
    
    
}

struct ImageParameters: Codable {
    var scaleX: Float = 1.0
    var scaleY: Float = 1.0
    var scaleZ: Float = 1.0
    var unit: String = ""
    var displayRanges: [[Double]] = []
    var scalebarLength: Int = 0
    var scaleFontSize: Float = 0
    var textureLoadChannel: Int? = 4
    var ignoreSaturatedPixels: simd_uchar4? = simd_uchar4(0, 0, 0, 0)

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        scaleX = try container.decodeIfPresent(Float.self, forKey: .scaleX) ?? 1.0
        scaleY = try container.decodeIfPresent(Float.self, forKey: .scaleY) ?? 1.0
        scaleZ = try container.decodeIfPresent(Float.self, forKey: .scaleZ) ?? 1.0
        unit = try container.decodeIfPresent(String.self, forKey: .unit) ?? ""
        displayRanges = try container.decodeIfPresent([[Double]].self, forKey: .displayRanges) ?? []
        scalebarLength = try container.decodeIfPresent(Int.self, forKey: .scalebarLength) ?? 0
        scaleFontSize = try container.decodeIfPresent(Float.self, forKey: .scaleFontSize) ?? 0
        textureLoadChannel = try container.decodeIfPresent(Int.self, forKey: .textureLoadChannel) ?? 4
        ignoreSaturatedPixels = try container.decodeIfPresent(simd_uchar4.self, forKey: .ignoreSaturatedPixels) ?? simd_uchar4(0, 0, 0, 0)
    }

    enum CodingKeys: String, CodingKey {
        case scaleX, scaleY, scaleZ, unit, displayRanges, scalebarLength, scaleFontSize, textureLoadChannel, ignoreSaturatedPixels
    }
    init() {
        
    }
}







struct PointClouds: Codable{
    var pointSet:[float3] = []
    var selectedIndex:UInt16 = 0
}

struct ControlPoint: Codable {
    var title: String
    var values0: [[Float]]
    var type0: Int
    var values1: [[Float]]
    var type1: Int
    var values2: [[Float]]
    var type2: Int
    var values3: [[Float]]
    var type3: Int
    
    
    enum CodingKeys: String, CodingKey {
        case title
        case values0
        case type0
        case values1
        case type1
        case values2
        case type2
        case values3
        case type3
    }
}
