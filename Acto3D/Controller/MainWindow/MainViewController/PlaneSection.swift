//
//  PlaneSection.swift
//  Acto3D
//
//  Created by Naoki Takeshita on 2022/03/03.
//

import Foundation
import Cocoa
import simd

extension ViewController{
    
    func calculateDistance(p1:float3, p2:float3){
        print("cal")
        let length = length(p1 - p2)
        var resultString = "Distance: \(length) px"
        if (renderer.imageParams.unit != "") {
            resultString += " \(length * renderer.imageParams.scaleX) \(renderer.imageParams.unit)"
        }
        distane_2pointsField.stringValue = resultString
        distane_2pointsField.sizeToFit()
    }
    
    
    @IBAction func showPlane1(_ sender : NSButton){
        if(pointSetTable.selectedRowIndexes.count != 3) {
            return
        }
        
        var index:[Int] = []
        for (_, i) in pointSetTable.selectedRowIndexes.enumerated() {
            index.append(i)
        }
        
        let point1 = renderer.pointClouds.pointSet[index[0]]
        let point2 = renderer.pointClouds.pointSet[index[1]]
        let point3 = renderer.pointClouds.pointSet[index[2]]
        
        let v1 = point1 - point2
        let v2 = point1 - point3
        let _cross = cross(v1, v2)
        
        if(_cross == float3()){
            let alert = NSAlert()
            alert.alertStyle = .critical
            alert.messageText = "Please select the other 3 points"
            alert.beginSheetModal(for: self.view.window!)
            return
        }
        
        let n = normalize (_cross)
        
        let d =  normalize (float3(0,0,1))
        let theta = acos (dot(n, d))
        
        
        // cross order is important
        var axis = normalize(cross(d, n))
        
        if (d == n){
            axis = d
        }
        
            
        let scale_Z = renderer.renderParams.zScale;
        
        let  matrix_centering_toView = float4x4(float4(1, 0, 0, 0),
                                                float4(0, 1, 0, 0),
                                                float4(0, 0, 1, 0),
                                                float4(renderer.volumeData.inputImageWidth.toFloat() / 2.0, renderer.volumeData.inputImageHeight.toFloat() / 2.0, renderer.volumeData.inputImageDepth.toFloat() * scale_Z / 2.0, 1))
        
        let radius:Float = renderer.renderParams.sliceMax.toFloat() / 2.0
        
        let directionVector = float3(0, 0, 1)
        
        let quat_plane = simd_quatf(angle: theta, axis: axis)
        
        let directionVector_rotate = quat_plane.act(directionVector)
        
        
        
        
        let p1 = matrix_centering_toView.inverse * float4(point1, 1)
        let p2 = matrix_centering_toView.inverse * float4(point2, 1)
        let p3 = matrix_centering_toView.inverse * float4(point3, 1)
        

        
        let ln1 = directionVector_rotate.x * p1.x + directionVector_rotate.y * p1.y + directionVector_rotate.z * p1.z
        let ln2 = directionVector_rotate.x * p2.x + directionVector_rotate.y * p2.y + directionVector_rotate.z * p2.z
        let ln3 = directionVector_rotate.x * p3.x + directionVector_rotate.y * p3.y + directionVector_rotate.z * p3.z
            
        let ln = (ln1 + ln2 + ln3) / 3.0
        
        slice_Slider.floatValue = radius - ln
        
        
        
        // crop lock
        renderer.renderParams.cropLockQuaternions = quat_plane
        renderer.renderParams.cropSliceNo = slice_Slider.integerValue.toUInt16()
        
        crop_Slider.integerValue = renderer.renderParams.cropSliceNo.toInt()
        crop_Label.stringValue = "\(crop_Slider.integerValue) / \(crop_Slider.maxValue.toInt())"
        
        
        renderer.renderOption.update(with: .CROP_LOCK)
        renderer.renderOption.update(with: .PLANE)
        switch_cropLock.integerValue = renderer.renderOption.contains(.CROP_LOCK) ? 1 : 0
        switch_plane.integerValue = renderer.renderOption.contains(.PLANE) ? 1 : 0
        
        
        renderer.renderParams.sliceNo = renderer.renderParams.sliceMax
        slice_Slider.doubleValue = slice_Slider.maxValue
        
        crop_Label.sizeToFit()
        slice_Label.sizeToFit()
        scale_Label.sizeToFit()
        zScale_Label.sizeToFit()
        
        
        
        self.rotateModel(withQuaternion: quat_plane, performRendering: true)
        
        normal_1.stringValue = "Normal: \(n.stringValue)"
        
        normal_1f = n
        
        if(normal_1f != nil && normal_2f != nil){
            
            let theta = acos (dot(normal_1f!, normal_2f!))
            let deg = degrees(fromRadians: theta)
            
            degree_2planes.stringValue = "Angle between 2 planes: \(String(format: "%.2f", min(deg, 180 - deg))) degrees"
            degree_2planes.sizeToFit()
        }
    }
    
