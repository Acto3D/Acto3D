//
//  Renderer.swift
//  Acto3D
//
//  Created by Naoki Takeshita on 2023/02/25.
//

import Foundation
import Cocoa    
import Metal
import simd

protocol VolumeRendererDelegate: AnyObject {
    func didCompleteCalculateHistogram(sender: VoluemeRenderer, histogram:[[UInt32]])
}

class VoluemeRenderer{
    weak var delegate: VolumeRendererDelegate?
    
    // Metal
    var device : MTLDevice!
    var cmdQueue : MTLCommandQueue!
    var renderPipeline: MTLComputePipelineState!
    var mtlLibrary: MTLLibrary!
    var mtlFunction: MTLFunction!
    var argumentManager: ArgumentEncoderManager?
    
    var mainTexture: MTLTexture?{
        didSet{
            self.argumentManager?.markAsNeedsUpdate(argumentIndex: .mainTexture)
        }
    }
    
    var volumeData:VolumeData = VolumeData()
    var renderOption = RenderOption(rawValue: 0)
    var renderParams = RenderingParameters()
    var pointClouds:PointClouds = PointClouds()
    var imageParams = ImageParameters ()
    
    var quaternion:simd_quatf = simd_quatf.init(ix: 0, iy: 0, iz: 0, r: 1)
    
    // Store metal buffer of Transfer function (Opacity for pixel value)
    var toneBuffer_ch1:MTLBuffer?
    var toneBuffer_ch2:MTLBuffer?
    var toneBuffer_ch3:MTLBuffer?
    var toneBuffer_ch4:MTLBuffer?
    
    var intensityRatio:[Float] = [1.0, 1.0, 1.0, 1.0]
    
    var currentShader:ShaderManage?
    
    struct Normals{
        var x = float3(1,0,0)
        var y = float3(0,1,0)
        var z = float3(0,0,1)
    }
    var normals = Normals()
    
    
    
    
    // FPS calculation
    private var lastFrameTime: TimeInterval = 0
    private var frameCount: Int = 0
    
    //MARK: MTLFunction & Pipeline for rendering
    public func initMetal(){
        self.device = MTLCreateSystemDefaultDevice()!
        self.cmdQueue = self.device.makeCommandQueue()
        self.cmdQueue.label = "Acto3D Command Queue"
        
        Logger.logOnlyToFile(message: "Metal device on \(self.device.name) is ready for use.")

        // Check device support for Metal and write to log.
        self.device.check_GpuSupport()
    }
    
    public func createDefaultLibrary(){
        guard let mtlLibrary = self.device.makeDefaultLibrary() else{
            Dialog.showDialog(message: "Error in creating default shader library")
            return
        }
        self.mtlLibrary = mtlLibrary
    }
    
    public func createMtlFunctionForRendering(){
        guard let shader = currentShader,
              let mtlFunction = mtlLibrary.makeFunction(name: shader.kernalName) else {
            
            Dialog.showDialog(message: "No corresponding shader found. Try in preset shader.")
            
            self.currentShader = ShaderManage.getPresetList()[AppConfig.DEFAULT_SHADER_NO]
                guard let shader = currentShader,
                      let mtlFunction = mtlLibrary.makeFunction(name: shader.kernalName) else {
                    Dialog.showDialog(message: "Unkown error")
                    return
                }
            
            self.mtlFunction = mtlFunction
            self.mtlFunction.label = MTL_label.main_rendering
            
            return
        }
        self.mtlFunction = mtlFunction
        self.mtlFunction.label = MTL_label.main_rendering
    }
    
    public func createMtlPipelineForRendering(){
        do{
            let pipelineDescriptor = MTLComputePipelineDescriptor()
            
            pipelineDescriptor.label = MTL_label.main_rendering
            pipelineDescriptor.computeFunction = mtlFunction
            renderPipeline = try device.makeComputePipelineState(descriptor: pipelineDescriptor, options: .argumentInfo, reflection: nil)
            
        }catch{
            Dialog.showDialog(message: "failed in creating metal pipeline")
        }
    }
    
