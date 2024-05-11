//
//  VC_ControlPoints.swift
//  Acto3D
//
//  Created by Naoki Takeshita on 2023/11/20.
//

import Foundation
import Cocoa

extension ViewController{
    //MARK: Tone Control
    func initToneCurveViews(){
        // toneCurve setting
        toneCh1.delegate = self
        toneCh2.delegate = self
        toneCh3.delegate = self
        toneCh4.delegate = self
        toneCh1.knobSize = 5
        toneCh2.knobSize = 5
        toneCh3.knobSize = 5
        toneCh4.knobSize = 5
        
        toneCh1.relativeView = self.view
        toneCh2.relativeView = self.view
        toneCh3.relativeView = self.view
        toneCh4.relativeView = self.view
        
        //MARK: Initial control points
        
        toneCh1.spline?.interpolateMode = .linear
        toneCh2.spline?.interpolateMode = .linear
        toneCh3.spline?.interpolateMode = .linear
        toneCh4.spline?.interpolateMode = .linear
        
        toneCh1.setControlPoint(array: controlPoints[0].values0)
        toneCh2.setControlPoint(array: controlPoints[0].values1)
        toneCh3.setControlPoint(array: controlPoints[0].values2)
        toneCh4.setControlPoint(array: controlPoints[0].values3)
        
        toneCh1.setDefaultBackgroundColor(color: wellCh1.color)
        toneCh2.setDefaultBackgroundColor(color: wellCh2.color)
        toneCh3.setDefaultBackgroundColor(color: wellCh3.color)
        toneCh4.setDefaultBackgroundColor(color: wellCh4.color)
        
    }
    
    internal func getDefaultControlPoints() -> [ControlPoint]{
        var points:[ControlPoint] = []
        
        // Set preset points
        points.append(ControlPoint(title: "Default", 
                                   values0: [[0,0], [30,0], [255,0.9]], type0: 0,
                                   values1: [[0,0], [30,0], [255,0.9]], type1: 0,
                                   values2: [[0,0], [30,0], [255,0.9]], type2: 0,
                                   values3: [[0,0], [30,0], [255,0.9]], type3: 0))
                      
        points.append(ControlPoint(title: "Default (Spline)",
                                   values0:  [[0,0], [30,0], [65, 0.15], [255,0.9]], type0: 1,
                                   values1:  [[0,0], [30,0], [65, 0.15], [255,0.9]], type1: 1,
                                   values2:  [[0,0], [30,0], [65, 0.15], [255,0.9]], type2: 1,
                                   values3:  [[0,0], [30,0], [65, 0.15], [255,0.9]], type3: 1))
        
        points.append(ControlPoint(title: "MPR",
                                   values0: [[0,1], [255,1]], type0: 0,
                                   values1: [[0,1], [255,1]], type1: 0,
                                   values2: [[0,1], [255,1]], type2: 0,
                                   values3: [[0,1], [255,1]], type3: 0))
        
        points.append(ControlPoint(title: "MPR (Cut low intensity)", 
                                   values0: [[0,0], [20, 0], [20.1, 1], [255,1]], type0: 0,
                                   values1: [[0,0], [20, 0], [20.1, 1], [255,1]], type1: 0,
                                   values2: [[0,0], [20, 0], [20.1, 1], [255,1]], type2: 0,
                                   values3: [[0,0], [20, 0], [20.1, 1], [255,1]], type3: 0))
                      
        points.append(ControlPoint(title: "Transparent-1",
                                   values0: [[0, 0], [255, 0.45]], type0: 0,
                                   values1: [[0, 0], [255, 0.45]], type1: 0,
                                   values2: [[0, 0], [255, 0.45]], type2: 0,
                                   values3: [[0, 0], [255, 0.45]], type3: 0))
                      
        points.append(ControlPoint(title: "Transparent-2 (Cut low intensity)",
                                   values0: [[0, 0], [20, 0], [33, 0.15], [50, 0.215], [255, 0.35]], type0: 0,
                                   values1: [[0, 0], [20, 0], [33, 0.15], [50, 0.215], [255, 0.35]], type1: 0,
                                   values2: [[0, 0], [20, 0], [33, 0.15], [50, 0.215], [255, 0.35]], type2: 0,
                                   values3: [[0, 0], [20, 0], [33, 0.15], [50, 0.215], [255, 0.35]], type3: 0))
        
        points.append(ControlPoint(title: "Transparent-3 (Consider low intensity, Spline)",
                                   values0: [[0, 0], [10, 0.1], [25, 0.15], [255, 0.4]], type0: 1,
                                   values1: [[0, 0], [10, 0.1], [25, 0.15], [255, 0.4]], type1: 1,
                                   values2: [[0, 0], [10, 0.1], [25, 0.15], [255, 0.4]], type2: 1,
                                   values3: [[0, 0], [10, 0.1], [25, 0.15], [255, 0.4]], type3: 1))
    
        return points
    }
    
