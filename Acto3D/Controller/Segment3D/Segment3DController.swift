//
//  Segment3DController.swift
//  Acto3D
//
//  Created by Naoki Takeshita on 2023/01/05.
//

import Cocoa
import Metal
import simd


protocol Segment3DProtocol {
    func closeView(sender:NSViewController)
}

class Segment3DController: NSViewController {
    var currentSegmentNode = SegmentNode()
    var nodeList:[SegmentNode] = []
    
    var device : MTLDevice!
    var cmdQueue : MTLCommandQueue!
    var lib: MTLLibrary!
    
    
    var delegate: Segment3DProtocol?
    
    var renderer:SegmentRenderer!
    
    var mainView:ViewController?
    
    var kmeansController:KMeansController!
    
    
    
    @IBOutlet weak var sliderSlice: NSSlider!
    @IBOutlet weak var labelSlice: NSTextField!
    
    @IBOutlet weak var sliderZoom: NSSlider!
    @IBOutlet weak var labelZoom: NSTextField!
    
    @IBOutlet weak var outputView: SegmentRenderView!
    
    @IBOutlet weak var cropView1: SegmentRenderView!
    @IBOutlet weak var cropView2: SegmentRenderView!
    @IBOutlet weak var cropViewForCluster: SegmentRenderView!
    
    @IBOutlet weak var clusterCountField: NSTextField!
    @IBOutlet weak var stepperCluster: NSStepper!
    
    @IBOutlet weak var clusteredView: SegmentRenderView!
    @IBOutlet weak var maskViewForCluster: SegmentRenderView!
    
    @IBOutlet weak var sliderSegmentSlice: NSSlider!
    
    @IBOutlet weak var nodeTable: NSTableView!
    
    @IBOutlet weak var segmentFileName: NSTextField!
    @IBOutlet weak var channelSelectionPopup : NSPopUpButton!
    
    
    var workingDir:URL!
    var fileList:[String]!
    var fileType:FileType = .none
    
    var filePackage:FilePackage!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        
        sliderSlice.maxValue = (renderer.renderModelParams?.sliceMax.toFloat().toDouble())!
        sliderSlice.doubleValue = sliderSlice.maxValue / 2.0
        
        renderer.renderModelParams.sliceNo = sliderSlice.integerValue.toUInt16()
        renderer.channel = 0
        renderer.renderModelParams.scale = 1.0
        sliderZoom.floatValue = renderer.renderModelParams!.scale
        
        // set delegate
        outputView.view = self
        clusteredView.view = self
        
        nodeTable.delegate = self
        nodeTable.dataSource = self
        
        
        // these values are set to the same size as the input image in [prepare for segue]
        let viewWidth = renderer.imageParams.outputImageWidth
        let viewHeight = renderer.imageParams.outputImageHeight
        
        // view size should be square
        let viewSizeSquare = max(viewWidth, viewHeight)
        renderer.imageParams.outputImageWidth = viewSizeSquare
        renderer.imageParams.outputImageHeight = viewSizeSquare
        
        
        kmeansController = KMeansController(device: self.device, cmdQueue: self.cmdQueue, lib: self.lib)
        
