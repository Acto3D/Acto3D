//
//  NSRect+.swift
//  Acto3D
//
//  Created by Naoki Takeshita on 2022/11/06.
//

import Foundation
import Cocoa

extension NSRect{
    func scaling(scaleX:CGFloat, scaleY:CGFloat) -> NSRect{
        return NSMakeRect(self.minX * scaleX,
                          self.minY * scaleY,
                          self.width * scaleX,
                          self.height * scaleY)
    }
    
    static func / (lhs: NSRect, rhs: CGFloat) -> NSRect {
        return NSRect(x: lhs.origin.x / rhs, y: lhs.origin.y / rhs, width: lhs.size.width / rhs, height: lhs.size.height / rhs)
    }
    
}

extension NSPoint{
    func scaling(scaleX:CGFloat, scaleY:CGFloat) -> NSPoint{
        return NSMakePoint(self.x * scaleX,
                          self.y * scaleY
                          )
    }
}
