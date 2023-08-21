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
    
    
    static func transferChannelToTexture(device: MTLDevice, cmdQueue:MTLCommandQueue, lib:MTLLibrary, inTexture: MTLTexture, dstTexture: MTLTexture, dstChannel: UInt8){
      
        guard let computeFunction = lib.makeFunction(name: "transferChannelToTexture") else {
            print("error make function")
            return
        }
        var renderPipeline: MTLComputePipelineState!
        
        renderPipeline = try? device.makeComputePipelineState(function: computeFunction)
        
        let cmdBuf = cmdQueue.makeCommandBuffer()!
        let computeSliceEncoder = cmdBuf.makeComputeCommandEncoder()!
        computeSliceEncoder.setComputePipelineState(renderPipeline)
        
        // Sampler Set
        let sampler = makeSampler(device: device)
        
        // Buffer set
        
        computeSliceEncoder.setTexture(inTexture, index: 0)
        computeSliceEncoder.setTexture(dstTexture, index: 1)
        computeSliceEncoder.setSamplerState(sampler, index: 0)
        
        var channel:UInt8 = dstChannel
        computeSliceEncoder.setBytes(&channel, length: MemoryLayout<UInt8>.stride, index: 0)
        
        
        // Compute optimization
        let xCount = inTexture.width
        let yCount = inTexture.height
        let zCount = inTexture.depth
        
        let maxTotalThreadsPerThreadgroup = renderPipeline.maxTotalThreadsPerThreadgroup // 1024
        let threadExecutionWidth          = renderPipeline.threadExecutionWidth // 32
        let width  = threadExecutionWidth // 32
        let height = 8
        let depth  = maxTotalThreadsPerThreadgroup / width / height // 1024 / 32 / 8 = 4
        let threadsPerThreadgroup = MTLSize(width: width, height: height, depth: depth) // MTLSize(width: 32, height: 8, depth: 4)
        let threadgroupsPerGrid = MTLSize(width: (xCount + width - 1) / width,
                                          height: (yCount + height - 1) / height,
                                          depth: (zCount + depth - 1) / depth)
        
        
        // Metal Dispatch
        computeSliceEncoder.dispatchThreadgroups(threadgroupsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
        computeSliceEncoder.endEncoding()
        
        cmdBuf.commit()
        cmdBuf.waitUntilCompleted()
        
    }
    
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
        let texOut = channel == -1 ? inTexture.createNewTextureWithSameSize(pixelFormat: .bgra8Unorm) : inTexture.createNewTextureWithSameSize(pixelFormat: .r8Unorm)!
        
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
        
        print("Gaussian 3D", "Thread for gaussian", threadsPerThreadgroup, "threadgroupsPerGrid", threadgroupsPerGrid)
        
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
        
        print("Counter", counterPtr.pointee)
        
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
