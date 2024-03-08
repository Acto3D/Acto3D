//
//  NSTextFieldWithAction.swift
//  Acto3D
//
//  Created by Naoki Takeshita on 2024/02/22.
//

import Cocoa

/**
String:0, Float:1, Int:2, UInt:3, UInt16:4
*/
@objc enum ValueType: Int {
    case String // 0
    case Float  // 1
    case Int    // 2
    case UInt   // 3
    case UInt16   // 4
}


protocol ValidatingTextFieldDelegate: AnyObject {
    func textFieldDidEndEditing(sender: ValidatingTextField, oldValue:Any, newValue:Any)
}

/**
 This text box reverts to its original value if input other than a predefined type is entered.
 */
class ValidatingTextField: NSTextField {
    weak var validationDelegate:ValidatingTextFieldDelegate?
    
    @IBInspectable var valueType: Int = 0 {
        didSet {
            inputValueType = ValueType(rawValue: valueType) ?? .String
        }
    }
    
    var inputValueType: ValueType = .String
    var storedValue:Any?
    var newValue:Any?
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        // Drawing code here.
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        self.wantsLayer = true
        self.layer?.borderWidth = 1.5
        self.layer?.borderColor =  NSColor.clear.cgColor
        
        if(self.inputValueType == .Float){
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.usesGroupingSeparator = false
            self.formatter = formatter
        }
        
        
    }
    
    override func textShouldBeginEditing(_ textObject: NSText) -> Bool {
        print("Should start", textObject)
        switch self.inputValueType {
        case .String:
            storedValue = self.stringValue
            
        case .Int:
            storedValue = self.integerValue
            
        case .Float:
            storedValue = self.floatValue
            
        case .UInt:
            storedValue = UInt(self.integerValue)
            
        case .UInt16:
            storedValue = UInt16(self.integerValue)
            
        default:
            break
        }
        
        return true
    }
    
    
    override func textShouldEndEditing(_ textObject: NSText) -> Bool {
        textShouldEndEditingEvent()
        
        return true
    }
    
    public func textShouldEndEditingEvent(){
        switch self.inputValueType {
        case .String:
            self.newValue = self.stringValue
            self.storedValue = self.newValue
            
        case .Int:
            if let newValue = Int(self.stringValue){
                self.newValue = newValue
                self.storedValue = self.newValue
                
            }else{
                self.integerValue = storedValue as! Int
            }
            
        case .Float:
            if let newValue = Float(self.stringValue){
                self.newValue = newValue
                self.storedValue = self.newValue
                
            }else{
                self.floatValue = storedValue as! Float
            }
            
        case .UInt:
            if let newValue = UInt(self.stringValue){
                self.newValue = newValue
                self.storedValue = self.newValue
                
            }else{
                self.integerValue = Int(storedValue as! UInt)
            }
            
        case .UInt16:
            if let newValue = UInt16(self.stringValue){
                self.newValue = newValue
                self.storedValue = self.newValue
                
            }else{
                self.integerValue = Int(storedValue as! UInt16)
            }
            
        default:
            break
        }
    }
    
    override func textDidEndEditing(_ notification: Notification) {
        textDidEndEditingEvent()
        
        super.textDidEndEditing(notification)
    }
    
    public func textDidEndEditingEvent(){
        guard let storedValue = self.storedValue,
              let newValue = self.newValue else {
            
            return}
        
        self.validationDelegate?.textFieldDidEndEditing(sender:self, oldValue: storedValue, newValue: newValue)
    }
    
    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        animateBorderColor(to: NSColor.selectedTextBackgroundColor.cgColor, duration: 0.5)
    }
    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        animateBorderColor(to: NSColor.clear.cgColor, duration: 0.5)
    }
    
    
    private func animateBorderColor(to color: CGColor?, duration: TimeInterval) {
        let animation = CABasicAnimation(keyPath: "borderColor")
        animation.fromValue = self.layer?.borderColor
        animation.toValue = color
        animation.duration = duration
        self.layer?.add(animation, forKey: "borderColorAnimation")
        self.layer?.borderColor =  color
    }
    
    
    override func updateTrackingAreas() {
        if !trackingAreas.isEmpty {
            for area in trackingAreas {
                removeTrackingArea(area)
            }
        }
        
        if bounds.size.width == 0 || bounds.size.height == 0 { return }
        
        let options:NSTrackingArea.Options = [
            .mouseEnteredAndExited,
            .activeAlways,
        ]
        
        let area = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(area)
    }
    
}
