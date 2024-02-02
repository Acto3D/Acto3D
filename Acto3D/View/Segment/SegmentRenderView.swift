//
//  SegmentRenderView.swift
//  Acto3D
//
//  Created by Naoki Takeshita on 2023/01/05.
//

/*
 Description:
  This file defines the custom view displayed in the segment window.

  Main Features:
  - Allows the user to select a working area via mouse interaction.
  - Makes cursor position more visible when manipulating cluster images.
  - Synchronizes cursor position across multiple views.
*/

import Cocoa
import simd

protocol SegmentRenderViewProtocol: AnyObject {
    func segmentRenderViewMouseMoved(view:SegmentRenderView, with event: NSEvent, point: NSPoint)
    func segmentRenderViewMouseDragged(view:SegmentRenderView, mouse startPoint: NSPoint, previousPoint: NSPoint, currentPoint: NSPoint)
    func segmentRenderViewMouseUp(view:SegmentRenderView, mouse startPoint: NSPoint, currentPoint: NSPoint)
    func segmentRenderViewMouseClicked(view:SegmentRenderView, mouse point: NSPoint)
    func segmentRenderViewMouseWheeled(view:SegmentRenderView, with event: NSEvent)
    
    
    func segmentRenderViewAreaConfirm(view:SegmentRenderView, area: NSRect)
    func segmentRenderViewAreaClicked(view:SegmentRenderView, point:NSPoint)
}

class SegmentRenderView: NSImageView {
    
    weak var view: SegmentRenderViewProtocol?
    
    var mouseMovedDuringMouseDown = false
    
    var isMouseOperating:Bool = false
    var currentMousePoint:NSPoint?
    var startMousePoint:NSPoint?
    var previousMousePoint:NSPoint?
    
    /// current focused area
    var confirmedArea:NSRect?
    
    var marker:NSPoint?
    
    var forceDrawLine = false
    private var isMouseInsideView = false
    
    var linkViews:[SegmentRenderView] = []
    
    private enum ToolMode {
        case none
        case hover
        case down
        case area
    }
    private var toolMode:ToolMode = .none
    
    private var isCommandKeyHeld = false
    
    override func awakeFromNib() {
        super.awakeFromNib()
        self.updateTrackingAreas()
    }
    
