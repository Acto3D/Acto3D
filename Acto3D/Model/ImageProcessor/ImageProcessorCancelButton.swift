//
//  ImageProcessorCancelButton.swift
//  Acto3D
//
//  Created by Naoki Takeshita on 2023/07/30.
//

import Cocoa

// To interrupt the kernel during image processing by GPU,
// we keep a reference to the processor class
// using an extension button.

class ImageProcessorCancelButton: NSButton {
    weak var processor:ImageProcessor?

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // Drawing code here.
    }
    
}
