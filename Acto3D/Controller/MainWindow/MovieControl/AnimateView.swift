//
//  AnimateView.swift
//  Acto3D
//
//  Created by Naoki Takeshita on 2022/03/07.
//

import Foundation
import Cocoa
import Metal
import MetalKit

class AnimateController{
    
    var isCancelled = false
    
    enum AnimationType:Int {
        case undefined = 0
        case rotate_L = 1
        case rotate_R = 2
        case rotate_T = 3
        case rotate_B = 4
        case fileToFile = 5
        case fileToFile_rotate_L = 6
        case fileToFile_rotate_R = 7
        case fileToFile_rotate_T = 8
        case fileToFile_rotate_B = 9
        case pause = 10
    }
    
    var workingDir:URL!
    
    var name:String{
        get{
            return NSDate().timeStampYYYYMMDDHHMMSS()
        }
    }
    
    var settingFileList:[String] = []
    
    struct Motion{
        var FPS:Float = 30.0
        var type:AnimationType = .undefined
        var startParamFileName:String = ""
        var endParamFileName:String = ""
        var duration:Float = 1000.0
        var name = ""
        var startParams:RenderingParameters = RenderingParameters()
        var endParams:RenderingParameters = RenderingParameters()
    }
    
    var motionArray:[Motion] = []
    
    init(){
        
    }
    
    func addMotion(motion: Motion){
        motionArray.append(motion)
    }
    
    func addEmptyPlistMotion(){
        var motion = Motion()
        motion.type = .fileToFile
        motionArray.append(motion)
    }
    func addEmptyRotationMotion(){
        var motion = Motion()
        motion.type = .rotate_L
        motionArray.append(motion)
    }
    
    
    
}

extension ViewController{
    @IBAction func addMotionButton(_ sender:Any){
        reloadPlistForAnimate(self)
        movSeq.animateController.addEmptyPlistMotion()
        movSeq.view.reloadData()
    }
    
    @IBAction func addRotation(_ sender:Any){
        reloadPlistForAnimate(self)
        movSeq.animateController.addEmptyRotationMotion()
        movSeq.view.reloadData()
        
    }
    
    @IBAction func reloadPlistForAnimate(_ sender:Any){
        guard let filePackage = filePackage else {return}
        
        guard let paramsPackage = filePackage.enumerateParameterFiles() else{
            movSeq.paramsPackage = []
            return
        }
        
        movSeq.paramsPackage = paramsPackage
        movSeq.setParamPackageToItems()
    }
    
    // sequencially preview
    @IBAction func previewMotionSequence(_ sender:Any){
        runAsyncFuncs(previewMode: true, forceLinearSampler: false) {
            
        }
    }
    
    func runAsyncFuncs(previewMode: Bool, forceLinearSampler: Bool, saveDirUrl:URL! = nil, completion: @escaping () -> Void) {
        var index = 0
        var savedFileList:[URL] = []
        
        print("*** Movie Creation ***")
        print(" Total motion counts: \(movSeq.animateController.motionArray.count)")
        
        func runNext() {
            guard index < movSeq.animateController.motionArray.count else {
                print("*** All image are created ***")
                print(savedFileList)
                
                if(previewMode == false){
                    print("*** Convert to MP4 ***")
                    let movC = MovieCreator(withFps: 30, size: NSSize(width: UInt16(animate_movSize.selectedItem!.title)!.toCGFloat(),
                                                                   height: UInt16(animate_movSize.selectedItem!.title)!.toCGFloat()))
                    //                    movC.create(imagePATH: saveDirUrl.path)
                    movC.createMovie(from: savedFileList, exportFileUrl: saveDirUrl.appendingPathComponent("result.mp4"))
                }
                
                completion()
                return
            }
            
            print(" Current No: \(index)")
            let motion = movSeq.animateController.motionArray[index]
            createMotionImage(motion: motion, previewMode: previewMode,
                              forceLinearSampler: forceLinearSampler,
                              arrayIndex: index, saveDirUrl: saveDirUrl) {savedImageUrls in
                if let savedImageUrls = savedImageUrls{
                    savedFileList += savedImageUrls
                }
                runNext()
            }
            index += 1
        }
        runNext()
    }
    
