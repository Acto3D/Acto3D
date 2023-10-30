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
            //MARK: gaussian 3d
            guard let mainTexture = renderer.mainTexture else{
                Dialog.showDialog(message: "No images")
                return
            }
            let alert = NSAlert()
            alert.messageText = "Apply 3D Gaussian filter"
            alert.informativeText = "Specify the parameters and target channels"
            alert.addButton(withTitle: "All channel")
            alert.addButton(withTitle: "Channel 1")
            alert.addButton(withTitle: "Channel 2")
            alert.addButton(withTitle: "Channel 3")
            alert.addButton(withTitle: "Channel 4")
            alert.addButton(withTitle: "Cancel")

            // Create a label for kernel size
            let label = NSTextField(frame: NSRect(x: 0, y: 0, width: 100, height: 24))
            label.stringValue = "Kernel Size:"
            label.isBezeled = false
            label.drawsBackground = false
            label.isEditable = false
            label.isSelectable = false
            label.alignment = .right
            label.sizeToFit()
            
            // Add a text field and a stepper for kernel size
            let textField = NSTextField(frame: NSRect(x: label.frame.maxX + 5, y: 0, width: 40, height: 24))
            let stepper = NSStepper(frame: NSRect(x: textField.frame.maxX + 5, y: 0, width: 20, height: 24))
            let defaultValue = 5
            textField.integerValue = defaultValue
            textField.alignment = .center
            stepper.minValue = 3
            stepper.maxValue = 15
            stepper.increment = 2
            stepper.integerValue = defaultValue
            stepper.target = textField
            stepper.action = #selector(NSTextField.takeIntValueFrom(_:))


            // Create a label for sigma
            let sigmaLabel = NSTextField(frame: NSRect(x: stepper.frame.maxX + 15, y: 0, width: 100, height: 24))
            sigmaLabel.stringValue = "Sigma:"
            sigmaLabel.isBezeled = false
            sigmaLabel.drawsBackground = false
            sigmaLabel.isEditable = false
            sigmaLabel.isSelectable = false
            sigmaLabel.alignment = .right
            sigmaLabel.sizeToFit()
            
            // Add a text field and a stepper for sigma
            let sigmaField = NSTextField(frame: NSRect(x: sigmaLabel.frame.maxX + 5, y: 0, width: 40, height: 24))
            let sigmaStepper = NSStepper(frame: NSRect(x: sigmaField.frame.maxX + 5, y: 0, width: 20, height: 24))
            let sigmaDefaultValue = 1.8
            sigmaField.doubleValue = sigmaDefaultValue
            sigmaField.alignment = .center
            sigmaStepper.minValue = 0.1
            sigmaStepper.maxValue = 30.0
            sigmaStepper.increment = 0.1
            sigmaStepper.doubleValue = sigmaDefaultValue
            sigmaStepper.target = sigmaField
            sigmaStepper.action = #selector(NSTextField.takeDoubleValueFrom(_:))


            let accessory = NSView(frame: NSRect(x: 0, y: 0, width: sigmaStepper.frame.maxX, height: 24))
            
            label.setFrameOrigin(NSPoint(x: label.frame.minX, y: label.frame.minY - (24.0 / 2.0 - label.frame.height - 2.0)))
            sigmaLabel.setFrameOrigin(NSPoint(x: sigmaLabel.frame.minX, y: sigmaLabel.frame.minY - (24.0 / 2.0 - sigmaLabel.frame.height - 2.0)))
            
            accessory.addSubview(label)
            accessory.addSubview(textField)
            accessory.addSubview(stepper)
            accessory.addSubview(sigmaLabel)
            accessory.addSubview(sigmaField)
            accessory.addSubview(sigmaStepper)

            alert.accessoryView = accessory
            
            let modalResult = alert.runModal()
            let firstButtonNo = NSApplication.ModalResponse.alertFirstButtonReturn.rawValue
            
            guard let ksize = Int(textField.stringValue) else{
                Dialog.showDialog(message: "Invalid kernel size: \(textField.stringValue)\nThe kernel size must be an odd integer.")
                return
            }
            
            guard let sigma = Float(sigmaField.stringValue) else{
                Dialog.showDialog(message: "Invalid sigma value: \(sigmaField.stringValue).")
                return
            }
            
            var targetChannel = -1
            
            switch modalResult.rawValue {
            case firstButtonNo:
                print("All channel")
                targetChannel = -1
                
            case firstButtonNo + 1:
                print("Channel 1")
                targetChannel = 0
                
            case firstButtonNo + 2:
                print("Channel 1")
                targetChannel = 1
                
            case firstButtonNo + 3:
                print("Channel 1")
                targetChannel = 2
                
            case firstButtonNo + 4:
                print("Channel 1")
                targetChannel = 3
                
            case firstButtonNo + 5:
                print("Cancel")
                return
                
            default:
                return
            }
            
            
            let processor = ImageProcessor(device: renderer.device, cmdQueue: renderer.cmdQueue, lib: renderer.mtlLibrary)
            
            var inProgress = true
            
            
            let contentView = self.view
            
            let overlayView = NonClickableNSView(frame: contentView.frame)
            overlayView.wantsLayer = true
            overlayView.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.7).cgColor
            
            
            let progressIndicator = NSProgressIndicator(frame: NSRect(x: 0, y: 0, width: 160, height: 40))
            progressIndicator.style = .bar
            progressIndicator.minValue = 0
            progressIndicator.maxValue = 100
            progressIndicator.doubleValue = 0 // Set the current progress
            progressIndicator.isIndeterminate = false
            progressIndicator.frame.origin.x = (contentView.frame.width - progressIndicator.frame.width) / 2
            progressIndicator.frame.origin.y = (contentView.frame.height - progressIndicator.frame.height) / 2
            

            
            let button = ImageProcessorCancelButton(title: "Cancel", target: nil, action: nil)
            button.bezelStyle = .rounded
            button.wantsLayer = true
            button.sizeToFit()
            button.action = #selector(imageProcessSendCancel(_:))
            button.processor = processor
            
            
            button.frame.origin.x = (contentView.frame.width - button.frame.width) / 2
            button.frame.origin.y = (contentView.frame.height - button.frame.height) / 2 - progressIndicator.bounds.height - 10
        
            button.layer?.backgroundColor = CGColor.clear
            
            
            overlayView.addSubview(progressIndicator)
            contentView.addSubview(overlayView, positioned: .above, relativeTo: nil)
            overlayView.addSubview(button)
            
            
            DispatchQueue.global().async {
                processor.applyFilter_Gaussian3D(inTexture: mainTexture, k_size: ksize.toUInt8(), sigma: sigma, channel: targetChannel) { result in
                   
                    DispatchQueue.main.async {
                        if(processor.isCanceled() == false){
                            if (targetChannel == -1){
                                self.renderer.mainTexture = result
                            }else{
                                ImageProcessor.transferChannelToTexture(device: self.renderer.device, cmdQueue:  self.renderer.cmdQueue, lib:  self.renderer.mtlLibrary, inTexture: result!, dstTexture:  self.renderer.mainTexture!, dstChannel: targetChannel.toUInt8())
                            }
                            let renderedImage = self.renderer.rendering()
                            self.outputView.image = renderedImage
                            
                        }
                        
                        inProgress = false
                        overlayView.removeFromSuperview()
                    }
                }
                
                while(inProgress){
                    let progress = processor.getProcessState()
                    
                    DispatchQueue.main.async {
                        progressIndicator.doubleValue = progress.percentage
                        
                    }
                    usleep(400)
                }
            }
            
        case "median":
            //MARK: median 3d
            guard let mainTexture = renderer.mainTexture else{
                Dialog.showDialog(message: "No images")
                return
            }
            let alert = NSAlert()
            alert.messageText = "Apply 3D Median filter"
            alert.informativeText = "Specify the parameters and target channels"
            alert.addButton(withTitle: "All channel")
            alert.addButton(withTitle: "Channel 1")
            alert.addButton(withTitle: "Channel 2")
            alert.addButton(withTitle: "Channel 3")
            alert.addButton(withTitle: "Channel 4")
            alert.addButton(withTitle: "Cancel")

            // Create a label for kernel size
            let label = NSTextField(frame: NSRect(x: 0, y: 0, width: 100, height: 24))
            label.stringValue = "Kernel Size:"
            label.isBezeled = false
            label.drawsBackground = false
            label.isEditable = false
            label.isSelectable = false
            label.alignment = .right
            label.sizeToFit()
            
            // Add a text field and a stepper for kernel size
            let textField = NSTextField(frame: NSRect(x: label.frame.maxX + 5, y: 0, width: 40, height: 24))
            let stepper = NSStepper(frame: NSRect(x: textField.frame.maxX + 5, y: 0, width: 20, height: 24))
            let defaultValue = 3
            textField.integerValue = defaultValue
            textField.alignment = .center
            stepper.minValue = 3
            stepper.maxValue = 7
            stepper.increment = 2
            stepper.integerValue = defaultValue
            stepper.target = textField
            stepper.action = #selector(NSTextField.takeIntValueFrom(_:))



            let accessory = NSView(frame: NSRect(x: 0, y: 0, width: stepper.frame.maxX, height: 24))
            
            label.setFrameOrigin(NSPoint(x: label.frame.minX, y: label.frame.minY - (24.0 / 2.0 - label.frame.height - 2.0)))
            label.setFrameOrigin(NSPoint(x: label.frame.minX, y: label.frame.minY - (24.0 / 2.0 - label.frame.height - 2.0)))
            
            accessory.addSubview(label)
            accessory.addSubview(textField)
            accessory.addSubview(stepper)

            alert.accessoryView = accessory
            
            let modalResult = alert.runModal()
            let firstButtonNo = NSApplication.ModalResponse.alertFirstButtonReturn.rawValue
            
            guard let ksize = Int(textField.stringValue) else{
                Dialog.showDialog(message: "Invalid kernel size: \(textField.stringValue)\nThe kernel size must be an odd integer.")
                return
            }
            
            var targetChannel = -1
            
            switch modalResult.rawValue {
            case firstButtonNo:
                print("All channel")
                targetChannel = -1
                
            case firstButtonNo + 1:
                print("Channel 1")
                targetChannel = 0
                
            case firstButtonNo + 2:
                print("Channel 1")
                targetChannel = 1
                
            case firstButtonNo + 3:
                print("Channel 1")
                targetChannel = 2
                
            case firstButtonNo + 4:
                print("Channel 1")
                targetChannel = 3
                
            case firstButtonNo + 5:
                print("Cancel")
                return
                
            default:
                return
            }
            
            
            
            let processor = ImageProcessor(device: renderer.device, cmdQueue: renderer.cmdQueue, lib: renderer.mtlLibrary)
            
            var inProgress = true
            
            
            let contentView = self.view
            
            let overlayView = NonClickableNSView(frame: contentView.frame)
            overlayView.wantsLayer = true
            overlayView.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.7).cgColor
            
            
            let progressIndicator = NSProgressIndicator(frame: NSRect(x: 0, y: 0, width: 160, height: 40))
            progressIndicator.style = .bar
            progressIndicator.minValue = 0
            progressIndicator.maxValue = 100
            progressIndicator.doubleValue = 0 // Set the current progress
            progressIndicator.isIndeterminate = false
            progressIndicator.frame.origin.x = (contentView.frame.width - progressIndicator.frame.width) / 2
            progressIndicator.frame.origin.y = (contentView.frame.height - progressIndicator.frame.height) / 2
            
            
            let button = ImageProcessorCancelButton(title: "Cancel", target: nil, action: nil)
            button.bezelStyle = .rounded
            button.wantsLayer = true
            button.sizeToFit()
            button.action = #selector(imageProcessSendCancel(_:))
            button.processor = processor
            
            
            button.frame.origin.x = (contentView.frame.width - button.frame.width) / 2
            button.frame.origin.y = (contentView.frame.height - button.frame.height) / 2 - progressIndicator.bounds.height - 10
        
            button.layer?.backgroundColor = CGColor.clear
            
            
            overlayView.addSubview(progressIndicator)
            contentView.addSubview(overlayView, positioned: .above, relativeTo: nil)
            overlayView.addSubview(button)
            
            
            DispatchQueue.global().async {
                
                
                processor.applyFilter_Median3D_QuickSelect(inTexture: mainTexture, k_size: ksize.toUInt8(), channel: targetChannel) { result in
                    
                     DispatchQueue.main.async {
                         if(processor.isCanceled() == false){
                             if (targetChannel == -1){
                                 self.renderer.mainTexture = result
                             }else{
                                 ImageProcessor.transferChannelToTexture(device:  self.renderer.device, cmdQueue:  self.renderer.cmdQueue, lib:  self.renderer.mtlLibrary, inTexture: result!, dstTexture:  self.renderer.mainTexture!, dstChannel: targetChannel.toUInt8())
                             }
                             let renderedImage = self.renderer.rendering()
                             self.outputView.image = renderedImage
                             
                         }
                         
                         inProgress = false
                         overlayView.removeFromSuperview()
                     }
                }
                
                
                
                while(inProgress){
                    let progress = processor.getProcessState()
                    
                    DispatchQueue.main.async {
                        progressIndicator.doubleValue = progress.percentage
                        
                    }
                    usleep(400)
                }
            }
            
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
            dialog.allowedFileTypes        = ["tif", "tiff", "jpg", "jpeg", "png"];
            
            if (dialog.runModal() ==  NSApplication.ModalResponse.OK) {
                let result = dialog.urls
                
                let savePanel = NSSavePanel()
                savePanel.title = "Save the movie"
                savePanel.allowedFileTypes = ["mp4"]
                
                if savePanel.runModal() == NSApplication.ModalResponse.OK {
                    if let saveURL = savePanel.url {
                        guard let sampleImage = NSImage(contentsOf: result[0])?.toCGImage else{
                            Dialog.showDialog(message: "Invalid format")
                            return
                        }
                        let width = sampleImage.width, height = sampleImage.height
                        
                        let movCreator = MovieCreator(withFps: 30, size: NSSize(width: width.toCGFloat(), height: height.toCGFloat()))
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
            
        case "copy_preset_shaders":
            let appURL = Bundle.main.bundleURL
            let mainShadersURL = appURL.appendingPathComponent("Contents").appendingPathComponent("Resources").appendingPathComponent("Shader").appendingPathComponent("Custom")
            
            // get custom shader dir
            guard let customShadersURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent("Shader").appendingPathComponent("Preset") else {
                Logger.logPrintAndWrite(message: "Could not obtein shader directory")
                return
            }
            do {
                try FileManager.default.createDirectory(at: customShadersURL, withIntermediateDirectories: true, attributes: nil)
            } catch {
                Logger.logPrintAndWrite(message: "Error in creating custom shader directory", level: .error)
                return
            }
            
            guard let mainShadersFiles = try? FileManager.default.contentsOfDirectory(at: mainShadersURL,
                                                                               includingPropertiesForKeys: nil,
                                                                               options: .skipsHiddenFiles)
            else{
                Logger.logPrintAndWrite(message: "could not obtein files in: \(mainShadersURL.path)")
                return
            }
            
            let metalFiles = mainShadersFiles.filter{$0.pathExtension == "metal"}
            if(metalFiles.count == 0){
                Logger.logPrintAndWrite(message: "no metal files in :\(mainShadersURL.path)")
                return
            }
            
            var overwriteAll = false
            
            for fileURL in metalFiles {
                let destinationURL = customShadersURL.appendingPathComponent(fileURL.lastPathComponent)
                if FileManager.default.fileExists(atPath: destinationURL.path){
                    if (overwriteAll){
                        // first, delete the existing file
                        do{
                            try FileManager.default.removeItem(at: destinationURL)
                            Logger.logPrintAndWrite(message: "delete existing shader file: \(destinationURL.path)")
                        }catch{
                            Logger.log(message: "error in overwrite \(destinationURL)")
                        }
                        
                    }else{
                        let alert = NSAlert()
                        alert.messageText = "Would you like to overwrite the existing file?"
                        alert.informativeText = "\(destinationURL.path) already exists."
                        alert.addButton(withTitle: "Overwrite")
                        alert.addButton(withTitle: "Skip")
                        alert.addButton(withTitle: "Overwrite All")
                        let response = alert.runModal()

                        switch response {
                        case .alertFirstButtonReturn:  // User chose to overwrite
                            do{
                                try FileManager.default.removeItem(at: destinationURL)
                                Logger.logPrintAndWrite(message: "delete existing shader file: \(destinationURL.path)")
                            }catch{
                                Logger.logPrintAndWrite(message: "error in handling file:\(destinationURL.path)")
                            }
                            
                        case .alertSecondButtonReturn:  // User chose to skip
                            Logger.logPrintAndWrite(message: "skip shader file: \(destinationURL.path)")
                            continue
                            
                        case .alertThirdButtonReturn:  // User chose to overwrite all
                            overwriteAll = true
                            do{
                                try FileManager.default.removeItem(at: destinationURL)
                                Logger.logPrintAndWrite(message: "delete existing shader file: \(destinationURL.path)")
                            }catch{
                                Logger.logPrintAndWrite(message: "error in handling file:\(destinationURL.path)")
                            }
                            
                        default:
                            break
                        }
                    }
                }
                do{
                    try FileManager.default.copyItem(at: fileURL, to: destinationURL)
                    Logger.logPrintAndWrite(message: "copy shader file: \(destinationURL.path)")
                }catch{
                    Logger.logPrintAndWrite(message: "error in handling file:\(destinationURL.path)")
                }
            }
            NSWorkspace.shared.activateFileViewerSelecting([customShadersURL])
            
        default:
            break
        }
        
    }
    
    
    @objc func imageProcessSendCancel(_ sender: ImageProcessorCancelButton) {
        print("Send Cancel message")
        sender.processor?.interruptProcess()
    }
    
}
