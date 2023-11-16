//
//  MTIFF.swift
//  Acto3D
//
//  Created by Naoki Takeshita
//


// The processing for loading ImageJ type TIFF files has been developed by referring to the ImageJ source code.
// Reference: https://github.com/imagej/ImageJ
// Rasband, W.S., ImageJ, U. S. National Institutes of Health, Bethesda, Maryland, USA, http://imagej.nih.gov/ij/, 1997-2012.
// Schneider, C.A., Rasband, W.S., Eliceiri, K.W. "NIH Image to ImageJ: 25 years of image analysis". Nature Methods 9, 671-675, 2012.[2]

import Foundation
import AppKit

public enum TiffType {
    case unknown
    case singlePageTiff
    case bigTiff
    case multipageTiff
    case ImageJ_TiffStack
    case ImageJ_LargetiffStack
}

// metadata types
let MAGIC_NUMBER = 0x494a494a;  // "IJIJ"
let INFO = 0x696e666f;          // "info" (Info image property)
let LABELS = 0x6c61626c;        // "labl" (slice labels)
let RANGES = 0x72616e67;        // "rang" (display ranges)
let LUTS = 0x6c757473;          // "luts" (channel LUTs)
let PLOT = 0x706c6f74;          // "plot" (serialized plot)
let ROI = 0x726f6920;           // "roi " (ROI)
let OVERLAY = 0x6f766572;       // "over" (overlay)
let PROPERTIES = 0x70726f70;    // "prop" (properties)


fileprivate func print(_ items: Any..., separator: String = " ", terminator: String = "\n"){
    Swift.print(items)
}


public class MTIFF {
    let stream:StreamData = StreamData()
    
    public var metaDataCounts:[Int]?
    private var metaDataPosition = 0
    public var displayRanges:[[Double]]?
    
    
    //    var data: Data?
    
    var isBigEndian = false
    public var ifdOffsets:[Int] = []
    
    public var width = 0
    public var height = 0
    public var channel = 0
    public var bitsPerSample = 0
    public var unitString:String?
    
    private var filePath:String?
    
    public var fileType:TiffType = .unknown
    
    public var fileDescription:[String : Any]?
//    public var acquisitionInfo:String?
    //    var imageJcompatibleLargeTiff = true
    
    public var resolutionX:Float = 1.0
    public var resolutionY:Float = 1.0
    
//    public var metaDataCounts:[Int] = []
    
    public var scaleX:Float {
        get{
            return 1.0 / self.resolutionX
        }
    }
    public var scaleY:Float{
        get{
            return 1.0 / self.resolutionY
        }
    }
    
    public var scaleZ:Float = 1.0
    
    var imgBytes:[Int] = []
    
    var imageJtype = false
    
    public var imgCount:Int = 0
    
    let sizeOfTypes = [0,1,1,2,4,8,1,1,2,4,8,4,8]
    
    /*
     1 ：BYTE型(1バイト整数）符号なし
     　2 ：ASCII型(1バイトASCII文字）
     　3 ：SHORT型(2バイト短整数）符号なし
     　4 ：LONG型(4バイト長整数）符号なし
     　5 ：RATIONAL型(8バイト分数、4バイト分子と４バイト分母）
     　6 ：SBYTE型(1バイト符号付き整数）
     　7 ：UNDEFINED型(1バイトデータ）
     　8 ：SSHORT型(2バイト符号付き整数）
     　9 ：SLONG型(4バイト符号付き整数）
     　10：SRATIONAL型(8バイト符号付き分数、4バイト分子と4バイト分母）
     　11：FLOAT型(4バイト実数、IEEE浮動小数点形式）
     　12：DOUBLE型(8バイト倍精度実数、IEEE倍精度浮動小数点形式）
     */
    
    var endian:Int = 0
    
    
    public init?(filePath:String) {
        self.filePath = filePath
        do{
            try openStream(filePath: self.filePath)
        }catch{
            return nil
        }
        analyzeTif()
        
        
    }
    
    public init?(fileURL:URL) {
        self.filePath = fileURL.path
        do{
            try openStream(filePath: self.filePath)
        }catch{
            return nil
        }
        analyzeTif()
        
    }
    
    
    deinit {
        print("MTIFF deinit. Close file handler.")
        try? stream.fileHandle?.close()
    }
    
    public func openStream(){
        try? openStream(filePath: filePath)
    }
    
    public func openStream(filePath:String?) throws {
        guard let filePath = filePath else {
            throw NSError(domain: "error", code: -1, userInfo: nil)
        }

        
        let url = URL(fileURLWithPath: filePath)
        
        let fileHandle = try? FileHandle(forReadingFrom: url)
        
        guard let fileHandle = fileHandle else {
            throw NSError(domain: "error", code: -1, userInfo: nil)
        }
            
        stream.fileHandle = fileHandle
    }
    public func closeStream(){
        try? stream.fileHandle?.close()
    }
    