    override var isFlipped: Bool {
        return true
    }
    
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }
    
    override var acceptsFirstResponder: Bool {
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
            .mouseEnteredAndExited,
            .activeAlways,
            .enabledDuringMouseDrag
        ]
        
        let area = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(area)
    }
    
    public func redraw(){
        self.setNeedsDisplay(self.bounds)
    }
    
    func getCurrentMousePointInView(point: NSPoint) -> NSPoint{
        var pt = self.superview!.convert(point, to: self)
        if(pt.x >= self.bounds.width){
            pt.x = self.bounds.width
        }
        if(pt.x < 0){
            pt.x = 0
        }
        
        if(pt.y >= self.bounds.height){
            pt.y = self.bounds.height
        }
        if(pt.y < 0){
            pt.y = 0
        }
        return pt
    }
    
    override func mouseExited(with event: NSEvent) {
        
        NSCursor.arrow.set()
        NSCursor.unhide()
        isMouseInsideView = false
        
        if(linkViews.count != 0){
            for item in linkViews{
                print(item)
                item.currentMousePoint = nil
                item.redraw()
            }
        }
        
        
        if(event.modifierFlags.contains(.command) == true){
            isCommandKeyHeld = true
        }else{
            isCommandKeyHeld = false
        }
        
        if(toolMode == .area){
            return
        }
        toolMode = .none
        redraw()
    }
    
    override func mouseEntered(with event: NSEvent) {
        isMouseInsideView = true
        if(forceDrawLine == true){
            NSCursor.hide()
        }
        
        if(event.modifierFlags.contains(.command) == true){
            isCommandKeyHeld = true
        }else{
            isCommandKeyHeld = false
        }
        
        if(toolMode == .area){
            return
        }
        
        toolMode = .hover
        
        currentMousePoint = getCurrentMousePointInView(point: event.locationInWindow)
        
        redraw()
    }
    
    override func mouseDown(with event: NSEvent) {
        currentMousePoint = getCurrentMousePointInView(point: event.locationInWindow)
        startMousePoint = currentMousePoint
        previousMousePoint = startMousePoint
        confirmedArea = nil
        
        isMouseOperating = true
        mouseMovedDuringMouseDown = false
        
        
        if(event.modifierFlags.contains(.command) == true){
            isCommandKeyHeld = true
        }else{
            isCommandKeyHeld = false
        }
        
        currentMousePoint = getCurrentMousePointInView(point: event.locationInWindow)
        
        
        toolMode = .down
        redraw()
    }
    

    override func mouseUp(with event: NSEvent) {
        if(event.modifierFlags.contains(.command) == true){
            isCommandKeyHeld = true
        }else{
            isCommandKeyHeld = false
        }
        
        currentMousePoint = getCurrentMousePointInView(point: event.locationInWindow)
        
        if(isCommandKeyHeld == true){
            
            if toolMode == .area{
                currentMousePoint = getCurrentMousePointInView(point: event.locationInWindow)
                
                guard let startMousePoint = startMousePoint ,
                      let currentMousePoint = currentMousePoint else {return}
                
                let areaRect = NSMakeRect(startMousePoint.x, startMousePoint.y,
                                          currentMousePoint.x - startMousePoint.x,
                                          currentMousePoint.y - startMousePoint.y)
//                confirmedArea = areaRect.standardized
                confirmedArea = areaRect.standardized.integral
                
                
                view?.segmentRenderViewAreaConfirm(view: self, area: confirmedArea!)
                print(areaRect.standardized, areaRect.standardized.integral)
                
                toolMode = .hover
                
            }else if toolMode == .down{
                currentMousePoint = getCurrentMousePointInView(point: event.locationInWindow)
                guard let currentMousePoint = currentMousePoint else {return}
                view?.segmentRenderViewAreaClicked(view: self, point: currentMousePoint)
                toolMode = .hover
            }
            
            redraw()
            
            startMousePoint = nil
            previousMousePoint = nil
            
        }else{
            if isMouseOperating == true {
                if(mouseMovedDuringMouseDown == true){
                    view?.segmentRenderViewMouseUp(view: self, mouse: startMousePoint!, currentPoint: currentMousePoint!)
                }else{
                    view?.segmentRenderViewMouseClicked(view: self, mouse: startMousePoint!)
                }
            }
            
            mouseMovedDuringMouseDown = false
            isMouseOperating = false
            
            startMousePoint = nil
            previousMousePoint = nil
            toolMode = .hover
            
        }
    }
    
    override func mouseDragged(with event: NSEvent) {
        previousMousePoint = currentMousePoint
        currentMousePoint = getCurrentMousePointInView(point: event.locationInWindow)
        
        if(event.modifierFlags.contains(.command) == true){
            isCommandKeyHeld = true
        }else{
            isCommandKeyHeld = false
        }
        
        if(toolMode == .down){
            toolMode = .area
        }
        
        if toolMode == .area{
            currentMousePoint = getCurrentMousePointInView(point: event.locationInWindow)
        }
        
        if(isCommandKeyHeld == true){
            redraw()
        }else{
            if isMouseOperating == true {
                mouseMovedDuringMouseDown = true
                view?.segmentRenderViewMouseDragged(view: self, mouse: startMousePoint!, previousPoint: previousMousePoint!, currentPoint: currentMousePoint!)
            }
        }
        
    }
    
    override func mouseMoved(with event: NSEvent) {
        isMouseInsideView = true
        
        currentMousePoint = getCurrentMousePointInView(point: event.locationInWindow)
        guard let currentMousePoint = currentMousePoint else {return}
        
        view?.segmentRenderViewMouseMoved(view: self, with: event, point: currentMousePoint)
        
        if(event.modifierFlags.contains(.command) == true){
            isCommandKeyHeld = true
        }else{
            isCommandKeyHeld = false
        }
        
        if(toolMode == .none){
            toolMode = .hover
        }
        
        redraw()
    }
    
    override func scrollWheel(with event: NSEvent) {
        view?.segmentRenderViewMouseWheeled(view: self, with: event)
    }
    
    override func rightMouseUp(with event: NSEvent) {
    }
    
    
    override func draw(_ dirtyRect: NSRect) {
        // draw background (black) of this view
        NSColor.black.set()
        let rects = NSBezierPath()
        rects.appendRect(self.bounds)
        rects.fill()
        
        // draw border (gray) of this view
        super.draw(dirtyRect)
        NSColor.secondaryLabelColor.setStroke()
        rects.stroke()
        
        if(marker != nil){
            NSColor.red.set()
            let rects = NSBezierPath()
            rects.appendArc(withCenter: marker!, radius: 4, startAngle: 0, endAngle: 360)
//            rects.appendRect(confirmedArea!.standardized)
//            rects.fill()
            rects.stroke()
        }
        
        if(confirmedArea != nil){
            NSColor.red.set() // choose color
            NSColor(calibratedRed: 1, green: 0, blue: 0, alpha: 0.2).setFill()
            
            let rects = NSBezierPath() // container for line(s)
            rects.appendRect(confirmedArea!.standardized.integral)
            rects.fill()
            rects.stroke()
        }
        
        if(forceDrawLine == true && isMouseInsideView == true){
            guard let currentMousePoint = currentMousePoint else {return}
            
            NSColor.red.set()
            
            let lines = NSBezierPath()
            lines.lineWidth = 1.5
            
            lines.move(to: NSMakePoint(0, currentMousePoint.y))
            lines.line(to: NSMakePoint(self.bounds.width, currentMousePoint.y))
            
            lines.move(to: NSMakePoint(currentMousePoint.x, 0))
            lines.line(to: NSMakePoint(currentMousePoint.x, self.bounds.height))
            
            lines.stroke()
            
            if(linkViews.count != 0){
                for item in linkViews{
                    print(item)
                    item.currentMousePoint = currentMousePoint
                    item.isMouseInsideView = true
                    item.redraw()
                }
            }
        }
        
        
        if(isCommandKeyHeld == false){
            return
        }
        
        guard let currentMousePoint = currentMousePoint else {return}
        
        switch toolMode {
        case .none:
            break
            
        case .hover:
            NSColor.red.set()
            
            let lines = NSBezierPath()
            lines.lineWidth = 1.5
            
            lines.move(to: NSMakePoint(0, currentMousePoint.y))
            lines.line(to: NSMakePoint(self.bounds.width, currentMousePoint.y))
            
            lines.move(to: NSMakePoint(currentMousePoint.x, 0))
            lines.line(to: NSMakePoint(currentMousePoint.x, self.bounds.height))
            
            lines.stroke()
            
        case .area:
            guard let startMousePoint = startMousePoint else {return}
            
            NSColor.red.set() // choose color
            NSColor(calibratedRed: 1, green: 0, blue: 0, alpha: 0.2).setFill()
            
            let rects = NSBezierPath() // container for line(s)
            rects.appendRect(NSMakeRect(startMousePoint.x, startMousePoint.y,
                                        currentMousePoint.x - startMousePoint.x,
                                        currentMousePoint.y - startMousePoint.y).standardized)
            rects.fill()
            rects.stroke()
            
        default:
            break
        }
    }
}
