//
//  VC_ImageFilter.swift
//  Acto3D
//
//  Created by Naoki Takeshita on 2024/02/17.
//

import Foundation
import Cocoa

extension ViewController{
    
    @objc func imageProcessSendCancel(_ sender: ImageProcessorCancelButton) {
        print("Send Cancel message")
        sender.processor?.interruptProcess()
    }
    
    // スイッチのアクションを処理するメソッド
    @objc func thresholdSliderAction(_ sender: NSSlider) {
        
    }
    
    internal func applyGaussian3D(){
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
                            ImageProcessor.transferTextureToTexture(device: self.renderer.device,
                                                                    cmdQueue: self.renderer.cmdQueue,
                                                                    lib: self.renderer.mtlLibrary,
                                                                    texIn: result!,
                                                                    texOut: self.renderer.mainTexture!,
                                                                    channelIn: 0, channelOut: targetChannel.toUInt8())
                            
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
    }
    
    internal func applyMedian3D(){
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
                            ImageProcessor.transferTextureToTexture(device: self.renderer.device,
                                                                    cmdQueue: self.renderer.cmdQueue,
                                                                    lib: self.renderer.mtlLibrary,
                                                                    texIn: result!,
                                                                    texOut: self.renderer.mainTexture!,
                                                                    channelIn: 0, channelOut: targetChannel.toUInt8())
                            
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
    }
    
