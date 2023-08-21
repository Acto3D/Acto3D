//
//  toneView.swift
//  toneCurve
//
//  Created by Naoki Takeshita on 2021/06/13.
//

import Cocoa
import Accelerate
import simd


protocol ToneCurveViewProtocol: AnyObject {
    func vMouseMoved(with event: NSEvent)
    func vMouseDragged(mouse startPoint: NSPoint, previousPoint: NSPoint, currentPoint: NSPoint)
    func vMouseUp(mouse startPoint: NSPoint, currentPoint: NSPoint)
    func splineDidChange(identifier:String?, sender:ToneCurveView)
    func splineIsEditting(identifier:String?, sender:ToneCurveView)
}

class ToneCurveView: NSView {
    weak var delegate: ToneCurveViewProtocol?
    
    let minRange:Int = 0
    let maxRange:Int = 255
    var lineWith:CGFloat = 1.8
    var borderLineWith:CGFloat = 1.5
    var knobSize:CGFloat = 8
    
    var relativeView:NSView?
    var mouseOverIndex:Int?
    
    var lineColor:NSColor = NSColor.white
    var highlightColor:NSColor = NSColor.red
    
    var backgroundColor:NSColor = NSColor.gridColor
    var borderColor = NSColor.unemphasizedSelectedTextBackgroundColor
    
    var histogram:[UInt32]?{
        didSet{
            updateView()
        }
    }
    
    var controlPoints:[[Float]] = [
        [0,0],
        [255,1]
    ]
    
    var interpolateMode: CubicSplineInterpolator.InterpolateMode = .cubicSpline{
        didSet{
            spline?.interpolateMode = interpolateMode
            updateView()
        }
    }
    
    
    var spline: CubicSplineInterpolator? {
        didSet {
            updateView()
        }
    }
    
    func getControlPoint() -> [[Float]]{
        return controlPoints
    }
    
    func setControlPoint(array : [[Float]], redraw:Bool = true) {
        self.controlPoints = array
        mouseOverIndex = nil
        updateSpline()
        updateView()
    }
    
    
    func updateView(){
        self.setNeedsDisplay(self.bounds)
    }
    
    override func viewWillDraw() {
        super.viewWillDraw()
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
            .mouseEnteredAndExited,
            .cursorUpdate,
            .activeAlways,
            .enabledDuringMouseDrag
        ]
        
        let area = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(area)
    }
    
    private func updateSpline(){
        let xP = controlPoints.map{
            $0[0]
        }
        let yP = controlPoints.map{
            $0[1]
        }
        
        if let spline = spline{
            spline.updateSpline(xPoints: xP, yPoints: yP)
        }else{
            self.spline = CubicSplineInterpolator(xPoints:xP, yPoints:yP)
        }
    }
    
    func getInterpolatedValues(scale: Int)->[Float]?{
        guard let spline = spline else {
            return nil
            
        }
        
        
        let xPs =  vDSP.ramp(withInitialValue: 0.0,
                             increment: 1.0 / Float(scale),
                             count: 255 * scale + 1)
        
        var interpolatedValues = xPs.map{
            Float(spline.interpolate($0))
        }
        
        // clip the alpha values to 0.0 - 1.0
        vDSP.clip(interpolatedValues, to: 0 ... 1, result: &interpolatedValues)
        
        return interpolatedValues
    }
