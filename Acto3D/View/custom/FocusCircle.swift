//
//  FocusCircle.swift
//  Acto3D
//
//  Created by Naoki Takeshita on 2022/02/07.
//

import Cocoa

class FocusCircle: NSView {

    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.updateLayer()
    }
    override func hitTest(_ point: NSPoint) -> NSView? {
        return nil
    }
    
    override class func awakeAfter(using coder: NSCoder) -> Any? {
        super.awakeAfter(using:coder)
    }
    
    override func draw(_ dirtyRect: NSRect) {
        // Drawing code here.
        
        super.draw(dirtyRect)
        self.frame.size = CGSize(width: 32, height: 32)
        self.layer?.cornerRadius = 16
    }
    
    override func shouldDelayWindowOrdering(for event: NSEvent) -> Bool {
        return true
    }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return false
    }
    
    
    override var acceptsFirstResponder: Bool{
        get {
            return false
            
        }
    }
    override func becomeFirstResponder() -> Bool {
        return false
    }
}
