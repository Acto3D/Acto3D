//
//  ImageOptionView.swift
//  Acto3D
//
//  Created by Naoki Takeshita on 2022/08/19.
//

import Cocoa
import simd

protocol ImageOptionViewProtocol {
    func closeView(sender:NSViewController)
    func applyParams(sender:NSViewController, params:ImageParameters)
}

class StoredImage{
    var imageNo = 0
    var image_ch1:CFData?
    var image_ch2:CFData?
    var image_ch3:CFData?
    var image_ch4:CFData?
    
    init() {
        
    }
    
    func getImageData(channel:Int) -> CFData?{
        if(channel == 0){
            return image_ch1
        }else if(channel == 1){
            return image_ch2
        }else if(channel == 2){
            return image_ch3
        }else if(channel == 3){
            return image_ch4
        }
        return nil
    }
}

class ImageOptionView: NSViewController {
    var delegate: ImageOptionViewProtocol?
    
//    var fileList:[String]!
//    var fileType:FileType = .none
//    var workingDir:URL!
    var filePackage:FilePackage!
    
    var renderer:VoluemeRenderer!
    
    var storedImage = StoredImage()
    
    @IBOutlet weak var slider_imgNo1: NSSlider!
    @IBOutlet weak var slider_imgNo2: NSSlider!
    @IBOutlet weak var slider_imgNo3: NSSlider!
    @IBOutlet weak var slider_imgNo4: NSSlider!
    
    
    @IBOutlet weak var imageWell1: NSImageView!
    @IBOutlet weak var imageWell2: NSImageView!
    @IBOutlet weak var imageWell3: NSImageView!
    @IBOutlet weak var imageWell4: NSImageView!
    
    var mtiff:MTIFF?
    
    @IBOutlet weak var label_range1: NSTextField!
    @IBOutlet weak var label_range2: NSTextField!
    @IBOutlet weak var label_range3: NSTextField!
    @IBOutlet weak var label_range4: NSTextField!
    
    @IBOutlet weak var histo_1: HistogramView!
    @IBOutlet weak var histo_2: HistogramView!
    @IBOutlet weak var histo_3: HistogramView!
    @IBOutlet weak var histo_4: HistogramView!
    
    @IBOutlet weak var ignoreSaturateButton_1: NSButton!
    @IBOutlet weak var ignoreSaturateButton_2: NSButton!
    @IBOutlet weak var ignoreSaturateButton_3: NSButton!
    @IBOutlet weak var ignoreSaturateButton_4: NSButton!
    
    
    @IBOutlet weak var voxelWidth: NSTextField!
    @IBOutlet weak var voxelHeight: NSTextField!
    @IBOutlet weak var voxelDepth: NSTextField!
    @IBOutlet weak var voxelUnit: NSTextField!
    
    
    var channelCount = 0
    var imageCount = 0
    var imageCountPerChannel = 0
    var imageWidth = 0
    var imageHeight = 0
    
    var imageParams = ImageParameters()
    
    var bit = 0
    
    var imageWell:[NSImageView] = []
    var slider_imgNo:[NSSlider] = []
    var label_range:[NSTextField] = []
    var histo:[HistogramView] = []
    var ignoreSaturate:[NSButton] = []
    
    // When extracting ByteData from an Image, the behavior differs between JPG, PNG, and TIFF.
    // For a 24-bit image, while JPG and PNG are converted to 32 bits, TIFF can be processed as 24 bits.
    // This is believed to be because the conversion process from NSImage to Data internally goes through a TIFF conversion.
    var needBitsAdjust = false
    
    var device : MTLDevice!
    var cmdQueue : MTLCommandQueue!
    var renderPipeline: MTLComputePipelineState?
    
    @IBOutlet weak var channelUse: NSPopUpButton!
    
    override func cancelOperation(_ sender: Any?) {
        delegate?.closeView(sender: self)
    }
    
    @IBAction func cancelButton(_ sender: Any) {
        self.cancelOperation(sender)
    }
    