//
//    private func drawBackground(_ dirtyRect: NSRect){
//        let roundrRectangleBack = NSBezierPath(roundedRect: NSRect(x: knobSize, y: knobSize, width: self.frame.width-knobSize*2, height: self.frame.height-knobSize*2), xRadius: knobSize, yRadius: knobSize)
//
//
//        backgroundColor.setFill()
//        roundrRectangleBack.fill()
//
//        borderColor.setStroke()
//        roundrRectangleBack.lineWidth = borderLineWith
//        roundrRectangleBack.stroke()
//    }
    
    
    // calculate Kernel Density Estimation, KDE
    // apply smoothing
    func gaussianKernelSmoothing(data: [Double], kernelBandwidth: Double) -> [Double] {
        var smoothedData = [Double](repeating: 0, count: data.count)
        let constant = 1 / sqrt(2 * .pi * kernelBandwidth * kernelBandwidth)

        for i in 0..<data.count {
            for j in 0..<data.count {
                let diff = Double(i - j)
                smoothedData[i] += data[j] * constant * exp(-0.5 * diff * diff / (kernelBandwidth * kernelBandwidth))
            }
        }
        
        return smoothedData
    }
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        guard let spline = spline else {
            Logger.logOnlyToFile(message: "spline curve has not been created.", level: .error)
            return
        }
        
        let graphSize = getGraphSize()
        
        // set the clip area
        let roundrRectangle = NSBezierPath(roundedRect: NSRect(x: knobSize, y: knobSize, width: self.frame.width-knobSize*2, height: self.frame.height-knobSize*2), xRadius: knobSize, yRadius: knobSize)
        
        NSGraphicsContext.current?.saveGraphicsState()
        roundrRectangle.addClip()
        
        if let histogramData = histogram {
            // パーセンタイルでスケーリング
            let sortedHistogramData = histogramData.sorted()
            let lowerIndex = Int(Double(sortedHistogramData.count) * 0.02)
            let upperIndex = Int(Double(sortedHistogramData.count) * 0.98)
            let lowerBound = Double(sortedHistogramData[lowerIndex])
            let upperBound = Double(sortedHistogramData[upperIndex])
            let clippedHistogramData = histogramData.map { min(max(Double($0), lowerBound), upperBound) }

            // ヒストグラムのバーの幅を設定
            let barWidth = Double(graphSize.width) / Double(histogramData.count)
            // ヒストグラムデータの平滑化
            let smoothedHistogramData = gaussianKernelSmoothing(data: clippedHistogramData, kernelBandwidth: 3.0)
            
            // グラフのスケールを設定
            let maxValue = smoothedHistogramData.max() ?? 0
            if (maxValue != 0){
                let scaleFactor = Double(graphSize.height) / maxValue * 0.9
                // ヒストグラムの描画
                let histogramPath = NSBezierPath()
                histogramPath.lineWidth = 1.0
                NSColor.darkGray.setStroke()
                for (index, data) in smoothedHistogramData.enumerated() {
                    let height = data * scaleFactor
                    let rect = CGRect(x: knobSize + CGFloat(index) * CGFloat(barWidth), y: knobSize, width: CGFloat(barWidth), height: CGFloat(height))
                    histogramPath.append(NSBezierPath(rect: rect))
                }
                histogramPath.stroke()
            }
        }
        
        // draw graph border
        NSGraphicsContext.current?.restoreGraphicsState()
        roundrRectangle.lineWidth = borderLineWith
        borderColor.setStroke()
        roundrRectangle.stroke()
        roundrRectangle.addClip()
        
        
        // draw curves
        // get Y values (0.0 - 1.0)
        var interpolateY = (0...255).map{
            spline.interpolate(Float($0))
        }
        vDSP.clip(interpolateY, to: 0 ... 1, result: &interpolateY)
        
        
        // draw alpha curve
        let pathSp = NSBezierPath()
        pathSp.lineWidth = lineWith
        
        lineColor.setStroke()
        lineColor.withAlphaComponent(0.2).setFill()
        
        pathSp.move(to: CGPoint(x: 0, y: 0))
        pathSp.line(to: CGPoint(x: 0, y: knobSize + CGFloat(interpolateY[0]) * graphSize.height))
        
        for x in 0...255 {
            pathSp.line(to: CGPoint(x: knobSize + CGFloat(x) * graphSize.width / 255,
                                        y: knobSize + CGFloat(interpolateY[x]) * graphSize.height))
            
        }
        
        pathSp.line(to: CGPoint(x: knobSize +  graphSize.width + knobSize, y: knobSize + CGFloat(interpolateY[255]) * graphSize.height))
        pathSp.line(to: CGPoint(x: knobSize +  graphSize.width + knobSize, y: 0))

        pathSp.stroke()
        pathSp.fill()
        
        
        
        // draw knobs
        NSGraphicsContext.current?.restoreGraphicsState()
        
        for i in 0..<self.spline!.xValues().count{
            let grabKnob = NSBezierPath()
            grabKnob.appendArc(withCenter:
                                NSMakePoint(
                                    knobSize + CGFloat(self.spline!.xValues()[i]) * graphSize.width / 255,
                                    knobSize + CGFloat(self.spline!.yValues()[i]) * graphSize.height),
                               radius: knobSize,
                               startAngle: 0, endAngle: 360)
            
            if (mouseOverIndex != nil && mouseOverIndex == i){
                highlightColor.setFill()
                
            }else{
                lineColor.setFill()
                
            }
            
            grabKnob.fill()
        }
    }
    
    
    
    override func awakeFromNib() {
        super.awakeFromNib()
        updateTrackingAreas()
        updateSpline()
    }
    
    func setDefaultBackgroundColorRed(){
        lineColor = NSColor(calibratedRed: 247/255, green: 43/255, blue: 45/255, alpha: 1)
        highlightColor = NSColor.white
    }
    func setDefaultBackgroundColorGreen(){
        lineColor = NSColor(calibratedRed: 48/255, green: 211/255, blue: 58/255, alpha: 1)
        highlightColor = NSColor.white
    }
    func setDefaultBackgroundColorBlue(){
        lineColor = NSColor(calibratedRed: 38/255, green: 107/255, blue: 255/255, alpha: 1)
        highlightColor = NSColor.white
    }
    func setDefaultBackgroundColor(color: NSColor){
        lineColor = color
        highlightColor = NSColor.white
    }
    
    private func getGraphSize() -> CGSize {
        return CGSize(width: self.bounds.width - knobSize * 2, height: self.bounds.height - knobSize * 2)
    }
    
    private func getPointInView(from event: NSEvent) -> CGPoint {
        return self.relativeView!.convert(event.locationInWindow, to: self)
    }
    
    override func mouseMoved(with event: NSEvent) {
        let point = getPointInView(from: event)
        let graphSize = getGraphSize()
        
        
        for (index, value) in controlPoints.enumerated() {
            let xPointInView = knobSize + CGFloat(value[0]) * graphSize.width / 255
            let yPointInView = knobSize + CGFloat(value[1]) * graphSize.height
            
            if (xPointInView - knobSize < point.x && point.x < xPointInView + knobSize &&
                    yPointInView - knobSize < point.y && point.y < yPointInView + knobSize) {
                mouseOverIndex = index
                updateView()
                return
            }
        }
        
        if mouseOverIndex != nil {
            mouseOverIndex = nil
            updateView()
        }
    }
    
    override func mouseDragged(with event: NSEvent) {
        let point = getPointInView(from: event)
        let graphSize = getGraphSize()
        
        var xPoint = (point.x - knobSize) / graphSize.width * 255
        var yPoint = (point.y - knobSize) / graphSize.height
        
        guard let mouseOverIndex = mouseOverIndex else {
            return
        }
        
        // Check if point is not the first or last and ensure it doesn't overlap the neighboring points
        if mouseOverIndex > 0 && mouseOverIndex < controlPoints.count - 1 {
            let lowerBoundX = Float(controlPoints[mouseOverIndex - 1][0]) + 1
            let upperBoundX = Float(controlPoints[mouseOverIndex + 1][0]) - 1
            
            if Float(xPoint) < lowerBoundX || Float(xPoint) > upperBoundX {
                return
            }
        }
        
        // Constrain xPoint for first and last control points
        if mouseOverIndex == 0 {
            xPoint = 0
        } else if mouseOverIndex == controlPoints.count - 1 {
            xPoint = 255
        }
        
        // Constrain xPoint and yPoint within [0, 255] and [0, 1] respectively
        xPoint = max(0, min(255, xPoint))
        yPoint = max(0, min(1, yPoint))
        
        controlPoints[mouseOverIndex] = [Float(xPoint), Float(yPoint)]
        updateSpline()
        updateView()
        delegate?.splineIsEditting(identifier: self.identifier?.rawValue, sender: self)
    }

    override func mouseDown(with event: NSEvent) {
        let point = getPointInView(from: event)
        let graphSize = getGraphSize()

        let xPoint = (point.x - knobSize) / graphSize.width * 255
        let yPoint = (point.y - knobSize) / graphSize.height

        // Check if the point is within the valid range
        guard point.x > knobSize && point.x < knobSize + graphSize.width &&
              point.y > knobSize && point.y < knobSize + graphSize.height else {
            return
        }

        // Insert new control point if the mouse is not over any knob
        if mouseOverIndex == nil {
            if let insertIndex = controlPoints.firstIndex(where: { $0[0] > Float(xPoint) }) {
                controlPoints.insert([Float(xPoint), Float(yPoint)], at: insertIndex)
                mouseOverIndex = insertIndex
                updateSpline()
                updateView()
                delegate?.splineDidChange(identifier: self.identifier?.rawValue, sender: self)
            }
        }
    }

    override func mouseUp(with event: NSEvent) {
        delegate?.splineDidChange(identifier: self.identifier?.rawValue, sender: self)
    }
    
    override func rightMouseDown(with event: NSEvent) {
        if let mouseOverIndex = mouseOverIndex {
            // remove the control point
            if mouseOverIndex != 0 && mouseOverIndex != controlPoints.count-1 {
                controlPoints.remove(at: mouseOverIndex)
                self.mouseOverIndex = nil
                updateSpline()
                updateView()
                delegate?.splineDidChange(identifier: self.identifier?.rawValue, sender: self)
            }
        } else {
            guard let spline = spline else {return}
            
            let menu = NSMenu()
            
            // Add menu items
            let item0 = NSMenuItem(title: "Curve style", action: #selector(selectInterpolateModeMenuItem(_:)), keyEquivalent: "")
            let item1 = NSMenuItem(title: "Spline Curve", action: #selector(selectInterpolateModeMenuItem(_:)), keyEquivalent: "")
            let item2 = NSMenuItem(title: "Lines", action: #selector(selectInterpolateModeMenuItem(_:)), keyEquivalent: "")
            let item3 = NSMenuItem.separator()
            let item4 = NSMenuItem(title: "Copy the list of transfer functions to the clipboard", action: #selector(copyTransferFunctionTable(_:)), keyEquivalent: "")
            let item5 = NSMenuItem(title: "Copy control points", action: #selector(copyControlPoints(_:)), keyEquivalent: "")
            let item6 = NSMenuItem(title: "Paste control points", action: #selector(pasteControlPoints(_:)), keyEquivalent: "")
            
            if(spline.interpolateMode == .cubicSpline){
                item1.state = .on
            }else{
                item2.state = .on
            }
            
            item1.identifier = NSUserInterfaceItemIdentifier(rawValue: "spline")
            item2.identifier = NSUserInterfaceItemIdentifier(rawValue: "line")
            
            menu.addItem(item0)
            menu.addItem(item1)
            menu.addItem(item2)
            item1.indentationLevel = 1
            item2.indentationLevel = 1
            menu.addItem(item3)
            menu.addItem(item4)
            menu.addItem(item5)
            menu.addItem(item6)
            
            // Set the target for menu item actions
            item1.target = self
            item2.target = self
            item4.target = self
            item5.target = self
            
            if(isClipboardFormatValidForControlPoints()){
                item6.target = self
                item6.isEnabled = true
            }else{
                item6.isEnabled = false
            }
            
            let location = NSEvent.mouseLocation
            
            
            // Show menu at cursor location
            menu.popUp(positioning: nil, at: location, in: nil)
        }
    }
    
    private func isClipboardFormatValidForControlPoints() -> Bool{
        let pasteboard = NSPasteboard.general

          // Check if the clipboard contains string data
          guard let stringData = pasteboard.string(forType: .string) else {
              return false
          }
        
        // Each line represents a pair of control points
        let lines = stringData.split(separator: "\n")
        guard !lines.isEmpty else {
            return false
        }
        
        // Check if the header is "X\tY"
        if lines[0] != "X\tY" {
            return false
        }
        
        return true
    }
    
    
    // Menu item actions
    @objc func selectInterpolateModeMenuItem(_ sender: NSMenuItem) {
        if(sender.identifier?.rawValue == "spline"){
            spline!.interpolateMode = .cubicSpline
        }else{
            spline?.interpolateMode = .linear
        }
        updateView()
        delegate?.splineDidChange(identifier: self.identifier?.rawValue, sender: self)
    }
    
    @objc func copyTransferFunctionTable(_ sender: NSMenuItem) {
        guard let table = self.getInterpolatedValues(scale: 10) else {return}
        
        var stringTable = table.enumerated().map { (index, value) -> String in
            return "\(Double(index)/10.0)\t\(value)"
        }.joined(separator: "\n")
        stringTable = "Pixel value\tOpacity\n" + stringTable

        // Copy to clipboard
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(stringTable, forType: .string)
    }
    @objc func copyControlPoints(_ sender: NSMenuItem) {
        let controlPoints = self.controlPoints // This is assumed to be [[Float]]
        
        var stringTable = controlPoints.enumerated().map { (index, value) -> String in
            return "\(value[0])\t\(value[1])"
        }.joined(separator: "\n")
        stringTable = "X\tY\n" + stringTable

        // Copy to clipboard
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(stringTable, forType: .string)
    }
    
    @objc func pasteControlPoints(_ sender: NSMenuItem) {
        let pasteboard = NSPasteboard.general

        // Check if the clipboard contains string data
        guard let stringData = pasteboard.string(forType: .string) else {
            return
        }
        
        // Each line represents a pair of control points
        let lines = stringData.split(separator: "\n")
        
        // Check if there is at least one line (the header)
        guard !lines.isEmpty else {
            return
        }
        
        // Check if the header is "X\tY"
        if lines[0] != "X\tY" {
            return
        }
        
        // Remove the header
        let controlPointLines = lines.dropFirst()
        var controlPoints:[[Float]] = []
        // Try to convert each line into a pair of Floats
        for line in controlPointLines {
            let stringValues = line.split(separator: "\t").map { String($0) }
            
            if stringValues.count != 2 {
                return
            }
            
            guard let v1 = Float(stringValues[0]),
                  let v2 = Float(stringValues[1]) else {
                return
            }
            controlPoints.append([v1, v2])
        }
        
        // If all lines are successfully converted, the format is valid
        self.setControlPoint(array: controlPoints)


    }

    
}