    @IBAction func showPlane2(_ sender : NSButton){
        if(pointSetTable.selectedRowIndexes.count != 3) {
            return
        }
        
        var index:[Int] = []
        for (_, i) in pointSetTable.selectedRowIndexes.enumerated() {
            index.append(i)
        }
        
        let point1 = renderer.pointClouds.pointSet[index[0]]
        let point2 = renderer.pointClouds.pointSet[index[1]]
        let point3 = renderer.pointClouds.pointSet[index[2]]
        
        let v1 = point1 - point2
        let v2 = point1 - point3
        let _cross = cross(v1, v2)
        
        if(_cross == float3()){
            let alert = NSAlert()
            alert.alertStyle = .critical
            alert.messageText = "Please select the other 3 points"
            alert.beginSheetModal(for: self.view.window!)
            return
        }
        
        let n = normalize (_cross)
        
        let d =  normalize (float3(0,0,1))
        let theta = acos (dot(n, d))
        
        
        // cross order is important
        var axis = normalize(cross(d, n))
        
        if (d == n){
            axis = d
        }
        
        print("rotationAxis", axis.stringValue)
        print("degree", degrees(fromRadians: theta))
        
            
        let scale_Z = renderer.renderParams.zScale;
        
        let  matrix_centering_toView = float4x4(float4(1, 0, 0, 0),
                                                float4(0, 1, 0, 0),
                                                float4(0, 0, 1, 0),
                                                float4(renderer.volumeData.inputImageWidth.toFloat() / 2.0, renderer.volumeData.inputImageHeight.toFloat() / 2.0, renderer.volumeData.inputImageDepth.toFloat() * scale_Z / 2.0, 1))
        
        let radius:Float = renderer.renderParams.sliceMax.toFloat() / 2.0
        
        let directionVector = float3(0, 0, 1)
        
        let quat_plane = simd_quatf(angle: theta, axis: axis)
        
        
        let directionVector_rotate = quat_plane.act(directionVector)
        
        let p1 = matrix_centering_toView.inverse * float4(point1, 1)
        let p2 = matrix_centering_toView.inverse * float4(point2, 1)
        let p3 = matrix_centering_toView.inverse * float4(point3, 1)
        

        
        let ln1 = directionVector_rotate.x * p1.x + directionVector_rotate.y * p1.y + directionVector_rotate.z * p1.z
        let ln2 = directionVector_rotate.x * p2.x + directionVector_rotate.y * p2.y + directionVector_rotate.z * p2.z
        let ln3 = directionVector_rotate.x * p3.x + directionVector_rotate.y * p3.y + directionVector_rotate.z * p3.z
            
        let ln = (ln1 + ln2 + ln3) / 3.0
        
        slice_Slider.floatValue = radius - ln
        
        
        // crop lock
        renderer.renderParams.cropLockQuaternions = quat_plane
        renderer.renderParams.cropSliceNo = slice_Slider.integerValue.toUInt16()
        
        crop_Slider.integerValue = renderer.renderParams.cropSliceNo.toInt()
        crop_Label.stringValue = "\(crop_Slider.integerValue) / \(crop_Slider.maxValue.toInt())"
        
        
        renderer.renderOption.update(with: .CROP_LOCK)
        renderer.renderOption.update(with: .PLANE)
        switch_cropLock.integerValue = renderer.renderOption.contains(.CROP_LOCK) ? 1 : 0
        switch_plane.integerValue = renderer.renderOption.contains(.PLANE) ? 1 : 0
        
        
        renderer.renderParams.sliceNo = renderer.renderParams.sliceMax
        slice_Slider.doubleValue = slice_Slider.maxValue
        
        crop_Label.sizeToFit()
        slice_Label.sizeToFit()
        scale_Label.sizeToFit()
        zScale_Label.sizeToFit()
        
        
        self.rotateModel(withQuaternion: quat_plane, performRendering: true)
        
        normal_2.stringValue = "Normal: \(n.stringValue)"
        normal_2f = n
        
        if(normal_1f != nil && normal_2f != nil){
            
            let theta = acos (dot(normal_1f!, normal_2f!))
            let deg = degrees(fromRadians: theta)
            
            degree_2planes.stringValue = "Angle between 2 planes: \(String(format: "%.2f", min(deg, 180 - deg))) degrees"
            degree_2planes.sizeToFit()
        }
    }
    
    
}
