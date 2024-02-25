//
//  menuActions.swift
//  Acto3D
//
//  Created by Naoki Takeshita on 2023/06/28.
//

import Foundation
import Cocoa

extension ViewController{
    @IBAction func menuAction(_ sender : NSMenuItem){
        
        switch sender.identifier?.rawValue {
        case "performanceTest":
            
            var startTime = Date()
            startTime = Date()
            
         
            
            let n = 200
            
            
            for _ in 0...(n-1) {
                _ = renderer.rendering()
            }
            
            let elapsed =  (Date().timeIntervalSince(startTime) * 1000 / Double(n))
            let elapsedString = String(format: "%.3f", elapsed)
            
            Logger.log(message: "Performace Test x50 avg = \(elapsedString) ms", writeToLogfile: true)
            
            
        case "showUserDefaults":
            guard let bundleIdentifier = Bundle.main.bundleIdentifier else {
                fatalError("Couldn't find bundle identifier.")
            }
            let preferencesDirectoryURL = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!.appendingPathComponent("Preferences")
            print(preferencesDirectoryURL)
            let plistFileName = "\(bundleIdentifier).plist"
            let plistFileURL = preferencesDirectoryURL.appendingPathComponent(plistFileName)

            print(plistFileURL)
            
            var isDir:ObjCBool  = false
            if FileManager.default.fileExists(atPath: plistFileURL.path, isDirectory: &isDir) {
                NSWorkspace.shared.activateFileViewerSelecting([plistFileURL])
            }
            

            
        case "resetSecureScope":
            UserDefaults.standard.removeObject(forKey: "PermanentFolderBookmarks")
            
        case "resetRecent":
            UserDefaults.standard.removeObject(forKey: "Recent")
            recentFiles = []
            
        case "gaussian":
            applyGaussian3D()
            
        case "median":
            applyMedian3D()
            
        case "otsu_binarization":
            applyBinarization_Otsu()
            
        case "binarization":
            applyBinarization()
            
        case "otsu_binarization_slicebyslice":
            applyBinarization_Otsu_SliceBySlice()
            
        case "export_to_tiff":
            let useChannel = sender.tag
            
            print(useChannel)
            
            guard let filePackage = filePackage else {return}
            
            renderer.exportToTiffForEachChannel(useChannel: useChannel, filePackage: filePackage)
            
        case "export_currentangle":
            let useChannel = sender.tag
            
            print(useChannel)
            
            guard let filePackage = filePackage else {return}
            
            renderer.exportToTiffForEachChannelWithCurrentAngleAndSize(useChannel: useChannel, filePackage: filePackage)
            
        case "re-compile":
            do{
                try shaderReCompile()
            }catch{
                print("ERROR:", error)
            }
            
        case "open_shader_dir":
            guard let customShadersURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent("Shader") else {
                return
            }
            do {
                try FileManager.default.createDirectory(at: customShadersURL, withIntermediateDirectories: true, attributes: nil)
            } catch {
            }
            
//            let appURL = Bundle.main.bundleURL
//            let shadersURL = appURL.appendingPathComponent("Contents").appendingPathComponent("Resources").appendingPathComponent("Shader")
//
//
            var isDir:ObjCBool  = false

            if FileManager.default.fileExists(atPath: customShadersURL.path, isDirectory: &isDir) {
                NSWorkspace.shared.activateFileViewerSelecting([customShadersURL])
            }
            
            
        case "showLogs":
            Logger.showLogDirectory()
            
        case "performance_test_item":
            Logger.logPrintAndWrite(message: "Performance check")
            
            let max = 2<<(8-1) - 1
            self.renderer.imageParams.displayRanges = [[Double]](repeating: [0, max.toDouble()], count: 4)
            self.renderer.imageParams.scaleX = 1
            self.renderer.imageParams.scaleY = 1
            self.renderer.imageParams.scaleZ = 1
            
            self.renderer.renderParams.zScale = 1
            
            var volumeData = VolumeData()
            

            if(sender.tag == -1){
                // perform test
//                self.renderer.bench(repeatCount: 10)
                DispatchQueue.global().async { [weak self] in
                    self?.renderer.bench2(repeatCount: 1000, random_rotate: false) {(complete) in
                        
                        DispatchQueue.main.async {
                            Logger.logPrintAndWrite(message: "Performance test finished.")
                            self?.renderer.mainTexture = nil
                        }
                    }
                }
                
                return
            }
            
            /*
             512 x 512 x 500  (0.49 GB)
             960 x 960 x 500  (1.72 GB)
             1024 x 1024 x 500  (1.95 GB)
             1280 x 1280 x 500  (3.05 GB)
             1536 x 1536 x 500  (4.39 GB)
             1920 x 1920 x 500  (6.87 GB)
             1920 x 1920 x 750  (10.3 GB)
             1920 x 1920 x 1000  (13.73 GB)
             */
            let xy_size = [480, 720, 960, 1200, 1440, 1680, 1920]
            let z_size = [900, 900, 900, 900, 900, 900, 900]
            let ind = sender.tag
            
            volumeData.inputImageWidth = xy_size[ind].toUInt16()
            volumeData.inputImageDepth = z_size[ind].toUInt16()
            volumeData.inputImageHeight = volumeData.inputImageWidth
            volumeData.numberOfComponent = 4
            
            Logger.logPrintAndWrite(message: "Performance test: size = \(xy_size[ind]) x \(xy_size[ind]) x \(z_size[ind]) pixels x 4 channel")
            
            self.renderer.volumeData = volumeData
//            self.renderer.renderParams.viewSize = 512
            self.renderer.renderParams.viewSize = 512
            popUpViewSize.selectedItem!.title = String( 512)
            self.scale_Slider.floatValue = 512.0 / volumeData.inputImageWidth.toFloat()
//            self.scale_Slider.floatValue = 1.0
            
            
            guard let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
                return
            }
            
            filePackage = FilePackage(fileDir: docDir, fileType: .multiFileStacks, fileList: [String](repeating: "test", count: volumeData.inputImageDepth.toInt()))
            guard let filePackage = filePackage else {
                return
            }
            
            benchmark_test_create3D(filePackage: filePackage)
            
        case "debug_mode":
            AppConfig.IS_DEBUG_MODE = !AppConfig.IS_DEBUG_MODE
            
        case "preview_size":
            AppConfig.PREVIEW_SIZE = sender.tag.toUInt16()
            
        case "high_quality_size":
            AppConfig.HQ_SIZE = sender.tag.toUInt16()
            
        case "accept_tcp":
            AppConfig.ACCEPT_TCP_CONNECTION = !AppConfig.ACCEPT_TCP_CONNECTION
            
        case "create_mp4":
            let dialog = NSOpenPanel();
            dialog.title                   = "Choose Images";
            dialog.showsResizeIndicator    = true;
            dialog.showsHiddenFiles        = false;
            dialog.canChooseDirectories    = false;
            dialog.canCreateDirectories    = true;
            dialog.allowsMultipleSelection = true;
//            dialog.allowedFileTypes        = ["tif", "tiff", "jpg", "jpeg", "png"];
            dialog.allowedContentTypes     = [.tiff, .jpeg, .png]
            
            
            let accessoryView = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 40))
            let textField = NSTextField(string: "FPS")
            textField.isBezeled = false
            textField.drawsBackground = false
            textField.isEditable = false
            textField.isSelectable = false
            textField.sizeToFit()
            textField.setFrameOrigin(NSPoint(x: 0, y: (40 - textField.frame.height) / 2))
            accessoryView.addSubview(textField)
            
            let fpspopup = NSPopUpButton()
            fpspopup.addItem(withTitle: "30")
            fpspopup.addItem(withTitle: "60")
            fpspopup.setFrameSize(NSSize(width: 100, height: 30))
            fpspopup.sizeToFit()
            fpspopup.setFrameOrigin(NSPoint(x: textField.frame.maxX + 10, y: (40 - fpspopup.frame.height) / 2 ))
            
            accessoryView.addSubview(fpspopup)
            
            if (dialog.runModal() ==  NSApplication.ModalResponse.OK) {
                let result = dialog.urls
                
                let savePanel = NSSavePanel()
                savePanel.title = "Save the movie"
//                savePanel.allowedFileTypes = [ "mp4"]
                savePanel.allowedContentTypes = [.mpeg4Movie]
                
                savePanel.accessoryView = accessoryView
                
                
                if savePanel.runModal() == NSApplication.ModalResponse.OK {
                    if let saveURL = savePanel.url {
                        guard let sampleImage = NSImage(contentsOf: result[0])?.toCGImage else{
                            Dialog.showDialog(message: "Invalid format")
                            return
                        }
                        let width = sampleImage.width, height = sampleImage.height
                        
                        let movCreator = MovieCreator(withFps: Int(fpspopup.titleOfSelectedItem!)!, size: NSSize(width: width.toCGFloat(), height: height.toCGFloat()))
                        movCreator.createMovie(from: result, exportFileUrl: saveURL)
                    
                    }
                }
                
            }else{
                return
            }
            
            
        case "open_file_directory":
            guard let filePackage = filePackage else {return}
            
            var isDir:ObjCBool  = false
            
            if filePackage.fileType == .multiFileStacks{
                if FileManager.default.fileExists(atPath: filePackage.fileDir.path, isDirectory: &isDir) {
                    NSWorkspace.shared.activateFileViewerSelecting([filePackage.fileDir])
                }
            }else if filePackage.fileType == .singleFileMultiPage{
                if FileManager.default.fileExists(atPath: filePackage.fileDir.path, isDirectory: &isDir) {
                    NSWorkspace.shared.activateFileViewerSelecting([filePackage.fileDir.appendingPathComponent(filePackage.fileList[0])])
                }
            }
        
        case "open_working_directory":
            guard let workingDirUrl = filePackage?.workingDir else {return}
            NSWorkspace.shared.activateFileViewerSelecting([workingDirUrl])
            
        case "copy_sample_shaders":
            copySampleShadersToShaderDirectory()
        
        case "tori":
            // creation of tori model
            if let _ = renderer.mainTexture {
                if !closeCurrentSession(){
                    return
                }
            }
            
            
            let demoTori = DemoModel(device: renderer.device, lib: renderer.mtlLibrary, cmdQueue: renderer.cmdQueue)
            
            guard let texture = demoTori.createDemoModel_tori(imgWidth: 500, imgHeight: 500, radius1: 150, radius2: 30, lineWidth: 5, inside_color: 0, outside_color: 120, edge_color: 240),
                  let tori_texture = demoTori.gaussian2D(inTexture: texture, k_size: 7, inChannel: 0, outChannel: 1) else{
                Logger.logPrintAndWrite(message: "Failed to create demo model (tori).")
                return
            }
            
            
            renderer.mainTexture = tori_texture
            
            renderer.volumeData = VolumeData(outputImageWidth: texture.width.toUInt16(), outputImageHeight: texture.height.toUInt16(),
                                             inputImageWidth: texture.width.toUInt16(), inputImageHeight: texture.height.toUInt16(), inputImageDepth: texture.depth.toUInt16(), numberOfComponent: 4)
            
            renderer.imageParams = ImageParameters()
            
            renderer.renderParams = RenderingParameters()
            zScale_Slider.floatValue = 1.0
            renderer.renderParams.zScale = 1
            updateSliceAndScale(currentSliceToMax: true)
            
            setDefaultDisplayRanges(bit: 8, channelCount: 4)
            
            self.xResolutionField.floatValue = self.renderer.imageParams.scaleX
            self.yResolutionField.floatValue = self.renderer.imageParams.scaleY
            self.zResolutionField.floatValue = self.renderer.imageParams.scaleZ
            self.scaleUnitField.stringValue = self.renderer.imageParams.unit
            
            
            toneCh1.setControlPoint(array: [[0,0], [130,0], [255,1]], redraw: true)
            toneCh1.interpolateMode = .cubicSpline
            toneCh2.setControlPoint(array: [[0,0], [130,0], [255,1]], redraw: true)
            toneCh2.interpolateMode = .cubicSpline
            
            
            renderer.renderOption.changeValue(option: .SAMPLER_LINEAR, value: 1)
            renderer.renderOption.changeValue(option: .SHADE, value: 0)
            renderer.renderOption.changeValue(option: .CROP_LOCK, value: 0)
            renderer.renderOption.changeValue(option: .CROP_TOGGLE, value: 0)
            renderer.renderOption.changeValue(option: .PLANE, value: 0)
            renderer.renderOption.changeValue(option: .FLIP, value: 0)
            renderer.renderOption.changeValue(option: .ADAPTIVE, value: 0)
            
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
            
            renderer.pointClouds = PointClouds()
            pointSetTable.reloadData()
            
            
            renderer.resetMetalFunctions()
            renderer.argumentManager = nil
            
            renderer.renderParams.sliceNo = renderer.renderParams.sliceMax
            renderer.renderParams.renderingStep = 1.0
            renderer.renderParams.scale = 0.8
            
            renderer.renderParams.intensityRatio = float4(0.2, 1, 0, 0)
            
            updateSliceAndScaleFromParams(params: renderer.renderParams)
            
            
            renderer.currentShader = ShaderManage.getPresetList()[0]
            segmentRenderMode.selectedSegment = 0
            
            transferTone(sender: toneCh1, targetGPUbuffer: &renderer.toneBuffer_ch1, index: 0)
            transferTone(sender: toneCh2, targetGPUbuffer: &renderer.toneBuffer_ch2, index: 1)
            transferTone(sender: toneCh3, targetGPUbuffer: &renderer.toneBuffer_ch3, index: 2)
            transferTone(sender: toneCh4, targetGPUbuffer: &renderer.toneBuffer_ch4, index: 3)
            
            rotateModel(deltaAxisX: -18, deltaAxisY: -20, deltaAxisZ: -3, performRendering: false)
            
            self.outputView.image = self.renderer.rendering()
            
            
            
            guard let documentToriDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent("DemoModel") else {
                return
            }
            do {
                try FileManager.default.createDirectory(at: documentToriDir.appendingPathComponent("Tori"), withIntermediateDirectories: true, attributes: nil)
            } catch {
            }
            
            filePackage = FilePackage(fileDir: documentToriDir, fileType: .singleFileMultiPage, fileList: ["Tori.tif"])
            filePackage?.isSafeDir = true
            pathField.stringValue = documentToriDir.path
            
            Logger.logPrintAndWrite(message: "⭐️ This model contains 2 channels.")
            Logger.logPrintAndWrite(message: "   The original image is stored in channel 1.")
            Logger.logPrintAndWrite(message: "   The model with the blur applied is stored in channel 2.")
            Logger.logPrintAndWrite(message: "🔔 You can export this model in [File] > [Export].")
            
            
        case "sphereincube":
            // creation of sphereincube
            if let _ = renderer.mainTexture {
                if !closeCurrentSession(){
                    return
                }
            }
            
            
            let demoSp = DemoModel(device: renderer.device, lib: renderer.mtlLibrary, cmdQueue: renderer.cmdQueue)
            
            guard let texture = demoSp.createDemoModel_sphereincube(imgWidth: 768, imgHeight: 768, ball_size: 256, square_size: 350),
                    let sp_texture = demoSp.gaussian2D(inTexture: texture, k_size: 7, inChannel: -1, outChannel: -1) else{
                Logger.logPrintAndWrite(message: "Failed to create demo model.")
                return
            }
            
            
            renderer.mainTexture = sp_texture
            
            renderer.volumeData = VolumeData(outputImageWidth: texture.width.toUInt16(), outputImageHeight: texture.height.toUInt16(),
                                             inputImageWidth: texture.width.toUInt16(), inputImageHeight: texture.height.toUInt16(), inputImageDepth: texture.depth.toUInt16(), numberOfComponent: 4)
            
            renderer.imageParams = ImageParameters()
            
            renderer.renderParams = RenderingParameters()
            zScale_Slider.floatValue = 1.0
            renderer.renderParams.zScale = 1
            updateSliceAndScale(currentSliceToMax: true)
            
            setDefaultDisplayRanges(bit: 8, channelCount: 4)
            
            self.xResolutionField.floatValue = self.renderer.imageParams.scaleX
            self.yResolutionField.floatValue = self.renderer.imageParams.scaleY
            self.zResolutionField.floatValue = self.renderer.imageParams.scaleZ
            self.scaleUnitField.stringValue = self.renderer.imageParams.unit
            
            
            toneCh1.setControlPoint(array: [[0,0], [50,0], [100, 0.2], [180, 0] ,[255,0.3]], redraw: true)
            toneCh1.interpolateMode = .cubicSpline
            toneCh2.setControlPoint(array: [[0,0], [50,0], [100, 0.2], [180, 0] ,[255,0.3]], redraw: true)
            toneCh2.interpolateMode = .cubicSpline
            toneCh3.setControlPoint(array: [[0,0], [50,0], [100, 0.2], [180, 0], [255,0.3]], redraw: true)
            toneCh3.interpolateMode = .cubicSpline
            toneCh4.setControlPoint(array: [[0,0], [50,0], [100, 0.2], [180, 0] ,[255,0.3]], redraw: true)
            toneCh4.interpolateMode = .cubicSpline
            
            
            renderer.renderOption.changeValue(option: .SAMPLER_LINEAR, value: 1)
            renderer.renderOption.changeValue(option: .SHADE, value: 0)
            renderer.renderOption.changeValue(option: .CROP_LOCK, value: 0)
            renderer.renderOption.changeValue(option: .CROP_TOGGLE, value: 0)
            renderer.renderOption.changeValue(option: .PLANE, value: 0)
            renderer.renderOption.changeValue(option: .FLIP, value: 0)
            renderer.renderOption.changeValue(option: .ADAPTIVE, value: 0)
            
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
            
            renderer.pointClouds = PointClouds()
            pointSetTable.reloadData()
            
            
            renderer.resetMetalFunctions()
            renderer.argumentManager = nil
            
            renderer.renderParams.sliceNo = renderer.renderParams.sliceMax
            renderer.renderParams.renderingStep = 1.0
            renderer.renderParams.scale = 0.4
            
            renderer.renderParams.intensityRatio = float4(1,1,1,1)
            
            renderer.renderParams.color = PackedColor(ch1_color: float4(hex: "ED703A"), ch2_color: float4(hex: "8AF513"), ch3_color: float4(hex: "8BAEF5"), ch4_color: float4(hex: "FFFFFF"))
            
            wellCh1.color =  NSColor.color(from: renderer.renderParams.color.ch1_color)
            wellCh2.color =  NSColor.color(from: renderer.renderParams.color.ch2_color)
            wellCh3.color =  NSColor.color(from: renderer.renderParams.color.ch3_color)
            wellCh4.color =  NSColor.color(from: renderer.renderParams.color.ch4_color)
            
            // Change the control color for Tone Curve View
            toneCh1.setDefaultBackgroundColor(color: wellCh1.color)
            toneCh2.setDefaultBackgroundColor(color: wellCh2.color)
            toneCh3.setDefaultBackgroundColor(color: wellCh3.color)
            toneCh4.setDefaultBackgroundColor(color: wellCh4.color)
            
            
            
            updateSliceAndScaleFromParams(params: renderer.renderParams)
            
            
            renderer.currentShader = ShaderManage.getPresetList()[0]
            segmentRenderMode.selectedSegment = 0
            
            transferTone(sender: toneCh1, targetGPUbuffer: &renderer.toneBuffer_ch1, index: 0)
            transferTone(sender: toneCh2, targetGPUbuffer: &renderer.toneBuffer_ch2, index: 1)
            transferTone(sender: toneCh3, targetGPUbuffer: &renderer.toneBuffer_ch3, index: 2)
            transferTone(sender: toneCh4, targetGPUbuffer: &renderer.toneBuffer_ch4, index: 3)
            
            rotateModel(deltaAxisX: -18, deltaAxisY: -20, deltaAxisZ: -3, performRendering: false)
            
            self.outputView.image = self.renderer.rendering()
            
            
            
            guard let documentDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent("DemoModel") else {
                return
            }
            do {
                try FileManager.default.createDirectory(at: documentDir.appendingPathComponent("SphereInCube"), withIntermediateDirectories: true, attributes: nil)
            } catch {
            }
            
            filePackage = FilePackage(fileDir: documentDir, fileType: .singleFileMultiPage, fileList: ["SphereInCube.tif"])
            filePackage?.isSafeDir = true
            pathField.stringValue = documentDir.path
            
            Logger.logPrintAndWrite(message: "⭐️ This model contains 4 channels.")
            Logger.logPrintAndWrite(message: "🔔 You can export this model in [File] > [Export].")
            
        case "thin_lumen":
            // creation of thin_lumen
            if let _ = renderer.mainTexture {
                if !closeCurrentSession(){
                    return
                }
            }
            
            let thinModelParams = getParametersOfThinModel()
            if(thinModelParams.sigma == 0 || thinModelParams.coefficient == 0 || thinModelParams.kernelSize == 0 || thinModelParams.radius == 0){
                return
            }
            
            let demo = DemoModel(device: renderer.device, lib: renderer.mtlLibrary, cmdQueue: renderer.cmdQueue)
            
            guard let texture = demo.createDemoModel_thin_lumen(imgWidth: 100, imgHeight: 100, innerRadius: thinModelParams.radius, coefficient: thinModelParams.coefficient, lineWidth: 3, inside_color: 1, outside_color: 1, edge_color: 1) else{
                Logger.logPrintAndWrite(message: "Failed to create demo model.")
                return
            }
            
            let processor = ImageProcessor(device: renderer.device, cmdQueue: renderer.cmdQueue, lib: renderer.mtlLibrary)
            
            DispatchQueue.global().async {
                processor.applyFilter_Gaussian3D(inTexture: texture, k_size: thinModelParams.kernelSize.toUInt8(), sigma: thinModelParams.sigma, channel: 0) { result in
                    
                    DispatchQueue.main.async {[self] in
                    ImageProcessor.transferTextureToTexture(device: self.renderer.device,
                                                            cmdQueue: self.renderer.cmdQueue,
                                                            lib: self.renderer.mtlLibrary,
                                                            texIn: result!,
                                                            texOut: texture,
                                                            channelIn: 0, channelOut: 1)
                    
                    
                        
                        renderer.mainTexture = texture
                        
                        
                        renderer.volumeData = VolumeData(outputImageWidth: texture.width.toUInt16(), outputImageHeight: texture.height.toUInt16(),
                                                         inputImageWidth: texture.width.toUInt16(), inputImageHeight: texture.height.toUInt16(), inputImageDepth: texture.depth.toUInt16(), numberOfComponent: 4)
                        
                        renderer.imageParams = ImageParameters()
                        
                        renderer.renderParams = RenderingParameters()
                        zScale_Slider.floatValue = 1.0
                        renderer.renderParams.zScale = 1
                        updateSliceAndScale(currentSliceToMax: true)
                        
                        setDefaultDisplayRanges(bit: 8, channelCount: 4)
                        
                        self.xResolutionField.floatValue = self.renderer.imageParams.scaleX
                        self.yResolutionField.floatValue = self.renderer.imageParams.scaleY
                        self.zResolutionField.floatValue = self.renderer.imageParams.scaleZ
                        self.scaleUnitField.stringValue = self.renderer.imageParams.unit
                        
                        
                        toneCh1.setControlPoint(array: [[0,0], [73,0], [150, 0.0] ,[255,0.3]], redraw: true)
                        toneCh1.interpolateMode = .cubicSpline
                        toneCh2.setControlPoint(array: [[0,0], [73,0], [150, 0.1] ,[255,0.3]], redraw: true)
                        toneCh2.interpolateMode = .cubicSpline
                        toneCh3.setControlPoint(array: [[0,0], [255,0.3]], redraw: true)
                        toneCh3.interpolateMode = .cubicSpline
                        toneCh4.setControlPoint(array: [[0,0],[255,0.3]], redraw: true)
                        toneCh4.interpolateMode = .cubicSpline
                        
                        
                        renderer.renderOption.changeValue(option: .SAMPLER_LINEAR, value: 1)
                        renderer.renderOption.changeValue(option: .SHADE, value: 0)
                        renderer.renderOption.changeValue(option: .CROP_LOCK, value: 0)
                        renderer.renderOption.changeValue(option: .CROP_TOGGLE, value: 0)
                        renderer.renderOption.changeValue(option: .PLANE, value: 0)
                        renderer.renderOption.changeValue(option: .FLIP, value: 0)
                        renderer.renderOption.changeValue(option: .ADAPTIVE, value: 0)
                        
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
                        
                        renderer.pointClouds = PointClouds()
                        pointSetTable.reloadData()
                        
                        
                        renderer.resetMetalFunctions()
                        renderer.argumentManager = nil
                        
                        renderer.renderParams.sliceNo = renderer.renderParams.sliceMax
                        renderer.renderParams.renderingStep = 1.0
                        renderer.renderParams.scale = 0.8
                        
                        renderer.renderParams.intensityRatio = float4(0,1,1,1)
                        
                        renderer.renderParams.color = PackedColor(ch1_color: float4(hex: "FFFFFF"), ch2_color: float4(hex: "FFFFFF"), ch3_color: float4(hex: "FFFFFF"), ch4_color: float4(hex: "FFFFFF"))
                        
                        wellCh1.color =  NSColor.color(from: renderer.renderParams.color.ch1_color)
                        wellCh2.color =  NSColor.color(from: renderer.renderParams.color.ch2_color)
                        wellCh3.color =  NSColor.color(from: renderer.renderParams.color.ch3_color)
                        wellCh4.color =  NSColor.color(from: renderer.renderParams.color.ch4_color)
                        
                        // Change the control color for Tone Curve View
                        toneCh1.setDefaultBackgroundColor(color: wellCh1.color)
                        toneCh2.setDefaultBackgroundColor(color: wellCh2.color)
                        toneCh3.setDefaultBackgroundColor(color: wellCh3.color)
                        toneCh4.setDefaultBackgroundColor(color: wellCh4.color)
                        
                        
                        
                        updateSliceAndScaleFromParams(params: renderer.renderParams)
                        
                        
                        renderer.currentShader = ShaderManage.getPresetList()[0]
                        segmentRenderMode.selectedSegment = 0
                        
                        transferTone(sender: toneCh1, targetGPUbuffer: &renderer.toneBuffer_ch1, index: 0)
                        transferTone(sender: toneCh2, targetGPUbuffer: &renderer.toneBuffer_ch2, index: 1)
                        transferTone(sender: toneCh3, targetGPUbuffer: &renderer.toneBuffer_ch3, index: 2)
                        transferTone(sender: toneCh4, targetGPUbuffer: &renderer.toneBuffer_ch4, index: 3)
                        
                        rotateModel(deltaAxisX: -118, deltaAxisY: -90, deltaAxisZ: -60, performRendering: false)
                        
                        self.outputView.image = self.renderer.rendering()
                        
                        let demoName = "ThinLumen_coef\(thinModelParams.coefficient)_radius\(thinModelParams.radius)_k\(thinModelParams.kernelSize)_sigma\(thinModelParams.sigma)"
                        
                        
                        
                        guard let documentDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent("DemoModel") else {
                            return
                        }
                        do {
                            try FileManager.default.createDirectory(at: documentDir.appendingPathComponent(demoName), withIntermediateDirectories: true, attributes: nil)
                        } catch {
                        }
                        
                        filePackage = FilePackage(fileDir: documentDir, fileType: .singleFileMultiPage, fileList: ["\(demoName).tif"])
                        filePackage?.isSafeDir = true
                        pathField.stringValue = documentDir.path
                        
                        Logger.logPrintAndWrite(message: "⭐️ Thin lumen model was created with the following parameters.")
                        Logger.logPrintAndWrite(message: "   Thinnest radius: \(thinModelParams.radius), Coefficient: \(thinModelParams.coefficient)")
                        Logger.logPrintAndWrite(message: "   Kernel size for gaussian blur: \(thinModelParams.kernelSize), Sigma for gaussian blur: \(thinModelParams.sigma)")
                        Logger.logPrintAndWrite(message: "⭐️ This model contains 2 channel.")
                        Logger.logPrintAndWrite(message: "   The original image is stored in channel 1. The blurd model for segmentation in stored in channel 2.")
                        Logger.logPrintAndWrite(message: "🔔 You can export this model in [File] > [Export].")
                    }
                }
                
                print("B")
                
            }
            
        default:
            break
        }
        
    }
    
    
}
