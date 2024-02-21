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
    
    
    func createDemoModel_thin_lumen(imgWidth: Int, imgHeight: Int, innerRadius: Float, coefficient: Float, lineWidth:Int, inside_color: Int, outside_color: Int, edge_color: Int) -> MTLTexture?{
        
        let depthcount = 750
        
        guard let computeFunction = lib.makeFunction(name: "createDemoModel_ThinLumen") else {
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
        
        var radius = innerRadius
        var coefficient = coefficient
        var lineWidth = lineWidth
        var edge_value = edge_color
        var inside_value = inside_color
        var outside_value = outside_color
        
        computeEncoder.setBytes(&radius, length: MemoryLayout<Float>.stride, index: 0)
        computeEncoder.setBytes(&coefficient, length: MemoryLayout<Float>.stride, index: 1)
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

extension ViewController{
    internal func getParametersOfThinModel() -> (coefficient: Float, radius:Float, kernelSize: Int, sigma: Float){
        
        let alert = NSAlert()
        alert.messageText = "Set parameters for Thin Lumen Model"
        alert.informativeText = "Specify the parameters"
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        
        // Create a label for kernel size
        let label = NSTextField(frame: NSRect(x: 0, y: 0, width: 100, height: 24))
        label.stringValue = "Coefficient:"
        label.isBezeled = false
        label.drawsBackground = false
        label.isEditable = false
        label.isSelectable = false
        label.alignment = .right
        label.sizeToFit()
        
        // Add a text field and a stepper for kernel size
        let textField = NSTextField(frame: NSRect(x: label.frame.maxX + 5, y: 0, width: 50, height: 24))
        let stepper = NSStepper(frame: NSRect(x: textField.frame.maxX + 5, y: 0, width: 20, height: 24))
        let defaultValue = 0.04
        textField.doubleValue = defaultValue
        textField.alignment = .center
        stepper.minValue = 0.001
        stepper.maxValue = 1
        stepper.increment = 0.01
        stepper.doubleValue = defaultValue
        stepper.target = textField
        stepper.action = #selector(NSTextField.takeDoubleValueFrom(_:))
        
        
        // Create a label for sigma
        let label_r = NSTextField(frame: NSRect(x: stepper.frame.maxX + 15, y: 0, width: 100, height: 24))
        label_r.stringValue = "Radius:"
        label_r.isBezeled = false
        label_r.drawsBackground = false
        label_r.isEditable = false
        label_r.isSelectable = false
        label_r.alignment = .right
        label_r.sizeToFit()
        
        // Add a text field and a stepper for sigma
        let textField_r = NSTextField(frame: NSRect(x: label_r.frame.maxX + 5, y: 0, width: 50, height: 24))
        let stepper_r = NSStepper(frame: NSRect(x: textField_r.frame.maxX + 5, y: 0, width: 20, height: 24))
        let defaultValue_r = 1.5
        textField_r.doubleValue = defaultValue_r
        textField_r.alignment = .center
        stepper_r.minValue = 0.1
        stepper_r.maxValue = 5
        stepper_r.increment = 0.5
        stepper_r.doubleValue = defaultValue_r
        stepper_r.target = textField_r
        stepper_r.action = #selector(NSTextField.takeDoubleValueFrom(_:))
        
        
        // Create a label for kernel size
        let label_k = NSTextField(frame: NSRect(x: 0, y: 30, width: 100, height: 24))
        label_k.stringValue = "Kernel size:"
        label_k.isBezeled = false
        label_k.drawsBackground = false
        label_k.isEditable = false
        label_k.isSelectable = false
        label_k.alignment = .right
        label_k.sizeToFit()
        
        // Add a text field and a stepper for kernel size
        let textField_k = NSTextField(frame: NSRect(x: label_k.frame.maxX + 5, y: 30, width: 50, height: 24))
        let stepper_k = NSStepper(frame: NSRect(x: textField_k.frame.maxX + 5, y: 30, width: 20, height: 24))
        let defaultValue_kernel = 7
        textField_k.integerValue = defaultValue_kernel
        textField_k.alignment = .center
        stepper_k.minValue = 3
        stepper_k.maxValue = 9
        stepper_k.increment = 2
        stepper_k.integerValue = defaultValue_kernel
        stepper_k.target = textField_k
        stepper_k.action = #selector(NSTextField.takeIntValueFrom(_:))
        
        
        // Create a label for sigma
        let label_s = NSTextField(frame: NSRect(x: stepper.frame.maxX + 15, y: 30, width: 100, height: 24))
        label_s.stringValue = "Sigma:"
        label_s.isBezeled = false
        label_s.drawsBackground = false
        label_s.isEditable = false
        label_s.isSelectable = false
        label_s.alignment = .right
        label_s.sizeToFit()
        
        // Add a text field and a stepper for sigma
        let textField_s = NSTextField(frame: NSRect(x: label_s.frame.maxX + 5, y: 30, width: 50, height: 24))
        let stepper_s = NSStepper(frame: NSRect(x: textField_s.frame.maxX + 5, y: 30, width: 20, height: 24))
        let defaultValue_s = 1.8
        textField_s.doubleValue = defaultValue_s
        textField_s.alignment = .center
        stepper_s.minValue = 0.1
        stepper_s.maxValue = 5
        stepper_s.increment = 0.5
        stepper_s.doubleValue = defaultValue_s
        stepper_s.target = textField_s
        stepper_s.action = #selector(NSTextField.takeDoubleValueFrom(_:))
        
        
//        let accessory = NSView(frame: NSRect(x: 0, y: 0, width: sigmaStepper.frame.maxX, height: 24))
        let accessory = FlippedView(frame: NSRect(x: 0, y: 0, width: stepper_r.frame.maxX, height: 24))
        
//        label.setFrameOrigin(NSPoint(x: label.frame.minX, y: label.frame.minY - (24.0 / 2.0 - label.frame.height - 2.0)))
//        sigmaLabel.setFrameOrigin(NSPoint(x: sigmaLabel.frame.minX, y: sigmaLabel.frame.minY - (24.0 / 2.0 - sigmaLabel.frame.height - 2.0)))
        
        accessory.addSubview(label)
        accessory.addSubview(textField)
        accessory.addSubview(stepper)
        
        accessory.addSubview(label_r)
        accessory.addSubview(textField_r)
        accessory.addSubview(stepper_r)
        
        accessory.addSubview(label_k)
        accessory.addSubview(textField_k)
        accessory.addSubview(stepper_k)
        
        accessory.addSubview(label_s)
        accessory.addSubview(textField_s)
        accessory.addSubview(stepper_s)
        
        accessory.adjustHeightOfView()
        
        alert.accessoryView = accessory
        
        let modalResult = alert.runModal()
        let firstButtonNo = NSApplication.ModalResponse.alertFirstButtonReturn.rawValue
        
        guard let ksize = Int(textField_k.stringValue) else{
            Dialog.showDialog(message: "Invalid kernel size: \(textField_k.stringValue)\nThe kernel size must be an odd integer.")
            return (0,0,0,0)
        }
        
        guard let sigma = Float(textField_s.stringValue) else{
            Dialog.showDialog(message: "Invalid sigma value: \(textField_s.stringValue).")
            return (0,0,0,0)
        }
        
        guard let coef = Float(textField.stringValue), coef > 0 else{
            Dialog.showDialog(message: "Invalid coefficient value: \(textField.stringValue).")
            return (0,0,0,0)
        }
        
        guard let radius = Float(textField_r.stringValue), coef > 0 else{
            Dialog.showDialog(message: "Invalid radius value: \(textField_r.stringValue).")
            return (0,0,0,0)
        }
        
        switch modalResult.rawValue {
        case firstButtonNo:
            return (coef, radius,  ksize,sigma)
            
            
        case firstButtonNo + 1:
            
            return (0,0,0,0)
            
        default:
            return (0,0,0,0)
        }
    }
}

class FlippedAccesoryView: NSView{
    
}
