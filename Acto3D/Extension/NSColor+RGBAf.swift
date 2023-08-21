//
//  NSColor+RGBAf.swift
//  Acto3D
//
//  Created by Naoki Takeshita on 2022/03/02.
//

import Foundation
import Cocoa

extension NSColor{
    func RGBAfloat()->[Float]{
        return [self.redComponent.toFloat(),
                self.greenComponent.toFloat(),
                self.blueComponent.toFloat(),
                self.alphaComponent.toFloat()]
    }
    func RGBAtoFloat4()->float4{
        return float4(x: self.redComponent.toFloat(),
                      y: self.greenComponent.toFloat(),
                      z: self.blueComponent.toFloat(),
                      w: self.alphaComponent.toFloat())
    }
    
    static func color(from value:float4) -> NSColor{
        return NSColor(red: value.x.toCGFloat(),
                       green: value.y.toCGFloat(),
                       blue: value.z.toCGFloat(),
                       alpha: value.w.toCGFloat())
    }
    
    func colorFromRGBAarray(rgba_array:[Float]) -> NSColor{
        return NSColor(red: CGFloat(rgba_array[0]),
                       green: CGFloat(rgba_array[1]),
                       blue: CGFloat(rgba_array[2]),
                       alpha: CGFloat(rgba_array[3]))
    }
    
    static func colorToData(color : NSColor) -> Data?{
        do{
            let data = try NSKeyedArchiver.archivedData(withRootObject: NSColor(red: color.redComponent,
                                                                                green: color.greenComponent,
                                                                                blue: color.blueComponent,
                                                                                alpha: color.alphaComponent),
                                                        requiringSecureCoding: false)
            return data
        }
        catch{
            return nil
        }
    }
    
}
