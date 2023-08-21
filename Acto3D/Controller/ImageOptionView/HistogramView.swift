//
//  HistogramView.swift
//  Acto3D
//
//  Created by Naoki Takeshita on 2022/08/22.
//

import Cocoa


protocol HistogramViewProtocol {
    func adjustRanges(channel: Int, ranges:[Double])
}

class HistogramView: NSView {
    var delegate: HistogramViewProtocol?
    
    var channel = 0
    var knobSize:CGFloat = 6
    
    var isResizing = false
    
    var _histogram:[UInt32]?
    var histogram:[UInt32]?{
        get{
            return _histogram
        }
        set{
            _histogram = newValue
            
            update()
            
            histogramClip8(bit: currentClipBit)
            previousClipBit = currentClipBit
            
            updateView()
        }
    }
    var clippedHistogram:[UInt32]?
    var color:NSColor = NSColor.systemGray
    
    var backgroundColor:NSColor = NSColor.gridColor
    var borderColor = NSColor.unemphasizedSelectedTextBackgroundColor
    
    var displayRanges:[Double]?
    
    var bit:Int = 0
    var currentClipBit:Int = 0
    var previousClipBit:Int = 0
    
    @IBOutlet weak var bitButton_8: NSButton!
    @IBOutlet weak var bitButton_10: NSButton!
    @IBOutlet weak var bitButton_12: NSButton!
    @IBOutlet weak var bitButton_14: NSButton!
    @IBOutlet weak var bitButton_16: NSButton!
    
    
    var maxIntensity:Int{
        get{
            let max = pow(2, bit) - 1
            return NSDecimalNumber(decimal: max).intValue
        }
    }
    var maxIntensityForCurrentClipBit:Int{
        get{
            let max = pow(2, currentClipBit) - 1
            return NSDecimalNumber(decimal: max).intValue
        }
    }
    
    enum MouseHoverPoint{
        case controlPoint1over
        case controlPoint1grab
        case controlPoint2over
        case controlPoint2grab
        case none
    }
    var mouseHoverPoint:MouseHoverPoint = .none
    
    let vMargin:CGFloat = 20
    
    var graphSize:CGSize{
        get{
            return CGSize(width: self.bounds.width-knobSize * 2, height: self.bounds.height-knobSize * 2 - vMargin)
        }
    }
    
    var controlPoints:[NSPoint] = [NSPoint](repeating: NSPoint(x: 0, y: 0), count: 2)
    
    @IBOutlet var view: NSView!
    