    /// before you call this function, you must call openStream()
    public func analyzeTif(){
        
        _ = stream.read(offset: 0, length: 1)
        endian = stream.convertedDataToInt()!
        
        // Endian check
        if(endian == 0x4D){
            isBigEndian = true
            print("Big Endian")
        }else if(endian == 0x49){
            isBigEndian = false
            print("Little Endian")
        }else{
            print("File error")
            self.fileType = .unknown
            self.closeStream()
            return
        }
        
        stream.isBigEndian = isBigEndian
        
        // FileType check
        _ = stream.read(offset: 2, length: 2)
        let fileType = stream.convertedDataToInt()!
        
        if(fileType == 0x2A){
            // 44
            print("Tiff format file")
        }else if(fileType == 0x2B){
            self.fileType = .bigTiff
            print("BigTiff format file")
            self.closeStream()
            return
        }else{
            self.fileType = .unknown
            print("This is not a tiff file")
            self.closeStream()
            return
        }
        
        // IFDのポインタ
        _ = stream.read(offset: 4, length: 4)
        var ifdOffset = stream.convertedDataToInt()!
        ifdOffsets.append(ifdOffset)
        print("IFD offset:", ifdOffset)
        
        _ = stream.read(offset: ifdOffset, length: 2)
        var tagCount = stream.convertedDataToInt()!
        print("tag Count:", tagCount)
        
        // 1つめのIFDのセットを読む
        // すべてのページが同じ幅などの条件であると仮定して，必要な情報を読むために1枚だけ読んでおく
        
        var tagStartPoint = ifdOffset + 2
        print("Start to read 1st IFD Entry")
        for _ in 0..<tagCount{
            // Tag (2 bytes)
            // Tag's data type (2 bytes)
            // Number of data elements (4 bytes)
            // Data itself or offset to the data (4 bytes)
            
            _ = stream.read(offset: tagStartPoint, length: 2)
            let tag = stream.convertedDataToInt()!
            
            _ = stream.read(offset: tagStartPoint + 2, length: 2)
            let tagType = stream.convertedDataToInt()!
            
            _ = stream.read(offset: tagStartPoint + 4, length: 4)
            let elementCount = stream.convertedDataToInt()!
            
            let dataSizeInByte = sizeOfTypes[tagType] * elementCount
            
            var readLength = dataSizeInByte
            if (readLength > 4){
                readLength = 4
            }
            
            _ = stream.read(offset: tagStartPoint + 8, length: readLength)
            
            if (readLength == 0){
                tagStartPoint += 12
                continue
            }
            
            let element = stream.convertedDataToInt()!
            
            
            print("\(tagStartPoint), tag: \(String(format: "%04x", tag).uppercased()), type: \(tagType), element: \(elementCount), byte: \(dataSizeInByte), element: \(element)")
            
            switch tag {
            case 0x0100:
                // width
                self.width = element
                
            case 0x0101:
                // height
                self.height = element
                
            case 0x011A:
                // X_Resolution
                // RATIONAL
                if(dataSizeInByte == 8){
                    _ = stream.read(offset: element, length: 4)
                    let top = stream.convertedDataToInt()!
                    
                    _ = stream.read(offset: element + 4, length: 4)
                    let bottom = stream.convertedDataToInt()!
                    
                    self.resolutionX = top.toFloat() / bottom.toFloat()
                    
                }
                print("X resolution", resolutionX)
                
            case 0x011B:
                // Y_Resolution
                // RATIONAL
                if(dataSizeInByte == 8){
                    _ = stream.read(offset: element, length: 4)
                    let top = stream.convertedDataToInt()!
                    
                    _ = stream.read(offset: element + 4, length: 4)
                    let bottom = stream.convertedDataToInt()!
                    
                    self.resolutionY = top.toFloat() / bottom.toFloat()
                    
                }
                print("Y resolution", resolutionX)
                
            case 0x0102:
                // bits
                if(dataSizeInByte <= 4){
                    self.bitsPerSample = element
                }
                
            case 0x010E:
                // comment of ImageJ
                // IMAGE_DESCRIPTION
                
                fileDescription = [:]
                
                let commentData = stream.read(offset: element, length: dataSizeInByte)!
                
                let commentString = String(bytes: commentData, encoding: .ascii)!
                
                commentString.enumerateLines{
                    line, stop in
                    print(line)
                    let components = line.components(separatedBy: "=")
                    if (components.count == 2){
                        let dicKey = line.components(separatedBy: "=")[0]
                        let dicVal = line.components(separatedBy: "=")[1]
                        self.fileDescription?.updateValue(dicVal, forKey: dicKey)
                    }else{
                    }
                    
                    
                }
                
                if let info = self.fileDescription{
                    if(info.keys.contains("spacing")){
                        scaleZ = Float(info["spacing"] as! String)!
                    }
                    
                    if(info.keys.contains("unit")){
                        unitString = info["unit"] as? String
                    }
                }
                
            case 0xC696:
                // META_DATA_BYTE_COUNTS
                //
                for i in 0..<elementCount{
                    _ = stream.read(offset: element + 4 * i, length: 4)

                    if metaDataCounts == nil{
                        metaDataCounts = []
                    }
                    metaDataCounts?.append(stream.convertedDataToInt()!)
//                    let dataCount =
//                    metaDataCounts.append(stream.getIntValue()!)
                }
                
                print("meta data count:", metaDataCounts?.count)
                
            case 0xC697:
                // META_DATA
                //
                self.metaDataPosition = element
//
//                acquisitionInfo = String(bytes: commentData, encoding: .ascii)!
//                //                print(commentString)
                
            default:
                break
            }
            
            
            tagStartPoint += 12
        }
        
        imgCount += 1
        
        print("1st IFD Entry Analyzed")
        
        
        var currentPoint = tagStartPoint
        
        print("Start to read additional IFD entries. start from \(currentPoint)")
        
        while true {
            _ = stream.read(offset: currentPoint, length: 4)
            ifdOffset = stream.convertedDataToInt()!
            
            if(ifdOffset == 0){
                print("Next ifd offset is 0")
                print("Found \(ifdOffsets.count) IFD entries")
                break
            }
            currentPoint = ifdOffset
            
            imgCount += 1
            
            ifdOffsets.append(currentPoint)
            
            _ = stream.read(offset: currentPoint, length: 2)
            tagCount = stream.convertedDataToInt()!
            
            currentPoint += 2 + 12 * tagCount
            
        }
        
        // type check
        if (imgCount == 1){
            self.fileType = .singlePageTiff
        }
        
        // Determine if it's an ImageJ Tiff file
        // Check if the key for ImageJ exists in the 0x010E fileInfo

        if let info = self.fileDescription{
            if(info.keys.contains("ImageJ")){
                print("Metadata contains ImageJ key")
                
                // channels
                if(info.keys.contains("channels")){
                    self.channel = Int(info["channels"] as! String)!
                }else{
                    self.channel = 1
                }
                
                print(imgCount)
                if(imgCount == 1){
                    // largeTif
                    self.fileType = .ImageJ_LargetiffStack
                    if(info.keys.contains("images")){
                        print("image count obtained from file info")
                        imgCount = Int(info["images"] as! String)!
                    }
                    
                }else{
                    self.fileType = .ImageJ_TiffStack
                    
                }
                
            }else{
                if(imgCount > 1){
                    self.fileType = .multipageTiff
                }
                
            }
            
        }else{
            print(imgCount)
            if(imgCount > 1){
                self.fileType = .multipageTiff
            }
        }
        
        if(imgCount == channel){
            channel = 1
        }
    }
    
    
    public func image(pageNo: Int) -> NSImage?{
        guard let _data = imageData(pageNo: pageNo) else {return nil}
        return  NSImage(data: _data)
    }
    
    public func imageData(pageNo:Int) -> Data?{
        if(pageNo >= self.imgCount){
            print("out of range. page np = \(pageNo), total image count = \(self.imgCount)")
            return nil
        }
        
        
        switch self.fileType {
        case .unknown , .singlePageTiff , .bigTiff:
            print("unsuppoerted file type: \(self.fileType)")
            return nil
            
        case .multipageTiff:
            return self.getImgData(pageNo: pageNo)
            
        case .ImageJ_TiffStack:
            return self.getImgDataImageJ(pageNo: pageNo)
            
        case .ImageJ_LargetiffStack:
            return self.getImgDataImageJLargefile(pageNo: pageNo)
            
            
        }
        
    }
    
