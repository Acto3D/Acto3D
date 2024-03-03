//
//  KMeansController.swift
//  Acto3D
//
//  Created by Naoki Takeshita on 2023/01/08.
//

import Foundation
import Cocoa


class KMeansController{
    
    var device : MTLDevice!
    var cmdQueue : MTLCommandQueue!
    var renderPipeline: MTLComputePipelineState!
    var lib:MTLLibrary!
    
    init(device:MTLDevice, cmdQueue:MTLCommandQueue, lib:MTLLibrary) {
        self.device = device
        self.cmdQueue = cmdQueue
        self.lib = lib
    }
    
    /// parameters for k-means clustering
    struct KMeansResult{
        /// initial centers for clustering used
        var centers: [Float]
        
        /// calculated centroids
        var calculatedClusterCentroids: [Float]
        
        /// cluster index for pixel array
        var clusters: [UInt8]
        
        /// mapped cluster index to 0-255 (UInt8 array)
        var clusterImage: [UInt8]
    }
    
    /// Performs k-means clustering on an input image.
    /// If initial centers have already been obtained, provide them; otherwise, set 'initialCenters' to nil.
    /// When 'initialCenters' is nil, the function uses k-means++ to compute the initial centers.
    /// After the initial centers are determined, the function refines these centers using the k-means algorithm.
    ///
    /// - Parameters:
    ///   - inputImage: The input CGImage for clustering.
    ///   - n_cluster: The number of clusters desired.
    ///   - initialCenters: The initial center values (optional). If not provided, k-means++ is used to determine them.
    /// - Returns: The results of the k-means clustering in a `KMeansResult` format. Returns nil if the clustering fails.
    func calculateKmeans(inputImage:CGImage, n_cluster:Int, initialCenters:[Float]?) -> KMeansResult?{
        var n_cluster:UInt8 = n_cluster.toUInt8()
        
        let w = Int(inputImage.size.width.rounded())
        let h = Int(inputImage.size.height.rounded())
        let totalBytes = w * h * 1 // * 1 for 8 bit
        
        var intensities = inputImage.getPixelData()
        
        // get the unique intensity array
        let uniqueIntensity = Array(Set(intensities))
        
        let maxInter_cluster = 30
        let maxTrial_cluster = 10
        let eps:Float = 0.5
        let maxInter_kmeans = 20
        
        // insufficient unique pixel values
        if(uniqueIntensity.count <= n_cluster){
            Dialog.showDialog(message: "Cluster classification is not possible for this area due to intensity variation\ntarget cluster=\(n_cluster), unique pixels=\(uniqueIntensity.count)")
            return nil
        }
        
        var centers = [Float](repeating: 0, count: n_cluster.toInt())
        
        // if previous cluster centroids are available, use them as initial centers of this k-means itteration
        // if not, select the new cluster centers with k-means++
        if (initialCenters != nil){
            centers = initialCenters!
            n_cluster = centers.count.toUInt8()
            
        }else{
            var clusterTrialIterates = 0
            while (clusterTrialIterates <= maxTrial_cluster){
                print("Initial clustering; trial: \(clusterTrialIterates)")
                if(clusterTrialIterates == maxTrial_cluster){
                    Dialog.showDialog(message: "Failed to select the initial cluster centers")
                    print("centers:", centers)
                    return nil
                }
                
                //The first center value is at random
                centers = [Float](repeating: -1, count: n_cluster.toInt())// avoid same cluster
                centers[0] = intensities[Int.random(in: 0..<totalBytes)].toFloat()
                print(" The center for cluster 0 was selected at random: \(centers[0])")
                
                var c = 1
                
                while (c < n_cluster){
                    print(" * Cluster\(c) selection started")
    
                    // calculate the distance between center value and pixel value
                    let distances = intensities.map{(val) -> Float in
                        return (val.toFloat() - centers[c-1]) * (val.toFloat() - centers[c-1])
                    }
                    
                    // weighed probability
                    let sumOfDistances = distances.reduce(0, +)
                    let probabilities = distances.map { $0.toDouble() / sumOfDistances.toDouble() }
                    var cumulativeProbability = 0.0
                    var nextCenter:Int?
                    
                    while nextCenter == nil {
                        let randomProbability = Double.random(in: 0...1)
                        for (i, probability) in probabilities.enumerated() {
                            cumulativeProbability += probability
                            if cumulativeProbability >= randomProbability {
                                nextCenter = i
                                break
                            }
                        }
                    }
                    print("   Cluster\(c): center=\(intensities[nextCenter!])")
                    if(centers.contains(intensities[nextCenter!].toFloat())){
                        print("   Same center occured. \(centers)")
                        break
                    }else{
                        centers[c] = intensities[nextCenter!].toFloat()
                        c += 1
                    }
                }
                
                print("Loop finished.")
                if(centers.contains(-1)){
                    print("Error in selecting centers. retry.")
                    clusterTrialIterates += 1
                    continue
                }else{
                    print("Success: \(centers)")
                    break
                }
            }
        }
        print("Calculated centers: \(centers.sorted())")
        
        /// 各ピクセルが所属するクラスタ番号を格納
        /// cluster index for each pixel
        var rawClusterArray = [UInt8](repeating: 0, count: totalBytes)
        
        /// クラスタ番号を0-255にマッピングしたもの
        /// mapped cluster index to 0-255
        var clusterImageArray = [UInt8](repeating: 0, count: totalBytes)
        
        let initialCenters = centers.sorted()
        var calculatedClusterCentroids = initialCenters
        
        guard let computeFunction = lib.makeFunction(name: "calcKmeansCluster") else {
            Dialog.showDialog(message: "Error in creating Metal function: calcKmeansCluster")
            return nil
        }
        
        if(renderPipeline == nil){
            do{
                renderPipeline = try self.device.makeComputePipelineState(function: computeFunction)
            }catch{
                Dialog.showDialog(message: "Error in creating Metal pipeline: calcKmeansCluster")
                return nil
            }
        }
        
        for trial in 0..<maxInter_kmeans{
            let prevClusterCenters = calculatedClusterCentroids
            
            
            let cmdBuf = cmdQueue.makeCommandBuffer()!
            let computeKMeansClusterEncoder = cmdBuf.makeComputeCommandEncoder()!
            computeKMeansClusterEncoder.setComputePipelineState(renderPipeline)
            
            let options: MTLResourceOptions = [.storageModeShared, .cpuCacheModeWriteCombined]
            let outBufSize = MemoryLayout<UInt8>.stride * totalBytes
            let outputBuffer = device.makeBuffer(length: outBufSize, options: options)
            
            // raw clusterを0-255に合わせたもの
            let clusterImageBuffer = device.makeBuffer(length: outBufSize, options: options)
            
            // Buffer set
            let inputBuffer = device.makeBuffer(bytes: &intensities, length: MemoryLayout<UInt8>.stride * totalBytes)!
            
            inputBuffer.label = "input pixel array"
            outputBuffer?.label = "Output pixel buffer"
            
            computeKMeansClusterEncoder.setBuffer(inputBuffer, offset: 0, index: 0)
            
            var totalBytesUint = UInt(totalBytes)
            
            computeKMeansClusterEncoder.setBytes(&totalBytesUint, length: MemoryLayout<UInt>.stride, index: 1)
            computeKMeansClusterEncoder.setBytes(&calculatedClusterCentroids, length: MemoryLayout<Float>.stride * calculatedClusterCentroids.count, index: 2)
            computeKMeansClusterEncoder.setBytes(&n_cluster, length: MemoryLayout<UInt8>.stride, index: 3)
            computeKMeansClusterEncoder.setBuffer(outputBuffer, offset: 0, index: 4)
     
            /// pixel counts for each cluster
            let clusterCountsBuffer = device.makeBuffer(length: MemoryLayout<UInt32>.stride * calculatedClusterCentroids.count, options: options)
            clusterCountsBuffer?.label = "pixelCountBuffer"
            computeKMeansClusterEncoder.setBuffer(clusterCountsBuffer, offset: 0, index: 5)
            
            /// sum of pixel values for each cluster
            let clusterIntensityMBuffer = device.makeBuffer(length: MemoryLayout<UInt32>.stride * calculatedClusterCentroids.count, options: options)
            clusterIntensityMBuffer?.label = "SumOfIntensityBuffer"
            computeKMeansClusterEncoder.setBuffer(clusterIntensityMBuffer, offset: 0, index: 6)
            
            clusterImageBuffer?.label = "clusterImageBuffer"
            computeKMeansClusterEncoder.setBuffer(clusterImageBuffer, offset: 0, index: 7)
            
            // Compute optimization
            let count = totalBytes // 並列処理数はピクセル数と一致
            
            let maxTotalThreadsPerThreadgroup = renderPipeline.maxTotalThreadsPerThreadgroup
            let threadExecutionWidth          = renderPipeline.threadExecutionWidth // 32
            let width  = maxTotalThreadsPerThreadgroup / threadExecutionWidth * threadExecutionWidth
            let height = 1
            let depth  = 1
            let threadsPerThreadgroup = MTLSize(width: width, height: height, depth: depth) // MTLSize(width: 1024, height: 1, depth: 1)
            
            let threadgroupsPerGrid = MTLSize(width: (count + width - 1) / width, height: 1, depth: 1)
            
            // Dispatch
            computeKMeansClusterEncoder.dispatchThreadgroups(threadgroupsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
            computeKMeansClusterEncoder.endEncoding()
            cmdBuf.commit()
            cmdBuf.waitUntilCompleted()
            
            
            let outClusterCountsPtr = clusterCountsBuffer!.contents().bindMemory(to: UInt32.self, capacity: calculatedClusterCentroids.count )
            let clusterCountsArray = Array(UnsafeBufferPointer(start: outClusterCountsPtr, count:  calculatedClusterCentroids.count))

            
            let outClusterIntensitySumPtr = clusterIntensityMBuffer!.contents().bindMemory(to: UInt32.self, capacity: calculatedClusterCentroids.count )
            let clusterIntensitySumArray = Array(UnsafeBufferPointer(start: outClusterIntensitySumPtr, count:  calculatedClusterCentroids.count))
            
            // select the new cluster centers
            for c in 0..<n_cluster.toInt(){
                calculatedClusterCentroids[c] = Float(clusterIntensitySumArray[c]) / Float(clusterCountsArray[c])
            }
            
            var outofEPS = false
            
            for c in 0..<n_cluster.toInt(){
                if(abs(calculatedClusterCentroids[c] - prevClusterCenters[c]) > eps){
                    outofEPS = true
                }
            }
            
            // if error value are low or itteration had been done
            if(outofEPS == false || trial == maxInter_kmeans - 1){
                // finish the itteration
                // create the new centroids and clustered image (pixel array)
                
                let outPixelDataPtr = outputBuffer?.contents().bindMemory(to: UInt8.self, capacity: totalBytes )
                rawClusterArray = Array(UnsafeBufferPointer(start: outPixelDataPtr, count: totalBytes))
     
                let clusterImagePtr = clusterImageBuffer!.contents().bindMemory(to: UInt8.self, capacity: totalBytes )
                clusterImageArray = Array(UnsafeBufferPointer(start: clusterImagePtr, count:  totalBytes))
               
                break
            }
            
        }
        
        return KMeansResult(centers: initialCenters,
                            calculatedClusterCentroids: calculatedClusterCentroids,
                            clusters: rawClusterArray,
                            clusterImage: clusterImageArray)
        
    }
    
}