    @IBAction func okButton(_ sender: Any) {
        self.imageParams.scaleX = voxelWidth.floatValue
        self.imageParams.scaleY = voxelHeight.floatValue
        self.imageParams.scaleZ = voxelDepth.floatValue
        self.imageParams.unit = voxelUnit.stringValue
        
        delegate?.applyParams(sender: self, params: self.imageParams)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        imageWell = [imageWell1, imageWell2, imageWell3, imageWell4]
        slider_imgNo = [slider_imgNo1, slider_imgNo2, slider_imgNo3, slider_imgNo4]
        label_range = [label_range1, label_range2, label_range3, label_range4]
        histo = [histo_1, histo_2, histo_3, histo_4]
        ignoreSaturate = [ignoreSaturateButton_1, ignoreSaturateButton_2, ignoreSaturateButton_3, ignoreSaturateButton_4]
        
        if let textureLoadChannel = imageParams.textureLoadChannel{
            switch textureLoadChannel{
            case 1:
                channelUse.selectItem(withTag: textureLoadChannel)
                
            case 2:
                channelUse.selectItem(withTag: textureLoadChannel)
                
            case 4:
                channelUse.selectItem(withTag: textureLoadChannel)
                
            default:
                channelUse.selectItem(withTag: 4)
            }
        }
        
        
        if (filePackage.fileType == .singleFileMultiPage){
            let fileURL = filePackage.fileDir.appendingPathComponent(filePackage.fileList[0])
            
            mtiff = MTIFF(fileURL: fileURL)
            guard let mtiff = mtiff else {
                self.delegate?.closeView(sender: self)
                return
            }
            
            channelCount = mtiff.channel
            imageCount = mtiff.imgCount
            imageCountPerChannel = imageCount / channelCount
            bit = mtiff.bitsPerSample
            imageWidth = mtiff.width
            imageHeight = mtiff.height
            
            
            print("bit", bit, mtiff.bitsPerSample, channelCount, imageCount, imageCountPerChannel)
            
            slider_imgNo1.minValue = 1
            slider_imgNo2.minValue = 1
            slider_imgNo3.minValue = 1
            slider_imgNo4.minValue = 1
            
            slider_imgNo1.maxValue = imageCountPerChannel.toDouble()
            slider_imgNo2.maxValue = imageCountPerChannel.toDouble()
            slider_imgNo3.maxValue = imageCountPerChannel.toDouble()
            slider_imgNo4.maxValue = imageCountPerChannel.toDouble()
            
            slider_imgNo1.integerValue = imageCountPerChannel / 2
            slider_imgNo2.integerValue = imageCountPerChannel / 2
            slider_imgNo3.integerValue = imageCountPerChannel / 2
            slider_imgNo4.integerValue = imageCountPerChannel / 2
            
            label_range1.stringValue = ""
            label_range2.stringValue = ""
            label_range3.stringValue = ""
            label_range4.stringValue = ""
            
            voxelWidth.floatValue = imageParams.scaleX
            voxelHeight.floatValue = imageParams.scaleY
            voxelDepth.floatValue = imageParams.scaleZ
            voxelUnit.stringValue = imageParams.unit
            
            
            for c in 0 ..< channelCount{
                slider_imgNo[c].isEnabled = true
                
                histo[c].bit = bit
                histo[c].currentClipBit = bit
                histo[c].delegate = self
                histo[c].channel = c
                histo[c].displayRanges = [imageParams.displayRanges[c][0], imageParams.displayRanges[c][1]]
                histo[c].update()
                
                ignoreSaturate[c].isHidden = false
                ignoreSaturate[c].state = self.imageParams.ignoreSaturatedPixels?[c] == 0 ? .off : .on
                
                
                label_range[c].stringValue = "min: \(imageParams.displayRanges[c][0].round(point: 2)), max: \(imageParams.displayRanges[c][1].round(point: 2))"
                label_range[c].sizeToFit()
                
                
                imageWell[c].image = getAdjustedImage(c: c)
            }
            
            storedImage.imageNo = imageCountPerChannel / 2
            
        }else if (filePackage.fileType == .multiFileStacks){
            let fileURL = filePackage.fileDir.appendingPathComponent(filePackage.fileList[0])
            
            guard let img = NSImage(contentsOf: fileURL),
                  let data = img.tiffRepresentation,
                  let imgRep:NSBitmapImageRep = NSBitmapImageRep(data: data)
            else{
                Dialog.showDialog(message: "Invalid image format")
                return
            }
            
            let imgCount = filePackage.fileList.count // imageの画像総数
            
            channelCount = imgRep.bitsPerPixel / imgRep.bitsPerSample
            imageCount = imgCount * channelCount
            imageCountPerChannel = imgCount
            bit = imgRep.bitsPerSample
            
            imageWidth = imgRep.pixelsWide
            imageHeight = imgRep.pixelsHigh
            
            Logger.logPrintAndWrite(message: " [Image Option View]: Multiple images, \(imgRep.bitsPerPixel) bits/px, \(imgRep.bitsPerSample) bits/channel, \(channelCount) channels")
            
            // Need for bits adjust
            // There's a difference in bit representation when converting through tiffRepresentation compared to converting via cgImage.
            // It's essential to compare and determine if any corrections are needed based on this difference.
            if(imgRep.bitsPerPixel == 24 &&
               img.toCGImage.bitsPerPixel == 32){
                needBitsAdjust = true
            }
            
            
//
//            let img = NSImage(contentsOf: filePath)
//            let imgRep:NSBitmapImageRep = NSBitmapImageRep(data: (img?.tiffRepresentation)!)!
//            let imgWidth = imgRep.pixelsWide
//            let imgHeight = imgRep.pixelsHigh
//
//            print(imgWidth, imgHeight, imgRep.samplesPerPixel, imgRep.bitsPerPixel,  imgRep.bitsPerSample)
            
            
            
            print(channelCount,imageCount, imageCountPerChannel, bit, imageWidth)
            
            slider_imgNo1.minValue = 1
            slider_imgNo2.minValue = 1
            slider_imgNo3.minValue = 1
            slider_imgNo4.minValue = 1
            
            slider_imgNo1.maxValue = imageCountPerChannel.toDouble()
            slider_imgNo2.maxValue = imageCountPerChannel.toDouble()
            slider_imgNo3.maxValue = imageCountPerChannel.toDouble()
            slider_imgNo4.maxValue = imageCountPerChannel.toDouble()
            
            let imageNo = imageCountPerChannel / 2

            slider_imgNo1.integerValue = imageNo
            slider_imgNo2.integerValue = imageNo
            slider_imgNo3.integerValue = imageNo
            slider_imgNo4.integerValue = imageNo
            
            label_range1.stringValue = ""
            label_range2.stringValue = ""
            label_range3.stringValue = ""
            label_range4.stringValue = ""
            
            voxelWidth.floatValue = imageParams.scaleX
            voxelHeight.floatValue = imageParams.scaleY
            voxelDepth.floatValue = imageParams.scaleZ
            voxelUnit.stringValue = imageParams.unit
            
            
            for c in 0 ..< channelCount{
                slider_imgNo[c].isEnabled = true
                
                histo[c].bit = bit
                histo[c].currentClipBit = bit
                histo[c].delegate = self
                histo[c].channel = c
                histo[c].displayRanges = [imageParams.displayRanges[c][0], imageParams.displayRanges[c][1]]
                histo[c].update()
                
                ignoreSaturate[c].isHidden = false
                ignoreSaturate[c].state = self.imageParams.ignoreSaturatedPixels?[c] == 0 ? .off : .on
                
                label_range[c].stringValue = "min: \(imageParams.displayRanges[c][0].round(point: 2)), max: \(imageParams.displayRanges[c][1].round(point: 2))"
                label_range[c].sizeToFit()
                
                
                imageWell[c].image = getAdjustedImage(c: c)
            }
            
            
            guard let eData = getEachChannelDataFromMultichannelImage(fileNo: imageNo - 1) else {return}
            
            if (channelCount == 1){
                storedImage.image_ch1 = eData[0]
            }else if (channelCount == 2){
                storedImage.image_ch1 = eData[0]
                storedImage.image_ch2 = eData[1]
            }else if (channelCount == 3){
                storedImage.image_ch1 = eData[0]
                storedImage.image_ch2 = eData[1]
                storedImage.image_ch3 = eData[2]
            }else if (channelCount == 4){
                storedImage.image_ch1 = eData[0]
                storedImage.image_ch2 = eData[1]
                storedImage.image_ch3 = eData[2]
                storedImage.image_ch4 = eData[3]
            }
            
            storedImage.imageNo = imageNo
            
            for c in 0 ..< channelCount{
                imageWell[c].image = getAdjustedImage(c: c)
            }
            
            storedImage.imageNo = imageNo
        
        }
        
    }
    
