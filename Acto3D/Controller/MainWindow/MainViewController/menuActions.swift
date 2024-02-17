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
            
        default:
            break
        }
        
    }
    
    
}
