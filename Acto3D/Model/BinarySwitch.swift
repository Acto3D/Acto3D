//
//  BinarySwitch.swift
//  Acto3D
//
//  Created by Naoki Takeshita on 2022/01/01.
//

import Cocoa
import Foundation

struct RenderOption: OptionSet {
    let rawValue: UInt16
    static let SAMPLER_LINEAR  = RenderOption(rawValue: 1 << 0)
    static let HQ  = RenderOption(rawValue: 1 << 1)
    static let ADAPTIVE  = RenderOption(rawValue: 1 << 2)
    static let CROP_LOCK  = RenderOption(rawValue: 1 << 3)
    static let FLIP  = RenderOption(rawValue: 1 << 4)
    static let MPR  = RenderOption(rawValue: 1 << 5)
    static let CROP_TOGGLE  = RenderOption(rawValue: 1 << 6)
    static let PREVIEW  = RenderOption(rawValue: 1 << 7)
    static let SHADE  = RenderOption(rawValue: 1 << 8)
    static let PLANE  = RenderOption(rawValue: 1 << 9)
    static let BOX  = RenderOption(rawValue: 1 << 10)
    static let POINT  = RenderOption(rawValue: 1 << 11)
    
    mutating func changeValue(option : RenderOption, value : Int){
            if (value == 0){
                self.remove(option)
            }else{
                self.insert(option)
            }
    }
}