    public func resetMetalFunctions(){
        createMtlFunctionForRendering()
        createMtlPipelineForRendering()
    }
    
    
    //MARK: - Main Rendering Function
    // This function sets each variable and structure to the argument buffer.
    // The argument buffer manager then sets these to the encoder.
    // If the content has not been changed, it will not be reset,
    // instead, the previous one will be reused.
    public func rendering(targetViewSize:UInt16 = 0, scalebar:Bool = true) -> NSImage?{
        guard let mainTexture = mainTexture else {return nil}
        
        var drawingViewSize = targetViewSize == 0 ? renderParams.viewSize : targetViewSize
        
//        if(renderOption.contains(.PREVIEW)){
//            drawingViewSize = AppConfig.PREVIEW_SIZE.toInt()
//        }
//        if(renderOption.contains(.HQ)){
//            drawingViewSize = AppConfig.HQ_SIZE.toInt()
//        }
        
        // check if current function and pipeline are rendering mode
        if (mtlFunction == nil ||
            mtlFunction.label != MTL_label.main_rendering){
            createMtlFunctionForRendering()
        }
        
        if (renderPipeline == nil ||
            renderPipeline.label != MTL_label.main_rendering){
            createMtlPipelineForRendering()
        }
        
        // Old code
        if(currentShader?.kernalName == "btf_perfordmanceCheckInPaper2"){
            return rendering_minimum()
        }
        
        guard let cmdBuffer = cmdQueue.makeCommandBuffer(label: "Acto3D Rendering Command Buffer") else{
            Dialog.showDialog(message: "Error in creating rendering command buffer", level: .error)
            return nil
        }
        
        
        //FIXME: Currently, Acto3D only supports Metal2's Argument Encoder
        // Currently, Acto3D only supports Metal2's Argument Encoder.
        // values such as quaternions, option, ... are small size variables
        // for variables < 4kb, Apple recommends using the setBytes function
        // However, to create a custom shader, it's better to have unified arguments,
        // so Acto3D uses setBuffer in the argument buffer.
        
        if(argumentManager == nil){
            argumentManager = ArgumentEncoderManager(device: device, mtlFunction: mtlFunction)
        }
        
        argumentManager?.encodeTexture(texture: mainTexture, argumentIndex: .mainTexture)
        argumentManager?.encodeOutputPixel(drawingViewSize: drawingViewSize.toInt())
        argumentManager?.encode(&renderParams, argumentIndex: .renderParams)
        argumentManager?.encode(toneBuffer_ch1, argumentIndex: .toneBufferCh1)
        argumentManager?.encode(toneBuffer_ch2, argumentIndex: .toneBufferCh2)
        argumentManager?.encode(toneBuffer_ch3, argumentIndex: .toneBufferCh3)
        argumentManager?.encode(toneBuffer_ch4, argumentIndex: .toneBufferCh4)
        
        var optionValue = renderOption.rawValue
        argumentManager?.encode(&optionValue, argumentIndex: .optionValue)
        argumentManager?.encode(&quaternion, argumentIndex: .quaternion)
        
        argumentManager?.encode(&drawingViewSize, argumentIndex: .targetViewSize)
        
        let samplerFilter = renderOption.contains(.SAMPLER_LINEAR) ? MTLSamplerMinMagFilter.linear : MTLSamplerMinMagFilter.nearest
        argumentManager?.encodeSampler(filter: samplerFilter)

        var pCount = pointClouds.pointSet.count.toUInt16()
        var pSelected = pointClouds.selectedIndex
        argumentManager?.encode(&pCount, argumentIndex: .pointSetCountBuffer)
        argumentManager?.encode(&pSelected, argumentIndex: .pointSetSelectedBuffer)
        
        
        var pointCooordinates = pointClouds.pointSet
        var tempCount = pointClouds.pointSet.count
        if (tempCount == 0){
            tempCount = 2
            pointCooordinates = [float3(500, 500, 500), float3(5, 7, 9)]
        }
        
        argumentManager?.encodeArray(pointCooordinates, argumentIndex: .pointCoordsBuffer, capacity: tempCount)
        
        
        let cmdEncoder = cmdBuffer.makeComputeCommandEncoder(label: "Acto3D Rendering Encoder")!
        
        cmdEncoder.useResource(mainTexture, usage: .read)
        cmdEncoder.useResource(argumentManager!.getBuffer(argumentIndex: .outputBuffer)!, usage: .write)
        cmdEncoder.useResource(argumentManager!.getBuffer(argumentIndex: .renderParams)!, usage: .read)
        cmdEncoder.useResource(argumentManager!.getBuffer(argumentIndex: .toneBufferCh1)!, usage: .read)
        cmdEncoder.useResource(argumentManager!.getBuffer(argumentIndex: .toneBufferCh2)!, usage: .read)
        cmdEncoder.useResource(argumentManager!.getBuffer(argumentIndex: .toneBufferCh3)!, usage: .read)
        cmdEncoder.useResource(argumentManager!.getBuffer(argumentIndex: .toneBufferCh4)!, usage: .read)
        cmdEncoder.useResource(argumentManager!.getBuffer(argumentIndex: .optionValue)!, usage: .read)
        cmdEncoder.useResource(argumentManager!.getBuffer(argumentIndex: .quaternion)!, usage: .read)
        cmdEncoder.useResource(argumentManager!.getBuffer(argumentIndex: .targetViewSize)!, usage: .read)
        cmdEncoder.useResource(argumentManager!.getBuffer(argumentIndex: .pointSetCountBuffer)!, usage: .read)
        cmdEncoder.useResource(argumentManager!.getBuffer(argumentIndex: .pointCoordsBuffer)!, usage: .read)
        cmdEncoder.useResource(argumentManager!.getBuffer(argumentIndex: .pointSetSelectedBuffer)!, usage: .read)
        
        cmdEncoder.setBuffer(argumentManager?.argumentBuffer, offset: 0, index: 0)
        
        cmdEncoder.setComputePipelineState(renderPipeline)
        
        var width = 0
        var height = 0
        if(device.checkNonUniformThreadgroup() == true){
            width = renderPipeline.threadExecutionWidth
            let threads_in_group = renderPipeline.maxTotalThreadsPerThreadgroup
            height = threads_in_group / width
            
            let threadsPerThreadgroup = MTLSize(width: width, height: height, depth: 1)
            cmdEncoder.dispatchThreads(MTLSize(width: drawingViewSize.toInt(), height: drawingViewSize.toInt(), depth: 1), threadsPerThreadgroup: threadsPerThreadgroup)
            
        }else{
            width = renderPipeline.threadExecutionWidth
            let threads_in_group = renderPipeline.maxTotalThreadsPerThreadgroup
            height = threads_in_group / width
            
            let threadsPerThreadgroup = MTLSize(width: width, height: height, depth: 1)
            
            let threadgroupsPerGrid = MTLSize(width: (drawingViewSize.toInt() + width - 1) / width,
                                              height: (drawingViewSize.toInt() + height - 1) / height,
                                              depth: 1)
            
            
            cmdEncoder.dispatchThreadgroups(threadgroupsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
        }
        
        let startTime = Date()

        cmdEncoder.endEncoding()
        cmdBuffer.commit()
        cmdBuffer.waitUntilCompleted()
        
        let elapsedTime = Date().timeIntervalSince(startTime) * 1000
        let kernelExecutionTime = (cmdBuffer.kernelEndTime - cmdBuffer.kernelStartTime) * 1000
        let gpuExecutionTimeInSeconds = (cmdBuffer.gpuEndTime - cmdBuffer.gpuStartTime) * 1000
        
        if(AppConfig.IS_DEBUG_MODE){
            Logger.log(message: "** Thread(\(width), \(height)), Time: Kernel=\(kernelExecutionTime), GPU=\(gpuExecutionTimeInSeconds), CPU=\(elapsedTime)")
        }
        
        // retrive calculated image data from buffer
        guard let providerRef = CGDataProvider(data: Data (bytes: argumentManager!.outputPxBuffer!.contents(),
                                                           count: MemoryLayout<UInt8>.stride * argumentManager!.currentPxByteSize) as CFData)
        else { return nil }
        
        // Resulting image is 24 bits RGB image
        guard let img = CGImage(
            width: drawingViewSize.toInt(),
            height: drawingViewSize.toInt(),
            bitsPerComponent: 8,
            bitsPerPixel: 8 * 3,
            bytesPerRow: MemoryLayout<UInt8>.stride * drawingViewSize.toInt() * 3,
            space:  CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
            provider: providerRef,
            decode: nil,
            shouldInterpolate: true,
            intent: .defaultIntent)
        else { return nil}
        
        
        
        if(self.imageParams.scalebarLength != 0 && scalebar == true){
            let scalebarImage = drawScale(image: img, drawingViewSize: drawingViewSize.toInt())
            //calculateFPS()
            return scalebarImage?.toNSImage
            
        }else{
            // return image as is
            //calculateFPS()
            return img.toNSImage
        }
    }
    
    public func rendering_minimum() -> NSImage?{
        guard let mainTexture = mainTexture else {return nil}
        
        let drawingViewSize = renderParams.viewSize.toInt()
        
        // check if current function and pipeline are rendering mode
        if mtlFunction == nil {
            createMtlFunctionForRendering()
        }
        if mtlFunction.label != MTL_label.main_rendering {
            createMtlFunctionForRendering()
        }
        
        if renderPipeline == nil{
            createMtlPipelineForRendering()
        }
        if renderPipeline.label != MTL_label.main_rendering {
            createMtlPipelineForRendering()
        }
        
        
        let sampler = ImageProcessor.makeSampler(device: device, filter: .nearest)
        var imgWidth:UInt16 = volumeData.inputImageWidth
        var imgHeight:UInt16 = volumeData.inputImageHeight
        var imgDepth:UInt16 = volumeData.inputImageDepth
        var sliceNo:UInt16 = renderParams.sliceNo
        var viewSize:UInt16 = renderParams.viewSize
        var scaleZ:Float = renderParams.zScale
        var scale:Float = renderParams.scale
        var sliceMax:UInt16 = renderParams.sliceMax
        var quaternion_gpu = quaternion
        
        guard let cmdBuffer = cmdQueue.makeCommandBuffer() else {
            Dialog.showDialog(message: "Error in creating rendering command buffer")
            return nil
        }
        
        cmdBuffer.label = "Rendering Command Buffer"
        
        
        cmdBuffer.label = "Rendering Command Buffer"
        
        
        let cmdEncoder = cmdBuffer.makeComputeCommandEncoder()!
        cmdEncoder.label = "Rendering Command Encoder"
        
        cmdEncoder.setTexture(mainTexture, index: 0)
        
        
        // bytes for output image (RGB image)
        let pxByteSize = drawingViewSize * drawingViewSize * 3
        let outputPx = UnsafeMutablePointer<UInt8>.allocate(capacity: pxByteSize)
        let outputBuffer = device.makeBuffer(bytes: outputPx,
                                             length: MemoryLayout<UInt8>.stride * pxByteSize)
        
        cmdEncoder.setBuffer(outputBuffer, offset: 0, index: 0)
        
        cmdEncoder.setBytes(&imgWidth, length: MemoryLayout<UInt16>.stride, index: 1)
        cmdEncoder.setBytes(&imgHeight, length: MemoryLayout<UInt16>.stride, index: 2)
        cmdEncoder.setBytes(&imgDepth, length: MemoryLayout<UInt16>.stride, index: 3)
        cmdEncoder.setBytes(&sliceNo, length: MemoryLayout<UInt16>.stride, index: 4)
        cmdEncoder.setBytes(&scale, length: MemoryLayout<Float>.stride, index: 5)
        cmdEncoder.setBytes(&viewSize, length: MemoryLayout<UInt16>.stride, index: 6)
        cmdEncoder.setBytes(&scaleZ, length: MemoryLayout<Float>.stride, index: 7)
        cmdEncoder.setBytes(&sliceMax, length: MemoryLayout<UInt16>.stride, index: 8)
        cmdEncoder.setBytes(&quaternion_gpu, length: MemoryLayout<simd_quatf>.stride, index: 9)
        cmdEncoder.setSamplerState(sampler, index: 0)
        
        
        cmdEncoder.setComputePipelineState(renderPipeline)

        if(device.checkNonUniformThreadgroup() == true){
            let width = renderPipeline.threadExecutionWidth
            let threads_in_group = renderPipeline.maxTotalThreadsPerThreadgroup
            let height = threads_in_group / width
            
            let threadsPerThreadgroup = MTLSize(width: width, height: height, depth: 1)
            cmdEncoder.dispatchThreads(MTLSize(width: drawingViewSize, height: drawingViewSize, depth: 1), threadsPerThreadgroup: threadsPerThreadgroup)
            
        }else{
            let width = renderPipeline.threadExecutionWidth
            let threads_in_group = renderPipeline.maxTotalThreadsPerThreadgroup
            let height = threads_in_group / width
            
            let threadsPerThreadgroup = MTLSize(width: width, height: height, depth: 1)
            
            let threadgroupsPerGrid = MTLSize(width: (drawingViewSize + width - 1) / width,
                                              height: (drawingViewSize + height - 1) / height,
                                              depth: 1)
            
            
            cmdEncoder.dispatchThreadgroups(threadgroupsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
        }
        
        
        cmdEncoder.endEncoding()
        
        cmdBuffer.commit()
        cmdBuffer.waitUntilCompleted()
        
        
        // retrive calculated image data from buffer
        guard let providerRef = CGDataProvider(data: Data (bytes: outputBuffer!.contents(),
                                                           count: MemoryLayout<UInt8>.stride * pxByteSize) as CFData)
        else { return nil }
        
        
        outputPx.deallocate()
        
        
        
        guard let img = CGImage(
            width: drawingViewSize,
            height: drawingViewSize,
            bitsPerComponent: 8,
            bitsPerPixel: 8 * 3,
            bytesPerRow: MemoryLayout<UInt8>.stride * drawingViewSize * 3,
            space:  CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
            provider: providerRef,
            decode: nil,
            shouldInterpolate: true,
            intent: .defaultIntent)
        else { return nil}
        
        
        return img.toNSImage
        
        
    }
    
    /// performance test
    public func bench(repeatCount:Int, random_rotate:Bool, completion: @escaping (Bool) -> Void){
        guard let mainTexture = mainTexture else {return }
        
        let drawingViewSize = renderParams.viewSize.toInt()
        
        // check if current function and pipeline are rendering mode
        if mtlFunction == nil {
            createMtlFunctionForRendering()
        }
        if mtlFunction.label != MTL_label.main_rendering {
            createMtlFunctionForRendering()
        }
        
        if renderPipeline == nil{
            createMtlPipelineForRendering()
        }
        if renderPipeline.label != MTL_label.main_rendering {
            createMtlPipelineForRendering()
        }
        
        
        guard let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }
        
        // Formatting the date for the file name
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd-HH-mm-ss"
        let dateString = dateFormatter.string(from: Date())
        
        let deviceName = device.name
        let deviceMaxMem = device.maxBufferLength / 1024 / 1024
        
        
        let resultFileName = "performance_\(dateString)_\(deviceName)-\(deviceMaxMem)MB-XY_\(volumeData.inputImageWidth)xZ_\(volumeData.inputImageDepth).csv"
        let saveFileUrl = docDir.appendingPathComponent(resultFileName)
        
        // header
        var data: [[String]] = [["Kernel Shader Processing Time (ms)", "GPU Time (ms)", "Quaternion_r", "Quaternion_i_1", "Quaternion_i_2", "Quaternion_i_3"]]

        
        let sampler = ImageProcessor.makeSampler(device: device, filter: .nearest)
        var imgWidth:UInt16 = volumeData.inputImageWidth
        var imgHeight:UInt16 = volumeData.inputImageHeight
        var imgDepth:UInt16 = volumeData.inputImageDepth
        var sliceNo:UInt16 = renderParams.sliceNo
        var viewSize:UInt16 = renderParams.viewSize
        var scaleZ:Float = renderParams.zScale
        var scale:Float = renderParams.scale
        var sliceMax:UInt16 = renderParams.sliceMax
        var quaternion_gpu = quaternion
        
        
        // bytes for output image (RGB image)
        let pxByteSize = drawingViewSize * drawingViewSize * 3
        let outputPx = UnsafeMutablePointer<UInt8>.allocate(capacity: pxByteSize)
        let outputBuffer = device.makeBuffer(bytes: outputPx,
                                             length: MemoryLayout<UInt8>.stride * pxByteSize)
        
        
        for i in 0...repeatCount{
            
            guard let cmdBuffer = cmdQueue.makeCommandBuffer() else {
                Dialog.showDialog(message: "Error in creating rendering command buffer")
                return
            }
            
            cmdBuffer.label = "Rendering Command Buffer"
            
            
            let cmdEncoder = cmdBuffer.makeComputeCommandEncoder()!
            cmdEncoder.label = "Rendering Command Encoder"
            
            cmdEncoder.setTexture(mainTexture, index: 0)
            
            
            
            cmdEncoder.setBuffer(outputBuffer, offset: 0, index: 0)
            
            cmdEncoder.setBytes(&imgWidth, length: MemoryLayout<UInt16>.stride, index: 1)
            cmdEncoder.setBytes(&imgHeight, length: MemoryLayout<UInt16>.stride, index: 2)
            cmdEncoder.setBytes(&imgDepth, length: MemoryLayout<UInt16>.stride, index: 3)
            cmdEncoder.setBytes(&sliceNo, length: MemoryLayout<UInt16>.stride, index: 4)
            cmdEncoder.setBytes(&scale, length: MemoryLayout<Float>.stride, index: 5)
            cmdEncoder.setBytes(&viewSize, length: MemoryLayout<UInt16>.stride, index: 6)
            cmdEncoder.setBytes(&scaleZ, length: MemoryLayout<Float>.stride, index: 7)
            cmdEncoder.setBytes(&sliceMax, length: MemoryLayout<UInt16>.stride, index: 8)
            cmdEncoder.setBytes(&quaternion_gpu, length: MemoryLayout<simd_quatf>.stride, index: 9)
            cmdEncoder.setSamplerState(sampler, index: 0)
            
            
            cmdEncoder.setComputePipelineState(renderPipeline)

            if(device.checkNonUniformThreadgroup() == true){
                let width = renderPipeline.threadExecutionWidth
                let threads_in_group = renderPipeline.maxTotalThreadsPerThreadgroup
                let height = threads_in_group / width
                
                let threadsPerThreadgroup = MTLSize(width: width, height: height, depth: 1)
                cmdEncoder.dispatchThreads(MTLSize(width: drawingViewSize, height: drawingViewSize, depth: 1), threadsPerThreadgroup: threadsPerThreadgroup)
                
            }else{
                let width = renderPipeline.threadExecutionWidth
                let threads_in_group = renderPipeline.maxTotalThreadsPerThreadgroup
                let height = threads_in_group / width
                
                let threadsPerThreadgroup = MTLSize(width: width, height: height, depth: 1)
                
                let threadgroupsPerGrid = MTLSize(width: (drawingViewSize + width - 1) / width,
                                                  height: (drawingViewSize + height - 1) / height,
                                                  depth: 1)
                
                
                cmdEncoder.dispatchThreadgroups(threadgroupsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
            }
            
            
            cmdEncoder.endEncoding()
            
            
            
            
            cmdBuffer.commit()
            cmdBuffer.waitUntilCompleted()
            
            let kernelExecutionTime = cmdBuffer.kernelEndTime - cmdBuffer.kernelStartTime
            let gpuExecutionTimeInSeconds = cmdBuffer.gpuEndTime - cmdBuffer.gpuStartTime
            
            let elapsedTimeInMilliseconds = kernelExecutionTime * 1000
            let gpuExecutionTimeInMilliseconds = gpuExecutionTimeInSeconds * 1000
            
            
            
            let processingTime = "\(elapsedTimeInMilliseconds)"
            let processingTimeGPU = "\(gpuExecutionTimeInMilliseconds)"
            let quaternionComponent1 = "\(quaternion.real)"
            let quaternionComponent2 = "\(quaternion.imag.x)"
            let quaternionComponent3 = "\(quaternion.imag.y)"
            let quaternionComponent4 = "\(quaternion.imag.z)"
            
            data.append([processingTime,processingTimeGPU, quaternionComponent1, quaternionComponent2, quaternionComponent3, quaternionComponent4])

            if random_rotate{
                rotateModel(deltaX: Float.random(in: 0...90), deltaY: Float.random(in: 0...90), deltaZ: 0)
            }
            
            if i % 10 == 0 {
                DispatchQueue.main.async {
                    Logger.logPrintAndWrite(message: "performance test (\(i) / \(repeatCount))")
                }
            }
        }
        
        outputPx.deallocate()
        
        DispatchQueue.main.async {
            Logger.logPrintAndWrite(message: "performance test finished.")
            
            // create csv
            let csvString = data.map { row in
                row.joined(separator: ",")
            }.joined(separator: "\n")
            
            do {
                try csvString.write(to: saveFileUrl, atomically: true, encoding: .utf8)
                Logger.logPrintAndWrite(message: "Saved: \(saveFileUrl.path)")
                
                var isDir: ObjCBool = false
                
                if FileManager.default.fileExists(atPath: saveFileUrl.path, isDirectory: &isDir) {
                    NSWorkspace.shared.activateFileViewerSelecting([saveFileUrl])
                }
            } catch {
                Logger.logPrintAndWrite(message: "Error")
            }
            
            completion(true)
        }
        
    }
    
    public func bench2(repeatCount:Int, random_rotate:Bool, completion: @escaping (Bool) -> Void){
        guard let mainTexture = mainTexture else {return }
        
        let drawingViewSize = renderParams.viewSize.toInt()
        
        // check if current function and pipeline are rendering mode
        if mtlFunction == nil {
            createMtlFunctionForRendering()
        }
        if mtlFunction.label != MTL_label.main_rendering {
            createMtlFunctionForRendering()
        }
        
        if renderPipeline == nil{
            createMtlPipelineForRendering()
        }
        if renderPipeline.label != MTL_label.main_rendering {
            createMtlPipelineForRendering()
        }
        
        
        guard let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }
        
        // Formatting the date for the file name
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd-HH-mm-ss"
        let dateString = dateFormatter.string(from: Date())
        
        let deviceName = device.name
        let deviceMaxMem = device.maxBufferLength / 1024 / 1024
        
        
        let resultFileName = "performance_\(dateString)_\(deviceName)-\(deviceMaxMem)MB-XY_\(volumeData.inputImageWidth)xZ_\(volumeData.inputImageDepth).csv"
        let saveFileUrl = docDir.appendingPathComponent(resultFileName)
        
        // header
        var data: [[String]] = [["GPU Time (ms)", "Kernel Shader Processing Time (ms)", "CPU Time (ms)", "Quaternion_r", "Quaternion_i_1", "Quaternion_i_2", "Quaternion_i_3"]]

        
        
        for i in 0...repeatCount{
            
            guard let cmdBuffer = cmdQueue.makeCommandBuffer() else {
                Dialog.showDialog(message: "Error in creating rendering command buffer")
                return
            }
            
            cmdBuffer.label = "Rendering Command Buffer"
            
            //FIXME: Currently, Acto3D only supports Metal2's Argument Encoder
            // Currently, Acto3D only supports Metal2's Argument Encoder.
            
            // values such as quaternions, option, ... are small size variables
            // for variables < 4kb, Apple recommends using the setBytes function
            // However, to create a custom shader, it's better to have unified arguments,
            // so Acto3D uses setBuffer in the argument buffer.
            if(argumentManager == nil){
                argumentManager = ArgumentEncoderManager(device: device, mtlFunction: mtlFunction)
            }
            
            argumentManager?.encodeTexture(texture: mainTexture, argumentIndex: .mainTexture)
            argumentManager?.encodeOutputPixel(drawingViewSize: drawingViewSize)
            argumentManager?.encode(&renderParams, argumentIndex: .renderParams)
            argumentManager?.encode(toneBuffer_ch1, argumentIndex: .toneBufferCh1)
            argumentManager?.encode(toneBuffer_ch2, argumentIndex: .toneBufferCh2)
            argumentManager?.encode(toneBuffer_ch3, argumentIndex: .toneBufferCh3)
            argumentManager?.encode(toneBuffer_ch4, argumentIndex: .toneBufferCh4)
            
            var optionValue = renderOption.rawValue
            argumentManager?.encode(&optionValue, argumentIndex: .optionValue)
            argumentManager?.encode(&quaternion, argumentIndex: .quaternion)
            
            let samplerFilter = renderOption.contains(.SAMPLER_LINEAR) ? MTLSamplerMinMagFilter.linear : MTLSamplerMinMagFilter.nearest
            argumentManager?.encodeSampler(filter: samplerFilter)

            var pCount = pointClouds.pointSet.count.toUInt16()
            var pSelected = pointClouds.selectedIndex
            argumentManager?.encode(&pCount, argumentIndex: .pointSetCountBuffer)
            argumentManager?.encode(&pSelected, argumentIndex: .pointSetSelectedBuffer)
            
            
            var pointCooordinates = pointClouds.pointSet
            var tempCount = pointClouds.pointSet.count
            if (tempCount == 0){
                tempCount = 2
                pointCooordinates = [float3(500, 500, 500), float3(5, 7, 9)]
            }
            
            
            argumentManager?.encodeArray(pointCooordinates, argumentIndex: .pointCoordsBuffer, capacity: tempCount)
            
            
            
            let cmdEncoder = cmdBuffer.makeComputeCommandEncoder()!
            cmdEncoder.label = "Rendering Command Encoder"
            
            cmdEncoder.useResource(mainTexture, usage: .read)
            cmdEncoder.useResource(argumentManager!.getBuffer(argumentIndex: .outputBuffer)!, usage: .write)
            cmdEncoder.useResource(argumentManager!.getBuffer(argumentIndex: .renderParams)!, usage: .read)
            cmdEncoder.useResource(argumentManager!.getBuffer(argumentIndex: .toneBufferCh1)!, usage: .read)
            cmdEncoder.useResource(argumentManager!.getBuffer(argumentIndex: .toneBufferCh2)!, usage: .read)
            cmdEncoder.useResource(argumentManager!.getBuffer(argumentIndex: .toneBufferCh3)!, usage: .read)
            cmdEncoder.useResource(argumentManager!.getBuffer(argumentIndex: .toneBufferCh4)!, usage: .read)
            cmdEncoder.useResource(argumentManager!.getBuffer(argumentIndex: .optionValue)!, usage: .read)
            cmdEncoder.useResource(argumentManager!.getBuffer(argumentIndex: .quaternion)!, usage: .read)
            cmdEncoder.useResource(argumentManager!.getBuffer(argumentIndex: .pointSetCountBuffer)!, usage: .read)
            cmdEncoder.useResource(argumentManager!.getBuffer(argumentIndex: .pointCoordsBuffer)!, usage: .read)
            cmdEncoder.useResource(argumentManager!.getBuffer(argumentIndex: .pointSetSelectedBuffer)!, usage: .read)
            
    //        cmdEncoder.setTexture(mainTexture, index: 0)
            
            cmdEncoder.setBuffer(argumentManager?.argumentBuffer, offset: 0, index: 0)
            
            cmdEncoder.setComputePipelineState(renderPipeline)
            
            
            if(device.checkNonUniformThreadgroup() == true){
                let width = renderPipeline.threadExecutionWidth
                let threads_in_group = renderPipeline.maxTotalThreadsPerThreadgroup
                let height = threads_in_group / width
                
                let threadsPerThreadgroup = MTLSize(width: width, height: height, depth: 1)
                print(width, height)
                cmdEncoder.dispatchThreads(MTLSize(width: drawingViewSize, height: drawingViewSize, depth: 1), threadsPerThreadgroup: threadsPerThreadgroup)
                
            }else{
                let width = renderPipeline.threadExecutionWidth
                let threads_in_group = renderPipeline.maxTotalThreadsPerThreadgroup
                let height = threads_in_group / width
                
                let threadsPerThreadgroup = MTLSize(width: width, height: height, depth: 1)
                
                let threadgroupsPerGrid = MTLSize(width: (drawingViewSize + width - 1) / width,
                                                  height: (drawingViewSize + height - 1) / height,
                                                  depth: 1)
                
                
                cmdEncoder.dispatchThreadgroups(threadgroupsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
            }
            
            cmdEncoder.endEncoding()
            cmdBuffer.commit()
            
            let startTime = Date()
            cmdBuffer.waitUntilCompleted()
            
            let elapsedTime = Date().timeIntervalSince(startTime) * 1000
            let kernelExecutionTime = (cmdBuffer.kernelEndTime - cmdBuffer.kernelStartTime) * 1000
            let gpuExecutionTimeInSeconds = (cmdBuffer.gpuEndTime - cmdBuffer.gpuStartTime) * 1000
            
            
            let processingTime = "\(kernelExecutionTime)"
            let processingTimeGPU = "\(gpuExecutionTimeInSeconds)"
            let processingTimeCPU = "\(elapsedTime)"
            let quaternionComponent1 = "\(quaternion.real)"
            let quaternionComponent2 = "\(quaternion.imag.x)"
            let quaternionComponent3 = "\(quaternion.imag.y)"
            let quaternionComponent4 = "\(quaternion.imag.z)"
            
            // 新しい行をデータ配列に追加
            data.append([processingTimeGPU,processingTime,processingTimeCPU, quaternionComponent1, quaternionComponent2, quaternionComponent3, quaternionComponent4])

            if random_rotate{
                rotateModel(deltaX: Float.random(in: 0...90), deltaY: Float.random(in: 0...90), deltaZ: 0)
            }
            
            if i % 10 == 0 {
                DispatchQueue.main.async {
                    Logger.logPrintAndWrite(message: "performance test (\(i) / \(repeatCount))")
                }
            }
        }
        
        DispatchQueue.main.async {
            Logger.logPrintAndWrite(message: "performance test finished.")
            
            // create csv
            let csvString = data.map { row in
                row.joined(separator: ",")
            }.joined(separator: "\n")
            
            do {
                try csvString.write(to: saveFileUrl, atomically: true, encoding: .utf8)
                Logger.logPrintAndWrite(message: "Saved: \(saveFileUrl.path)")
                
                var isDir: ObjCBool = false
                
                if FileManager.default.fileExists(atPath: saveFileUrl.path, isDirectory: &isDir) {
                    NSWorkspace.shared.activateFileViewerSelecting([saveFileUrl])
                }
            } catch {
                Logger.logPrintAndWrite(message: "Error")
            }
            
            completion(true)
        }
        
    }
    
    
    private func calculateFPS() {
        // Get the current timestamp
        let currentTime = CACurrentMediaTime()
        
        // Increment the frame counter
        frameCount += 1
        
        // Calculate the time difference
        let elapsedTime = currentTime - lastFrameTime
        
        // If at least one second has passed
        if elapsedTime >= 1.0 {
            // Calculate FPS
            let fps = Double(frameCount) / elapsedTime
            
            // Output FPS to the console (you could also update a label on the screen)
            Logger.log(message: "\(fps)")
            
            // Reset the frame counter and the last frame time
            frameCount = 0
            lastFrameTime = currentTime
        }
    }
    
    /// add scale bar to image
    func drawScale(image: CGImage, drawingViewSize:Int) -> CGImage?{
        // Create a CGContext from the original CGImage
        guard let context = CGContext(
            data: nil,
            width: image.width,
            height: image.height,
            bitsPerComponent: 8,
            bytesPerRow: MemoryLayout<UInt8>.stride * drawingViewSize * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
                
        else {
            return nil
            
        }
        
        // Draw the image onto the context
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        
        let scaleBarLength = self.imageParams.scalebarLength
        
        let scaleMagnification : CGFloat = drawingViewSize.toCGFloat() / renderParams.viewSize.toCGFloat()
        
        
        let baseVector = quaternion.act(float3(1,0,0))
        let scaledVector = float3(baseVector.x * scaleMagnification.toFloat() * renderParams.scale / imageParams.scaleX,
                                  baseVector.y * scaleMagnification.toFloat() * renderParams.scale / imageParams.scaleY,
                                  baseVector.z * scaleMagnification.toFloat() * renderParams.scale * renderParams.zScale / imageParams.scaleZ)
        let scaledVectorLength = length(scaledVector)

        
        
        // Set the line color and width
        let scaleBarWidth = drawingViewSize.toCGFloat() / 128.0
        
        // Define the start and end points of the line
        let origin = NSPoint(x: drawingViewSize.toCGFloat() / 16.0 , y: drawingViewSize.toCGFloat() / 16.0)
        
//        let scaleXvec:CGFloat = 200 * renderParams.scale.toCGFloat() / imageParams.scaleX.toCGFloat()
//        let scaleZvec:CGFloat = 200 * renderParams.scale.toCGFloat() * renderParams.zScale.toCGFloat() / imageParams.scaleZ.toCGFloat()
//
//        let length = 50.0 * self.renderParams.scale.toCGFloat()
        
        
        
        let staticAxisEndPoint = CGPoint(x: origin.x +  scaledVectorLength.toCGFloat() * scaleBarLength.toCGFloat() ,
                                         y: origin.y)
        context.move(to: origin)
        context.addLine(to: staticAxisEndPoint)
        context.setLineWidth(scaleBarWidth)
        context.setStrokeColor(NSColor.yellow.cgColor)
        context.strokePath()
        
        if imageParams.scaleFontSize != 0{
            // show scale string
            
            // Set the font and text color
            let scaleFontSize = (imageParams.scaleFontSize * drawingViewSize.toFloat() / 512.0 ).toCGFloat()
            let font = NSFont.boldSystemFont(ofSize: scaleFontSize)
            let attributes_fore: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: NSColor.white,
            ]
            
            let attributes_back: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: NSColor.black,
                .strokeWidth: -5.0
            ]
            
            let text = "\(imageParams.scalebarLength) \(imageParams.unit)"
            let string = CFStringCreateWithCString(nil, text, CFStringBuiltInEncodings.UTF8.rawValue)
            
            let attributedString_fore = CFAttributedStringCreate(nil, string, attributes_fore as CFDictionary)
            let attributedString_back = CFAttributedStringCreate(nil, string, attributes_back as CFDictionary)
            let line_fore = CTLineCreateWithAttributedString(attributedString_fore!)
            let line_back = CTLineCreateWithAttributedString(attributedString_back!)
            
            context.textPosition = NSPoint(x: origin.x, y: origin.y + scaleBarWidth )
            CTLineDraw(line_back, context)
            context.textPosition = NSPoint(x: origin.x, y: origin.y + scaleBarWidth )
            CTLineDraw(line_fore, context)
            
        }
        
        
        // Get the resulting image
        return context.makeImage()
    }
    
    public func calculateTextureHistogram(){
        DispatchQueue.global().async {[ self] in
            Logger.start(for: "histogram calculation")
            
            guard let calcHistoFunc = mtlLibrary.makeFunction(name: "computeColorHistogram") else{
                Dialog.showDialog(message: "Error in creating metal function for histogram")
                return
            }
            var pipeline:MTLComputePipelineState!
            do{
                let pipelineDescriptor = MTLComputePipelineDescriptor()
                
                pipelineDescriptor.label = MTL_label.calculate_histogram
                pipelineDescriptor.computeFunction = calcHistoFunc
                pipeline = try device.makeComputePipelineState(descriptor: pipelineDescriptor, options: [], reflection: nil)
                
       
                
            }catch{
                Dialog.showDialog(message: "Error in creating metal pipeline for histogram")
                return
            }
            
            guard let mainTexture = self.mainTexture else{
                Dialog.showDialog(message: "Error in refering main texture")
                return
            }
            
            let cmdQueue = device.makeCommandQueue()!
            cmdQueue.label = "Queue for histogram"
            let commandBuffer = cmdQueue.makeCommandBuffer()!
            commandBuffer.label = "Command buffer for histogram"
            let computeCommandEncoder = commandBuffer.makeComputeCommandEncoder()!
            computeCommandEncoder.label = "Encoder for histogram"
            
            
            let histogramSize = 256 * 4 // RGBA
            let histogramBuffer = self.device.makeBuffer(length: histogramSize * MemoryLayout<UInt32>.size, options: .storageModeShared)
            histogramBuffer?.label = "Buffer for histogram"
            
            computeCommandEncoder.setComputePipelineState(pipeline)
            computeCommandEncoder.setTexture(self.mainTexture!, index: 0)
            
            var channelCount: UInt8 = 4
            computeCommandEncoder.setBytes(&channelCount, length: MemoryLayout<UInt8>.stride, index: 0)
            
            computeCommandEncoder.setBuffer(histogramBuffer, offset: 0, index: 1)
            
            
            if(device.checkNonUniformThreadgroup() == true){
                let threadGroupSize = MTLSizeMake(pipeline.threadExecutionWidth, pipeline.maxTotalThreadsPerThreadgroup / pipeline.threadExecutionWidth, 1)
                computeCommandEncoder.dispatchThreads(MTLSize(width: mainTexture.width,
                                                              height: mainTexture.height,
                                                              depth: mainTexture.depth),
                                                      threadsPerThreadgroup: threadGroupSize)
                
            }else{
                let threadGroupSize = MTLSize(width: pipeline.threadExecutionWidth,
                                              height: pipeline.maxTotalThreadsPerThreadgroup / pipeline.threadExecutionWidth,
                                              depth: 1)
                let threadGroups = MTLSize(width: (mainTexture.width + threadGroupSize.width - 1) / threadGroupSize.width,
                                           height: (mainTexture.height + threadGroupSize.height - 1) / threadGroupSize.height,
                                           depth: mainTexture.depth)
                computeCommandEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)
                
            }
            
            computeCommandEncoder.endEncoding()
            
            commandBuffer.addCompletedHandler { buffer in
                let elapsedTime = Logger.stop(for: "histogram calculation")
                
                if let error = buffer.error {
                    print("Error occurred: \(error)")
                    return
                }
                
                var histogramPerChannel: [[UInt32]] = []
                
                for channel in 0..<Int(channelCount) {
                    let bins = 256
                    let channelSize = bins * MemoryLayout<UInt32>.size
                    let histogramData = UnsafeMutablePointer<UInt32>.allocate(capacity: bins)
                    
                    let offset = channel * channelSize
                    memcpy(histogramData, histogramBuffer!.contents().advanced(by: offset), channelSize)
                    
                    let histogramForThisChannel = Array(UnsafeBufferPointer(start: histogramData, count: bins))
                    histogramPerChannel.append(histogramForThisChannel)
                    
                    histogramData.deallocate()
                }
                
                // 出力
                for (channel, histogram) in histogramPerChannel.enumerated() {
                    print("Histogram for channel \(channel): \(histogram)")
                }
                
                DispatchQueue.main.sync {
                    Logger.logPrintAndWrite(message: "Histogram calucation finished. caluculate time = \(elapsedTime) ms")
                    self.delegate?.didCompleteCalculateHistogram(sender: self, histogram: histogramPerChannel)
                    
                }
            }
            commandBuffer.commit()
            
        }
        
        
    }
    
    
    public func transferToneArrayToBuffer(toneArray: [Float], targetGpuBuffer: inout MTLBuffer?, index:Int){
        let bufferSize = MemoryLayout<Float>.stride * toneArray.count // 4 * 2560 = 10 KB
        if(targetGpuBuffer == nil){
            targetGpuBuffer = device.makeBuffer(length: bufferSize, options: .storageModePrivate)
        }
        
        let options: MTLResourceOptions = [.storageModeShared,  .cpuCacheModeWriteCombined]
        let cpuBuffer = device.makeBuffer(bytes: toneArray, length: bufferSize, options: options)
        
        
        let cmdBuf = self.cmdQueue.makeCommandBuffer()!
        let encoder = cmdBuf.makeBlitCommandEncoder()!
        encoder.copy(from: cpuBuffer!, sourceOffset: 0, to: targetGpuBuffer!, destinationOffset: 0, size: bufferSize)
        targetGpuBuffer?.label = "tone buffer \(index)"
        
        switch index{
        case 0:
            argumentManager?.markAsNeedsUpdate(argumentIndex: .toneBufferCh1)
        case 1:
            argumentManager?.markAsNeedsUpdate(argumentIndex: .toneBufferCh2)
        case 2:
            argumentManager?.markAsNeedsUpdate(argumentIndex: .toneBufferCh3)
        case 3:
            argumentManager?.markAsNeedsUpdate(argumentIndex: .toneBufferCh4)
        default:
            break
        }
        
        
        encoder.endEncoding()
        cmdBuf.commit()
    }
    
    
    
