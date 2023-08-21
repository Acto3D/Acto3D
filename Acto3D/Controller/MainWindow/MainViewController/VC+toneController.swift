//
//  toneController.swift
//  Acto3D
//
//  Created by Naoki Takeshita on 2022/01/05.
//

import Foundation
import Cocoa
import Accelerate
import simd

extension ViewController:ToneCurveViewProtocol{
    func splineDidChange(identifier: String?, sender: ToneCurveView) {
        if let identifier = identifier {
            switch identifier {
            case "toneCh1":
                transferTone(sender: sender, targetGPUbuffer: &renderer.toneBuffer_ch1, index: 0)
                
            case "toneCh2":
                transferTone(sender: sender, targetGPUbuffer: &renderer.toneBuffer_ch2, index: 1)
                
            case "toneCh3":
                transferTone(sender: sender, targetGPUbuffer: &renderer.toneBuffer_ch3, index: 2)
                
            case "toneCh4":
                transferTone(sender: sender, targetGPUbuffer: &renderer.toneBuffer_ch4, index: 3)
                
            default:
                break
            }
            outputView.image = renderer.rendering()
        }
    }

    func transferTone(sender: ToneCurveView, targetGPUbuffer: inout MTLBuffer?, index:Int){
        let toneArray = sender.getInterpolatedValues(scale: 10)!
        renderer.transferToneArrayToBuffer(toneArray: toneArray, targetGpuBuffer: &targetGPUbuffer, index: index)
        
    }

    
    func splineIsEditting(identifier: String?, sender: ToneCurveView) {
    }
    
    func vMouseMoved(with event: NSEvent) {
        
    }
    
    func vMouseDragged(mouse startPoint: NSPoint, previousPoint: NSPoint, currentPoint: NSPoint) {
        
    }
    
    func vMouseUp(mouse startPoint: NSPoint, currentPoint: NSPoint) {
        
    }
    
    
    
}
