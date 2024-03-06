//
//  VC+MouseEvent.swift
//  Acto3D
//
//  Created by Naoki Takeshita on 2022/08/12.
//

import Foundation
import Cocoa
import Metal
import simd


extension ViewController: ModelViewProtocol{
    
    func modelViewMouseMoved(with event: NSEvent, point: NSPoint){
        if(renderer.mainTexture == nil){
            return
        }
        
        let viewSize = renderer.renderParams.viewSize
        
        let outputViewPoint = self.view.convert(point, to: outputView)
        let viewScaleW = outputView.frame.width / CGFloat (viewSize.toFloat())
        let viewScaleH = outputView.frame.height / CGFloat (viewSize.toFloat())
        let viewScale = Float(min(viewScaleW, viewScaleH))
        
//        focusCircle.frame.origin = CGPoint(x: point.x - 16, y: point.y - 16)
//        self.focusCircle.isHidden = false
//        self.focusCircle.alphaValue = 1
        
        let viewCenterPosition = float2(x: Float(outputViewPoint.x - outputView.frame.width / 2.0) / viewScale + viewSize.toFloat() / 2.0,
                                        y: (-1.0) * (Float(outputViewPoint.y - outputView.frame.height / 2.0) / viewScale) + viewSize.toFloat() / 2.0)

        let centeredPosition:float4 = float4(Float(outputViewPoint.x - outputView.frame.width / 2.0) / viewScale,
                                             (-1.0) * (Float(outputViewPoint.y - outputView.frame.height / 2.0) / viewScale),
                                             0,
                                             1)

        let transferMat = matrix_float4x4(float4(1, 0, 0, 0),
                                          float4(0, 1, 0, 0),
                                          float4(0, 0, 1.0, 0),
                                          float4(renderer.renderParams.translationX, renderer.renderParams.translationY, 0, 1.0));
        
        let scaleMatRatio = 1.0 / renderer.renderParams.scale;
        let scale_Z = renderer.renderParams.zScale;
        let scaleMat = float4x4(float4(scaleMatRatio, 0, 0, 0),
                                float4(0, scaleMatRatio, 0, 0),
                                float4(0, 0, 1, 0),
                                float4(0, 0, 0, 1))
        
        let  matrix_centering_toView = float4x4(float4(1, 0, 0, 0),
                                                float4(0, 1, 0, 0),
                                                float4(0, 0, 1, 0),
                                                float4(renderer.volumeData.inputImageWidth.toFloat() / 2.0,
                                                       renderer.volumeData.inputImageHeight.toFloat() / 2.0,
                                                       renderer.volumeData.inputImageDepth.toFloat() * scale_Z / 2.0, 1))
        
        let directionVector = float3(0, 0, 1)
        let directionVector_rotate = renderer.quaternion.act(directionVector)
        
        let pos = transferMat * scaleMat * centeredPosition
        let mappedXYZ = renderer.quaternion.act(pos.xyz)
        
        let radius:Float = renderer.renderParams.sliceMax.toFloat() / 2.0
        let ts =  radius - renderer.renderParams.sliceNo.toFloat()
        
        let current_mapped_pos = mappedXYZ + ts * directionVector_rotate;
        let currentPos:float4 = float4(current_mapped_pos, 1)
        
        let coordinatePos = matrix_centering_toView * currentPos;
        
        
        let samplerPostion = float3(coordinatePos.x / (renderer.volumeData.inputImageWidth.toFloat()),
                                    coordinatePos.y / (renderer.volumeData.inputImageHeight.toFloat()),
                                    renderer.renderOption.contains(.FLIP) ?
                                    1 - (coordinatePos.z / (renderer.volumeData.inputImageDepth.toFloat() * scale_Z)) :
                                        (coordinatePos.z / (renderer.volumeData.inputImageDepth.toFloat() * scale_Z)));
        
        
        currentCoordinate = coordinatePos
        
        Logger.logCoorginate(message: "\(samplerPostion.stringValue) -> \(currentCoordinate.xyz.stringValue)")
        

        
    }
    func modelViewMouseDragged(with event: NSEvent, mouse startPoint: NSPoint, previousPoint: NSPoint, currentPoint: NSPoint){
        if(renderer.mainTexture == nil){
            return
        }
        
        let deltaH = Float( currentPoint.x - previousPoint.x)
        let deltaV = Float( currentPoint.y - previousPoint.y)
        
        if(keyboard["49"] == true){ // Space
            renderer.renderParams.translationX -= deltaH
            renderer.renderParams.translationY += deltaV
            outputView.image = renderer.rendering(targetViewSize: AppConfig.PREVIEW_SIZE)
            return
        }
        
        if(event.modifierFlags.contains(.command) == true){
            // When mouse drags with combination of command key, rotate section plane.
            let thetaAxisX = radians(fromDegrees: -deltaV )
            let thetaAxisY = radians(fromDegrees: -deltaH )
            let thetaAxisZ = radians(fromDegrees: 0 )
            
            let quat_X = simd_quatf(angle: thetaAxisX, axis: float3(1, 0, 0))
            let quat_Y = simd_quatf(angle: thetaAxisY, axis: float3(0, 1, 0))
            let quat_Z = simd_quatf(angle: thetaAxisZ, axis: float3(0, 0, 1))
            
            let quat = quat_Y *  quat_Z  * quat_X
            
            renderer.renderParams.cropLockQuaternions = quat * renderer.renderParams.cropLockQuaternions
            outputView.image = renderer.rendering(targetViewSize: AppConfig.PREVIEW_SIZE)
            
        }else{
            rotateModel(deltaAxisX: deltaV, deltaAxisY: deltaH, deltaAxisZ: 0, performRendering: false)
            outputView.image = renderer.rendering(targetViewSize: AppConfig.PREVIEW_SIZE)
        }
        
    }
    
    
    