    @IBAction func changeIgnoreSaturatePixelSwitchValue(_ sender:NSButton){
        self.imageParams.ignoreSaturatedPixels?[sender.tag] = sender.state == .on ? 1 : 0
        imageWell[sender.tag].image = getAdjustedImage(c: sender.tag)
    }
    
    @IBAction func imageNoSliderChange(_ sender:NSSlider){
        let imageNo = sender.integerValue
        slider_imgNo1.integerValue = imageNo
        slider_imgNo2.integerValue = imageNo
        slider_imgNo3.integerValue = imageNo
        slider_imgNo4.integerValue = imageNo
        
        print(imageNo)
        
        if (filePackage.fileType == .singleFileMultiPage){
            for c in 0 ..< channelCount{
                imageWell[c].image = getAdjustedImage(c: c)
            }
            
            storedImage.imageNo = imageNo
            
        }else if (filePackage.fileType == .multiFileStacks){
            guard let eData = getEachChannelDataFromMultichannelImage(fileNo: imageNo - 1) else {return}
            
            if (channelCount == 1){
                storedImage.image_ch1 = eData[0]
            }else if (channelCount == 2){
                storedImage.image_ch1 = eData[0]
                storedImage.image_ch2 = eData[1]
            }else if (channelCount == 3){
                storedImage.image_ch1 = eData[0]
                storedImage.image_ch2 = eData[1]
                storedImage.image_ch3 = eData[2]
            }else if (channelCount == 4){
                storedImage.image_ch1 = eData[0]
                storedImage.image_ch2 = eData[1]
                storedImage.image_ch3 = eData[2]
                storedImage.image_ch4 = eData[3]
            }
            
            storedImage.imageNo = imageNo
            for c in 0 ..< channelCount{
                imageWell[c].image = getAdjustedImage(c: c)
            }
            
                
            
        }
        
    }
    