        cropViewForCluster.forceDrawLine = true
        clusteredView.forceDrawLine = true
        maskViewForCluster.forceDrawLine = true
        clusteredView.linkViews = [cropViewForCluster, maskViewForCluster]
        
        
        // initial draw
        outputView.image = renderer.renderSlice()
    }
    
    
    @IBAction func sliderSliceChanged(_ sender: NSSlider) {
        labelSlice.integerValue = sender.integerValue
        
        labelSlice.sizeToFit()
        
        renderer?.renderModelParams?.sliceNo = sliderSlice.integerValue.toUInt16()
        
        
        outputView.image = renderer?.renderSlice()
        
        if(currentSegmentNode.cropArea != nil){
            guard let targetArea = outputView.confirmedArea?.standardized else {return}
            guard let currentImg = renderer.baseImage else {return}
            
            let scaleX = currentImg.width.toCGFloat() / outputView.bounds.width
            let scaleY = currentImg.height.toCGFloat() / outputView.bounds.height
            
            let scaledArea = targetArea.scaling(scaleX: scaleX, scaleY: scaleY)
            let croppedImg = currentImg.cropping(to: scaledArea)
            cropViewForCluster.image = croppedImg?.toNSImage
            
        }
        
        
    }
    
    @IBAction func sliderZoomChanged(_ sender: NSSlider) {
        labelZoom.stringValue = String(format: "%.2f", sender.floatValue)
        labelZoom.sizeToFit()

        
        renderer?.renderModelParams?.scale = sender.floatValue
        
        outputView.image = renderer?.renderSlice()
    }
    
    
    @IBAction func setSameQuatAsMain(_ sender: Any) {
        renderer.rotateModelTo(quaternion: mainView!.renderer.quaternion)
//        renderer.quaternion = mainView!.renderer.quaternion
//
//        renderer.normals.x = mainView!.normalX
//        renderer.normals.y = mainView!.normalY
//        renderer.normals.z = mainView!.normalZ
        
        
        
        outputView.image = renderer?.renderSlice()
    }
    
    override func keyDown(with event: NSEvent) {
        print(event)
    
        switch event.keyCode {
        case 123: // left
            renderer.renderModelParams.translationX += 10
            outputView.image = renderer?.renderSlice()
            break
            
        case 124: // →
            renderer.renderModelParams.translationX -= 10
            outputView.image = renderer?.renderSlice()
            break
            
        case 125: // ↓
            renderer.renderModelParams.translationY -= 10
            outputView.image = renderer?.renderSlice()
            break
            
        case 126: // ↑
            renderer.renderModelParams.translationY += 10
            outputView.image = renderer?.renderSlice()
            break
            
        default:
            break
        }
        
    }
    
    
    @IBAction func preProcessForTexture(_ sender: Any) {
        if(renderer.channel == 4){
            Dialog.showDialog(message: "Already processed or no input image")
            return
        }
        
        let processor = ImageProcessor(device: self.device, cmdQueue: self.cmdQueue, lib: self.lib)
        
        var inProgress = true
        // overlay
        let contentView = self.view
        let overlayView = NonClickableNSView(frame: contentView.frame)
        overlayView.wantsLayer = true
        overlayView.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.7).cgColor
        
        let progressIndicator = NSProgressIndicator(frame: NSRect(x: 0, y: 0, width: 160, height: 40))
        progressIndicator.style = .bar
        progressIndicator.minValue = 0
        progressIndicator.maxValue = 100
        progressIndicator.doubleValue = 0 // Set the current progress
        progressIndicator.isIndeterminate = false
        progressIndicator.frame.origin.x = (contentView.frame.width - progressIndicator.frame.width) / 2
        progressIndicator.frame.origin.y = (contentView.frame.height - progressIndicator.frame.height) / 2
        
        let button = ImageProcessorCancelButton(title: "Cancel", target: nil, action: nil)
        button.bezelStyle = .rounded
        button.wantsLayer = true
        button.sizeToFit()
        button.action = #selector(imageProcessSendCancel(_:))
        button.processor = processor
        button.frame.origin.x = (contentView.frame.width - button.frame.width) / 2
        button.frame.origin.y = (contentView.frame.height - button.frame.height) / 2 - progressIndicator.bounds.height - 10
        button.layer?.backgroundColor = CGColor.clear
        
        overlayView.addSubview(progressIndicator)
        contentView.addSubview(overlayView, positioned: .above, relativeTo: nil)
        overlayView.addSubview(button)
        
        
        DispatchQueue.global().async {
            processor.applyFilter_Gaussian3D(inTexture: self.renderer.mainTexture!, k_size: 7, channel: self.renderer.channel.toInt()){ result in
                DispatchQueue.main.async {
                    if(processor.isCanceled() == false){
                        if let result = result{
                            self.renderer.preProcessedTexture = result
                            self.channelSelectionPopup.selectItem(at: 4)
                            self.renderer.channel = 4
                            self.outputView.image = self.renderer.renderSlice()
                        } else {
                            Dialog.showDialog(message: "Error in calculating pre-process")
                        }
                    }
                    inProgress = false
                    overlayView.removeFromSuperview()
                }
            }
            
            while(inProgress){
                let progress = processor.getProcessState()
                
                DispatchQueue.main.async {
                    progressIndicator.doubleValue = progress.percentage
                    
                }
                usleep(400)
            }
        }
        
        
        
    }
    
    @objc func imageProcessSendCancel(_ sender: ImageProcessorCancelButton) {
        print("Send Cancel message")
        sender.processor?.interruptProcess()
    }
    
    
    @IBAction func setSlice1(_ sender: Any) {
        guard let targetArea = outputView.confirmedArea?.standardized else {return}
        
        guard let currentImg = renderer.baseImage else {return} // squared image
        
        let scaleX = currentImg.width.toCGFloat() / outputView.bounds.width
        let scaleY = currentImg.height.toCGFloat() / outputView.bounds.height
        // scaleX = scaleY
        
        let scaledArea = targetArea.scaling(scaleX: scaleX, scaleY: scaleY)
        let croppedImg = currentImg.cropping(to: scaledArea)
        cropView1.image = croppedImg?.toNSImage
        
        currentSegmentNode.startSliceNo = sliderSlice.integerValue
        currentSegmentNode.quaternion = renderer.quaternion
        
        currentSegmentNode.prepareContainer()
        currentSegmentNode.renderModelParams = self.renderer.renderModelParams
        
        sliderSegmentSlice.maxValue = (currentSegmentNode.sliceCount - 1).toDouble()
    }
    
    @IBAction func setSlice2(_ sender: Any) {
        guard let targetArea = outputView.confirmedArea?.standardized else {return}
        
        guard let currentImg = renderer.baseImage else {return} // squared image
        
        let scaleX = currentImg.width.toCGFloat() / outputView.bounds.width
        let scaleY = currentImg.height.toCGFloat() / outputView.bounds.height
        // scaleX = scaleY
        
        let scaledArea = targetArea.scaling(scaleX: scaleX, scaleY: scaleY)
        let croppedImg = currentImg.cropping(to: scaledArea)
        cropView2.image = croppedImg?.toNSImage
        
        currentSegmentNode.endSliceNo = sliderSlice.integerValue
        currentSegmentNode.quaternion = renderer.quaternion
        
        currentSegmentNode.prepareContainer()
        currentSegmentNode.renderModelParams = self.renderer.renderModelParams
        
        sliderSegmentSlice.maxValue = (currentSegmentNode.sliceCount - 1).toDouble()
    }
    
    @IBAction func clusterCountFieldChanged(_ sender: Any) {
        stepperCluster.integerValue = clusterCountField.integerValue
    }
    @IBAction func clusterCountStepperChanged(_ sender: NSStepper) {
        clusterCountField.integerValue = stepperCluster.integerValue
    }
    
    /// Re-calculate k-means cluster for current image.
    @IBAction func clusterImageRefresh(_ sender: Any) {
        guard let currentImage = cropViewForCluster.image?.toCGImage else {
            return
        }
        
        guard let kmeansResult = kmeansController.calculateKmeans(inputImage: currentImage, n_cluster: stepperCluster.integerValue, initialCenters: nil)
        else{
            Dialog.showDialog(message: "Could not calculate k-means++")
            return
        }
        
        let _w = Int(currentImage.size.width.rounded())
        let _h = Int(currentImage.size.height.rounded())
        
        guard let clusterCGImage = create8bitImage(pixelArray: kmeansResult.clusterImage, width: _w, height: _h) else {return}
        clusteredView.image = clusterCGImage.toNSImage
        currentSegmentNode.currentKMeansResult = kmeansResult
    }

    @IBAction func gotoFirstSlice(_ sender: Any) {
        guard let startSliceNo = currentSegmentNode.startSliceNo else {
            Dialog.showDialog(message: "Set the target slices first")
            return
        }
        
        labelSlice.integerValue = startSliceNo
        labelSlice.sizeToFit()
        sliderSlice.integerValue = startSliceNo
        
        renderer?.renderModelParams?.sliceNo = sliderSlice.integerValue.toUInt16()
        outputView.image = renderer?.renderSlice()
        
        currentSegmentNode.currentSliceNo = startSliceNo
        
        guard let targetArea = outputView.confirmedArea?.standardized else {return}
        
        guard let currentImg = renderer.baseImage else {return}
        let scaleX = currentImg.width.toCGFloat() / outputView.bounds.width
        let scaleY = currentImg.height.toCGFloat() / outputView.bounds.height
        
        let scaledArea = targetArea.scaling(scaleX: scaleX, scaleY: scaleY)
        let croppedImg = currentImg.cropping(to: scaledArea)
        cropViewForCluster.image = croppedImg?.toNSImage
    }
    
    @IBAction func gotoEndSlice(_ sender: Any) {
        guard let endSliceNo = currentSegmentNode.endSliceNo else {
            Dialog.showDialog(message: "Set the target slices first")
            return
        }
        
        labelSlice.integerValue = endSliceNo
        labelSlice.sizeToFit()
        sliderSlice.integerValue = endSliceNo
        renderer?.renderModelParams?.sliceNo = sliderSlice.integerValue.toUInt16()
        outputView.image = renderer?.renderSlice()
        currentSegmentNode.currentSliceNo = endSliceNo
        
        guard let targetArea = outputView.confirmedArea?.standardized else {return}
        
        guard let currentImg = renderer.baseImage else {return}
        let scaleX = currentImg.width.toCGFloat() / outputView.bounds.width
        let scaleY = currentImg.height.toCGFloat() / outputView.bounds.height
        
        let scaledArea = targetArea.scaling(scaleX: scaleX, scaleY: scaleY)
        let croppedImg = currentImg.cropping(to: scaledArea)
        cropViewForCluster.image = croppedImg?.toNSImage
    }
    
    /// Crop the base image to specific area, calculate k-means, create mask image
    func createMaskForSlice(sliceNo: Int) -> (croppedImage:CGImage, clusteredImage:CGImage, maskImage:CGImage)?{
        let index = currentSegmentNode.indexForSlice(slice: sliceNo)
        // set texture for specific sliceNo to SegmentRenderer
        renderer?.renderModelParams?.sliceNo = sliceNo.toUInt16()
        _ = renderer.renderSlice()
            
        // crop領域部分の次スライスの画像を取得
        guard let cropArea = currentSegmentNode.cropArea else {return nil}
        guard let currentImg = renderer.baseImage else {return nil}
        
        var scaleX:CGFloat = 0
        var scaleY:CGFloat = 0
        
        if Thread.isMainThread {
            scaleX = currentImg.width.toCGFloat() / outputView.bounds.width
            scaleY = currentImg.height.toCGFloat() / outputView.bounds.height
        }else{
            DispatchQueue.main.sync {
                scaleX = currentImg.width.toCGFloat() / outputView.bounds.width
                scaleY = currentImg.height.toCGFloat() / outputView.bounds.height
            }
        }
         
        
        let scaledArea = cropArea.scaling(scaleX: scaleX, scaleY: scaleY)
        
        guard let croppedImg = currentImg.cropping(to: scaledArea) else {return nil}
        
//        let croppedImageForCurrentSlice = croppedImg.toNSImage
        
//        cropViewForCurrentSlice.image = croppedImg.toNSImage
        
        
        //MARK: Rules for creating mask images:
        // 1. If a cluster center is already set for the current index being processed, use that.
        // 2. If not, use the calculated cluster centroids from the previous index.
        // Note: To support changes to the number of clusters during processing,
        // determine the number of clusters based on the count of cluster centers.

        var centers:[Float]
        if(currentSegmentNode.clusterCenters[index] != [nil]){
            centers = currentSegmentNode.clusterCenters[index].map{Float($0!)}
            
        }else{
            if index == 0{
                centers = currentSegmentNode.initialClusterCenters.map{Float($0)}
            }else{
                if(currentSegmentNode.clusterCentroids[index - 1] != [nil]){
                    centers = currentSegmentNode.clusterCentroids[index - 1].map{Float($0!)}
                }else{
                    Dialog.showDialog(message: "Provide initial centers or previous centroids first.")
                    return nil
                }
            }
        }
        
        guard let kmeansResult = kmeansController.calculateKmeans(inputImage: croppedImg, n_cluster: centers.count, initialCenters: centers)
        else{
            Dialog.showDialog(message: "Could not perform k-means++ or k-menas.")
            return nil
        }
        
        currentSegmentNode.clusterCenters[index] = kmeansResult.centers
        currentSegmentNode.clusterCentroids[index] = kmeansResult.calculatedClusterCentroids
        
        
        let _w = Int(croppedImg.size.width.rounded())
        let _h = Int(croppedImg.size.height.rounded())
        let totalBytes = _w * _h
        
//        var intensities = kmeansResult.clusters.map{(val) -> UInt8 in
//            return 255 / stepperCluster.integerValue.toUInt8() * val
//        }
        
        guard let providerRef = CGDataProvider(data: Data(bytes: kmeansResult.clusterImage, count: totalBytes) as CFData) else{return nil}
        
        guard let clusteredCgImage = CGImage(
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
        else {return nil}
        
//        clusterView.image = clusteredCgImage.toNSImage
        
        if Thread.isMainThread {
            scaleX = clusteredCgImage.width.toCGFloat() / maskViewForCluster.bounds.width
            scaleY = clusteredCgImage.height.toCGFloat() / maskViewForCluster.bounds.height
        }else{
            DispatchQueue.main.sync {
                scaleX = clusteredCgImage.width.toCGFloat() / maskViewForCluster.bounds.width
                scaleY = clusteredCgImage.height.toCGFloat() / maskViewForCluster.bounds.height
            }
        }
        let scale = max(scaleX, scaleY)

        
        // Fill in the target points of clustered images.
        // - The coordinates to be filled in for the first slice are the points specified by the mouse.
        // - For subsequent slices, use the moment calculated from the previous slice image.
        // - If the user specifies the fill-in coordinates individually, prioritize that.
        var point = CGPoint()
        if(index == 0){
            point = currentSegmentNode.point[0] ?? CGPoint(x: 0, y: 0)
        }else{
            point = currentSegmentNode.moment[index - 1] ?? CGPoint(x: 0, y: 0)
        }
        
        
        //MARK: 20240812 check
        point = currentSegmentNode.point[index] ?? point
//        if(currentSegmentNode.point[index] != nil){
//            point = currentSegmentNode.point[index]!
//        }
        
        /// Mask image created by filling the specific point
        guard let fillResult = clusteredCgImage.fill(in: point).image else {
            Dialog.showDialog(message: "Error in filling the point")
            return nil
        }
        guard let momentResult = fillResult.calcMoment(device: device, cmdQueue: cmdQueue, lib: lib) else{
            Dialog.showDialog(message: "Error in calculating moments")
            return nil
        }
        
        currentSegmentNode.moment[index] = momentResult.moment
        currentSegmentNode.maskImage[index] = fillResult
        
        if (currentSegmentNode.point[index] == nil){
            clusteredView.marker = momentResult.moment.scaling(scaleX: 1/scale, scaleY: 1/scale)
        }else{
            clusteredView.marker = currentSegmentNode.point[index]!.scaling(scaleX: 1/scale, scaleY: 1/scale)
        }
        
        return (croppedImg, clusteredCgImage, fillResult)
//        clusterSelectedView.image = fillResult?.toNSImage
//        clusterView.redraw()
    }
    
    @IBAction func nextSlice(_ sender: Any) {
        if(currentSegmentNode.currentSliceNo == nil){
            currentSegmentNode.currentSliceNo = currentSegmentNode.startSliceNo
        }
        guard let currentSlice = currentSegmentNode.currentSliceNo else {return}
        
        let currentSliceIndex = currentSegmentNode.indexForSlice(slice: currentSlice)
        
        if(currentSlice == currentSegmentNode.endSliceNo!){
            print("out of range")
            return
        }
        
        let nextSlice = currentSegmentNode.goToNextSlice()
        let index = currentSegmentNode.indexForSlice(slice: nextSlice)
        
        print("Slice: \(currentSlice) -> \(nextSlice), index=\(index-1) -> \(index)")
        
        labelSlice.integerValue = nextSlice
        labelSlice.sizeToFit()
        sliderSlice.integerValue = nextSlice
        sliderSegmentSlice.integerValue = currentSliceIndex + 1
        renderer?.renderModelParams?.sliceNo = sliderSlice.integerValue.toUInt16()
        
//        DispatchQueue.main.sync {[self] in
            outputView.image = renderer?.renderSlice()
//        }
        guard let maskParams = createMaskForSlice(sliceNo: nextSlice) else {
            Dialog.showDialog(message: "Error in creating mask image")
            return
        }
        cropViewForCluster.image = maskParams.croppedImage.toNSImage
        clusteredView.image = maskParams.clusteredImage.toNSImage
        maskViewForCluster.image = maskParams.maskImage.toNSImage
        
        // The following code is necessary for calculating the DICE loss
        // between the previous mask image and the current created mask image.
        if let prevPixelData = currentSegmentNode.maskImage[index - 1]?.getPixelData(),
           let currentPixelData = currentSegmentNode.maskImage[index]?.getPixelData()
        {
            print("Dice: ", calcDiceCoeff(pixel1: prevPixelData, pixel2: currentPixelData))
        }
        
        
        //MARK: for paper figure
        // for create paper figure, export images
        /*
        guard let tmpDir = filePackage.tmpDir else{
            return
        }
        let filename = "-\(String(format: "%03d", index-1)).tif"
        
        let orgImage = cropViewForCurrentSlice.image
        let clusterImage = clusterView.image
        let maskImage = clusterSelectedView.image
        
        let orgFileUrl = tmpDir.appendingPathComponent("org"+filename)
        let clsFileUrl = tmpDir.appendingPathComponent("cls"+filename)
        let mskFileUrl = tmpDir.appendingPathComponent("msk"+filename)
        
        if let tiff = orgImage?.tiffRepresentation,
           let imgRep = NSBitmapImageRep(data: tiff),
           let tiffData = imgRep.representation(using: .tiff, properties: [:]){
            
            do {
                try tiffData.write(to: orgFileUrl)
            }catch{
                print("error")
            }
        }
        
        if let tiff = clusterImage?.tiffRepresentation,
           let imgRep = NSBitmapImageRep(data: tiff),
           let tiffData = imgRep.representation(using: .tiff, properties: [:]){
            
            do {
                try tiffData.write(to: clsFileUrl)
            }catch{
                print("error")
            }
        }
        
        if let tiff = maskImage?.tiffRepresentation,
           let imgRep = NSBitmapImageRep(data: tiff),
           let tiffData = imgRep.representation(using: .tiff, properties: [:]){
            
            do {
                try tiffData.write(to: mskFileUrl)
            }catch{
                print("error")
            }
        }
         */
    }
    
    @IBAction func prevSlice(_ sender: Any) {
        if(currentSegmentNode.currentSliceNo == nil){
            currentSegmentNode.currentSliceNo = currentSegmentNode.startSliceNo
        }
        guard let currentSlice = currentSegmentNode.currentSliceNo
        else{
            return
        }
        let currentSliceIndex = currentSegmentNode.indexForSlice(slice: currentSlice)
        
        if(currentSlice == currentSegmentNode.startSliceNo!){
            print("out of range")
            return
        }
        
        let nextSlice = currentSegmentNode.goToPrevSlice()
        let index = currentSegmentNode.indexForSlice(slice: nextSlice)
        
        print("Slice: \(currentSlice) -> \(nextSlice), index=\(index+1) -> \(index)")
        
        labelSlice.integerValue = nextSlice
        labelSlice.sizeToFit()
        sliderSlice.integerValue = nextSlice
        sliderSegmentSlice.integerValue = currentSliceIndex - 1
        renderer?.renderModelParams?.sliceNo = sliderSlice.integerValue.toUInt16()
        outputView.image = renderer?.renderSlice()
        
        guard let maskParams = createMaskForSlice(sliceNo: nextSlice) else {
            Dialog.showDialog(message: "Error in creating mask image")
            return
        }
        cropViewForCluster.image = maskParams.croppedImage.toNSImage
        clusteredView.image = maskParams.clusteredImage.toNSImage
        maskViewForCluster.image = maskParams.maskImage.toNSImage

    }
    
    
    
    
    //MARK: - Applies k-means clustering iteratively starting from the specified slice
    @IBAction func createMaskSequenceFromStart(_ sender: Any) {
        if currentSegmentNode.isValid == false {return}
        iterateKMeansClusteringFrom(index: 0)
    }
    
    @IBAction func createMaskSequenceFromSelectedIndex(_ sender: Any) {
        if currentSegmentNode.isValid == false {return}
        print("sliderSegmentSlice.integerValue", sliderSegmentSlice.integerValue)
        iterateKMeansClusteringFrom(index: sliderSegmentSlice.integerValue)
    }
    
    /// Applies k-means clustering iteratively starting from the specified slice.
    /// For each clustered slice image, it fills in the specified points to create a mask image.
    /// If the mask image significantly deviates from the mask of the previous slice (using DICE error),
    /// manual verification is recommended.
    func iterateKMeansClusteringFrom(index:Int){
        if(currentSegmentNode.isValid == false) {return}
        
        guard let endSliceNo = currentSegmentNode.endSliceNo else{return}
        
        let startIndex = index
        let startSliceNo = currentSegmentNode.sliceForIndex(index: startIndex)
        let endIndex = currentSegmentNode.indexForSlice(slice: endSliceNo)
        
        print("start: \(startSliceNo), end: \(endSliceNo) = index: \(startIndex) > \(endIndex)")
        
        currentSegmentNode.currentSliceNo = startSliceNo
        sliderSegmentSlice.integerValue = startIndex
        
        
        var shouldExitLoop = false // flag for stopping loop
        
        if(startIndex == 0){
            // If starting from the first slice in Nodes,
            // initial cluster centers must be provided.
            if(currentSegmentNode.clusterCenters[0] == [nil]){
                Dialog.showDialog(message: "Provide initial cluster first")
                return
            }
        }else{
            // For slices other than the first, either initial cluster centers or the centroids from the previous slice must be provided.
            if(currentSegmentNode.clusterCenters[startIndex] == [nil] &&
               currentSegmentNode.clusterCentroids[startIndex - 1] == [nil]){
                Dialog.showDialog(message: "Provide initial centers or previous centroids first.\nThis can be resolved by applying clustering to the current slice and specifying the structure of interest.")
                return
            }
        }
        
        
        DispatchQueue.global(qos: .userInteractive).async{ [self] in
            
            autoreleasepool{
                for _ in (startIndex + 1)...endIndex{
                    if shouldExitLoop {
                        break
                    }
                    
                    guard let currentSlice = currentSegmentNode.currentSliceNo else {return}
                    let currentSliceIndex = currentSegmentNode.indexForSlice(slice: currentSlice)
                    
                    if(currentSlice == currentSegmentNode.endSliceNo!){
                        print("out of range")
                        shouldExitLoop = true
                        return
                    }
                    
                    let nextSlice = currentSegmentNode.goToNextSlice()
                    let index = currentSegmentNode.indexForSlice(slice: nextSlice)
                    
                    print("Slice: \(currentSlice) -> \(nextSlice), index=\(index-1) -> \(index)")
                    
                    DispatchQueue.main.sync {
                        labelSlice.integerValue = nextSlice
                        labelSlice.sizeToFit()
                        sliderSlice.integerValue = nextSlice
                        sliderSegmentSlice.integerValue = currentSliceIndex + 1
                        renderer?.renderModelParams?.sliceNo = sliderSlice.integerValue.toUInt16()
                        outputView.image = renderer?.renderSlice()
                    }
                    
                    guard let maskParams = createMaskForSlice(sliceNo: nextSlice) else {
                        Dialog.showDialog(message: "Error in creating mask image")
                        shouldExitLoop = true
                        return
                    }
                    
                    DispatchQueue.main.sync {
                        cropViewForCluster.image = maskParams.croppedImage.toNSImage
                        clusteredView.image = maskParams.clusteredImage.toNSImage
                        maskViewForCluster.image = maskParams.maskImage.toNSImage
                        
                        // The following code is necessary for calculating the DICE loss
                        // between the previous mask image and the current created mask image.
                        if let prevPixelData = currentSegmentNode.maskImage[index - 1]?.getPixelData(),
                           let currentPixelData = currentSegmentNode.maskImage[index]?.getPixelData()
                        {
                            let dice = calcDiceCoeff(pixel1: prevPixelData, pixel2: currentPixelData)
                            print("Dice: ", calcDiceCoeff(pixel1: prevPixelData, pixel2: currentPixelData))
                            if(dice <= 0.80){
                                Dialog.showDialog(message: "The automatic processing was interrupted due to significant changes in the mask image. Please ensure it's the correct clustering mask image and process it manually.", title: "", style: .informational)
                                shouldExitLoop = true
                                return
                            }
                        }
                    }
                    
                }
                
                
            }
        }
    }
    //MARK: -
    
    
    
    @IBAction func sliderSegmentElement(_ sender: Any) {
        if(currentSegmentNode.isValid){
            showSegmentNodeSlice(node: currentSegmentNode, index: sliderSegmentSlice.integerValue)
        }
    }
    
    @IBAction func deleteNodeElementAfter(_ sender: Any) {
        currentSegmentNode.removeElementAfter(index: currentSegmentNode.indexForSlice(slice: currentSegmentNode.currentSliceNo))
        
        clusteredView.image = nil
        maskViewForCluster.image = nil
    }
    
    @IBAction func deleteCurrentSlice(_ sender: Any) {
        let index = currentSegmentNode.indexForSlice(slice: currentSegmentNode.currentSliceNo)
        currentSegmentNode.removeElement(for: index)
        
        clusteredView.image = nil
        maskViewForCluster.image = nil
    }
    
    
    /// Apply segment node elements to views
    func showSegmentNodeSlice(node: SegmentNode, index: Int){
        let sliceNo = node.sliceForIndex(index: index)
        
        if(node.maskImage[index] == nil){
            // Mask image is not yet set.
            clusteredView.image = nil
            maskViewForCluster.image = nil
            
        }else{
            maskViewForCluster.image = node.maskImage[index]!.toNSImage
        }
        
        // crop領域部分の画像を表示
        let cropArea = node.cropArea!
        outputView.confirmedArea = cropArea
        
        self.renderer.renderModelParams = node.renderModelParams
        self.renderer.rotateModelTo(quaternion: node.quaternion)
        self.renderer.renderModelParams.sliceNo = sliderSlice.integerValue.toUInt16()
        
        outputView.image = renderer.renderSlice()
        
        guard let currentImg = renderer.baseImage else {
            print("renderer.baseImage nil")
            return
        }
        
        let scaleX = currentImg.width.toCGFloat() / outputView.bounds.width
        let scaleY = currentImg.height.toCGFloat() / outputView.bounds.height
        
        let scaledArea = cropArea.scaling(scaleX: scaleX, scaleY: scaleY)
        let croppedImg = currentImg.cropping(to: scaledArea)
        
        cropViewForCluster.image = croppedImg?.toNSImage
        
        // use the centers if provided
        // if not, use the previous centroids
        if(node.clusterCenters[index] != [nil]){
            
            print("initial centers for index:\(index)", node.clusterCenters[index])
            
            guard let kmeansResult = kmeansController.calculateKmeans(inputImage: croppedImg!,
                                                                      n_cluster: node.clusterCenters[index].count,
                                                                      initialCenters: node.clusterCenters[index].map{Float($0!)})
            else{
                Dialog.showDialog(message: "Could not calculate k-means++/k-means")
                return
            }
        
            let clusterCGImage = create8bitImage(pixelArray: kmeansResult.clusterImage, width: node.width!, height: node.height!)
            
            clusteredView.image = clusterCGImage?.toNSImage
        }else{
            if(index > 0 && node.clusterCentroids[index - 1] != [nil]){
                let prevCentroids = node.clusterCentroids[index-1]
                print("use previoud centroids for index:\(index)", prevCentroids)
                
                guard let kmeansResult = kmeansController.calculateKmeans(inputImage: croppedImg!,
                                                                          n_cluster: prevCentroids.count,
                                                                          initialCenters: prevCentroids.map{Float($0!)})
                else{
                    Dialog.showDialog(message: "Could not calculate k-means++/k-means")
                    return
                }
            
                let clusterCGImage = create8bitImage(pixelArray: kmeansResult.clusterImage, width: node.width!, height: node.height!)
                
                clusteredView.image = clusterCGImage?.toNSImage
                
            }
        }
        
        
        currentSegmentNode = node
        currentSegmentNode.currentSliceNo = sliceNo
        
        
        labelSlice.integerValue = sliceNo
        labelSlice.sizeToFit()
        sliderSlice.integerValue = sliceNo
        
        
        
    }
    
    /// Creates a mask texture from a `SegmentNode`.
    /// Transfers the pixel data from the `SegmentNode` to create a texture.
    /// After the texture is created, it is merged into the base image.
    /// Returns `true` if the process completes successfully.
    private func createMaskTexture(node: SegmentNode) -> Bool{
        if node.isValid == false {return false}
        
        guard let _w = node.width,
              let _h = node.height else {return false}
        
        let sliceCount = node.sliceCount

        let pxCountPerSlice = _w * _h
        
        // mask texture setting
        let textureDescriptor = MTLTextureDescriptor()
        textureDescriptor.pixelFormat = MTLPixelFormat.r8Unorm
        textureDescriptor.textureType = .type3D
        textureDescriptor.width = _w
        textureDescriptor.height = _h
        textureDescriptor.depth = sliceCount
        textureDescriptor.allowGPUOptimizedContents = true
        
        textureDescriptor.usage = [.shaderRead, .shaderWrite]
        textureDescriptor.storageMode = .private
        
        let maskTexture = self.device.makeTexture(descriptor: textureDescriptor)!
        
        let bufSize = MemoryLayout<UInt8>.stride * pxCountPerSlice * sliceCount
        let options: MTLResourceOptions = [.storageModeShared, .cpuCacheModeWriteCombined ]
        
        let maskBuffer = self.device.makeBuffer(length: bufSize, options: options)
        let maskBufferPtr = maskBuffer!.contents().bindMemory(to: UInt8.self, capacity: bufSize)
        
        
        for z in 0..<node.sliceCount{
            if(node.maskImage[z] == nil){
                // zero
                memset(&maskBufferPtr[_w * _h * z], 0, _w * _h)
            }else{
                memmove(&maskBufferPtr[_w * _h * z], node.maskImage[z]!.getPixelData(), _w * _h)
            }
        }
        
        var cmdBuf = cmdQueue.makeCommandBuffer()!
        let encoder = cmdBuf.makeBlitCommandEncoder()!
        
        encoder.copy(from: maskBuffer!, sourceOffset: 0,
                     sourceBytesPerRow: _w,
                     sourceBytesPerImage: _w * _h,
                     sourceSize: MTLSize(width: _w,
                                         height: _h,
                                         depth: sliceCount),
                     to: maskTexture,
                     destinationSlice: 0, destinationLevel: 0, destinationOrigin: MTLOrigin(x: 0, y: 0, z: 0))
        
        encoder.endEncoding()
        cmdBuf.commit()
        
        // -------------------------
        
        guard let computeFunction = lib.makeFunction(name: "createMaskTexture3D") else {
            print("error make function")
            return false
        }
        var renderPipeline: MTLComputePipelineState!
        
        renderPipeline = try? self.device.makeComputePipelineState(function: computeFunction)
        
        cmdBuf = cmdQueue.makeCommandBuffer()!
        
        let computeMakeMaskEncoder = cmdBuf.makeComputeCommandEncoder()!
        computeMakeMaskEncoder.setComputePipelineState(renderPipeline)
        
        var passSliceNo = node.startSliceNo!.toUInt16()
 
        let passPoint = node.cropArea.origin //.scaling(scaleX: scale, scaleY: scale)
        
        var passRectLeft = UInt16(passPoint.x.rounded())
        var passRectTop = UInt16(passPoint.y.rounded())
    
        print("rect org pos", passRectLeft, passRectTop)

        
        computeMakeMaskEncoder.setBytes(&renderer.imageParams!, length: MemoryLayout<VolumeData>.stride, index: 0)
        var renderModelParams = node.renderModelParams!
        computeMakeMaskEncoder.setBytes(&renderModelParams, length: MemoryLayout<RenderingParameters>.stride, index: 1)
        computeMakeMaskEncoder.setBytes(&passSliceNo, length: MemoryLayout<UInt16>.stride, index: 2)
        var quaternion = node.quaternion!
        computeMakeMaskEncoder.setBytes(&quaternion, length: MemoryLayout<simd_quatf>.stride, index: 3)
        computeMakeMaskEncoder.setBytes(&passRectLeft, length: MemoryLayout<UInt16>.stride, index: 4)
        computeMakeMaskEncoder.setBytes(&passRectTop, length: MemoryLayout<UInt16>.stride, index: 5)
        
        
        let viewScaleW = outputView.frame.width / renderer.imageParams.outputImageWidth.toCGFloat()
        let viewScaleH = outputView.frame.height / renderer.imageParams.outputImageHeight.toCGFloat()
        var viewScale = Float(min(viewScaleW, viewScaleH))
        
        
        computeMakeMaskEncoder.setBytes(&viewScale, length: MemoryLayout<Float>.stride, index: 6)
        
        var frameWidth = outputView.frame.width.toFloat()
        var frameHeight = outputView.frame.height.toFloat()
        
        computeMakeMaskEncoder.setBytes(&frameWidth, length: MemoryLayout<Float>.stride, index: 7)
        computeMakeMaskEncoder.setBytes(&frameHeight, length: MemoryLayout<Float>.stride, index: 8)
        
        // z: positive direction=0, negative direction=1
        var sliceDir:UInt8 = 0
        if(node.endSliceNo! > node.startSliceNo!){
            sliceDir = 0
        }else{
            sliceDir = 1
        }
        computeMakeMaskEncoder.setBytes(&sliceDir, length: MemoryLayout<UInt8>.stride, index: 9)
        
        computeMakeMaskEncoder.setTexture(maskTexture, index: 0)
        
        // Sampler Set
        var sampler: MTLSamplerState!
        let samplerDescriptor = MTLSamplerDescriptor()
        samplerDescriptor.sAddressMode = .clampToZero
        samplerDescriptor.tAddressMode = .clampToZero
        samplerDescriptor.minFilter = .linear
        samplerDescriptor.magFilter = .linear
        sampler = device.makeSamplerState(descriptor: samplerDescriptor)
        
        computeMakeMaskEncoder.setSamplerState(sampler, index: 0)
        
        // If mask texture has already been set, use it, otherwise create.
        if (renderer.maskTexture == nil){
            renderer.initMaskTexture()
        }
        computeMakeMaskEncoder.setTexture(renderer.maskTexture!, index: 1)
            
        
        // Compute optimization
        let xCount = _w
        let yCount = _h
        let zCount = sliceCount
        let maxTotalThreadsPerThreadgroup = renderPipeline.maxTotalThreadsPerThreadgroup
        let threadExecutionWidth          = renderPipeline.threadExecutionWidth
        let width  = threadExecutionWidth
        let height = 8
        let depth  = maxTotalThreadsPerThreadgroup / width / height
        let threadsPerThreadgroup = MTLSize(width: width, height: height, depth: depth)
        let threadgroupsPerGrid = MTLSize(width: (xCount + width - 1) / width,
                                          height: (yCount + height - 1) / height,
                                          depth: (zCount + depth - 1) / depth)
        
        // Metal Dispatch
        computeMakeMaskEncoder.dispatchThreadgroups(threadgroupsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
        computeMakeMaskEncoder.endEncoding()
        
        cmdBuf.commit()
        cmdBuf.waitUntilCompleted()
        
        return true
    }
    
    @IBAction func applyMaskToTexture(_ sender: Any) {
        if createMaskTexture(node: currentSegmentNode) == true{
            // after the mask texture is created, add the node setting to the list
            nodeList.append(currentSegmentNode)
            
            currentSegmentNode = SegmentNode()
            cropView1.image = nil
            cropView2.image = nil
            
            cropViewForCluster.image = nil
            clusteredView.image = nil
            maskViewForCluster.image = nil
            
            sliderSegmentSlice.integerValue = 0
            sliderSegmentSlice.maxValue = 0
            
            nodeTable.reloadData()

        }
    }
    
    /// Combine all nodes to create a new mask texture
    @IBAction func mergeNodesIntoTexture(_ sender: Any) {
        renderer.initMaskTexture()
        
        for node in nodeList{
            _ = createMaskTexture(node: node)
        }
        
        outputView.image = renderer.renderSlice()
    }
    
    @IBAction func removeSelectedNode(_ sender: Any) {
        // nodeTable.selectedRow will be '-1' when unselected
        if(nodeTable.selectedRow >= 0){
            nodeList.remove(at: nodeTable.selectedRow)
            nodeTable.reloadData()
        }
    }
    
    @IBAction func saveNodeToFile(_ sender: Any) {
        guard var segmentDir = filePackage.segmentDir else{
            Dialog.showDialog(message: "Cannot create directory for segment")
            return
        }
        
        if(segmentFileName.stringValue == ""){
            let fileStamp = NSDate().timeStampYYYYMMDDHHMMSS()
            
            segmentDir = segmentDir.appendingPathComponent("\(fileStamp).json")
            
        }else{
            if (!segmentFileName.stringValue.hasSuffix(".json")){
                segmentFileName.stringValue = segmentFileName.stringValue + ".json"
            }
            segmentDir = segmentDir.appendingPathComponent(segmentFileName.stringValue)
        }
        
        do{
            let data = try JSONEncoder().encode(nodeList)
            try saveDataToFile(data: data, fileUrl: segmentDir)
            
        }catch{
            Dialog.showDialog(message: "Cannot save segment file")
        }
        
        
    }
    
    func saveDataToFile(data: Data, fileUrl: URL) throws {
        try data.write(to: fileUrl, options: .atomic)
    }
    
    func loadDataFromFile<T>(fileUrl: URL, type: T.Type) throws -> T where T: Decodable {
        let data = try Data(contentsOf: fileUrl)
        let decoder = JSONDecoder()
        return try decoder.decode(type, from: data)
    }
    
    @IBAction func loadFileToNode(_ sender: NSButton) {
        guard let filePackage = filePackage,
              let segmentDir = filePackage.segmentDir else {
            Dialog.showDialog(message: "cannot access to file directory")
            return
        }
        
        let jsonList = filePackage.getJsonFiles(url: segmentDir)
        
        let jsonListMenu = NSMenu()
        
        jsonList.forEach { fileName in
            let menuItem = NSMenuItem(title: fileName, action: #selector(self.loadSegmentFromJSON(_:)), keyEquivalent: "")
            jsonListMenu.addItem(menuItem)
            
        }
        
        let menuPosition = sender.superview!.convert(NSPoint(x: sender.frame.minX, y: sender.frame.minY), to: self.view)
        
        jsonListMenu.popUp(positioning: nil, at: NSPoint(x: menuPosition.x, y: menuPosition.y), in: self.view)
    }
    
    @objc func loadSegmentFromJSON(_ sender: NSMenuItem) {
        guard let filePackage = filePackage,
              let segmentDir = filePackage.segmentDir else {
            Dialog.showDialog(message: "cannot access to file directory")
            return
        }
        
        let fileUrl = segmentDir.appendingPathComponent(sender.title)

        do{
            let node = try loadDataFromFile(fileUrl: fileUrl, type: [SegmentNode].self)
            nodeList = node
            nodeTable.reloadData()
            segmentFileName.stringValue = sender.title
            
        }catch{
            Dialog.showDialog(message: "Error in loading segment files")
            nodeList = []
            nodeTable.reloadData()
            segmentFileName.stringValue = ""
        }
    }
    
    /// Export mask as binary image
    @IBAction func exportMaskTexture(_ sender: Any) {
        
        guard let maskTexture = renderer.maskTexture else {
            Dialog.showDialog(message: "No mask texture")
            return
            
        }
        
        // if apply gaussian
        // let maskTexture_gaussian = renderer.apply_gaussianBlur3D(input: maskTexture, channel: 0)!
        
        // This code is necessary to fill small holes within the image.
        renderer.copyMaskToTexture(texIn: maskTexture, texOut: maskTexture, channel: 0, binary: true)
        
        
        // create output directory
        guard let filePackage = filePackage,
              let segmentDir = filePackage.segmentDir else {
            return
        }
        
        let outputDir = segmentDir.appendingPathComponent("\(NSDate().timeStampYYYYMMDDHHMMSS())")
        
        let fileManager = FileManager.default
        do {
            try fileManager.createDirectory(at: outputDir, withIntermediateDirectories: true, attributes: nil)
        } catch {
            print("Cannot create directory")
            return
        }
        
        let width = maskTexture.width
        let height = maskTexture.height
        let depth = maskTexture.depth
        let bytesPerRow = width
        let bytesPerImage = width * height
        let region = MTLRegionMake3D(0, 0, 0, width, height, depth)
        
        // Output Texture
        let textureDescriptor = MTLTextureDescriptor()
        textureDescriptor.pixelFormat = MTLPixelFormat.r8Unorm
        textureDescriptor.textureType = .type3D
        textureDescriptor.width = renderer.mainTexture!.width
        textureDescriptor.height = renderer.mainTexture!.height
        textureDescriptor.depth = renderer.mainTexture!.depth
        textureDescriptor.allowGPUOptimizedContents = true

        textureDescriptor.usage = [.shaderRead, .shaderWrite] // .shaderRead
        textureDescriptor.storageMode = .shared

        let acceccableTexture = self.device.makeTexture(descriptor: textureDescriptor)!
        
        let cmdBuf = cmdQueue.makeCommandBuffer()!
        let encoder = cmdBuf.makeBlitCommandEncoder()!
        encoder.copy(from: maskTexture, to: acceccableTexture)
        encoder.endEncoding()
        cmdBuf.commit()
        
        for slice in 0..<depth {
            autoreleasepool{
                
                print("slice", slice)
                var imageBytes = [UInt8](repeating: 0, count: width * height)
                acceccableTexture.getBytes(&imageBytes, bytesPerRow: bytesPerRow, from: MTLRegionMake3D(0, 0, slice, width, height, 1), mipmapLevel: 0)
                
                guard let providerRef = CGDataProvider(data: Data (bytes: &imageBytes,
                                                                   count: MemoryLayout<UInt8>.stride * bytesPerImage) as CFData)
                else{
                    print("ref")
                    return
                    
                }
                
                guard let cgim = CGImage(
                    width: width,
                    height:height,
                    bitsPerComponent: 8, // 8
                    bitsPerPixel: 8 * 1, // 24 or 32
                    bytesPerRow: MemoryLayout<UInt8>.stride * bytesPerRow,  // * 4 for 32bit
                    space:  CGColorSpaceCreateDeviceGray(),
                    bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),  //CGImageAlphaInfo.noneSkipLast.rawValue
                    provider: providerRef,
                    decode: nil,
                    shouldInterpolate: true,
                    intent: .defaultIntent)
                else {
                    return
                    
                }
                let imgRes = cgim.toNSImage
                
                guard let tiff = imgRes.tiffRepresentation,
                      let imgRep = NSBitmapImageRep(data: tiff)
                else {
                    return
                }
                
                let saveFileName = "z" + String(format: "%05d", slice) + ".tif"
                let savePath = outputDir.appendingPathComponent(saveFileName)
                
                guard let tiffData = imgRep.representation(using: .tiff, properties: [:]) else {
                    return
                }
                
                do {
                    try tiffData.write(to: savePath)
                }catch{
                    print("error")
                }
            }
        }
    }
    
    @IBAction func transferToMainTexture(_ sender: NSButton) {
        let destChannelMenu = NSMenu()
        
        destChannelMenu.addItem(NSMenuItem(title: "Apply Mask to Main Texture", action: nil, keyEquivalent: ""))
        for i in 0...3{
            let menuItem = NSMenuItem(title: "Channel \(i+1)", action: #selector(self.applyMaskToMainTexture(_:)), keyEquivalent: "")
            menuItem.tag = i
            destChannelMenu.addItem(menuItem)
        }
        
        destChannelMenu.addItem(NSMenuItem.separator())
        destChannelMenu.addItem(NSMenuItem(title: "Apply Smoothed Mask to Main Texture", action: nil, keyEquivalent: ""))
        for i in 0...3{
            let menuItem = NSMenuItem(title: "Channel \(i+1)", action: #selector(self.applySmoothedMaskToMainTexture(_:)), keyEquivalent: "")
            menuItem.tag = i
            destChannelMenu.addItem(menuItem)
        }
        
        let menuPosition = sender.superview!.convert(NSPoint(x: sender.frame.minX, y: sender.frame.minY), to: self.view)
        
        destChannelMenu.popUp(positioning: nil, at: NSPoint(x: menuPosition.x, y: menuPosition.y), in: self.view)
        
    }
    
    @objc func applyMaskToMainTexture(_ sender:NSMenuItem){
        renderer.transferMaskToMainTexture(destChannel: sender.tag.toUInt8(), smooth: false)
        Dialog.showDialog(message: "Completed", title: "", style: .informational)
    }
    @objc func applySmoothedMaskToMainTexture(_ sender:NSMenuItem){
        renderer.transferMaskToMainTexture(destChannel: sender.tag.toUInt8(), smooth: true)
        Dialog.showDialog(message: "Completed", title: "", style: .informational)
    }
    
    @IBAction func selectChannelNumber(_ sender: NSPopUpButton){
        renderer.channel = sender.indexOfSelectedItem.toUInt8()
        outputView.image = renderer.renderSlice()
    }
    
    
    @IBAction func clearMaskImage(_ sender: Any) {
        renderer.maskTexture = nil
        outputView.image = renderer.renderSlice()
    }
}

//MARK: - SegmentRenderViewProtocol
extension Segment3DController:SegmentRenderViewProtocol{
    
    func segmentRenderViewAreaConfirm(view: SegmentRenderView, area: NSRect) {
        switch view.identifier?.rawValue {
        case "main":
            currentSegmentNode.cropArea = area
            currentSegmentNode.cropAreaCoord = area / outputView.bounds.width
            currentSegmentNode.viewSize = outputView.frame.size
            
            guard let targetArea = outputView.confirmedArea?.standardized else {return}
            guard let currentImg = renderer.baseImage else {return}
            
            let scaleX = currentImg.width.toCGFloat() / outputView.bounds.width
            let scaleY = currentImg.height.toCGFloat() / outputView.bounds.height
            
            let scaledArea = targetArea.scaling(scaleX: scaleX, scaleY: scaleY)
            let croppedImg = currentImg.cropping(to: scaledArea)
            
            currentSegmentNode.size = croppedImg?.size
            
            
            break
            
        case "clusterView":
            break
            
        default:
            break
        }
        
    }
    
    func segmentRenderViewAreaClicked(view: SegmentRenderView, point: NSPoint) {
        switch view.identifier?.rawValue {
        case "main":
            break
            
        case "clusterView":
            break
            
        default:
            break
        }
    }
    
    func segmentRenderViewMouseMoved(view: SegmentRenderView, with event: NSEvent, point: NSPoint) {
        switch view.identifier?.rawValue {
        case "main":
            let outputViewPoint = point // mouse location (origin: left-top)
            let viewScaleW = outputView.frame.width / renderer.imageParams.outputImageWidth.toCGFloat()
            let viewScaleH = outputView.frame.height / renderer.imageParams.outputImageHeight.toCGFloat()
            let viewScale = Float(min(viewScaleW, viewScaleH))
            
            //FIXME: not consider flip
            // position from center; range is -viewSize/2 to +viewSize/2
            let centeredPosition:float4 = float4(Float(outputViewPoint.x - outputView.frame.width / 2.0) / viewScale,
                                                 Float(outputViewPoint.y - outputView.frame.height / 2.0) / viewScale, // flip  * (-1)
                                                 0,
                                                 1)

            let transferMat = matrix_float4x4(
                float4(1, 0, 0, 0),
                float4(0, 1, 0, 0),
                float4(0, 0, 1.0, 0),
                float4(renderer.renderModelParams.translationX, renderer.renderModelParams.translationY, 0, 1.0)
            )
            
            let scaleMatRatio = 1.0 / renderer.renderModelParams.scale;
            let scale_Z = renderer.renderModelParams.zScale;
            let scaleMat = float4x4(
                float4(scaleMatRatio, 0, 0, 0),
                float4(0, scaleMatRatio, 0, 0),
                float4(0, 0, 1, 0),
                float4(0, 0, 0, 1)
            )
            
            print("image W,H,D", renderer.imageParams.inputImageWidth, renderer.imageParams.inputImageHeight, renderer.imageParams.inputImageDepth)
            
            let  matrix_centering_toView = float4x4(
                float4(1, 0, 0, 0),
                float4(0, 1, 0, 0),
                float4(0, 0, 1, 0),
                float4(renderer.imageParams.inputImageWidth.toFloat() / 2.0, renderer.imageParams.inputImageHeight.toFloat() / 2.0, renderer.imageParams.inputImageDepth.toFloat() * scale_Z / 2.0, 1)
            )
            
            let directionVector = float3(0, 0, 1)
            let directionVector_rotate = renderer.quaternion.act(directionVector)
            
            let pos = transferMat * scaleMat * centeredPosition
            let mappedXYZ = renderer.quaternion.act(pos.xyz)
            
            let radius:Float = renderer.renderModelParams.sliceMax.toFloat() / 2.0
            let ts =  radius - renderer.renderModelParams.sliceNo.toFloat()
            
            let current_mapped_pos = mappedXYZ + ts * directionVector_rotate
            
            let currentPos:float4 = float4(current_mapped_pos, 1)
            
            let coordinatePos = matrix_centering_toView * currentPos;
            
            let samplerPostion = float3(
                coordinatePos.x / (renderer.imageParams.inputImageWidth.toFloat()),
                coordinatePos.y / (renderer.imageParams.inputImageHeight.toFloat()),
                coordinatePos.z / (renderer.imageParams.inputImageDepth.toFloat() * scale_Z)
            )
            
            // to get the z number in original stack, divide by (z_scale)
            print("texture location(0-1): ", samplerPostion.stringValue)
            print("current ts:", ts)
            
        default:
            break
        }
        
    }
    
    func segmentRenderViewMouseDragged(view: SegmentRenderView, mouse startPoint: NSPoint, previousPoint: NSPoint, currentPoint: NSPoint) {
        switch view.identifier?.rawValue {
        case "main":
            // rotate MPR views with mouse operation
            
            let deltaH = Float( currentPoint.x - previousPoint.x)
            let deltaV = Float( currentPoint.y - previousPoint.y)
            
            renderer.rotateModel(deltaX: deltaV, deltaY: deltaH, deltaZ: 0)
            
            outputView.image = renderer.renderSlice()
            
        default:
            break
        }
        
        
    }
    
    func segmentRenderViewMouseUp(view: SegmentRenderView, mouse startPoint: NSPoint, currentPoint: NSPoint) {
        
    }
    
    func segmentRenderViewMouseClicked(view: SegmentRenderView, mouse point: NSPoint) {
        
        switch view.identifier?.rawValue {
        case "main":
            break
            
        case "clusterView":
            // mouse click on clustered grayscale image
            // fill the clustered image and create mask image
            
            guard let clusterImage = clusteredView.image?.toCGImage else {return}
            
            let scaleX = clusterImage.width.toCGFloat() / maskViewForCluster.bounds.width
            let scaleY = clusterImage.height.toCGFloat() / maskViewForCluster.bounds.height
            let scale = max(scaleX, scaleY)
            
            
            let scaledPoint = point.scaling(scaleX: scale, scaleY: scale)
            if((scaledPoint.x > clusterImage.width.toCGFloat()) || (scaledPoint.y > clusterImage.height.toCGFloat())){
                Dialog.showDialog(message: "Pointed area is outside of the image")
                return
            }
            
            
            guard let fillResult = clusterImage.fill(in: scaledPoint).image else {
                Dialog.showDialog(message: "Could not fill the image")
                return
            }
            
            guard let moment = fillResult.calcMoment(device: device, cmdQueue: cmdQueue, lib: lib) else{
                Dialog.showDialog(message: "Could not calculate moments")
                return
            }
            
            let index = currentSegmentNode.indexForSlice(slice: sliderSlice.integerValue)
            
            print("click summary:", index, moment.moment, scaledPoint)
            
            currentSegmentNode.point[index] = scaledPoint
            currentSegmentNode.moment[index] = moment.moment
            currentSegmentNode.maskImage[index] = fillResult
            
            guard let kmeansRes = currentSegmentNode.currentKMeansResult else{
                Dialog.showDialog(message: "Something wrong in current k-means result")
                return
            }
            
            currentSegmentNode.clusterCenters[index] = kmeansRes.centers
            currentSegmentNode.clusterCentroids[index] = kmeansRes.calculatedClusterCentroids
            if(index == 0){
                currentSegmentNode.initialClusterCenters = kmeansRes.centers
            }
            
            maskViewForCluster.image = fillResult.toNSImage
            clusteredView.marker = moment.moment.scaling(scaleX: 1/scale, scaleY: 1/scale)
            clusteredView.redraw()
            
            break
            
        default:
            break
        }
    }
    
    func segmentRenderViewMouseWheeled(view: SegmentRenderView, with event: NSEvent) {
        
    }
}


//MARK: - Table view
extension Segment3DController:NSTableViewDataSource, NSTableViewDelegate{
    func numberOfRows(in tableView: NSTableView) -> Int {
        return nodeList.count
    }
    
    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        return row
    }
    
    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        currentSegmentNode = nodeList[row]
        sliderSegmentSlice.maxValue = (currentSegmentNode.sliceCount - 1).toDouble()
        sliderSegmentSlice.integerValue = 0
        currentSegmentNode.currentSliceNo = currentSegmentNode.sliceForIndex(index: 0)
        
        sliderSlice.integerValue = currentSegmentNode.startSliceNo!
        
        self.renderer.renderModelParams = currentSegmentNode.renderModelParams
        
        self.renderer.rotateModelTo(quaternion: currentSegmentNode.quaternion)
        
        renderer?.renderModelParams?.sliceNo = sliderSlice.integerValue.toUInt16()
        
        sliderSliceChanged(sliderSlice)
        
        guard let currentImg = renderer.baseImage else {
            return true
        }
        
        let cropArea = currentSegmentNode.cropArea!
        outputView.confirmedArea = cropArea
        
        let scaleX = currentImg.width.toCGFloat() / outputView.bounds.width
        let scaleY = currentImg.height.toCGFloat() / outputView.bounds.height
        
        let scaledArea = currentSegmentNode.cropArea.scaling(scaleX: scaleX, scaleY: scaleY)
        let croppedImg = currentImg.cropping(to: scaledArea)
        
        cropViewForCluster.image = croppedImg?.toNSImage
        
        maskViewForCluster.image = currentSegmentNode.maskImage[0]?.toNSImage
        
        
        _ = createMaskTexture(node: currentSegmentNode)
        outputView.image = renderer.renderSlice()
        
        return true
    }
}
