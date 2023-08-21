//
//  subViewController.swift
//  Acto3D
//
//  Created by Naoki Takeshita on 2022/02/03.
//

import Cocoa
import Foundation
import simd

class subViewController: NSViewController {
    
    weak var mainView:ViewController!
    
    weak var _win:NSWindow?
    /// get main Window object
    weak var mainWindow:NSWindow?{
        get{
            if(_win == nil){
                print("Get MainWindow Process...")
                NSApplication.shared.windows.forEach { item in
                    print(item.title)
                    if(item.title.contains("Acto3D")){
                        _win = item
                        return
                    }
                }
            }
            return _win
        }
    }
    
    
    @IBOutlet weak var coordinate_1_1: NSTextField!
    @IBOutlet weak var coordinate_1_2: NSTextField!
    @IBOutlet weak var coordinate_1_3: NSTextField!
    
    @IBOutlet weak var coordinate_2_1: NSTextField!
    @IBOutlet weak var coordinate_2_2: NSTextField!
    @IBOutlet weak var coordinate_2_3: NSTextField!
    
    var coordinate_1_1f:float4?
    var coordinate_1_2f:float4?
    var coordinate_1_3f:float4?
    var normal_1f:float3?
    
    var coordinate_2_1f:float4?
    var coordinate_2_2f:float4?
    var coordinate_2_3f:float4?
    var normal_2f:float3?
    
    @IBOutlet weak var degree_2planes: NSTextField!
    
    @IBOutlet weak var normal_1: NSTextField!
    @IBOutlet weak var normal_2: NSTextField!
    
    override func viewDidLoad() {
        coordinate_1_1.stringValue = ""
        coordinate_1_2.stringValue = ""
        coordinate_1_3.stringValue = ""
        coordinate_2_1.stringValue = ""
        coordinate_2_2.stringValue = ""
        coordinate_2_3.stringValue = ""
        normal_1.stringValue = ""
        normal_2.stringValue = ""
        
        super.viewDidLoad()
        // Do view setup here.
        print("controller view")
    }
    
    private func activateMainWindow(){
        mainWindow?.makeKeyAndOrderFront(self)
        mainWindow?.makeMain()
        mainWindow?.makeKey()
    }
    
    
    @IBAction func getCoordinate_plane1(_ sender: NSButton) {
        switch sender.title {
        case "Point 1":
            coordinate_1_1f = mainView.currentCoordinate
            coordinate_1_1.stringValue = mainView.currentCoordinate.xyz.stringValue
        case "Point 2":
            coordinate_1_2f = mainView.currentCoordinate
            coordinate_1_2.stringValue = mainView.currentCoordinate.xyz.stringValue
        case "Point 3":
            coordinate_1_3f = mainView.currentCoordinate
            coordinate_1_3.stringValue = mainView.currentCoordinate.xyz.stringValue
        default:
            break
        }
        
        
        guard let coordinate_1_1f = coordinate_1_1f,
              let coordinate_1_2f = coordinate_1_2f ,
              let coordinate_1_3f = coordinate_1_3f else {return}
        
        let v1 = coordinate_1_1f - coordinate_1_2f
        let v2 = coordinate_1_1f - coordinate_1_3f
        normal_1f = normalize (cross(v1.xyz, v2.xyz))
        
        normal_1.stringValue = "Normal: \(normal_1f!.stringValue)"
        normal_1.sizeToFit()
        
        
        // すべてのpointが入力されていた場合は角度を計算する
        guard let coordinate_2_1f = coordinate_2_1f,
              let coordinate_2_2f = coordinate_2_2f,
              let coordinate_2_3f = coordinate_2_3f else {return}
        
        let v1_1 = coordinate_1_1f.xyz - coordinate_1_2f.xyz
        let v1_2 = coordinate_1_1f.xyz - coordinate_1_3f.xyz
        let n_1 = normalize (cross(v1_1, v1_2))
        
        let v2_1 = coordinate_2_1f.xyz - coordinate_2_2f.xyz
        let v2_2 = coordinate_2_1f.xyz - coordinate_2_3f.xyz
        let n_2 = normalize (cross(v2_1, v2_2))

        let theta = acos (dot(n_1, n_2))
        let deg = degrees(fromRadians: theta)
        
        degree_2planes.stringValue = "Angle between 2 planes: \(String(format: "%.2f", min(deg, 180 - deg))) degrees"
        degree_2planes.sizeToFit()
//        print("degree", degrees(fromRadians: theta))
        
    }
    
