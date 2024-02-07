//
//  ImageExt.swift
//  Acto3D
//
//  Created by Naoki TAKESHITA on 2021/12/18.
//

import Foundation
import Cocoa
import Metal

extension NSImage {
    var toCGImage: CGImage {
        var imageRect = NSRect(x: 0, y: 0, width: size.width, height: size.height)
#if swift(>=3.0)
        guard let image = cgImage(forProposedRect: &imageRect, context: nil, hints: nil) else {
            abort()
        }
#else
        guard let image = CGImageForProposedRect(&imageRect, context: nil, hints: nil) else {
            abort()
        }
#endif
        return image
    }
    
    /// Only grayscale image
    func resize(to size: NSSize) -> NSImage? {
        let cgImage = self.toCGImage
        
        let newRep = NSBitmapImageRep(bitmapDataPlanes: nil,
                                      pixelsWide: Int(size.width),
                                      pixelsHigh: Int(size.height),
                                      bitsPerSample: cgImage.bitsPerComponent,
                                      samplesPerPixel: cgImage.bitsPerComponent / cgImage.bitsPerPixel,
                                      hasAlpha: false,
                                      isPlanar: false,
                                      colorSpaceName: NSColorSpaceName.deviceWhite, bytesPerRow: Int(size.width) * cgImage.bitsPerComponent / 8, bitsPerPixel: cgImage.bitsPerComponent)
        
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: newRep!)
        
        let nsContext = NSGraphicsContext.current!.cgContext
        nsContext.draw(cgImage, in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
        
        NSGraphicsContext.restoreGraphicsState()
        
        let newImage = NSImage(size: size)
        newImage.addRepresentation(newRep!)
        return newImage
    }
}

extension CGImage {
    var size: CGSize {
#if swift(>=3.0)
#else
        let inputImageWidth = CGImageGetWidth(self)
        let inputImageHeight = CGImageGetHeight(self)
#endif
        return CGSize(width: width, height: height)
    }
    
    var toNSImage: NSImage {
#if swift(>=3.0)
        return NSImage(cgImage: self, size: size)
#else
        return NSImage(CGImage: self, size: size)
#endif
    }
    
    
    /// Obtein pixel data array of `[UInt8]` for grayscaled image
    func getPixelData() -> [UInt8]{
        let _w = Int(self.size.width.rounded())
        let _h = Int(self.size.height.rounded())
        
        if(_w != self.width || _h != self.height){
            Dialog.showDialogWithDebug(message: "Invalid image size, \(_w), \(_h), \(self.width), \(self.height)")
        }
        if(self.bitsPerPixel != 8 || self.bitsPerComponent != 8){
            Dialog.showDialogWithDebug(message: "Input image must be 8 bits gray scale image.")
        }
        
        
        // The following approach was adopted because on some machines,
        // pixel values weren't being fetched accurately, thus necessitating
        // the use of a data provider.
        //
        // However, similar to images loaded from a file, the data provider
        // often isn't aligned, resulting in row bytes often being greater
        // than width * 8.
        //
        // While it might be inefficient, values are fetched using a for loop
        // due to this alignment issue.

//        let totalBytes = _w * _h
//
//        let colorSpace = CGColorSpaceCreateDeviceGray()
//        var intensities = [UInt8](repeating: 0, count: totalBytes)
//
//        let contextRef = CGContext(data: &intensities, width: _w, height: _h, bitsPerComponent: 8, bytesPerRow: _w * 1, space: colorSpace, bitmapInfo: 0)
//
//        contextRef?.draw(self, in: CGRect(x: 0.0, y: 0.0, width: CGFloat(_w), height: CGFloat(_h)))
//
//        return intensities
        
        
        guard let pixelData = self.dataProvider?.data,
              let data = CFDataGetBytePtr(pixelData)
        else {
            return []
        }
        
        let width = self.width
        let height = self.height
        let rowBytes = self.bytesPerRow
        let bytesPerPixel = self.bitsPerPixel / 8 // this should be 1
        
        var pixelValues: [UInt8] = []
        
        for y in 0..<height {
            for x in 0..<width {
                let pixelIndex = y * rowBytes + x * bytesPerPixel
                pixelValues.append(data[pixelIndex])
            }
        }
        
        return pixelValues
    }
    
    func convertToLinearLoc(_x:Int, _y:Int, _w:Int, _h:Int){
        
    }
    
    struct FillParam {
        
        var XL = 0
        var XR = 0
        var YL = 0
        var YO = 0
    }
    