    private func getImgData(pageNo:Int) -> Data?{
        
        try? openStream(filePath: self.filePath)
        
        var pointerToImg:[Int] = []
        var stripBytes:[Int] = []
        
        print("calculate needed bytes")
        var needBytes = 0
        needBytes = 10 // 8 + tagCount(2 bytes)
        needBytes += 4 // next IFD = 00-00-00-00
        
        _ = stream.read(offset: self.ifdOffsets[pageNo], length: 2)
        var tagCount = stream.convertedDataToInt()!
        print("tag Count:", tagCount)
        
        var sumStripBytes = 0
        
        var currentPoint = self.ifdOffsets[pageNo]+2
        
        
        for _ in 0..<tagCount {
            
            _ = stream.read(offset: currentPoint, length: 2)
            let tag = stream.convertedDataToInt()!
            
            _ = stream.read(offset: currentPoint + 2, length: 2)
            let tagType = stream.convertedDataToInt()!
            
            _ = stream.read(offset: currentPoint + 4, length: 4)
            let elementCount = stream.convertedDataToInt()!
            
            let dataSizeInByte = sizeOfTypes[tagType] * elementCount
            
            var readLength = dataSizeInByte
            if (dataSizeInByte > 4){
                readLength = 4
            }
            
            _ = stream.read(offset: currentPoint + 8, length: readLength)
            let element = stream.convertedDataToInt()!
            
            print("\(currentPoint), tag: \(String(format: "%04x", tag).uppercased()), type: \(tagType), element: \(elementCount), byte: \(dataSizeInByte), element: \(element)")
            
            if (tag == 0x0117){
                // stripBytes
                needBytes += 2 + 2 + 4 + 4 // 12
                if (dataSizeInByte > 4){
                    print("追加バイト:", dataSizeInByte)
                    needBytes += dataSizeInByte
                }
                
                if (elementCount > 1){
                    print("strip count= \(elementCount)")
                    for j in 0..<elementCount{
                        let stripReadLengthPosition = element + sizeOfTypes[tagType] * j
                        _ = stream.read(offset: stripReadLengthPosition, length: sizeOfTypes[tagType])
                        //            print(j, stream.getIntValue()!)
                        stripBytes.append(stream.convertedDataToInt()!)
                    }
                    print(stripBytes)
                    sumStripBytes = stripBytes.reduce(0, +)
                    
                    needBytes += sumStripBytes
                }else{
                    stripBytes.append(element)
                    sumStripBytes = stripBytes.reduce(0, +)
                    needBytes += sumStripBytes
                }
                
                
            }else if (tag == 0x0111){
                // pointer to img
                needBytes += 2 + 2 + 4 + 4 // 12
                
                if (dataSizeInByte > 4){
                    needBytes += dataSizeInByte
                }
                
                if (elementCount > 1){
                    print("data count= \(elementCount)")
                    for j in 0..<elementCount {
                        let stripReadDataPosition = element + sizeOfTypes[tagType] * j
                        _ = stream.read(offset: stripReadDataPosition, length: sizeOfTypes[tagType])
                        //            print(j, stream.getIntValue()!)
                        
                        pointerToImg.append(stream.convertedDataToInt()!)
                    }
                    print(pointerToImg)
                }else{
                    pointerToImg.append(element)
                }
                
                
            }else{
                needBytes += 2 + 2 + 4 + 4 // 12
                if (dataSizeInByte > 4){
                    needBytes += dataSizeInByte
                }
            }
            
            currentPoint += 12
        }
        
        print("final need bytes", needBytes)
        
        
        
        // create img data
        var newData = Data(repeating: 0, count: needBytes + 1000)
        
        var pointerToNewImg:[Int] = []
        
        
        newData[0...4] = stream.read(offset: 0, length: 4)!
        newData[isBigEndian ? 7 : 4] = 0x08
        newData[8...9] = stream.read(offset: self.ifdOffsets[pageNo], length: 2)!
        
        
        _ = stream.read(offset: self.ifdOffsets[pageNo], length: 2)
        tagCount = stream.convertedDataToInt()!
        print("tag Count:", tagCount)
        
        currentPoint = self.ifdOffsets[pageNo]+2
        
        var newDataLargeDataPosition = 8 + 2 + 12 * tagCount + 4
        
        var newDataPosition = 8 + 2
        var imgDataStartPosition = 0
        
        for _ in 0..<tagCount {
            
            _ = stream.read(offset: currentPoint, length: 2)
            let tag = stream.convertedDataToInt()!
            
            if (tag == 0x0117){
                
                _ = stream.read(offset: currentPoint + 2, length: 2)
                let tagType = stream.convertedDataToInt()!
                
                _ = stream.read(offset: currentPoint + 4, length: 4)
                let elementCount = stream.convertedDataToInt()!
                
                let dataSizeInByte = sizeOfTypes[tagType] * elementCount
                
                var readLength = dataSizeInByte
                
                if (dataSizeInByte > 4){
                    readLength = 4
                }
                
                _ = stream.read(offset: currentPoint + 8, length: readLength)
                let element = stream.convertedDataToInt()!
                
                
                newData[newDataPosition ..< newDataPosition + 8] = stream.read(offset: currentPoint, length: 8)!
                
                newData[newDataPosition + 8 + (isBigEndian ? 0 : 3)] = UInt8(newDataLargeDataPosition >> 24 & 255)
                newData[newDataPosition + 8 + (isBigEndian ? 1 : 2)] = UInt8(newDataLargeDataPosition >> 16 & 255)
                newData[newDataPosition + 8 + (isBigEndian ? 2 : 1)] = UInt8(newDataLargeDataPosition >> 8 & 255)
                newData[newDataPosition + 8 + (isBigEndian ? 3 : 0)] = UInt8(newDataLargeDataPosition & 255)
                
                print(newDataLargeDataPosition)
                
                newData[newDataLargeDataPosition ..< newDataLargeDataPosition + dataSizeInByte] = stream.read(offset: element, length: dataSizeInByte)!
                
                newDataLargeDataPosition += dataSizeInByte
                
                
            }else if (tag == 0x0111){
                
                _ = stream.read(offset: currentPoint + 2, length: 2)
                let tagType = stream.convertedDataToInt()!
                
                _ = stream.read(offset: currentPoint + 4, length: 4)
                let elementCount = stream.convertedDataToInt()!
                
                let dataSizeInByte = sizeOfTypes[tagType] * elementCount
                
                var readLength = dataSizeInByte
                
                if (dataSizeInByte > 4){
                    readLength = 4
                }
                
                _ = stream.read(offset: currentPoint + 8, length: readLength)
                //                let element = stream.getIntValue()!
                
                
                newData[newDataPosition ..< newDataPosition + 8] = stream.read(offset: currentPoint, length: 8)!
                
                newData[newDataPosition + 8 + (isBigEndian ? 0 : 3)] = UInt8(newDataLargeDataPosition >> 24 & 255)
                newData[newDataPosition + 8 + (isBigEndian ? 1 : 2)] = UInt8(newDataLargeDataPosition >> 16 & 255)
                newData[newDataPosition + 8 + (isBigEndian ? 2 : 1)] = UInt8(newDataLargeDataPosition >> 8 & 255)
                newData[newDataPosition + 8 + (isBigEndian ? 3 : 0)] = UInt8(newDataLargeDataPosition & 255)
                
                imgDataStartPosition = newDataLargeDataPosition + dataSizeInByte
                var newImgDataStartPosition = imgDataStartPosition
                
                if(pointerToImg.count == 1){
                    
                }
                
                for j in 0..<pointerToImg.count {
                    print(newDataLargeDataPosition)
                    
                    newData[newDataLargeDataPosition + (isBigEndian ? 0 : 3)] = UInt8(newImgDataStartPosition >> 24 & 255)
                    newData[newDataLargeDataPosition + (isBigEndian ? 1 : 2)] = UInt8(newImgDataStartPosition >> 16 & 255)
                    newData[newDataLargeDataPosition + (isBigEndian ? 2 : 1)] = UInt8(newImgDataStartPosition >> 8 & 255)
                    newData[newDataLargeDataPosition + (isBigEndian ? 3 : 0)] = UInt8(newImgDataStartPosition & 255)
                    
                    //                    if(imageJcompatibleLargeTiff == false){
                    
                    newData[newImgDataStartPosition ..< newImgDataStartPosition + stripBytes[j]] =
                    stream.read(offset: pointerToImg[j], length: stripBytes[j])!
                    //
                    //                    }else{
                    //                        let specialPosition = pointerToImg[j] + stripBytes[j] * imageJcompatibleImgNo
                    //                        newData[newImgDataStartPosition ..< newImgDataStartPosition + stripBytes[j]] =
                    //                        stream.read(offset: specialPosition, length: stripBytes[j])!
                    //                    }
                    
                    newDataLargeDataPosition += sizeOfTypes[tagType]
                    newImgDataStartPosition += stripBytes[j]
                }
                newDataLargeDataPosition = newImgDataStartPosition
                
            }else{
                
                _ = stream.read(offset: currentPoint + 2, length: 2)
                let tagType = stream.convertedDataToInt()!
                
                _ = stream.read(offset: currentPoint + 4, length: 4)
                let elementCount = stream.convertedDataToInt()!
                
                let dataSizeInByte = sizeOfTypes[tagType] * elementCount
                
                if (dataSizeInByte > 4){
                    newData[newDataPosition ..< newDataPosition + 8] = stream.read(offset: currentPoint, length: 8)!
                    
                    newData[newDataPosition + 8 + (isBigEndian ? 0 : 3)] = UInt8(newDataLargeDataPosition >> 24 & 255)
                    newData[newDataPosition + 8 + (isBigEndian ? 1 : 2)] = UInt8(newDataLargeDataPosition >> 16 & 255)
                    newData[newDataPosition + 8 + (isBigEndian ? 2 : 1)] = UInt8(newDataLargeDataPosition >> 8 & 255)
                    newData[newDataPosition + 8 + (isBigEndian ? 3 : 0)] = UInt8(newDataLargeDataPosition & 255)
                    
                    _ = stream.read(offset: currentPoint + 8, length: 4)
                    let element = stream.convertedDataToInt()!
                    
                    newData[newDataLargeDataPosition ..< newDataLargeDataPosition + dataSizeInByte] = stream.read(offset: element, length: dataSizeInByte)!
                    
                    newDataLargeDataPosition += dataSizeInByte
                    
                }else{
                    newData[newDataPosition ..< newDataPosition + 12] = stream.read(offset: currentPoint, length: 12)!
                }
                
                
            }
            
            
            currentPoint += 12
            
            if (tag != 0x010E){
                newDataPosition += 12
            }
            
            
        }
        
        return newData
        
    }
    
    
    private func getImgDataImageJ(pageNo:Int) -> Data?{
        // < 4 GB imageJ Tiff
        // IFD counts = Image counts
        print("read tiff (< 4 GB ImageJ Tiff): page no = \(pageNo)")
        
        var pointerToImg:[Int] = []
        var stripBytes:[Int] = []
        
        print("calculate needed bytes")
        var needBytes = 0
        needBytes = 10 // endian(2) + type(2) + ifd start point(4) + tag count(2)
        needBytes += 4 // next IFD = 00-00-00-00
        
        _ = stream.read(offset: self.ifdOffsets[pageNo], length: 2)
        var tagCount = stream.convertedDataToInt()!
        print("tag Count:", tagCount)
        
        var sumStripBytes = 0
        
        var currentPoint = self.ifdOffsets[pageNo] + 2
        
        
        for _ in 0..<tagCount {
            
            _ = stream.read(offset: currentPoint, length: 2)
            let tag = stream.convertedDataToInt()!
            
            _ = stream.read(offset: currentPoint + 2, length: 2)
            let tagType = stream.convertedDataToInt()!
            
            _ = stream.read(offset: currentPoint + 4, length: 4)
            let elementCount = stream.convertedDataToInt()!
            
            let dataSizeInByte = sizeOfTypes[tagType] * elementCount
            
            var readLength = dataSizeInByte
            if (dataSizeInByte > 4){
                readLength = 4
            }
            
            _ = stream.read(offset: currentPoint + 8, length: readLength)
            let element = stream.convertedDataToInt()!
            
            print("\(currentPoint), tag: \(String(format: "%04x", tag).uppercased()), type: \(tagType), element: \(elementCount), byte: \(dataSizeInByte), element: \(element)")
            
            if (tag == 0x0117){
                // StripByteCounts
                needBytes += 2 + 2 + 4 + 4 // 12
                if (dataSizeInByte > 4){
                    needBytes += dataSizeInByte
                }
                
                
                if (elementCount > 1){
                    print("strip count= \(elementCount)")
                    for j in 0..<elementCount{
                        let stripReadLengthPosition = element + sizeOfTypes[tagType] * j
                        _ = stream.read(offset: stripReadLengthPosition, length: sizeOfTypes[tagType])
                        //            print(j, stream.getIntValue()!)
                        stripBytes.append(stream.convertedDataToInt()!)
                    }
                    print(stripBytes)
                    sumStripBytes = stripBytes.reduce(0, +)
                    
                    needBytes += sumStripBytes
                    
                }else{
                    stripBytes.append(element)
                    sumStripBytes = stripBytes.reduce(0, +)
                    needBytes += sumStripBytes
                }
                
                
            }else if (tag == 0x0111){
                
                needBytes += 2 + 2 + 4 + 4 // 12
                
                if (dataSizeInByte > 4){
                    needBytes += dataSizeInByte
                }
                
                if (elementCount > 1){
                    print("strip data count= \(elementCount)")
                    for j in 0..<elementCount {
                        let stripReadDataPosition = element + sizeOfTypes[tagType] * j
                        _ = stream.read(offset: stripReadDataPosition, length: sizeOfTypes[tagType])
                        //            print(j, stream.getIntValue()!)
                        
                        pointerToImg.append(stream.convertedDataToInt()!)
                    }
                    print(pointerToImg)
                }else{
                    pointerToImg.append(element)
                }
                
                
            }else{
                needBytes += 2 + 2 + 4 + 4 // 12
                if (dataSizeInByte > 4){
                    needBytes += dataSizeInByte
                }
            }
            
            currentPoint += 12
        }
        
        print("final need bytes", needBytes)
        
        // create img data
        var newData = Data(repeating: 0, count: needBytes + 1000)
        
        var pointerToNewImg:[Int] = []
        
        newData[0...4] = stream.read(offset: 0, length: 4)!
        newData[isBigEndian ? 7 : 4] = 0x08
        newData[8...9] = stream.read(offset: self.ifdOffsets[pageNo], length: 2)!
        
        _ = stream.read(offset: self.ifdOffsets[pageNo], length: 2)
        tagCount = stream.convertedDataToInt()!
        print("tag Count:", tagCount)
        
        currentPoint = self.ifdOffsets[pageNo]+2
        
        var newDataLargeDataPosition = 8 + 2 + 12 * tagCount + 4
        
        var newDataPosition = 8 + 2
        var imgDataStartPosition = 0
        
        for _ in 0..<tagCount {
            
            _ = stream.read(offset: currentPoint, length: 2)
            let tag = stream.convertedDataToInt()!
            
            if (tag == 0x0117){
                // stripBytes
                //                _ = stream.read(offset: currentPoint, length: 2)
                //                let tag = stream.getIntValue()!
                
                _ = stream.read(offset: currentPoint + 2, length: 2)
                let tagType = stream.convertedDataToInt()!
                
                _ = stream.read(offset: currentPoint + 4, length: 4)
                let elementCount = stream.convertedDataToInt()!
                
                let dataSizeInByte = sizeOfTypes[tagType] * elementCount
                
                var readLength = dataSizeInByte
                
                if (dataSizeInByte > 4){
                    readLength = 4
                }
                
                _ = stream.read(offset: currentPoint + 8, length: readLength)
                let element = stream.convertedDataToInt()!
                
                // copy tag, data type, element count = 8 bytes
                newData[newDataPosition ..< newDataPosition + 8] = stream.read(offset: currentPoint, length: 8)!
                
                // element = address to large data position
                newData[newDataPosition + 8 + (isBigEndian ? 0 : 3)] = UInt8(newDataLargeDataPosition >> 24 & 255)
                newData[newDataPosition + 8 + (isBigEndian ? 1 : 2)] = UInt8(newDataLargeDataPosition >> 16 & 255)
                newData[newDataPosition + 8 + (isBigEndian ? 2 : 1)] = UInt8(newDataLargeDataPosition >> 8 & 255)
                newData[newDataPosition + 8 + (isBigEndian ? 3 : 0)] = UInt8(newDataLargeDataPosition & 255)
                
                
                newData[newDataLargeDataPosition ..< newDataLargeDataPosition + dataSizeInByte] = stream.read(offset: element, length: dataSizeInByte)!
                
                newDataLargeDataPosition += dataSizeInByte
                
                
            }else if (tag == 0x0111){
                
                _ = stream.read(offset: currentPoint + 2, length: 2)
                let tagType = stream.convertedDataToInt()!
                
                _ = stream.read(offset: currentPoint + 4, length: 4)
                let elementCount = stream.convertedDataToInt()!
                
                let dataSizeInByte = sizeOfTypes[tagType] * elementCount
                
                var readLength = dataSizeInByte
                
                if (dataSizeInByte > 4){
                    readLength = 4
                }
                
                _ = stream.read(offset: currentPoint + 8, length: readLength)
                
                // copy tag, data type, element count = 8 bytes
                newData[newDataPosition ..< newDataPosition + 8] = stream.read(offset: currentPoint, length: 8)!
                
                // element = address to large data position
                print(newDataLargeDataPosition)
                newData[newDataPosition + 8 + (isBigEndian ? 0 : 3)] = UInt8(newDataLargeDataPosition >> 24 & 255)
                newData[newDataPosition + 8 + (isBigEndian ? 1 : 2)] = UInt8(newDataLargeDataPosition >> 16 & 255)
                newData[newDataPosition + 8 + (isBigEndian ? 2 : 1)] = UInt8(newDataLargeDataPosition >> 8 & 255)
                newData[newDataPosition + 8 + (isBigEndian ? 3 : 0)] = UInt8(newDataLargeDataPosition & 255)
                
                imgDataStartPosition = newDataLargeDataPosition // + dataSizeInByte
                
                var newImgDataStartPosition = imgDataStartPosition
                
                if(pointerToImg.count == 1){
                    print("tag 0x0111, pointer to image data count = 1")
                   
                }
                
                for j in 0..<pointerToImg.count {
                    print(newDataLargeDataPosition)
                    
                    newData[newDataLargeDataPosition + (isBigEndian ? 0 : 3)] = UInt8(newImgDataStartPosition >> 24 & 255)
                    newData[newDataLargeDataPosition + (isBigEndian ? 1 : 2)] = UInt8(newImgDataStartPosition >> 16 & 255)
                    newData[newDataLargeDataPosition + (isBigEndian ? 2 : 1)] = UInt8(newImgDataStartPosition >> 8 & 255)
                    newData[newDataLargeDataPosition + (isBigEndian ? 3 : 0)] = UInt8(newImgDataStartPosition & 255)
                    
                    
                    newData[newImgDataStartPosition ..< newImgDataStartPosition + stripBytes[j]] =
                    stream.read(offset: pointerToImg[j], length: stripBytes[j])!
                    
                    
                    newDataLargeDataPosition += sizeOfTypes[tagType]
                    newImgDataStartPosition += stripBytes[j]
                }
                
                newDataLargeDataPosition = newImgDataStartPosition
     
                
            }else{
                
                _ = stream.read(offset: currentPoint + 2, length: 2)
                let tagType = stream.convertedDataToInt()!
                
                _ = stream.read(offset: currentPoint + 4, length: 4)
                let elementCount = stream.convertedDataToInt()!
                
                let dataSizeInByte = sizeOfTypes[tagType] * elementCount
                
                if (dataSizeInByte > 4){
                    newData[newDataPosition ..< newDataPosition + 8] = stream.read(offset: currentPoint, length: 8)!
                    
                    newData[newDataPosition + 8 + (isBigEndian ? 0 : 3)] = UInt8(newDataLargeDataPosition >> 24 & 255)
                    newData[newDataPosition + 8 + (isBigEndian ? 1 : 2)] = UInt8(newDataLargeDataPosition >> 16 & 255)
                    newData[newDataPosition + 8 + (isBigEndian ? 2 : 1)] = UInt8(newDataLargeDataPosition >> 8 & 255)
                    newData[newDataPosition + 8 + (isBigEndian ? 3 : 0)] = UInt8(newDataLargeDataPosition & 255)
                    
                    _ = stream.read(offset: currentPoint + 8, length: 4)
                    let element = stream.convertedDataToInt()!
                    
                    newData[newDataLargeDataPosition ..< newDataLargeDataPosition + dataSizeInByte] = stream.read(offset: element, length: dataSizeInByte)!
                    
                    newDataLargeDataPosition += dataSizeInByte
                    
                }else{
                    newData[newDataPosition ..< newDataPosition + 12] = stream.read(offset: currentPoint, length: 12)!
                    
                    // Reset ImageJ LUT
                    if (tag == 0x0106){
                        
                        let valueOfPhotometricInterpretation = 1
                        
                        newData[newDataPosition + 8 + (isBigEndian ? 0 : 1)] = UInt8(valueOfPhotometricInterpretation >> 8 & 255)
                        newData[newDataPosition + 8 + (isBigEndian ? 1 : 0)] = UInt8(valueOfPhotometricInterpretation & 255)
                        
                    }
                    
                }
                
                
            }
            
            
            currentPoint += 12
            
            if (tag != 0x010E){
                // image description
                newDataPosition += 12
            }
            
            
        }
        
        
        return newData
        
    }
    
    
    
