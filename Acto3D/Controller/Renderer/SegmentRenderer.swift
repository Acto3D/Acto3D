//
//  SegmentRenderer.swift
//  Acto3D
//
//  Created by Naoki Takeshita on 2023/01/05.
//

import Foundation
import Cocoa
import Metal
import simd



class SegmentRenderer{
    
    var device : MTLDevice!
    var cmdQueue : MTLCommandQueue!
    var mtlLib: MTLLibrary!
    var renderPipeline: MTLComputePipelineState!
    
    var mainTexture:MTLTexture?
    var preProcessedTexture:MTLTexture?
    var maskTexture:MTLTexture?
    
    /// 8 bits per components RGB (with mask image)
    var image:CGImage?
    
    /// 8 bits image without mask (original texture)
    var baseImage:CGImage?
    
    var renderModelParams:RenderingParameters!
    var imageParams:VolumeData!
    
    /// which channel to process: 0, 1, 2, 3, 4 (4 = pre-processed texture)
    var channel:UInt8 = 0
    
    var quaternion:simd_quatf = simd_quatf(float4x4(1))
    
    struct Normals{
        var x = float3(1,0,0)
        var y = float3(0,1,0)
        var z = float3(0,0,1)
    }
    
    var normals = Normals()
    
    
    
    init(device:MTLDevice, cmdQueue:MTLCommandQueue, mtlLib: MTLLibrary) {
        self.device = device
        self.cmdQueue = cmdQueue
        self.mtlLib = mtlLib
        
        prepareForMTL()
    }
    
    public func prepareForMTL(){
        guard let computeFunction = mtlLib.makeFunction(name: "createMprForSegment") else {
            print("error make function")
            Dialog.showDialogWithDebug(message: "func: \(#function), line: \(#line) \n cannot create compute function")
            return
        }
        do{
            self.renderPipeline = try device.makeComputePipelineState(function: computeFunction)
        }catch{
            Dialog.showDialogWithDebug(message: "func: \(#function), line: \(#line) \n cannot create render pipeline")
        }
    }
    
