//
//  TCPServer.swift
//
//  Created by Naoki Takeshita on 2024/02/20.
//

import Foundation
import Network
import Cocoa


protocol TCPServerDelegate: AnyObject {
    func startDataTransfer(sender: TCPServer, connectionID: Int)
    func portInUse(sender: TCPServer, port: UInt16)
    func listenerInReady(sender: TCPServer, port: UInt16)
}

class TCPServer {
    let port: NWEndpoint.Port
    var listener: NWListener?
    var connections: [Int: NWConnection] = [:]  // retain connection as dictionary
    var nextConnectionID: Int = 0 // Unique ID
    
    enum ShapeMode{
        case ZCYX
        case ZYX
        case LZYX
        case TEXSZ
    }
    enum ParameterMode{
        case VOXEL
        case SLICE
        case SCALE
    }
    
    weak var delegate:TCPServerDelegate?
    weak var vc:ViewController?
    
    private var imageWidth: UInt32 = 0
    private var imageHeight: UInt32 = 0
    private var imageDepth: UInt32 = 0
    private var imageChannel: UInt32 = 0
    private var receivedSlices: UInt32 = 0
    
    weak var renderer:VoluemeRenderer!
    
    var renderPipeline: MTLComputePipelineState!
    var parallelPipeline : MTLComputePipelineState?
    
    init?(port: UInt16) {
        guard let serverPort = NWEndpoint.Port(rawValue: port) else { return nil }
        self.port = serverPort
    }
    
    
    func start() {
        do {
            listener = try NWListener(using: .tcp, on: port)
        } catch {
            print("Unable to start listener: \(error.localizedDescription)")
            return
        }
        guard let listener = listener else{
            return
        }
        
        listener.stateUpdateHandler = {[weak self] state in
            print("Listener state: \(state)")
            
            switch state {
            case .ready:
                self?.delegate?.listenerInReady(sender: self!, port: self!.port.rawValue)
                
            case .setup:
                break
                
            case .failed(let error):
                print("Server failed with error: \(error)")
                self?.stop(byError: true)
                
                if error == NWError.posix(.EADDRINUSE){
                    self?.delegate?.portInUse(sender: self!, port: self!.port.rawValue)
                }
                
            default:
                break
            }
        }
        
        listener.newConnectionHandler = {[weak self] newConnection in
            self?.accept(connection: newConnection)
        }
        
        listener.start(queue: .main)
    }
    
    private func accept(connection: NWConnection) {
        let connectionID = nextConnectionID
        nextConnectionID += 1
        
        connections[connectionID] = connection
        
        connection.stateUpdateHandler = {[weak self] state in
            switch state {
            case .ready:
                print("Connection \(connectionID) is ready.")
                self?.receiveMessage(connectionID: connectionID)
                
            case .failed(let error):
                print("Connection \(connectionID) failed with error: \(error)")
                self?.connections.removeValue(forKey: connectionID)
                
            case .cancelled:
                print("Connection \(connectionID) cancelled. Remove from collection.")
                self?.connections.removeValue(forKey: connectionID)
                
            default:
                break
            }
        }
        
        connection.start(queue: .main)
    }
    
    private func receiveMessage(connectionID: Int) {
        guard let connection = connections[connectionID] else { return }
        
        // Wait for START signal
        connection.receive(minimumIncompleteLength: 5, maximumLength: 5) { [weak self] (data, _, isComplete, error) in
            if let data = data,
               let signal = String(data: data, encoding: .utf8)
            {
                switch signal{
                case "START":
                    // Initialize slice count for new data input.
                    self?.receivedSlices = 0
                    print("Received start signal, Connection \(connectionID)")
                    self?.delegate?.startDataTransfer(sender: self!, connectionID: connectionID)
                    
                case "ZDATA":
                    // After verifing version compatibility, send slice each by each (parallel).
                    // This is start signal
                    self?.waitForClientResponse(connectionID: connectionID)
                    
                case "PEND_":
                    // When parallel slice transfer finished.
                    self?.vc?.zScale_Slider.floatValue = self!.renderer.renderParams.zScale
                    self?.vc?.updateSliceAndScale(currentSliceToMax: true)
                    
                    self?.vc?.xResolutionField.floatValue = self!.renderer.imageParams.scaleX
                    self?.vc?.yResolutionField.floatValue = self!.renderer.imageParams.scaleY
                    self?.vc?.zResolutionField.floatValue = self!.renderer.imageParams.scaleZ
                    self?.vc?.scaleUnitField.stringValue = self!.renderer.imageParams.unit
                    
                    self?.vc?.progressBar.isHidden = true
                    self?.vc?.progressBar.doubleValue = 0
                    self?.vc?.outputView.image = self?.renderer.rendering()
                    
                    self?.parallelPipeline = nil
                    self?.stopConnectionByID(connectionID)
                    
                default:
                    break
                }
            }
            
            if isComplete {
                print("Connection complete")
                connection.cancel()
                self?.connections.removeValue(forKey: connectionID)
                
            } else if let error = error {
                print("Received error: \(error)")
                connection.cancel()
                self?.connections.removeValue(forKey: connectionID)
                
            } else {
                // Continue waiting for signals.
            }
        }
    }
    