    //MARK: - rotate function
    
    public func rotateModel(deltaX: Float, deltaY:Float, deltaZ:Float){
        let thetaAxisX = radians(fromDegrees: deltaX )
        let thetaAxisY = radians(fromDegrees: deltaY )
        let thetaAxisZ = radians(fromDegrees: deltaZ )
        
        let quat_X = simd_quatf(angle: thetaAxisX, axis: normalize(normals.x))
        let quat_Y = simd_quatf(angle: thetaAxisY, axis: normalize(normals.y))
        let quat_Z = simd_quatf(angle: thetaAxisZ, axis: normalize(normals.z))
        
        // This order is important
        let quat = quat_Y *  quat_Z  * quat_X
        
        normals.x = quat.act(normals.x)
        normals.y = quat.act(normals.y)
        normals.z = quat.act(normals.z)
        
        quaternion = quat * quaternion
        
  
    }
    
    /// set new quaternion manually
    public func rotateModelTo(quaternion: simd_quatf){
        self.quaternion = quaternion
        
        // reset normals and apply new quaternion
        self.normals = Normals()
        
        normals.x = quaternion.act(normals.x)
        normals.y = quaternion.act(normals.y)
        normals.z = quaternion.act(normals.z)
    }
    
    public func resetRotation(){
        self.normals = Normals()
        self.quaternion = simd_quatf.init(ix: 0, iy: 0, iz: 0, r: 1)
    }
    
