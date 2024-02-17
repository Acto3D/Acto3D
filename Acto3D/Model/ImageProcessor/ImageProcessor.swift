//
//  ImageProcessor.swift
//  Acto3D
//
//  Created by Naoki Takeshita on 2023/03/24.
//

import Foundation
import Metal
import Cocoa

class ImageProcessor{
    var counterBuffer: MTLBuffer?
    var device:MTLDevice!
    var cmdQueue:MTLCommandQueue!
    var lib:MTLLibrary!
    
    var totalCounter:Int?
    var counterPtr:UnsafeMutablePointer<Int32>?
    var cancelPtr:UnsafeMutablePointer<Bool>?
    
    init(device: MTLDevice, cmdQueue:MTLCommandQueue, lib:MTLLibrary){
        self.device = device
        self.cmdQueue = cmdQueue
        self.lib = lib
    }
    
    
    static func transferTextureToTexture(device: MTLDevice, cmdQueue:MTLCommandQueue, lib:MTLLibrary, texIn:MTLTexture, texOut:MTLTexture, channelIn:UInt8, channelOut:UInt8){
        
        guard let computeFunction = lib.makeFunction(name: "transferTextureToTexture") else {
            print("error make function")
            return
        }
        var renderPipeline: MTLComputePipelineState!
        
        renderPipeline = try? device.makeComputePipelineState(function: computeFunction)
        
        let cmdBuf = cmdQueue.makeCommandBuffer()!
        let computeSliceEncoder = cmdBuf.makeComputeCommandEncoder()!
        computeSliceEncoder.setComputePipelineState(renderPipeline)
        
        // Buffer set
        
        computeSliceEncoder.setTexture(texIn, index: 0)
        computeSliceEncoder.setTexture(texOut, index: 1)
        
        var channelIn:UInt8 = channelIn
        computeSliceEncoder.setBytes(&channelIn, length: MemoryLayout<UInt8>.stride, index: 0)
        
        var channelOut:UInt8 = channelOut
        computeSliceEncoder.setBytes(&channelOut, length: MemoryLayout<UInt8>.stride, index: 1)
        
        // Compute optimization
        let xCount = texIn.width
        let yCount = texIn.height
        let zCount = texIn.depth
        
        let maxTotalThreadsPerThreadgroup = renderPipeline.maxTotalThreadsPerThreadgroup
        let threadExecutionWidth          = renderPipeline.threadExecutionWidth
        let width  = threadExecutionWidth
        let height = 8
        let depth  = maxTotalThreadsPerThreadgroup / width / height
        let threadsPerThreadgroup = MTLSize(width: width, height: height, depth: depth)
        let threadgroupsPerGrid = MTLSize(width: (xCount + width - 1) / width,
                                          height: (yCount + height - 1) / height,
                                          depth: (zCount + depth - 1) / depth)
        
        // Metal Dispatch
        computeSliceEncoder.dispatchThreadgroups(threadgroupsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
        computeSliceEncoder.endEncoding()
        
        cmdBuf.commit()
        cmdBuf.waitUntilCompleted()
    }
    
//    static func transferChannelToTexture(device: MTLDevice, cmdQueue:MTLCommandQueue, lib:MTLLibrary, inTexture: MTLTexture, dstTexture: MTLTexture, dstChannel: UInt8){
//
//        guard let computeFunction = lib.makeFunction(name: "transferTextureToTexture") else {
//            print("error make function")
//            return
//        }
//        var renderPipeline: MTLComputePipelineState!
//
//        renderPipeline = try? device.makeComputePipelineState(function: computeFunction)
//
//        let cmdBuf = cmdQueue.makeCommandBuffer()!
//        let computeSliceEncoder = cmdBuf.makeComputeCommandEncoder()!
//        computeSliceEncoder.setComputePipelineState(renderPipeline)
//
//        // Sampler Set
//        let sampler = makeSampler(device: device)
//
//        // Buffer set
//
//        computeSliceEncoder.setTexture(inTexture, index: 0)
//        computeSliceEncoder.setTexture(dstTexture, index: 1)
//        computeSliceEncoder.setSamplerState(sampler, index: 0)
//
//        var channel:UInt8 = dstChannel
//        computeSliceEncoder.setBytes(&channel, length: MemoryLayout<UInt8>.stride, index: 0)
//
//
//        // Compute optimization
//        let xCount = inTexture.width
//        let yCount = inTexture.height
//        let zCount = inTexture.depth
//
//        let maxTotalThreadsPerThreadgroup = renderPipeline.maxTotalThreadsPerThreadgroup // 1024
//        let threadExecutionWidth          = renderPipeline.threadExecutionWidth // 32
//        let width  = threadExecutionWidth // 32
//        let height = 8
//        let depth  = maxTotalThreadsPerThreadgroup / width / height // 1024 / 32 / 8 = 4
//        let threadsPerThreadgroup = MTLSize(width: width, height: height, depth: depth) // MTLSize(width: 32, height: 8, depth: 4)
//        let threadgroupsPerGrid = MTLSize(width: (xCount + width - 1) / width,
//                                          height: (yCount + height - 1) / height,
//                                          depth: (zCount + depth - 1) / depth)
//
//
//        // Metal Dispatch
//        computeSliceEncoder.dispatchThreadgroups(threadgroupsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
//        computeSliceEncoder.endEncoding()
//
//        cmdBuf.commit()
//        cmdBuf.waitUntilCompleted()
//
//    }
    
    static func makeSampler(device: MTLDevice, filter: MTLSamplerMinMagFilter = .linear) -> MTLSamplerState{
        let samplerDescriptor = MTLSamplerDescriptor()
        samplerDescriptor.sAddressMode = .clampToZero
        samplerDescriptor.tAddressMode = .clampToZero
        samplerDescriptor.minFilter = filter
        samplerDescriptor.magFilter = filter
        samplerDescriptor.supportArgumentBuffers = true
        
        return device.makeSamplerState(descriptor: samplerDescriptor)!
    }
    
    public func applyFilter_Gaussian3D(inTexture:MTLTexture, k_size: UInt8, sigma: Float = 1.8, channel: Int, completion: @escaping (MTLTexture?) -> Void) {

        guard let computeFunction = lib.makeFunction(name: "applyFilter_gaussian3D") else {
            print("error make function")
            completion(nil)
            return
        }
        
        var pipeline:MTLComputePipelineState!
        do{
            let pipelineDescriptor = MTLComputePipelineDescriptor()
            pipelineDescriptor.label = MTL_label.applyFilter_gaussian3D
            pipelineDescriptor.computeFunction = computeFunction
            pipeline = try device.makeComputePipelineState(descriptor: pipelineDescriptor, options: [], reflection: nil)
            
        }catch{
            Dialog.showDialog(message: "Error in creating metal pipeline for gaussian3D")
            completion(nil)
            return
        }
        
        let cmdBuf = cmdQueue.makeCommandBuffer()!
        cmdBuf.label = "Apply Filter"
        
        let computeEncoder = cmdBuf.makeComputeCommandEncoder()!
        computeEncoder.setComputePipelineState(pipeline)
        
        // Sampler Set
        let sampler = device.makeSampler(filter: .linear)
        
        // Output Texture
        let texOut = channel == -1 ?
        inTexture.createNewTextureWithSameSize(pixelFormat: .bgra8Unorm) : inTexture.createNewTextureWithSameSize(pixelFormat: inTexture.pixelFormat)!
        
        computeEncoder.setTexture(inTexture, index: 0)
        computeEncoder.setTexture(texOut, index: 1)
        
        var k_size = k_size
        var channel = channel
        
        // create 3D kernal (as 1D array)
        let half_kernel_size = k_size.toInt() / 2
        var kernel_weights = [Float](repeating: 0, count: k_size.toInt() * k_size.toInt() * k_size.toInt())
        var sum: Float = 0
        for i in -half_kernel_size...half_kernel_size {
            for j in -half_kernel_size...half_kernel_size {
                for k in -half_kernel_size...half_kernel_size {
                    let idx = (i + half_kernel_size) * Int(k_size) * Int(k_size) + (j + half_kernel_size) * Int(k_size) + (k + half_kernel_size)
                    kernel_weights[idx] = exp(-(Float(i * i + j * j + k * k)) / (2.0 * sigma * sigma))
                    sum += kernel_weights[idx]
                }
            }
        }
        for i in 0..<(k_size.toInt() * k_size.toInt() * k_size.toInt()) {
            kernel_weights[Int(i)] /= sum
        }
        
        let weightsBuffer = device.makeBuffer(bytes: &kernel_weights, length: MemoryLayout<Float>.size * kernel_weights.count, options: [])
        computeEncoder.setBuffer(weightsBuffer, offset: 0, index: 0)
        
        computeEncoder.setBytes(&k_size, length: MemoryLayout<UInt8>.stride, index: 1)
        computeEncoder.setBytes(&channel, length: MemoryLayout<Int>.stride, index: 2)
        computeEncoder.setSamplerState(sampler, index: 0)
        
        
        // global counter buffer
        var globalCounterValue: Int32 = 0
        let globalCounterBuffer = device.makeBuffer(bytes: &globalCounterValue,
                                                    length: MemoryLayout<Int32>.size,
                                                    options: .storageModeShared)

        computeEncoder.setBuffer(globalCounterBuffer, offset: 0, index: 3)
        
        var isCancel = false
        let isCancelBuffer = device.makeBuffer(bytes: &isCancel,
                                                    length: MemoryLayout<Bool>.size,
                                                    options: .storageModeShared)
        cancelPtr = isCancelBuffer?.contents().bindMemory(to: Bool.self, capacity: 1)
        computeEncoder.setBuffer(isCancelBuffer, offset: 0, index: 4)
//         threadgroup memory
//         let localCounterSize = MemoryLayout<Int32>.size
        computeEncoder.setThreadgroupMemoryLength(16, index: 0) // multiple of 16
        
        // Compute optimization
        let xCount = inTexture.width
        let yCount = inTexture.height
        let zCount = inTexture.depth
        let maxTotalThreadsPerThreadgroup = pipeline.maxTotalThreadsPerThreadgroup
        let threadExecutionWidth          = pipeline.threadExecutionWidth
        let width  = threadExecutionWidth
        let height = 8
        let depth  = maxTotalThreadsPerThreadgroup / width / height
        let threadsPerThreadgroup = MTLSize(width: width, height: height, depth: depth) 
        let threadgroupsPerGrid = MTLSize(width: (xCount + width - 1) / width,
                                          height: (yCount + height - 1) / height,
                                          depth: (zCount + depth - 1) / depth)
        
        
        // counter setting
        totalCounter = threadgroupsPerGrid.width * threadgroupsPerGrid.height * threadgroupsPerGrid.depth
        counterPtr = globalCounterBuffer?.contents().bindMemory(to: Int32.self, capacity: 1)
        
        // Metal Dispatch
        computeEncoder.dispatchThreadgroups(threadgroupsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
        computeEncoder.endEncoding()
        
        
        // Completion Handler
        cmdBuf.addCompletedHandler { _ in
            // Call the completion handler with the output texture
            completion(texOut)
        }
        
        cmdBuf.commit()
     
        
    }
    
    
    public func applyFilter_Median3D_QuickSelect(inTexture:MTLTexture, k_size: UInt8, channel: Int, completion: @escaping (MTLTexture?) -> Void) {

        guard let computeFunction = lib.makeFunction(name: "applyFilter_median3D") else {
            print("error make function")
            completion(nil)
            return
        }
        
        var pipeline:MTLComputePipelineState!
        do{
            let pipelineDescriptor = MTLComputePipelineDescriptor()
            pipelineDescriptor.label = MTL_label.applyFilter_median3D
            pipelineDescriptor.computeFunction = computeFunction
            pipeline = try device.makeComputePipelineState(descriptor: pipelineDescriptor, options: [], reflection: nil)
            
        }catch{
            Dialog.showDialog(message: "Error in creating metal pipeline for gaussian3D")
            completion(nil)
            return
        }
        
        let cmdBuf = cmdQueue.makeCommandBuffer()!
        cmdBuf.label = "Apply Filter"
        
        let computeEncoder = cmdBuf.makeComputeCommandEncoder()!
        computeEncoder.setComputePipelineState(pipeline)
        
        // Sampler Set
        // let sampler = device.makeSampler(filter: .linear)
        
        // Output Texture
        let texOut = channel == -1 ? inTexture.createNewTextureWithSameSize(pixelFormat: .bgra8Unorm) : inTexture.createNewTextureWithSameSize(pixelFormat: .r8Unorm)!
        
        computeEncoder.setTexture(inTexture, index: 0)
        computeEncoder.setTexture(texOut, index: 1)
        
        var k_size = k_size
        var channel = channel
        
        computeEncoder.setBytes(&k_size, length: MemoryLayout<UInt8>.stride, index: 0)
        computeEncoder.setBytes(&channel, length: MemoryLayout<Int>.stride, index: 1)
        
        var globalCounterValue: Int32 = 0
        let globalCounterBuffer = device.makeBuffer(bytes: &globalCounterValue,
                                                    length: MemoryLayout<Int32>.size,
                                                    options: .storageModeShared)

        computeEncoder.setBuffer(globalCounterBuffer, offset: 0, index: 2)
        
        var isCancel = false
        let isCancelBuffer = device.makeBuffer(bytes: &isCancel,
                                                    length: MemoryLayout<Bool>.size,
                                                    options: .storageModeShared)
        cancelPtr = isCancelBuffer?.contents().bindMemory(to: Bool.self, capacity: 1)
        computeEncoder.setBuffer(isCancelBuffer, offset: 0, index: 3)
        
        
        computeEncoder.setThreadgroupMemoryLength(16, index: 0)
        
        // Compute optimization
        let xCount = inTexture.width
        let yCount = inTexture.height
        let zCount = inTexture.depth
        let maxTotalThreadsPerThreadgroup = pipeline.maxTotalThreadsPerThreadgroup
        let threadExecutionWidth          = pipeline.threadExecutionWidth
        let width  = threadExecutionWidth
        let height = 8
        let depth  = maxTotalThreadsPerThreadgroup / width / height
        let threadsPerThreadgroup = MTLSize(width: width, height: height, depth: depth)
        let threadgroupsPerGrid = MTLSize(width: (xCount + width - 1) / width,
                                          height: (yCount + height - 1) / height,
                                          depth: (zCount + depth - 1) / depth)
        
        print("Thread for gaussian", threadsPerThreadgroup, "threadgroupsPerGrid", threadgroupsPerGrid)
        
        // counter setting
        totalCounter = threadgroupsPerGrid.width * threadgroupsPerGrid.height * threadgroupsPerGrid.depth
        counterPtr = globalCounterBuffer?.contents().bindMemory(to: Int32.self, capacity: 1)
        
        // Metal Dispatch
        computeEncoder.dispatchThreadgroups(threadgroupsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
        computeEncoder.endEncoding()
        
        
        // Completion Handler
        cmdBuf.addCompletedHandler { _ in
            // Call the completion handler with the output texture
            completion(texOut)
        }
        
        
        cmdBuf.commit()
        
    }
    
    
    
    public func applyFilter_binarizationWithThreshold(inTexture:MTLTexture, threshold: UInt8, channel: Int, invert: Bool, completion: @escaping (MTLTexture?) -> Void) {

        guard let computeFunction = lib.makeFunction(name: "applyFilter_binarizationWithThreshold") else {
            print("error make function")
            completion(nil)
            return
        }
        
        var pipeline:MTLComputePipelineState!
        do{
            let pipelineDescriptor = MTLComputePipelineDescriptor()
            pipelineDescriptor.label = MTL_label.applyFilter_median3D
            pipelineDescriptor.computeFunction = computeFunction
            pipeline = try device.makeComputePipelineState(descriptor: pipelineDescriptor, options: [], reflection: nil)
            
        }catch{
            Dialog.showDialog(message: "Error in creating metal pipeline for binarizationWithThreshold")
            completion(nil)
            return
        }
        
        let cmdBuf = cmdQueue.makeCommandBuffer()!
        cmdBuf.label = "Apply Filter"
        
        let computeEncoder = cmdBuf.makeComputeCommandEncoder()!
        computeEncoder.setComputePipelineState(pipeline)
        
        // Sampler Set
        // let sampler = device.makeSampler(filter: .linear)
        
        // Output Texture
        let texOut = channel == -1 ? inTexture.createNewTextureWithSameSize(pixelFormat: .bgra8Unorm) : inTexture.createNewTextureWithSameSize(pixelFormat: .r8Unorm)!
        
        computeEncoder.setTexture(inTexture, index: 0)
        computeEncoder.setTexture(texOut, index: 1)
        
        var threshold = threshold
        var channel = channel
        var invert = invert
        
        computeEncoder.setBytes(&threshold, length: MemoryLayout<UInt8>.stride, index: 0)
        computeEncoder.setBytes(&channel, length: MemoryLayout<Int>.stride, index: 1)
        computeEncoder.setBytes(&invert, length: MemoryLayout<Bool>.stride, index: 2)
        
        var globalCounterValue: Int32 = 0
        let globalCounterBuffer = device.makeBuffer(bytes: &globalCounterValue,
                                                    length: MemoryLayout<Int32>.size,
                                                    options: .storageModeShared)

        computeEncoder.setBuffer(globalCounterBuffer, offset: 0, index: 3)
        
        var isCancel = false
        let isCancelBuffer = device.makeBuffer(bytes: &isCancel,
                                                    length: MemoryLayout<Bool>.size,
                                                    options: .storageModeShared)
        cancelPtr = isCancelBuffer?.contents().bindMemory(to: Bool.self, capacity: 1)
        computeEncoder.setBuffer(isCancelBuffer, offset: 0, index: 4)
        
        computeEncoder.setThreadgroupMemoryLength(16, index: 0)
        
        // Compute optimization
        let xCount = inTexture.width
        let yCount = inTexture.height
        let zCount = inTexture.depth
        let maxTotalThreadsPerThreadgroup = pipeline.maxTotalThreadsPerThreadgroup
        let threadExecutionWidth          = pipeline.threadExecutionWidth
        let width  = threadExecutionWidth
        let height = 8
        let depth  = maxTotalThreadsPerThreadgroup / width / height
        let threadsPerThreadgroup = MTLSize(width: width, height: height, depth: depth)
        let threadgroupsPerGrid = MTLSize(width: (xCount + width - 1) / width,
                                          height: (yCount + height - 1) / height,
                                          depth: (zCount + depth - 1) / depth)
        
        print("Thread for gaussian", threadsPerThreadgroup, "threadgroupsPerGrid", threadgroupsPerGrid)
        
        // counter setting
        totalCounter = threadgroupsPerGrid.width * threadgroupsPerGrid.height * threadgroupsPerGrid.depth
        counterPtr = globalCounterBuffer?.contents().bindMemory(to: Int32.self, capacity: 1)
        
        // Metal Dispatch
        computeEncoder.dispatchThreadgroups(threadgroupsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
        computeEncoder.endEncoding()
        
        
        // Completion Handler
        cmdBuf.addCompletedHandler { _ in
            // Call the completion handler with the output texture
            completion(texOut)
        }
        
        
        cmdBuf.commit()
        
    }
    
    
    public func applyFilter_calculateHistogramSliceBySlice(inTexture:MTLTexture, channel: Int, invert: Bool, completion: @escaping (MTLTexture?) -> Void) {

        guard let computeFunction = lib.makeFunction(name: "computeHistogramSliceBySlice") else {
            print("error make function")
            completion(nil)
            return
        }
        
        var pipeline:MTLComputePipelineState!
        do{
            let pipelineDescriptor = MTLComputePipelineDescriptor()
            pipelineDescriptor.label = MTL_label.applyFilter_median3D
            pipelineDescriptor.computeFunction = computeFunction
            pipeline = try device.makeComputePipelineState(descriptor: pipelineDescriptor, options: [], reflection: nil)
            
        }catch{
            Dialog.showDialog(message: "Error in creating metal pipeline for computeHistogramSliceBySlice")
            completion(nil)
            return
        }
        
        var cmdBuf = cmdQueue.makeCommandBuffer()!
        cmdBuf.label = "Apply Filter"
        
        var computeEncoder = cmdBuf.makeComputeCommandEncoder()!
        computeEncoder.setComputePipelineState(pipeline)
        
        
        
        print("Create a buffer for retain histogram data")
        let histogramSize = 256 * inTexture.depth
        let histogramBuffer = self.device.makeBuffer(length: histogramSize * MemoryLayout<UInt32>.size, options: .storageModeShared)
        histogramBuffer?.label = "Buffer for histogram"
        
        computeEncoder.setTexture(inTexture, index: 0)
        
        var channel: UInt8 = UInt8(channel)
        computeEncoder.setBytes(&channel, length: MemoryLayout<UInt8>.stride, index: 0)
        computeEncoder.setBuffer(histogramBuffer, offset: 0, index: 1)
        
        
        if(device.checkNonUniformThreadgroup() == true){
            let threadGroupSize = MTLSizeMake(pipeline.threadExecutionWidth, pipeline.maxTotalThreadsPerThreadgroup / pipeline.threadExecutionWidth, 1)
            computeEncoder.dispatchThreads(MTLSize(width: inTexture.width,
                                                   height: inTexture.height,
                                                   depth: inTexture.depth),
                                           threadsPerThreadgroup: threadGroupSize)
            
        }else{
            let threadGroupSize = MTLSize(width: pipeline.threadExecutionWidth,
                                          height: pipeline.maxTotalThreadsPerThreadgroup / pipeline.threadExecutionWidth,
                                          depth: 1)
            let threadGroups = MTLSize(width: (inTexture.width + threadGroupSize.width - 1) / threadGroupSize.width,
                                       height: (inTexture.height + threadGroupSize.height - 1) / threadGroupSize.height,
                                       depth: inTexture.depth)
            computeEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)
            
        }
        
        computeEncoder.endEncoding()
        
        cmdBuf.commit()
        cmdBuf.waitUntilCompleted()
        
        
        print("Get histogram")
        
        var histogramPerDepth: [[UInt32]] = []
        
        for i in 0..<inTexture.depth{
            
            let bins = 256
            let channelSize = bins * MemoryLayout<UInt32>.size
            let histogramData = UnsafeMutablePointer<UInt32>.allocate(capacity: bins)
            
            let offset = i * channelSize
            memcpy(histogramData, histogramBuffer!.contents().advanced(by: offset), channelSize)
            
            let histogramForThisChannel = Array(UnsafeBufferPointer(start: histogramData, count: bins))
            histogramPerDepth.append(histogramForThisChannel)
            
            histogramData.deallocate()
        }
        
        
        var threshold_otsu:[UInt8] = []
        for i in 0..<inTexture.depth{
            threshold_otsu.append(calculateThreshold_Otsu(histogram: histogramPerDepth[i], totalPixels: inTexture.width * inTexture.height))
        }
        
        print(threshold_otsu)
        
        
        
        
        
        
        guard let computeFunction2 = lib.makeFunction(name: "applyFilter_binarizationWithThresholdSeries") else {
            print("error make function")
            completion(nil)
            return
        }
        
        var pipeline2:MTLComputePipelineState!
        do{
            let pipelineDescriptor = MTLComputePipelineDescriptor()
            pipelineDescriptor.label = MTL_label.other
            pipelineDescriptor.computeFunction = computeFunction2
            pipeline2 = try device.makeComputePipelineState(descriptor: pipelineDescriptor, options: [], reflection: nil)
            
        }catch{
            Dialog.showDialog(message: "Error in creating metal pipeline for computeHistogramSliceBySlice")
            completion(nil)
            return
        }
        
        var cmdBuf2 = cmdQueue.makeCommandBuffer()!
        cmdBuf2.label = "Apply Filter"
        
        var computeEncoder2 = cmdBuf2.makeComputeCommandEncoder()!
        computeEncoder2.setComputePipelineState(pipeline2)
        
        // Sampler Set
        // let sampler = device.makeSampler(filter: .linear)
        
        // Output Texture
        let texOut = inTexture.createNewTextureWithSameSize(pixelFormat: .r8Unorm)!
        
        computeEncoder2.setTexture(inTexture, index: 0)
        computeEncoder2.setTexture(texOut, index: 1)
        
        
        var invert = invert
        
        computeEncoder2.setBytes(&threshold_otsu, length: MemoryLayout<UInt8>.stride * threshold_otsu.count, index: 0)
        computeEncoder2.setBytes(&channel, length: MemoryLayout<UInt8>.stride, index: 1)
        computeEncoder2.setBytes(&invert, length: MemoryLayout<Bool>.stride, index: 2)
        
        var globalCounterValue: Int32 = 0
        let globalCounterBuffer = device.makeBuffer(bytes: &globalCounterValue,
                                                    length: MemoryLayout<Int32>.size,
                                                    options: .storageModeShared)

        computeEncoder2.setBuffer(globalCounterBuffer, offset: 0, index: 3)
        
        var isCancel = false
        let isCancelBuffer = device.makeBuffer(bytes: &isCancel,
                                                    length: MemoryLayout<Bool>.size,
                                                    options: .storageModeShared)
        cancelPtr = isCancelBuffer?.contents().bindMemory(to: Bool.self, capacity: 1)
        computeEncoder2.setBuffer(isCancelBuffer, offset: 0, index: 4)
        
        computeEncoder2.setThreadgroupMemoryLength(16, index: 0)
        
        // Compute optimization
        let xCount = inTexture.width
        let yCount = inTexture.height
        let zCount = inTexture.depth
        let maxTotalThreadsPerThreadgroup = pipeline.maxTotalThreadsPerThreadgroup
        let threadExecutionWidth          = pipeline.threadExecutionWidth
        let width  = threadExecutionWidth
        let height = 8
        let depth  = maxTotalThreadsPerThreadgroup / width / height
        let threadsPerThreadgroup = MTLSize(width: width, height: height, depth: depth)
        let threadgroupsPerGrid = MTLSize(width: (xCount + width - 1) / width,
                                          height: (yCount + height - 1) / height,
                                          depth: (zCount + depth - 1) / depth)
        
        
        // counter setting
        totalCounter = threadgroupsPerGrid.width * threadgroupsPerGrid.height * threadgroupsPerGrid.depth
        counterPtr = globalCounterBuffer?.contents().bindMemory(to: Int32.self, capacity: 1)
        
        // Metal Dispatch
        computeEncoder2.dispatchThreadgroups(threadgroupsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
        computeEncoder2.endEncoding()
        
        
        // Completion Handler
        cmdBuf2.addCompletedHandler { _ in
            // Call the completion handler with the output texture
            completion(texOut)
        }
        
        
        cmdBuf2.commit()
        
        
    }
    
    
    
    public func calculateThreshold_Otsu(histogram: [UInt32], totalPixels:Int) -> UInt8{
        let histogram: [Int] = histogram.map { Int($0) }
        print(histogram)
        
        var sum: Int64 = 0
        var sumB: Int64 = 0
        var wB = 0
        var wF = 0
        var mB: Float = 0
        var mF: Float = 0
        var maxVariance: Float = 0
        var threshold: UInt8 = 0
        
        print("total pixels", totalPixels)
        
        for i in 0..<histogram.count {
            sum += Int64(i) * Int64(histogram[i])
        }
        
        for t in 0..<256 {
            wB += histogram[t]      // Weight Background
            if wB == 0 { continue }
            
            wF = totalPixels - wB   // Weight Foreground
            if wF == 0 { break }
            
            sumB += Int64(t) * Int64(histogram[t])
            
            mB = Float(sumB) / Float(wB)        // Mean Background
            mF = Float(sum - sumB) / Float(wF)  // Mean Foreground
            
            // Between Class Variance
            let variance = Float(wB) * Float(wF) * (mB - mF) * (mB - mF)
            
            // Check if new maximum found
            if variance > maxVariance {
                maxVariance = variance
                threshold = UInt8(t)
            }
        }
        
        print("threshold", threshold)
        return threshold
    }
    
    
    /*
    public func applyFilter_Median3D(inTexture:MTLTexture, k_size: UInt8, channel: Int, completion: @escaping (MTLTexture?) -> Void) {

        guard let computeFunction = lib.makeFunction(name: "applyFilter_median3D") ,
        let computeTransferFunction = lib.makeFunction(name: "transfer_FloatToTexture")
        else {
            print("error make function")
            completion(nil)
            return
        }
        
        var pipeline:MTLComputePipelineState!
        var pipelineTransfer:MTLComputePipelineState!
        do{
            let pipelineDescriptor = MTLComputePipelineDescriptor()
            pipelineDescriptor.label = MTL_label.applyFilter_gaussian3D
            pipelineDescriptor.computeFunction = computeFunction
            pipeline = try device.makeComputePipelineState(descriptor: pipelineDescriptor, options: [], reflection: nil)
            
            let pipelineTransferDescriptor = MTLComputePipelineDescriptor()
            pipelineTransferDescriptor.label = MTL_label.transfer_Float
            pipelineTransferDescriptor.computeFunction = computeTransferFunction
            pipelineTransfer = try device.makeComputePipelineState(descriptor: pipelineTransferDescriptor, options: [], reflection: nil)
            
        }catch{
            Dialog.showDialog(message: "Error in creating metal pipeline for Median 3D")
            completion(nil)
            return
        }
        
        
        var k_size: UInt8 = k_size
        let k_cube: Int = k_size.toInt() * k_size.toInt() * k_size.toInt()
        var channel = channel
        
        
        let floatMemoryNeededSize = MemoryLayout<Float>.stride * inTexture.width * inTexture.height * k_cube
        let outputBuffer0 = device.makeBuffer(length: channel == -1 || channel == 0 ? floatMemoryNeededSize : 4,
                                             options: [.storageModeShared])!
        let outputBuffer1 = device.makeBuffer(length: channel == -1 || channel == 1 ? floatMemoryNeededSize : 4,
                                             options: [.storageModeShared])!
        let outputBuffer2 = device.makeBuffer(length: channel == -1 || channel == 2 ? floatMemoryNeededSize : 4,
                                             options: [.storageModeShared])!
        let outputBuffer3 = device.makeBuffer(length: channel == -1 || channel == 3 ? floatMemoryNeededSize : 4,
                                             options: [.storageModeShared])!
        let outputBufferPtr0 = outputBuffer0.contents()
        let outputBufferPtr1 = outputBuffer1.contents()
        let outputBufferPtr2 = outputBuffer2.contents()
        let outputBufferPtr3 = outputBuffer3.contents()
        print(floatMemoryNeededSize.toFloat() / 1024, "kB", MemoryLayout<Float>.stride)
        
        self.totalCounter = inTexture.depth
        // バッファーの作成
        var globalCounterValue: Int32 = 0
        let globalCounterBuffer = device.makeBuffer(bytes: &globalCounterValue,
                                                    length: MemoryLayout<Int32>.size,
                                                    options: .storageModeShared)
        counterPtr = globalCounterBuffer?.contents().bindMemory(to: Int32.self, capacity: 1)
        
        // Compute optimization
        let xCount = inTexture.width
        let yCount = inTexture.height
        let width  = pipeline.threadExecutionWidth
        let height = pipeline.maxTotalThreadsPerThreadgroup / width
        
        let width_transfer  = pipelineTransfer.threadExecutionWidth
        let height_transfer = pipelineTransfer.maxTotalThreadsPerThreadgroup / width_transfer
        
        let threadsPerThreadgroup = MTLSize(width: width,
                                            height: height,
                                            depth: 1)
        let threadgroupsPerGrid = MTLSize(width: (xCount + width - 1) / width,
                                          height: (yCount + height - 1) / height,
                                          depth: 1)
        let threadsPerThreadgroup_transfer = MTLSize(width: width_transfer,
                                                     height: height_transfer,
                                                     depth: 1)
        let threadgroupsPerGrid_transfer = MTLSize(width: (xCount + width_transfer - 1) / width_transfer,
                                                   height: (yCount + height_transfer - 1) / height_transfer,
                                                   depth: 1)
        
        // Sampler Set
        let sampler = device.makeSampler(filter: .linear)
        // Output Texture
        let texOut = channel == -1 ? inTexture.createNewTextureWithSameSize(pixelFormat: .bgra8Unorm) : inTexture.createNewTextureWithSameSize(pixelFormat: .r8Unorm)!
        
        // cancel buffer
        var isCancel = false
        let isCancelBuffer = device.makeBuffer(bytes: &isCancel,
                                                    length: MemoryLayout<Bool>.size,
                                                    options: .storageModeShared)
        cancelPtr = isCancelBuffer?.contents().bindMemory(to: Bool.self, capacity: 1)
        
        autoreleasepool{
            
            for z in 0..<inTexture.depth{
                if(isCanceled() == true){
                    break
                }
                
                counterPtr?.pointee = Int32(z)
                
                let cmdBuf = cmdQueue.makeCommandBuffer()!
                cmdBuf.label = "Apply Filter"
                let computeEncoder = cmdBuf.makeComputeCommandEncoder()!
                computeEncoder.setComputePipelineState(pipeline)
                
                computeEncoder.setTexture(inTexture, index: 0)
                computeEncoder.setSamplerState(sampler, index: 0)
                computeEncoder.setBytes(&k_size, length: MemoryLayout<UInt8>.stride, index: 0)
                computeEncoder.setBytes(&channel, length: MemoryLayout<Int>.stride, index: 1)
                computeEncoder.setBuffer(globalCounterBuffer, offset: 0, index: 2)
                computeEncoder.setBuffer(outputBuffer0, offset: 0, index: 3)
                computeEncoder.setBuffer(outputBuffer1, offset: 0, index: 4)
                computeEncoder.setBuffer(outputBuffer2, offset: 0, index: 5)
                computeEncoder.setBuffer(outputBuffer3, offset: 0, index: 6)
                
                // Metal Dispatch
                computeEncoder.dispatchThreadgroups(threadgroupsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
                computeEncoder.endEncoding()
                cmdBuf.commit()
                cmdBuf.waitUntilCompleted()
                
                // Create median array
                let queue = DispatchQueue(label: "com.ntakeshita.Acto3D", attributes: .concurrent)
                let group = DispatchGroup()
                
                let output0 = UnsafeMutablePointer<Float>.allocate(capacity: inTexture.width * inTexture.height)
                let output1 = UnsafeMutablePointer<Float>.allocate(capacity: inTexture.width * inTexture.height)
                let output2 = UnsafeMutablePointer<Float>.allocate(capacity: inTexture.width * inTexture.height)
                let output3 = UnsafeMutablePointer<Float>.allocate(capacity: inTexture.width * inTexture.height)
                
                queue.async(group: group) {
                    DispatchQueue.concurrentPerform(iterations: inTexture.width) { x in
                        DispatchQueue.concurrentPerform(iterations: inTexture.height) { y in
                            if(channel == -1){
                                let pxArray0 = outputBufferPtr0.advanced(by: MemoryLayout<Float>.stride * (inTexture.width * y + x) * k_cube).bindMemory(to: Float.self, capacity: k_cube)
                                let floatArray0 = Array(UnsafeBufferPointer(start: pxArray0, count: k_cube))
                                let median0: Float = floatArray0.sorted()[k_cube / 2]
                                
                                let pxArray1 = outputBufferPtr1.advanced(by: MemoryLayout<Float>.stride * (inTexture.width * y + x) * k_cube).bindMemory(to: Float.self, capacity: k_cube)
                                let floatArray1 = Array(UnsafeBufferPointer(start: pxArray1, count: k_cube))
                                let median1: Float = floatArray1.sorted()[k_cube / 2]
                                
                                let pxArray2 = outputBufferPtr2.advanced(by: MemoryLayout<Float>.stride * (inTexture.width * y + x) * k_cube).bindMemory(to: Float.self, capacity: k_cube)
                                let floatArray2 = Array(UnsafeBufferPointer(start: pxArray2, count: k_cube))
                                let median2: Float = floatArray2.sorted()[k_cube / 2]
                                
                                let pxArray3 = outputBufferPtr3.advanced(by: MemoryLayout<Float>.stride * (inTexture.width * y + x) * k_cube).bindMemory(to: Float.self, capacity: k_cube)
                                let floatArray3 = Array(UnsafeBufferPointer(start: pxArray3, count: k_cube))
                                let median3: Float = floatArray3.sorted()[k_cube / 2]
                                
                                output0[y * inTexture.width + x] = median0
                                output1[y * inTexture.width + x] = median1
                                output2[y * inTexture.width + x] = median2
                                output3[y * inTexture.width + x] = median3
                                
                            }else if(channel == 0){
                                let pxArray0 = outputBufferPtr0.advanced(by: MemoryLayout<Float>.stride * (inTexture.width * y + x) * k_cube).bindMemory(to: Float.self, capacity: k_cube)
                                let floatArray0 = Array(UnsafeBufferPointer(start: pxArray0, count: k_cube))
                                let median0: Float = floatArray0.sorted()[k_cube / 2]
                                
                                output0[y * inTexture.width + x] = median0
                                
                            }else if(channel == 1){
                                let pxArray1 = outputBufferPtr1.advanced(by: MemoryLayout<Float>.stride * (inTexture.width * y + x) * k_cube).bindMemory(to: Float.self, capacity: k_cube)
                                let floatArray1 = Array(UnsafeBufferPointer(start: pxArray1, count: k_cube))
                                let median1: Float = floatArray1.sorted()[k_cube / 2]
                                
                                output1[y * inTexture.width + x] = median1
                                
                            }else if(channel == 2){
                                let pxArray2 = outputBufferPtr2.advanced(by: MemoryLayout<Float>.stride * (inTexture.width * y + x) * k_cube).bindMemory(to: Float.self, capacity: k_cube)
                                let floatArray2 = Array(UnsafeBufferPointer(start: pxArray2, count: k_cube))
                                let median2: Float = floatArray2.sorted()[k_cube / 2]
                                
                                output2[y * inTexture.width + x] = median2
                                
                            }else if(channel == 3){
                                let pxArray3 = outputBufferPtr3.advanced(by: MemoryLayout<Float>.stride * (inTexture.width * y + x) * k_cube).bindMemory(to: Float.self, capacity: k_cube)
                                let floatArray3 = Array(UnsafeBufferPointer(start: pxArray3, count: k_cube))
                                let median3: Float = floatArray3.sorted()[k_cube / 2]
                                
                                output3[y * inTexture.width + x] = median3
                                
                            }
                        }
                    }
                }
                
                group.wait()
                
                let buffer0 = device.makeBuffer(bytesNoCopy: UnsafeMutableRawPointer(output0),
                                                length: inTexture.width * inTexture.height * MemoryLayout<Float>.size,
                                                options: .storageModeShared) { pointer, _ in
                    pointer.deallocate()
                }
                let buffer1 = device.makeBuffer(bytesNoCopy: UnsafeMutableRawPointer(output1),
                                                length: inTexture.width * inTexture.height * MemoryLayout<Float>.size,
                                                options: .storageModeShared) { pointer, _ in
                    pointer.deallocate()
                }
                let buffer2 = device.makeBuffer(bytesNoCopy: UnsafeMutableRawPointer(output2),
                                                length: inTexture.width * inTexture.height * MemoryLayout<Float>.size,
                                                options: .storageModeShared) { pointer, _ in
                    pointer.deallocate()
                }
                let buffer3 = device.makeBuffer(bytesNoCopy: UnsafeMutableRawPointer(output3),
                                                length: inTexture.width * inTexture.height * MemoryLayout<Float>.size,
                                                options: .storageModeShared) { pointer, _ in
                    pointer.deallocate()
                }
                
                
                let cmdTransferBuf = cmdQueue.makeCommandBuffer()!
                cmdTransferBuf.label = "Transfer Floats"
                
                let computeTransferEncoder = cmdTransferBuf.makeComputeCommandEncoder()!
                computeTransferEncoder.setComputePipelineState(pipelineTransfer)
                
                computeTransferEncoder.setTexture(inTexture, index: 0)
                computeTransferEncoder.setTexture(texOut, index: 1)
                computeTransferEncoder.setBuffer(buffer0, offset: 0, index: 0)
                computeTransferEncoder.setBuffer(buffer1, offset: 0, index: 1)
                computeTransferEncoder.setBuffer(buffer2, offset: 0, index: 2)
                computeTransferEncoder.setBuffer(buffer3, offset: 0, index: 3)
                computeTransferEncoder.setBytes(&channel, length: MemoryLayout<Int>.stride, index: 4)
                computeTransferEncoder.setBuffer(globalCounterBuffer, offset: 0, index: 5)
                
                // Metal Dispatch
                computeTransferEncoder.dispatchThreadgroups(threadgroupsPerGrid_transfer, threadsPerThreadgroup: threadsPerThreadgroup_transfer)
                computeTransferEncoder.endEncoding()
                
                cmdTransferBuf.commit()
                
                cmdTransferBuf.waitUntilCompleted()
            }
            
        }
        completion(texOut)
      
    }
     */

    public func getProcessState() -> (currentTaskCount: Int, totalTaskCount: Int, percentage: Double){
        guard let totalCounter = totalCounter,
              let counterPtr = counterPtr else{
            return (0,0, 100)
        }
        
        let progress = Int(counterPtr.pointee)
        let progressPercentage = Double(progress) / Double(totalCounter) * 100.0
        
        
        return (progress, totalCounter, progressPercentage)
    }
    
    public func interruptProcess(){
        guard let cancelPtr = cancelPtr else {return}
        cancelPtr.pointee = true
    }
    
    public func isCanceled() -> Bool{
        guard let cancelPtr = cancelPtr else {return false}
        return cancelPtr.pointee
    }
}
