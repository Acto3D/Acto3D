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
        let controlPoint:[[Float]] = controlPoints[0].1
        
        toneCh1.spline?.interpolateMode = .linear
        toneCh2.spline?.interpolateMode = .linear
        toneCh3.spline?.interpolateMode = .linear
        toneCh4.spline?.interpolateMode = .linear
        
        toneCh1.setControlPoint(array: controlPoint)
        toneCh2.setControlPoint(array: controlPoint)
        toneCh3.setControlPoint(array: controlPoint)
        toneCh4.setControlPoint(array: controlPoint)
        
        toneCh1.setDefaultBackgroundColor(color: wellCh1.color)
        toneCh2.setDefaultBackgroundColor(color: wellCh2.color)
        toneCh3.setDefaultBackgroundColor(color: wellCh3.color)
        toneCh4.setDefaultBackgroundColor(color: wellCh4.color)
        
    }
    
    func createPresetControlPoints(){
        controlPoints.append(("Default", [[0,0], [30,0], [255,0.9]], 0))
        controlPoints.append(("Default (Spline)", [[0,0], [30,0], [65, 0.15], [255,0.9]], 1))
        controlPoints.append(("MPR", [[0,1], [255,1]], 0))
        controlPoints.append(("MPR (Cut low intensity)", [[0,0], [20, 0], [20.1, 1], [255,1]], 0))
        controlPoints.append(("Transparent-1", [[0, 0], [255, 0.45]], 0))
        controlPoints.append(("Transparent-2 (Cut low intensity)", [[0, 0], [20, 0], [33, 0.15], [50, 0.215], [255, 0.35]], 0))
        controlPoints.append(("Transparent-3 (Consider low intensity, Spline)", [[0, 0], [10, 0.1], [25, 0.15], [255, 0.4]], 1))
    
        for (title, _, _)  in controlPoints{
            let menuItem = NSMenuItem(title: title, action: #selector(controlPointsMenuItemSelected), keyEquivalent: "")
            menuItem.identifier = NSUserInterfaceItemIdentifier(title)
            controlPointsMenu.addItem(menuItem)
        }
    }
    
    /// toneControl preset button clicked
    @IBAction func toneControlOptionButton(_ sender: NSButton) {
        let menuPosition = sender.superview!.convert(NSPoint(x: sender.frame.minX, y: sender.frame.minY), to: self.view)
        controlPointsMenu.popUp(positioning: nil, at: NSPoint(x: menuPosition.x, y: menuPosition.y), in: self.view)
    }
    
    @objc func controlPointsMenuItemSelected(_ sender: NSMenuItem) {
        if let identifier = sender.identifier?.rawValue {
            
            if let controlPointsItem = controlPoints.first(where: { $0.0 == identifier }){
                
                toneCh1.setControlPoint(array: controlPointsItem.1)
                toneCh2.setControlPoint(array: controlPointsItem.1)
                toneCh3.setControlPoint(array: controlPointsItem.1)
                toneCh4.setControlPoint(array: controlPointsItem.1)
                
                toneCh1.spline?.interpolateMode =  CubicSplineInterpolator.InterpolateMode(rawValue: controlPointsItem.2)!
                toneCh2.spline?.interpolateMode =  CubicSplineInterpolator.InterpolateMode(rawValue: controlPointsItem.2)!
                toneCh3.spline?.interpolateMode =  CubicSplineInterpolator.InterpolateMode(rawValue: controlPointsItem.2)!
                toneCh4.spline?.interpolateMode =  CubicSplineInterpolator.InterpolateMode(rawValue: controlPointsItem.2)!
                
                
                transferTone(sender: toneCh1, targetGPUbuffer: &renderer.toneBuffer_ch1, index: 0)
                transferTone(sender: toneCh2, targetGPUbuffer: &renderer.toneBuffer_ch2, index: 1)
                transferTone(sender: toneCh3, targetGPUbuffer: &renderer.toneBuffer_ch3, index: 2)
                transferTone(sender: toneCh4, targetGPUbuffer: &renderer.toneBuffer_ch4, index: 3)
                
                outputView.image = renderer.rendering()
                
            }
        }
    }
    
    
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
