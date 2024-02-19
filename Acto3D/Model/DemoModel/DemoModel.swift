//
//  DemoModel.swift
//  Acto3D
//
//  Created by Naoki Takeshita on 2024/02/19.
//

import Foundation
import Cocoa
import Metal

class DemoModel{
    var device:MTLDevice!
    var lib:MTLLibrary!
    var cmdQueue:MTLCommandQueue!
    
    init(device:MTLDevice, lib:MTLLibrary, cmdQueue:MTLCommandQueue) {
        self.device = device
        self.lib = lib
        self.cmdQueue = cmdQueue
    }
    
    func createDemoModel_tori(imgWidth: Int, imgHeight: Int, radius1: Int, radius2: Int, lineWidth:Int, inside_color: Int, outside_color: Int, edge_color: Int) -> MTLTexture?{
        
        let depthcount = (radius1 + radius2 + 20) * 2 + 1
        
        guard let computeFunction = lib.makeFunction(name: "createDemoModel_Tori") else {
            print("error make function")
            return nil
        }
        
        var pipeline:MTLComputePipelineState!
        do{
            let pipelineDescriptor = MTLComputePipelineDescriptor()
            pipelineDescriptor.label = MTL_label.other
            pipelineDescriptor.computeFunction = computeFunction
            pipeline = try device.makeComputePipelineState(descriptor: pipelineDescriptor, options: [], reflection: nil)
            
        }catch{
            Dialog.showDialog(message: "Error in creating metal pipeline for demoModel")
            return nil
        }
        
        let cmdBuf = cmdQueue.makeCommandBuffer()!
        cmdBuf.label = "Creating Demo Model"
        
        let computeEncoder = cmdBuf.makeComputeCommandEncoder()!
        computeEncoder.setComputePipelineState(pipeline)
        
        guard let texture = device.makeTexture(withChannelCount: 4, width: imgWidth, height: imgHeight, depth: depthcount) else {return nil}
        
        computeEncoder.setTexture(texture, index: 0)
        
        var radius1 = radius1
        var radius2 = radius2
        var lineWidth = lineWidth
        var edge_value = edge_color
        var inside_value = inside_color
        var outside_value = outside_color
        
        computeEncoder.setBytes(&radius1, length: MemoryLayout<Int>.stride, index: 0)
        computeEncoder.setBytes(&radius2, length: MemoryLayout<Int>.stride, index: 1)
        computeEncoder.setBytes(&lineWidth, length: MemoryLayout<Int>.stride, index: 2)
        computeEncoder.setBytes(&edge_value, length: MemoryLayout<Int>.stride, index: 3)
        computeEncoder.setBytes(&inside_value, length: MemoryLayout<Int>.stride, index: 4)
        computeEncoder.setBytes(&outside_value, length: MemoryLayout<Int>.stride, index: 5)
        
        
        // Compute optimization
        let xCount = texture.width
        let yCount = texture.height
        let zCount = texture.depth
        let maxTotalThreadsPerThreadgroup = pipeline.maxTotalThreadsPerThreadgroup
        let threadExecutionWidth          = pipeline.threadExecutionWidth
        let width  = threadExecutionWidth
        let height = 8
        let depth  = maxTotalThreadsPerThreadgroup / width / height
        let threadsPerThreadgroup = MTLSize(width: width, height: height, depth: depth)
        let threadgroupsPerGrid = MTLSize(width: (xCount + width - 1) / width,
                                          height: (yCount + height - 1) / height,
                                          depth: (zCount + depth - 1) / depth)
        
        
        // Metal Dispatch
        computeEncoder.dispatchThreadgroups(threadgroupsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
        computeEncoder.endEncoding()
        
        
        cmdBuf.commit()
        cmdBuf.waitUntilCompleted()
        
        return texture
    }
    
    
    
    func createDemoModel_sphereincube(imgWidth: Int, imgHeight: Int, ball_size: Int, square_size: Int) -> MTLTexture?{
        
        let depthcount = (square_size + 20) * 2 
        
        guard let computeFunction = lib.makeFunction(name: "createDemoModel_SphereInCube") else {
            print("error make function")
            return nil
        }
        
        var pipeline:MTLComputePipelineState!
        do{
            let pipelineDescriptor = MTLComputePipelineDescriptor()
            pipelineDescriptor.label = MTL_label.other
            pipelineDescriptor.computeFunction = computeFunction
            pipeline = try device.makeComputePipelineState(descriptor: pipelineDescriptor, options: [], reflection: nil)
            
        }catch{
            Dialog.showDialog(message: "Error in creating metal pipeline for demoModel")
            return nil
        }
        
        let cmdBuf = cmdQueue.makeCommandBuffer()!
        cmdBuf.label = "Creating Demo Model"
        
        let computeEncoder = cmdBuf.makeComputeCommandEncoder()!
        computeEncoder.setComputePipelineState(pipeline)
        
        guard let texture = device.makeTexture(withChannelCount: 4, width: imgWidth, height: imgHeight, depth: depthcount) else {return nil}
        
        computeEncoder.setTexture(texture, index: 0)
        
        var ball_size = ball_size
        var square_size = square_size
        
        computeEncoder.setBytes(&ball_size, length: MemoryLayout<Int>.stride, index: 0)
        computeEncoder.setBytes(&square_size, length: MemoryLayout<Int>.stride, index: 1)
        
        
        // Compute optimization
        let xCount = texture.width
        let yCount = texture.height
        let zCount = texture.depth
        let maxTotalThreadsPerThreadgroup = pipeline.maxTotalThreadsPerThreadgroup
        let threadExecutionWidth          = pipeline.threadExecutionWidth
        let width  = threadExecutionWidth
        let height = 8
        let depth  = maxTotalThreadsPerThreadgroup / width / height
        let threadsPerThreadgroup = MTLSize(width: width, height: height, depth: depth)
        let threadgroupsPerGrid = MTLSize(width: (xCount + width - 1) / width,
                                          height: (yCount + height - 1) / height,
                                          depth: (zCount + depth - 1) / depth)
        
        
        // Metal Dispatch
        computeEncoder.dispatchThreadgroups(threadgroupsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
        computeEncoder.endEncoding()
        
        
        cmdBuf.commit()
        cmdBuf.waitUntilCompleted()
        
        return texture
    }
    
    
    
    public func gaussian2D(inTexture:MTLTexture, k_size: UInt8, sigma: Float = 1.4, inChannel :Int, outChannel:Int) -> MTLTexture? {

        guard let computeFunction = lib.makeFunction(name: "applyFilter_gaussian2D") else {
            print("error make function")
            return nil
        }
        
        var pipeline:MTLComputePipelineState!
        do{
            let pipelineDescriptor = MTLComputePipelineDescriptor()
            pipelineDescriptor.label = MTL_label.applyFilter_gaussian3D
            pipelineDescriptor.computeFunction = computeFunction
            pipeline = try device.makeComputePipelineState(descriptor: pipelineDescriptor, options: [], reflection: nil)
            
        }catch{
            Dialog.showDialog(message: "Error in creating metal pipeline for gaussian3D")
            return nil
        }
        
        let cmdBuf = cmdQueue.makeCommandBuffer()!
        cmdBuf.label = "Apply Filter"
        
        let computeEncoder = cmdBuf.makeComputeCommandEncoder()!
        computeEncoder.setComputePipelineState(pipeline)
        
        // Sampler Set
        let sampler = device.makeSampler(filter: .linear)
        
        
        computeEncoder.setTexture(inTexture, index: 0)
        
        var outTex = (inChannel != outChannel) ? inTexture : inTexture.createNewTextureWithSameSize(pixelFormat: inTexture.pixelFormat)
        computeEncoder.setTexture(outTex, index: 1)
        
        
        var k_size = k_size
        
        // create 2D kernal (as 1D array)
        let half_kernel_size = k_size.toInt() / 2
        var kernel_weights = [Float](repeating: 0, count: k_size.toInt() * k_size.toInt())
        var sum: Float = 0
        for i in -half_kernel_size...half_kernel_size {
            for j in -half_kernel_size...half_kernel_size {
                    let idx = (i + half_kernel_size) * Int(k_size) + (j + half_kernel_size)
                    kernel_weights[idx] = exp(-(Float(i * i + j * j)) / (2.0 * sigma * sigma))
                    sum += kernel_weights[idx]
            }
        }
        for i in 0..<(k_size.toInt() * k_size.toInt() ) {
            kernel_weights[i] /= sum
        }
        
        let weightsBuffer = device.makeBuffer(bytes: &kernel_weights, length: MemoryLayout<Float>.size * kernel_weights.count, options: [])
        computeEncoder.setBuffer(weightsBuffer, offset: 0, index: 0)
        
        computeEncoder.setBytes(&k_size, length: MemoryLayout<UInt8>.stride, index: 1)
        computeEncoder.setSamplerState(sampler, index: 0)
        
        var inChannel = inChannel
        var outChannel = outChannel
        computeEncoder.setBytes(&inChannel, length: MemoryLayout<Int>.stride, index: 2)
        computeEncoder.setBytes(&outChannel, length: MemoryLayout<Int>.stride, index: 3)
        
        
        
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
        
        
        
        // Metal Dispatch
        computeEncoder.dispatchThreadgroups(threadgroupsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
        computeEncoder.endEncoding()
        
        cmdBuf.commit()
        cmdBuf.waitUntilCompleted()
        
        return outTex
        
    }
    
}