    //MARK: Obtain images which are clipped to 8 bits according to the display ranges
    /// Obtain images which are clipped to 8 bits according to the display ranges
    private func getAdjustedImage(c: Int) -> NSImage?{
        var ranges: [Float] = imageParams.displayRanges[c].compactMap { Float($0) }
        
        if(storedImage.imageNo != slider_imgNo[c].integerValue){
            let currentImageNo = (slider_imgNo[c].integerValue - 1) * channelCount + c
            guard let mtiff = mtiff,
                  let currentImageData = mtiff.imageData(pageNo: currentImageNo),
                  let cgImage = NSImage(data: currentImageData)?.toCGImage,
                  let provider = cgImage.dataProvider else {
                return nil
            }
        
            switch c {
            case 0: storedImage.image_ch1 = provider.data
            case 1: storedImage.image_ch2 = provider.data
            case 2: storedImage.image_ch3 = provider.data
            case 3: storedImage.image_ch4 = provider.data
            default: break
            }
            
        }
        
        guard let data = CFDataGetBytePtr(storedImage.getImageData(channel: c)) else {
            return nil
        }
        
        // Pixel Data Transfer to GPU
        let pxCount = imageWidth * imageHeight
        let bytesPerPixel = bit / 8
        guard let commandBuffer = cmdQueue.makeCommandBuffer(),
              let blitEncoder = commandBuffer.makeBlitCommandEncoder() else {
            return nil
        }
        commandBuffer.label = "Pixel Data Transfer Command Buffer"
        blitEncoder.label = "Pixel Data Transfer Encoder"
        
        let bufSize = MemoryLayout<UInt8>.stride * pxCount * bytesPerPixel
        let options: MTLResourceOptions = [.storageModeShared, .cpuCacheModeWriteCombined]
        
        guard let pixelBuffer = device.makeBuffer(length: pxCount * bytesPerPixel * MemoryLayout<UInt8>.stride, options: options),
              let gpuBuffer = device.makeBuffer(length: bufSize, options: .storageModePrivate) else{
            Dialog.showDialogWithDebug(message: "Failed to create buffers")
            return nil
        }
              
        let pixelPtr = pixelBuffer.contents().bindMemory(to: UInt8.self, capacity: pxCount * bytesPerPixel)
        memmove(pixelPtr, data, pxCount * bytesPerPixel)
        
        blitEncoder.copy(from: pixelBuffer, sourceOffset: 0, to: gpuBuffer, destinationOffset: 0, size: bufSize)
        blitEncoder.endEncoding()
        commandBuffer.commit()
        
        
        
        guard let changeRangeCommandBuffer = cmdQueue.makeCommandBuffer(),
        let changeRangeEncoder = changeRangeCommandBuffer.makeComputeCommandEncoder()else{
            return nil
        }
        changeRangeCommandBuffer.label = "Display Range Adjustment Command Buffer"
        changeRangeEncoder.label = "Range Adjustment Encoder"
        
        guard let computeFunction = bit == 8 ? renderer.mtlLibrary.makeFunction(name: "changeRangeEncoder8bit") : renderer.mtlLibrary.makeFunction(name: "changeRangeEncoder16bit")  else {
            changeRangeEncoder.endEncoding()
            return nil
        }
        
        computeFunction.label = "arrange function"
        
        if renderPipeline == nil || renderPipeline?.label != "getAdjustedImage" {
            let pipelineDescriptor = MTLComputePipelineDescriptor()
            pipelineDescriptor.label = "getAdjustedImage"
            pipelineDescriptor.computeFunction = computeFunction
            renderPipeline = try? renderer.device.makeComputePipelineState(descriptor: pipelineDescriptor, options: .argumentInfo, reflection: nil)
        }
        
        guard let renderPipeline = renderPipeline else { return nil }
        
        
        changeRangeEncoder.setComputePipelineState(renderPipeline)
        changeRangeEncoder.setBuffer(gpuBuffer, offset: 0, index: 0)
        changeRangeEncoder.setBytes(&ranges, length: MemoryLayout<Float>.stride * 2, index: 1)
        var w = imageWidth.toUInt16()
        var h = imageHeight.toUInt16()
        changeRangeEncoder.setBytes(&w, length: MemoryLayout<UInt16>.stride, index: 2)
        changeRangeEncoder.setBytes(&h, length: MemoryLayout<UInt16>.stride, index: 3)
        
        
        let outBufSize = MemoryLayout<UInt8>.stride * pxCount
        
        let outputPixelBuffer = device.makeBuffer(length: outBufSize, options: options)
        
        changeRangeEncoder.setBuffer(outputPixelBuffer, offset: 0, index: 4)
        
        let intensityLength = bit == 8 ? (0xFF + 1) : (0xFFFF) + 1
        let intensityCountBuffer = device.makeBuffer(length: MemoryLayout<UInt32>.stride * intensityLength, options: options)
        
        changeRangeEncoder.setBuffer(intensityCountBuffer!, offset: 0, index: 5)
        changeRangeEncoder.setBytes(&self.imageParams.ignoreSaturatedPixels![c], length: MemoryLayout<UInt8>.stride, index: 6)
    
        let width = renderPipeline.threadExecutionWidth
        let threads_in_group = renderPipeline.maxTotalThreadsPerThreadgroup
        let height = threads_in_group / width
        let depth  = 1 
        let threadsPerThreadgroup = MTLSize(width: width, height: height, depth: depth)
        
        
        let threadgroupsPerGrid = MTLSize(width: (imageWidth + width - 1) / width, height: (imageHeight + height - 1) / height, depth: 1)
        changeRangeEncoder.dispatchThreadgroups(threadgroupsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
        
        changeRangeEncoder.endEncoding()
        changeRangeCommandBuffer.commit()
        
        changeRangeCommandBuffer.waitUntilCompleted()
        
        
        let intensityPtr = intensityCountBuffer!.contents().bindMemory(to: UInt32.self, capacity: intensityLength)
        let intensityBfr = UnsafeBufferPointer(start: intensityPtr, count: intensityLength)
        let intensityAry = Array(intensityBfr)
        
        histo[c].histogram = intensityAry
        
        
        guard let providerRef = CGDataProvider(data: Data (bytes: outputPixelBuffer!.contents(),
                                                           count: MemoryLayout<UInt8>.stride * pxCount) as CFData)
        else { return nil }
        
        
        guard let cgim = CGImage(
            width: imageWidth,
            height: imageHeight,
            bitsPerComponent: 8, // 8
            bitsPerPixel: 8, // 24 or 32
            bytesPerRow: MemoryLayout<UInt8>.stride * imageWidth,  // * 4 for 32bit
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
            provider: providerRef,
            decode: nil,
            shouldInterpolate: true,
            intent: .defaultIntent)
        else { return  nil}
        
        return cgim.toNSImage
    }
    @IBAction func selectChannelUse(_ sender: NSPopUpButton) {
        imageParams.textureLoadChannel = sender.selectedTag()
    }
    
    private func getEachChannelDataFromMultichannelImage(fileNo:Int) -> [CFData]?{
        guard let imgTmp = NSImage(contentsOf: filePackage.fileDir.appendingPathComponent(filePackage.fileList[fileNo])),
              let provider = imgTmp.toCGImage.dataProvider,
              let data = CFDataGetBytePtr(provider.data) else {
            return nil
        }
        
        // if the original image was 24 bit, the cgimage will be 32 bit
        // if the original image was 8 bit, the cgimage will be 8 bit
        // to get the accurate bits/px; if bit is 8, channelCount * bit
        // but in tiff image, bits are converted in the correct way
        let pxCount = imageWidth * imageHeight
        let bytesPerPixel = bit / 8
        let options: MTLResourceOptions = [.storageModeShared, .cpuCacheModeWriteCombined]
        
        
        guard let commandBuffer = renderer.cmdQueue.makeCommandBuffer(),
              let blitEncoder = commandBuffer.makeBlitCommandEncoder() else {
            return nil
        }
        commandBuffer.label = "transfer image to GPU"

        var bufferSize = MemoryLayout<UInt8>.stride * pxCount * channelCount * bytesPerPixel
        if (needBitsAdjust == true) {
            // if original image was 24 bits, provided Data from cgImage would be 32 bits
            bufferSize = MemoryLayout<UInt8>.stride * pxCount * 32
        }
        
        guard let pixelBuffer = device.makeBuffer(length: bufferSize, options: options),
              let imageMetalBuffer = device.makeBuffer(length: bufferSize, options: .storageModePrivate) else {
            return nil
        }

        
        let pixelPtr = pixelBuffer.contents().bindMemory(to: UInt8.self, capacity: bufferSize)
        memmove(pixelPtr, data, bufferSize)

        blitEncoder.copy(from: pixelBuffer, sourceOffset: 0, to: imageMetalBuffer, destinationOffset: 0, size: bufferSize)
        blitEncoder.endEncoding()
        commandBuffer.commit()
        
        
        // Split channels from RGBA to RRR GGG BBB AAA
        guard let splitCommandBuffer = self.cmdQueue.makeCommandBuffer(),
              let splitChannelEncoder = splitCommandBuffer.makeComputeCommandEncoder(),
              let computeFunctionName = bit == 8 ? "splitChannelEncoder8bit" : "splitChannelEncoder16bit",
              let computeFunction = renderer.mtlLibrary.makeFunction(name: computeFunctionName) else {
            return nil
        }
        
        if renderPipeline == nil || renderPipeline?.label != "getEachChannelDataFromMultichannelImage" {
            let pipelineDescriptor = MTLComputePipelineDescriptor()
            pipelineDescriptor.label = "getEachChannelDataFromMultichannelImage"
            pipelineDescriptor.computeFunction = computeFunction
            renderPipeline = try? renderer.device.makeComputePipelineState(descriptor: pipelineDescriptor, options: .argumentInfo, reflection: nil)
        }
        
        guard let renderPipeline = renderPipeline else { return nil }
        
        splitChannelEncoder.setComputePipelineState(renderPipeline)
        splitChannelEncoder.setBuffer(imageMetalBuffer, offset: 0, index: 0)

        var imgChannelCount = channelCount.toUInt8()
        splitChannelEncoder.setBytes(&imgChannelCount, length: MemoryLayout<UInt8>.stride, index: 1)
        var w = imageWidth.toUInt16()
        var h = imageHeight.toUInt16()
        splitChannelEncoder.setBytes(&w, length: MemoryLayout<UInt16>.stride, index: 2)
        splitChannelEncoder.setBytes(&h, length: MemoryLayout<UInt16>.stride, index: 3)
        
        
         
         let outBufSize = MemoryLayout<UInt8>.stride * pxCount * channelCount * bytesPerPixel
         
         let outputPixelBuffer = device.makeBuffer(length: outBufSize, options: options)
         
        splitChannelEncoder.setBuffer(outputPixelBuffer, offset: 0, index: 4)
        
        splitChannelEncoder.setBytes(&needBitsAdjust, length: MemoryLayout<Bool>.stride, index: 5)
         
         let width = renderPipeline.threadExecutionWidth
         let threads_in_group = renderPipeline.maxTotalThreadsPerThreadgroup
         let height = threads_in_group / width
         let depth  = 1 // 1024 / 32 / 8 = 4
         let threadsPerThreadgroup = MTLSize(width: width, height: height, depth: depth)
         
         
         let threadgroupsPerGrid = MTLSize(width: (imageWidth + width - 1) / width, height: (imageHeight + height - 1) / height, depth: 1)
        splitChannelEncoder.dispatchThreadgroups(threadgroupsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
         
        splitChannelEncoder.endEncoding()
        splitCommandBuffer.commit()
         
        splitCommandBuffer.waitUntilCompleted()
         
         
        let outPixelDataPtr = outputPixelBuffer?.contents().bindMemory(to: UInt8.self, capacity: pxCount * channelCount * bytesPerPixel)
        
        
        var resultData:[CFData] = []
        
        for c in 0..<channelCount{
            let outPixelDataBfr = UnsafeBufferPointer(start: outPixelDataPtr! + c * pxCount * bytesPerPixel, count: pxCount * bytesPerPixel)
            let outPixelData = Data(buffer: outPixelDataBfr) as CFData
            
            resultData.append(outPixelData)
        }
        
        return resultData
        
    }
    
}

extension ImageOptionView: HistogramViewProtocol{
    func adjustRanges(channel:Int, ranges: [Double]) {
        imageParams.displayRanges[channel][0] = ranges[0]
        imageParams.displayRanges[channel][1] = ranges[1]
        
        label_range[channel].stringValue = "min: \(imageParams.displayRanges[channel][0].round(point: 2)), max: \(imageParams.displayRanges[channel][1].round(point: 2))"
        label_range[channel].sizeToFit()
        
        imageWell[channel].image = getAdjustedImage(c: channel)
    }
    
    
}