    func modelViewMouseWheeled(with event: NSEvent){
        if(renderer.mainTexture == nil){
            return
        }
        
        // Change slice no according to the delta value of mouse wheel
        let direction = event.deltaY > 0 ? 1 : -1
        
        if(event.modifierFlags.contains(.command)){
            if(abs(event.deltaY) > 3){
                crop_Slider.integerValue += 5 * direction
            }else if(abs(event.deltaY) > 2){
                crop_Slider.integerValue += 3 * direction
            }else if(abs(event.deltaY) > 1){
                crop_Slider.integerValue += 2 * direction
            }else if(abs(event.deltaY) > 0.5){
                crop_Slider.integerValue += 1 * direction
            }else{
                return
            }
            
            renderer.renderParams.cropSliceNo = crop_Slider.integerValue.toUInt16()
            crop_Label.integerValue = crop_Slider.integerValue
            
        }else{
            if(abs(event.deltaY) > 3){
                slice_Slider.integerValue += 5 * direction
            }else if(abs(event.deltaY) > 2){
                slice_Slider.integerValue += 3 * direction
            }else if(abs(event.deltaY) > 1){
                slice_Slider.integerValue += 2 * direction
            }else if(abs(event.deltaY) > 0.5){
                slice_Slider.integerValue += 1 * direction
            }else{
                return
            }
            
            renderer.renderParams.sliceNo = slice_Slider.integerValue.toUInt16()
            slice_Label_current.integerValue = slice_Slider.integerValue
        }
        
        outputView.image = renderer.rendering(targetViewSize: AppConfig.PREVIEW_SIZE)
        
        if let timer = scrollEndTimer{
            timer.invalidate()
        }
        self.scrollEndTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false, block: { timer in
            self.outputView.image = self.renderer.rendering()
        })
    }
    
    
    func modelViewMouseUp(mouse startPoint: NSPoint, currentPoint: NSPoint){
        if(renderer.mainTexture == nil){
            return
        }
        
        outputView.image = renderer.rendering()
    }
    
    func modelViewMouseClicked(mouse point: NSPoint) {
        if(renderer.mainTexture == nil){
            return
        }
        
        let viewSize = renderer.renderParams.viewSize
        
        print(outputView.bounds.size, outputView.bounds)
        print(outputView.frame.size, outputView.frame)
        print(outputView.layer!.frame.size, outputView.layer!.frame,outputView.layer!.bounds )
        
        let outputViewPoint = self.view.convert(point, to: outputView)
        print(outputViewPoint)
        let viewScaleW = outputView.frame.width / CGFloat (viewSize.toFloat())
        let viewScaleH = outputView.frame.height / CGFloat (viewSize.toFloat())
        let viewScale = Float(min(viewScaleW, viewScaleH))

        let viewCenterPosition =
        float2(Float(outputViewPoint.x - outputView.frame.width / 2.0) / viewScale + viewSize.toFloat() / 2.0,
               (-1.0) * (Float(outputViewPoint.y - outputView.frame.height / 2.0) / viewScale) + viewSize.toFloat() / 2.0)
        
        let centeredPosition:float4 =
        float4(Float(outputViewPoint.x - outputView.frame.width / 2.0) / viewScale,
               (-1.0) * (Float(outputViewPoint.y - outputView.frame.height / 2.0) / viewScale),
               0,
               1)

        let transferMat = matrix_float4x4(float4(1, 0, 0, 0),
                                          float4(0, 1, 0, 0),
                                          float4(0, 0, 1.0, 0),
                                          float4(renderer.renderParams.translationX, renderer.renderParams.translationY, 0, 1.0))
        
        let scaleMatRatio = 1.0 / renderer.renderParams.scale;
        let scale_Z = renderer.renderParams.zScale;
        let scaleMat = float4x4(float4(scaleMatRatio, 0, 0, 0),
                                float4(0, scaleMatRatio, 0, 0),
                                float4(0, 0, 1, 0),
                                float4(0, 0, 0, 1))
        
        let  matrix_centering_toView = float4x4(float4(1, 0, 0, 0),
                                                float4(0, 1, 0, 0),
                                                float4(0, 0, 1, 0),
                                                float4(renderer.volumeData.inputImageWidth.toFloat() / 2.0,
                                                       renderer.volumeData.inputImageHeight.toFloat() / 2.0,
                                                       renderer.volumeData.inputImageDepth.toFloat() * scale_Z / 2.0, 1))
        
        let directionVector = float3(0, 0, 1)
        let directionVector_rotate = renderer.quaternion.act(directionVector)
        
        let pos = transferMat * scaleMat * centeredPosition
        let mappedXYZ = renderer.quaternion.act(pos.xyz)
        
        let radius:Float = renderer.renderParams.sliceMax.toFloat() / 2.0
        let ts =  radius - renderer.renderParams.sliceNo.toFloat()
        
        let current_mapped_pos = mappedXYZ + ts * directionVector_rotate;
        let currentPos:float4 = float4(current_mapped_pos, 1)
        
        let coordinatePos = matrix_centering_toView * currentPos;
        
        
        let samplerPostion = float3(coordinatePos.x / (renderer.volumeData.inputImageWidth.toFloat()),
                                    coordinatePos.y / (renderer.volumeData.inputImageHeight.toFloat()),
                                    renderer.renderOption.contains(.FLIP) ?
                                    1 - (coordinatePos.z / (renderer.volumeData.inputImageDepth.toFloat() * scale_Z)) :
                                        (coordinatePos.z / (renderer.volumeData.inputImageDepth.toFloat() * scale_Z)));
        
        
        currentCoordinate = coordinatePos
        
        Logger.logCoorginate(message: "\(samplerPostion.stringValue) -> \(currentCoordinate.xyz.stringValue)")

        
        print("sampler:", samplerPostion.stringValue)
        print("current ts:", ts)
        
        renderer.pointClouds.pointSet.append(currentCoordinate.xyz)
        renderer.pointClouds.selectedIndex = (renderer.pointClouds.pointSet.count - 1).toUInt16()

        
        pointSetTable.reloadData()
        
        if (renderer.pointClouds.pointSet.count > 0){
            removeAllButton.isEnabled = true
        }else{
            removeAllButton.isEnabled = false
        }
        
        
        
        renderer.renderParams.pointX = viewCenterPosition.x
        renderer.renderParams.pointY = viewCenterPosition.y
        
        
        renderer.argumentManager?.markAsNeedsUpdate(argumentIndex: .pointCoordsBuffer)
        renderer.argumentManager?.markAsNeedsUpdate(argumentIndex: .pointSetCountBuffer)
        renderer.argumentManager?.markAsNeedsUpdate(argumentIndex: .pointSetSelectedBuffer)
        
            outputView.image = renderer.rendering()
    }
    
    
    
}