    func writeControlPointsData(){
        let fileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("controlPoints.json")
        do{
            let encoder = JSONEncoder()
            encoder.outputFormatting = .sortedKeys
            let data = try encoder.encode(controlPoints)
            try data.write(to: fileURL, options: .atomic)
            
        }catch{
            Logger.logPrintAndWrite(message: "Error writing control points", level: .error)
        }
    }
    
    func loadControlPointsData(){
        let fileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("controlPoints.json")
        do {
            let jsonData = try Data(contentsOf: fileURL)
            self.controlPoints = try JSONDecoder().decode([ControlPoint].self, from: jsonData)
            
        } catch {
            Logger.logPrintAndWrite(message: "Error loading stored control points.", level: .error)
            self.controlPoints = getDefaultControlPoints()
            writeControlPointsData()
        }
    }
    
    func createPresetControlPoints(){
        // Check preset control points file
        let fileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("controlPoints.json")
        
        if(FileManager.default.fileExists(atPath: fileURL.path)){
            loadControlPointsData()
            
        }else{
            self.controlPoints = getDefaultControlPoints()
            writeControlPointsData()
            
        }
        

    }
    
    
    /// toneControl preset button clicked
    @IBAction func toneControlOptionButton(_ sender: NSButton) {
        // Create menu
        controlPointsMenu.removeAllItems()
        
        for (index, controlPoint) in controlPoints.enumerated() {
            // Create label
            let labelButton = NSButton(title: controlPoint.title, target: self, action: #selector(changeControlPointsWith))
            labelButton.alignment = .left
            labelButton.showsBorderOnlyWhileMouseInside = true
            labelButton.bezelStyle = .recessed
            labelButton.focusRingType = .none
            labelButton.frame = NSRect(x: 5, y: 0, width: 300, height: 25)
            
            // Create edit button
            let editLabelButton = NSButton(image: NSImage(systemSymbolName: "square.and.pencil", accessibilityDescription: nil)!, target: self, action:#selector(renameControlPoints))
            editLabelButton.imagePosition = .imageOnly
            editLabelButton.imageScaling = .scaleProportionallyUpOrDown
            editLabelButton.bezelStyle = .circular
            editLabelButton.showsBorderOnlyWhileMouseInside = true
            editLabelButton.focusRingType = .none
            editLabelButton.frame = NSRect(x: 305, y: 0, width: 25, height: 25)
            
            // Create delete button
            let deleteButton = NSButton(image: NSImage(named: NSImage.stopProgressFreestandingTemplateName)!, target: self, action:#selector(removeControlPoints))
            deleteButton.imagePosition = .imageOnly
            deleteButton.bezelStyle = .circular
            deleteButton.showsBorderOnlyWhileMouseInside = true
            deleteButton.focusRingType = .none
            deleteButton.frame = NSRect(x: 325, y: 0, width: 25, height: 25)
            
            labelButton.identifier = NSUserInterfaceItemIdentifier(controlPoint.title)
            labelButton.tag = index
            editLabelButton.tag = index
            deleteButton.tag = index
            
            let itemView = NSView(frame: NSRect(x: 0, y: 0, width: 350, height: 25))
            itemView.addSubview(labelButton)
            itemView.addSubview(deleteButton)
            itemView.addSubview(editLabelButton)
            
            let menuItem = NSMenuItem()
            menuItem.view = itemView
            menuItem.identifier = NSUserInterfaceItemIdentifier(controlPoint.title)
            controlPointsMenu.addItem(menuItem)
        }
        
        
        // Create label
        let labelButton = NSButton(title: "Register Current Control Points", target: self, action: #selector(registerCurrentPoints))
        labelButton.alignment = .center
        labelButton.showsBorderOnlyWhileMouseInside = false
        //            labelButton.bezelStyle = .recessed
        labelButton.focusRingType = .none
        labelButton.frame = NSRect(x: 5, y: 0, width: 300, height: 25)
        
        let itemView = NSView(frame: NSRect(x: 0, y: 0, width: 350, height: 25))
        itemView.addSubview(labelButton)
        
        let menuItem = NSMenuItem()
        menuItem.view = itemView
        controlPointsMenu.addItem(menuItem)
        
        
        
        let menuPosition = sender.superview!.convert(NSPoint(x: sender.frame.minX, y: sender.frame.minY), to: self.view)
        controlPointsMenu.popUp(positioning: nil, at: NSPoint(x: menuPosition.x, y: menuPosition.y), in: self.view)
    }
    
    @objc func registerCurrentPoints(_ sender: NSButton) {
        controlPointsMenu.cancelTracking()
        controlPointsMenu.removeAllItems()
        
        let alert = NSAlert()
        alert.messageText = "Register Current Control Points"
        alert.informativeText = "Enter a name for the current control points:"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        
        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        textField.placeholderString = "Control Points Name"
//        textField.stringValue = "Control points"
//        textField.selectText(self)
        alert.accessoryView = textField
        
        
        alert.beginSheetModal(for: self.view.window!) { (response) in
            if response == .alertFirstButtonReturn {
                var name = textField.stringValue
                print(name)
                if(name == ""){
                    name = "User defined control points"
                }
                
                self.controlPoints.append(ControlPoint(title: name,
                                                       values0: self.toneCh1.controlPoints, type0: self.toneCh1.spline!.interpolateMode.rawValue,
                                                       values1: self.toneCh2.controlPoints, type1: self.toneCh2.spline!.interpolateMode.rawValue,
                                                       values2: self.toneCh3.controlPoints, type2: self.toneCh3.spline!.interpolateMode.rawValue,
                                                       values3: self.toneCh4.controlPoints, type3: self.toneCh4.spline!.interpolateMode.rawValue))
                
                self.writeControlPointsData()
                
            } else {
                
            }
        }

        DispatchQueue.main.async {
            alert.window.makeFirstResponder(textField)
        }
    
    }
    
    @objc func removeControlPoints(_ sender: NSButton) {
        controlPoints.remove(at: sender.tag)
        writeControlPointsData()
        
        controlPointsMenu.cancelTracking()
        controlPointsMenu.removeAllItems()
        
    }
    
    @objc func renameControlPoints(_ sender: NSButton) {
        controlPointsMenu.cancelTracking()
        controlPointsMenu.removeAllItems()
        
        let alert = NSAlert()
        alert.messageText = "Rename Selected Control Points"
        alert.informativeText = "Enter a new name for the control points:"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        
        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        textField.placeholderString = "Control Points Name"
        textField.stringValue = controlPoints[sender.tag].title
        //        textField.selectText(self)
        alert.accessoryView = textField
        
        
        alert.beginSheetModal(for: self.view.window!) { (response) in
            if response == .alertFirstButtonReturn {
                let name = textField.stringValue
                print(name)
                if(name == ""){
                    
                }else{
                    self.controlPoints[sender.tag].title = name
                    self.writeControlPointsData()
                    
                }
                
            } else {
                
            }
        }
        
        DispatchQueue.main.async {
            alert.window.makeFirstResponder(textField)
        }
        
    }
    
    @objc func changeControlPointsWith(_ sender: NSButton) {
        if let identifier = sender.identifier?.rawValue {
            
            if let controlPoint = controlPoints.first(where: {$0.title == identifier}){
                
                toneCh1.setControlPoint(array: controlPoint.values0)
                toneCh2.setControlPoint(array: controlPoint.values1)
                toneCh3.setControlPoint(array: controlPoint.values2)
                toneCh4.setControlPoint(array: controlPoint.values3)
                
                toneCh1.spline?.interpolateMode =  CubicSplineInterpolator.InterpolateMode(rawValue: controlPoint.type0)!
                toneCh2.spline?.interpolateMode =  CubicSplineInterpolator.InterpolateMode(rawValue: controlPoint.type1)!
                toneCh3.spline?.interpolateMode =  CubicSplineInterpolator.InterpolateMode(rawValue: controlPoint.type2)!
                toneCh4.spline?.interpolateMode =  CubicSplineInterpolator.InterpolateMode(rawValue: controlPoint.type3)!
                
                
                transferTone(sender: toneCh1, targetGPUbuffer: &renderer.toneBuffer_ch1, index: 0)
                transferTone(sender: toneCh2, targetGPUbuffer: &renderer.toneBuffer_ch2, index: 1)
                transferTone(sender: toneCh3, targetGPUbuffer: &renderer.toneBuffer_ch3, index: 2)
                transferTone(sender: toneCh4, targetGPUbuffer: &renderer.toneBuffer_ch4, index: 3)
                
                outputView.image = renderer.rendering()
                
            }
        }
        
        controlPointsMenu.cancelTracking()
        controlPointsMenu.removeAllItems()
    }
    
//    @objc func controlPointsMenuItemSelected(_ sender: NSMenuItem) {
//        if let identifier = sender.identifier?.rawValue {
//            
//            if let controlPointsItem = controlPoints.first(where: { $0.0 == identifier }){
//                
//                toneCh1.setControlPoint(array: controlPointsItem.1)
//                toneCh2.setControlPoint(array: controlPointsItem.1)
//                toneCh3.setControlPoint(array: controlPointsItem.1)
//                toneCh4.setControlPoint(array: controlPointsItem.1)
//                
//                toneCh1.spline?.interpolateMode =  CubicSplineInterpolator.InterpolateMode(rawValue: controlPointsItem.2)!
//                toneCh2.spline?.interpolateMode =  CubicSplineInterpolator.InterpolateMode(rawValue: controlPointsItem.2)!
//                toneCh3.spline?.interpolateMode =  CubicSplineInterpolator.InterpolateMode(rawValue: controlPointsItem.2)!
//                toneCh4.spline?.interpolateMode =  CubicSplineInterpolator.InterpolateMode(rawValue: controlPointsItem.2)!
//                
//                
//                transferTone(sender: toneCh1, targetGPUbuffer: &renderer.toneBuffer_ch1, index: 0)
//                transferTone(sender: toneCh2, targetGPUbuffer: &renderer.toneBuffer_ch2, index: 1)
//                transferTone(sender: toneCh3, targetGPUbuffer: &renderer.toneBuffer_ch3, index: 2)
//                transferTone(sender: toneCh4, targetGPUbuffer: &renderer.toneBuffer_ch4, index: 3)
//                
//                outputView.image = renderer.rendering()
//                
//            }
//        }
//        
//    }
    
    
    @IBAction func linkToneCurve(_ sender: NSButton) {
        var controlPoints:[[Float]]?
        var interpolateMode:Int?
        
        switch sender.identifier?.rawValue {
        case "ch1":
            controlPoints = toneCh1.getControlPoint()
            interpolateMode = toneCh1.spline?.interpolateMode.rawValue
            
        case "ch2":
            controlPoints = toneCh2.getControlPoint()
            interpolateMode = toneCh2.spline?.interpolateMode.rawValue
            
        case "ch3":
            controlPoints = toneCh3.getControlPoint()
            interpolateMode = toneCh3.spline?.interpolateMode.rawValue
            
        case "ch4":
            controlPoints = toneCh4.getControlPoint()
            interpolateMode = toneCh4.spline?.interpolateMode.rawValue
            
        default:
            break
            
        }
        
        guard let controlPoints = controlPoints,
              let interpolateMode = interpolateMode else {return}
        
        toneCh1.setControlPoint(array: controlPoints)
        toneCh2.setControlPoint(array: controlPoints)
        toneCh3.setControlPoint(array: controlPoints)
        toneCh4.setControlPoint(array: controlPoints)
        
        toneCh1.spline?.interpolateMode = CubicSplineInterpolator.InterpolateMode(rawValue: interpolateMode)!
        toneCh2.spline?.interpolateMode = CubicSplineInterpolator.InterpolateMode(rawValue: interpolateMode)!
        toneCh3.spline?.interpolateMode = CubicSplineInterpolator.InterpolateMode(rawValue: interpolateMode)!
        toneCh4.spline?.interpolateMode = CubicSplineInterpolator.InterpolateMode(rawValue: interpolateMode)!
        
        transferTone(sender: toneCh1, targetGPUbuffer: &renderer.toneBuffer_ch1, index: 0)
        transferTone(sender: toneCh2, targetGPUbuffer: &renderer.toneBuffer_ch2, index: 1)
        transferTone(sender: toneCh3, targetGPUbuffer: &renderer.toneBuffer_ch3, index: 2)
        transferTone(sender: toneCh4, targetGPUbuffer: &renderer.toneBuffer_ch4, index: 3)
        
        outputView.image = renderer.rendering()
        
    }
    
}
