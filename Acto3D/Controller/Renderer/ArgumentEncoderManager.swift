//
//  ArgumentEncoderManager.swift
//  Acto3D
//
//  Created by Naoki Takeshita on 2023/07/15.
//

import Foundation
import Metal

class ArgumentEncoderManager {
    private let device: MTLDevice
    private let mtlFunction: MTLFunction

    // The argument encoder
    private var argumentEncoder: MTLArgumentEncoder!
    public var argumentBuffer: MTLBuffer!

    // A dictionary to store buffers by argument index
    private var buffers = [Int: MTLBuffer]()
    // A dictionary to track if a value is updated
    private var needsUpdate = [Int: Bool]()
    
    
    var currentPxByteSize: Int = 0
    var outputPxBuffer: MTLBuffer?
    
    var sampler: MTLSamplerState?
    var currentSamplerFilter: MTLSamplerMinMagFilter = .nearest
    
    enum ArgumentIndex: Int, CaseIterable, CustomStringConvertible {
        var description: String{
            switch self{
            case .mainTexture: return "mainTexture"
            case .renderParams: return "renderParams"
            case .outputBuffer: return "output pixel buffer"
            case .toneBufferCh1: return "tone buffer 1"
            case .toneBufferCh2: return "tone buffer 2"
            case .toneBufferCh3: return "tone buffer 3"
            case .toneBufferCh4: return "tone buffer 4"
            case .optionValue: return "option value"
            case .quaternion: return "quaternion"
            case .sampler: return "sampler"
            case .targetViewSize: return "targetViewSize"
            case .pointSetCountBuffer: return "pointSet count"
            case .pointSetSelectedBuffer: return "pointSet selector"
            case .pointCoordsBuffer: return "pointSet coords"
            }
        }
        
        case mainTexture = 0
        case renderParams = 1
        case outputBuffer = 2
        case toneBufferCh1 = 3
        case toneBufferCh2 = 4
        case toneBufferCh3 = 5
        case toneBufferCh4 = 6
        case optionValue = 7
        case quaternion = 8
        case targetViewSize = 9
        case sampler = 10
        case pointSetCountBuffer = 11
        case pointSetSelectedBuffer = 12
        case pointCoordsBuffer = 13
    }

    init(device: MTLDevice, mtlFunction: MTLFunction) {
        self.device = device
        self.mtlFunction = mtlFunction

        // Create the argument encoder when the manager is initialized
        self.argumentEncoder = mtlFunction.makeArgumentEncoder(bufferIndex: 0)
        self.argumentEncoder.label = "Argument Encoder"
        
        let argumentBufferLength = argumentEncoder.encodedLength
        
        // create argument buffer
        guard let argumentBuffer = device.makeBuffer(length: argumentBufferLength, options: [.cpuCacheModeWriteCombined, .storageModeShared])
        else {
            Dialog.showDialog(message: "Error in creating argument buffer.", level: .error)
            return
        }
        
        self.argumentBuffer = argumentBuffer
        self.argumentBuffer.label = "Argument Buffer"
        
        self.argumentEncoder.setArgumentBuffer(argumentBuffer, offset: 0)
        
        for argumentIndex in ArgumentIndex.allCases {
            needsUpdate[argumentIndex.rawValue] = true
        }
    }

    func encodeTexture(texture: MTLTexture, argumentIndex: ArgumentIndex){
        let index = argumentIndex.rawValue
        
        if needsUpdate[index] == true{
            argumentEncoder.setTexture(texture, index: index)
            
            needsUpdate[index] = false
            
            if(AppConfig.IS_DEBUG_MODE == true){
                print("arg texture index:\(index) (\(argumentIndex.description)), \(String(describing: type(of: texture))), set")
            }

        }else{
            if(AppConfig.IS_DEBUG_MODE == true){
                print("arg texture index:\(index) (\(argumentIndex.description)), \(String(describing: type(of: texture))), reuse")
            }
        }
    }
    
