//
//  Codable.swift
//  Acto3D
//
//  Created by Naoki Takeshita on 2023/02/20.
//

import Foundation
import Cocoa
import simd

extension simd_quatf: Codable{
    enum CodingKeys: String, CodingKey {
        case rotation
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        let array = [self.imag.x, self.imag.y, self.imag.z, self.real]
        try container.encode(array, forKey: .rotation)
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let array = try container.decode([Float].self, forKey: .rotation)
        self = simd_quatf(ix: array[0], iy: array[1], iz: array[2], r: array[3])
    }
}
