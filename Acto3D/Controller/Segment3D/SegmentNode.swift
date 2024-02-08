//
//  SegmentNode.swift
//  Acto3D
//
//  Created by Naoki Takeshita on 2023/02/16.
//

import Foundation
import Cocoa
import simd


struct SegmentNode: Codable{
    var startSliceNo:Int?
    var endSliceNo:Int?
    var currentSliceNo:Int!
    var currentSliceIndex:Int{
        get{
            return self.indexForSlice(slice: currentSliceNo)
        }
    }
    
    var currentKMeansResult:KMeansController.KMeansResult?
    
    /// The size of cropped image
    var size:CGSize?
    
    /// The NSView size of MPR image
    var viewSize:CGSize?
    
    var quaternion:simd_quatf!
    var renderModelParams:RenderingParameters!
    
    var initialClusterCenters:[Float] = []
    
    /// Cluster centers for the slice should be previous cluster centroids
    var clusterCenters:[[Float?]] = [[]]
    
    /// Calculated cluster centroids for the slice
    var clusterCentroids:[[Float?]] = [[]]
    
    var cropArea:NSRect!
    
    /// represents the target area mapped between 0 and 1.0
    var cropAreaCoord:NSRect?
    
    var point:[CGPoint?] = []
    var moment:[CGPoint?] = []
    var maskImage:[CGImage?] = []
    var area:[UInt?] = []
    
    var pixelCount:Int? = nil
    
    
    /// Return `false` if this class is not prepared for segmentation
    var isValid:Bool{
        get{
            if (self.sliceCount == 0 ||  startSliceNo == nil || endSliceNo == nil){
                return false
            }else{
                return true
            }
        }
    }
    
    public enum CodingKeys: String, CodingKey {
        case startSliceNo
        case endSliceNo
        case size
        case viewSize
        case quaternion
        case renderModelParams
        case initialClusterCenters
        case clusterCenters
        case clusterCentroids
        case cropArea
        case cropAreaCoord
        case point
        case moment
        case maskImage
        case area
        case pixelCount
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encodeIfPresent(startSliceNo, forKey: .startSliceNo)
        try container.encodeIfPresent(endSliceNo, forKey: .endSliceNo)
        try container.encodeIfPresent(size, forKey: .size)
        try container.encodeIfPresent(viewSize, forKey: .viewSize)
        try container.encodeIfPresent(quaternion, forKey: .quaternion)
        try container.encodeIfPresent(renderModelParams, forKey: .renderModelParams)
        try container.encodeIfPresent(initialClusterCenters, forKey: .initialClusterCenters)
        try container.encodeIfPresent(clusterCenters, forKey: .clusterCenters)
        try container.encodeIfPresent(clusterCentroids, forKey: .clusterCentroids)
        try container.encodeIfPresent(cropArea, forKey: .cropArea)
        try container.encodeIfPresent(cropAreaCoord, forKey: .cropAreaCoord)
        try container.encodeIfPresent(point, forKey: .point)
        try container.encodeIfPresent(moment, forKey: .moment)
        
        try container.encodeIfPresent(area, forKey: .area)
        
        try container.encodeIfPresent(pixelCount, forKey: .pixelCount)
        
        // Encode CGImages as Data
        try container.encode(maskImage.map { image -> Data? in
            guard let image = image else { return nil }
            let rep = NSBitmapImageRep(cgImage: image)
            return rep.representation(using: .png, properties: [:])
//            return rep.representation(using: .tiff, properties: [:])  <- previous set, data size increase
        }, forKey: .maskImage)
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        startSliceNo = try container.decodeIfPresent(Int.self, forKey: .startSliceNo)
        endSliceNo = try container.decodeIfPresent(Int.self, forKey: .endSliceNo)
        size = try container.decodeIfPresent(CGSize.self, forKey: .size)
        viewSize = try container.decodeIfPresent(CGSize.self, forKey: .viewSize)
        quaternion = try container.decodeIfPresent(simd_quatf.self, forKey: .quaternion)
        renderModelParams = try container.decodeIfPresent(RenderingParameters.self, forKey: .renderModelParams)
        initialClusterCenters = try container.decode([Float].self, forKey: .initialClusterCenters)
        
        
        // `try? ---` is for compatibility with previous versions
        if let clusterCenters = try? container.decodeIfPresent([[Float]].self, forKey: .clusterCenters){
            self.clusterCenters = clusterCenters
        }else{
            clusterCenters = try container.decode([[Float?]].self, forKey: .clusterCenters)
        }
        
        
        // `try? ---` is for compatibility with previous versions
        if let clusterCentroids = try? container.decodeIfPresent([[Float]].self, forKey: .clusterCentroids){
            self.clusterCentroids = clusterCentroids
        }else{
            clusterCentroids = try container.decodeIfPresent([[Float?]].self, forKey: .clusterCentroids) ??
            [[Float?]](repeating: [nil], count: sliceCount)
        }
        