    func scanLine(lx: Int, rx: Int, y:Int,  oy:Int, th:uint8, px:[UInt8], buffer:inout [FillParam], _w:Int, _h:Int){
        var lx = lx
        
        while (lx <= rx){
            
            while (lx < rx){
                if(px[y * _w + lx] == th){
                    break
                }
                lx += 1
            }
            
            
            if(px[y * _w + lx] != th){
                break
            }
            
            let tlx = lx
            
            while (lx <= rx){
                if(px[y * _w + lx] != th){
                    break
                }
                lx += 1
            }
            
            buffer.append(FillParam(XL: tlx, XR: lx - 1, YL: y, YO: oy))
            
        }
        
    }
    
    
    func fill(in point:CGPoint) -> (image:CGImage?, value:UInt8, fillCount:Int){
        
        let px = self.getPixelData()
        var fillImg = [UInt8](repeating: 0, count: px.count)
        let _w = Int(self.size.width.rounded())
        let _h = Int(self.size.height.rounded())
        
        var fillCount = 0
        
        let totalBytes = _w * _h
        
        var buffer:[FillParam] = [FillParam(XL: Int(point.x), XR: Int(point.x), YL: Int(point.y), YO: Int(point.y))]
        
        
        
        let th = px[self.width * Int(point.y) + Int(point.x)]
        
        var trial = 0
        
        while(buffer.count > 0){
            trial += 1
            
            var XL = buffer[0].XL
            var XR = buffer[0].XR
            let YL = buffer[0].YL
            let YO = buffer[0].YO
            
            
            let lxsav = XL - 1
            let rxsav = XR + 1
            
            buffer.removeFirst()
            
            
            if(fillImg[YL * _w + XL] == 255){
                continue
            }
            
            while (XL > 0){
                if(px[YL * _w + XL] != th){
                    break
                }
                
                XL -= 1
            }
            
            while (XR < _w - 1){
                if(px[YL * _w + (XR + 1)] != th){
                    break
                }
                
                XR += 1
            }
            
            fillImg.replaceSubrange((YL * _w + XL )...(YL * _w + XR ), with: repeatElement(255, count: XR-XL+1))
            
            fillCount += XR-XL+1
            
            
            if (YL - 1 >= 0){
                if (YL - 1 == YO){
                    scanLine(lx: XL, rx: lxsav, y: YL-1, oy: YL, th: th, px: px, buffer: &buffer, _w: _w, _h: _h)
                    scanLine(lx: rxsav, rx: XR, y: YL-1, oy: YL, th: th, px: px, buffer: &buffer, _w: _w, _h: _h)
                }else{
                    scanLine(lx: XL, rx: XR, y: YL-1, oy: YL, th: th, px: px, buffer: &buffer, _w: _w, _h: _h)
                    
                }
            }
            
            if (YL + 1 <= height - 1){
                if (YL + 1 == YO){
                    scanLine(lx: XL, rx: lxsav, y: YL+1, oy: YL, th: th, px: px, buffer: &buffer, _w: _w, _h: _h)
                    scanLine(lx: rxsav, rx: XR, y: YL+1, oy: YL, th: th, px: px, buffer: &buffer, _w: _w, _h: _h)
                }
                else{
                    scanLine(lx: XL, rx: XR, y: YL+1, oy: YL, th: th, px: px, buffer: &buffer, _w: _w, _h: _h)
                }
                
            }
        }
        
        
        guard let providerRef = CGDataProvider(data: Data(bytes: &fillImg, count: totalBytes) as CFData) else{return (nil, 0, 0)}
        
        
        guard let fillImage = CGImage(
            width: _w,
            height: _h,
            bitsPerComponent: 8, // 8
            bitsPerPixel: 8 * 1, // 24 or 32
            bytesPerRow: MemoryLayout<UInt8>.stride * _w * 1,  // * 4 for 32bit
            space:  CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),  //CGImageAlphaInfo.noneSkipLast.rawValue
            provider: providerRef,
            decode: nil,
            shouldInterpolate: true,
            intent: .defaultIntent)
        else { return (nil, 0, 0)}
        
        // Get filled area
        // let pixel255count = fillImg.filter{$0 == 255}.count
        
