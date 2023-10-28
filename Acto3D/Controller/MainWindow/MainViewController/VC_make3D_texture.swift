//
//  VC+make3Dtex.swift
//  Acto3D
//
//  Created by Naoki Takeshita on 2022/01/19.
//

import Foundation
import Cocoa
import Metal
import simd

import Accelerate.vImage

extension ViewController{
    
    @IBAction func make3D(_ sender: Any) {
        guard let filePackage = filePackage else {
            return
        }
        
        if (filePackage.fileType == .singleFileMultiPage){
            make3Dtexture_from_ImageJ_tiff(filePackage: filePackage){success in
                if(success == true){
                    self.updateViewAfterTextureLoad()
                }
                DispatchQueue.main.async {
                    self.progressBar.isHidden = true
                    self.progressBar.doubleValue = 0
                }
            }
            
        }else if (filePackage.fileType == .multiFileStacks){
            make3Dtexture_from_ImageStacks(filePackage: filePackage){success in
                if(success == true){
                    self.updateViewAfterTextureLoad()
                }
                DispatchQueue.main.async {
                    self.progressBar.isHidden = true
                    self.progressBar.doubleValue = 0
                }
            }
            
        }else{
        }
    }
    
    func updateViewAfterTextureLoad() {
        self.renderer.createMtlFunctionForRendering()
        self.renderer.createMtlPipelineForRendering()
        
        DispatchQueue.main.sync {[self] in
            self.zScale_Slider.floatValue = self.renderer.renderParams.zScale
            self.updateSliceAndScale(currentSliceToMax: true)
                

            self.xResolutionField.floatValue = self.renderer.imageParams.scaleX
            self.yResolutionField.floatValue = self.renderer.imageParams.scaleY
            self.zResolutionField.floatValue = self.renderer.imageParams.scaleZ
            self.scaleUnitField.stringValue = self.renderer.imageParams.unit

            if(self.renderer.imageParams.textureLoadChannel != 4){
                self.intensityRatio_slider_4.floatValue = 0
                self.renderer.renderParams.intensityRatio[3] = 0
                self.toneCh4.setControlPoint(array: [[0,0], [255,0]], redraw: true)
            }
                
            self.outputView.image = self.renderer.rendering()
                
            self.renderer.calculateTextureHistogram()
        }
    }

    
    // MARK: -
    // MARK: Image Stacks
    /// Create 3D textures from a sequence of image files
    internal func make3Dtexture_from_ImageStacks(filePackage: FilePackage, completion: @escaping (Bool) -> Void){
        // Load the first image and determine some parameters
        
        Logger.logPrintAndWrite(message: "Start to load directory: \(filePackage.fileDir.path)")
        
        let firstImageUrl = filePackage.fileDir.appendingPathComponent(filePackage.fileList[0])
        guard let img = NSImage(contentsOf: firstImageUrl),
              let tiffData = img.tiffRepresentation,
              let imgRep:NSBitmapImageRep = NSBitmapImageRep(data: tiffData)
        else{
            Dialog.showDialog(message: "Invalid image format")
            completion(false)
            return
        }
        
        // When extracting ByteData from an Image, the behavior differs between JPG, PNG, and TIFF.
        // For a 24-bit image, while JPG and PNG are converted to 32 bits, TIFF can be processed as 24 bits.
        // This is believed to be because the conversion process from NSImage to Data internally goes through a TIFF conversion.
        var needBitsAdjust = false
        
        // Need for bits adjust
        // There's a difference in bit representation when converting through tiffRepresentation compared to converting via cgImage.
        // It's essential to compare and determine if any corrections are needed based on this difference.
        if(imgRep.bitsPerPixel == 24 &&
           img.toCGImage.bitsPerPixel == 32){
            needBitsAdjust = true
        }
        
        let imgWidth = imgRep.pixelsWide
        let imgHeight = imgRep.pixelsHigh
        let imgCount = filePackage.fileList.count
        var numberOfComponents = imgRep.bitsPerPixel / imgRep.bitsPerSample
        let bit = imgRep.bitsPerSample.toUInt8()
        
        renderer.volumeData.inputImageWidth = imgRep.pixelsWide.toUInt16()
        renderer.volumeData.inputImageHeight = imgRep.pixelsHigh.toUInt16()
        renderer.volumeData.inputImageDepth = imgCount.toUInt16()
        
        var ranges:[Float] = []
        ranges = self.renderer.imageParams.displayRanges.flatMap{
            $0.map{
                Float($0)
            }
        }
        
        let zScaleRatio = renderer.imageParams.scaleZ / renderer.imageParams.scaleX
        renderer.renderParams.zScale = zScaleRatio
        
        Logger.logPrintAndWrite(message: "Create 3D texture from image stacks.")
        Logger.logPrintAndWrite(message: " Multiple images, \(imgRep.bitsPerPixel) bits/px, \(imgRep.bitsPerSample) bits/channel, \(numberOfComponents) channels")
        
        
        renderer.volumeData.numberOfComponent = 4
        
        // progressbar setting
        progressBar.isHidden = false
        progressBar.maxValue = (imgCount - 1).toDouble()
        progressBar.minValue = 0.0
        progressBar.doubleValue = 0
        self.progressBar.contentFilters = [
            CIFilter(name: "CIHueAdjust", parameters: ["inputAngle": NSNumber(value: 4)])!
        ]
        
        var pxCountPerSlice = imgWidth * imgHeight * numberOfComponents
        if(needBitsAdjust){
            pxCountPerSlice = imgWidth * imgHeight * 4

        }
        
        // texture setting    // texture setting
        renderer.mainTexture = renderer.device.makeTexture(withChannelCount: self.renderer.imageParams.textureLoadChannel!,
                                                           width: self.renderer.volumeData.inputImageWidth.toInt(),
                                                           height: self.renderer.volumeData.inputImageHeight.toInt(),
                                                           depth: self.renderer.volumeData.inputImageDepth.toInt())
        renderer.mainTexture?.label = "Acto3D Texture"
        guard let _ = renderer.mainTexture else{
            Dialog.showDialog(message: "Failed to create texture")
            Logger.logPrintAndWrite(message: "Failed to create texture")
            completion(false)
            return
        }
        Logger.logOnlyToFile(message: "  Created a 3D Texture: \(renderer.mainTexture!)")
        
        
        var renderPipeline:MTLComputePipelineState!
        
        DispatchQueue.global(qos: .userInteractive).async{ [self] in
            for j in (0 ..< imgCount){
                autoreleasepool{
                    let bytesPerPixel = imgRep.bitsPerSample / 8
                    
                    let bufferSizePerSlice = MemoryLayout<UInt8>.stride * pxCountPerSlice * bytesPerPixel
                    let options: MTLResourceOptions = [.storageModeShared, .cpuCacheModeWriteCombined ]
                    
                    
                    guard let cpuBuffer = renderer.device.makeBuffer(length: bufferSizePerSlice, options: options),
                          let gpuBuffer = renderer.device.makeBuffer(length: bufferSizePerSlice, options: .storageModePrivate) else {
                        Logger.logOnlyToFile(message: "  Error in creating CPU or GPU buffers")
                        completion(false)
                        return
                    }
                    
                    let cpuPixels = cpuBuffer.contents().bindMemory(to: UInt8.self, capacity: pxCountPerSlice * bytesPerPixel)
                           
                    // Load single image
                    let imageUrl = filePackage.fileDir.appendingPathComponent(filePackage.fileList[j])
                    guard let img = NSImage(contentsOf: imageUrl)?.toCGImage,
                          let pixelData = img.dataProvider?.data,
                          let data = CFDataGetBytePtr(pixelData) else {
                        Logger.logOnlyToFile(message: "  Error in reading image data")
                        completion(false)
                        return
                    }
                    
//                    guard let img = NSImage(contentsOf: imageUrl),
//                          let tiffData = img.tiffRepresentation,
//                          let data = CFDataGetBytePtr(tiffData as CFData)
//                    else{
//                        Dialog.showDialog(message: "Invalid image format")
//                        return
//                    }
                    
                    
                    // Copy image data to CPU buffer
                    memmove(&cpuPixels[0], data, pxCountPerSlice * bytesPerPixel)
                    
                    guard let commandBuffer = renderer.cmdQueue.makeCommandBuffer(),
                          let blitEncoder = commandBuffer.makeBlitCommandEncoder() else {
                        Logger.logOnlyToFile(message: "  Error in creating command buffer or blit encoder")
                        completion(false)
                        return
                    }
                    
                    blitEncoder.label = "Pixel Data Transfer Encoder"
                    commandBuffer.label = "Pixel Data Transfer Command Buffer"
                    cpuBuffer.label = "CPU Pixel Data Buffer"
                    gpuBuffer.label = "GPU Pixel Data Buffer"
                    
                    // Copy data from CPU buffer to GPU buffer
                    blitEncoder.copy(from: cpuBuffer, sourceOffset: 0, to: gpuBuffer, destinationOffset: 0, size: bufferSizePerSlice)
                    blitEncoder.endEncoding()
                    commandBuffer.commit()
                    
                    // Run Compute Shader to arrange pixel data
                    // Kernel Funciton
                    // 各画像，各チャンネルの値を読み込んで，display rangeで調整してテクスチャへ書き込んでいく
                    guard let arrangeCommandBuffer = renderer.cmdQueue.makeCommandBuffer(),
                          let computeEncoder = arrangeCommandBuffer.makeComputeCommandEncoder(),
                          let computeFunction = renderer.mtlLibrary.makeFunction(name: bit == 8 ? "createTextureFromStacks8bit" : "createTextureFromStacks16bit") else {
                        print("Error in creating compute command buffer or function")
                        Logger.logOnlyToFile(message: "  Error in creating pixel arrangement function")
                        completion(false)
                        return
                    }
                    arrangeCommandBuffer.label = "Arrange Pixel Buffer"
                    computeEncoder.label = "Arrangement Encoder"
                    computeFunction.label = "Arrange Function"
                    
                    if j == 0 {
                        do{
                            renderPipeline = try renderer.device.makeComputePipelineState(function: computeFunction)
                        }catch{
                            Logger.logOnlyToFile(message: "  Error in creating pipeline for pixel arrangement function")
                        }
                            
                    }
                    computeEncoder.setComputePipelineState(renderPipeline)
                    
                    var zPosition = j.toUInt16()
                    
                    // Set resources for the compute shader
                    computeEncoder.setBuffer(gpuBuffer, offset: 0, index: 0)
                    computeEncoder.setBytes(&renderer.volumeData, length: MemoryLayout<VolumeData>.stride, index: 1)
                    computeEncoder.setBytes(&numberOfComponents, length: MemoryLayout<UInt8>.stride, index: 2)
                    computeEncoder.setBytes(&zPosition, length: MemoryLayout<UInt16>.stride, index: 3)
                    computeEncoder.setBytes(&ranges, length: MemoryLayout<Float>.stride * ranges.count, index: 4)
                    computeEncoder.setBytes(&renderer.imageParams.ignoreSaturatedPixels, length: MemoryLayout<simd_uchar4>.stride, index: 5)
                    computeEncoder.setBytes(&needBitsAdjust, length: MemoryLayout<Bool>.stride, index: 6)
                    computeEncoder.setTexture(renderer.mainTexture, index: 0)
                    
                    
                    
                    if(renderer.device.checkNonUniformThreadgroup() == true){
                        let threadGroupSize = MTLSizeMake(renderPipeline.threadExecutionWidth, renderPipeline.maxTotalThreadsPerThreadgroup / renderPipeline.threadExecutionWidth, 1)
                        computeEncoder.dispatchThreads(MTLSize(width: imgWidth, height: imgHeight, depth: 1),
                                                       threadsPerThreadgroup: threadGroupSize)
                        
                    }else{
                        let threadGroupSize = MTLSize(width: renderPipeline.threadExecutionWidth,
                                                      height: renderPipeline.maxTotalThreadsPerThreadgroup / renderPipeline.threadExecutionWidth,
                                                      depth: 1)
                        let threadGroups = MTLSize(width: (imgWidth + threadGroupSize.width - 1) / threadGroupSize.width,
                                                   height: (imgHeight + threadGroupSize.height - 1) / threadGroupSize.height,
                                                   depth: 1)
                        computeEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)
                        
                    }

                    computeEncoder.endEncoding()
                    arrangeCommandBuffer.commit()
                    
                    
                    // Update progress bar
                    DispatchQueue.main.async {[self] in
                        self.progressBar.increment(by: 1)
                    }
                    
                }
            }
            
            completion(true)
        }
        
    }
    
    // MARK: - From ImageJ TIFF
    internal func make3Dtexture_from_ImageJ_tiff(filePackage:FilePackage, completion: @escaping (Bool) -> Void){
        let tiffUrl = filePackage.fileDir.appendingPathComponent(filePackage.fileList[0])
        
        guard let mTiff = MTIFF(fileURL: tiffUrl) else{
            Logger.logPrintAndWrite(message: "Error in loading file: \(tiffUrl.path)", level: .error)
            completion(false)
            return
        }
        
        Logger.logPrintAndWrite(message: "Start to load file: \(tiffUrl.path)")
        
        mTiff.getMetaData()
        
        var imgWidth = mTiff.width
        var imgHeight = mTiff.height
        let imgCount = mTiff.imgCount // Total image counts in tiff file (channel * Depth)
        var numberOfComponents = mTiff.channel
        let imgDepth = imgCount / numberOfComponents  // slice count
        let bit = mTiff.bitsPerSample.toUInt8()
        
        
        renderer.volumeData.inputImageWidth = imgWidth.toUInt16()
        renderer.volumeData.inputImageHeight = imgHeight.toUInt16()
        renderer.volumeData.inputImageDepth = imgDepth.toUInt16()
        
        var ranges:[Float] = []
        
        if self.renderer.imageParams.displayRanges.count != 0{
            ranges = self.renderer.imageParams.displayRanges.flatMap{
                $0.map{
                    Float($0)
                }
            }
            
        }else{
            for _ in 0..<numberOfComponents{
                ranges.append(0.0)
                ranges.append(pow(2.0, Float(bit)) - 1.0)
            }
        }
        
        var zScaleRatio = renderer.imageParams.scaleZ / renderer.imageParams.scaleX
        renderer.renderParams.zScale = zScaleRatio
        
        renderer.volumeData.numberOfComponent = 4
        
        progressBar.isHidden = false
        progressBar.maxValue = (imgCount - 1).toDouble()
        progressBar.minValue = 0.0
        progressBar.doubleValue = 0.0
        self.progressBar.contentFilters = [
            CIFilter(name: "CIHueAdjust", parameters: ["inputAngle": NSNumber(value: 4)])!
        ]
        
        let bench = Benchmark()
        
        bench.start(key: "load images")
        
        
        var pxCountPerSlice = imgWidth * imgHeight * numberOfComponents
        
        
        
        let channel = renderer.imageParams.textureLoadChannel!
        let width = renderer.volumeData.inputImageWidth.toInt()
        let height = renderer.volumeData.inputImageHeight.toInt()
        let depth = renderer.volumeData.inputImageDepth.toInt()
        
        // texture setting
        renderer.mainTexture = renderer.device.makeTexture(withChannelCount: channel,
                                                           width: width,
                                                           height: height,
                                                           depth: depth)
        renderer.mainTexture?.label = "Acto3D Texture"
        
        // if creation of mainTexture failed,
        //  - XYZ dimension check
        //  - buffer check
        
        
//        This is a debug code for downsizing for memory capacity
//        if(AppConfig.IS_DEBUG_MODE){
//            renderer.mainTexture = nil
//        }
        
        
        // If the creation of the 3D texture fails, it's most likely due to the max buffer size limitation.
        // Consider downsizing the image for verification.
        var downsizeRatio:Float = 1.0
        
        
        // Try to downsize in XY dimension so as to fit within 2048 px.
        if renderer.mainTexture == nil{
            if(depth <= 2048 &&
               (width > 2048 ||
                height > 2048) ){
                
                // Input image size error
                
                Logger.logPrintAndWrite(message: "Input image: Width=\(width), Height=\(height), Depth=\(depth)")
                Logger.logPrintAndWrite(message: "The input image has a depth of 2048 or less, but both width and height must also be 2048 or less.")
                
                // Calculate shrink ratio
                let ratio = min(2048.0 / width.toFloat(), 2048.0 / height.toFloat())
                
                downsizeRatio *= ratio
                
                let newWidth = round(width.toFloat() * downsizeRatio).toInt()
                let newHeight = round(height.toFloat() * downsizeRatio).toInt()
                
                let newScaleX = renderer.imageParams.scaleX / downsizeRatio
                let newScaleY = renderer.imageParams.scaleY / downsizeRatio
                
                let alert = NSAlert()
                alert.messageText = "Resolution Adjustment Needed"
                alert.informativeText = "The image size exceeds the limit size (XY <= 2048).\n" +
                "Do you want to downsize the XY resolution to fit within the limits?\n\n" +
                "Width: \(width) -> \(newWidth)\n" +
                "Height: \(height) -> \(newHeight)\n" +
                "Depth: \(imgDepth), " +
                "Load channels: \(channel)\n" +
                "X resolution: \(renderer.imageParams.scaleX) -> \(newScaleX)\n" +
                "Y resolution: \(renderer.imageParams.scaleY) -> \(newScaleY)\n" +
                "Z resolution: \(renderer.imageParams.scaleZ)\n\n" +
                "Note: The Z-direction resolution and stack count will remain unchanged."
                alert.alertStyle = .warning
                alert.addButton(withTitle: "Yes")
                alert.addButton(withTitle: "No")
                
                let response = alert.runModal()
                
                switch response {
                case .alertFirstButtonReturn:
                    // procceed
                    Logger.logPrintAndWrite(message: "Downsize, Width: \(width) -> \(newWidth), Height: \(height) -> \(newHeight), X resolution: \(renderer.imageParams.scaleX) -> \(newScaleX), Y resolution: \(renderer.imageParams.scaleY) -> \(newScaleY)")
                    
                    // Change some parameters
                    renderer.volumeData.inputImageWidth = newWidth.toUInt16()
                    renderer.volumeData.inputImageHeight = newHeight.toUInt16()
                    
                    renderer.imageParams.scaleX = newScaleX
                    renderer.imageParams.scaleY = newScaleY
                    
                    zScaleRatio = renderer.imageParams.scaleZ / renderer.imageParams.scaleX
                    renderer.renderParams.zScale = zScaleRatio
                    
                    imgWidth = newWidth
                    imgHeight = newHeight
                    
                    pxCountPerSlice = imgWidth * imgHeight * numberOfComponents
                    
                    // Retry creation of texture
                    renderer.mainTexture = renderer.device.makeTexture(withChannelCount: self.renderer.imageParams.textureLoadChannel!,
                                                                       width: self.renderer.volumeData.inputImageWidth.toInt(),
                                                                       height: self.renderer.volumeData.inputImageHeight.toInt(),
                                                                       depth: self.renderer.volumeData.inputImageDepth.toInt())
                    renderer.mainTexture?.label = "Acto3D Texture"
                    
                    break
                    
                case .alertSecondButtonReturn:
                    completion(false)
                    return
                    
                default:
                    completion(false)
                    return
                }
                
                
            }
        }
        
        // If buffer error happens,
        if renderer.mainTexture == nil{
            // maybe, filed in creation of mainTexure due to buffer error
            
            let maxBuffer = renderer.device.maxBufferLength
            
            //            This is a debug code for downsizing for memory capacity
            //            if(AppConfig.IS_DEBUG_MODE){
            //                maxBuffer = 8 * 1024 * 1024 * 1024
            //            }
            
            let requestBufferSize = channel * width * height * depth
            
            if(maxBuffer <= requestBufferSize){
                Logger.logPrintAndWrite(message: "Error in creating texture")
                Logger.logPrintAndWrite(message: "Max Buffer Size: \(maxBuffer/1024/1024/1024) GB, Requested Size: \(requestBufferSize/1024/1024/1024) GB")
                
                // Check the adequate volume size
                let rawRatio = sqrt(Float(maxBuffer) / (Float(channel) * Float(width) * Float(height) * Float(depth)))
                downsizeRatio = rawRatio * 0.95
                
                let newWidth = round(width.toFloat() * downsizeRatio).toInt()
                let newHeight = round(height.toFloat() * downsizeRatio).toInt()
                
                let newScaleX = renderer.imageParams.scaleX / downsizeRatio
                let newScaleY = renderer.imageParams.scaleY / downsizeRatio
                
                let alert = NSAlert()
                alert.messageText = "Resolution Adjustment Needed"
                alert.informativeText = "The image size exceeds the available GPU memory.\n" +
                "Do you want to downsize the XY resolution to fit within the memory limits?\n" +
                "If you select 'No,' you have the option to reduce the number of channels loaded and retry.\n\n" +
                "Width: \(width) -> \(newWidth)\n" +
                "Height: \(height) -> \(newHeight)\n" +
                "Depth: \(imgDepth), " +
                "Load channels: \(channel)\n" +
                "X resolution: \(renderer.imageParams.scaleX) -> \(newScaleX)\n" +
                "Y resolution: \(renderer.imageParams.scaleY) -> \(newScaleY)\n" +
                "Z resolution: \(renderer.imageParams.scaleZ)\n\n" +
                "Note: The Z-direction resolution and stack count will remain unchanged."
                alert.alertStyle = .warning
                alert.addButton(withTitle: "Yes")
                alert.addButton(withTitle: "No")
                
                let response = alert.runModal()
                
                switch response {
                case .alertFirstButtonReturn:
                    // procceed
                    Logger.logPrintAndWrite(message: "Downsize Width: \(width) -> \(newWidth), Height: \(height) -> \(newHeight), X resolution: \(renderer.imageParams.scaleX) -> \(newScaleX), Y resolution: \(renderer.imageParams.scaleY) -> \(newScaleY)")
                    
                    // Change some parameters
                    renderer.volumeData.inputImageWidth = newWidth.toUInt16()
                    renderer.volumeData.inputImageHeight = newHeight.toUInt16()
                    
                    renderer.imageParams.scaleX = newScaleX
                    renderer.imageParams.scaleY = newScaleY
                    
                    zScaleRatio = renderer.imageParams.scaleZ / renderer.imageParams.scaleX
                    renderer.renderParams.zScale = zScaleRatio
                    
                    imgWidth = newWidth
                    imgHeight = newHeight
                    
                    pxCountPerSlice = imgWidth * imgHeight * numberOfComponents
                    
                    // Retry creation of texture
                    renderer.mainTexture = renderer.device.makeTexture(withChannelCount: self.renderer.imageParams.textureLoadChannel!,
                                                                       width: self.renderer.volumeData.inputImageWidth.toInt(),
                                                                       height: self.renderer.volumeData.inputImageHeight.toInt(),
                                                                       depth: self.renderer.volumeData.inputImageDepth.toInt())
                    renderer.mainTexture?.label = "Acto3D Texture"
                    
                    
                    break
                    
                case .alertSecondButtonReturn:
                    completion(false)
                    return
                    
                default:
                    completion(false)
                    return
                }
                
            }
        }
        
        // After adjusting the XY dimension or buffer correction, if the texture creation still fails, return
        if(renderer.mainTexture == nil){
            Dialog.showDialog(message: "Acto3D counld not create texture.")
            completion(false)
            return
        }
        
        guard let _ = renderer.mainTexture else{
            Dialog.showDialog(message: "Failed to create texture")
            Logger.logPrintAndWrite(message: "Failed to create texture")
            completion(false)
            return
        }
        Logger.logOnlyToFile(message: "  Created a 3D Texture: \(renderer.mainTexture!)")
        
        var renderPipeline:MTLComputePipelineState!
        
        DispatchQueue.global(qos: .userInteractive).async{ [self] in
            
            for j in (0 ..< imgDepth){
                autoreleasepool{
                    /// 8-bit: 1, 16-bit: 2
                    let bytesPerPixel = mTiff.bitsPerSample / 8
                    
                    let bufferSizePerSlice = MemoryLayout<UInt8>.stride * pxCountPerSlice * bytesPerPixel
                    let options: MTLResourceOptions = [.storageModeShared, .cpuCacheModeWriteCombined ]
                    
                    // Create CPU buffer with pixel data from TIFF
                    
                    guard let cpuBuffer = renderer.device.makeBuffer(length: bufferSizePerSlice, options: options),
                          let gpuBuffer = renderer.device.makeBuffer(length: bufferSizePerSlice, options: .storageModePrivate) else {
                        Logger.logOnlyToFile(message: "  Error in creating CPU or GPU buffers")
                        completion(false)
                        return
                    }
                    
                    let slicePixel_pointer = cpuBuffer.contents().bindMemory(to: UInt8.self, capacity: pxCountPerSlice * bytesPerPixel)
                    
                    for c in 0..<numberOfComponents{
                        if(downsizeRatio == 1.0){
                            // Do not need downsize
                            guard let pixelData = mTiff.image(pageNo: j * numberOfComponents + c)?.toCGImage.dataProvider?.data,
                                  let data = CFDataGetBytePtr(pixelData) else{
                                Logger.logOnlyToFile(message: "  Error in reading tiff data")
                                completion(false)
                                return
                            }
                            
                            let destination = slicePixel_pointer.advanced(by: imgWidth * imgHeight * bytesPerPixel * c)
                            memmove(destination, data, imgWidth * imgHeight * bytesPerPixel)
                            
                        }else{
                            guard let tiffImage = mTiff.image(pageNo: j * numberOfComponents + c) ,
                                  let resizedImage = tiffImage.resize(to: NSSize(width: imgWidth.toCGFloat(), height: imgHeight.toCGFloat()))
                            else {
                                completion(false)
                                return
                                
                            }
                            
                            
                            guard let pixelData = resizedImage.toCGImage.dataProvider?.data,
                                  let data = CFDataGetBytePtr(pixelData) else{
                                Logger.logOnlyToFile(message: "  Error in reading tiff data")
                                completion(false)
                                return
                            }
                            
                            let destination = slicePixel_pointer.advanced(by: imgWidth * imgHeight * bytesPerPixel * c)
                            memmove(destination, data, imgWidth * imgHeight * bytesPerPixel)
                        }
                    }
                    
                    guard let commandBuffer = renderer.cmdQueue.makeCommandBuffer(),
                          let blitEncoder = commandBuffer.makeBlitCommandEncoder() else {
                        Logger.logOnlyToFile(message: "  Error in creating command buffer or blit encoder")
                        completion(false)
                        return
                    }
                    
                    blitEncoder.label = "Pixel Data Transfer Encoder"
                    commandBuffer.label = "Pixel Data Transfer Command Buffer"
                    cpuBuffer.label = "CPU Pixel Data Buffer"
                    gpuBuffer.label = "GPU Pixel Data Buffer"
                    
                    blitEncoder.copy(from: cpuBuffer, sourceOffset: 0, to: gpuBuffer, destinationOffset: 0, size: bufferSizePerSlice)
                    blitEncoder.endEncoding()
                    commandBuffer.commit()
                    
                    
                    // Run Compute Shader to arrange pixel data
                    guard let arrangeCommandBuffer = renderer.cmdQueue.makeCommandBuffer(),
                          let computeEncoder = arrangeCommandBuffer.makeComputeCommandEncoder(),
                          let computeFunction = renderer.mtlLibrary.makeFunction(name: bit == 8 ? "createTexture8bit" : "createTexture16bit") else {
                        print("Error in creating compute command buffer or function")
                        Logger.logOnlyToFile(message: "  Error in creating pixel arrangement function")
                        completion(false)
                        return
                    }
                    arrangeCommandBuffer.label = "Arrange Pixel Buffer"
                    computeEncoder.label = "Arrangement Encoder"
                    computeFunction.label = "Arrange Function"
                    
                    if j == 0 {
                        do{
                            renderPipeline = try renderer.device.makeComputePipelineState(function: computeFunction)
                        }catch{
                            Logger.logOnlyToFile(message: "  Error in creating pipeline for pixel arrangement function")
                        }
                            
                    }
                    computeEncoder.setComputePipelineState(renderPipeline)
                    
                    var zPosition = j.toUInt16()
                    
                    // Set resources for the compute shader
                    computeEncoder.setBuffer(gpuBuffer, offset: 0, index: 0)
                    computeEncoder.setBytes(&renderer.volumeData, length: MemoryLayout<VolumeData>.stride, index: 1)
                    computeEncoder.setBytes(&numberOfComponents, length: MemoryLayout<UInt8>.stride, index: 2)
                    computeEncoder.setBytes(&zPosition, length: MemoryLayout<UInt16>.stride, index: 3)
                    computeEncoder.setBytes(&ranges, length: MemoryLayout<Float>.stride * ranges.count, index: 4)
                    computeEncoder.setBytes(&renderer.imageParams.ignoreSaturatedPixels, length: MemoryLayout<simd_uchar4>.stride, index: 5)
                    
                    computeEncoder.setTexture(renderer.mainTexture, index: 0)

                    if(renderer.device.checkNonUniformThreadgroup() == true){
                        let threadGroupSize = MTLSizeMake(renderPipeline.threadExecutionWidth, renderPipeline.maxTotalThreadsPerThreadgroup / renderPipeline.threadExecutionWidth, 1)
                        computeEncoder.dispatchThreads(MTLSize(width: imgWidth, height: imgHeight, depth: 1),
                                                       threadsPerThreadgroup: threadGroupSize)
                        
                    }else{
                        let threadGroupSize = MTLSize(width: renderPipeline.threadExecutionWidth,
                                                      height: renderPipeline.maxTotalThreadsPerThreadgroup / renderPipeline.threadExecutionWidth,
                                                      depth: 1)
                        let threadGroups = MTLSize(width: (imgWidth + threadGroupSize.width - 1) / threadGroupSize.width,
                                                   height: (imgHeight + threadGroupSize.height - 1) / threadGroupSize.height,
                                                   depth: 1)
                        computeEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)
                        
                    }
                

                    computeEncoder.endEncoding()
                    arrangeCommandBuffer.commit()
                    
                    
                    // Update progress bar
                    DispatchQueue.main.async {[self] in
                        self.progressBar.increment(by: Double(numberOfComponents))
                    }
                }
            }
            
            completion(true)
        }
    }
    
    
    
    internal func benchmark_test_create3D(filePackage: FilePackage){
        
        Logger.logPrintAndWrite(message: "Start to load directory: \(filePackage.fileDir.path)")
        
        
        let imgWidth = renderer.volumeData.inputImageWidth.toInt()
        let imgHeight =  renderer.volumeData.inputImageHeight.toInt()
        let imgCount =  renderer.volumeData.inputImageDepth.toInt()
        var numberOfComponents = 4
        let bit = 8
    
        let zScaleRatio:Float = 1.0
        
        renderer.volumeData.numberOfComponent = 4
        
        // progressbar setting
        progressBar.isHidden = false
        progressBar.maxValue = (imgCount - 1).toDouble()
        progressBar.minValue = 0.0
        progressBar.doubleValue = 0
        self.progressBar.contentFilters = [
            CIFilter(name: "CIHueAdjust", parameters: ["inputAngle": NSNumber(value: 4)])!
        ]
        
        var ranges:[Float] = []
        ranges = self.renderer.imageParams.displayRanges.flatMap{
            $0.map{
                Float($0)
            }
        }
        
        
        let pxCountPerSlice = imgWidth * imgHeight * numberOfComponents
        
        
        // texture setting
        renderer.mainTexture = renderer.device.makeTexture(withChannelCount: self.renderer.imageParams.textureLoadChannel!,
                                                           width: self.renderer.volumeData.inputImageWidth.toInt(),
                                                           height: self.renderer.volumeData.inputImageHeight.toInt(),
                                                           depth: self.renderer.volumeData.inputImageDepth.toInt())
        renderer.mainTexture?.label = "Acto3D Texture"
        guard let _ = renderer.mainTexture else{
            Dialog.showDialog(message: "Failed to create texture")
            Logger.logPrintAndWrite(message: "Failed to create texture")
            return
        }
        Logger.logOnlyToFile(message: "  Created a 3D Texture: \(renderer.mainTexture!)")
        
        
        var renderPipeline:MTLComputePipelineState!
        
        DispatchQueue.global(qos: .userInteractive).async{ [self] in
            for j in (0 ..< imgCount){
                autoreleasepool{
                    let bytesPerPixel = 1
                    
                    let bufferSizePerSlice = MemoryLayout<UInt8>.stride * pxCountPerSlice * bytesPerPixel
                    let options: MTLResourceOptions = [.storageModeShared, .cpuCacheModeWriteCombined ]
                    
                    
                    guard let cpuBuffer = renderer.device.makeBuffer(length: bufferSizePerSlice, options: options),
                          let gpuBuffer = renderer.device.makeBuffer(length: bufferSizePerSlice, options: .storageModePrivate) else {
                        Logger.logOnlyToFile(message: "  Error in creating CPU or GPU buffers")
                        return
                    }
                    
                    let cpuPixels = cpuBuffer.contents().bindMemory(to: UInt8.self, capacity: pxCountPerSlice * bytesPerPixel)
                            
                    // create random image
                    var data = [UInt8](repeating: 0, count: pxCountPerSlice)
                    let randomBytes = SecRandomCopyBytes(kSecRandomDefault, data.count, &data)
                    if randomBytes == errSecSuccess {
                    } else {
                        Dialog.showDialog(message: "Failed to generate random bytes")
                    }
                    
                    // Copy image data to CPU buffer
                    memmove(&cpuPixels[0], data, pxCountPerSlice)
                    
                    guard let commandBuffer = renderer.cmdQueue.makeCommandBuffer(),
                          let blitEncoder = commandBuffer.makeBlitCommandEncoder() else {
                        Logger.logOnlyToFile(message: "  Error in creating command buffer or blit encoder")
                        return
                    }
                    
                    blitEncoder.label = "Pixel Data Transfer Encoder"
                    commandBuffer.label = "Pixel Data Transfer Command Buffer"
                    cpuBuffer.label = "CPU Pixel Data Buffer"
                    gpuBuffer.label = "GPU Pixel Data Buffer"
                    
                    // Copy data from CPU buffer to GPU buffer
                    blitEncoder.copy(from: cpuBuffer, sourceOffset: 0, to: gpuBuffer, destinationOffset: 0, size: bufferSizePerSlice)
                    blitEncoder.endEncoding()
                    commandBuffer.commit()
                    
                    // Run Compute Shader to arrange pixel data
                    guard let arrangeCommandBuffer = renderer.cmdQueue.makeCommandBuffer(),
                          let computeEncoder = arrangeCommandBuffer.makeComputeCommandEncoder(),
                          let computeFunction = renderer.mtlLibrary.makeFunction(name: bit == 8 ? "createTextureFromStacks8bit" : "createTextureFromStacks16bit") else {
                        print("Error in creating compute command buffer or function")
                        Logger.logOnlyToFile(message: "  Error in creating pixel arrangement function")
                        return
                    }
                    arrangeCommandBuffer.label = "Arrange Pixel Buffer"
                    computeEncoder.label = "Arrangement Encoder"
                    computeFunction.label = "Arrange Function"
                    
                    if j == 0 {
                        do{
                            renderPipeline = try renderer.device.makeComputePipelineState(function: computeFunction)
                        }catch{
                            Logger.logOnlyToFile(message: "  Error in creating pipeline for pixel arrangement function")
                        }
                            
                    }
                    computeEncoder.setComputePipelineState(renderPipeline)
                    
                    var zPosition = j.toUInt16()
                    
                    // Set resources for the compute shader
                    computeEncoder.setBuffer(gpuBuffer, offset: 0, index: 0)
                    computeEncoder.setBytes(&renderer.volumeData, length: MemoryLayout<VolumeData>.stride, index: 1)
                    computeEncoder.setBytes(&numberOfComponents, length: MemoryLayout<UInt8>.stride, index: 2)
                    computeEncoder.setBytes(&zPosition, length: MemoryLayout<UInt16>.stride, index: 3)
                    computeEncoder.setBytes(&ranges, length: MemoryLayout<Float>.stride * ranges.count, index: 4)
                    computeEncoder.setBytes(&renderer.imageParams.ignoreSaturatedPixels, length: MemoryLayout<simd_uchar4>.stride, index: 5)
                    var needBitsAdjust = false
                    computeEncoder.setBytes(&needBitsAdjust, length: MemoryLayout<Bool>.stride, index: 6)
                    computeEncoder.setTexture(renderer.mainTexture, index: 0)
                    
                    
                    
                    if(renderer.device.checkNonUniformThreadgroup() == true){
                        let threadGroupSize = MTLSizeMake(renderPipeline.threadExecutionWidth, renderPipeline.maxTotalThreadsPerThreadgroup / renderPipeline.threadExecutionWidth, 1)
                        computeEncoder.dispatchThreads(MTLSize(width: imgWidth, height: imgHeight, depth: 1),
                                                       threadsPerThreadgroup: threadGroupSize)
                        
                    }else{
                        let threadGroupSize = MTLSize(width: renderPipeline.threadExecutionWidth,
                                                      height: renderPipeline.maxTotalThreadsPerThreadgroup / renderPipeline.threadExecutionWidth,
                                                      depth: 1)
                        let threadGroups = MTLSize(width: (imgWidth + threadGroupSize.width - 1) / threadGroupSize.width,
                                                   height: (imgHeight + threadGroupSize.height - 1) / threadGroupSize.height,
                                                   depth: 1)
                        computeEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)
                        
                    }

                    computeEncoder.endEncoding()
                    arrangeCommandBuffer.commit()
                    
                    
                    // Update progress bar
                    DispatchQueue.main.async {[self] in
                        self.progressBar.increment(by: 1)
                    }
                    
                }
            }
            
            self.renderer.createMtlFunctionForRendering()
            self.renderer.createMtlPipelineForRendering()
                
            
            DispatchQueue.main.sync {[self] in
                print("Initial Draw in main thread")
                
                self.zScale_Slider.floatValue = zScaleRatio
                self.renderer.renderParams.zScale = zScaleRatio
                self.updateSliceAndScale(currentSliceToMax: true)
                
                
                self.progressBar.isHidden = true
                self.progressBar.doubleValue = 0
                
                
                self.xResolutionField.floatValue = self.renderer.imageParams.scaleX
                self.yResolutionField.floatValue = self.renderer.imageParams.scaleY
                self.zResolutionField.floatValue = self.renderer.imageParams.scaleZ
                self.scaleUnitField.stringValue = self.renderer.imageParams.unit
                
                
                if(self.renderer.imageParams.textureLoadChannel != 4){
                    self.intensityRatio_slider_4.floatValue = 0
                    self.renderer.renderParams.intensityRatio[3] = 0
                    self.toneCh4.setControlPoint(array: [[0,0], [255,0]], redraw: true)
                }
                
                
                self.outputView.image = self.renderer.rendering()
                
            }
        }
        
    }
}