    func encodeSampler(filter: MTLSamplerMinMagFilter){
        if(self.sampler == nil){
            if(AppConfig.IS_DEBUG_MODE == true){
                print("arg sampler index:\(ArgumentIndex.sampler.rawValue), \(String(describing: type(of: sampler))), created")
            }
            self.sampler = device.makeSampler(filter: filter, addressMode: .clampToZero)
            self.currentSamplerFilter = filter
            
            argumentEncoder.setSamplerState(self.sampler, index: ArgumentIndex.sampler.rawValue)
            
        }else{
            if(self.currentSamplerFilter != filter){
                // when sampler description has changed
                self.sampler = device.makeSampler(filter: filter, addressMode: .clampToZero)
                self.currentSamplerFilter = filter
                if(AppConfig.IS_DEBUG_MODE == true){
                    print("arg sampler index:\(ArgumentIndex.sampler.rawValue) (\(ArgumentIndex.sampler.description)), \(String(describing: type(of: sampler))), recreated because filter was changed")
                }
                argumentEncoder.setSamplerState(self.sampler, index: ArgumentIndex.sampler.rawValue)
                
            }else{
                if(AppConfig.IS_DEBUG_MODE == true){
                    print("arg sampler index:\(ArgumentIndex.sampler.rawValue) (\(ArgumentIndex.sampler.description)), \(String(describing: type(of: sampler))), reuse")
                }
            }
        }
    }
    
    // Encodes a struct to the specified argument index
    func encode<T>(_ value: inout T, argumentIndex: ArgumentIndex, capacity: Int = 1) {
        let index = argumentIndex.rawValue
        
        let size = MemoryLayout<T>.stride * capacity
        
        if buffers[index] == nil {
            if(AppConfig.IS_DEBUG_MODE == true){
                print("arg buffer index:\(index) (\(argumentIndex.description)), \(String(describing: T.self)), LayoutSize:\(MemoryLayout<T>.stride), size:\(size) created -> \(value)")
            }
            buffers[index] = device.makeBuffer(length: size, options: [.cpuCacheModeWriteCombined, .storageModeShared])
            buffers[index]?.label = argumentIndex.description
            
            let pointer = buffers[index]!.contents().bindMemory(to: T.self, capacity: capacity)
            pointer.pointee = value
            
            argumentEncoder.setBuffer(buffers[index], offset: 0, index: index)
            needsUpdate[index] = false
            
        }else{
            if(AppConfig.IS_DEBUG_MODE == true){
                print("arg buffer index:\(index) (\(argumentIndex.description)), \(String(describing: T.self)) reuse")
            }
            
        }
        
        if memcmp(buffers[index]!.contents(), &value, size) != 0 {
            let pointer = buffers[index]!.contents().bindMemory(to: T.self, capacity: capacity)
            pointer.pointee = value
            
            // Set the updated buffer in the argument encoder
            argumentEncoder.setBuffer(buffers[index], offset: 0, index: index)
            
            if(AppConfig.IS_DEBUG_MODE == true){
                print("arg buffer index:\(index) (\(argumentIndex.description)), \(String(describing: T.self)) update because value change was detected -> \(value)")
            }
            
            // Reset the update status for this index
            needsUpdate[index] = false
        }
    }
    
    // Encodes a struct to the specified argument index
    func encodeArray(_ value: [float3], argumentIndex: ArgumentIndex, capacity: Int = 1) {
        let index = argumentIndex.rawValue
        // If a buffer for this index doesn't exist, create one
        if (buffers[index] == nil) {
            let size = MemoryLayout<float3>.stride * capacity
            if(AppConfig.IS_DEBUG_MODE == true){
                print("arg buffer index:\(index), \(String(describing: float3.self)), LayoutSize:\(MemoryLayout<float3>.stride), size:\(size) created")
            }
            buffers[index] = device.makeBuffer(bytes: value, length: size, options: [.cpuCacheModeWriteCombined, .storageModeShared])
            buffers[index]?.label = argumentIndex.description
            argumentEncoder.setBuffer(buffers[index], offset: 0, index: index)
            needsUpdate[index] = false
            
        }else{
            if(AppConfig.IS_DEBUG_MODE == true){
                print("arg buffer index:\(index) (\(argumentIndex.description)), \(String(describing: float3.self)) reuse")
            }
            
        }

        if needsUpdate[index] == true {
            let size = MemoryLayout<float3>.stride * capacity
            if(AppConfig.IS_DEBUG_MODE == true){
                print("arg buffer index:\(index) (\(argumentIndex.description)), \(String(describing: float3.self)), LayoutSize:\(MemoryLayout<float3>.stride), size:\(size) created")
            }
            buffers[index] = device.makeBuffer(bytes: value, length: size, options: [.cpuCacheModeWriteCombined, .storageModeShared])
            buffers[index]?.label = argumentIndex.description
            argumentEncoder.setBuffer(buffers[index], offset: 0, index: index)
            needsUpdate[index] = true
        }
    }
    
