//
//  EXButton.swift
//  Acto3D
//
//  Created by Naoki Takeshita on 2023/06/14.
//

import Cocoa

class EXButton: NSButton, NSPopoverDelegate  {
    
    var sheetView:NSView?
    var popover: NSPopover!
    var hoverTimer: Timer?

    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // Drawing code here.
        
    }
    
    
    override func awakeFromNib() {
        super.awakeFromNib()
        configure()
        
        print("POP OVER")
        popover = NSPopover()
        popover.behavior = .transient
        popover.delegate = self
    }
    
    func configure() {
        let options:NSTrackingArea.Options = [
            .mouseMoved,
            .cursorUpdate,
            .mouseEnteredAndExited,
            .activeAlways,
            .enabledDuringMouseDrag
        ]
        let trackingArea = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(trackingArea)
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
    
    override func mouseMoved(with event: NSEvent) {
 
    }
    
    override func mouseEntered(with event: NSEvent) {
        
            hoverTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { [weak self] _ in
                self!.showExplanationSheet(for: self!)
                  }
    }
    override func mouseExited(with event: NSEvent) {
        // Dismiss the explanation sheet
        popover.performClose(self)
        hoverTimer?.invalidate()
        
    }
    func popoverShouldDetach(_ popover: NSPopover) -> Bool {
        return true
    }
    
    func showExplanationSheet(for control: NSControl) {
        let explanationViewController = NSViewController()
        explanationViewController.view = NSView(frame: NSRect(x: 0, y: 0, width: 450, height: 300))
        explanationViewController.view.wantsLayer = true

        popover.contentViewController = explanationViewController
        
        var rect = control.bounds
        rect.origin.x -= 5
        
        
        let explanation = """
                    checked: The image is constructed by sampling XYZ in the same proportion as the current view size. The final image is influenced by the value of the scale.

                    unchecked: The image is constructed by sampling XYZ in the same proportion as the original image size. It is then adjusted to the view size. The final image is not affected by the scale value, but larger original image sizes result in higher computational load.

                    In both cases, increasing the step value allows reducing the number of samples towards the back of the visual field. For example, if the step is 1.5, x : y : z will be sampled in a ratio of 1 : 1 : 1.5.
                    """

        
        let label = NSTextField(labelWithString: explanation)
        label.frame = explanationViewController.view.bounds
        label.setFrameOrigin(NSPoint(x: 10, y: 10))
        label.setFrameSize(NSMakeSize(explanationViewController.view.frame.width - 20, explanationViewController.view.frame.height - 20))

        label.lineBreakMode = .byWordWrapping
        
        explanationViewController.view.addSubview(label)
        
        
        popover.show(relativeTo: rect, of: control, preferredEdge: .maxY)
    }
    
}
