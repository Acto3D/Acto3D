//
//  SaveAndLoad.swift
//  Acto3D
//
//  Created by Naoki Takeshita on 2022/02/28.
//

import Foundation
import Cocoa
import Metal
import MetalKit
import CoreGraphics

extension ViewController{
    
    public func interpolate<T: BinaryFloatingPoint>(p1: T, p2:T, ratio:Float) -> T{
        return p1 + (p2 - p1) * T(ratio)
    }
    
    public func interpolate<T: FixedWidthInteger>(p1: T, p2:T, ratio:Float) -> T{
        return T(Float(p1) + (Float(p2) - Float(p1)) * (ratio))
    }
    
    public func interpolate<T: SIMD>(p1: T, p2:T, ratio:Float) -> T where T.Scalar == Float{
        return p1 + (p2 - p1) * ratio
    }
    
    public func interpolate(p1: [[Float]], p2:[[Float]], ratio:Float) -> [[Float]]{
        let interpolatedArray = p1.enumerated().map { (i, values) in
            values.enumerated().map { (j, value) in
                value + (p2[i][j] - value) * ratio
            }
        }
        return interpolatedArray
    }
    
    public func interpolate(p1: PackedColor, p2:PackedColor, ratio:Float) -> PackedColor{
        return PackedColor(ch1_color: interpolate(p1: p1.ch1_color, p2: p2.ch1_color, ratio: ratio),
                           ch2_color: interpolate(p1: p1.ch2_color, p2: p2.ch2_color, ratio: ratio),
                           ch3_color: interpolate(p1: p1.ch3_color, p2: p2.ch3_color, ratio: ratio),
                           ch4_color: interpolate(p1: p1.ch4_color, p2: p2.ch4_color, ratio: ratio))
    }
    func generateInterpolatedParameters(p1: StoredParameters, p2:StoredParameters, ratio: Float) -> StoredParameters{
        
        var interpolateParams = StoredParameters()
        
        interpolateParams.quaternion = simd_slerp(p1.quaternion, p2.quaternion, ratio)
        
        var renderParams = RenderingParameters()
        
        renderParams.scale = interpolate(p1: p1.renderParams.scale, p2: p2.renderParams.scale, ratio: ratio)
        renderParams.zScale = interpolate(p1: p1.renderParams.zScale, p2: p2.renderParams.zScale, ratio: ratio)
        renderParams.sliceNo = interpolate(p1: p1.renderParams.sliceNo, p2: p2.renderParams.sliceNo, ratio: ratio)
        renderParams.sliceMax = interpolate(p1: p1.renderParams.sliceMax, p2: p2.renderParams.sliceMax, ratio: ratio)
        renderParams.trimX_min = interpolate(p1: p1.renderParams.trimX_min, p2: p2.renderParams.trimX_min, ratio: ratio)
        renderParams.trimX_max = interpolate(p1: p1.renderParams.trimX_max, p2: p2.renderParams.trimX_max, ratio: ratio)
        renderParams.trimY_min = interpolate(p1: p1.renderParams.trimY_min, p2: p2.renderParams.trimY_min, ratio: ratio)
        renderParams.trimY_max = interpolate(p1: p1.renderParams.trimY_max, p2: p2.renderParams.trimY_max, ratio: ratio)
        renderParams.trimZ_min = interpolate(p1: p1.renderParams.trimZ_min, p2: p2.renderParams.trimZ_min, ratio: ratio)
        renderParams.trimZ_max = interpolate(p1: p1.renderParams.trimZ_max, p2: p2.renderParams.trimZ_max, ratio: ratio)
        
        renderParams.color = interpolate(p1: p1.renderParams.color, p2: p2.renderParams.color, ratio: ratio)
        
        renderParams.cropLockQuaternions = simd_slerp(p1.renderParams.cropLockQuaternions, p2.renderParams.cropLockQuaternions, ratio)
        
        renderParams.cropSliceNo = interpolate(p1: p1.renderParams.cropSliceNo, p2: p2.renderParams.cropSliceNo, ratio: ratio)
        
        renderParams.eularX = interpolate(p1: p1.renderParams.eularX, p2: p2.renderParams.eularX, ratio: ratio)
        renderParams.eularY = interpolate(p1: p1.renderParams.eularY, p2: p2.renderParams.eularY, ratio: ratio)
        renderParams.eularZ = interpolate(p1: p1.renderParams.eularZ, p2: p2.renderParams.eularZ, ratio: ratio)
        
        renderParams.translationX = interpolate(p1: p1.renderParams.translationX, p2: p2.renderParams.translationX, ratio: ratio)
        renderParams.translationY = interpolate(p1: p1.renderParams.translationY, p2: p2.renderParams.translationY, ratio: ratio)
        
        renderParams.viewSize = interpolate(p1: p1.renderParams.viewSize, p2: p2.renderParams.viewSize, ratio: ratio)
        renderParams.alphaPower = p1.renderParams.alphaPower
        
        renderParams.renderingStep = interpolate(p1: p1.renderParams.renderingStep, p2: p2.renderParams.renderingStep, ratio: ratio)
        
        renderParams.renderingMethod = p1.renderParams.renderingMethod
        
        renderParams.backgroundColor = interpolate(p1: p1.renderParams.backgroundColor!, p2: p2.renderParams.backgroundColor!, ratio: ratio)
        
        renderParams.intensityRatio = interpolate(p1: p1.renderParams.intensityRatio, p2: p2.renderParams.intensityRatio, ratio: ratio)
        renderParams.light = interpolate(p1: p1.renderParams.light, p2: p2.renderParams.light, ratio: ratio)
        renderParams.shade = interpolate(p1: p1.renderParams.shade, p2: p2.renderParams.shade, ratio: ratio)

        
        
        interpolateParams.renderParams = renderParams
        
        interpolateParams.toneColors = []
        for (index, _) in p1.toneColors.enumerated(){
            interpolateParams.toneColors.append(interpolate(p1: p1.toneColors[index], p2: p2.toneColors[index], ratio: ratio))
        }
                    
        interpolateParams.imageParams = p1.imageParams
        interpolateParams.renderOption = p1.renderOption
        
        interpolateParams.controlPoints = ratio < 0.5 ? p1.controlPoints : p2.controlPoints
        
        if let p1alpha = p1.alphaValues,
           let p2alpha = p2.alphaValues {
            interpolateParams.alphaValues = interpolate(p1: p1alpha, p2: p2alpha, ratio: ratio)
        }
        
        interpolateParams.pointClouds = p1.pointClouds
    
        
        return interpolateParams
        
        
    }
    