        return (fillImage, th, fillCount)
    }
    
    
    func grayScaleImage() -> CGImage? {
        let rect = CGRect(x: 0, y: 0, width: size.width, height: size.height)
        guard let context = CGContext(data: nil,
                                      width: Int(size.width),
                                      height: Int(size.height),
                                      bitsPerComponent: 8,
                                      bytesPerRow: 0,
                                      space: CGColorSpaceCreateDeviceGray(),
                                      bitmapInfo: CGImageAlphaInfo.none.rawValue)
                
        else {
            return nil
        }
        
        context.draw(self, in: rect)
        
        guard let image = context.makeImage() else {
            return nil
        }
        
        return image
    }
    
    
    /// Calculates moment from binary image
    func calcMoment(device:MTLDevice, cmdQueue:MTLCommandQueue, lib:MTLLibrary) -> (moment:CGPoint, m00:UInt, m01:UInt, m10:UInt)?{
        guard let computeFunction = lib.makeFunction(name: "moment") else {
            return nil
        }
        let renderPipeline = try? device.makeComputePipelineState(function: computeFunction)
        
        let cmdBuf = cmdQueue.makeCommandBuffer()!
        let computeSliceEncoder = cmdBuf.makeComputeCommandEncoder()!
        computeSliceEncoder.setComputePipelineState(renderPipeline!)
        
        let inputArray = self.getPixelData()
        
        
        let options: MTLResourceOptions = [.storageModeShared, .cpuCacheModeWriteCombined ]
        let inputBuffer = device.makeBuffer(bytes: inputArray, length: MemoryLayout<UInt8>.stride * inputArray.count, options: options)
        computeSliceEncoder.setBuffer(inputBuffer, offset: 0, index: 0)
        
        let m00_buffer = device.makeBuffer(length: MemoryLayout<UInt>.stride)!
        let m01_buffer = device.makeBuffer(length: MemoryLayout<UInt>.stride)!
        let m10_buffer = device.makeBuffer(length: MemoryLayout<UInt>.stride)!
        
        computeSliceEncoder.setBuffer(m00_buffer, offset: 0, index: 1)
        computeSliceEncoder.setBuffer(m10_buffer, offset: 0, index: 2)
        computeSliceEncoder.setBuffer(m01_buffer, offset: 0, index: 3)
        
        var _h:UInt16 = self.height.toUInt16()
        var _w:UInt16 = self.width.toUInt16()
        computeSliceEncoder.setBytes(&_w, length: MemoryLayout<UInt16>.stride, index: 4)
        computeSliceEncoder.setBytes(&_h, length: MemoryLayout<UInt16>.stride, index: 5)
        
        // Compute optimization
        let xCount = _w.toInt()
        let yCount = _h.toInt()
        
        
        let maxTotalThreadsPerThreadgroup = renderPipeline!.maxTotalThreadsPerThreadgroup // 1024
        let threadExecutionWidth          = renderPipeline!.threadExecutionWidth // 32
        let width  = threadExecutionWidth // 32
        let height = maxTotalThreadsPerThreadgroup / width // 1024 / 32 = 32
        let depth  = 1
        let threadsPerThreadgroup = MTLSize(width: width, height: height, depth: depth) // MTLSize(width: 32, height: 32, depth: 1)
        let threadgroupsPerGrid = MTLSize(width: (xCount + width - 1) / width,
                                          height: (yCount + height - 1) / height,
                                          depth: 1)
        
        
        // Metal Dispatch
        computeSliceEncoder.dispatchThreadgroups(threadgroupsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
        computeSliceEncoder.endEncoding()
        
        cmdBuf.commit()
        cmdBuf.waitUntilCompleted()
        
        let m00p = m00_buffer.contents().bindMemory(to: UInt.self, capacity: MemoryLayout<UInt>.stride)
        let aa = UnsafeBufferPointer(start: m00p, count: 1)
        let m00A = Array(aa)
        
        let m01p = m01_buffer.contents().bindMemory(to: UInt.self, capacity: MemoryLayout<UInt>.stride)
        let bb = UnsafeBufferPointer(start: m01p, count: 1)
        let m01A = Array(bb)
        
        let m10p = m10_buffer.contents().bindMemory(to: UInt.self, capacity: MemoryLayout<UInt>.stride)
        let cc = UnsafeBufferPointer(start: m10p, count: 1)
        let m10A = Array(cc)
        
        let momX = CGFloat(m10A[0]) / CGFloat(m00A[0])
        let momY = CGFloat(m01A[0]) / CGFloat(m00A[0])
//        print(momX, momY)
        
        return (NSMakePoint(momX, momY), m00A[0], m01A[0], m10A[0])
    }
    
    
}

