//
//  TCPServer.swift
//  tcptest
//
//  Created by Naoki Takeshita on 2024/02/20.
//

import Foundation
import Network
import Cocoa


protocol TCPServerDelegate: AnyObject {
    func startDataTransfer(sender: TCPServer)
}

class TCPServer {
    let port: NWEndpoint.Port
    var listener: NWListener?
    var connection: NWConnection?
    
    enum ShapeMode{
        case ZCYX
        case ZYX
        case LZYX
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
    
    var renderer:VoluemeRenderer!
    
    var renderPipeline:MTLComputePipelineState!
    
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
        
        listener?.stateUpdateHandler = { state in
            print("Listener state: \(state)")
            
            switch state {
            case .ready:
                Logger.logPrintAndWrite(message: "Acto3D is accepting data input (Port: \(AppConfig.TCP_PORT))")
                print("TCP Server is ready at port \(self.port)")
            case .setup:
                print("Listerner setuped")
                
            case .failed(let error):
                print("Server failed with error: \(error)")
                self.stop(byError: true)
                
            default:
                break
            }
        }
        
        listener?.newConnectionHandler = { newConnection in
            self.connection = newConnection
            self.handleConnection()
        }
        
        listener?.start(queue: .main)
    }
    
    
    private func handleConnection() {
        connection?.start(queue: .main)
        
        receiveStartSignal()
    }
    
    private func receiveStartSignal() {
        receivedSlices = 0
        
        connection?.receive(minimumIncompleteLength: 1, maximumLength: 5) { (data, _, _, error) in
            if let data = data, let signal = String(data: data, encoding: .utf8), signal == "START" {
                print("Received start signal")
                
                self.delegate?.startDataTransfer(sender: self)
                
            } else if let error = error {
                print("Error receiving start signal: \(error)")
                self.stop(byError: true)
                
            }
        }
    }
    
    public func sendVersionInfoToStartTransferSession() {
        let versionString = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
        let versionData = Data(versionString.utf8)
        connection?.send(content: versionData, completion: .contentProcessed({ sendError in
            if let sendError = sendError {
                print("Failed to send version info: \(sendError)")
                self.stop(byError: true)
                return
            }
            print("Version info sent successfully.")
            
            self.waitForClientResponse()
        }))
    }
    
