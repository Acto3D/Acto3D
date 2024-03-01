//
//  ModelView.swift
//  Acto3D
//
//  Created by Naoki Takeshita on 2022/01/01.
//

import Cocoa
import simd

// Main View for output rendered image 

protocol ModelViewProtocol: AnyObject {
    func modelViewMouseMoved(with event: NSEvent, point: NSPoint)
    func modelViewMouseDragged(with event: NSEvent, mouse startPoint: NSPoint, previousPoint: NSPoint, currentPoint: NSPoint)
    func modelViewMouseUp(mouse startPoint: NSPoint, currentPoint: NSPoint)
    func modelViewMouseClicked(mouse point: NSPoint)
    func modelViewMouseWheeled(with event: NSEvent)
}

class ModelView: NSImageView {
    
    weak var view: ModelViewProtocol?
    
    var mouseMovedDuringMouseDown = false
    
    var isMouseOperating:Bool = false
    var currentMousePoint:NSPoint?
    var startMousePoint:NSPoint?
    var previousMousePoint:NSPoint?
    
    
    
    override func awakeFromNib() {
        super.awakeFromNib()
        configure()
    }
    
    func configure() {
        let options:NSTrackingArea.Options = [
            .mouseMoved,
            .cursorUpdate,
            .activeAlways,
            .enabledDuringMouseDrag
        ]
        let trackingArea = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(trackingArea)
    }
    
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }
    
    
    
    override func updateTrackingAreas() {
        if !trackingAreas.isEmpty {
            for area in trackingAreas {
                removeTrackingArea(area)
            }
        }
        
        if bounds.size.width == 0 || bounds.size.height == 0 { return }
        
        let options:NSTrackingArea.Options = [
            .mouseMoved,
            .cursorUpdate,
            .activeAlways,
            .enabledDuringMouseDrag
        ]
        
        let area = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(area)
    }
    
    
    override var acceptsFirstResponder: Bool {return true}
    
    
    override func mouseDown(with event: NSEvent) {
        //NSLog("mouseDown")

        currentMousePoint = event.locationInWindow
        startMousePoint = currentMousePoint
        previousMousePoint = startMousePoint
        
        isMouseOperating = true
        mouseMovedDuringMouseDown = false
    }

    override func mouseUp(with event: NSEvent) {
        currentMousePoint = event.locationInWindow
        
        if isMouseOperating == true {
            if(mouseMovedDuringMouseDown == true){
                view?.modelViewMouseUp(mouse: startMousePoint!, currentPoint: currentMousePoint!)
            }else{
                view?.modelViewMouseClicked(mouse: startMousePoint!)
            }
        }
        
        mouseMovedDuringMouseDown = false
        isMouseOperating = false
    }
    override func mouseDragged(with event: NSEvent) {
        previousMousePoint = currentMousePoint
        currentMousePoint = event.locationInWindow
        
        if isMouseOperating == true {
            mouseMovedDuringMouseDown = true
            view?.modelViewMouseDragged(with: event, mouse: startMousePoint!, previousPoint: previousMousePoint!, currentPoint: currentMousePoint!)
        }
        
    }

    
    override func mouseMoved(with event: NSEvent) {
//       view?.modelViewMouseMoved(with: event)
        view?.modelViewMouseMoved(with: event, point: event.locationInWindow)
//        event.locationInWindow
    }
    
    override func scrollWheel(with event: NSEvent) {
        view?.modelViewMouseWheeled(with: event)
    }
    
    override func rightMouseUp(with event: NSEvent) {
    }
    
    
    
}