    public func sendVersionInfoToStartTransferSession(connectionID: Int) {
        // After recieved START signal, send Version information to client
        guard let connection = connections[connectionID] else {
            print("Connection \(connectionID) not found.")
            return
        }
        
        let versionString = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
        let versionData = Data(versionString.utf8)
        connection.send(content: versionData, completion: .contentProcessed({[self] sendError in
            if let sendError = sendError {
                print("Failed to send version info: \(sendError)")
                self.stopConnectionByID(connectionID)
                return
            }
            print("Version info sent successfully. \(versionString)")
            self.waitForClientResponse(connectionID: connectionID)
        }))
    }
    
    private func waitForClientResponse(connectionID: Int) {
        guard let connection = connections[connectionID] else {
            print("Connection \(connectionID) not found.")
            return
        }
        
        connection.receive(minimumIncompleteLength: 5, maximumLength: 5) {[self] (data, _, _, error) in
            guard let data = data, error == nil,
                  let response = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .controlCharacters)
            else {
                print("Error receiving client response (ID: \(connectionID): \(error?.localizedDescription ?? "Unknown error")")
                self.stopConnectionByID(connectionID)
                return
            }
            
            if (response == "ZCYX_"){
                print("Data type would be ZCYX")
                receiveImageInfo(mode: .ZCYX, connectionID: connectionID)
                
            }else if(response == "ZYX__"){
                print("Data type would be ZYX")
                receiveImageInfo(mode: .ZYX, connectionID: connectionID)
                
            }else if(response == "LZYX_"){
                print("Data type would be LZYX")
                receiveImageInfo(mode: .LZYX, connectionID: connectionID)
                
            }else if(response == "GPARA"){
                print("Send parameters from Acto3D")
                sendParameters(connectionID: connectionID)
                
            }else if(response == "SPARA"){
                print("Set parameters from external software")
                getParametersAndSet(connectionID: connectionID)
                
            }else if(response == "CURIM"){
                print("Send Current Image")
                sendCurrentSliceData(connectionID: connectionID)
                
            }else if(response == "STOP_"){
                print("STOP command")
                stopConnectionByID(connectionID)
                
            }else if(response == "TEXSZ"){
                print("Prepare 3D Texture (TEXSZ)")
                print("Create pipeline")
                
                // To avoid simultanious creation of pipeline in parallel threads, create pipeline first.
                guard let computeFunction = renderer.mtlLibrary.makeFunction(name: "createTextureFromCYX_8bit"),
                      let pipeline = try? renderer.device.makeComputePipelineState(function: computeFunction)
                else {
                    print("Failed in creating pipeline for arranging parallel input iamges.")
                    return
                }
                self.parallelPipeline = pipeline
                
                receiveImageInfo(mode: .TEXSZ, connectionID: connectionID)
                
            }else if(response == "SLICP"){
                print("Accept parallel input (SLICP)")
                receiveAndTransferImageToTexture(connectionID: connectionID)
                
            }else{
                print("Received error code or incompatible version from client.")
                stopConnectionByID(connectionID)
            }
        }
    }
    
    private func receiveImageInfo(mode: ShapeMode, connectionID: Int) {
        guard let connection = connections[connectionID] else {
            print("Connection \(connectionID) not found.")
            return
        }
        
        // Close current session
        if let _ = self.renderer.mainTexture,
           let closeSession = self.vc?.closeCurrentSession(),
           !closeSession{
            // Selected cancel for the dialog.
            print("Continue current session. Stop data interaction.")
            self.stopConnectionByID(connectionID)
            return
        }
        
        switch mode{
        case .ZCYX, .TEXSZ:
            Logger.logPrintAndWrite(message: "Waiting for ZCYX images.")
            connection.receive(minimumIncompleteLength: 16, maximumLength: 16) {[self] (data, _, _, error) in
                if let data = data {
                    let imageInfo = data.withUnsafeBytes {
                        (pointer: UnsafeRawBufferPointer) -> (UInt32, UInt32, UInt32, UInt32) in
                        let depth = pointer.load(fromByteOffset: 0, as: UInt32.self)
                        let channel = pointer.load(fromByteOffset: 4, as: UInt32.self)
                        let height = pointer.load(fromByteOffset: 8, as: UInt32.self)
                        let width = pointer.load(fromByteOffset: 12, as: UInt32.self)
                        return (depth, channel, height, width)
                    }
                    
                    self.imageWidth = imageInfo.3
                    self.imageHeight = imageInfo.2
                    self.imageDepth = imageInfo.0
                    self.imageChannel = imageInfo.1
                    
                    Logger.logPrintAndWrite(message: "Received image info - Z: \(self.imageDepth), C: \(self.imageChannel), Y: \(self.imageHeight), X: \(self.imageWidth)")
                    
                    self.receiveSliceData(mode: mode, connectionID: connectionID)
                    
                } else if let error = error {
                    print("Error receiving image info: \(error)")
                    self.stopConnectionByID(connectionID)
                }
            }
            
        case .ZYX:
            Logger.logPrintAndWrite(message: "Waiting for ZYX images.")
            connection.receive(minimumIncompleteLength: 12, maximumLength: 12) {[self] (data, _, _, error) in
                if let data = data {
                    let imageInfo = data.withUnsafeBytes {
                        (pointer: UnsafeRawBufferPointer) -> (UInt32, UInt32, UInt32) in
                        let depth = pointer.load(fromByteOffset: 0, as: UInt32.self)
                        let height = pointer.load(fromByteOffset: 4, as: UInt32.self)
                        let width = pointer.load(fromByteOffset: 8, as: UInt32.self)
                        return (depth, height, width)
                    }
                    
                    self.imageWidth = imageInfo.2
                    self.imageHeight = imageInfo.1
                    self.imageDepth = imageInfo.0
                    self.imageChannel = 1
                    
                    Logger.logPrintAndWrite(message: "Received image info - Z: \(self.imageDepth), C: \(self.imageChannel), Y: \(self.imageHeight), X: \(self.imageWidth)")
                    
                    self.receiveSliceData(mode: .ZYX, connectionID: connectionID)
                    
                } else if let error = error {
                    print("Error receiving image info: \(error)")
                    self.stopConnectionByID(connectionID)
                }
            }
            
        case .LZYX:
            Logger.logPrintAndWrite(message: "Waiting for LZYX images.")
            connection.receive(minimumIncompleteLength: 16, maximumLength: 16) {[self] (data, _, _, error) in
                if let data = data {
                    let imageInfo = data.withUnsafeBytes {
                        (pointer: UnsafeRawBufferPointer) -> (UInt32, UInt32, UInt32, UInt32) in
                        let channel = pointer.load(fromByteOffset: 0, as: UInt32.self)
                        let depth = pointer.load(fromByteOffset: 4, as: UInt32.self)
                        let width = pointer.load(fromByteOffset: 8, as: UInt32.self)
                        let height = pointer.load(fromByteOffset: 12, as: UInt32.self)
                        return (channel, depth, height, width)
                    }
                    
                    self.imageWidth = imageInfo.3
                    self.imageHeight = imageInfo.2
                    self.imageDepth = imageInfo.1
                    self.imageChannel = imageInfo.0
                    
                    Logger.logPrintAndWrite(message: "Received image info - Z: \(self.imageDepth), C: \(self.imageChannel), Y: \(self.imageHeight), X: \(self.imageWidth)")
                    
                    self.receiveSliceData(mode: .LZYX, connectionID: connectionID)
                    
                } else if let error = error {
                    print("Error receiving image info: \(error)")
                    self.stopConnectionByID(connectionID)
                }
            }
        }
    }
    
    private func receiveSliceData(mode: ShapeMode, connectionID: Int) {
        guard let _ = connections[connectionID] else {
            print("Connection \(connectionID) not found.")
            return
        }
        
        // initialize renderer params
        renderer.volumeData = VolumeData(outputImageWidth: imageWidth.toUInt16(),
                                         outputImageHeight: imageHeight.toUInt16(),
                                         inputImageWidth: imageWidth.toUInt16(),
                                         inputImageHeight: imageHeight.toUInt16(),
                                         inputImageDepth: imageDepth.toUInt16(),
                                         numberOfComponent: imageChannel.toUInt8())
        renderer.imageParams = ImageParameters()
        let max = 2<<(8-1) - 1
        renderer.imageParams.displayRanges = [[Double]](repeating: [0, max.toDouble()],
                                                        count: renderer.volumeData.numberOfComponent.toInt())
        
        // progressbar setting
        vc?.progressBar.isHidden = false
        vc?.progressBar.maxValue = (imageDepth.toInt() - 1).toDouble()
        vc?.progressBar.minValue = 0.0
        vc?.progressBar.doubleValue = 0
        vc?.progressBar.contentFilters = [
            CIFilter(name: "CIHueAdjust", parameters: ["inputAngle": NSNumber(value: 4)])!
        ]
        
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
        
        if(mode == .TEXSZ){
            print("Prepared 3D texture for parallel input.")
            self.stopConnectionByID(connectionID)
            return
            
        }else{
            self.waitingSliceData(mode: mode, connectionID: connectionID)
        }
    }
    
    
    /// transfer each slice for z
    private func receiveAndTransferImageToTexture(connectionID: Int){
        guard let connection = connections[connectionID] else {
            print("Connection \(connectionID) not found.")
            return
        }
        
        // actual data size for 1 slice image (= byte in 8 bits image)
        let sliceSize = Int(imageWidth * imageHeight * imageChannel)
        
        connection.receive(minimumIncompleteLength: sliceSize + 4, maximumLength: sliceSize + 4) {[self] (data, _, isComplete, error) in
            if let data = data {
                let zInformation = data.subdata(in: 0..<4).withUnsafeBytes { $0.load(as: UInt32.self) }
                print("Received slice index (z): \(zInformation)")
                
                let imageData = data.subdata(in: 4..<data.count)
                
                // Allocate data memory region for 4 channels
                let pxCountPerSlice = self.imageWidth.toInt() * self.imageHeight.toInt() * 4
                
                let bufferSizePerSlice = MemoryLayout<UInt8>.stride * pxCountPerSlice
                let options: MTLResourceOptions = [.storageModeShared, .cpuCacheModeWriteCombined ]
                
                guard let cpuBuffer = renderer.device.makeBuffer(length: bufferSizePerSlice, options: options),
                      let gpuBuffer = renderer.device.makeBuffer(length: bufferSizePerSlice, options: .storageModePrivate) else {
                    Logger.logPrintAndWrite(message: "  Error in creating CPU or GPU buffers", level: .error)
                    self.stopConnectionByID(connectionID)
                    return
                }
                
                let cpuPixels = cpuBuffer.contents().bindMemory(to: UInt8.self, capacity: pxCountPerSlice)
                
                // Copy image data to CPU buffer (CYX)
                imageData.withUnsafeBytes { rawPtr in
                    if let ptr = rawPtr.baseAddress?.assumingMemoryBound(to: UInt8.self){
                        memmove(&cpuPixels[0], ptr, sliceSize)
                    }
                }
                
                guard let commandBuffer = renderer.cmdQueue.makeCommandBuffer(),
                      let blitEncoder = commandBuffer.makeBlitCommandEncoder() else {
                    self.stopConnectionByID(connectionID)
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
                
                // Kernel Funciton
                guard let arrangeCommandBuffer = renderer.cmdQueue.makeCommandBuffer(),
                      let computeEncoder = arrangeCommandBuffer.makeComputeCommandEncoder(),
                      let computeFunction = renderer.mtlLibrary.makeFunction(name: "createTextureFromCYX_8bit")
                else {
                    print("Error in creating compute command buffer or function")
                    return
                }
                arrangeCommandBuffer.label = "Arrange Pixel Buffer"
                computeEncoder.label = "Arrangement Encoder"
                computeFunction.label = "Arrange Function"
                
                guard let parallelPipeline = self.parallelPipeline else{
                    print("Parallel render pipeline has not preapared yet.")
                    self.stopConnectionByID(connectionID)
                    return
                }
                
                computeEncoder.setComputePipelineState(parallelPipeline)
                
                var zPosition = zInformation.toUInt16()
                var originalNumberOfComponents: UInt8 = self.imageChannel.toUInt8()
                
                computeEncoder.setBuffer(gpuBuffer, offset: 0, index: 0)
                computeEncoder.setBytes(&renderer.volumeData, length: MemoryLayout<VolumeData>.stride, index: 1)
                computeEncoder.setBytes(&originalNumberOfComponents, length: MemoryLayout<UInt8>.stride, index: 2)
                computeEncoder.setBytes(&zPosition, length: MemoryLayout<UInt16>.stride, index: 3)
                computeEncoder.setTexture(renderer.mainTexture, index: 0)
                
                if(renderer.device.checkNonUniformThreadgroup() == true){
                    let threadGroupSize = MTLSizeMake(parallelPipeline.threadExecutionWidth, parallelPipeline.maxTotalThreadsPerThreadgroup / parallelPipeline.threadExecutionWidth, 1)
                    computeEncoder.dispatchThreads(MTLSize(width: self.imageWidth.toInt(), height: self.imageHeight.toInt(), depth: 1),
                                                   threadsPerThreadgroup: threadGroupSize)
                    
                }else{
                    let threadGroupSize = MTLSize(width: parallelPipeline.threadExecutionWidth,
                                                  height: parallelPipeline.maxTotalThreadsPerThreadgroup / parallelPipeline.threadExecutionWidth,
                                                  depth: 1)
                    let threadGroups = MTLSize(width: (self.imageWidth.toInt() + threadGroupSize.width - 1) / threadGroupSize.width,
                                               height: (self.imageHeight.toInt() + threadGroupSize.height - 1) / threadGroupSize.height,
                                               depth: 1)
                    computeEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)
                    
                }
                
                computeEncoder.endEncoding()
                arrangeCommandBuffer.commit()
                
                // Update progress bar
                DispatchQueue.main.async {[self] in
                    self.vc?.progressBar.increment(by: 1)
                }
                
                self.stopConnectionByID(connectionID)
            }
        }
    }
    
    
    private func waitingSliceData(mode: ShapeMode, connectionID: Int){
        guard let connection = connections[connectionID] else {
            print("Connection \(connectionID) not found.")
            return
        }
        
        if receivedSlices >= imageDepth {
            vc?.zScale_Slider.floatValue = self.renderer.renderParams.zScale
            vc?.updateSliceAndScale(currentSliceToMax: true)
            
            vc?.xResolutionField.floatValue = renderer.imageParams.scaleX
            vc?.yResolutionField.floatValue = renderer.imageParams.scaleY
            vc?.zResolutionField.floatValue = renderer.imageParams.scaleZ
            vc?.scaleUnitField.stringValue = renderer.imageParams.unit
            
            vc?.progressBar.isHidden = true
            vc?.progressBar.doubleValue = 0
            vc?.outputView.image = renderer.rendering()
            
            // Waiting for end signal
            receiveEndSignal(connectionID: connectionID)
            
            return
        }
        
        // actual data size for 1 slice image (= byte in 8 bits image)
        let sliceSize = Int(imageWidth * imageHeight * imageChannel)
        
        connection.receive(minimumIncompleteLength: sliceSize, maximumLength: sliceSize) {[self] (data, _, isComplete, error) in
            guard let data = data else {
                if let error = error {
                    print("Error receiving slice data: \(error)")
                    self.stopConnectionByID(connectionID)
                }
                return
            }
            
            if(self.receivedSlices % 10 == 0){
                //                Logger.logPrintAndWrite(message: " Data transfer... (\(self.receivedSlices+1) / \(self.imageDepth))", level: .info)
            }
            
            // Allocate data memory region for 4 channels
            var pxCountPerSlice = self.imageWidth.toInt() * self.imageHeight.toInt() * 4
            
            autoreleasepool{
                let dataArray = [UInt8](data)
                
                let bufferSizePerSlice = MemoryLayout<UInt8>.stride * pxCountPerSlice
                let options: MTLResourceOptions = [.storageModeShared, .cpuCacheModeWriteCombined ]
                
                guard let cpuBuffer = renderer.device.makeBuffer(length: bufferSizePerSlice, options: options),
                      let gpuBuffer = renderer.device.makeBuffer(length: bufferSizePerSlice, options: .storageModePrivate) else {
                    Logger.logPrintAndWrite(message: "  Error in creating CPU or GPU buffers", level: .error)
                    self.stopConnectionByID(connectionID)
                    return
                }
                
                let cpuPixels = cpuBuffer.contents().bindMemory(to: UInt8.self, capacity: pxCountPerSlice)
                
                // Copy image data to CPU buffer (CYX)
                memmove(&cpuPixels[0], dataArray, sliceSize)
                
                guard let commandBuffer = renderer.cmdQueue.makeCommandBuffer(),
                      let blitEncoder = commandBuffer.makeBlitCommandEncoder() else {
                    self.stopConnectionByID(connectionID)
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
                guard let arrangeCommandBuffer = renderer.cmdQueue.makeCommandBuffer(),
                      let computeEncoder = arrangeCommandBuffer.makeComputeCommandEncoder(),
                      let computeFunction = renderer.mtlLibrary.makeFunction(name: "createTextureFromCYX_8bit")
                else {
                    print("Error in creating compute command buffer or function")
                    return
                }
                arrangeCommandBuffer.label = "Arrange Pixel Buffer"
                computeEncoder.label = "Arrangement Encoder"
                computeFunction.label = "Arrange Function"
                
                // create render pipeline if first slice
                if receivedSlices == 0 {
                    do{
                        renderPipeline = try renderer.device.makeComputePipelineState(function: computeFunction)
                    }catch{
                        Logger.logOnlyToFile(message: "  Error in creating pipeline for pixel arrangement function")
                    }
                    
                }
                computeEncoder.setComputePipelineState(renderPipeline)
                
                var zPosition = receivedSlices.toUInt16()
                var originalNumberOfComponents: UInt8 = self.imageChannel.toUInt8()
                
                // Set resources for the compute shader
                computeEncoder.setBuffer(gpuBuffer, offset: 0, index: 0)
                computeEncoder.setBytes(&renderer.volumeData, length: MemoryLayout<VolumeData>.stride, index: 1)
                computeEncoder.setBytes(&originalNumberOfComponents, length: MemoryLayout<UInt8>.stride, index: 2)
                computeEncoder.setBytes(&zPosition, length: MemoryLayout<UInt16>.stride, index: 3)
                computeEncoder.setTexture(renderer.mainTexture, index: 0)
                
                
                if(renderer.device.checkNonUniformThreadgroup() == true){
                    let threadGroupSize = MTLSizeMake(renderPipeline.threadExecutionWidth, renderPipeline.maxTotalThreadsPerThreadgroup / renderPipeline.threadExecutionWidth, 1)
                    computeEncoder.dispatchThreads(MTLSize(width: self.imageWidth.toInt(), height: self.imageHeight.toInt(), depth: 1),
                                                   threadsPerThreadgroup: threadGroupSize)
                    
                }else{
                    let threadGroupSize = MTLSize(width: renderPipeline.threadExecutionWidth,
                                                  height: renderPipeline.maxTotalThreadsPerThreadgroup / renderPipeline.threadExecutionWidth,
                                                  depth: 1)
                    let threadGroups = MTLSize(width: (self.imageWidth.toInt() + threadGroupSize.width - 1) / threadGroupSize.width,
                                               height: (self.imageHeight.toInt() + threadGroupSize.height - 1) / threadGroupSize.height,
                                               depth: 1)
                    computeEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)
                    
                }
                
                computeEncoder.endEncoding()
                arrangeCommandBuffer.commit()
                
                // Update progress bar
                DispatchQueue.main.async {[self] in
                    self.vc?.progressBar.increment(by: 1)
                }
                
            }
            
            self.receivedSlices += 1
            
            // wait for next slice
            if !isComplete {
                self.waitingSliceData(mode: mode, connectionID: connectionID)
            }
        }
    }
    
    private func receiveEndSignal(connectionID: Int) {
        guard let connection = connections[connectionID] else {
            print("Connection \(connectionID) not found.")
            return
        }
        
        connection.receive(minimumIncompleteLength: 3, maximumLength: 3) {[self] (data, _, isComplete, error) in
            if let data = data, let signal = String(data: data, encoding: .utf8), signal == "END" {
                print("Received end signal. Data transmission completed successfully.")
                
                //                Logger.logPrintAndWrite(message: "Data transfer succeeded.", level: .info)
                
                self.stopConnectionByID(connectionID)
                
            } else if let error = error {
                print("Error receiving end signal: \(error)")
                self.stopConnectionByID(connectionID)
            }
        }
    }
    
    
    private func stopConnectionByID(_ connectionID: Int) {
        if let connection = connections[connectionID] {
            connection.cancel()
            connections.removeValue(forKey: connectionID)
            print("Connection \(connectionID) will stop.")
        }
    }
    
    
    public func sendParameters(connectionID: Int){
        guard let connection = connections[connectionID] else {
            print("Connection \(connectionID) not found.")
            return
        }
        
        connection.receive(minimumIncompleteLength: 4, maximumLength: 4) {[weak self] (lengthData, _, _, error) in
            if let strLength = lengthData?.withUnsafeBytes({$0.load(as: UInt32.self)}){
                connection.receive(minimumIncompleteLength: Int(strLength), maximumLength: Int(strLength)) {[weak self] (data, _, _, error) in
                    guard let data = data,
                    let cmd = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .controlCharacters) else {
                        print("Error receiving message: \(error?.localizedDescription ?? "Unknown error")")
                        self?.stopConnectionByID(connectionID)
                        return
                    }
                    
                    switch cmd {
                    case "getCurrentSliceNo":
                        if let params = self?.renderer.renderParams.sliceNo.toUInt32(){
                            self?.sendValue(connection: connection, connectionID: connectionID, value: params, completion: { result in
                                self?.stopConnectionByID(connectionID)
                            })
                        }
                        
                    case "getCurrentScale":
                        if let params = self?.renderer.renderParams.scale{
                            self?.sendValue(connection: connection, connectionID: connectionID, value: params, completion: { result in
                                self?.stopConnectionByID(connectionID)
                            })
                        }
                        
                    case "getCurrentZScale":
                        if let params = self?.renderer.renderParams.zScale{
                            self?.sendValue(connection: connection, connectionID: connectionID, value: params, completion: { result in
                                self?.stopConnectionByID(connectionID)
                            })
                        }
                        
                    case "getSliceImage":
                        self?.sendSliceImage(connection: connection, connectionID: connectionID, completion: { result in
                            self?.stopConnectionByID(connectionID)
                        })
                                                
                        
                    default:
                        print("Invalid connection commands.")
                        self?.stopConnectionByID(connectionID)
                    }
                    
                }
            }
        }
    }
    
    private func sendSliceImage(connection: NWConnection, connectionID: Int, completion: @escaping (Bool) -> Void){
        connection.receive(minimumIncompleteLength: 9, maximumLength: 9) {[weak self] (data, _, _, error) in
            if let data = data{
                let args = data.withUnsafeBytes {
                    (pointer: UnsafeRawBufferPointer) -> (UInt32, UInt32,  Bool) in
                    let sliceNo = pointer.load(fromByteOffset: 0, as: UInt32.self)
                    let targetViewSize = pointer.load(fromByteOffset: 4, as: UInt32.self)
                    let refreshView = pointer.load(fromByteOffset: 8, as: Bool.self)
                    return (sliceNo, targetViewSize, refreshView)
                }
                
                self?.renderer.renderParams.sliceNo = args.0.toUInt16()
                
                guard let image = self?.renderer.rendering(targetViewSize: args.1.toUInt16()) ,
                      let currentData = self?.renderer.getCurrentImageData(),
                      let imageData = currentData.data
                else{
                    print("Failed in creating image for slice with view size:\(args.1)")
                    completion(false)
                    return
                }
                
                if(args.2 == true){
                    // refresh view
                    self?.vc?.outputView.image = image
                }

                
                connection.send(content: imageData, completion: .contentProcessed({[weak self] error in
                    if let error = error {
                        print("Error sending image data: \(error)")
                        self?.stopConnectionByID(connectionID)
                        completion(false)
                        return
                    }
                    
                    completion(true)
                    
                }))
                
            }
        }
    }
    
    private func sendValue<T>(connection:NWConnection, connectionID: Int, value: T, completion: @escaping (Bool) -> Void){
        var value = value
        let valueData = Data(bytes: &value, count: MemoryLayout<T>.size)
        
        connection.send(content: valueData, completion: .contentProcessed({[weak self] error in
            if let error = error {
                print("Error sending parameters: \(error)")
                self?.stopConnectionByID(connectionID)
                completion(false)
                return
            }
            
            completion(true)
        }))
    }
    
    public func sendCurrentSliceData(connectionID: Int){
        guard let connection = connections[connectionID] else {
            print("Connection \(connectionID) not found.")
            return
        }
        
        let currentData = renderer.getCurrentImageData()
        guard let imageData = currentData.data,
              let imageSize = currentData.viewSize else{
            return
        }
        
        // Send image size info (currently, width = height)
        var width = UInt32(imageSize)
        var height = UInt32(imageSize)
        var imageSizeData = Data(bytes: &width, count: 4)
        imageSizeData.append(Data(bytes: &height, count: 4))
        
        connection.send(content: imageSizeData, completion: .contentProcessed({[self] error in
            if let error = error {
                print("Failed to send size data:", error)
                return
            }
            print("Send image size")
            
            connection.send(content: imageData, completion: .contentProcessed({[self] error in
                if let error = error {
                    print("Failed to send image data:", error)
                    return
                }
                print("Image data sent successfully.")
                
                self.receiveEndSignal(connectionID: connectionID)
            }))
        }))
    }
    
    /// Set parameters from external apps.
    public func getParametersAndSet(connectionID: Int){
        guard let connection = connections[connectionID] else {
            print("Connection \(connectionID) not found.")
            return
        }
        
        connection.receive(minimumIncompleteLength: 4, maximumLength: 4) {[weak self] (lengthData, _, _, error) in
            if let strLength = lengthData?.withUnsafeBytes({$0.load(as: UInt32.self)}){
                connection.receive(minimumIncompleteLength: Int(strLength), maximumLength: Int(strLength)) {[weak self] (data, _, _, error) in
                    guard let data = data,
                          let cmd = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .controlCharacters) else {
                        print("Error receiving message: \(error?.localizedDescription ?? "Unknown error")")
                        self?.stopConnectionByID(connectionID)
                        return
                    }
                    
                    switch cmd {
                    case "setScale":
                        self?.getValue(connection: connection, type: Float.self, completion: {[weak self] result in
                            switch result {
                            case .success(let value):
                                print("Set scale value to :\(value)")
                                self?.renderer.renderParams.scale = value
                                self?.vc?.scale_Slider.floatValue = value
                                self?.vc?.scale_Label.floatValue = value
                                self?.vc?.outputView.image = self?.renderer.rendering()
                                
                            case .failure(let error):
                                print(error)
                                
                            }
                            self?.stopConnectionByID(connectionID)
                        })
                        
                    case "setZScale":
                        self?.getValue(connection: connection, type: Float.self, completion: {[weak self] result in
                            switch result {
                            case .success(let value):
                                print("Set scale value to :\(value)")
                                self?.renderer.renderParams.zScale = value
                                self?.vc?.zScale_Slider.floatValue = value
                                self?.vc?.zScale_Label.floatValue = value
                                self?.vc?.outputView.image = self?.renderer.rendering()
                                
                            case .failure(let error):
                                print(error)
                                
                            }
                            self?.stopConnectionByID(connectionID)
                        })
                        
                    case "setSlice":
                        self?.getValue(connection: connection, type: UInt32.self, completion: {[weak self] result in
                            switch result {
                            case .success(let value):
                                print("Set slice value to :\(value)")
                                self?.renderer.renderParams.sliceNo = value.toUInt16()
                                self?.vc?.slice_Slider.integerValue = value.toInt()
                                self?.vc?.slice_Label_current.integerValue = value.toInt()
                                self?.vc?.outputView.image = self?.renderer.rendering()
                                
                            case .failure(let error):
                                print(error)
                                
                            }
                            self?.stopConnectionByID(connectionID)
                        })
                        
                        
                    case "setVoxelSize":
                        connection.receive(minimumIncompleteLength: 32, maximumLength: 32) {[weak self] (data, _, _, error) in
                            if let data = data {
                                let imageInfo = data.withUnsafeBytes {
                                    (pointer: UnsafeRawBufferPointer) -> (Float, Float, Float, String) in
                                    let resX = pointer.load(fromByteOffset: 0, as: Float.self)
                                    let resY = pointer.load(fromByteOffset: 4, as: Float.self)
                                    let resZ = pointer.load(fromByteOffset: 8, as: Float.self)
                                    let unitStr = String(data: data[12...31], encoding: .utf8)?.trimmingCharacters(in: .init(charactersIn: "\0")) ?? ""
                                    return (resX, resY, resZ, unitStr)
                                }
                                print("Set voxel value to :\(imageInfo)")
                                
                                self?.renderer.imageParams.scaleX = imageInfo.0
                                self?.renderer.imageParams.scaleY = imageInfo.1
                                self?.renderer.imageParams.scaleZ = imageInfo.2
                                self?.renderer.imageParams.unit = imageInfo.3
                                
                                self?.vc?.xResolutionField.floatValue = imageInfo.0
                                self?.vc?.yResolutionField.floatValue = imageInfo.1
                                self?.vc?.zResolutionField.floatValue = imageInfo.2
                                self?.vc?.scaleUnitField.stringValue = imageInfo.3
                                
                                self?.vc?.showIsortopicView(imageInfo)
                            }
                            self?.stopConnectionByID(connectionID)
                        }
                        
                    default:
                        print("Invalid connection commands.")
                        self?.stopConnectionByID(connectionID)
                    }
                }
            }
        }
    }
    
    private func getValue<T>(connection:NWConnection, type: T.Type, completion: @escaping (Result<T, Error>) -> Void)  {//where T: FixedWidthInteger
        connection.receive(minimumIncompleteLength: MemoryLayout<T>.size, maximumLength: MemoryLayout<T>.size) { (data, _, _, error) in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data, data.count == MemoryLayout<T>.size else {
                completion(.failure(NWError.posix(POSIXErrorCode.EBADMSG)))
                return
            }
            
            let value = data.withUnsafeBytes {
                $0.load(as: T.self)
            }
            completion(.success(value))
        }
    }
    
    
    func stop(byError:Bool=false) {
        listener?.cancel()
        print("Server stopped")
    }
    
    
    deinit {
        listener?.cancel()
        print("Server on port \(self.port) is closed.")
        Logger.logPrintAndWrite(message: "Shutdown TCP Server.")
    }
    
    
    static func getLocalIPAddress() -> String? {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else { return nil }
        guard let firstAddr = ifaddr else { return nil }
        
        for ifptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let interface = ifptr.pointee
            let addrFamily = interface.ifa_addr.pointee.sa_family
            if addrFamily == UInt8(AF_INET) { // IPv4
                var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                let success = getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                                          &hostname, socklen_t(hostname.count),
                                          nil, socklen_t(0), NI_NUMERICHOST) == 0
                if success {
                    let currentAddress = String(cString: hostname)
                    if interface.ifa_flags & UInt32(IFF_LOOPBACK) == 0 { // exclude 127.0.0.1
                        address = currentAddress
                        break
                    }
                }
            }
        }
        freeifaddrs(ifaddr)
        return address
    }
}