    func getStoredParams(from fileName: String) -> StoredParameters?{
        guard let filePackage = filePackage,
              let paramDir = filePackage.parameterDir else {return nil}
        
        let fileUrl = paramDir.appendingPathComponent(fileName)
        
        var params:StoredParameters?
        
        do{
            
            let data = try Data(contentsOf: fileUrl)
            let decoder = JSONDecoder()
            params = try decoder.decode(StoredParameters.self, from: data)
            
        }catch let error{
            Dialog.showDialog(message: error.localizedDescription)
            return nil
        }
        
        guard var params = params else {return nil}
        
        params.imageParams = renderer.imageParams
        
        return params
    }
    
    func getRenderModelParams(file: String) -> RenderingParameters?{
        guard let filePackage = filePackage,
              let paramDir = filePackage.parameterDir else {return nil}
        
        let fileUrl = paramDir.appendingPathComponent(file)
        
        var params:StoredParameters?
        
        do{
            let data = try Data(contentsOf: fileUrl)
            let decoder = JSONDecoder()
            params = try decoder.decode(StoredParameters.self, from: data)
            
        }catch let error{
            Dialog.showDialog(message: error.localizedDescription)
            return nil
        }
        
        guard var params = params else {return nil}
        
        params.imageParams = renderer.imageParams
        
        // apply params
        renderer.renderParams = params.renderParams
        renderer.resetRotation()
        renderer.rotateModelTo(quaternion: params.quaternion)
        renderer.renderOption = RenderOption(rawValue: params.renderOption)
        renderer.pointClouds = params.pointClouds
        
        return params.renderParams
    }
    
    
    
    func positiveAngle(x:Float,y:Float,z:Float) -> float3{
        let X = (x >= 0) ? x : x + 360
        let Y = (y >= 0) ? y : y + 360
        let Z = (z >= 0) ? z : z + 360
        return float3(x: X, y: Y, z: Z)
    }
    
    
    // MARK: - Save & Load Parameters
    
