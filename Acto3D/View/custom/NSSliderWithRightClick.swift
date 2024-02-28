//
//  NSSliderWithRightClick.swift
//  Acto3D
//
//  Created by Naoki Takeshita on 2024/02/28.
//

import Cocoa

class NSSliderWithRightClick: NSSlider {

    var onRightClick: ((_ event: NSEvent) -> Void)?
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // Drawing code here.
    }
    
    override func rightMouseDown(with event: NSEvent) {
        onRightClick?(event)
    }
    
}