    public func renderSlice() -> NSImage?{
        if renderPipeline == nil{
            Dialog.showDialog(message: "func: \(#function), line: \(#line) \n render pipeline has not created")
            return nil
        }
        guard let _ = mainTexture else {
            Dialog.showDialog(message: "Please load images first")
            return nil
        }
        
        
        let cmdBuffer = cmdQueue.makeCommandBuffer()!
        cmdBuffer.label = "Command Buffer (Segment 3D)"
        
        let cmdEncoder = cmdBuffer.makeComputeCommandEncoder()!
        cmdEncoder.setComputePipelineState(renderPipeline)
        cmdEncoder.label = "Command Encoder (Segment 3D)"
        
        
        let pxByteSize = imageParams!.outputImageWidth.toInt() * imageParams!.outputImageHeight.toInt() * 3
        let pxByteSizeBaseCh = imageParams!.outputImageWidth.toInt() * imageParams!.outputImageHeight.toInt()
        
        /// `outputPx` is RGB32bits image
        let outputPx = UnsafeMutablePointer<UInt8>.allocate(capacity: pxByteSize)
        
        /// `outputPxBaseCh` is R8 image
        let outputPxBaseCh = UnsafeMutablePointer<UInt8>.allocate(capacity: pxByteSizeBaseCh)
        
        let outputBuffer = device.makeBuffer(bytes: outputPx,
                                             length: MemoryLayout<UInt8>.stride * pxByteSize,
                                             options: .storageModeShared)
        let outputBufferBaseCh = device.makeBuffer(bytes: outputPxBaseCh,
                                                   length: MemoryLayout<UInt8>.stride * pxByteSizeBaseCh,
                                                   options: .storageModeShared)
        
        cmdEncoder.setBuffer(outputBuffer, offset: 0, index: 0)
        cmdEncoder.setBytes(&imageParams, length: MemoryLayout<VolumeData>.stride, index: 1)
        cmdEncoder.setBytes(&renderModelParams, length: MemoryLayout<RenderingParameters>.stride, index: 2)
        cmdEncoder.setBytes(&quaternion, length: MemoryLayout<simd_quatf>.stride, index: 3)
        cmdEncoder.setBuffer(outputBufferBaseCh, offset: 0, index: 4)
        
        let mprSampler = device.makeSampler(filter: .linear, addressMode: .clampToZero)
        cmdEncoder.setSamplerState(mprSampler, index: 0)
        
        if(self.maskTexture != nil){
            cmdEncoder.setTexture(self.maskTexture, index: 1)
            var useMaskTexture:UInt8 = 1
            cmdEncoder.setBytes(&useMaskTexture, length: MemoryLayout<UInt8>.stride, index: 6)
        }else{
            var useMaskTexture:UInt8 = 0
            cmdEncoder.setBytes(&useMaskTexture, length: MemoryLayout<UInt8>.stride, index: 6)
        }
        
        var channelToUse:UInt8
        if(self.channel != 4){
            cmdEncoder.setTexture(mainTexture, index: 0)
            channelToUse = self.channel
        }else{
            if(preProcessedTexture != nil){
                cmdEncoder.setTexture(preProcessedTexture, index: 0)
                channelToUse = 0
            }else{
                cmdEncoder.setTexture(mainTexture, index: 0)
                channelToUse = self.channel
            }
        }
        cmdEncoder.setBytes(&channelToUse, length: MemoryLayout<UInt8>.stride, index: 5)
        
        
        let width = renderPipeline.threadExecutionWidth
        let threads_in_group = renderPipeline.maxTotalThreadsPerThreadgroup
        let height = threads_in_group / width
        let threadsPerThreadgroup = MTLSize(width: width, height: height, depth: 1)
        
        let threadgroupsPerGrid = MTLSize(width: (imageParams.outputImageWidth.toInt() + width - 1) / width, height: (imageParams.outputImageHeight.toInt() + height - 1) / height, depth: 1)
        cmdEncoder.dispatchThreadgroups(threadgroupsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
        
        cmdEncoder.endEncoding()
        cmdBuffer.commit()
        cmdBuffer.waitUntilCompleted()
        
        // decode image
        guard let providerRef = CGDataProvider(data: Data (bytes: outputBuffer!.contents(),
                                                           count: MemoryLayout<UInt8>.stride * pxByteSize) as CFData)
        else {
            Dialog.showDialog(message: "func: \(#function), line: \(#line) \n Decoding failed (buffer error)")
            return nil
            
        }
        
        guard let providerRef_gray = CGDataProvider(data: Data (bytes: outputBufferBaseCh!.contents(),
                                                                count: MemoryLayout<UInt8>.stride * pxByteSizeBaseCh) as CFData)
        else {
            Dialog.showDialog(message: "func: \(#function), line: \(#line) \n Decoding failed (buffer error)")
            return nil
            
        }
        
        outputPx.deallocate()
        outputPxBaseCh.deallocate()
        
        
        guard let cgim = CGImage(
            width: imageParams.outputImageWidth.toInt(),
            height: imageParams.outputImageHeight.toInt(),
            bitsPerComponent: 8, // 8
            bitsPerPixel: 8 * 3, // 24 or 32
            bytesPerRow: MemoryLayout<UInt8>.stride * imageParams.outputImageWidth.toInt() * 3,  // * 4 for 32bit
            space:  CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),  //CGImageAlphaInfo.noneSkipLast.rawValue
            provider: providerRef,
            decode: nil,
            shouldInterpolate: true,
            intent: .defaultIntent)
        else {
            Dialog.showDialog(message: "func: \(#function), line: \(#line) \n Decoding failed")
            return nil
            
        }
        
        guard let cgim_gray = CGImage(
            width: imageParams.outputImageWidth.toInt(),
            height: imageParams.outputImageHeight.toInt(),
            bitsPerComponent: 8, // 8
            bitsPerPixel: 8 * 1, // 24 or 32
            bytesPerRow: MemoryLayout<UInt8>.stride * imageParams.outputImageWidth.toInt() * 1,  // * 4 for 32bit
            space:   CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),  //CGImageAlphaInfo.noneSkipLast.rawValue
            provider: providerRef_gray,
            decode: nil,
            shouldInterpolate: true,
            intent: .defaultIntent)
        else {
            Dialog.showDialog(message: "func: \(#function), line: \(#line) \n Decoding failed")
            return nil
            
        }
        
        self.image = cgim
        self.baseImage = cgim_gray
        