    //MARK: - export
    
    /// exportToTiffForEachChannel
    /// - Parameters:
    ///   - useChannel: -1(all) or 0-3
    public func exportToTiffForEachChannel(useChannel:Int, filePackage:FilePackage){
        
        guard let inTex = self.mainTexture else {
            Dialog.showDialog(message: "First load texture")
            return
        }
        
        // prepare dir
        guard let exportDir = filePackage.exportDir else {return}
        
        let outDir_0 = filePackage.createSubdirectoryForUrl(url: exportDir, directoryName: "ch1")
        let outDir_1 = filePackage.createSubdirectoryForUrl(url: exportDir, directoryName: "ch2")
        let outDir_2 = filePackage.createSubdirectoryForUrl(url: exportDir, directoryName: "ch3")
        let outDir_3 = filePackage.createSubdirectoryForUrl(url: exportDir, directoryName: "ch4")
        
        let width = inTex.width
        let height = inTex.height
        let depth = inTex.depth
        
        guard let computeFunction = mtlLibrary.makeFunction(name: "separateChannel") else {
            print("error make function")
            return
        }
        computeFunction.label = MTL_label.export
        
        let pipelineDescriptor = MTLComputePipelineDescriptor()
        
        pipelineDescriptor.label = MTL_label.export
        pipelineDescriptor.computeFunction = computeFunction
        renderPipeline = try? device.makeComputePipelineState(descriptor: pipelineDescriptor, options: .argumentInfo, reflection: nil)
        
        
        for slice in 0..<depth {
            autoreleasepool{
                
                let cmdBuf = cmdQueue.makeCommandBuffer()!
                cmdBuf.label = MTL_label.export
                
                let cmdEncoder = cmdBuf.makeComputeCommandEncoder()!
                cmdEncoder.setComputePipelineState(renderPipeline)
                
                
                let pxByteSize = width * height
                let outputPx_0 = UnsafeMutablePointer<UInt8>.allocate(capacity: pxByteSize)
                let outputPx_1 = UnsafeMutablePointer<UInt8>.allocate(capacity: pxByteSize)
                let outputPx_2 = UnsafeMutablePointer<UInt8>.allocate(capacity: pxByteSize)
                let outputPx_3 = UnsafeMutablePointer<UInt8>.allocate(capacity: pxByteSize)
                
                let outputBuffer_0 = device.makeBuffer(bytes: outputPx_0,
                                                       length: MemoryLayout<UInt8>.stride * pxByteSize,
                                                       options: .storageModeShared)
                let outputBuffer_1 = device.makeBuffer(bytes: outputPx_0,
                                                       length: MemoryLayout<UInt8>.stride * pxByteSize,
                                                       options: .storageModeShared)
                let outputBuffer_2 = device.makeBuffer(bytes: outputPx_0,
                                                       length: MemoryLayout<UInt8>.stride * pxByteSize,
                                                       options: .storageModeShared)
                let outputBuffer_3 = device.makeBuffer(bytes: outputPx_0,
                                                       length: MemoryLayout<UInt8>.stride * pxByteSize,
                                                       options: .storageModeShared)
                
                cmdEncoder.setBuffer(outputBuffer_0, offset: 0, index: 0)
                cmdEncoder.setBuffer(outputBuffer_1, offset: 0, index: 1)
                cmdEncoder.setBuffer(outputBuffer_2, offset: 0, index: 2)
                cmdEncoder.setBuffer(outputBuffer_3, offset: 0, index: 3)
                
                cmdEncoder.setTexture(inTex, index: 0)
                
                var sliceDepth:uint16 = slice.toUInt16()
                
                cmdEncoder.setBytes(&sliceDepth, length: MemoryLayout<UInt16>.stride, index: 4)
                
                
                // Compute optimization
                let xCount = inTex.width
                let yCount = inTex.height
                
                let maxTotalThreadsPerThreadgroup = renderPipeline.maxTotalThreadsPerThreadgroup // 1024
                let threadExecutionWidth          = renderPipeline.threadExecutionWidth // 32
                let t_width  = threadExecutionWidth // 32
                let t_height = maxTotalThreadsPerThreadgroup / t_width
                let t_depth  = 1
                let threadsPerThreadgroup = MTLSize(width: t_width, height: t_height, depth: t_depth)
                let threadgroupsPerGrid = MTLSize(width: (xCount + t_width - 1) / t_width,
                                                  height: (yCount + t_height - 1) / t_height,
                                                  depth: 1)
                
                
                // Metal Dispatch
                cmdEncoder.dispatchThreadgroups(threadgroupsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
                cmdEncoder.endEncoding()
                
                cmdBuf.commit()
                cmdBuf.waitUntilCompleted()
                
                
                // create cgImg for each channel
                
                guard let providerRef_0 = CGDataProvider(data: Data (bytes: outputBuffer_0!.contents(),
                                                                     count: MemoryLayout<UInt8>.stride * pxByteSize) as CFData),
                      let providerRef_1 = CGDataProvider(data: Data (bytes: outputBuffer_1!.contents(),
                                                                     count: MemoryLayout<UInt8>.stride * pxByteSize) as CFData),
                      let providerRef_2 = CGDataProvider(data: Data (bytes: outputBuffer_2!.contents(),
                                                                     count: MemoryLayout<UInt8>.stride * pxByteSize) as CFData),
                      let providerRef_3 = CGDataProvider(data: Data (bytes: outputBuffer_3!.contents(),
                                                                     count: MemoryLayout<UInt8>.stride * pxByteSize) as CFData)
                else {
                    return
                    
                }
                
                
                outputPx_0.deallocate()
                outputPx_1.deallocate()
                outputPx_2.deallocate()
                outputPx_3.deallocate()
                
                
                
                guard let img_0 = CGImage(
                    width: inTex.width,
                    height: inTex.height,
                    bitsPerComponent: 8,
                    bitsPerPixel: 8 ,
                    bytesPerRow: MemoryLayout<UInt8>.stride * inTex.width ,
                    space:  CGColorSpaceCreateDeviceGray(),
                    bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
                    provider: providerRef_0,
                    decode: nil,
                    shouldInterpolate: true,
                    intent: .defaultIntent),
                      let img_1 = CGImage(
                        width: inTex.width,
                        height: inTex.height,
                        bitsPerComponent: 8,
                        bitsPerPixel: 8 ,
                        bytesPerRow: MemoryLayout<UInt8>.stride * inTex.width ,
                        space:  CGColorSpaceCreateDeviceGray(),
                        bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
                        provider: providerRef_1,
                        decode: nil,
                        shouldInterpolate: true,
                        intent: .defaultIntent),
                      let img_2 = CGImage(
                        width: inTex.width,
                        height: inTex.height,
                        bitsPerComponent: 8,
                        bitsPerPixel: 8 ,
                        bytesPerRow: MemoryLayout<UInt8>.stride * inTex.width ,
                        space:  CGColorSpaceCreateDeviceGray(),
                        bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
                        provider: providerRef_2,
                        decode: nil,
                        shouldInterpolate: true,
                        intent: .defaultIntent),
                      let img_3 = CGImage(
                        width: inTex.width,
                        height: inTex.height,
                        bitsPerComponent: 8,
                        bitsPerPixel: 8 ,
                        bytesPerRow: MemoryLayout<UInt8>.stride * inTex.width ,
                        space:  CGColorSpaceCreateDeviceGray(),
                        bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
                        provider: providerRef_3,
                        decode: nil,
                        shouldInterpolate: true,
                        intent: .defaultIntent)
                else { return }
                
                let saveFileName = "z" + String(format: "%05d", sliceDepth) + ".tif"
                
                
                if(useChannel == -1){
                    guard let destination_0 = CGImageDestinationCreateWithURL(outDir_0.appendingPathComponent(saveFileName) as CFURL, kUTTypeTIFF, 1, nil),
                          let destination_1 = CGImageDestinationCreateWithURL(outDir_1.appendingPathComponent(saveFileName) as CFURL, kUTTypeTIFF, 1, nil),
                          let destination_2 = CGImageDestinationCreateWithURL(outDir_2.appendingPathComponent(saveFileName) as CFURL, kUTTypeTIFF, 1, nil),
                          let destination_3 = CGImageDestinationCreateWithURL(outDir_3.appendingPathComponent(saveFileName) as CFURL, kUTTypeTIFF, 1, nil)
                    else{
                        return
                    }
                    
                    CGImageDestinationAddImage(destination_0, img_0, nil)
                    CGImageDestinationAddImage(destination_1, img_1, nil)
                    CGImageDestinationAddImage(destination_2, img_2, nil)
                    CGImageDestinationAddImage(destination_3, img_3, nil)
                    
                    guard CGImageDestinationFinalize(destination_0) ,
                          CGImageDestinationFinalize(destination_1) ,
                          CGImageDestinationFinalize(destination_2) ,
                          CGImageDestinationFinalize(destination_3) else {
                        print("Failed to finalize CGImageDestination")
                        return
                    }
                }else if (useChannel == 0){
                    guard let destination_0 = CGImageDestinationCreateWithURL(outDir_0.appendingPathComponent(saveFileName) as CFURL, kUTTypeTIFF, 1, nil)
                    else{
                        return
                    }
                    
                    CGImageDestinationAddImage(destination_0, img_0, nil)
                    
                    guard CGImageDestinationFinalize(destination_0) else {
                        print("Failed to finalize CGImageDestination")
                        return
                    }
                }else if (useChannel == 1){
                    guard let destination_1 = CGImageDestinationCreateWithURL(outDir_1.appendingPathComponent(saveFileName) as CFURL, kUTTypeTIFF, 1, nil)
                    else{
                        return
                    }
                    
                    CGImageDestinationAddImage(destination_1, img_1, nil)
                    
                    guard CGImageDestinationFinalize(destination_1) else {
                        print("Failed to finalize CGImageDestination")
                        return
                    }
                }else if (useChannel == 2){
                    guard let destination_2 = CGImageDestinationCreateWithURL(outDir_2.appendingPathComponent(saveFileName) as CFURL, kUTTypeTIFF, 1, nil)
                    else{
                        return
                    }
                    
                    CGImageDestinationAddImage(destination_2, img_2, nil)
                    
                    guard CGImageDestinationFinalize(destination_2) else {
                        print("Failed to finalize CGImageDestination")
                        return
                    }
                }else if (useChannel == 3){
                    guard let destination_3 = CGImageDestinationCreateWithURL(outDir_3.appendingPathComponent(saveFileName) as CFURL, kUTTypeTIFF, 1, nil)
                    else{
                        return
                    }
                    
                    CGImageDestinationAddImage(destination_3, img_3, nil)
                    
                    guard CGImageDestinationFinalize(destination_3) else {
                        print("Failed to finalize CGImageDestination")
                        return
                    }
                }
                
                
            }
        }
        
        filePackage.openUrlInFinder(url: exportDir)
        
    }
    
    public func exportToTiffForEachChannelWithCurrentAngleAndSize(useChannel:Int, filePackage:FilePackage){
        var tmpRenderParams = renderParams
        
        guard let inTex = self.mainTexture else {
            Dialog.showDialog(message: "First load texture")
            return
        }
        
        // prepare dir
        guard let exportDir = filePackage.exportDir else {return}
        
        let outDir_0 = filePackage.createSubdirectoryForUrl(url: exportDir, directoryName: "current_angle_ch1")
        let outDir_1 = filePackage.createSubdirectoryForUrl(url: exportDir, directoryName: "current_angle_ch2")
        let outDir_2 = filePackage.createSubdirectoryForUrl(url: exportDir, directoryName: "current_angle_ch3")
        let outDir_3 = filePackage.createSubdirectoryForUrl(url: exportDir, directoryName: "current_angle_ch4")
        
        let drawingViewSize = renderParams.viewSize.toInt()
        
        guard let computeFunction = mtlLibrary.makeFunction(name: "separateChannel_MPR") else {
            print("error make function")
            return
        }
        computeFunction.label = MTL_label.export
        
        let pipelineDescriptor = MTLComputePipelineDescriptor()
        
        pipelineDescriptor.label = MTL_label.export
        pipelineDescriptor.computeFunction = computeFunction
        renderPipeline = try? device.makeComputePipelineState(descriptor: pipelineDescriptor, options: .argumentInfo, reflection: nil)
        
        
        for slice in 0..<tmpRenderParams.sliceMax {
            autoreleasepool{
                print(slice, tmpRenderParams.sliceMax - slice)
                tmpRenderParams.sliceNo = slice
                
                
                
                
                
                let cmdBuffer = cmdQueue.makeCommandBuffer()!
                cmdBuffer.label = MTL_label.export
                
                // Currently, Acto3D only supports Metal2's Argument Encoder.
                
                // create argument encoder
                let argumentEncoder = computeFunction.makeArgumentEncoder(bufferIndex: 0)
                argumentEncoder.label = "argument Encoder"
                let argumentBufferLength = argumentEncoder.encodedLength
                
                // create argument buffer
                let argumentBuffer = device.makeBuffer(length: argumentBufferLength, options: [])
                argumentBuffer?.label = "argument Buffer"
                
                argumentEncoder.setArgumentBuffer(argumentBuffer, offset: 0)
                
                argumentEncoder.setTexture(mainTexture, index: 0)
                
                
                let paramsBuffer = device.makeBuffer(bytes: &tmpRenderParams, length: MemoryLayout<RenderingParameters>.stride)
                argumentEncoder.setBuffer(paramsBuffer, offset: 0, index: 1)
                
                // bytes for output image (RGB image)
                let pxByteSize = drawingViewSize * drawingViewSize
                let outputPx_0 = UnsafeMutablePointer<UInt8>.allocate(capacity: pxByteSize)
                let outputPx_1 = UnsafeMutablePointer<UInt8>.allocate(capacity: pxByteSize)
                let outputPx_2 = UnsafeMutablePointer<UInt8>.allocate(capacity: pxByteSize)
                let outputPx_3 = UnsafeMutablePointer<UInt8>.allocate(capacity: pxByteSize)
                
                let outputBuffer_0 = device.makeBuffer(bytes: outputPx_0,
                                                     length: MemoryLayout<UInt8>.stride * pxByteSize,
                                                     options: .storageModeShared)
                let outputBuffer_1 = device.makeBuffer(bytes: outputPx_1,
                                                     length: MemoryLayout<UInt8>.stride * pxByteSize,
                                                     options: .storageModeShared)
                let outputBuffer_2 = device.makeBuffer(bytes: outputPx_2,
                                                     length: MemoryLayout<UInt8>.stride * pxByteSize,
                                                     options: .storageModeShared)
                let outputBuffer_3 = device.makeBuffer(bytes: outputPx_3,
                                                     length: MemoryLayout<UInt8>.stride * pxByteSize,
                                                     options: .storageModeShared)
                
                argumentEncoder.setBuffer(outputBuffer_0, offset: 0, index: 2)
                argumentEncoder.setBuffer(outputBuffer_1, offset: 0, index: 3)
                argumentEncoder.setBuffer(outputBuffer_2, offset: 0, index: 4)
                argumentEncoder.setBuffer(outputBuffer_3, offset: 0, index: 5)
                
                
                // Sampler Set
                let sampler = renderOption.contains(.SAMPLER_LINEAR) ? ImageProcessor.makeSampler(device: device, filter: .linear) : ImageProcessor.makeSampler(device: device, filter: .nearest)
                argumentEncoder.setSamplerState(sampler, index: 6)
                
                
                let cmdEncoder = cmdBuffer.makeComputeCommandEncoder()!
                cmdEncoder.setComputePipelineState(renderPipeline)
                cmdEncoder.label = "Rendering Command Encoder"
                
                // set usage of argument buffers
                cmdEncoder.useResource(mainTexture!, usage: .read )
                cmdEncoder.useResource(outputBuffer_0!, usage: .write)
                cmdEncoder.useResource(outputBuffer_1!, usage: .write)
                cmdEncoder.useResource(outputBuffer_2!, usage: .write)
                cmdEncoder.useResource(outputBuffer_3!, usage: .write)
                
                cmdEncoder.setBuffer(argumentBuffer, offset: 0, index: 0)
                
                var option:UInt16 = renderOption.rawValue
                cmdEncoder.setBytes(&option, length: MemoryLayout<UInt16>.stride, index: 2)
                
                cmdEncoder.setBytes(&quaternion, length: MemoryLayout<simd_quatf>.stride, index: 1)
                
                
                
                
                let width = renderPipeline.threadExecutionWidth
                let threads_in_group = renderPipeline.maxTotalThreadsPerThreadgroup
                let height = threads_in_group / width
                
                let threadsPerThreadgroup = MTLSize(width: width, height: height, depth: 1)
                
                let threadgroupsPerGrid = MTLSize(width: (drawingViewSize + width - 1) / width,
                                                  height: (drawingViewSize + height - 1) / height,
                                                  depth: 1)
                cmdEncoder.dispatchThreadgroups(threadgroupsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
                
                cmdEncoder.endEncoding()
                cmdBuffer.commit()
                cmdBuffer.waitUntilCompleted()
                
                
                
                
                
                
                // create cgImg for each channel
                
                guard let providerRef_0 = CGDataProvider(data: Data (bytes: outputBuffer_0!.contents(),
                                                                     count: MemoryLayout<UInt8>.stride * pxByteSize) as CFData),
                      let providerRef_1 = CGDataProvider(data: Data (bytes: outputBuffer_1!.contents(),
                                                                     count: MemoryLayout<UInt8>.stride * pxByteSize) as CFData),
                      let providerRef_2 = CGDataProvider(data: Data (bytes: outputBuffer_2!.contents(),
                                                                     count: MemoryLayout<UInt8>.stride * pxByteSize) as CFData),
                      let providerRef_3 = CGDataProvider(data: Data (bytes: outputBuffer_3!.contents(),
                                                                     count: MemoryLayout<UInt8>.stride * pxByteSize) as CFData)
                else {
                    return
                    
                }
                
                
                outputPx_0.deallocate()
                outputPx_1.deallocate()
                outputPx_2.deallocate()
                outputPx_3.deallocate()
                
                
                
                guard let img_0 = CGImage(
                    width: drawingViewSize,
                    height: drawingViewSize,
                    bitsPerComponent: 8,
                    bitsPerPixel: 8 ,
                    bytesPerRow: MemoryLayout<UInt8>.stride * drawingViewSize ,
                    space:  CGColorSpaceCreateDeviceGray(),
                    bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
                    provider: providerRef_0,
                    decode: nil,
                    shouldInterpolate: true,
                    intent: .defaultIntent),
                      let img_1 = CGImage(
                        width: drawingViewSize,
                        height: drawingViewSize,
                        bitsPerComponent: 8,
                        bitsPerPixel: 8 ,
                        bytesPerRow: MemoryLayout<UInt8>.stride * drawingViewSize ,
                        space:  CGColorSpaceCreateDeviceGray(),
                        bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
                        provider: providerRef_1,
                        decode: nil,
                        shouldInterpolate: true,
                        intent: .defaultIntent),
                      let img_2 = CGImage(
                        width: drawingViewSize,
                        height: drawingViewSize,
                        bitsPerComponent: 8,
                        bitsPerPixel: 8 ,
                        bytesPerRow: MemoryLayout<UInt8>.stride * drawingViewSize ,
                        space:  CGColorSpaceCreateDeviceGray(),
                        bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
                        provider: providerRef_2,
                        decode: nil,
                        shouldInterpolate: true,
                        intent: .defaultIntent),
                      let img_3 = CGImage(
                        width: drawingViewSize,
                        height: drawingViewSize,
                        bitsPerComponent: 8,
                        bitsPerPixel: 8 ,
                        bytesPerRow: MemoryLayout<UInt8>.stride * drawingViewSize ,
                        space:  CGColorSpaceCreateDeviceGray(),
                        bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
                        provider: providerRef_3,
                        decode: nil,
                        shouldInterpolate: true,
                        intent: .defaultIntent)
                else { return }
                
                let saveFileName = "z" + String(format: "%05d", tmpRenderParams.sliceNo) + ".tif"
                
                
                if(useChannel == -1){
                    guard let destination_0 = CGImageDestinationCreateWithURL(outDir_0.appendingPathComponent(saveFileName) as CFURL, kUTTypeTIFF, 1, nil),
                          let destination_1 = CGImageDestinationCreateWithURL(outDir_1.appendingPathComponent(saveFileName) as CFURL, kUTTypeTIFF, 1, nil),
                          let destination_2 = CGImageDestinationCreateWithURL(outDir_2.appendingPathComponent(saveFileName) as CFURL, kUTTypeTIFF, 1, nil),
                          let destination_3 = CGImageDestinationCreateWithURL(outDir_3.appendingPathComponent(saveFileName) as CFURL, kUTTypeTIFF, 1, nil)
                    else{
                        return
                    }
                    
                    CGImageDestinationAddImage(destination_0, img_0, nil)
                    CGImageDestinationAddImage(destination_1, img_1, nil)
                    CGImageDestinationAddImage(destination_2, img_2, nil)
                    CGImageDestinationAddImage(destination_3, img_3, nil)
                    
                    guard CGImageDestinationFinalize(destination_0) ,
                          CGImageDestinationFinalize(destination_1) ,
                          CGImageDestinationFinalize(destination_2) ,
                          CGImageDestinationFinalize(destination_3) else {
                        print("Failed to finalize CGImageDestination")
                        return
                    }
                }else if (useChannel == 0){
                    guard let destination_0 = CGImageDestinationCreateWithURL(outDir_0.appendingPathComponent(saveFileName) as CFURL, kUTTypeTIFF, 1, nil)
                    else{
                        return
                    }
                    
                    CGImageDestinationAddImage(destination_0, img_0, nil)
                    
                    guard CGImageDestinationFinalize(destination_0) else {
                        print("Failed to finalize CGImageDestination")
                        return
                    }
                }else if (useChannel == 1){
                    guard let destination_1 = CGImageDestinationCreateWithURL(outDir_1.appendingPathComponent(saveFileName) as CFURL, kUTTypeTIFF, 1, nil)
                    else{
                        return
                    }
                    
                    CGImageDestinationAddImage(destination_1, img_1, nil)
                    
                    guard CGImageDestinationFinalize(destination_1) else {
                        print("Failed to finalize CGImageDestination")
                        return
                    }
                }else if (useChannel == 2){
                    guard let destination_2 = CGImageDestinationCreateWithURL(outDir_2.appendingPathComponent(saveFileName) as CFURL, kUTTypeTIFF, 1, nil)
                    else{
                        return
                    }
                    
                    CGImageDestinationAddImage(destination_2, img_2, nil)
                    
                    guard CGImageDestinationFinalize(destination_2) else {
                        print("Failed to finalize CGImageDestination")
                        return
                    }
                }else if (useChannel == 3){
                    guard let destination_3 = CGImageDestinationCreateWithURL(outDir_3.appendingPathComponent(saveFileName) as CFURL, kUTTypeTIFF, 1, nil)
                    else{
                        return
                    }
                    
                    CGImageDestinationAddImage(destination_3, img_3, nil)
                    
                    guard CGImageDestinationFinalize(destination_3) else {
                        print("Failed to finalize CGImageDestination")
                        return
                    }
                }
                
                
                
                
            }
        }
        
        
        filePackage.openUrlInFinder(url: exportDir)
    }
}