    func encode(_ buffer: MTLBuffer?, argumentIndex: ArgumentIndex) {
        let index = argumentIndex.rawValue
        
        if(needsUpdate[index] == true){
            buffers[index] = buffer
            argumentEncoder.setBuffer(buffer, offset: 0, index: index)
            needsUpdate[index] = false
            if(AppConfig.IS_DEBUG_MODE == true){
                print("arg buffer index:\(index) (\(argumentIndex.description)), \(String(describing: type(of: buffer))), set")
            }
            
        }else{
            if(AppConfig.IS_DEBUG_MODE == true){
                print("arg buffer index:\(index) (\(argumentIndex.description)), \(String(describing: type(of: buffer))), reuse")
            }
        }
    }
    
    func encodeOutputPixel(drawingViewSize: Int){
        let index = ArgumentIndex.outputBuffer.rawValue
        
        if(outputPxBuffer == nil){
            // create output pixel & buffer if not exist
            currentPxByteSize = drawingViewSize * drawingViewSize * 3
            outputPxBuffer = device.makeBuffer(length: MemoryLayout<UInt8>.stride * currentPxByteSize)
            buffers[index] = outputPxBuffer
            argumentEncoder.setBuffer(buffers[index], offset: 0, index: index)
            
            if(AppConfig.IS_DEBUG_MODE == true){
                print("arg output buffer index:\(ArgumentIndex.outputBuffer.rawValue) (\(ArgumentIndex.outputBuffer.description)), Output pixel buffer create \(currentPxByteSize)")
            }
            
        }else{
            // if pixel size is not changed, same buffer will reuse
            if(currentPxByteSize == drawingViewSize * drawingViewSize * 3){
                if(AppConfig.IS_DEBUG_MODE == true){
                    print("arg output buffer index:\(ArgumentIndex.outputBuffer.rawValue) (\(ArgumentIndex.outputBuffer.description)), Output pixel buffer reuse \(currentPxByteSize)")
                }
                
            }else{
                // recreate
                currentPxByteSize = drawingViewSize * drawingViewSize * 3
                outputPxBuffer = device.makeBuffer(length: MemoryLayout<UInt8>.stride * currentPxByteSize)
                buffers[index] = outputPxBuffer
                argumentEncoder.setBuffer(buffers[index], offset: 0, index: index)
                
                if(AppConfig.IS_DEBUG_MODE == true){
                    print("arg output buffer index:\(ArgumentIndex.outputBuffer.rawValue) (\(ArgumentIndex.outputBuffer.description)), Output pixel buffer was recreated because drawing view size was chaneged \(currentPxByteSize)")
                }
            }
        }
    }

    // Provides a way to mark a buffer as updated
    func markAsNeedsUpdate(argumentIndex: ArgumentIndex) {
        needsUpdate[argumentIndex.rawValue] = true
        if(AppConfig.IS_DEBUG_MODE == true){
            print("arg buffer index:\(argumentIndex.rawValue) markes as Needs Updata")
        }
    }

    // Provides a way to get the buffer associated with an index (if needed)
    func getBuffer(argumentIndex: ArgumentIndex) -> MTLBuffer? {
        return buffers[argumentIndex.rawValue]
    }
}