    //MARK: - motion rendering
    // create or preview motion
    func createMotionImage(motion: AnimateController.Motion, previewMode: Bool, forceLinearSampler: Bool, arrayIndex:Int = 0, saveDirUrl:URL! = nil, completion: @escaping ([URL]?) -> Void){
        guard var startParams = getStoredParams(from: motion.startParamFileName) else {return}
        
        var endParams:StoredParameters?
        
        if(motion.type == .fileToFile || motion.type == .fileToFile_rotate_B || motion.type == .fileToFile_rotate_L ||
           motion.type == .fileToFile_rotate_R || motion.type == .fileToFile_rotate_T){
            guard var p = getStoredParams(from: motion.endParamFileName) else {return}
            
            toneCh1.setControlPoint(array: p.controlPoints[0])
            toneCh2.setControlPoint(array: p.controlPoints[1])
            toneCh3.setControlPoint(array: p.controlPoints[2])
            toneCh4.setControlPoint(array: p.controlPoints[3])
            
            p.alphaValues = [toneCh1.getInterpolatedValues(scale: 10)!,
                             toneCh2.getInterpolatedValues(scale: 10)!,
                             toneCh3.getInterpolatedValues(scale: 10)!,
                             toneCh4.getInterpolatedValues(scale: 10)!]
            
            endParams = p
        }
        
        // apply params as init state
        toneCh1.setControlPoint(array: startParams.controlPoints[0])
        toneCh2.setControlPoint(array: startParams.controlPoints[1])
        toneCh3.setControlPoint(array: startParams.controlPoints[2])
        toneCh4.setControlPoint(array: startParams.controlPoints[3])
        
        startParams.alphaValues = [toneCh1.getInterpolatedValues(scale: 10)!,
                                   toneCh2.getInterpolatedValues(scale: 10)!,
                                   toneCh3.getInterpolatedValues(scale: 10)!,
                                   toneCh4.getInterpolatedValues(scale: 10)!]
        
        transferTone(sender: toneCh1, targetGPUbuffer: &renderer.toneBuffer_ch1, index: 0)
        transferTone(sender: toneCh2, targetGPUbuffer: &renderer.toneBuffer_ch2, index: 1)
        transferTone(sender: toneCh3, targetGPUbuffer: &renderer.toneBuffer_ch3, index: 2)
        transferTone(sender: toneCh4, targetGPUbuffer: &renderer.toneBuffer_ch4, index: 3)
        
        var needTransferTone = false
        if let p1alpha = startParams.alphaValues, let p2alpha = endParams?.alphaValues {
            if(p1alpha != p2alpha){
                needTransferTone = true
            }
        }
        
        // apply params
        renderer.renderParams = startParams.renderParams
        renderer.resetRotation()
        renderer.rotateModelTo(quaternion: startParams.quaternion)
        renderer.renderOption = RenderOption(rawValue: startParams.renderOption)
        renderer.pointClouds = startParams.pointClouds
        
        
        
        movSeq.animateController.isCancelled = false
        
        
        guard let contentView = NSApplication.shared.keyWindow?.contentView else {return}
        
        let button = NSButton(title: "Cancel", target: nil, action: nil)
        button.bezelStyle = .rounded
        button.wantsLayer = true
        button.sizeToFit()
        button.action = #selector(cancelButtonPressed)
        
        let overlayView = NonClickableNSView(frame: NSApplication.shared.keyWindow?.contentView?.frame ?? NSRect.zero)
        overlayView.wantsLayer = true
        overlayView.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.25).cgColor
        //        overlayView.layer?.backgroundColor = CGColor.clear
        
        
        let progressIndicator = NSProgressIndicator(frame: NSRect(x: 0, y: 0, width: 60, height: 60))
        progressIndicator.style = .spinning
        progressIndicator.startAnimation(nil)
        overlayView.addSubview(progressIndicator)
        progressIndicator.frame.origin.x = (contentView.frame.width - progressIndicator.frame.width) / 2
        progressIndicator.frame.origin.y = (contentView.frame.height - progressIndicator.frame.height) / 2
        
        
        contentView.addSubview(overlayView, positioned: .above, relativeTo: nil)
        overlayView.addSubview(button)
        
        button.frame.origin.x = (contentView.frame.width - button.frame.width) / 2
        button.frame.origin.y = (contentView.frame.height - button.frame.height) / 2 - progressIndicator.bounds.height - 10
        
        
        button.layer?.backgroundColor = CGColor.clear
        

        
        var imgSeqNo = 0
        