    @IBAction func getCoordinate_plane2(_ sender: NSButton) {
        switch sender.title {
        case "Point 1":
            coordinate_2_1f = mainView.currentCoordinate
            coordinate_2_1.stringValue = mainView.currentCoordinate.xyz.stringValue
        case "Point 2":
            coordinate_2_2f = mainView.currentCoordinate
            coordinate_2_2.stringValue = mainView.currentCoordinate.xyz.stringValue
        case "Point 3":
            coordinate_2_3f = mainView.currentCoordinate
            coordinate_2_3.stringValue = mainView.currentCoordinate.xyz.stringValue
        default:
            break
        }
        
        
        guard let coordinate_2_1f = coordinate_2_1f,
              let coordinate_2_2f = coordinate_2_2f ,
              let coordinate_2_3f = coordinate_2_3f else {return}
        
        let v1 = coordinate_2_1f - coordinate_2_2f
        let v2 = coordinate_2_1f - coordinate_2_3f
        normal_2f = normalize (cross(v1.xyz, v2.xyz))
        
        normal_2.stringValue = "Normal: \(normal_2f!.stringValue)"
        normal_2.sizeToFit()
    }
    
    func rotateToPlaneWithParams(vec1: float3, vec2:float3, vec3:float3){
        let v1 = vec1 - vec2
        let v2 = vec1 - vec3
        let n = normalize (cross(v1, v2))
        
        // (0,0,1)との角度
        let d =  normalize (float3(0,0,1))
        let theta = acos (dot(n, d))
        
        // cross order is important
        let axis = normalize(cross(d, n))
        
        print("rotationAxis", axis.stringValue)
        print("degree", degrees(fromRadians: theta))
        
        
        
        
        // initialize vector to AP view
        mainView.normalX = float3(1,0,0)
        mainView.normalY = float3(0,1,0)
        mainView.normalZ = float3(0,0,1)
        mainView.quaternion = simd_quatf(float4x4(1))
        
        let qua = simd_quatf(angle: theta, axis: axis)
        
        mainView.normalX = qua.act(mainView.normalX)
        mainView.normalY = qua.act(mainView.normalY)
        mainView.normalZ = qua.act(mainView.normalZ)
        
        mainView.quaternion = qua * mainView.quaternion
        
        let eular = mainView.quatToEulerAngles(mainView.quaternion) * 180.0 / PI
        
        let normals = mainView.quaternion.act(float3(0, 0, 1))
        
        
        // p1-p3を逆回転して座標をちぇっく
        print("P1", vec1.stringValue)
        let cP1 = mainView.quaternion.inverse.act(vec1)
        print(cP1.stringValue)
        
        print("P2", vec2.stringValue)
        let cP2 = mainView.quaternion.inverse.act(vec2)
        print(cP2.stringValue)
        
        print("P3", vec3.stringValue)
        let cP3 = mainView.quaternion.inverse.act(vec3)
        print(cP3.stringValue)
        
        
        let scale_Z = mainView.modelParameter.zScale;
        let radius:Float = mainView.modelParameter.sliceMax.toFloat() / 2.0
        
        //            cP1-3はZが同じ値になる
        let cZ = cP3.z / (mainView.metadata.depth.toFloat() * scale_Z)
        print("cZ", cZ)
        print("normals", normals.stringValue)
        var ts = cZ // / (normals.z)
        print("ts", ts)
        
        ts = cZ - (mainView.metadata.depth.toFloat() * scale_Z / 2.0)
        
        //            modelParameter.sliceNo = UInt16(radius + ts)
        print("radius", radius)
        print("cP3.z" , cP3.z)
        //        mainView.modelParameter.sliceNo = UInt16(cP3.z + radius / 2.0)
        //        mainView.modelParameter.sliceNo = UInt16(radius - cP3.z + 230 )
        //        mainView.slice_Slider.floatValue = mainView.modelParameter.sliceNo.toFloat()
        
        
        mainView.renderOption.changeValue(option: .CROP_LOCK, value: 1)
        // cropをlockしたときの回転とスライスNoをセット
        mainView.modelParameter.cropLockQuaternions = mainView.quaternion
        mainView.modelParameter.cropSliceNo = mainView.modelParameter.sliceNo
        
        // 現在のsliceNoはリセットしてMaxに移動しておく
        //                modelParameter.sliceNo = modelParameter.sliceMax
        //                slice_Slider.doubleValue = slice_Slider.maxValue
        
        
        
        if (Thread.current.isMainThread){
            mainView.eularX.floatValue = eular.z
            mainView.eularY.floatValue = eular.x
            mainView.eularZ.floatValue = eular.y
            
            mainView.normalVecField.stringValue = "Norm: \(round(normals.x * 100)/100) \(round(normals.y * 100)/100) \(round(normals.z * 100)/100)"
            
            
        }else{
            DispatchQueue.main.sync {
                mainView.eularX.floatValue = eular.z
                mainView.eularY.floatValue = eular.x
                mainView.eularZ.floatValue = eular.y
                
                mainView.normalVecField.stringValue = "Norm: \(normals)"
            }
        }
        
        //        print(eular)
        //        print(quatToEulerAngles(quaternion))
        //        print(quatToEular2(quaternion))
        
        //        eularXYZ = float3(eular.z, eular.x, eular.y)
        
        
        mainView.uniforms = float4x4(mainView.quaternion)
        
        
        mainView.computeRendering()
    }
    