        cropArea = try container.decodeIfPresent(NSRect.self, forKey: .cropArea)
        
        if(cropArea == nil){
            cropArea = NSRect(x: 429, y: 429, width: 429, height: 429)
        }
        
        // Adjusting values for compatibility with previous versions
        if viewSize == nil{
            cropArea = NSRect(
                x: cropArea.origin.x / 429.0 * 460.0,
                y: cropArea.origin.y / 429.0 * 460.0,
                width: cropArea.size.width / 429.0 * 460.0,
                height: cropArea.size.height / 429.0 * 460.0
            )
        }
        
        cropAreaCoord = try container.decodeIfPresent(NSRect.self, forKey: .cropAreaCoord) ?? cropArea / 429.0
        point = try container.decode([CGPoint?].self, forKey: .point)
        moment = try container.decode([CGPoint?].self, forKey: .moment)
        area = try container.decode([UInt?].self, forKey: .area)
        pixelCount = try container.decodeIfPresent(Int.self, forKey: .pixelCount)

        // Decode data as CGImages
        maskImage = try container.decode([Data?].self, forKey: .maskImage).map { data in
            guard let data = data else { return nil }
            return NSImage(data: data)?.toCGImage
        }
    }
    
    init(){
        
    }
    
    var width:Int?{
        get{
            guard let size = self.size else{
                return nil
            }
            return Int(size.width.rounded())
        }
    }
    
    var height:Int?{
        get{
            guard let size = self.size else{
                return nil
            }
            return Int(size.height.rounded())
        }
    }
    
    
    var sliceCount:Int {
        get{
            if(startSliceNo != nil && endSliceNo != nil){
                return abs(startSliceNo! - endSliceNo!) + 1
            }else{
                return 0
            }
        }
    }
    
    mutating func goToNextSlice() -> Int{
        if(startSliceNo! > endSliceNo!){
            currentSliceNo -= 1
            if(currentSliceNo < endSliceNo!){
                currentSliceNo = endSliceNo!
            }
            return currentSliceNo
        }else{
            currentSliceNo += 1
            if(currentSliceNo > endSliceNo!){
                currentSliceNo = endSliceNo!
            }
            return currentSliceNo
        }
    }
    mutating func goToPrevSlice() -> Int{
        if(startSliceNo! > endSliceNo!){
            currentSliceNo += 1
            if(currentSliceNo > startSliceNo!){
                currentSliceNo = startSliceNo!
            }
            return currentSliceNo
        }else{
            currentSliceNo -= 1
            if(currentSliceNo < startSliceNo!){
                currentSliceNo = startSliceNo!
            }
            return currentSliceNo
        }
    }
    
    
    func indexForSlice(slice:Int) -> Int{
        if(startSliceNo! > endSliceNo!){
            return startSliceNo! - slice
        }else{
            return slice - startSliceNo!
        }
    }
    
    func sliceForIndex(index: Int) -> Int{
        if let startSliceNo = startSliceNo,
           let endSliceNo = endSliceNo{
            if(startSliceNo > endSliceNo){
                return startSliceNo - index
            }else{
                return startSliceNo + index
            }
        }else{
            return 0
        }
    }
    
    
    /// Prepare elements for SegmentNodes
    /// Each params are set to nil array
    mutating func prepareContainer(){
        guard let _ = startSliceNo, let _ = endSliceNo else{return}
        
        initialClusterCenters = [Float](repeating: 0, count: 0)
        clusterCenters = [[Float?]](repeating: [nil], count: sliceCount)
        clusterCentroids = [[Float?]](repeating: [nil], count: sliceCount)
//        nodeImage = [CGImage?](repeating: nil, count: sliceCount)
        point = [CGPoint?](repeating: nil, count: sliceCount)
        moment = [CGPoint?](repeating: nil, count: sliceCount)
        area = [UInt?](repeating: nil, count: sliceCount)
        maskImage = [CGImage?](repeating: nil, count: sliceCount)
        
        print("Prepare container for segment nodes: count = \(sliceCount)")
    }
    
    /// Remove elements after the index
    /// This function set nil to each elements (not remove)
    mutating func removeElementAfter(index: Int){
        let startIndex = self.indexForSlice(slice: self.currentSliceNo!)
        let lastIndex = self.indexForSlice(slice: self.endSliceNo!)
        
        print("remove", startIndex, lastIndex, index)
        if(index > lastIndex || index < 0){
            // index out of range
            return
        }
        
        for i in startIndex...lastIndex{
            self.point[i] = nil
            self.moment[i] = nil
            self.clusterCenters[i] = [nil]
            self.clusterCentroids[i] = [nil]
            self.maskImage[i] = nil
        }
    }
    
    /// Remove elements for the index
    /// This function set nil to elements (not remove)
    mutating func removeElement(for index:Int){
        self.point[index] = nil
        self.moment[index] = nil
        self.clusterCenters[index] = [nil]
        self.clusterCentroids[index] = [nil]
        self.maskImage[index] = nil
    }
    
}