    struct StoredParameters:Codable{
        var renderParams:RenderingParameters!
        var quaternion:simd_quatf!
        var controlPoints:[[[Float]]]!
        var toneColors:[float4]!
        
        var controlPointsInterpolateMode:[Int]?
        
        var pointClouds:PointClouds! = PointClouds()
        var renderOption:UInt16!
        var shaderInfo:ShaderManage? 
        
        var alphaValues:[[Float]]?
        
        var imageParams:ImageParameters?
    }
    
    /// Save Parameters to JSON
    @IBAction func SaveParams(_ sender: NSButton) {
        // save as JSON
        
        guard let filePackage = filePackage else { return }
        
        // create data struct to save
        let storedParams = StoredParameters(renderParams: renderer.renderParams,
                                            quaternion: renderer.quaternion,
                                            controlPoints: [toneCh1.controlPoints,
                                                            toneCh2.controlPoints,
                                                            toneCh3.controlPoints,
                                                            toneCh4.controlPoints],
                                            toneColors: [wellCh1.color.RGBAtoFloat4(),
                                                         wellCh2.color.RGBAtoFloat4(),
                                                         wellCh3.color.RGBAtoFloat4(),
                                                         wellCh4.color.RGBAtoFloat4()],
                                            
                                            controlPointsInterpolateMode: [toneCh1.spline!.interpolateMode.rawValue,
                                                                           toneCh2.spline!.interpolateMode.rawValue,
                                                                           toneCh3.spline!.interpolateMode.rawValue,
                                                                           toneCh4.spline!.interpolateMode.rawValue],
                                            
                                            pointClouds: renderer.pointClouds,
                                            renderOption: renderer.renderOption.rawValue,
                                            shaderInfo: renderer.currentShader,
                                            imageParams: renderer.imageParams)
        
        // Create thumbnail image from current output rendering image
        guard let currentImage = outputView.image else {
            Dialog.showDialog(message: "Cannot create thumbnail")
            return
        }
        let screen = NSScreen.main
        let scaleFactor = screen?.backingScaleFactor ?? 1.0 // return 2.0 for Retina display
        
        // resize
        let newSize = NSSize(width: 256 / scaleFactor, height: 256 / scaleFactor)
        let resizedImage = NSImage(size: newSize)
        resizedImage.lockFocus()
        currentImage.draw(in: NSRect(origin: .zero, size: newSize),
                          from: NSRect(origin: .zero, size: currentImage.size),
                          operation: .sourceOver,
                          fraction: 1.0)
        resizedImage.unlockFocus()
        
        
        let fileStamp = NSDate().timeStampYYYYMMDDHHMMSS()
        let paramDir = filePackage.parameterDir!
        let jsonUrl = paramDir.appendingPathComponent("\(fileStamp).json")
        let jpegUrl = paramDir.appendingPathComponent("\(fileStamp).jpg")
        
        // save JSON
        do{
            let data = try JSONEncoder().encode(storedParams)
            try data.write(to: jsonUrl, options: .atomic)
        }catch{
            Dialog.showDialog(message: error.localizedDescription)
            return
        }
        
        // save thumbnail
        guard let tiff = resizedImage.tiffRepresentation,
              let imgRep = NSBitmapImageRep(data: tiff)
        else {
            return
        }
        guard let data = imgRep.representation(using: .jpeg, properties: [.compressionFactor:0.9]) else {
            return
        }
        do {
            try data.write(to: jpegUrl)
        }catch{
            Dialog.showDialog(message: error.localizedDescription)
            return
        }
        Logger.log(message: "saved current parameters")
    }
    
