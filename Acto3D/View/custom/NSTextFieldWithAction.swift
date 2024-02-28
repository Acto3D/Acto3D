//
//  NSTextFieldWithAction.swift
//  Acto3D
//
//  Created by Naoki Takeshita on 2024/02/22.
//

import Cocoa

@objc enum ValueType: Int {
    case String // 0
    case Float  // 1
    case Int    // 2
    case UInt   // 3
}


protocol ValidatingTextFieldDelegate: AnyObject {
    func textFieldDidEndEditing(sender: ValidatingTextField, oldValue:Any, newValue:Any)
}

class ValidatingTextField: NSTextField {
    weak var validationDelegate:ValidatingTextFieldDelegate?
    
    // Input Type - Specify the type of input: "string", "int", or "float"
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
            
        default:
            break
        }
        
        return true
    }
    
    
    override func textShouldEndEditing(_ textObject: NSText) -> Bool {
        print("textShouldEndEditing", textObject)
        switch self.inputValueType {
        case .String:
            self.newValue = self.stringValue
            
        case .Int:
            if let newValue = Int(self.stringValue){
                self.newValue = newValue
            }else{
                self.integerValue = storedValue as! Int
            }
            
        case .Float:
            if let newValue = Float(self.stringValue){
                self.newValue = newValue
            }else{
                self.floatValue = storedValue as! Float
            }
            
        case .UInt:
            if let newValue = UInt(self.stringValue){
                self.newValue = newValue
            }else{
                self.integerValue = Int(storedValue as! UInt)
            }
            
        default:
            break
        }
        
        return true
    }
    
    override func textDidEndEditing(_ notification: Notification) {
        guard let storedValue = self.storedValue,
              let newValue = self.newValue else {
            print("error")
            return}
        
        self.validationDelegate?.textFieldDidEndEditing(sender:self, oldValue: storedValue, newValue: newValue)
        
        super.textDidEndEditing(notification)
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
        print("Tarea")
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