    @IBOutlet weak var bitClipTo8: NSButton!
    @IBOutlet weak var bitClipTo10: NSButton!
    @IBOutlet weak var bitClipTo12: NSButton!
    @IBOutlet weak var bitClipTo14: NSButton!
    @IBOutlet weak var bitClipTo16: NSButton!
    
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        
        loadNib()
    }
    
    @IBAction func bitClip(_ sender: NSButton) {
        currentClipBit = sender.tag
        
        bitClipTo8.state = .off
        bitClipTo10.state = .off
        bitClipTo12.state = .off
        bitClipTo14.state = .off
        bitClipTo16.state = .off
        
        switch sender.tag {
        case 8:
            print("clip 8")
            histogramClip8(bit: 8)
            break
        case 10:
            print("clip 10")
            histogramClip8(bit: 10)
            break
        case 12:
            histogramClip8(bit: 12)
            print("clip 12")
            break
        case 14:
            histogramClip8(bit: 14)
            print("clip 14")
            break
        case 16:
            histogramClip8(bit: 16)
            print("clip 16")
            break
        default:
            break
        }
        sender.state = .on
        print("red", self.bounds)
        update()
        self.setNeedsDisplay(self.bounds)
    }
    override class func awakeFromNib() {
        print("nib")
    }
    
    @objc func hist16bit(_ sender:Any){
        print("16bitbut")
    }
    
    override func updateTrackingAreas() {
        //すでに指定済みのtrackingAreaを一旦解除しておく
        if !trackingAreas.isEmpty {
            for area in trackingAreas {
                removeTrackingArea(area)
            }
        }
        
        if bounds.size.width == 0 || bounds.size.height == 0 { return }
        
        //トラッキングオプションを指定(Enter / Exit と一緒に Moved も対象に)
        let options:NSTrackingArea.Options = [
            .mouseMoved,
            .cursorUpdate,
            .activeAlways,
            .enabledDuringMouseDrag
        ]
        
        let area = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(area)
        //        print("update track")
    }
    
    override func viewWillStartLiveResize() {
//        update()
        updateView()
        
        isResizing = true
    }
    override func viewDidEndLiveResize() {
//        update()
        updateView()
        
        isResizing = false
    }

    func loadNib() {
        let name = String(describing: HistogramView.self)
        if let nib = NSNib(nibNamed: name, bundle: Bundle(for: type(of: self))) {
            nib.instantiate(withOwner: self, topLevelObjects: nil)
            var newConstraints = [NSLayoutConstraint]()
            for oldConstraint in view.constraints {
                let firstItem = oldConstraint.firstItem === view ? self : oldConstraint.firstItem as Any
                let secondItem = oldConstraint.secondItem === view ? self : oldConstraint.secondItem as Any
                newConstraints.append(NSLayoutConstraint(item: firstItem,
                                                         attribute: oldConstraint.firstAttribute,
                                                         relatedBy: oldConstraint.relation,
                                                         toItem: secondItem,
                                                         attribute: oldConstraint.secondAttribute,
                                                         multiplier: oldConstraint.multiplier,
                                                         constant: oldConstraint.constant))
            }
            for newView in view.subviews {
                addSubview(newView)
            }
            addConstraints(newConstraints)
        }
        
    }
    
    override init(frame: NSRect)
    {
        super.init(frame: frame)
        
        loadNib()
        
        
    }
    
    public func update(){
        
        if(bit == 8){
            bitClipTo10.isEnabled = false
            bitClipTo12.isEnabled = false
            bitClipTo14.isEnabled = false
            bitClipTo16.isEnabled = false
            bitClipTo8.state = .on
            bitClipTo10.state = .off
            bitClipTo12.state = .off
            bitClipTo14.state = .off
            bitClipTo16.state = .off
        }else{
            bitClipTo10.isEnabled = true
            bitClipTo12.isEnabled = true
            bitClipTo14.isEnabled = true
            bitClipTo16.isEnabled = true
            bitClipTo8.state = .off
            bitClipTo10.state = .off
            bitClipTo12.state = .off
            bitClipTo14.state = .off
            bitClipTo16.state = .off
            switch self.currentClipBit {
            case 8:
                bitClipTo8.state = .on
            case 10:
                bitClipTo10.state = .on
            case 12:
                bitClipTo12.state = .on
            case 14:
                bitClipTo14.state = .on
            case 16:
                bitClipTo16.state = .on
            default:
                break
            }
        }
        
        if(histogram == nil){
            print("histogram is not set")
            bitButton_8.isHidden = true
            bitButton_10.isHidden = true
            bitButton_12.isHidden = true
            bitButton_14.isHidden = true
            bitButton_16.isHidden = true
        }else{
            bitButton_8.isHidden = false
            bitButton_10.isHidden = false
            bitButton_12.isHidden = false
            bitButton_14.isHidden = false
            bitButton_16.isHidden = false
        }
        
        
//        print("max", maxIntensity)
        
        
        let p1 = NSPoint(x:  CGFloat(displayRanges![0]) / CGFloat(maxIntensityForCurrentClipBit) * graphSize.width ,
                         y:  0)
        let p2 = NSPoint(x:  CGFloat(displayRanges![1]) / CGFloat(maxIntensityForCurrentClipBit) * graphSize.width ,
                         y:  1 * graphSize.height)
        
        var knobPoint1:NSPoint
        var knobPoint2:NSPoint
        
        if(p1.x >= 0){
            knobPoint1 = p1
        }else{
            knobPoint1 = NSPoint(x:   0 , y:    -p1.x * (p2.y - p1.y) / (p2.x - p1.x))
        }
        
        if(p2.x <= graphSize.width){
            knobPoint2 = p2
        }else{
            knobPoint2 = NSPoint(x: graphSize.width , y: (graphSize.width - p1.x) * (p2.y - p1.y) / (p2.x - p1.x))
            
        }
        controlPoints[0] = NSPoint(x: knobSize + knobPoint1.x, y: knobSize + knobPoint1.y)
        controlPoints[1] = NSPoint(x: knobSize + knobPoint2.x, y: knobSize + knobPoint2.y)
    }
    
    public func histogram16to8(){
        var his = [UInt32](repeating: 0, count: 256)
        for i in 0..<256{
            //            print(i * 256, 255 + 256 * i)
            his[i] = histogram![(i * 256) ... (255 + 256 * i)].reduce(0, +)
        }
        //        print(his)
        self.histogram = his
    }
    public func histogram14to8(){
        var his = [UInt32](repeating: 0, count: 256)
        for i in 0..<256{
            //            print(i * 64, 63 + 64 * i)
            his[i] = histogram![(i * 64) ... (63 + 64 * i)].reduce(0, +)
        }
        //        print(his)
        self.histogram = his
    }
    
    public func histogramClip8(bit:Int){
        let power = pow(2, bit)
        let mag = NSDecimalNumber(decimal: power / 256).intValue
//        print(mag)
        guard let histogram = histogram else {
            return
        }

        clippedHistogram = [UInt32](repeating: 0, count: 256)
        for i in 0..<256{
//            print(i, i * mag, mag - 1 + mag * i)
            clippedHistogram![i] = histogram[(i * mag) ... mag - 1 + mag * i].reduce(0, +)
        }
//        print(clippedHistogram!)
    }
    
    //MARK: - draw
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        if(isResizing){
            update()
        }
        
        
        if(currentClipBit != previousClipBit){
            histogramClip8(bit: currentClipBit)
            previousClipBit = currentClipBit
        }
        
        
        guard let clippedHistogram = clippedHistogram else {
            return
        }
        
        let max = clippedHistogram.max()!
        
        let roundrRectangle = NSBezierPath(roundedRect: NSRect(x: knobSize-2, y: knobSize-2, width: self.frame.width-knobSize*2+4, height: self.frame.height-knobSize*2 - vMargin+4), xRadius: knobSize, yRadius: knobSize)

        
        let path = NSBezierPath()
        
        borderColor.setStroke()
        borderColor.withAlphaComponent(0.2).setFill()
        
        path.lineWidth = 2.0
        
        let dataCount = clippedHistogram.count
        
        let interpolateDistance = graphSize.width / CGFloat(dataCount - 1)
        
        
        for i in 0..<dataCount {
            if i == 0{
                let yp = Float(         clippedHistogram[i] * UInt32(graphSize.height - knobSize ) / max )
                
                let p:NSPoint = NSPoint(x: knobSize +  CGFloat(i) * interpolateDistance, y: knobSize +  CGFloat( yp))
     
                path.move(to: p)
            }else if i == dataCount - 1{
                
                let yp = Float(         clippedHistogram[i] * UInt32(graphSize.height - knobSize ) / max )
                
                let p:NSPoint = NSPoint(x:  knobSize + CGFloat(i) * interpolateDistance, y:  knobSize + CGFloat( yp))
                path.line(to:p)
            }else{
                let yp = Float(         clippedHistogram[i] * UInt32(graphSize.height - knobSize ) / max )
                
                let p:NSPoint = NSPoint(x:  knobSize + CGFloat(i) * interpolateDistance, y:  knobSize + CGFloat( yp))
                path.line(to:p)
            }
        }
        
        
        path.stroke()
        
        
        let rangeLine = NSBezierPath()
        NSColor.selectedControlTextColor.setStroke()
        rangeLine.lineWidth = 2.0
        
        rangeLine.move(to: controlPoints[0])
        rangeLine.line(to: controlPoints[1])
        rangeLine.stroke()
        
        let roundrRectangle2 = NSBezierPath(roundedRect: NSRect(x: knobSize, y: knobSize, width: self.frame.width-knobSize*2, height: self.frame.height-knobSize*2 - vMargin), xRadius: knobSize, yRadius: knobSize)
        roundrRectangle.lineWidth = 6
        NSColor.controlBackgroundColor.setStroke()
        roundrRectangle.stroke()
        borderColor.setStroke()
        roundrRectangle2.lineWidth = 1.5
        roundrRectangle2.stroke()
        
        
        let grabKnob1 = NSBezierPath()
        if(mouseHoverPoint == .controlPoint1over){
            NSColor.red.setFill()
        }else{
            NSColor.selectedControlTextColor.setFill()
        }
        grabKnob1.appendArc(withCenter:controlPoints[0],
                           radius: knobSize,
                           startAngle: 0, endAngle: 360)
        grabKnob1.fill()
        
        
        
        let grabKnob2 = NSBezierPath()
        if(mouseHoverPoint == .controlPoint2over){
            NSColor.red.setFill()
        }else{
            NSColor.selectedControlTextColor.setFill()
        }
        grabKnob2.appendArc(withCenter:controlPoints[1],
                           radius: knobSize,
                           startAngle: 0, endAngle: 360)
        grabKnob2.fill()
        
    }
    
    
    func createLayerForColor(color: NSColor) -> CAShapeLayer{
        let layer = CAShapeLayer()
        layer.strokeColor = color.cgColor
        layer.fillColor = color.withAlphaComponent(0.3).cgColor
        layer.masksToBounds = true
        layer.lineJoin = .round
        
        return layer
    }
    
    
    override func mouseMoved(with event: NSEvent) {
        let point = self.superview?.superview?.convert(event.locationInWindow, to: self)
        guard let point = point else {
            return
        }
        
        let currentMouseState = mouseHoverPoint
        
        if(point.x > controlPoints[0].x - knobSize &&
           point.x < controlPoints[0].x + knobSize &&
           point.y > controlPoints[0].y - knobSize &&
           point.y < controlPoints[0].y + knobSize){
            mouseHoverPoint = .controlPoint1over
        }else if(point.x > controlPoints[1].x - knobSize &&
                 point.x < controlPoints[1].x + knobSize &&
                 point.y > controlPoints[1].y - knobSize &&
                 point.y < controlPoints[1].y + knobSize){
            mouseHoverPoint = .controlPoint2over
        }else{
            mouseHoverPoint = .none
        }
        
        if(currentMouseState != mouseHoverPoint){
            updateView()
        }
        
        
    }
    
    override func mouseDown(with event: NSEvent) {
        let point = self.superview?.superview?.convert(event.locationInWindow, to: self)
        guard let point = point else {
            return
        }
        
        let max = pow(2, currentClipBit) - 1
        
        let currentMouseState = mouseHoverPoint
        
        if(point.x > controlPoints[0].x - knobSize &&
           point.x < controlPoints[0].x + knobSize &&
           point.y > controlPoints[0].y - knobSize &&
           point.y < controlPoints[0].y + knobSize){
            mouseHoverPoint = .controlPoint1grab
        }else if(point.x > controlPoints[1].x - knobSize &&
                 point.x < controlPoints[1].x + knobSize &&
                 point.y > controlPoints[1].y - knobSize &&
                 point.y < controlPoints[1].y + knobSize){
            mouseHoverPoint = .controlPoint2grab
        }else{
            mouseHoverPoint = .none
        }
    }
    
    override func mouseDragged(with event: NSEvent) {
        let point = self.superview?.superview?.convert(event.locationInWindow, to: self)
        guard var point = point else {
            return
        }
        
        
        let margin: CGFloat = 3.0
        
        if(mouseHoverPoint == .controlPoint1grab){
            if(point.x <= knobSize){
                point.x = knobSize
            }
            if(point.y <= knobSize){
                point.y = knobSize
            }
            
            if(point.x > point.y){
                if(point.x < controlPoints[1].x - margin){
                    let p = NSPoint(x: point.x , y: 0 + knobSize)
                    
                    controlPoints[0] = p
                }
            }else{
                if(point.y < controlPoints[1].y - margin){
                    let p = NSPoint(x: 0 + knobSize, y: point.y )
                    controlPoints[0] = p
                }
                
            }
        }else if(mouseHoverPoint == .controlPoint2grab){
            if(point.x >= knobSize + graphSize.width){
                point.x = knobSize + graphSize.width
            }
            if(point.y >= knobSize + graphSize.height){
                point.y = knobSize + graphSize.height
            }
            
            if( (knobSize + graphSize.width) - point.x > (knobSize + graphSize.height) - point.y){
                if(point.x > controlPoints[0].x + margin){
                    
                    let p = NSPoint(x: point.x , y: 0 + knobSize + graphSize.height)
                    controlPoints[1] = p
                }
            }else{
                if(point.y > controlPoints[0].y + margin){
                    
                    let p = NSPoint(x: graphSize.width + 0, y: point.y )
                    controlPoints[1] = p
                }
            }
        }
        updateView()
        getDisplayRange()
    }
    override func mouseUp(with event: NSEvent) {
      
        mouseHoverPoint = .none
        updateView()
    }
    
    func getDisplayRange(){
        let p1 = NSPoint(x: controlPoints[0].x - knobSize, y: controlPoints[0].y - knobSize)
        let p2 = NSPoint(x: controlPoints[1].x - knobSize, y: controlPoints[1].y - knobSize)
        let t = -p1.y / (p2.y - p1.y)
        let x = p1.x + t * (p2.x - p1.x)
        
        let min_range = x / graphSize.width * CGFloat(maxIntensityForCurrentClipBit)
        
        
        let t2 = (graphSize.height - p1.y) / (p2.y - p1.y)
        let x2 = p1.x + t2 * (p2.x - p1.x)
        
        let max_range = x2 / graphSize.width * CGFloat(maxIntensityForCurrentClipBit)
        
        self.displayRanges = [min_range, max_range]
        
        delegate?.adjustRanges(channel: self.channel, ranges: self.displayRanges!)
    }
    
    func updateView(){
        self.setNeedsDisplay(self.bounds)
    }
    
}

extension NSBezierPath {
    
    public var cgPath: CGPath {
        let path: CGMutablePath = CGMutablePath()
        var points = [NSPoint](repeating: NSPoint.zero, count: 3)
        for i in (0 ..< self.elementCount) {
            switch self.element(at: i, associatedPoints: &points) {
            case .moveTo:
                path.move(to: CGPoint(x: points[0].x, y: points[0].y))
            case .lineTo:
                path.addLine(to: CGPoint(x: points[0].x, y: points[0].y))
            case .curveTo:
                path.addCurve(to: CGPoint(x: points[2].x, y: points[2].y),
                              control1: CGPoint(x: points[0].x, y: points[0].y),
                              control2: CGPoint(x: points[1].x, y: points[1].y))
            case .closePath:
                path.closeSubpath()
            @unknown default:
                break
            }
        }
        return path
    }
    
    
}