    /// get JSON list and create menu items
    @IBAction func loadStoredParamList(_ sender: NSButton) {
        guard let filePackage = filePackage else {return}
        
        guard let jsonList = filePackage.enumerateParameterFiles() else{
            let jsonListMenu = NSMenu()
            jsonListMenu.addItem(NSMenuItem(title: "Setting file does not exist", action: nil, keyEquivalent: ""))
            let menuPosition = sender.superview!.convert(NSPoint(x: sender.frame.minX, y: sender.frame.minY), to: self.view)
            jsonListMenu.popUp(positioning: nil, at: NSPoint(x: menuPosition.x, y: menuPosition.y), in: self.view)
        
            return
        }
        
        
        let jsonListMenu = NSMenu()
        
        jsonList.forEach { (fileName, img) in
            let menuItem = NSMenuItem(title: fileName, action: #selector(self.loadParametersFromJSON(_:)), keyEquivalent: "")
            menuItem.image = img
            jsonListMenu.addItem(menuItem)
            
        }
        
        
        let menuPosition = sender.superview!.convert(NSPoint(x: sender.frame.minX, y: sender.frame.minY), to: self.view)
        
        jsonListMenu.popUp(positioning: nil, at: NSPoint(x: menuPosition.x, y: menuPosition.y), in: self.view)
        
    }
    
    /// load adn apply parameters from JSON
    @objc func loadParametersFromJSON(_ sender: NSMenuItem) {
        guard let filePackage = filePackage else {return}
        
        guard let paramDir = filePackage.parameterDir else {return}
        let fileUrl = paramDir.appendingPathComponent(sender.title)
        
        Logger.log(message: "Load parameters from: \(fileUrl.path)", level: .info, writeToLogfile: true)
        
        var params:StoredParameters!
        
        do{
            let data = try Data(contentsOf: fileUrl)
            let decoder = JSONDecoder()
            params = try decoder.decode(StoredParameters.self, from: data)
        }catch let error{
            Dialog.showDialog(message: error.localizedDescription)
            return
        }
        
        // Apply params
        renderer.renderParams = params.renderParams
        renderer.resetRotation()
        renderer.rotateModelTo(quaternion: params.quaternion)
        renderer.renderOption = RenderOption(rawValue: params.renderOption)
        renderer.pointClouds = params.pointClouds
        
        if let shaderInfo = params.shaderInfo{
            renderer.currentShader = shaderInfo
        }else{
            renderer.currentShader = ShaderManage.getPresetList()[1]
        }
        
        switch renderer.currentShader!.kernalName {
        case "preset_FTB":
            segmentRenderMode.selectedSegment = 0
            
        case "preset_BTF":
            segmentRenderMode.selectedSegment = 1
            
        case "preset_MIP":
            segmentRenderMode.selectedSegment = 2
            
        default:
            if(shaderList.contains{ $0.kernalName == renderer.currentShader!.kernalName}){
                segmentRenderMode.selectedSegment = 3
            }else{
                Dialog.showDialog(message: "Shader: \(renderer.currentShader!.functionLabel) (\(renderer.currentShader!.kernalName)) was not found. \n Instead, the preset shader will be used.")
                                  
                renderer.currentShader = ShaderManage.getPresetList()[AppConfig.DEFAULT_SHADER_NO]
                segmentRenderMode.selectedSegment = AppConfig.DEFAULT_SHADER_NO
                
            }
        }
        
        // update views
        toneCh1.setControlPoint(array: params.controlPoints[0])
        toneCh2.setControlPoint(array: params.controlPoints[1])
        toneCh3.setControlPoint(array: params.controlPoints[2])
        toneCh4.setControlPoint(array: params.controlPoints[3])
        
        // Set Interpolate Mode for Control points (0 = Linear, 1 = Spline)
        if let interpolateMode = params.controlPointsInterpolateMode{
            toneCh1.interpolateMode = CubicSplineInterpolator.InterpolateMode(rawValue: interpolateMode[0])!
            toneCh2.interpolateMode = CubicSplineInterpolator.InterpolateMode(rawValue: interpolateMode[1])!
            toneCh3.interpolateMode = CubicSplineInterpolator.InterpolateMode(rawValue: interpolateMode[2])!
            toneCh4.interpolateMode = CubicSplineInterpolator.InterpolateMode(rawValue: interpolateMode[3])!
        }else{
            Logger.logPrintAndWrite(message: "Interpolate Mode is not defined", level:.info)
        }
        
        wellCh1.color =  NSColor.color(from: params.toneColors[0])
        wellCh2.color =  NSColor.color(from: params.toneColors[1])
        wellCh3.color =  NSColor.color(from: params.toneColors[2])
        wellCh4.color =  NSColor.color(from: params.toneColors[3])
        
        // Change the control color for Tone Curve View
        toneCh1.setDefaultBackgroundColor(color: wellCh1.color)
        toneCh2.setDefaultBackgroundColor(color: wellCh2.color)
        toneCh3.setDefaultBackgroundColor(color: wellCh3.color)
        toneCh4.setDefaultBackgroundColor(color: wellCh4.color)
        
        transferTone(sender: toneCh1, targetGPUbuffer: &renderer.toneBuffer_ch1, index: 0)
        transferTone(sender: toneCh2, targetGPUbuffer: &renderer.toneBuffer_ch2, index: 1)
        transferTone(sender: toneCh3, targetGPUbuffer: &renderer.toneBuffer_ch3, index: 2)
        transferTone(sender: toneCh4, targetGPUbuffer: &renderer.toneBuffer_ch4, index: 3)
 
        // update sliders
        updateSliceAndScaleFromParams(params: params.renderParams)
        
        
        
        let eular = quatToEulerAngles(params.quaternion) * 180.0 / PI
        eularX.floatValue = eular.z
        eularY.floatValue = eular.x
        eularZ.floatValue = eular.y
        
        let normals = params.quaternion.act(float3(0, 0, 1))
        normalVecField.stringValue = "Normal Vector: \(normals.stringValue)"
        normalVecField.sizeToFit()
        
        intensityRatio_slider_1.floatValue = renderer.renderParams.intensityRatio[0]
        intensityRatio_slider_2.floatValue = renderer.renderParams.intensityRatio[1]
        intensityRatio_slider_3.floatValue = renderer.renderParams.intensityRatio[2]
        intensityRatio_slider_4.floatValue = renderer.renderParams.intensityRatio[3]
        
        
        changeSwitchFromValue(object: switch_interpolation, option: renderer.renderOption, element: .SAMPLER_LINEAR)
        changeSwitchFromValue(object: switch_shade, option: renderer.renderOption, element: .SHADE)
        changeSwitchFromValue(object: switch_cropLock, option: renderer.renderOption, element: .CROP_LOCK)
        changeSwitchFromValue(object: switch_cropOpposite, option: renderer.renderOption, element: .CROP_TOGGLE)
        changeSwitchFromValue(object: switch_plane, option: renderer.renderOption, element: .PLANE)
        changeSwitchFromValue(object: switch_flip, option: renderer.renderOption, element: .FLIP)
        changeSwitchFromValue(object: switch_boundingBox, option: renderer.renderOption, element: .BOX)
        changeCheckButtonFromValue(object: check_adaptive, option: renderer.renderOption, element: .ADAPTIVE)
        
        popUpViewSize.selectItem(withTitle: String(renderer.renderParams.viewSize))
        popUpAlphaPower.selectItem(withTitle: "x\(renderer.renderParams.alphaPower)")
        
        pointSetTable.reloadData()
        
        if (renderer.pointClouds.pointSet.count > 0){
            removeAllButton.isEnabled = true
        }else{
            removeAllButton.isEnabled = false
        }
        
        
        renderer.resetMetalFunctions()
        renderer.argumentManager = nil
        outputView.image = renderer.rendering()
        
        
        let prevDisplayRanges = renderer.imageParams.displayRanges
        
        if(params.imageParams != nil){
            renderer.imageParams = params.imageParams!
            xResolutionField.floatValue = renderer.imageParams.scaleX
            yResolutionField.floatValue = renderer.imageParams.scaleY
            zResolutionField.floatValue = renderer.imageParams.scaleZ
            scaleUnitField.stringValue = renderer.imageParams.unit
            scalebarLengthField.integerValue = renderer.imageParams.scalebarLength
            scaleFontSizeSlider.floatValue = renderer.imageParams.scaleFontSize
        }
   
        
        Logger.log(message: "Current ranges: \(prevDisplayRanges)")
        if let dr = params.imageParams?.displayRanges {
            Logger.log(message: "Loaded ranges: \(dr)")
        }
        
        
        // if display ranges are different from loaded params
        // reload images with saved ranges
        
        if(prevDisplayRanges != params.imageParams!.displayRanges){
            let alert = NSAlert()
            alert.alertStyle = .critical
            alert.messageText = "Saved display ranges are different from the current ranges."
            alert.addButton(withTitle: "Use the saved ranges")
            alert.addButton(withTitle: "Keep the current ranges")
            
            let response = alert.runModal()
            if(response == .alertFirstButtonReturn){
                renderer.imageParams.displayRanges = params.imageParams!.displayRanges
                make3D(self)
            }
        }
        
    }
    
}