    private var imageJLargefileCommonBaseData:Data?
    
    private var imageJLargefileOriginalStripPosition:Int?
    private var imageJLargefileOriginalStripByteLength:Int?
    private var imageJLargefileNewStripPosition:Int?
    private var imageJLargefileCommonNeedbytes:Int?
    
    private func getImgDataImageJLargefile(pageNo:Int) -> Data?{
        
        try? openStream(filePath: self.filePath)
        
        if(imageJLargefileCommonBaseData != nil){
            print("page:", pageNo)
            return getImgDataImageJLargefileFastcopy(pageNo: pageNo)
        }
        
        var pointerToImg:[Int] = []
        var stripBytes:[Int] = []
        
        print("calculate needed bytes")
        var needBytes = 0
        needBytes = 10 // 8 + tagCount(2 bytes)
        needBytes += 4 // next IFD = 00-00-00-00
        
        _ = stream.read(offset: self.ifdOffsets[0], length: 2)
        var tagCount = stream.convertedDataToInt()!
        print("tag Count:", tagCount)
        
        var sumStripBytes = 0
        
        var currentPoint = self.ifdOffsets[0]+2
        
        
        for _ in 0..<tagCount {
            
            _ = stream.read(offset: currentPoint, length: 2)
            let tag = stream.convertedDataToInt()!
            
            _ = stream.read(offset: currentPoint + 2, length: 2)
            let tagType = stream.convertedDataToInt()!
            
            _ = stream.read(offset: currentPoint + 4, length: 4)
            let elementCount = stream.convertedDataToInt()!
            
            let dataSizeInByte = sizeOfTypes[tagType] * elementCount
            
            var readLength = dataSizeInByte
            if (dataSizeInByte > 4){
                readLength = 4
            }
            
            _ = stream.read(offset: currentPoint + 8, length: readLength)
            let element = stream.convertedDataToInt()!
            
            
            if (tag == 0x0117){
                // stripBytes
                needBytes += 2 + 2 + 4 + 4 // 12
                if (dataSizeInByte > 4){
                    needBytes += dataSizeInByte
                }
                
                if (elementCount > 1){
                    print("strip count= \(elementCount)")
                    for j in 0..<elementCount{
                        let stripReadLengthPosition = element + sizeOfTypes[tagType] * j
                        _ = stream.read(offset: stripReadLengthPosition, length: sizeOfTypes[tagType])
                        //            print(j, stream.getIntValue()!)
                        stripBytes.append(stream.convertedDataToInt()!)
                    }
                    print(stripBytes)
                    sumStripBytes = stripBytes.reduce(0, +)
                    
                    needBytes += sumStripBytes
                }else{
                    // element Count = 1 なら，そのままstripByteがかいてある
                    stripBytes.append(element)
                    sumStripBytes = stripBytes.reduce(0, +)
                    needBytes += sumStripBytes
                }
                
                
            }else if (tag == 0x0111){
                // pointer to img
                needBytes += 2 + 2 + 4 + 4 // 12
                
                if (dataSizeInByte > 4){
                    needBytes += dataSizeInByte
                }
                
                if (elementCount > 1){
                    for j in 0..<elementCount {
                        let stripReadDataPosition = element + sizeOfTypes[tagType] * j
                        _ = stream.read(offset: stripReadDataPosition, length: sizeOfTypes[tagType])
                        //            print(j, stream.getIntValue()!)
                        
                        pointerToImg.append(stream.convertedDataToInt()!)
                    }
                    print(pointerToImg)
                }else{
                    pointerToImg.append(element)
                }
                
                
            }else{
                needBytes += 2 + 2 + 4 + 4 // 12
                if (dataSizeInByte > 4){
                    needBytes += dataSizeInByte
                }
            }
            
            currentPoint += 12
        }
        
        
        if(pointerToImg.count == 1 && stripBytes.count == 1){
            imageJLargefileOriginalStripPosition = pointerToImg[0]
            imageJLargefileOriginalStripByteLength = stripBytes[0]
            imageJLargefileCommonNeedbytes = needBytes
            
        }else{
            print("ImageJ Largetiff strip error")
            return nil
        }
        
        
        
        
        // create img data
        var newData = Data(repeating: 0, count: needBytes + 1000)
        
        var pointerToNewImg:[Int] = []
        
        
        newData[0...4] = stream.read(offset: 0, length: 4)!
        newData[isBigEndian ? 7 : 4] = 0x08
        newData[8...9] = stream.read(offset: self.ifdOffsets[0], length: 2)!
        
        
        _ = stream.read(offset: self.ifdOffsets[0], length: 2)
        tagCount = stream.convertedDataToInt()!
        print("tag Count:", tagCount)
        
        currentPoint = self.ifdOffsets[0]+2
        
        var newDataLargeDataPosition = 8 + 2 + 12 * tagCount + 4
        
        var newDataPosition = 8 + 2
        var imgDataStartPosition = 0
        
        for _ in 0..<tagCount {
            
            _ = stream.read(offset: currentPoint, length: 2)
            let tag = stream.convertedDataToInt()!
            
            if (tag == 0x0117){
                // stripBytes
                //                _ = stream.read(offset: currentPoint, length: 2)
                //                let tag = stream.getIntValue()!
                
                _ = stream.read(offset: currentPoint + 2, length: 2)
                let tagType = stream.convertedDataToInt()!
                
                _ = stream.read(offset: currentPoint + 4, length: 4)
                let elementCount = stream.convertedDataToInt()!
                
                let dataSizeInByte = sizeOfTypes[tagType] * elementCount
                
                var readLength = dataSizeInByte
                
                if (dataSizeInByte > 4){
                    readLength = 4
                }
                
                _ = stream.read(offset: currentPoint + 8, length: readLength)
                let element = stream.convertedDataToInt()!
                
                
                newData[newDataPosition ..< newDataPosition + 8] = stream.read(offset: currentPoint, length: 8)!
                
                newData[newDataPosition + 8 + (isBigEndian ? 0 : 3)] = UInt8(newDataLargeDataPosition >> 24 & 255)
                newData[newDataPosition + 8 + (isBigEndian ? 1 : 2)] = UInt8(newDataLargeDataPosition >> 16 & 255)
                newData[newDataPosition + 8 + (isBigEndian ? 2 : 1)] = UInt8(newDataLargeDataPosition >> 8 & 255)
                newData[newDataPosition + 8 + (isBigEndian ? 3 : 0)] = UInt8(newDataLargeDataPosition & 255)
                
                
                newData[newDataLargeDataPosition ..< newDataLargeDataPosition + dataSizeInByte] = stream.read(offset: element, length: dataSizeInByte)!
                
                newDataLargeDataPosition += dataSizeInByte
                
                
            }else if (tag == 0x0111){
                // pointer to img
                // 0x01 11 AA AA BB BB
                //                _ = stream.read(offset: currentPoint, length: 2)
                //                let tag = stream.getIntValue()!
                
                _ = stream.read(offset: currentPoint + 2, length: 2)
                let tagType = stream.convertedDataToInt()!
                
                _ = stream.read(offset: currentPoint + 4, length: 4)
                let elementCount = stream.convertedDataToInt()!
                
                let dataSizeInByte = sizeOfTypes[tagType] * elementCount
                
                var readLength = dataSizeInByte
                
                if (dataSizeInByte > 4){
                    readLength = 4
                }
                
                _ = stream.read(offset: currentPoint + 8, length: readLength)
                
                newData[newDataPosition ..< newDataPosition + 8] = stream.read(offset: currentPoint, length: 8)!
                
                newData[newDataPosition + 8 + (isBigEndian ? 0 : 3)] = UInt8(newDataLargeDataPosition >> 24 & 255)
                newData[newDataPosition + 8 + (isBigEndian ? 1 : 2)] = UInt8(newDataLargeDataPosition >> 16 & 255)
                newData[newDataPosition + 8 + (isBigEndian ? 2 : 1)] = UInt8(newDataLargeDataPosition >> 8 & 255)
                newData[newDataPosition + 8 + (isBigEndian ? 3 : 0)] = UInt8(newDataLargeDataPosition & 255)
                
                imgDataStartPosition = newDataLargeDataPosition
//                imgDataStartPosition = newDataLargeDataPosition + dataSizeInByte
                var newImgDataStartPosition = imgDataStartPosition
                
       
                print(newDataLargeDataPosition)
                
                newData[newDataLargeDataPosition + (isBigEndian ? 0 : 3)] = UInt8(newImgDataStartPosition >> 24 & 255)
                newData[newDataLargeDataPosition + (isBigEndian ? 1 : 2)] = UInt8(newImgDataStartPosition >> 16 & 255)
                newData[newDataLargeDataPosition + (isBigEndian ? 2 : 1)] = UInt8(newImgDataStartPosition >> 8 & 255)
                newData[newDataLargeDataPosition + (isBigEndian ? 3 : 0)] = UInt8(newImgDataStartPosition & 255)
                

                imageJLargefileNewStripPosition = newImgDataStartPosition
                let specialPosition = pointerToImg[0] + stripBytes[0] * pageNo
                newData[newImgDataStartPosition ..< newImgDataStartPosition + stripBytes[0]] =
                stream.read(offset: specialPosition, length: stripBytes[0])!
                
                
                newDataLargeDataPosition += sizeOfTypes[tagType]
                newImgDataStartPosition += stripBytes[0]
                
                newDataLargeDataPosition = newImgDataStartPosition
                
                
            }else{
                
                _ = stream.read(offset: currentPoint + 2, length: 2)
                let tagType = stream.convertedDataToInt()!
                
                _ = stream.read(offset: currentPoint + 4, length: 4)
                let elementCount = stream.convertedDataToInt()!
                
                let dataSizeInByte = sizeOfTypes[tagType] * elementCount
                
                if (dataSizeInByte > 4){
                    newData[newDataPosition ..< newDataPosition + 8] = stream.read(offset: currentPoint, length: 8)!
                    
                    newData[newDataPosition + 8 + (isBigEndian ? 0 : 3)] = UInt8(newDataLargeDataPosition >> 24 & 255)
                    newData[newDataPosition + 8 + (isBigEndian ? 1 : 2)] = UInt8(newDataLargeDataPosition >> 16 & 255)
                    newData[newDataPosition + 8 + (isBigEndian ? 2 : 1)] = UInt8(newDataLargeDataPosition >> 8 & 255)
                    newData[newDataPosition + 8 + (isBigEndian ? 3 : 0)] = UInt8(newDataLargeDataPosition & 255)
                    
                    _ = stream.read(offset: currentPoint + 8, length: 4)
                    let element = stream.convertedDataToInt()!
                    
                    newData[newDataLargeDataPosition ..< newDataLargeDataPosition + dataSizeInByte] = stream.read(offset: element, length: dataSizeInByte)!
                    
                    newDataLargeDataPosition += dataSizeInByte
                    
                }else{
                    newData[newDataPosition ..< newDataPosition + 12] = stream.read(offset: currentPoint, length: 12)!
                    
                    if (tag == 0x0106){
                        print("Force change color mode", newData[newDataPosition + 8], newData[newDataPosition + 9])
                        
                        let valueOfPhotometricInterpretation = 1
                        
                        newData[newDataPosition + 8 + (isBigEndian ? 0 : 1)] = UInt8(valueOfPhotometricInterpretation >> 8 & 255)
                        newData[newDataPosition + 8 + (isBigEndian ? 1 : 0)] = UInt8(valueOfPhotometricInterpretation & 255)
                        
                        print("Force change color mode", newData[newDataPosition + 8], newData[newDataPosition + 9])
                    }
                    
                }
                
                
            }
            
            
            currentPoint += 12
            
            if (tag != 0x010E){
                newDataPosition += 12
            }
            
            
        }
        
        imageJLargefileCommonBaseData = newData
        
        return newData
        
    }
    
    
    private func getImgDataImageJLargefileFastcopy(pageNo:Int) -> Data?{
        guard var imageJLargefileCommonBaseData = imageJLargefileCommonBaseData,
              let imageJLargefileNewStripPosition = imageJLargefileNewStripPosition,
              let imageJLargefileOriginalStripByteLength = imageJLargefileOriginalStripByteLength,
              let imageJLargefileOriginalStripPosition = imageJLargefileOriginalStripPosition
        else {
            return nil
        }
        
        imageJLargefileCommonBaseData[imageJLargefileNewStripPosition ..< imageJLargefileNewStripPosition + imageJLargefileOriginalStripByteLength] =
        stream.read(offset: imageJLargefileOriginalStripPosition + imageJLargefileOriginalStripByteLength * pageNo, length: imageJLargefileOriginalStripByteLength)!
        
        return imageJLargefileCommonBaseData
    }
    
