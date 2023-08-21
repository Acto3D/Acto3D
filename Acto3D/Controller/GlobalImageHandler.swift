//
//  GlobalImageHandler.swift
//  Acto3D
//
//  Created by Naoki Takeshita on 2023/02/05.
//

import Foundation
import Cocoa


func create8bitImage(pixelArray:[UInt8], width:Int, height:Int) -> CGImage?{
    let totalBytes = width * height * 1
    guard let providerRef = CGDataProvider(data: Data(bytes: pixelArray, count: totalBytes) as CFData) else{
        return nil
        
    }
    
    guard let image = CGImage(
        width: width,
        height: height,
        bitsPerComponent: 8, // 8
        bitsPerPixel: 8 * 1, // 24 or 32
        bytesPerRow: MemoryLayout<UInt8>.stride * width * 1,  // * 4 for 32bit
        space:  CGColorSpaceCreateDeviceGray(),
        bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),  //CGImageAlphaInfo.noneSkipLast.rawValue
        provider: providerRef,
        decode: nil,
        shouldInterpolate: true,
        intent: .defaultIntent)
    else {
        return nil
        
    }
    
    return image
}
