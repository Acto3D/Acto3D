//
//  MTLTexture.swift
//  Acto3D
//
//  Created by Naoki Takeshita on 2023/02/24.
//

import Foundation
import Cocoa
import Metal

extension MTLTexture{
    func createNewTextureWithSameSize(pixelFormat:MTLPixelFormat) -> MTLTexture?{
//        func createNewTextureWithSameSize(device:MTLDevice, pixelFormat:MTLPixelFormat) -> MTLTexture?{
        let outTextureDescriptor = MTLTextureDescriptor()
        outTextureDescriptor.pixelFormat = pixelFormat
        outTextureDescriptor.textureType = .type3D
        outTextureDescriptor.width = self.width
        outTextureDescriptor.height = self.height
        outTextureDescriptor.depth = self.depth
        outTextureDescriptor.allowGPUOptimizedContents = true
        
        outTextureDescriptor.usage = [.shaderRead, .shaderWrite]
        outTextureDescriptor.storageMode = .private
        
        return self.device.makeTexture(descriptor: outTextureDescriptor)
    }

}


extension MTLDevice{
    func makeTexture(withChannelCount channelCount:Int, width:Int, height:Int, depth:Int) -> MTLTexture? {
        guard channelCount == 1 || channelCount == 2 || channelCount == 4 else {
            Dialog.showDialog(message: "Channel count error")
            Logger.logPrintAndWrite(message: "Can not create texture for channel count: \(channelCount)")
            
            return nil
        }
        
        guard width <= 2048, height <= 2048, depth <= 2048 else {
            Dialog.showDialog(message: "The input image must have a height and width of 2048 pixels or less, and the number of Z stacks must be 2048 or fewer.")
            
            return nil
        }
        
        let textureDescriptor = MTLTextureDescriptor()
        textureDescriptor.textureType = .type3D
        textureDescriptor.width = width
        textureDescriptor.height = height
        textureDescriptor.depth = depth
        textureDescriptor.allowGPUOptimizedContents = true
        textureDescriptor.usage = [.shaderRead, .shaderWrite]
        textureDescriptor.storageMode = .private
        
        switch channelCount {
        case 1:
            textureDescriptor.pixelFormat = .r8Unorm
        case 2:
            textureDescriptor.pixelFormat = .rg8Unorm
        case 4:
            textureDescriptor.pixelFormat = .rgba8Unorm
        default:
            break
        }
        
        return self.makeTexture(descriptor: textureDescriptor)
    }
    
    func checkNonUniformThreadgroup() -> Bool{
        if #available(macOS 13.0, *) {
            if(self.supportsFamily(.common3) == true ||
               self.supportsFamily(.metal3) == true ||
               self.supportsFamily(.apple4) == true ||
               self.supportsFamily(.mac2) == true){
                return true
            }else{
                return false
            }
            
        } else {
            if(self.supportsFamily(.common3) == true ||
               self.supportsFamily(.apple4) == true ||
               self.supportsFamily(.mac2) == true){
                return true
            }else{
                return false
            }
        }
    }
    
    func makeSampler(filter: MTLSamplerMinMagFilter = .linear, addressMode:MTLSamplerAddressMode = .clampToZero) -> MTLSamplerState{
        let samplerDescriptor = MTLSamplerDescriptor()
        samplerDescriptor.sAddressMode = addressMode
        samplerDescriptor.tAddressMode = addressMode
        samplerDescriptor.minFilter = filter
        samplerDescriptor.magFilter = filter
        samplerDescriptor.supportArgumentBuffers = true
        
        return self.makeSamplerState(descriptor: samplerDescriptor)!
    }
    
    
    func check_GpuSupport(){
        // Metal GPU family check
        Logger.logOnlyToFile(message: "Check GPU Family Supports")
        for gpu in MTLGPUFamily.allCases{
            Logger.logOnlyToFile(message: "  GPU Family: \(gpu) \(self.supportsFamily(gpu))")
        }
        
        // argumentBufferTier
        let argumentBufferTier = self.argumentBuffersSupport
        
        var tierstring = ""
        
        switch argumentBufferTier {
            
        case .tier1:
            tierstring = "⚠️ The device supports argument buffer tier 1."
            Logger.logPrintAndWrite(message: tierstring, level: .error)
            Logger.logPrintAndWrite(message: "⚠️ Acto3D may not work properly with your GPU device.")
            
        case .tier2:
            tierstring = "The device supports argument buffer tier 2."
            Logger.log(message: tierstring, level: .info, writeToLogfile: true, onlyToFile: true)
            
        default:
            tierstring = "⚠️ The device does not support argument buffers."
            Logger.logPrintAndWrite(message: tierstring, level: .error)
            Logger.logPrintAndWrite(message: "⚠️ Acto3D may not work properly with your GPU device.")
            
        }
        
        switch self.readWriteTextureSupport {
        case .tier1:
            tierstring = "⚠️ The device supports texture read and write tier 1."
            Logger.logPrintAndWrite(message: tierstring, level: .error)
            Logger.logPrintAndWrite(message: "⚠️ Acto3D may not work properly with your GPU device.")
            
        case .tier2:
            tierstring = "The device supports texture read and write tier 2."
            Logger.log(message: tierstring, level: .info, writeToLogfile: true, onlyToFile: true)
            
        default:
            tierstring = "⚠️ The device does not support texture read and write."
            Logger.logPrintAndWrite(message: tierstring, level: .error)
            Logger.logPrintAndWrite(message: "⚠️ Acto3D may not work properly with your GPU device.")
            
        }
        
        if(self.checkNonUniformThreadgroup()){
            Logger.logOnlyToFile(message: "The device supports non uniform threadgroup function.")
        }else{
            Logger.logOnlyToFile(message: "⚠️ The device does not support non uniform threadgroup function.")
        }

    }
}


extension MTLGPUFamily:CaseIterable, CustomStringConvertible{
    public var description: String {
        switch self {
        case .apple1:
            return "apple1"
        case .apple2:
            return "apple2"
        case .apple3:
            return "apple3"
        case .apple4:
            return "apple4"
        case .apple5:
            return "apple5"
        case .apple6:
            return "apple6"
        case .apple7:
            return "apple7"
        case .apple8:
            return "apple8"
        case .common1:
            return "common1"
        case .common2:
            return "common2"
        case .common3:
            return "common3"
        case .mac2:
            return "mac2"
        case .metal3:
            return "metal3"
        default:
            return "Unknown"
        }
    }
    
    public static var allCases: [MTLGPUFamily] {
        var cases: [MTLGPUFamily] =
        [.apple1, .apple2, .apple3, .apple4, .apple5, .apple6, .apple7, .apple8, .common1, .common2, .common3, .mac2]
        
        if #available(macOS 13.0, *) {
            cases.append(.metal3)
        }
        
        return cases
    }
}

extension MTLCommandQueue{
    func makeCommandBuffer(label:String) -> MTLCommandBuffer?{
        let cmdBuffer = self.makeCommandBuffer()
        cmdBuffer?.label = label
        return cmdBuffer
    }
}

extension MTLCommandBuffer{
    func makeComputeCommandEncoder(label:String) -> MTLComputeCommandEncoder?{
        let cmdEncoder = self.makeComputeCommandEncoder()
        cmdEncoder?.label = label
        return cmdEncoder
    }
}
