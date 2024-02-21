//
//  FlippedViewForScroll.swift
//  Acto3D
//
//  Created by Naoki Takeshita on 2022/08/28.
//

import Cocoa

class FlippedView: NSView {

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // Drawing code here.
    }
    
    override var isFlipped: Bool {
        return true
    }
    
    override func resize(withOldSuperviewSize oldSize: NSSize) {
        var maxHeight:CGFloat = 0
        
        for item in self.subviews.enumerated(){
            if (item.element.className == "NSBox"){
                let box = item.element as! NSBox
                if (maxHeight <= box.frame.maxY){
                    maxHeight = box.frame.maxY
                }
            }
        }
        self.setFrameSize(NSSize(width: oldSize.width, height: maxHeight))
    }
    
    func adjustHeightOfView(){
        var maxHeight:CGFloat = 0
        
        for item in self.subviews.enumerated(){
            
            if (maxHeight <= item.element.frame.maxY){
                maxHeight = item.element.frame.maxY
            }
            
        }
        self.setFrameSize(NSSize(width: self.frame.width, height: maxHeight))
    }
}
