//
//  Types.swift
//  Acto3D
//
//  Created by Naoki Takeshita on 2021/12/20.
//

import Foundation
import simd

extension UInt8{
    func toInt() -> Int{
        return Int(self)
    }
    func toDouble() -> Double{
        return Double(self)
    }
    func toFloat() -> Float{
        return Float(self)
    }
}

extension UInt16{
    func toInt() -> Int{
        return Int(self)
    }
    func toUInt32() -> UInt32{
        return UInt32(self)
    }
    func toFloat() -> Float{
        return Float(self)
    }
    func toCGFloat() -> CGFloat{
        return CGFloat(self)
    }
}

extension UInt32{
    func toInt() -> Int{
        return Int(self)
    }
    func toUInt16() -> UInt16{
        return UInt16(self)
    }
    func toUInt8() -> UInt8{
        return UInt8(self)
    }
}

extension UInt64{
    func toInt() -> Int{
        return Int(self)
    }
}


extension Float{
    func toInt() -> Int{
        return Int(self)
    }
    func toUInt16() -> UInt16{
        return UInt16(self)
    }
    func toDouble() -> Double{
        return Double(self)
    }
    func toFormatString(format :String) -> String{
        return  String(format: format, self)
    }
    func toCGFloat() -> CGFloat{
        return CGFloat(self)
    }
}


extension CGFloat{
    func toFloat() -> Float{
        return Float(self)
    }
}


extension Double{
    func toFormatString(format :String) -> String{
        return  String(format: format, self)
    }
    func toInt() -> Int{
        return Int(self)
    }
    func round(point: Int) -> Double{
        let p = point.toDouble()
        let r = (self * pow(10.0, p)).rounded() / pow(10.0, p)
        return r
    }
}

extension Int{
    func toFloat() -> Float{
        return Float(self)
    }
    func toCGFloat() -> CGFloat{
        return CGFloat(self)
    }
    func toDouble() -> Double{
        return Double(self)
    }
    func toUInt8() -> UInt8{
        return UInt8(self)
    }
    func toUInt16() -> UInt16{
        return UInt16(self)
    }
}

typealias float2 = simd_float2
typealias float3 = simd_float3
typealias float4 = simd_float4
typealias float4x4 = matrix_float4x4


extension float4{
    
    init(hex: String)  {
        let r, g, b: Float
        let hexColor = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedHex = hexColor.hasPrefix("#") ? String(hexColor.dropFirst()) : hexColor
        
        if cleanedHex.count == 6 {
            let scanner = Scanner(string: cleanedHex)
            var hexNumber: UInt64 = 0
            
            if scanner.scanHexInt64(&hexNumber) {
                r = Float((hexNumber & 0xff0000) >> 16) / 255.0
                g = Float((hexNumber & 0x00ff00) >> 8) / 255.0
                b = Float(hexNumber & 0x0000ff) / 255.0
                
                self = float4(r, g, b, 1)
                return
            }
        }
        self.init(0, 0, 0, 1)
    }
}