    public func sendCurrentSliceData(){
        let currentData = renderer.getCurrentImageData()
        guard let imageData = currentData.data,
              let imageSize = currentData.viewSize else{
            return
        }
        
        // 画像のサイズ（幅と高さ）をUInt32で送信
        var width = UInt32(imageSize)
        var height = UInt32(imageSize) // この例では幅と高さが同じと仮定
        var imageSizeData = Data(bytes: &width, count: 4)
        imageSizeData.append(Data(bytes: &height, count: 4))

        connection?.send(content: imageSizeData, completion: .contentProcessed({ error in
            if let error = error {
                print("Failed to send size data:", error)
                return
            }
            print("Send image size")
            
            self.connection?.send(content: imageData, completion: .contentProcessed({ error in
                if let error = error {
                    print("Failed to send image data:", error)
                    return
                }
                print("Image data sent successfully.")
                
                self.receiveEndSignal()
            }))
        }))
    }
    
    
    private func waitForClientResponse() {
        connection?.receive(minimumIncompleteLength: 5, maximumLength: 5) {(data, _, _, error) in
            guard let data = data, error == nil, let response = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .controlCharacters) else {
                print("Error receiving client response or connection error: \(error?.localizedDescription ?? "Unknown error")")
                
                
                
                return
            }

            if (response == "ZCYX_"){
                print("Data type would be ZCYX")
                self.receiveImageInfo(mode: .ZCYX)
                
            }else if(response == "ZYX__"){
                print("Data type would be ZYX")
                self.receiveImageInfo(mode: .ZYX)
                
            }else if(response == "LZYX_"){
                print("Data type would be LZYX")
                self.receiveImageInfo(mode: .LZYX)
                
            }else if(response == "VOXEL"){
                print("Set Voxel size")
                self.setParameters(mode: .VOXEL)
                
            }else if(response == "SLICE"){
                print("Set Slice")
                self.setParameters(mode: .SLICE)
                
            }else if(response == "SCALE"){
                print("Set Scale")
                self.setParameters(mode: .SCALE)
                
            }else if(response == "CURIM"){
                print("Send Current Image")
                self.sendCurrentSliceData()
                
            }else{
                print("Received error code or incompatible version from client.")
                self.stop(byError: true)
            }
        }
    }
    
    private func setParameters(mode: ParameterMode) {
        switch mode{
        case .VOXEL:
            connection?.receive(minimumIncompleteLength: 32, maximumLength: 32) { (data, _, _, error) in
                if let data = data {
                    let imageInfo = data.withUnsafeBytes {
                        (pointer: UnsafeRawBufferPointer) -> (Float, Float, Float, String) in
                        let resX = pointer.load(fromByteOffset: 0, as: Float.self)
                        let resY = pointer.load(fromByteOffset: 4, as: Float.self)
                        let resZ = pointer.load(fromByteOffset: 8, as: Float.self)
                        let unitStr = String(data: data[12...31], encoding: .utf8)?.trimmingCharacters(in: .init(charactersIn: "\0")) ?? ""
                        return (resX, resY, resZ, unitStr)
                    }
                    
                    self.renderer.imageParams.scaleX = imageInfo.0
                    self.renderer.imageParams.scaleY = imageInfo.1
                    self.renderer.imageParams.scaleZ = imageInfo.2
                    self.renderer.imageParams.unit = imageInfo.3
                    
                    self.vc?.xResolutionField.floatValue = imageInfo.0
                    self.vc?.yResolutionField.floatValue = imageInfo.1
                    self.vc?.zResolutionField.floatValue = imageInfo.2
                    self.vc?.scaleUnitField.stringValue = imageInfo.3
                    
                    self.vc?.showIsortopicView(self)
                    
                    // Waiting for end signal
                    self.receiveEndSignal()
                    
                } else if let error = error {
                    print("Error receiving image info: \(error)")
                    self.stop(byError: true)
                }
            }
            
        case .SCALE:
            connection?.receive(minimumIncompleteLength: 4, maximumLength: 4) { (data, _, _, error) in
                if let data = data {
                    let scale = data.withUnsafeBytes {
                        $0.load(as: Float.self)
                    }
                    
                    self.renderer.renderParams.scale = scale
                    self.vc?.scale_Slider.floatValue = scale
                    self.vc?.scale_Label.floatValue = scale
                    self.vc?.outputView.image = self.renderer.rendering()
                    
                    // Waiting for end signal
                    self.receiveEndSignal()
                    
                } else if let error = error {
                    print("Error receiving image info: \(error)")
                    self.stop(byError: true)
                }
            }
            
        case .SLICE:
            connection?.receive(minimumIncompleteLength: 4, maximumLength: 4) { (data, _, _, error) in
                if let data = data {
                    let sliceNo = data.withUnsafeBytes {
                        $0.load(as: UInt32.self)
                    }
                    
                    self.renderer.renderParams.sliceNo = sliceNo.toUInt16()
                    self.vc?.slice_Slider.integerValue = sliceNo.toInt()
                    self.vc?.slice_Label_current.integerValue = sliceNo.toInt()
                    self.vc?.outputView.image = self.renderer.rendering()
                    
                    // Waiting for end signal
                    self.receiveEndSignal()
                    
                } else if let error = error {
                    print("Error receiving image info: \(error)")
                    self.stop(byError: true)
                }
            }
        default:
            break
        }
    }
    
    private func receiveImageInfo(mode: ShapeMode) {
        if let _ = self.renderer.mainTexture {
            if let closeSession = self.vc?.closeCurrentSession(),
               !closeSession{
                return
            }else{
            }
        }else{
        }
        
        switch mode{
        case .ZCYX:
            Logger.logPrintAndWrite(message: "Waiting for ZCYX images.")
            connection?.receive(minimumIncompleteLength: 16, maximumLength: 16) { (data, _, _, error) in
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
                    
                    
                    self.receiveSliceData(mode: .ZCYX)
                    
                } else if let error = error {
                    print("Error receiving image info: \(error)")
                    self.stop(byError: true)
                }
            }
            
        case .ZYX:
            Logger.logPrintAndWrite(message: "Waiting for ZYX images.")
            connection?.receive(minimumIncompleteLength: 12, maximumLength: 12) { (data, _, _, error) in
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
                    
                    
                    self.receiveSliceData(mode: .ZYX)
                    
                } else if let error = error {
                    print("Error receiving image info: \(error)")
                    self.stop(byError: true)
                }
            }
            
        case .LZYX:
            Logger.logPrintAndWrite(message: "Waiting for LZYX images.")
            connection?.receive(minimumIncompleteLength: 16, maximumLength: 16) { (data, _, _, error) in
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
                    
                    
                    self.receiveSliceData(mode: .LZYX)
                    
                } else if let error = error {
                    print("Error receiving image info: \(error)")
                    self.stop(byError: true)
                }
            }
            
        default:
            break
        }
    }
    
    
    private func receiveSliceData(mode: ShapeMode) {
        print("Prepare for accepting data, and create texture base.")
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
        
        // texture setting    // texture setting
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
        
        self.waitingSliceData(mode: mode)
    }
    
    private func waitingSliceData(mode: ShapeMode){
        print("Waiting for slice data")
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
            receiveEndSignal()
            
            return
        }
        
        // actual data size for 1 slice image (= byte in 8 bits image)
        let sliceSize = Int(imageWidth * imageHeight * imageChannel)
        
        connection?.receive(minimumIncompleteLength: sliceSize, maximumLength: sliceSize) { [self] (data, _, isComplete, error) in
            print("slice", receivedSlices)
            
            guard let data = data else {
                if let error = error {
                    print("Error receiving slice data: \(error)")
                    self.stop(byError: true)
                }
                return
            }
            
            if(self.receivedSlices % 10 == 0){
                Logger.logPrintAndWrite(message: " Data transfer... (\(self.receivedSlices+1) / \(self.imageDepth))", level: .info)
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
                    return
                }
                
                let cpuPixels = cpuBuffer.contents().bindMemory(to: UInt8.self, capacity: pxCountPerSlice)
                
                // Copy image data to CPU buffer (CYX)
                memmove(&cpuPixels[0], dataArray, sliceSize)
                
                guard let commandBuffer = renderer.cmdQueue.makeCommandBuffer(),
                      let blitEncoder = commandBuffer.makeBlitCommandEncoder() else {
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
                self.waitingSliceData(mode: mode)
            }
        }
    }
    
    
    private func receiveEndSignal() {
        connection?.receive(minimumIncompleteLength: 3, maximumLength: 3) { (data, _, isComplete, error) in
            if let data = data, let signal = String(data: data, encoding: .utf8), signal == "END" {
                print("Received end signal. Data transmission completed successfully.")
    
                Logger.logPrintAndWrite(message: "Data transfer succeeded.", level: .info)
 
                
                self.receiveStartSignal()
                
            } else if let error = error {
                print("Error receiving end signal: \(error)")
                self.stop(byError: true)
            }
        }
    }

    
    
    func stop(byError:Bool=false) {
        connection?.cancel()
        listener?.cancel()
        print("Server stopped")
    }
    
    
    deinit {
        connection?.cancel()
        listener?.cancel()
        print("Server on port \(self.port) is stopped.")
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
                    if interface.ifa_flags & UInt32(IFF_LOOPBACK) == 0 { // 127.0.0.1 を除外
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