    @IBAction func rotateToPlane(_ sender: NSButton) {
        switch sender.identifier?.rawValue {
        case "Plane1":
            guard let coordinate_1_1f = coordinate_1_1f,
                  let coordinate_1_2f = coordinate_1_2f ,
                  let coordinate_1_3f = coordinate_1_3f else {return}
            
            rotateToPlaneWithParams(vec1: coordinate_1_1f.xyz, vec2: coordinate_1_2f.xyz, vec3: coordinate_1_3f.xyz)
            
            break
        case "Plane2":
            guard let coordinate_2_1f = coordinate_2_1f,
                  let coordinate_2_2f = coordinate_2_2f ,
                  let coordinate_2_3f = coordinate_2_3f else {return}
            
            rotateToPlaneWithParams(vec1: coordinate_2_1f.xyz, vec2: coordinate_2_2f.xyz, vec3: coordinate_2_3f.xyz)
            
            break
            
        default:
            break
        }
        
        return
        guard let coordinate_1_1f = coordinate_1_1f,
              let coordinate_1_2f = coordinate_1_2f ,
              let coordinate_1_3f = coordinate_1_3f else {return}
        
        let v1 = coordinate_1_1f - coordinate_1_2f
        let v2 = coordinate_1_1f - coordinate_1_3f
        normal_1f = normalize (cross(v1.xyz, v2.xyz))
        
        // (0,0,1)との角度
        let d =  normalize (float3(0,0,1))
        let theta = acos (dot(normal_1f!, d))
        
        // cross order is important
        let axis = normalize(cross(d, normal_1f!))
        
        print("rotationAxis", axis.stringValue)
        print("degree", degrees(fromRadians: theta))
        
        
        
        
        // initialize vector to AP view
        mainView.normalX = float3(1,0,0)
        mainView.normalY = float3(0,1,0)
        mainView.normalZ = float3(0,0,1)
        mainView.quaternion = simd_quatf(float4x4(1))
        
        let qua = simd_quatf(angle: theta, axis: axis)
        
        mainView.normalX = qua.act(mainView.normalX)
        mainView.normalY = qua.act(mainView.normalY)
        mainView.normalZ = qua.act(mainView.normalZ)
        
        mainView.quaternion = qua * mainView.quaternion
        
        let eular = mainView.quatToEulerAngles(mainView.quaternion) * 180.0 / PI
        
        let normals = mainView.quaternion.act(float3(0, 0, 1))
        
        
        // p1-p3を逆回転して座標をちぇっく
        print("P1", coordinate_1_1f.xyz.stringValue)
        let cP1 = mainView.quaternion.inverse.act(coordinate_1_1f.xyz)
        print(cP1.stringValue)
        
        print("P2", coordinate_1_2f.xyz.stringValue)
        let cP2 = mainView.quaternion.inverse.act(coordinate_1_2f.xyz)
        print(cP2.stringValue)
        
        print("P3", coordinate_1_3f.xyz.stringValue)
        let cP3 = mainView.quaternion.inverse.act(coordinate_1_3f.xyz)
        print(cP3.stringValue)
        
        
        let scale_Z = mainView.modelParameter.zScale;
        let radius:Float = mainView.modelParameter.sliceMax.toFloat() / 2.0
        
        //            cP1-3はZが同じ値になる
        let cZ = cP3.z / (mainView.metadata.depth.toFloat() * scale_Z)
        print("cZ", cZ)
        print("normals", normals.stringValue)
        var ts = cZ // / (normals.z)
        print("ts", ts)
        
        ts = cZ - (mainView.metadata.depth.toFloat() * scale_Z / 2.0)
        
        //            modelParameter.sliceNo = UInt16(radius + ts)
        print("radius", radius)
        print("cP3.z" , cP3.z)
        mainView.modelParameter.sliceNo = UInt16(cP3.z + radius / 2.0)
        mainView.modelParameter.sliceNo = UInt16(radius - cP3.z + 230 )
        mainView.slice_Slider.floatValue = mainView.modelParameter.sliceNo.toFloat()
        
        
        mainView.renderOption.changeValue(option: .CROP_LOCK, value: 1)
        // cropをlockしたときの回転とスライスNoをセット
        mainView.modelParameter.cropLockQuaternions = mainView.quaternion
        mainView.modelParameter.cropSliceNo = mainView.modelParameter.sliceNo
        
        // 現在のsliceNoはリセットしてMaxに移動しておく
        //                modelParameter.sliceNo = modelParameter.sliceMax
        //                slice_Slider.doubleValue = slice_Slider.maxValue
        
        
        
        if (Thread.current.isMainThread){
            mainView.eularX.floatValue = eular.z
            mainView.eularY.floatValue = eular.x
            mainView.eularZ.floatValue = eular.y
            
            mainView.normalVecField.stringValue = "Norm: \(round(normals.x * 100)/100) \(round(normals.y * 100)/100) \(round(normals.z * 100)/100)"
            
            
        }else{
            DispatchQueue.main.sync {
                mainView.eularX.floatValue = eular.z
                mainView.eularY.floatValue = eular.x
                mainView.eularZ.floatValue = eular.y
                
                mainView.normalVecField.stringValue = "Norm: \(normals)"
            }
        }
        
        //        print(eular)
        //        print(quatToEulerAngles(quaternion))
        //        print(quatToEular2(quaternion))
        
        //        eularXYZ = float3(eular.z, eular.x, eular.y)
        
        
        mainView.uniforms = float4x4(mainView.quaternion)
        
        
        mainView.computeRendering()
    }
    
    
    
    
    @IBAction func rotateButton(_ sender: NSButton) {
        
        switch sender.identifier?.rawValue {
        case "Clock":
            mainView.rotateModel(deltaAxisX: 0, deltaAxisY: 0, deltaAxisZ: -90)
            return
        case "Counter":
            mainView.rotateModel(deltaAxisX: 0, deltaAxisY: 0, deltaAxisZ: 90)
            return
            
        case "R90":
            mainView.rotateModel(deltaAxisX: 0, deltaAxisY: -90, deltaAxisZ: 0)
            return
        case "T90":
            mainView.rotateModel(deltaAxisX: -90, deltaAxisY: 0, deltaAxisZ: 0)
            return
        default:
            break
        }
        
        
        // init parameters
        mainView.normalX = float3(1,0,0)
        mainView.normalY = float3(0,1,0)
        mainView.normalZ = float3(0,0,1)
        mainView.quaternion = simd_quatf(float4x4(1))
        
        
        switch sender.identifier?.rawValue {
        case "Anterior":
            mainView.rotateModel(deltaAxisX: 0, deltaAxisY: 0, deltaAxisZ: 0)
        case "Posterior":
            mainView.rotateModel(deltaAxisX: 0, deltaAxisY: 180, deltaAxisZ: 0)
            
        case "Top":
            mainView.rotateModel(deltaAxisX: -90, deltaAxisY: 0, deltaAxisZ: 0)
        case "Bottom":
            mainView.rotateModel(deltaAxisX: 90, deltaAxisY: 0, deltaAxisZ: 0)
        case "Left":
            mainView.rotateModel(deltaAxisX: 0, deltaAxisY: 90, deltaAxisZ: 0)
        case "Right":
            mainView.rotateModel(deltaAxisX: 0, deltaAxisY: -90, deltaAxisZ: 0)
            
        default:
            break
        }
        
        
    }
    
}
