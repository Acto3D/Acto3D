//
//  MovieCreator.swift
//  Acto3D
//
//  Created by Naoki Takeshita on 2022/03/07.
//
import Cocoa
import Foundation
import AVFoundation


typealias CXEMovieMakerCompletion = (URL) -> Void
typealias CXEMovieMakerUIImageExtractor = (AnyObject) -> NSImage?

class MovieCreator {
    
    var imgSize:Int = 0
    var fps:Int = 30
    
    var fileList:[URL]!
    var width = 0
    var height = 0
    
    init(withFps fps:Int, size:NSSize){
        self.fps = fps
        
        self.width = Int(size.width)
        self.height = Int(size.height)
    }
    
    func createMovie(from fileList:[URL], exportFileUrl:URL){
        let settings = CXEImagesToVideo.videoSettings(codec: AVVideoCodecType.h264.rawValue, width: width, height: height)
        
        let movieMaker = CXEImagesToVideo(videoSettings: settings, exportUrl: exportFileUrl, fps: fps)

        let images = fileList.map{
            NSImage(contentsOf: $0)!
        }
        
        movieMaker.createMovieFrom(images: images) { i in
            print(i)
        }
    }
    
}


public class CXEImagesToVideo: NSObject{
    var assetWriter:AVAssetWriter!
    var writeInput:AVAssetWriterInput!
    var bufferAdapter:AVAssetWriterInputPixelBufferAdaptor!
    var videoSettings:[String : Any]!
    var frameTime:CMTime!
    var fileURL:URL!
    var path:String = ""
    
    var completionBlock: CXEMovieMakerCompletion?
    var movieMakerUIImageExtractor:CXEMovieMakerUIImageExtractor?
    
    
    public class func videoSettings(codec:String, width:Int, height:Int) -> [String: Any]{
        if(Int(width) % 16 != 0){
            print("warning: video settings width must be divisible by 16")
        }
        
        let videoCompressionProperties:[String: Any] = [
            AVVideoAverageBitRateKey: 82000000,
            AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel ,
        ]
        
        let videoSettings:[String: Any] = [AVVideoCodecKey: AVVideoCodecType.h264,
                                           AVVideoWidthKey: width,
                                          AVVideoHeightKey: height,
                           AVVideoCompressionPropertiesKey: videoCompressionProperties]
        
        return videoSettings
    }
    