    public func getMetaData(){
        guard let metaDataCounts = metaDataCounts else {
            return
        }
        
        try? openStream(filePath: filePath)
        
//        let n = metaDataCounts.count
        
        let hdrSize = metaDataCounts[0];
        print("hdrSize", hdrSize)
        if (hdrSize<12 || hdrSize>804) {
            return
        }
        
        var seek = self.metaDataPosition
        
        print("1st seek", seek)
        _ = stream.read(offset: seek, length: 4)
        seek += 4
        
        let magicNumber = stream.convertedDataToInt()!
        if(magicNumber != MAGIC_NUMBER){ // "IJIJ"
            return
        }
        
        let nTypes = (hdrSize-4)/8;
        var types:[Int] = [Int](repeating: 0, count: nTypes)
        var counts:[Int] = [Int](repeating: 0, count: nTypes)
        
        var extraMetaDataEntries = 0;
        
        for i in 0..<nTypes{
            _ = stream.read(offset: seek, length: 4)
            seek += 4
            
            types[i] = stream.convertedDataToInt()!
            
            _ = stream.read(offset: seek, length: 4)
            seek += 4
            counts[i] = stream.convertedDataToInt()!
            
            print(types[i], counts[i])

            if (types[i] < 0xffffff){
                extraMetaDataEntries += counts[i]
            }
        }
        
//        let metaDataTypes = [Int](repeating: 0, count: extraMetaDataEntries)
       
//        let metaData = Data(repeating: 0, count: extraMetaDataEntries)
        
        var start = 1
//        var eMDindex = 0
        
        print("seek", seek)
        for i in 0 ..< nTypes{
            if(types[i] == INFO){
                print("* INFO")
                print("Start Count", start, ", Read Start Position", seek, ", Read bytes",  metaDataCounts[start], ", Read Counts", counts[i])
                seek += metaDataCounts[start]
                
            }else if(types[i] == LABELS){
                print("* LABELS")
                print("Start Count", start, ", Read Start Position", seek, " Read Counts", counts[i])
                
                for j in 0 ..< counts[i]{
//                    print("  \(j) / \(counts[i]) Start Count", start, ", Read Start Position", seek)
                    seek += metaDataCounts[start + j]
                }
                
            }else if(types[i] == RANGES){
                print("* RANGES")
                print("Start Count", start, ", Read Start Position", seek, ", Read bytes",  metaDataCounts[start], ", Read Counts", counts[i])
                
                for c in 0 ..< self.channel{
                    print("channel: \(c)")
                    _ = stream.read(offset: seek + c * 16 + 0, length: 8)
                    let range_min = stream.convertedDataToDouble()
                    _ = stream.read(offset: seek + c * 16 + 8, length: 8)
                    let range_max = stream.convertedDataToDouble()
                    
                    if(displayRanges == nil){
                        displayRanges = [[Double]](repeating: [0], count: 0)
                    }
                    
                    displayRanges?.append([range_min, range_max])
                }
                
                
                seek += metaDataCounts[start]
                
                print(self.displayRanges!)
                
            }else if(types[i] == LUTS){
                print("* LUTS")
                print("Start Count", start, ", Read Start Position", seek, " Read Counts", counts[i])
                
                for j in 0 ..< counts[i]{
//                    print("  \(j) / \(counts[i]) Start Count", start, ", Read Start Position", seek)
                    seek += metaDataCounts[start + j]
                }
                
            }else if(types[i] == PLOT){
                print("* PLOT")
                print("Start Count", start, ", Read Start Position", seek, ", Read bytes",  metaDataCounts[start], ", Read Counts", counts[i])
                seek += metaDataCounts[start]
                
            }else if(types[i] == ROI){
                print("* ROI")
                print("Start Count", start, ", Read Start Position", seek, ", Read bytes",  metaDataCounts[start], ", Read Counts", counts[i])
                seek += metaDataCounts[start]
                
            }else if(types[i] == OVERLAY){
                print("* OVERLAY")
                print("Start Count", start, ", Read Start Position", seek, " Read Counts", counts[i])
                
                for j in 0 ..< counts[i]{
//                    print("  \(j) / \(counts[i]) Start Count", start, ", Read Start Position", seek)
                    seek += metaDataCounts[start + j]
                }
                
            }else if(types[i] == PROPERTIES){
                print("* PROPERTIES")
                print("Start Count", start, ", Read Start Position", seek, " Read Counts", counts[i])
                
                for j in 0 ..< counts[i]{
//                    print("  \(j) / \(counts[i]) Start Count", start, ", Read Start Position", seek)
                    seek += metaDataCounts[start + j]
                }
            }else if(types[i] < 0xFFFFFF){
                print("* other")
                
                print("Start Count", start, ", Read Start Position", seek, " Read Counts", counts[i])
                
                for j in 0 ..< counts[i]{
//                    print("  \(j) / \(counts[i]) Start Count", start, ", Read Start Position", seek)
                    seek += metaDataCounts[start + j]
                }
            }else{
                print("* unknown")
                
                print("Start Count", start, ", Read Start Position", seek, " Read Counts", counts[i])
                
                for j in 0 ..< counts[i]{
//                    print("  \(j) / \(counts[i]) Start Count", start, ", Read Start Position", seek)
                    seek += metaDataCounts[start + j]
                }
            }
            start += counts[i]
        }
        
        
//        self.closeStream()
        
    }
    
    
    
    
}