    internal func applyBinarization_Otsu(){
        
            //MARK: Otsu_binarization
            guard let mainTexture = renderer.mainTexture else{
                Dialog.showDialog(message: "No images")
                return
            }
            
            let alert = NSAlert()
            alert.messageText = "Apply Otsu threshold"
            alert.informativeText = "Specify the target channels"
            
            
            // Create a label for kernel size
            let label = NSTextField(frame: NSRect(x: 0, y: 0, width: 100, height: 24))
            label.stringValue = "Which channel image would you like to binarize?"
            label.isBezeled = false
            label.drawsBackground = false
            label.isEditable = false
            label.isSelectable = false
            label.alignment = .center
            label.sizeToFit()
            
            let label2 = NSTextField(frame: NSRect(x: 0, y: 0, width: 100, height: 24))
            label2.stringValue = "Which channel would you like to write to?"
            label2.isBezeled = false
            label2.drawsBackground = false
            label2.isEditable = false
            label2.isSelectable = false
            label2.alignment = .center
            label2.sizeToFit()
            
            let label3 = NSTextField(frame: NSRect(x: 0, y: 0, width: 100, height: 24))
            label3.stringValue = "Would you like to invert black and white?"
            label3.isBezeled = false
            label3.drawsBackground = false
            label3.isEditable = false
            label3.isSelectable = false
            label3.alignment = .center
            label3.sizeToFit()
            
            let label4 = NSTextField(frame: NSRect(x: 0, y: 0, width: 100, height: 24))
            label4.stringValue = "If 'On', pixels with values \nhigher than the threshold will be black."
            label4.isBezeled = false
            label4.drawsBackground = false
            label4.isEditable = false
            label4.isSelectable = false
            label4.alignment = .center
            label4.sizeToFit()
            
            let segment_input = NSSegmentedControl(labels: ["Channel 1", "Channel 2", "Channel 3", "Channel 4"], trackingMode: .selectOne, target: nil, action: nil)
            segment_input.segmentStyle = .rounded
            segment_input.alignment = .center
            segment_input.sizeToFit()
            segment_input.selectedSegment = 0
            
            let segment_output = NSSegmentedControl(labels: ["Channel 1", "Channel 2", "Channel 3", "Channel 4"], trackingMode: .selectOne, target: nil, action: nil)
            segment_output.segmentStyle = .rounded
            segment_output.alignment = .center
            segment_output.sizeToFit()
            segment_output.selectedSegment = 0
            
            let switch_invert = NSSwitch(frame: NSRect(x: 0, y: 0, width: 20, height: 20))
            switch_invert.integerValue = 0
            switch_invert.sizeToFit()
            
            

            let accessoryWidth:CGFloat = 300
            let accessoryHeight:CGFloat = 250
            let accessory = NSView(frame: NSRect(x: 0, y: 0, width: accessoryWidth, height: accessoryHeight))
            
            label.setFrameOrigin(NSPoint(x: (accessoryWidth - label.frame.width) / 2.0, y: accessoryHeight - label.frame.height))
            segment_input.setFrameOrigin(NSPoint(x: (accessoryWidth - segment_input.frame.width) / 2.0, y: label.frame.minY - segment_input.frame.height - 10))
            label2.setFrameOrigin(NSPoint(x: (accessoryWidth - label2.frame.width) / 2.0, y: segment_input.frame.minY - label2.frame.height - 20))
            segment_output.setFrameOrigin(NSPoint(x: (accessoryWidth - segment_output.frame.width) / 2.0, y: label2.frame.minY - segment_output.frame.height - 10))
            
            label3.setFrameOrigin(NSPoint(x: (accessoryWidth - label3.frame.width) / 2.0, y: segment_output.frame.minY - label3.frame.height - 20))
            switch_invert.setFrameOrigin(NSPoint(x: (accessoryWidth - switch_invert.frame.width) / 2.0, y: label3.frame.minY - switch_invert.frame.height - 5))
            label4.setFrameOrigin(NSPoint(x: (accessoryWidth - label4.frame.width) / 2.0, y: switch_invert.frame.minY - label4.frame.height - 5))
            
            accessory.addSubview(label)
            accessory.addSubview(segment_input)
            accessory.addSubview(label2)
            accessory.addSubview(segment_output)
            accessory.addSubview(label3)
            accessory.addSubview(switch_invert)
            accessory.addSubview(label4)

            alert.accessoryView = accessory
            
            
            alert.addButton(withTitle: "Apply")
            alert.addButton(withTitle: "Cancel")
            
            let modalResult = alert.runModal()
            let firstButtonNo = NSApplication.ModalResponse.alertFirstButtonReturn.rawValue
            
            switch modalResult.rawValue {
            case firstButtonNo:
                print("Apply")
                
            case firstButtonNo + 1:
                print("Cancel")
                return
                
            default:
                return
            }
            
            
            
            var channelHistogram:[UInt32]?
            
            // re-caluculate histogram
            renderer.calculateTextureHistogram()
            
            switch segment_input.selectedSegment {
            case 0:
                channelHistogram = toneCh1.histogram
            case 1:
                channelHistogram = toneCh2.histogram
            case 2:
                channelHistogram = toneCh3.histogram
            case 3:
                channelHistogram = toneCh4.histogram
            default:
                channelHistogram = nil
            }
            
            let inChannel = segment_input.selectedSegment
            let outChannel = segment_output.selectedSegment
            let invert:Bool = switch_invert.integerValue == 0 ? false : true
            
            guard let channelHistogram = channelHistogram else {
                Dialog.showDialogWithDebug(message: "Error in creating histograms")
                return
                
            }
            
            
            let processor = ImageProcessor(device: renderer.device, cmdQueue: renderer.cmdQueue, lib: renderer.mtlLibrary)
            
            let threshold = processor.calculateThreshold_Otsu(histogram: channelHistogram, totalPixels: mainTexture.width * mainTexture.height * mainTexture.depth)
            
            
            
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
                
                
                processor.applyFilter_binarizationWithThreshold(inTexture: mainTexture, threshold: threshold, channel: inChannel, invert: invert) { result in
                    
                    DispatchQueue.main.async {
                        if(processor.isCanceled() == false){
                            ImageProcessor.transferTextureToTexture(device: self.renderer.device,
                                                                    cmdQueue: self.renderer.cmdQueue,
                                                                    lib: self.renderer.mtlLibrary,
                                                                    texIn: result!,
                                                                    texOut: self.renderer.mainTexture!,
                                                                    channelIn: 0, channelOut: outChannel.toUInt8())
                            
                            
                            let renderedImage = self.renderer.rendering()
                            self.outputView.image = renderedImage
                            
                        }
                        
                        inProgress = false
                        overlayView.removeFromSuperview()
                        
                        Dialog.showDialog(message: "Calculated threshold: \(threshold)", title: "Otsu's binarization", style: .informational, level: .info)
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
            
    }
    
    internal func applyBinarization(){
        
            //MARK: Normal_binarization
            guard let mainTexture = renderer.mainTexture else{
                Dialog.showDialog(message: "No images")
                return
            }
            
            let alert = NSAlert()
            alert.messageText = "Apply threshold"
            alert.informativeText = "Specify the target channels"
            
            
            // Create a label for kernel size
            let label = NSTextField(frame: NSRect(x: 0, y: 0, width: 100, height: 24))
            label.stringValue = "Which channel image would you like to binarize?"
            label.isBezeled = false
            label.drawsBackground = false
            label.isEditable = false
            label.isSelectable = false
            label.alignment = .center
            label.sizeToFit()
            
            let label2 = NSTextField(frame: NSRect(x: 0, y: 0, width: 100, height: 24))
            label2.stringValue = "Which channel would you like to write to?"
            label2.isBezeled = false
            label2.drawsBackground = false
            label2.isEditable = false
            label2.isSelectable = false
            label2.alignment = .center
            label2.sizeToFit()
            
            let label3 = NSTextField(frame: NSRect(x: 0, y: 0, width: 100, height: 24))
            label3.stringValue = "Would you like to invert black and white?"
            label3.isBezeled = false
            label3.drawsBackground = false
            label3.isEditable = false
            label3.isSelectable = false
            label3.alignment = .center
            label3.sizeToFit()
            
            let label4 = NSTextField(frame: NSRect(x: 0, y: 0, width: 100, height: 24))
            label4.stringValue = "If 'On', pixels with values \nhigher than the threshold will be black."
            label4.isBezeled = false
            label4.drawsBackground = false
            label4.isEditable = false
            label4.isSelectable = false
            label4.alignment = .center
            label4.sizeToFit()
            
            let segment_input = NSSegmentedControl(labels: ["Channel 1", "Channel 2", "Channel 3", "Channel 4"], trackingMode: .selectOne, target: nil, action: nil)
            segment_input.segmentStyle = .rounded
            segment_input.alignment = .center
            segment_input.sizeToFit()
            segment_input.selectedSegment = 0
            
            let segment_output = NSSegmentedControl(labels: ["Channel 1", "Channel 2", "Channel 3", "Channel 4"], trackingMode: .selectOne, target: nil, action: nil)
            segment_output.segmentStyle = .rounded
            segment_output.alignment = .center
            segment_output.sizeToFit()
            segment_output.selectedSegment = 0
            
            let switch_invert = NSSwitch(frame: NSRect(x: 0, y: 0, width: 20, height: 20))
            switch_invert.integerValue = 0
            switch_invert.sizeToFit()
            
            let slider = NSSlider(value: 128, minValue: 0, maxValue: 255, target: nil, action: nil)
            slider.setFrameSize(NSSize(width: 150, height: slider.frame.height))
            
            let label5 = NSTextField(frame: NSRect(x: 0, y: 0, width: 100, height: 24))
            label5.stringValue = "128"
            label5.isBezeled = false
            label5.drawsBackground = false
            label5.isEditable = false
            label5.isSelectable = false
            label5.alignment = .left
            label5.sizeToFit()
            label5.setFrameSize(NSSize(width: 100, height: label5.frame.height))
            
            slider.target = label5
            slider.action = #selector(NSTextField.takeIntValueFrom(_:))
            

            let accessoryWidth:CGFloat = 300
            let accessoryHeight:CGFloat = 300
            let accessory = NSView(frame: NSRect(x: 0, y: 0, width: accessoryWidth, height: accessoryHeight))
            
            label.setFrameOrigin(NSPoint(x: (accessoryWidth - label.frame.width) / 2.0, y: accessoryHeight - label.frame.height))
            segment_input.setFrameOrigin(NSPoint(x: (accessoryWidth - segment_input.frame.width) / 2.0, y: label.frame.minY - segment_input.frame.height - 10))
            label2.setFrameOrigin(NSPoint(x: (accessoryWidth - label2.frame.width) / 2.0, y: segment_input.frame.minY - label2.frame.height - 20))
            segment_output.setFrameOrigin(NSPoint(x: (accessoryWidth - segment_output.frame.width) / 2.0, y: label2.frame.minY - segment_output.frame.height - 10))
            
            label3.setFrameOrigin(NSPoint(x: (accessoryWidth - label3.frame.width) / 2.0, y: segment_output.frame.minY - label3.frame.height - 20))
            switch_invert.setFrameOrigin(NSPoint(x: (accessoryWidth - switch_invert.frame.width) / 2.0, y: label3.frame.minY - switch_invert.frame.height - 5))
            label4.setFrameOrigin(NSPoint(x: (accessoryWidth - label4.frame.width) / 2.0, y: switch_invert.frame.minY - label4.frame.height - 5))
            
            slider.setFrameOrigin(NSPoint(x: (accessoryWidth - slider.frame.width) / 2.0, y: label4.frame.minY - slider.frame.height - 20))
            label5.setFrameOrigin(NSPoint(x: (accessoryWidth - slider.frame.width) / 2.0 + slider.frame.width + 10, y: (slider.frame.height - label5.frame.height) / 2 + slider.frame.minY))
            
            accessory.addSubview(label)
            accessory.addSubview(segment_input)
            accessory.addSubview(label2)
            accessory.addSubview(segment_output)
            accessory.addSubview(label3)
            accessory.addSubview(switch_invert)
            accessory.addSubview(label4)
            accessory.addSubview(slider)
            accessory.addSubview(label5)

            alert.accessoryView = accessory
            
            
            alert.addButton(withTitle: "Apply")
            alert.addButton(withTitle: "Cancel")
            
            let modalResult = alert.runModal()
            let firstButtonNo = NSApplication.ModalResponse.alertFirstButtonReturn.rawValue
            
            switch modalResult.rawValue {
            case firstButtonNo:
                print("Apply")
                
            case firstButtonNo + 1:
                print("Cancel")
                return
                
            default:
                return
            }
            
            
            
            let inChannel = segment_input.selectedSegment
            let outChannel = segment_output.selectedSegment
            let invert:Bool = switch_invert.integerValue == 0 ? false : true
            let threshold = slider.integerValue.toUInt8()
            
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
                
                
                processor.applyFilter_binarizationWithThreshold(inTexture: mainTexture, threshold: threshold, channel: inChannel, invert: invert) { result in
                    
                    DispatchQueue.main.async {
                        if(processor.isCanceled() == false){
                            ImageProcessor.transferTextureToTexture(device: self.renderer.device,
                                                                    cmdQueue: self.renderer.cmdQueue,
                                                                    lib: self.renderer.mtlLibrary,
                                                                    texIn: result!,
                                                                    texOut: self.renderer.mainTexture!,
                                                                    channelIn: 0, channelOut: outChannel.toUInt8())
                            
                            
                            let renderedImage = self.renderer.rendering()
                            self.outputView.image = renderedImage
                            
                        }
                        
                        inProgress = false
                        overlayView.removeFromSuperview()
                        
                        Dialog.showDialog(message: "Used threshold: \(threshold)", title: "Otsu's binarization", style: .informational, level: .info)
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
            
    }
    
    internal func applyBinarization_Otsu_SliceBySlice(){
        
            //MARK: Otsu_binarization
            guard let mainTexture = renderer.mainTexture else{
                Dialog.showDialog(message: "No images")
                return
            }
            
            let alert = NSAlert()
            alert.messageText = "Apply Otsu threshold (Slice by Slice)"
            alert.informativeText = "Specify the target channels"
            
            
            // Create a label for kernel size
            let label = NSTextField(frame: NSRect(x: 0, y: 0, width: 100, height: 24))
            label.stringValue = "Which channel image would you like to binarize?"
            label.isBezeled = false
            label.drawsBackground = false
            label.isEditable = false
            label.isSelectable = false
            label.alignment = .center
            label.sizeToFit()
            
            let label2 = NSTextField(frame: NSRect(x: 0, y: 0, width: 100, height: 24))
            label2.stringValue = "Which channel would you like to write to?"
            label2.isBezeled = false
            label2.drawsBackground = false
            label2.isEditable = false
            label2.isSelectable = false
            label2.alignment = .center
            label2.sizeToFit()
            
            let label3 = NSTextField(frame: NSRect(x: 0, y: 0, width: 100, height: 24))
            label3.stringValue = "Would you like to invert black and white?"
            label3.isBezeled = false
            label3.drawsBackground = false
            label3.isEditable = false
            label3.isSelectable = false
            label3.alignment = .center
            label3.sizeToFit()
            
            let label4 = NSTextField(frame: NSRect(x: 0, y: 0, width: 100, height: 24))
            label4.stringValue = "If 'On', pixels with values \nhigher than the threshold will be black."
            label4.isBezeled = false
            label4.drawsBackground = false
            label4.isEditable = false
            label4.isSelectable = false
            label4.alignment = .center
            label4.sizeToFit()
            
            let segment_input = NSSegmentedControl(labels: ["Channel 1", "Channel 2", "Channel 3", "Channel 4"], trackingMode: .selectOne, target: nil, action: nil)
            segment_input.segmentStyle = .rounded
            segment_input.alignment = .center
            segment_input.sizeToFit()
            segment_input.selectedSegment = 0
            
            let segment_output = NSSegmentedControl(labels: ["Channel 1", "Channel 2", "Channel 3", "Channel 4"], trackingMode: .selectOne, target: nil, action: nil)
            segment_output.segmentStyle = .rounded
            segment_output.alignment = .center
            segment_output.sizeToFit()
            segment_output.selectedSegment = 0
            
            let switch_invert = NSSwitch(frame: NSRect(x: 0, y: 0, width: 20, height: 20))
            switch_invert.integerValue = 0
            switch_invert.sizeToFit()
            
            

            let accessoryWidth:CGFloat = 300
            let accessoryHeight:CGFloat = 250
            let accessory = NSView(frame: NSRect(x: 0, y: 0, width: accessoryWidth, height: accessoryHeight))
            
            label.setFrameOrigin(NSPoint(x: (accessoryWidth - label.frame.width) / 2.0, y: accessoryHeight - label.frame.height))
            segment_input.setFrameOrigin(NSPoint(x: (accessoryWidth - segment_input.frame.width) / 2.0, y: label.frame.minY - segment_input.frame.height - 10))
            label2.setFrameOrigin(NSPoint(x: (accessoryWidth - label2.frame.width) / 2.0, y: segment_input.frame.minY - label2.frame.height - 20))
            segment_output.setFrameOrigin(NSPoint(x: (accessoryWidth - segment_output.frame.width) / 2.0, y: label2.frame.minY - segment_output.frame.height - 10))
            
            label3.setFrameOrigin(NSPoint(x: (accessoryWidth - label3.frame.width) / 2.0, y: segment_output.frame.minY - label3.frame.height - 20))
            switch_invert.setFrameOrigin(NSPoint(x: (accessoryWidth - switch_invert.frame.width) / 2.0, y: label3.frame.minY - switch_invert.frame.height - 5))
            label4.setFrameOrigin(NSPoint(x: (accessoryWidth - label4.frame.width) / 2.0, y: switch_invert.frame.minY - label4.frame.height - 5))
            
            accessory.addSubview(label)
            accessory.addSubview(segment_input)
            accessory.addSubview(label2)
            accessory.addSubview(segment_output)
            accessory.addSubview(label3)
            accessory.addSubview(switch_invert)
            accessory.addSubview(label4)

            alert.accessoryView = accessory
            
            
            alert.addButton(withTitle: "Apply")
            alert.addButton(withTitle: "Cancel")
            
            let modalResult = alert.runModal()
            let firstButtonNo = NSApplication.ModalResponse.alertFirstButtonReturn.rawValue
            
            switch modalResult.rawValue {
            case firstButtonNo:
                print("Apply")
                
            case firstButtonNo + 1:
                print("Cancel")
                return
                
            default:
                return
            }
            
            
            let inChannel = segment_input.selectedSegment
            let outChannel = segment_output.selectedSegment
            let invert:Bool = switch_invert.integerValue == 0 ? false : true
            
            
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
           
                processor.applyFilter_calculateHistogramSliceBySlice(inTexture: mainTexture, channel: inChannel, invert: invert){ result in
                    
                    DispatchQueue.main.async {
                        if(processor.isCanceled() == false){
                            ImageProcessor.transferTextureToTexture(device: self.renderer.device,
                                                                    cmdQueue: self.renderer.cmdQueue,
                                                                    lib: self.renderer.mtlLibrary,
                                                                    texIn: result!,
                                                                    texOut: self.renderer.mainTexture!,
                                                                    channelIn: 0, channelOut: outChannel.toUInt8())
                            
                            
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
            
            
            
            
            
            
            
            
            
    }
    
}