    public init(videoSettings: [String: Any], exportUrl:URL, fps:Int) {
        super.init()
       
        self.fileURL = exportUrl
        self.assetWriter = try! AVAssetWriter(url: exportUrl, fileType: AVFileType.mov)
        
        self.videoSettings = videoSettings
        self.writeInput = AVAssetWriterInput(mediaType: AVMediaType.video, outputSettings: videoSettings)
        assert(self.assetWriter.canAdd(self.writeInput), "add failed")
        
        self.assetWriter.add(self.writeInput)
        let bufferAttributes:[String: Any] = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32ARGB)]
        self.bufferAdapter = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: self.writeInput, sourcePixelBufferAttributes: bufferAttributes)
        self.frameTime = CMTimeMake(value: 1, timescale: Int32(fps))
    }
    
    func setPath(url:URL, fps:Int){
        let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
        self.assetWriter = try! AVAssetWriter(url: url, fileType: AVFileType.mov)
        
//        self.videoSettings = videoSettings
        self.writeInput = AVAssetWriterInput(mediaType: AVMediaType.video, outputSettings: videoSettings)
        assert(self.assetWriter.canAdd(self.writeInput), "add failed")
        
        self.assetWriter.add(self.writeInput)
        let bufferAttributes:[String: Any] = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32ARGB)]
        self.bufferAdapter = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: self.writeInput, sourcePixelBufferAttributes: bufferAttributes)
        self.frameTime = CMTimeMake(value: 1, timescale: Int32(fps))
        print("file EXP")
        
    }
    
    func setPath(path:String, fps:Int){
        let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
        let tempPath = path + "/exprotvideo.mp4"
        print(tempPath)
        if(FileManager.default.fileExists(atPath: tempPath)){
            guard (try? FileManager.default.removeItem(atPath: tempPath)) != nil else {
                print("remove path failed")
                return
            }
        }
        
        self.fileURL = URL(fileURLWithPath: tempPath)
        self.assetWriter = try! AVAssetWriter(url: self.fileURL, fileType: AVFileType.mov)
        
//        self.videoSettings = videoSettings
        self.writeInput = AVAssetWriterInput(mediaType: AVMediaType.video, outputSettings: videoSettings)
        assert(self.assetWriter.canAdd(self.writeInput), "add failed")
        
        self.assetWriter.add(self.writeInput)
        let bufferAttributes:[String: Any] = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32ARGB)]
        self.bufferAdapter = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: self.writeInput, sourcePixelBufferAttributes: bufferAttributes)
        self.frameTime = CMTimeMake(value: 1, timescale: Int32(fps))
        print("file EXP")
        
    }
    
    func createMovieFrom(urls: [URL], withCompletion: @escaping CXEMovieMakerCompletion){
        self.createMovieFromSource(images: urls as [AnyObject], extractor:{(inputObject:AnyObject) ->NSImage? in
            return NSImage(data: try! Data(contentsOf: inputObject as! URL))}, withCompletion: withCompletion)
    }
    
    func createMovieFrom(images: [NSImage], withCompletion: @escaping CXEMovieMakerCompletion){
        self.createMovieFromSource(images: images, extractor: {(inputObject:AnyObject) -> NSImage? in
            return inputObject as? NSImage}, withCompletion: withCompletion)
    }
    
    func createMovieFromSource(images: [AnyObject], extractor: @escaping CXEMovieMakerUIImageExtractor, withCompletion: @escaping CXEMovieMakerCompletion){
        self.completionBlock = withCompletion
        
        self.assetWriter.startWriting()
        self.assetWriter.startSession(atSourceTime: CMTime.zero)
        
        let mediaInputQueue = DispatchQueue(label: "mediaInputQueue")
        var i = 0
        let frameNumber = images.count
        
        self.writeInput.requestMediaDataWhenReady(on: mediaInputQueue){
            while(true){
                if(i >= frameNumber){
                    break
                }
                
                if (self.writeInput.isReadyForMoreMediaData){
                    var sampleBuffer:CVPixelBuffer?
                    autoreleasepool{
                        let img = extractor(images[i])
                        if img == nil{
                            i += 1
                            print("Warning: counld not extract one of the frames")
                            //continue
                        }
                        sampleBuffer = self.newPixelBufferFrom(cgImage: img!.cgImage)
                    }
                    if (sampleBuffer != nil){
                        if(i == 0){
                            self.bufferAdapter.append(sampleBuffer!, withPresentationTime: CMTime.zero)
                        }else{
                            let value = i - 1
                            let lastTime = CMTimeMake(value: Int64(value), timescale: self.frameTime.timescale)
                            let presentTime = CMTimeAdd(lastTime, self.frameTime)
                            self.bufferAdapter.append(sampleBuffer!, withPresentationTime: presentTime)
                        }
                        i = i + 1
                    }
                }
            }
            self.writeInput.markAsFinished()
            self.assetWriter.finishWriting {
                DispatchQueue.main.sync {
                    self.completionBlock!(self.fileURL)
                }
            }
        }
    }
    
    func newPixelBufferFrom(cgImage:CGImage) -> CVPixelBuffer?{
        let options:[String: Any] = [kCVPixelBufferCGImageCompatibilityKey as String: true, kCVPixelBufferCGBitmapContextCompatibilityKey as String: true]
        var pxbuffer:CVPixelBuffer?
        let frameWidth = self.videoSettings[AVVideoWidthKey] as! Int
        let frameHeight = self.videoSettings[AVVideoHeightKey] as! Int
        
        let status = CVPixelBufferCreate(kCFAllocatorDefault, frameWidth, frameHeight, kCVPixelFormatType_32ARGB, options as CFDictionary?, &pxbuffer)
        assert(status == kCVReturnSuccess && pxbuffer != nil, "newPixelBuffer failed")
        
        CVPixelBufferLockBaseAddress(pxbuffer!, CVPixelBufferLockFlags(rawValue: 0))
        let pxdata = CVPixelBufferGetBaseAddress(pxbuffer!)
        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(data: pxdata, width: frameWidth, height: frameHeight, bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(pxbuffer!), space: rgbColorSpace, bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)
        assert(context != nil, "context is nil")
        
        context!.concatenate(CGAffineTransform.identity)
        context!.draw(cgImage, in: CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height))
        CVPixelBufferUnlockBaseAddress(pxbuffer!, CVPixelBufferLockFlags(rawValue: 0))
        return pxbuffer
    }
}


private extension NSImage {
    var cgImage: CGImage {
        var imageRect = NSRect(x: 0, y: 0, width: size.width, height: size.height)
#if swift(>=3.0)
        guard let image =  cgImage(forProposedRect: &imageRect, context: nil, hints: nil) else {
            abort()
        }
#else
        guard let image = CGImageForProposedRect(&imageRect, context: nil, hints: nil) else {
            abort()
        }
#endif
        return image
    }
}