        return cgim.toNSImage
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
        self.quaternion = simd_quatf(float4x4(1))
    }
    
    
    public func initMaskTexture(){
        guard let mainTexture = self.mainTexture else {return}
        self.maskTexture = mainTexture.createNewTextureWithSameSize( pixelFormat: .r8Unorm)
        

        let clearPipelineState = try! device.makeComputePipelineState(function: mtlLib.makeFunction(name: "clear3DTexture")!)

        let commandBuffer = cmdQueue.makeCommandBuffer()!
        let commandEncoder = commandBuffer.makeComputeCommandEncoder()!
        commandEncoder.setComputePipelineState(clearPipelineState)
        commandEncoder.setTexture(self.maskTexture, index: 0)
        
        let xCount = self.maskTexture!.width
        let yCount = self.maskTexture!.height
        let zCount = self.maskTexture!.depth
        let maxTotalThreadsPerThreadgroup = clearPipelineState.maxTotalThreadsPerThreadgroup
        let threadExecutionWidth          = clearPipelineState.threadExecutionWidth
        let width  = threadExecutionWidth
        let height = 8
        let depth  = maxTotalThreadsPerThreadgroup / width / height
        let threadsPerThreadgroup = MTLSize(width: width, height: height, depth: depth)
        let threadgroupsPerGrid = MTLSize(width: (xCount + width - 1) / width,
                                          height: (yCount + height - 1) / height,
                                          depth: (zCount + depth - 1) / depth)


        commandEncoder.dispatchThreadgroups(threadgroupsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
        commandEncoder.endEncoding()

        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

    }
    
    public func transferMaskToMainTexture(destChannel : UInt8, smooth:Bool){
        guard let maskTexture = maskTexture,
              let mainTexture = mainTexture else {
            Dialog.showDialog(message: "No mask image")
            return
        }
        
        
        if (smooth == true){
            print("Mask(Binary) to mainTexture")
            copyMaskToTexture(texIn: maskTexture, texOut: mainTexture, channel: destChannel, binary: true)
            
            print("mainTexture to Mask")
            copyTextureToMask(texIn: mainTexture, channel: destChannel, texOut: maskTexture)
            
            let semaphore = DispatchSemaphore(value: 0)
            
            print("3")
            let processor = ImageProcessor(device: self.device, cmdQueue: self.cmdQueue, lib: self.mtlLib)
            processor.applyFilter_Gaussian3D(inTexture: maskTexture, k_size: 5, channel: 0){ result in
                self.maskTexture = result
                semaphore.signal()
            }
            
            print("4")
            semaphore.wait()
            
            if(self.maskTexture == nil){
                return
            }
            
            self.copyMaskToTexture(texIn: self.maskTexture!, texOut: mainTexture, channel: destChannel, binary: false)
            self.maskTexture = nil
            
        }else{
            // just transfer mask to main texture
            copyMaskToTexture(texIn: maskTexture, texOut: mainTexture, channel: destChannel, binary: true)
            self.maskTexture = nil
        }
        
    }
    
    public func copyMaskToTexture(texIn:MTLTexture, texOut:MTLTexture, channel:UInt8, binary:Bool){
        guard let computeFunction = mtlLib.makeFunction(name: "transferMaskToTexture") else {
            print("error make function")
            return
        }
        var renderPipeline: MTLComputePipelineState!
        
        renderPipeline = try? self.device.makeComputePipelineState(function: computeFunction)
        
        let cmdBuf = cmdQueue.makeCommandBuffer()!
        let computeSliceEncoder = cmdBuf.makeComputeCommandEncoder()!
        computeSliceEncoder.setComputePipelineState(renderPipeline)
        
        // Sampler Set
        var sampler: MTLSamplerState!
        let samplerDescriptor = MTLSamplerDescriptor()
        samplerDescriptor.sAddressMode = .clampToZero
        samplerDescriptor.tAddressMode = .clampToZero
        samplerDescriptor.minFilter = .linear
        samplerDescriptor.magFilter = .linear
        sampler = device.makeSamplerState(descriptor: samplerDescriptor)
        
        // Buffer set
        
        computeSliceEncoder.setTexture(texIn, index: 0)
        computeSliceEncoder.setTexture(texOut, index: 1)
        computeSliceEncoder.setSamplerState(sampler, index: 0)
        
        var channel:UInt8 = channel
        computeSliceEncoder.setBytes(&channel, length: MemoryLayout<UInt8>.stride, index: 0)
        
        var binary:Bool = binary
        computeSliceEncoder.setBytes(&binary, length: MemoryLayout<Bool>.stride, index: 1)
        
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
    
    public func copyTextureToMask(texIn: MTLTexture, channel: UInt8, texOut:MTLTexture){
        print("prepare compute function")
        guard let computeFunction = mtlLib.makeFunction(name: "transferChannelToMask") else {
            print("error make function")
            return
        }
        var renderPipeline: MTLComputePipelineState!
        
        
        print("prepare render pipeline")
        renderPipeline = try? self.device.makeComputePipelineState(function: computeFunction)
        
        print("render is created")
        
        let cmdBuf = cmdQueue.makeCommandBuffer()!
        print("command buffer created")
        let computeSliceEncoder = cmdBuf.makeComputeCommandEncoder()!
        print("command encoder created")
        computeSliceEncoder.setComputePipelineState(renderPipeline)
        print("pipeline set to encoder")
        
        // Sampler Set
        var sampler: MTLSamplerState!
        let samplerDescriptor = MTLSamplerDescriptor()
        samplerDescriptor.sAddressMode = .clampToZero
        samplerDescriptor.tAddressMode = .clampToZero
        samplerDescriptor.minFilter = .linear
        samplerDescriptor.magFilter = .linear
        sampler = device.makeSamplerState(descriptor: samplerDescriptor)
        
        
        print("set textures to encoder")
        computeSliceEncoder.setTexture(texIn, index: 0)
        computeSliceEncoder.setTexture(texOut, index: 1)
        
        print("set sampler to encoder")
        computeSliceEncoder.setSamplerState(sampler, index: 0)
        
        print("set variable to encoder")
        var channel:UInt8 = channel
        computeSliceEncoder.setBytes(&channel, length: MemoryLayout<UInt8>.stride, index: 0)
        
        
        print("metal params have set")
        
        // Compute optimization
        let xCount = texIn.width
        let yCount = texIn.height
        let zCount = texIn.depth
        
        let maxTotalThreadsPerThreadgroup = renderPipeline.maxTotalThreadsPerThreadgroup // 1024
        let threadExecutionWidth          = renderPipeline.threadExecutionWidth // 32
        let width  = threadExecutionWidth // 32
        let height = 8
        let depth  = maxTotalThreadsPerThreadgroup / width / height // 1024 / 32 / 8 = 4
        let threadsPerThreadgroup = MTLSize(width: width, height: height, depth: depth) // MTLSize(width: 32, height: 8, depth: 4)
        let threadgroupsPerGrid = MTLSize(width: (xCount + width - 1) / width,
                                          height: (yCount + height - 1) / height,
                                          depth: (zCount + depth - 1) / depth)
        
        
        print("Dispatch")
        // Metal Dispatch
        computeSliceEncoder.dispatchThreadgroups(threadgroupsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
        computeSliceEncoder.endEncoding()
        
        print("METAL MEDIAN START")
        
        cmdBuf.commit()
        cmdBuf.waitUntilCompleted()
        
        print("METAL MEDIAN DONE")
    }
    
    public func apply_gaussianBlur3D(input texIn: MTLTexture, channel:UInt8) -> MTLTexture?{
        
        guard let computeFunction = mtlLib.makeFunction(name: "gaussianBlur3D") else {
            print("error make function")
            return nil
        }
        var renderPipeline: MTLComputePipelineState!
        
        renderPipeline = try? self.device.makeComputePipelineState(function: computeFunction)
        
        let cmdBuf = cmdQueue.makeCommandBuffer()!
        cmdBuf.label = "Apply Filter"
        let computeSliceEncoder = cmdBuf.makeComputeCommandEncoder()!
        computeSliceEncoder.setComputePipelineState(renderPipeline)
        
        // Sampler Set
        var sampler: MTLSamplerState!
        let samplerDescriptor = MTLSamplerDescriptor()
        samplerDescriptor.sAddressMode = .clampToZero
        samplerDescriptor.tAddressMode = .clampToZero
        samplerDescriptor.minFilter = .linear
        samplerDescriptor.magFilter = .linear
        sampler = device.makeSamplerState(descriptor: samplerDescriptor)
        
        // Output Texture
        let outTextureDescriptor = MTLTextureDescriptor()
        outTextureDescriptor.pixelFormat = MTLPixelFormat.r8Unorm
        outTextureDescriptor.textureType = .type3D
        outTextureDescriptor.width = texIn.width
        outTextureDescriptor.height = texIn.height
        outTextureDescriptor.depth = texIn.depth
        outTextureDescriptor.allowGPUOptimizedContents = true
        outTextureDescriptor.usage = [.shaderRead, .shaderWrite]
        outTextureDescriptor.storageMode = .private
        
        let texOut = self.device.makeTexture(descriptor: outTextureDescriptor)!
        
        
        computeSliceEncoder.setTexture(texIn, index: 0)
        computeSliceEncoder.setTexture(texOut, index: 1)
        
        var sigma:Float = 1.8
        computeSliceEncoder.setBytes(&sigma, length: MemoryLayout<Float>.stride, index: 0)
        
        var channel = channel
        computeSliceEncoder.setBytes(&channel, length: MemoryLayout<UInt8>.stride, index: 1)
        
        computeSliceEncoder.setSamplerState(sampler, index: 0)
        
        // Compute optimization
        let xCount = texIn.width
        let yCount = texIn.height
        let zCount = texIn.depth
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
        
        print("METAL MEDIAN START")
        
        cmdBuf.commit()
        cmdBuf.waitUntilCompleted()
        
        print("METAL MEDIAN DONE")
        
        return texOut
        
    }
}
