//
//  KeyEvent.swift
//  Acto3D
//
//  Created by Naoki Takeshita on 2022/03/04.
//

import Foundation
import Cocoa
import simd

// keyboard management in the main view

extension ViewController{
    
    private struct keyCodeDic {
        static var keyboard = ["":false]
    }
    
    /// A dictionary for key hold / release detection
    var keyboard: [String : Bool] {
        get {
            guard let key = objc_getAssociatedObject(self, &keyCodeDic.keyboard) as? [String : Bool] else {
                return ["Z": false,
                        "A": false,
                        "S": false,
                        "C": false,
                        "49": false,]
            }
            return key
        }
        set {
            objc_setAssociatedObject(self, &keyCodeDic.keyboard, newValue, .OBJC_ASSOCIATION_RETAIN)
        }
    }
    
    
    override func keyDown(with event: NSEvent) {
        // z 6, x 7, c 8, v 9
        // down 125, up 126
        
        switch event.keyCode {
        case 6: // z
            if(keyboard["Z"] == false){
                keyboard["Z"] =  true
                renderer.renderOption.changeValue(option: .MPR, value: 1)
                mprmodeIndicator.isHidden = false
                outputView.image = renderer.rendering()
            }
            
        case 0: // a
            if(keyboard["A"] == false){
                keyboard["A"] =  true
                renderer.renderOption.changeValue(option: .POINT, value: 1)
                outputView.image = renderer.rendering()
            }
            
        case 1: // s
            //MARK: Snapshot
            if(keyboard["S"] == false){
                keyboard["S"] =  true
                
                guard let filePackage = filePackage else {return}
                
                let currentScale = renderer.renderParams.scale
                let currentViewSize = renderer.renderParams.viewSize
                
                let currentOption = renderer.renderOption.rawValue
                renderer.renderOption.changeValue(option: .SAMPLER_LINEAR, value: 1)
                
                // set temporaly view size
                let viewSizeHQ:UInt16 = AppConfig.HQ_SIZE
                
                var tmpImg_wo_scalebar:NSImage?
                var tmpImg_only_scalebar:NSImage?
                var tmpImg_w_scalebar:NSImage?
                
                if(renderer.imageParams.scalebarLength != 0){
                    tmpImg_wo_scalebar = renderer.rendering(targetViewSize: viewSizeHQ, scalebar: false)
                    guard let tmpImg_wo_scalebar = tmpImg_wo_scalebar else {return}
                    
                    let width = viewSizeHQ.toInt()
                    let height = viewSizeHQ.toInt()
                    let bytesPerRow = MemoryLayout<UInt8>.stride * width * 3
                    let totalBytes = bytesPerRow * height

                    let data = Data(count: totalBytes)
                    
                    guard let providerRef = CGDataProvider(data: data as CFData) else {return}
                    guard let blankImage = CGImage(
                        width: width,
                        height: height,
                        bitsPerComponent: 8,
                        bitsPerPixel: 8 * 3,
                        bytesPerRow: bytesPerRow,
                        space:  CGColorSpaceCreateDeviceRGB(),
                        bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
                        provider: providerRef,
                        decode: nil,
                        shouldInterpolate: true,
                        intent: .defaultIntent)
                    else { return }
                    
                    tmpImg_only_scalebar = renderer.drawScale(image: blankImage, drawingViewSize: viewSizeHQ.toInt())?.toNSImage
                    tmpImg_w_scalebar = renderer.drawScale(image: tmpImg_wo_scalebar.toCGImage, drawingViewSize: viewSizeHQ.toInt())?.toNSImage
                    
                }else{
                    tmpImg_wo_scalebar = renderer.rendering(targetViewSize: viewSizeHQ)
                }
                
                // save
                guard let filePath = filePackage.snapshotDir else{
                    Dialog.showDialog(message: "directory error for snapshot")
                    Logger.logPrintAndWrite(message: "directory error for snapshot", level: .error)
                    return
                }
                
                let baseFileName_wo_ext = "snap_" + NSDate().timeStampYYYYMMDDHHMMSS()
                
                var fileURLs:[URL] = []
                
                if let tiff = tmpImg_wo_scalebar?.tiffRepresentation,
                   let imgRep = NSBitmapImageRep(data: tiff),
                   let data = imgRep.representation(using: .tiff, properties: [:]) {
                    let saveUrl = filePath.appendingPathComponent(baseFileName_wo_ext + "_wo_scale.tif")
                    
                    fileURLs.append(saveUrl)
                    
                    do {
                        try data.write(to: saveUrl)
                        Logger.logPrintAndWrite(message: "Saved a snapshot to \(saveUrl.path)")
                    } catch {
                        Logger.logPrintAndWrite(message: "Error in saving a snapshot to \(saveUrl.path)", level: .error)
                    }
                }
                
                if let tiff = tmpImg_only_scalebar?.tiffRepresentation,
                   let imgRep = NSBitmapImageRep(data: tiff),
                   let data = imgRep.representation(using: .tiff, properties: [:]) {
                    let saveUrl = filePath.appendingPathComponent(baseFileName_wo_ext + "_scalebar_\(renderer.imageParams.scalebarLength)\(renderer.imageParams.unit).tif")
                    
                    fileURLs.append(saveUrl)
                    
                    do {
                        try data.write(to: saveUrl)
                        Logger.logPrintAndWrite(message: "Saved a snapshot to \(saveUrl.path)")
                    } catch {
                        Logger.logPrintAndWrite(message: "Error in saving a snapshot to \(saveUrl.path)", level: .error)
                    }
                }
                
                if let tiff = tmpImg_w_scalebar?.tiffRepresentation,
                   let imgRep = NSBitmapImageRep(data: tiff),
                   let data = imgRep.representation(using: .tiff, properties: [:]) {
                    let saveUrl = filePath.appendingPathComponent(baseFileName_wo_ext + ".tif")
                    
                    do {
                        try data.write(to: saveUrl)
                        Logger.logPrintAndWrite(message: "Saved a snapshot to \(saveUrl.path)")
                    } catch {
                        Logger.logPrintAndWrite(message: "Error in saving a snapshot to \(saveUrl.path)", level: .error)
                    }
                }

                renderer.renderOption = RenderOption(rawValue: currentOption)
                
                if(AppConfig.CLIPBOARD_WHEN_SNAPSHOT){
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.writeObjects(fileURLs as [NSPasteboardWriting])
                    
                    Logger.logPrintAndWrite(message: "Copy files to clipboard")
                }
                
            }
            
            
        case 8: // c
            //MARK: Copy
            if(keyboard["C"] == false){
                keyboard["C"] =  true
                
                let currentOption = renderer.renderOption.rawValue
                
                renderer.renderOption.changeValue(option: .SAMPLER_LINEAR, value: 1)
                
                let tmpImg = renderer.rendering(targetViewSize: AppConfig.HQ_SIZE)

                
                let pasteboard = NSPasteboard.general
                pasteboard.declareTypes([.tiff], owner: nil)
                
                if let imageData = tmpImg?.tiffRepresentation{
                    pasteboard.clearContents()
                    pasteboard.setData(imageData, forType: NSPasteboard.PasteboardType(rawValue: "NSTIFFPboardType"))
                    Logger.log(message: "Copied to the clipboard", writeToLogfile: true)
                }
                
                renderer.renderOption = RenderOption(rawValue: currentOption)
            }
            
        case 123: // ←
            renderer.renderParams.translationX += 10
            outputView.image = renderer.rendering()
            break
            
        case 124: // →
            renderer.renderParams.translationX -= 10
            outputView.image = renderer.rendering()
            break
            
        case 125: // ↓
            renderer.renderParams.translationY -= 10
            outputView.image = renderer.rendering()
            break
            
        case 126: // ↑
            renderer.renderParams.translationY += 10
            outputView.image = renderer.rendering()
            break
            
        case 49: // Space
                keyboard["49"] =  true
            
        default:
            print("View Key Down :\(event.keyCode)")
            break
        }
    }
    override func keyUp(with event: NSEvent) {
        switch event.keyCode {
        case 6: // z
            if(keyboard["Z"] == true){
                keyboard["Z"] = false
                renderer.renderOption.changeValue(option: .MPR, value: 0)
                renderer.argumentManager?.markAsNeedsUpdate(argumentIndex: .optionValue)
                mprmodeIndicator.isHidden = true
                outputView.image = renderer.rendering()
            }
            
        case 0: // a
            if(keyboard["A"] == true){
                keyboard["A"] = false
                renderer.renderOption.changeValue(option: .POINT, value: 0)
                renderer.argumentManager?.markAsNeedsUpdate(argumentIndex: .optionValue)
                outputView.image = renderer.rendering()
            }
            
        case 1: // s
            if(keyboard["S"] == true){
                keyboard["S"] = false
            }
        case 8: // c
            if(keyboard["C"] == true){
                keyboard["C"] = false
            }
        case 49: // Space
            keyboard["49"] =  false
            
        case 53:  // ESC key
            self.view.window?.makeFirstResponder(self)
            
        default:
            print("View Key UP :\(event.keyCode)")
            break
        }
        
    }
}