        let duration = motion.duration
        let range = round(duration * motion.FPS / 1000) - 1  //30fps
        if (range <= 0){
            Dialog.showDialog(message: "too short duration time")
            return
        }
        
        var drawingSize:UInt16 = previewMode == true ? AppConfig.PREVIEW_SIZE : UInt16(animate_movSize.selectedItem!.title)!
        
        print("DrawindSize:", drawingSize)
        
        DispatchQueue.global(qos: .default).async{ [self] in
            
            var savedFileUrls:[URL] = []
            
            for i in 0...range.toInt(){
                if(movSeq.animateController.isCancelled == true){
                    
                    DispatchQueue.main.sync {
                        Logger.log(message: "Animation was canceled")
                        
                        outputView.image = renderer.rendering()
                        
                        overlayView.removeFromSuperview()
                        
                    }
                    
                    return
                }
                
                // Record the start time of this process.
                // Later, adjust the difference from the time required to 30 fps by stopping the thread
                let startTime = CACurrentMediaTime()
                
                if(motion.type == .rotate_L){
                    renderer.resetRotation()
                    renderer.rotateModelTo(quaternion: startParams.quaternion)
                    renderer.rotateModel(deltaX: 0, deltaY: -360.0 / range * i.toFloat(), deltaZ: 0)
                    
                }else if(motion.type == .rotate_R){
                    renderer.resetRotation()
                    renderer.rotateModelTo(quaternion: startParams.quaternion)
                    renderer.rotateModel(deltaX: 0, deltaY: 360.0 / range * i.toFloat(), deltaZ: 0)
                    
                }else if(motion.type == .rotate_T){
                    renderer.resetRotation()
                    renderer.rotateModelTo(quaternion: startParams.quaternion)
                    renderer.rotateModel(deltaX: 360.0 / range * i.toFloat(), deltaY: 0, deltaZ: 0)
                    
                }else if(motion.type == .rotate_B){
                    renderer.resetRotation()
                    renderer.rotateModelTo(quaternion: startParams.quaternion)
                    renderer.rotateModel(deltaX: -360.0 / range * i.toFloat(), deltaY: 0, deltaZ: 0)
                    
                }else if(motion.type == .fileToFile || motion.type == .fileToFile_rotate_B || motion.type == .fileToFile_rotate_L ||
                         motion.type == .fileToFile_rotate_R || motion.type == .fileToFile_rotate_T){
                    let params = generateInterpolatedParameters(p1: startParams, p2: endParams!, ratio: i.toFloat() / range)
                    
                    renderer.renderParams = params.renderParams
                    renderer.resetRotation()
                    renderer.rotateModelTo(quaternion: params.quaternion)
                    renderer.renderOption = RenderOption(rawValue: params.renderOption)
                    renderer.pointClouds = params.pointClouds
                    
                    if(needTransferTone == true){
                        renderer.transferToneArrayToBuffer(toneArray: params.alphaValues![0], targetGpuBuffer: &renderer.toneBuffer_ch1, index: 0)
                        renderer.transferToneArrayToBuffer(toneArray: params.alphaValues![1], targetGpuBuffer: &renderer.toneBuffer_ch2, index: 1)
                        renderer.transferToneArrayToBuffer(toneArray: params.alphaValues![2], targetGpuBuffer: &renderer.toneBuffer_ch3, index: 2)
                        renderer.transferToneArrayToBuffer(toneArray: params.alphaValues![3], targetGpuBuffer: &renderer.toneBuffer_ch4, index: 3)
                    }
                    
                    // Set additional rotation if needed
                    switch motion.type {
                    case .fileToFile_rotate_L:
                        renderer.rotateModel(deltaX: 0, deltaY: -360.0 / range * i.toFloat(), deltaZ: 0)
                        
                    case .fileToFile_rotate_R:
                        renderer.rotateModel(deltaX: 0, deltaY: 360.0 / range * i.toFloat(), deltaZ: 0)
                        
                    case .fileToFile_rotate_T:
                        renderer.rotateModel(deltaX: 360.0 / range * i.toFloat(), deltaY: 0, deltaZ: 0)
                        
                    case .fileToFile_rotate_B:
                        renderer.rotateModel(deltaX: -360.0 / range * i.toFloat(), deltaY: 0, deltaZ: 0)
                        
                    default:
                        break
                    }
                }
                
                DispatchQueue.main.sync {
                    
                    
                    if (forceLinearSampler == true){
                        renderer.renderOption.changeValue(option: .SAMPLER_LINEAR, value: 1)
                    }
                    
                    let outputImage = renderer.rendering(targetViewSize: drawingSize)
                    outputView.image = outputImage
                    
                    
                    if(previewMode == true){
                        // low quality image and draw in real time as possible
                        
                        // Calculate the time required for the process and wait if it is faster than 30 fps.
                        // If it is slower, reduce the image quality.
                        let endTime = CACurrentMediaTime()
                        let processTime = endTime - startTime
                        let waitTime = (1.0 / 30.0) - processTime
                        if waitTime > 0 {
                            Thread.sleep(forTimeInterval: waitTime)
                        }else{
                            if(drawingSize > 64){
                                drawingSize /= 2
                            }
                        }
                    }else{
                        // save images
                        let saveFileName = String(format: "%03d", arrayIndex) + "-" + String(format: "%06d", imgSeqNo) + ".tif"
                        let saveFileUrl = saveDirUrl!.appendingPathComponent(saveFileName)
                        savedFileUrls.append(saveFileUrl)
                        
                        guard let tiff =  outputImage?.tiffRepresentation,
                              let imgRep = NSBitmapImageRep(data: tiff)
                        else {
                            return
                        }
                        
                        guard let data = imgRep.representation(using: .tiff, properties: [:]) else {
                            return
                        }
                        
                        try! data.write(to: saveFileUrl)
                        
                        
                    }
                    
                }
                
                imgSeqNo += 1
            }
            
            
            DispatchQueue.main.sync {
                Logger.log(message: "Animation finished")
                outputView.image = renderer.rendering()
                overlayView.removeFromSuperview()
                completion(savedFileUrls)
            }
        }
        
    }
    
    @IBAction func startCreateSequenceFile(_ sender:Any){
        guard let filePackage = filePackage,
              let movDir = filePackage.movieDir else {return}
        
        // create save dir
        
        let timeStamp = NSDate().timeStampYYYYMMDDHHMMSS()
        let saveDir = movDir.appendingPathComponent(timeStamp)
        
        let fileManager = FileManager.default
        do {
            try fileManager.createDirectory(at: saveDir, withIntermediateDirectories: true, attributes: nil)
        } catch {
            Dialog.showDialog(message: "failed to create directory: \(saveDir.path)")
            return
        }
        
        runAsyncFuncs(previewMode: false, forceLinearSampler: true, saveDirUrl: saveDir) {
            
            var isDir:ObjCBool  = false
            if FileManager.default.fileExists(atPath: filePackage.fileDir.path, isDirectory: &isDir) {
                if(isDir.boolValue == true){
                    NSWorkspace.shared.activateFileViewerSelecting([saveDir.appendingPathComponent("result.mp4")])
                }
                
            }
            
        }
        
        return
        
    }
    
}
class NonClickableNSView: NSView {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return false
    }
    
    override func mouseDown(with event: NSEvent) {}
    override func mouseUp(with event: NSEvent) {}
    override func mouseDragged(with event: NSEvent) {}
    override func scrollWheel(with event: NSEvent) {}
    override func rightMouseUp(with event: NSEvent) {}
    override func rightMouseDown(with event: NSEvent) {}
    override func rightMouseDragged(with event: NSEvent) {}
    override func otherMouseUp(with event: NSEvent) {}
    override func otherMouseDown(with event: NSEvent) {}
    override func otherMouseDragged(with event: NSEvent) {}
}


extension ViewController: SequenceCellProtocol, SequenceCellRotationProtocol{
    
    @objc func cancelButtonPressed( _ sender:Any) {
        movSeq.animateController.isCancelled = true
    }
    
    // Preview button in cell pushed
    func sequenceCellRotationPreview(control: AnimateController.Motion) {
        createMotionImage(motion: control, previewMode: true, forceLinearSampler: false){url in
            
        }
    }
    
    
    // Preview button in cell pushed
    func sequenceCellPreview(control: AnimateController.Motion) {
        createMotionImage(motion: control, previewMode: true, forceLinearSampler: false){url in
            
        }
    }
    
    
    
}

