//
//  ViewController.swift
//  Acto3D
//
//  Created by Naoki TAKESHITA on 2021/12/18.
//

import Cocoa
import Metal
import MetalKit

import IOKit




class ViewController: NSViewController{
    

    
    @IBOutlet weak var focusCircle: FocusCircle!
    
    var currentCoordinate:float4 = float4(0, 0, 0, 0)
    
    @IBOutlet weak var mprmodeIndicator: NSTextField!
    
    // MENUs
    @IBOutlet var openMenu: NSMenu!
    
    @IBOutlet weak var pathField: NSTextField!
    
    @IBOutlet weak var fileListTable: NSTableView!
    @IBOutlet weak var logTable: NSTableView!
    @IBOutlet weak var pointSetTable: NSTableView!
    
    @IBOutlet weak var imgPreview: NSImageView!
    
    
    @IBOutlet weak var scale_Slider: NSSlider!
    @IBOutlet weak var scale_Label: ValidatingTextField!
    @IBOutlet weak var slice_Slider: NSSlider!
    @IBOutlet weak var crop_Slider: NSSlider!
    @IBOutlet weak var crop_Label: NSTextField!
    @IBOutlet weak var slice_Label: NSTextField!
    @IBOutlet weak var slice_Label_current: ValidatingTextField!
    @IBOutlet weak var zScale_Slider: NSSlider!
    @IBOutlet weak var zScale_Label: ValidatingTextField!
    
    
    @IBOutlet weak var light_Slider: NSSlider!
    @IBOutlet weak var shade_Slider: NSSlider!
    
    
    @IBOutlet weak var xMin_Slider: NSSlider!
    @IBOutlet weak var xMax_Slider: NSSlider!
    @IBOutlet weak var yMin_Slider: NSSlider!
    @IBOutlet weak var yMax_Slider: NSSlider!
    @IBOutlet weak var zMin_Slider: NSSlider!
    @IBOutlet weak var zMax_Slider: NSSlider!
    
    @IBOutlet weak var toneCh1: ToneCurveView!
    @IBOutlet weak var toneCh2: ToneCurveView!
    @IBOutlet weak var toneCh3: ToneCurveView!
    @IBOutlet weak var toneCh4: ToneCurveView!
    
    // name, control points, linear or spline
    var controlPoints:[(String, [[Float]], Int)] = []
    let controlPointsMenu: NSMenu = NSMenu()
    
    
    @IBOutlet weak var intensityRatio_slider_1: NSSlider!
    @IBOutlet weak var intensityRatio_slider_2: NSSlider!
    @IBOutlet weak var intensityRatio_slider_3: NSSlider!
    @IBOutlet weak var intensityRatio_slider_4: NSSlider!
    
    @IBOutlet weak var wellCh1: NSColorWell!
    @IBOutlet weak var wellCh2: NSColorWell!
    @IBOutlet weak var wellCh3: NSColorWell!
    @IBOutlet weak var wellCh4: NSColorWell!
    
    
    @IBOutlet weak var eularX: NSTextField!
    @IBOutlet weak var eularY: NSTextField!
    @IBOutlet weak var eularZ: NSTextField!
    
    @IBOutlet weak var normalVecField: NSTextField!
    
    // SWITCH
    @IBOutlet weak var switch_interpolation: NSSwitch!
    @IBOutlet weak var switch_backtofront: NSSwitch!
    @IBOutlet weak var switch_shade: NSSwitch!
    @IBOutlet weak var switch_cropLock: NSSwitch!
    @IBOutlet weak var switch_cropOpposite: NSSwitch!
    @IBOutlet weak var switch_flip: NSSwitch!
    @IBOutlet weak var switch_plane: NSSwitch!
    @IBOutlet weak var switch_boundingBox: NSSwitch!
    @IBOutlet weak var check_adaptive: NSButton!
    
    @IBOutlet weak var stepLabel: NSTextField!
    @IBOutlet weak var stepSlider: NSSlider!
    
    @IBOutlet weak var segmentRenderMode: NSSegmentedControl!
    
    
    @IBOutlet weak var outputView: ModelView!
    
    
    @IBOutlet weak var progressBar: NSProgressIndicator!
    
    
    var filePackage:FilePackage?
    
    
    
    /// main renderer
    var renderer = VoluemeRenderer()

    
    @IBOutlet weak var popUpViewSize: NSPopUpButton!
    @IBOutlet weak var popUpAlphaPower: NSPopUpButton!
    
    
    struct RecentFile:Codable {
        let fileType: String
        let filePath: String
    }
    var recentFiles:[RecentFile]?
    
    // ========================================================
    // Plane Section
    var normal_1f:float3?
    var normal_2f:float3?
    
    @IBOutlet weak var degree_2planes: NSTextField!
    @IBOutlet weak var distane_2pointsField: NSTextField!
    @IBOutlet weak var normal_1: NSTextField!
    @IBOutlet weak var normal_2: NSTextField!
    @IBOutlet weak var removeSelectedButton: NSButton!
    @IBOutlet weak var removeAllButton: NSButton!
    @IBOutlet weak var planeSectionButton1: NSButton!
    @IBOutlet weak var planeSectionButton2: NSButton!
    
    
    // ============================================
    // Animation
    @IBOutlet weak var animate_startPlist: NSPopUpButton!
    @IBOutlet weak var animate_endPlist: NSPopUpButton!
    @IBOutlet weak var animate_movSize: NSPopUpButton!
    @IBOutlet weak var animate_movFPS: NSPopUpButton!
    
    @IBOutlet weak var durationField: NSTextField!
    
    @IBOutlet weak var movCollectionView: MovieCollectionView!
    var movSeq:MovieSequence!
    
    var currentIndex = 0
    
    // ============ scale box ===============
    @IBOutlet weak var xResolutionField: NSTextField!
    @IBOutlet weak var yResolutionField: NSTextField!
    @IBOutlet weak var zResolutionField: NSTextField!
    @IBOutlet weak var scaleUnitField: NSTextField!
    @IBOutlet weak var scalebarLengthField: NSTextField!
    @IBOutlet weak var scaleFontSizeSlider: NSSlider!
    
    
    var shaderList:[ShaderManage] = ShaderManage.getPresetList()
    
    var tcpServer:TCPServer?
    
    //MARK: - Initialize
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // delegate setup
        fileListTable.dataSource = self
        fileListTable.delegate = self
        
        pointSetTable.delegate = self
        pointSetTable.dataSource = self
        
        outputView.view = self
        
        mprmodeIndicator.isHidden = true
        
        
        
        Logger.setTableView(logTable)
        
        // init Renderer
        renderer.delegate = self
        renderer.initMetal()
    
        // The application compiles preset shaders and custom shaders created by the user at runtime.
        // If the compilation fails, the device will use a default library.
        // Preset .metal files are already compiled during the build process of the application,
        // and the compiler has generated a default.metallib file.
        // Therefore, in case the compilation of custom shaders fails due to errors,
        // the application will create a default library from the compiled default.metallib file.
        do{
            try shaderReCompile(onAppLaunch: true)
            
        }catch{
            Logger.log(message: "⚠️ Error in compiling custom shaders. Use preset shader.", level: .error, writeToLogfile: true)
            renderer.createDefaultLibrary()
        }
        
        renderer.currentShader = shaderList[AppConfig.DEFAULT_SHADER_NO] // select default shader
        segmentRenderMode.selectSegment(withTag: AppConfig.DEFAULT_SHADER_NO)
        
        // check system resource
        checkSystemResource()
        
        setDefaultColorToWell()
        
        // Create preset control points
        createPresetControlPoints()
        
        initToneCurveViews()
        
        transferTone(sender: toneCh1, targetGPUbuffer: &renderer.toneBuffer_ch1, index: 0)
        transferTone(sender: toneCh2, targetGPUbuffer: &renderer.toneBuffer_ch2, index: 1)
        transferTone(sender: toneCh3, targetGPUbuffer: &renderer.toneBuffer_ch3, index: 2)
        transferTone(sender: toneCh4, targetGPUbuffer: &renderer.toneBuffer_ch4, index: 3)
        
        // load security bookmarks
        Permission.loadSecurityBookmarks()
        
        // load recent file list
        let userDefaults = UserDefaults.standard
        
        if let savedFilesArrayData = userDefaults.data(forKey: "Recent") {
            do {
                let decodedFilesArray = try PropertyListDecoder().decode([RecentFile].self, from: savedFilesArrayData)
                for file in decodedFilesArray {
                    print("Type: \(file.fileType), Path: \(file.filePath)")
                }
                recentFiles = decodedFilesArray
                
            } catch {
            }
        } else {
        }
        
        movSeq = MovieSequence(collectionView: movCollectionView)
        movSeq.vc = self
        
        
        // Editible Validation Text Field
        zScale_Label.validationDelegate = self
        scale_Label.validationDelegate = self
        slice_Label_current.validationDelegate = self
        
        
        if let tcpServer = TCPServer(port: AppConfig.TCP_PORT){
            self.tcpServer = tcpServer
            self.tcpServer?.delegate = self
            self.tcpServer?.renderer = renderer
            self.tcpServer?.vc = self
            self.tcpServer?.start()
        }
    }
    
    


    func getMachineModelIdentifier() -> String? {
        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        var machineModelIdentifier = [CChar](repeating: 0, count: Int(size))
        sysctlbyname("hw.model", &machineModelIdentifier, &size, nil, 0)
        return String(cString: machineModelIdentifier)
    }

    func getProcessorName() -> String? {
        var size = 0
        sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0)
        var processorName = [CChar](repeating: 0, count: Int(size))
        sysctlbyname("machdep.cpu.brand_string", &processorName, &size, nil, 0)
        return String(cString: processorName)
    }
    
    func checkSystemResource(){
        // information for debugging
        // Get device name
        guard let machineModel = getMachineModelIdentifier(),
        let processor = getProcessorName() else {
            return
        }
        let operatingSystem = ProcessInfo.processInfo.operatingSystemVersionString
        let processorCount = ProcessInfo.processInfo.processorCount
        Logger.log(message: "\(machineModel), \(operatingSystem), processor=\(processor), processorCount=\(processorCount)", writeToLogfile: true, onlyToFile: true)
        
        
        
        let ph_mem = Double(ProcessInfo.processInfo.physicalMemory) / 1024.0 / 1024.0 / 1024.0
        let recommendSize =  Double(renderer.device.recommendedMaxWorkingSetSize) / 1024.0 / 1024.0 / 1024.0
        let maxBufSize = Double(renderer.device.maxBufferLength) / 1024.0 / 1024.0 / 1024.0
        Logger.log(message: "Physical Memory: \(String(format: "%.1f", ph_mem)) GB, GPU: \(renderer.device.name), Max Buffer Size: \(String(format: "%.1f", maxBufSize)) GB, Recommended Memory Usage Limit: \(String(format: "%.1f", recommendSize)) GB", level: .info, writeToLogfile: true)
        print(renderer.device.maxBufferLength)
    }
    
    func setDefaultColorToWell(){
        wellCh1.color = NSColor(calibratedRed: 1, green: 0, blue: 0, alpha: 1)
        wellCh2.color = NSColor(calibratedRed: 0, green: 1, blue: 0, alpha: 1)
        wellCh3.color = NSColor(calibratedRed: 0, green: 0, blue: 1, alpha: 1)
        wellCh4.color = NSColor(calibratedRed: 1, green: 1, blue: 1, alpha: 1)
    }
    
    
    func getFilesFromDir(result: (path: String, items:[String]?)?){
        if let result = result,
           let fileList = result.items{
            pathField.stringValue = result.path
            
            filePackage = FilePackage(fileDir: URL(fileURLWithPath: result.path, isDirectory: true),
                                      fileType: .multiFileStacks,
                                      fileList: fileList)
            
            fileListTable.reloadData()
            
            Logger.logPrintAndWrite(message: "Directory: \(filePackage!.fileDir.path)")
            
            let workingDir = URL(fileURLWithPath: pathField.stringValue, isDirectory: true)
            let filePath = workingDir.appendingPathComponent(fileList[0])
            
            let img = NSImage(contentsOf: filePath)
            let imgRep:NSBitmapImageRep = NSBitmapImageRep(data: (img?.tiffRepresentation)!)!
            let imgWidth = imgRep.pixelsWide
            let imgHeight = imgRep.pixelsHigh
            
            print(imgWidth, imgHeight, imgRep.samplesPerPixel, imgRep.bitsPerPixel,  imgRep.bitsPerSample)
            
            let estimateNeedMemory = round(Double(imgWidth * imgHeight * 4 * fileList.count) / 1024 / 1024)
            
            Logger.logPrintAndWrite(message: "  Width = \(imgWidth), Hieght = \(imgHeight), Depth = \(fileList.count)", level: .info)
            Logger.logPrintAndWrite(message: "Estimated GPU Memory Requirements: \(estimateNeedMemory) MB")
            
            
            renderer.imageParams.scaleX = 1.0
            renderer.imageParams.scaleY = 1.0
            renderer.imageParams.scaleZ = 1.0
            renderer.imageParams.unit = ""
            
            
            setDefaultDisplayRanges(bit: imgRep.bitsPerSample, channelCount: imgRep.samplesPerPixel)
            print(renderer.imageParams.displayRanges)
            
            progressBar.maxValue = (fileList.count - 1).toDouble()
            progressBar.minValue = 0
            progressBar.doubleValue = 0
            progressBar.isHidden = true
            
            // Recent
            // get an instance of UserDefaults
            if(recentFiles == nil){
                recentFiles = []
            }
            
            for (index, recentFile) in recentFiles!.enumerated(){
                if (recentFile.filePath == pathField.stringValue){
                    print(index)
                    recentFiles?.remove(at: index)
                    break
                }
            }
            
            recentFiles?.append(RecentFile(fileType: "Dir", filePath: pathField.stringValue))
            
            if (recentFiles!.count > AppConfig.KEEP_RECENT_NUM){
                recentFiles?.remove(at: 0)
            }
            
            let userDefaults = UserDefaults.standard
            do {
                let encodedFilesArray = try PropertyListEncoder().encode(recentFiles!)
                userDefaults.set(encodedFilesArray, forKey: "Recent")
            } catch {
                print("Failed to encode filesArray: \(error)")
            }
            
        }else{
            Logger.log(message: "⚠️ No image data", level: .error, writeToLogfile: true)
        }
        
        
        
    }
    
    //MARK: Loading Process
    @IBAction func openDir(_ sender: Any) {
        let result = getDirectoryAndFilesWithPanel()
        getFilesFromDir(result: result)
    }
    
    
    @IBAction func openTiff(_ sender: Any) {
        let result = getTiffFile()
        
        
        if let result = result {
            loadTiff(dirPath: result.path, fileName: result.item)
        }
    }
    
    private func loadTiff(dirPath:String, fileName:String){
        
        let workingDir = URL(fileURLWithPath: dirPath, isDirectory: true)
        let filePath = workingDir.appendingPathComponent(fileName)
        
        Logger.logPrintAndWrite(message: "File: \(filePath.path)")
        let fileManager = FileManager()
        if !fileManager.fileExists(atPath: filePath.path){
            Logger.logPrintAndWrite(message: "File Not Found. The selected file does not exist.", level: .error)
        }
        
        guard let mTiff = MTIFF(filePath: filePath.path) else{
            Logger.logPrintAndWrite(message: "⚠️ Error in loading tiff file.", level: .error)
            return
        }
        
        // ファイル自体は読み込めるようであれば，packageを作成
        filePackage = FilePackage(fileDir: URL(fileURLWithPath: dirPath, isDirectory: true),
                                  fileType: .none,
                                  fileList: [fileName])
        
        pathField.stringValue = dirPath
        
        switch mTiff.fileType {
        case .unknown , .bigTiff, .singlePageTiff:
            Logger.logPrintAndWrite(message: "⚠️ Invalid tiff format: \(mTiff.fileType)", level: .error)
            filePackage?.fileType = .none
            return
            
        case .multipageTiff:
            Logger.logPrintAndWrite(message: "⚠️ Multipage Tiff must contain ImageJ tags", level: .error)
            
            filePackage = nil
            fileListTable.reloadData()
            
            return
            
        case .ImageJ_TiffStack, .ImageJ_LargetiffStack:
            Logger.logPrintAndWrite(message: "ImageJ meta data found", level: .info)
            var fileList = Array(1 ... (mTiff.imgCount)).map{String($0) + " / \(mTiff.imgCount)"}
            
            fileList[0] = fileName
            filePackage?.fileList = fileList
            filePackage?.fileType = .singleFileMultiPage
            
            fileListTable.reloadData()
            
            
            // get ImageJ meta data
            print("Meta Data Detect")
            mTiff.getMetaData()
            
            // Exception for display ranges
            if(mTiff.channel == 1){
                if let info = mTiff.fileDescription{
                    if(info.keys.contains("min") && info.keys.contains("max")){
                        let min_range = Double(info["min"] as! String)!
                        let max_range = Double(info["max"] as! String)!
                        mTiff.displayRanges = [[min_range, max_range]]
                    }
                }
            }
            
            let unitString = mTiff.unitString == nil ? "" : "\(mTiff.unitString!)"
            renderer.imageParams.scaleX = mTiff.scaleX
            renderer.imageParams.scaleY = mTiff.scaleY
            renderer.imageParams.scaleZ = mTiff.scaleZ
            renderer.imageParams.unit = unitString
            
            Logger.logPrintAndWrite(message: "Tiff file contains \(mTiff.imgCount) images (\(mTiff.imgCount / mTiff.channel) slices per channel).", level: .info)
            Logger.logPrintAndWrite(message: "  Width = \(mTiff.width), Hieght = \(mTiff.height), Depth = \(mTiff.imgCount / mTiff.channel)", level: .info)
            Logger.logPrintAndWrite(message: "  Voxel resolution: X = \(renderer.imageParams.scaleX), Y = \(renderer.imageParams.scaleY), Z = \(renderer.imageParams.scaleZ) \(renderer.imageParams.unit)", level: .info)
            
            
            if(mTiff.scaleX != mTiff.scaleY){
                Logger.logPrintAndWrite(message: "⚠️ The voxel resolutions of X and Y are different.", level: .error)
                Logger.logPrintAndWrite(message: "  The visualization is possible, but the measured values may be inaccurate.", level: .error)
            }
            
            // display ranges
            if(mTiff.displayRanges != nil){
                renderer.imageParams.displayRanges = mTiff.displayRanges!
            }else{
                // set default ranges
                setDefaultDisplayRanges(bit: mTiff.bitsPerSample, channelCount: mTiff.channel)
            }
            
            Logger.logPrintAndWrite(message: "  Display Range: \(renderer.imageParams.displayRanges)")
            
            let estimateNeedMemory = round(Double(mTiff.width * mTiff.height * 4 * mTiff.imgCount / mTiff.channel) / 1024 / 1024)
            Logger.logPrintAndWrite(message: "Estimated GPU Memory Requirements: \(estimateNeedMemory) MB")
            
        }
        
        // Register Recent used
        // get an instance of UserDefaults
        if(recentFiles == nil){
            recentFiles = []
        }
        
        for (index, recentFile) in recentFiles!.enumerated(){
            if (recentFile.filePath == filePath.path){
                recentFiles?.remove(at: index)
                break
            }
        }
        
        recentFiles?.append(RecentFile(fileType: "Tiff", filePath: filePath.path))
        
        
        if (recentFiles!.count > AppConfig.KEEP_RECENT_NUM){
            recentFiles?.remove(at: 0)
        }
        
        let userDefaults = UserDefaults.standard
        do {
            let encodedFilesArray = try PropertyListEncoder().encode(recentFiles!)
            userDefaults.set(encodedFilesArray, forKey: "Recent")
        } catch {
            print("Failed to encode filesArray: \(error)")
        }
        
    }
    
    
    @IBAction func openMenuOption(_ sender: NSButton) {
        let menuCount = openMenu.items.count
        print("menuCount" , menuCount)
       
        if(menuCount > 4){
            for i in (4..<menuCount).reversed(){
                print(i)
                openMenu.removeItem(at: i)
            }
        }
        
        if let recentFiles = recentFiles {
            for (index, recentFile) in recentFiles.enumerated(){
                let item = NSMenuItem(title: "[\(index)] " + recentFile.filePath, action: #selector(openFromRecentMenu(_:)), keyEquivalent: "")
                openMenu.addItem(item)
            }
        }
        
        openMenu.popUp(positioning: nil, at: NSPoint(x: sender.frame.minX, y: sender.frame.minY), in: self.view)
    }
    
    @objc func openFromRecentMenu(_ sender: NSMenuItem) {
        for (index, menuItem) in openMenu.items.enumerated(){
            if menuItem.title == sender.title {
                let k = (index - 4)
                print(recentFiles![k])
                
                let type = recentFiles![k].fileType
                let name = recentFiles![k].filePath
                
                if (type == "Dir"){
                    let fileManager = FileManager()
                    if !fileManager.fileExists(atPath: name){
                        // file does not exist
                        Logger.log(message: "⚠️ Error in loading file.", level: .error, writeToLogfile: true)
                        return
                    }
                    
                    _ = Permission.checkPermission(url: URL(fileURLWithPath: name))
                    let result = getDirectoryAndFilesWithDirectoryPath(dirPath: name)
                    
                    getFilesFromDir(result: result)
                    
                }  else if (type == "Tiff"){
                    // File
                    let url = URL(fileURLWithPath: name)
                    let fileManager = FileManager()
                    if !fileManager.fileExists(atPath: url.path){
                        // file does not exist
                        Logger.log(message: "⚠️ Error in loading file.", level: .error, writeToLogfile: true)
                        return
                    }
                    
                    _ = Permission.checkPermission(url: url.deletingLastPathComponent())
                    let dir = url.deletingLastPathComponent().path
                    let fileName = url.lastPathComponent
                    loadTiff(dirPath: dir, fileName: fileName)
                    
                }
            }
        }
    }
    
    public func setDefaultDisplayRanges(bit: Int, channelCount:Int){
        // 8 bit: 255, 16 bit: 65535
        let max = 2<<(bit-1) - 1
        self.renderer.imageParams.displayRanges = [[Double]](repeating: [0, max.toDouble()], count: channelCount)
    }
    
 
    
    @IBAction func selectViewSize(_ sender: Any) {
        let drawingviewSize = Int(popUpViewSize.selectedItem!.title)!.toUInt16()
        renderer.volumeData.outputImageHeight = drawingviewSize
        renderer.volumeData.outputImageWidth = drawingviewSize
        renderer.renderParams.viewSize = drawingviewSize
        
        outputView.image = renderer.rendering()
    }
    
    @IBAction func selectAlphaPower(_ sender: NSPopUpButton) {
        renderer.renderParams.alphaPower = UInt8(sender.selectedItem!.identifier!.rawValue)!
        
        outputView.image = renderer.rendering()
    }
    
    
    @IBAction func openDirInFinder(_ sender: Any) {
        guard let filePackage = filePackage else {return}
        
        var isDir:ObjCBool  = false
        
        if filePackage.fileType == .multiFileStacks{
            if FileManager.default.fileExists(atPath: filePackage.fileDir.path, isDirectory: &isDir) {
                NSWorkspace.shared.activateFileViewerSelecting([filePackage.fileDir])
            }
        }else if filePackage.fileType == .singleFileMultiPage{
            if FileManager.default.fileExists(atPath: filePackage.fileDir.path, isDirectory: &isDir) {
                NSWorkspace.shared.activateFileViewerSelecting([filePackage.fileDir.appendingPathComponent(filePackage.fileList[0])])
            }
        }
        
    }
    
    func openDirInFinder(path: String){
        var isDir:ObjCBool  = false
        if FileManager.default.fileExists(atPath: path, isDirectory: &isDir) {
            NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
        }
    }
    func openDirInFinder(url: URL){
        var isDir:ObjCBool  = false
        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }
    }
    
    
    func resetCurrentData(){
        self.filePackage = nil
        self.renderer.imageParams = ImageParameters()
        self.renderer.volumeData = VolumeData()
        self.renderer.renderParams = RenderingParameters()
        self.renderer.pointClouds = PointClouds()
        
        outputView.image = nil
    }
    
    @IBAction func logger_menu(_ sender: Any) {
        switch (sender as! NSMenuItem).title {
        case "Clear logs":
            Logger.clearLog()
        default:
            break
        }
    }
    
    func changeSwitchFromValue(object: NSSwitch, option: RenderOption, element:RenderOption.Element){
        object.integerValue = option.contains(element) ? 1:0
    }
    func changeCheckButtonFromValue(object: NSButton, option: RenderOption, element:RenderOption.Element){
        object.state = option.contains(element) ? NSControl.StateValue(1):NSControl.StateValue(0)
    }
    
    @IBAction func renderOptionButton(_ sender: NSButton) {
        switch sender.identifier?.rawValue {
        case "adaptive":
            renderer.renderOption.changeValue(option: .ADAPTIVE, value: sender.state.rawValue)
            
        default:
            break
        }
        renderer.argumentManager?.markAsNeedsUpdate(argumentIndex: .renderParams)
        outputView.image = renderer.rendering()
    }
    @IBAction func renderOptionSwitch(_ sender:NSSwitch){
        switch sender.identifier?.rawValue {
        case "linear":
            renderer.renderOption.changeValue(option: .SAMPLER_LINEAR, value: sender.integerValue)
            
        case "shade":
            renderer.renderOption.changeValue(option: .SHADE, value: sender.integerValue)
            
        case "crop_lock":
            renderer.renderOption.changeValue(option: .CROP_LOCK, value: sender.integerValue)
            
            renderer.renderParams.cropLockQuaternions = renderer.quaternion
            renderer.renderParams.cropSliceNo = renderer.renderParams.sliceNo
            
            crop_Slider.integerValue = renderer.renderParams.cropSliceNo.toInt()
            crop_Label.stringValue = "\(crop_Slider.integerValue) / \(crop_Slider.maxValue.toInt())"
            
            renderer.renderParams.sliceNo = renderer.renderParams.sliceMax
            slice_Slider.doubleValue = slice_Slider.maxValue
            
            crop_Label.sizeToFit()
            slice_Label.sizeToFit()
            scale_Label.sizeToFit()
            zScale_Label.sizeToFit()
            
        case "crop_toggle":
            renderer.renderOption.changeValue(option: .CROP_TOGGLE, value: sender.integerValue)
            
        case "flip":
            renderer.renderOption.changeValue(option: .FLIP, value: sender.integerValue)
        case "plane":
            renderer.renderOption.changeValue(option: .PLANE, value: sender.integerValue)
            
        case "box":
            renderer.renderOption.changeValue(option: .BOX, value: sender.integerValue)
            
        default:
            break;
        }
        
        renderer.argumentManager?.markAsNeedsUpdate(argumentIndex: .renderParams)
        outputView.image = renderer.rendering()
    }
    
    
    
    
    @IBAction func updateSliceSlider(_ sender: NSSlider) {
        updateSliceAndScale(currentSliceToMax: false)
        outputView.image = renderer.rendering()
    }
    
    @IBAction func updateZscaleSlider(_ sender: NSSlider) {
        if(slice_Slider.doubleValue == slice_Slider.maxValue){
            updateSliceAndScale(currentSliceToMax: true)
        }else{
            updateSliceAndScale(currentSliceToMax: false)
        }
        outputView.image = renderer.rendering()
    }
    
    @IBAction func updateScaleSlider(_ sender: NSSlider) {
        updateSliceAndScale(currentSliceToMax: false)
        outputView.image = renderer.rendering()
    }
    
    @IBAction func updateCropSlider(_ sender: NSSlider) {
        renderer.renderParams.cropSliceNo = crop_Slider.integerValue.toUInt16()
        
        crop_Label.stringValue = "\(crop_Slider.integerValue) / \(crop_Slider.maxValue.toInt())"
        crop_Label.sizeToFit()
        
        renderer.argumentManager?.markAsNeedsUpdate(argumentIndex: .renderParams)
        
        
        outputView.image = renderer.rendering()
    }
    
    /// adjust maximum value of slice slider
    func updateSliceAndScale(currentSliceToMax mode: Bool){
        // Calculate the radius of a sphere that covers all texels
        renderer.renderParams.zScale = zScale_Slider.floatValue
        
        let radius = length(float3(renderer.volumeData.inputImageWidth.toFloat() / 2,
                                   renderer.volumeData.inputImageHeight.toFloat() / 2,
                                   renderer.volumeData.inputImageDepth.toFloat() * renderer.renderParams.zScale / 2))
        
        slice_Slider.minValue = 0
        slice_Slider.maxValue = round(radius * 2).toDouble()
        crop_Slider.minValue = 0
        crop_Slider.maxValue = round(radius * 2).toDouble()
        
        if(mode == true){
            slice_Slider.doubleValue = slice_Slider.maxValue
        }
        
        renderer.renderParams.sliceMax = slice_Slider.maxValue.toInt().toUInt16()
        renderer.renderParams.sliceNo = slice_Slider.integerValue.toUInt16()
        renderer.renderParams.scale = scale_Slider.floatValue
        
        slice_Label_current.stringValue = "\(slice_Slider.integerValue)"
        slice_Label_current.sizeToFit()
        slice_Label_current.constraints.first(where: {$0.firstAttribute == .width})?.constant = slice_Label_current.frame.width
        slice_Label.stringValue = "/ \(slice_Slider.maxValue.toInt())"
        crop_Label.stringValue = "\(crop_Slider.integerValue) / \(crop_Slider.maxValue.toInt())"
        scale_Label.stringValue = "\(scale_Slider.floatValue.toFormatString(format: "%.2f"))"
        zScale_Label.stringValue = "\(zScale_Slider.floatValue.toFormatString(format: "%.2f"))"
        
        slice_Label.sizeToFit()
        
        crop_Label.sizeToFit()
        scale_Label.sizeToFit()
        zScale_Label.sizeToFit()
    }
    
    func updateSliceAndScaleFromParams(params: RenderingParameters){
        
        slice_Slider.minValue = 0
        slice_Slider.maxValue = params.sliceMax.toInt().toDouble()
        crop_Slider.minValue = 0
        crop_Slider.maxValue = slice_Slider.maxValue
        scale_Slider.floatValue = params.scale
        zScale_Slider.floatValue = params.zScale
        slice_Slider.integerValue = params.sliceNo.toInt()
        crop_Slider.integerValue = params.cropSliceNo.toInt()
        
        slice_Label_current.stringValue = "\(slice_Slider.integerValue)"
        slice_Label_current.sizeToFit()
        slice_Label_current.constraints.first(where: {$0.firstAttribute == .width})?.constant = slice_Label_current.frame.width
        slice_Label.stringValue = "/ \(slice_Slider.maxValue.toInt())"
        crop_Label.stringValue = "\(crop_Slider.integerValue) / \(crop_Slider.maxValue.toInt())"
        scale_Label.stringValue = "\(scale_Slider.floatValue.toFormatString(format: "%.2f"))"
        zScale_Label.stringValue = "\(zScale_Slider.floatValue.toFormatString(format: "%.2f"))"
        
        slice_Label.sizeToFit()
        crop_Label.sizeToFit()
        scale_Label.sizeToFit()
        zScale_Label.sizeToFit()
        
        xMin_Slider.floatValue = params.trimX_min
        xMax_Slider.floatValue = params.trimX_max
        yMin_Slider.floatValue = params.trimY_min
        yMax_Slider.floatValue = params.trimY_max
        zMin_Slider.floatValue = params.trimZ_min
        zMax_Slider.floatValue = params.trimZ_max
        
        stepSlider.floatValue = params.renderingStep
        stepLabel.floatValue = stepSlider.floatValue
        stepLabel.sizeToFit()
        
        light_Slider.floatValue = params.light
        shade_Slider.floatValue = params.shade
        intensityRatio_slider_1.floatValue = params.intensityRatio[0]
        intensityRatio_slider_2.floatValue = params.intensityRatio[1]
        intensityRatio_slider_3.floatValue = params.intensityRatio[2]
        intensityRatio_slider_4.floatValue = params.intensityRatio[3]
        
        
        
        
        renderer.argumentManager?.markAsNeedsUpdate(argumentIndex: .renderParams)
    }
    
    @IBAction func updateTrimSlider(_ sender:NSSlider){
        switch sender.identifier?.rawValue {
        case "x_min":
            if(xMin_Slider.doubleValue >= xMax_Slider.doubleValue){
                xMin_Slider.doubleValue = xMax_Slider.doubleValue
            }
            
            break
        case "x_max":
            if(xMax_Slider.doubleValue <= xMin_Slider.doubleValue){
                xMax_Slider.doubleValue = xMin_Slider.doubleValue
            }
            break
        case "y_min":
            if(yMin_Slider.doubleValue >= yMax_Slider.doubleValue){
                yMin_Slider.doubleValue = yMax_Slider.doubleValue
            }
            break
        case "y_max":
            if(yMax_Slider.doubleValue <= yMin_Slider.doubleValue){
                yMax_Slider.doubleValue = yMin_Slider.doubleValue
            }
            
            break
        case "z_min":
            if(zMin_Slider.doubleValue >= zMax_Slider.doubleValue){
                zMin_Slider.doubleValue = zMax_Slider.doubleValue
            }
            break
        case "z_max":
            if(zMax_Slider.doubleValue <= zMin_Slider.doubleValue){
                zMax_Slider.doubleValue = zMin_Slider.doubleValue
            }
            break
        default:
            break
        }
        
        renderer.renderParams.trimX_min = xMin_Slider.floatValue
        renderer.renderParams.trimX_max = xMax_Slider.floatValue
        renderer.renderParams.trimY_min = yMin_Slider.floatValue
        renderer.renderParams.trimY_max = yMax_Slider.floatValue
        renderer.renderParams.trimZ_min = zMin_Slider.floatValue
        renderer.renderParams.trimZ_max = zMax_Slider.floatValue
        
        renderer.argumentManager?.markAsNeedsUpdate(argumentIndex: .renderParams)
        outputView.image = renderer.rendering()
    }
    
    @IBAction func intensityRatioSliderChanged(_ sender: NSSlider){
//        renderer.intensityRatio[sender.tag] = sender.floatValue
        renderer.renderParams.intensityRatio[sender.tag] = sender.floatValue
        print(renderer.renderParams.intensityRatio)
        renderer.argumentManager?.markAsNeedsUpdate(argumentIndex: .renderParams)
        outputView.image = renderer.rendering()
    }
    
    @IBAction func light_shade_SliderChanged(_ sender: NSSlider) {
        switch sender.identifier?.rawValue {
        case "light":
            renderer.renderParams.light = sender.floatValue
        case "shade":
            renderer.renderParams.shade = sender.floatValue
        default:
            break
        }
        renderer.argumentManager?.markAsNeedsUpdate(argumentIndex: .renderParams)
        outputView.image = renderer.rendering()
    }
    
    
    @IBAction func colorWellChanged(_ sender: NSColorWell) {
        //color_ch1
        switch sender.identifier?.rawValue {
        case "color_ch1":
            toneCh1.setDefaultBackgroundColor(color: sender.color)
            renderer.renderParams.color.ch1_color = float4(sender.color.redComponent.toFloat(),
                                                    sender.color.greenComponent.toFloat(),
                                                    sender.color.blueComponent.toFloat(),
                                                    0)
            toneCh1.updateView()
        case "color_ch2":
            toneCh2.setDefaultBackgroundColor(color: sender.color)
            renderer.renderParams.color.ch2_color = float4(sender.color.redComponent.toFloat(),
                                                    sender.color.greenComponent.toFloat(),
                                                    sender.color.blueComponent.toFloat(),
                                                    0)
            toneCh2.updateView()
        case "color_ch3":
            toneCh3.setDefaultBackgroundColor(color: sender.color)
            renderer.renderParams.color.ch3_color = float4(sender.color.redComponent.toFloat(),
                                                    sender.color.greenComponent.toFloat(),
                                                    sender.color.blueComponent.toFloat(),
                                                    0)
            toneCh3.updateView()
        case "color_ch4":
            toneCh4.setDefaultBackgroundColor(color: sender.color)
            renderer.renderParams.color.ch4_color = float4(sender.color.redComponent.toFloat(),
                                                    sender.color.greenComponent.toFloat(),
                                                    sender.color.blueComponent.toFloat(),
                                                    0)
            toneCh4.updateView()
            
        case "color_bg":
            renderer.renderParams.backgroundColor = float3(sender.color.redComponent.toFloat(),
                                              sender.color.greenComponent.toFloat(),
                                              sender.color.blueComponent.toFloat())
        default:
            break
        }
        
        //        print(modelParameter.color)
        
        outputView.image = renderer.rendering()
    }
    //MARK: - Render Option
    
    @IBAction func changeRenderingStep(_ sender: NSSlider) {
        renderer.renderParams.renderingStep = sender.floatValue
        stepLabel.floatValue = sender.floatValue
        stepLabel.sizeToFit()
        
        renderer.argumentManager?.markAsNeedsUpdate(argumentIndex: .renderParams)
        
        outputView.image = renderer.rendering()
    }
    
    @IBAction func changeRenderMode(_ sender: NSSegmentedControl) {
        let mode = sender.selectedSegment
        
        for shader in shaderList{
            print(shader)
        }
        
        switch mode {
        case 0:
            renderer.currentShader = shaderList[0]
            self.renderer.renderParams.renderingMethod = sender.selectedSegment.toUInt8()
            renderer.resetMetalFunctions()
            outputView.image = renderer.rendering()
            
        case 1:
            renderer.currentShader = shaderList[1]
            self.renderer.renderParams.renderingMethod = sender.selectedSegment.toUInt8()
            renderer.resetMetalFunctions()
            outputView.image = renderer.rendering()
            
        case 2:
            renderer.currentShader = shaderList[2]
            self.renderer.renderParams.renderingMethod = sender.selectedSegment.toUInt8()
            renderer.resetMetalFunctions()
            outputView.image = renderer.rendering()
            
        case 3:
            // the first 3 items of shaderList is presetted function
            let menuItems = createMenuItems(from: Array(shaderList.dropFirst(3)))
            
            let menu = NSMenu()
            for menuItem in menuItems {
                menu.addItem(menuItem)
                
            }
            
            let position = sender.convert(sender.bounds, to: nil)
            print(position)
            menu.popUp(positioning: nil, at: NSPoint(x: position.maxX - 100, y: position.minY - 10), in: sender.window?.contentView)
            
        default:
            break
        }
        
        
    }
    
    
    @objc func selectShader(_ sender: NSMenuItem) {
        let shaderIndex = sender.tag + 3
        renderer.currentShader = shaderList[shaderIndex]
        renderer.resetMetalFunctions()
        outputView.image = renderer.rendering()
    }
    
    func createMenuItems(from shaders: [ShaderManage]) -> [NSMenuItem] {
        var rootMenuItems: [NSMenuItem] = []
        var menuItemMap: [String: NSMenuItem] = [:]
        
        var itemIndex = 0
        
        for shader in shaders {
            let pathComponents = shader.location.split(separator: "/")
            var currentMenu: NSMenu? = nil
            
            for (index, component) in pathComponents.enumerated() {
                let isLastComponent = index == pathComponents.count - 1
                let key = pathComponents.prefix(index + 1).joined(separator: "/")
                
                if let existingMenuItem = menuItemMap[key] {
                    currentMenu = existingMenuItem.submenu
                } else {
                    if isLastComponent {
                        let leafMenuItem = NSMenuItem(title: shader.functionLabel, action: #selector(selectShader(_:)), keyEquivalent: "")
                        
                        
                        let multiLineString = shader.functionLabel
                        let attributedString = NSAttributedString(string: multiLineString)

                        
                        // 2行目のテキストの属性を設定
                        let additionalInfoString = "\n    " + shader.description + "\n    " + shader.authorName
                        let additionalInfoAttributes: [NSAttributedString.Key: Any] = [
                            .font: NSFont.systemFont(ofSize: NSFont.systemFontSize),
                            .foregroundColor: NSColor.systemGray
                        ]
                        let additionalInfoAttributedString = NSAttributedString(string: additionalInfoString, attributes: additionalInfoAttributes)
                        
                        
                        let finalAttributedString = NSMutableAttributedString()
                  
                        finalAttributedString.append(attributedString)
                        finalAttributedString.append(additionalInfoAttributedString)
                        
                        // Set attributedTitle with multi-line string
                        leafMenuItem.attributedTitle = finalAttributedString
                        
                        leafMenuItem.tag = itemIndex
                        itemIndex += 1
                        
                        if index == 0 {
                            rootMenuItems.append(leafMenuItem)
                        } else {
                            currentMenu?.addItem(leafMenuItem)
                        }
                    } else {
                        let newMenuItem = NSMenuItem(title: String(component), action: nil, keyEquivalent: "")
                        let newSubmenu = NSMenu(title: String(component))
                        
                        newMenuItem.submenu = newSubmenu
                        
                        if index == 0 {
                            rootMenuItems.append(newMenuItem)
                        } else {
                            currentMenu?.addItem(newMenuItem)
                        }
                        
                        menuItemMap[key] = newMenuItem
                        currentMenu = newSubmenu
                    }
                }
            }
        }
        
        return rootMenuItems
    }
    
    /// Close the current session
    public func closeCurrentSession() -> Bool{
        let alert = NSAlert()
        alert.messageText = "This operation will close the current session."
        alert.informativeText = "Do you want to procees?"
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .warning
        
        let response = alert.runModal()
        switch response {
        case .alertFirstButtonReturn:
            filePackage = nil
            renderer.mainTexture = nil
            renderer.resetRotation()
            fileListTable.reloadData()
            pathField.stringValue = ""
            outputView.image = nil
            Logger.logPrintAndWrite(message: "Close the current session.")
            
            
            return true
            
        case .cancel:
            return false
            
        default:
            return false
        }
    }

    
    // MARK: - Rotate Function
    @IBAction func rotateButton(_ sender: NSButton) {
        switch sender.identifier?.rawValue {
        case "Clock":
            rotateModel(deltaAxisX: 0, deltaAxisY: 0, deltaAxisZ: -90)
            return
        case "Counter":
            rotateModel(deltaAxisX: 0, deltaAxisY: 0, deltaAxisZ: 90)
            return
            
        case "R90":
            rotateModel(deltaAxisX: 0, deltaAxisY: 90, deltaAxisZ: 0)
            return
        case "T90":
            rotateModel(deltaAxisX: 90, deltaAxisY: 0, deltaAxisZ: 0)
            return
            
            
        case "Center":
            renderer.renderParams.translationX = 0
            renderer.renderParams.translationY = 0
            outputView.image = renderer.rendering()
            return
            
        default:
            break
        }
        
        renderer.resetRotation()
        
        
        switch sender.identifier?.rawValue {
        case "Anterior":
            rotateModel(deltaAxisX: 0, deltaAxisY: 0, deltaAxisZ: 0)
        case "Posterior":
            rotateModel(deltaAxisX: 0, deltaAxisY: 180, deltaAxisZ: 0)
            
        case "Top":
            rotateModel(deltaAxisX: -90, deltaAxisY: 0, deltaAxisZ: 0)
        case "Bottom":
            rotateModel(deltaAxisX: 90, deltaAxisY: 0, deltaAxisZ: 0)
        case "Left":
            rotateModel(deltaAxisX: 0, deltaAxisY: 90, deltaAxisZ: 0)
        case "Right":
            rotateModel(deltaAxisX: 0, deltaAxisY: -90, deltaAxisZ: 0)
            
        default:
            break
        }
        
        
    
    }
    
    func rotateModel(withQuaternion quat:simd_quatf, performRendering:Bool = true){
        renderer.rotateModelTo(quaternion: quat)
        
        
        let eular = quatToEulerAngles(self.renderer.quaternion) * 180.0 / PI
        let normals = self.renderer.quaternion.act(float3(0, 0, 1))
        
        if (Thread.current.isMainThread){
            eularX.floatValue = eular.z
            eularY.floatValue = eular.x
            eularZ.floatValue = eular.y
            normalVecField.stringValue = "Normal Vector: \(normals.stringValue)"
            normalVecField.sizeToFit()
        }else{
            DispatchQueue.main.sync {
                eularX.floatValue = eular.z
                eularY.floatValue = eular.x
                eularZ.floatValue = eular.y
                normalVecField.stringValue = "Normal Vector: \(normals.stringValue)"
                normalVecField.sizeToFit()
            }
        }
        
        
        if(performRendering){
            outputView.image = renderer.rendering()
        }
    }
    
    /// rotate model by eular angles
    /// - Parameters:
    ///   - deltaAxisX: eular angle
    ///   - deltaAxisY: eular angle
    ///   - deltaAxisZ: eular angle
    ///   - performRendering: default value is true. set this parameter to false when rotate in second thread
    func rotateModel(deltaAxisX: Float, deltaAxisY:Float, deltaAxisZ:Float, performRendering:Bool = true){
        renderer.rotateModel(deltaX: deltaAxisX, deltaY: deltaAxisY, deltaZ: deltaAxisZ)
        
        let eular = quatToEulerAngles(renderer.quaternion) * 180.0 / PI
        
        let normals = renderer.quaternion.act(float3(0, 0, 1))
        
        if (Thread.current.isMainThread){
            eularX.floatValue = eular.z
            eularY.floatValue = eular.x
            eularZ.floatValue = eular.y
            
            normalVecField.stringValue = "Normal Vector: \(normals.stringValue)"
            normalVecField.sizeToFit()
            
        }else{
            print("not in thread")
            DispatchQueue.main.sync {
                eularX.floatValue = eular.z
                eularY.floatValue = eular.x
                eularZ.floatValue = eular.y
                
                normalVecField.stringValue = "Normal Vector: \(normals)"
                normalVecField.sizeToFit()
            }
        }
        
        if(performRendering == true){
            outputView.image = renderer.rendering()
        }
        
    }
    
    
    @IBAction func rotateManually(_ sender: NSButton) {
        renderer.resetRotation()
        
        rotateModel(deltaAxisX: eularX.floatValue, deltaAxisY: eularY.floatValue, deltaAxisZ: eularZ.floatValue)
    }
    
    
    @IBAction func viewAround(_ sender: NSButton) {
        
        DispatchQueue.global(qos: .default).async{ [self] in
            
            for _ in 0...360{
                rotateModel(deltaAxisX: 0, deltaAxisY: 1, deltaAxisZ: 0, performRendering: false)
                DispatchQueue.main.sync {
                    outputView.image = renderer.rendering()
                }
            }
            
        }
    }
    
    
    @IBAction func copyImageToPasteboard(_ sender: Any) {
        let pasteboard = NSPasteboard.general
        pasteboard.declareTypes([.tiff], owner: nil)
        
        if let imageData = outputView.image?.tiffRepresentation{
            pasteboard.clearContents()
            pasteboard.setData(imageData, forType: NSPasteboard.PasteboardType(rawValue: "NSTIFFPboardType"))
        }
    }
    
    
    @IBAction func updateScaleResolution(_ sender: Any) {
        let xRes = self.xResolutionField.floatValue
        let yRes = self.yResolutionField.floatValue
        let zRes = self.zResolutionField.floatValue
        let unitString = self.scaleUnitField.stringValue
        let scaleLength = self.scalebarLengthField.integerValue
        
        renderer.imageParams.scaleX = xRes
        renderer.imageParams.scaleY = yRes
        renderer.imageParams.scaleZ = zRes
        renderer.imageParams.unit = unitString
        renderer.imageParams.scalebarLength = scaleLength
        
        
    }
    
    @IBAction func scaleFontSizeSliderChanged(_ sender: NSSlider) {
        renderer.imageParams.scaleFontSize = sender.floatValue
        outputView.image = renderer.rendering()
    }
    
    @IBAction func showIsortopicView(_ sender: Any) {
        let zscale = renderer.imageParams.scaleZ / renderer.imageParams.scaleX
        zScale_Slider.floatValue = zscale
        updateZscaleSlider(zScale_Slider)
    }
}


extension ViewController: ImageOptionViewProtocol, Segment3DProtocol{
    
    func applyParams(sender: NSViewController, params: ImageParameters) {
        // update params
        self.renderer.imageParams = params
        self.dismiss(sender)
        
        Logger.logPrintAndWrite(message: "Update image parameters")
        Logger.logPrintAndWrite(message: "  Display Range: \(renderer.imageParams.displayRanges)")
        Logger.logPrintAndWrite(message: "  Voxel resolution: X = \(renderer.imageParams.scaleX), Y = \(renderer.imageParams.scaleY), Z = \(renderer.imageParams.scaleZ) \(renderer.imageParams.unit)", level: .info)
        
    }
    
    func closeView(sender: NSViewController) {
        print(sender)
        self.dismiss(sender)
    }
    
    
    @IBAction func showImageOptionView(_ sender: Any) {
        guard let filePackage = filePackage else {return}
        
        let imageOptionView = self.storyboard!.instantiateController(withIdentifier:"imageOptionView") as! ImageOptionView
        
        imageOptionView.delegate = self
        imageOptionView.filePackage = filePackage
        imageOptionView.renderer = self.renderer
        imageOptionView.imageParams = self.renderer.imageParams
        imageOptionView.device = renderer.device
        imageOptionView.cmdQueue = renderer.cmdQueue
        
        self.presentAsSheet(imageOptionView)
    }
    
    
    override func shouldPerformSegue(withIdentifier identifier: NSStoryboardSegue.Identifier, sender: Any?) -> Bool {
        guard let _ = filePackage else{
            Dialog.showDialog(message: "Please load images at first.")
            return false
        }
        return true
    }
    
    override func prepare(for segue: NSStoryboardSegue, sender: Any?) {
        if let filePackage = filePackage {
            
            
            if segue.identifier == "segment3DSegue" {
                let segmentView = segue.destinationController as! Segment3DController
                
                segmentView.title = "Segment 3D"
                segmentView.delegate = self
                segmentView.device = renderer.device
                segmentView.cmdQueue = renderer.cmdQueue
                segmentView.lib = renderer.mtlLibrary
                
                segmentView.renderer = SegmentRenderer(device: renderer.device, cmdQueue: renderer.cmdQueue, mtlLib: renderer.mtlLibrary)
                segmentView.renderer?.mainTexture = self.renderer.mainTexture
                segmentView.renderer?.renderModelParams = self.renderer.renderParams
                segmentView.renderer?.imageParams = self.renderer.volumeData
                segmentView.renderer.imageParams?.outputImageHeight = self.renderer.volumeData.inputImageHeight
                segmentView.renderer.imageParams?.outputImageWidth = self.renderer.volumeData.inputImageWidth
                
                segmentView.mainView = self
                
                
                let dirPath = pathField.stringValue
                let workingDir = URL(fileURLWithPath: dirPath, isDirectory: true)
                
                segmentView.filePackage = filePackage
                
                segmentView.workingDir = workingDir
                segmentView.fileType = filePackage.fileType
                segmentView.fileList = filePackage.fileList
                
                segmentView.voxelSize = renderer.imageParams.scaleX
                segmentView.voxelUnit = renderer.imageParams.unit
                segmentView.originalResolutionZ = renderer.imageParams.scaleZ

                
            }
            
        }else{
            return
            
        }
        
    }
}

extension ViewController: ValidatingTextFieldDelegate {
    func textFieldDidEndEditing(sender: ValidatingTextField, oldValue: Any, newValue: Any) {
        print(sender.inputValueType.rawValue)
        switch sender.inputValueType{
        case .String:
            break
        case .Int:
            break
        case .Float:
//            updateSliceAndScale(currentSliceToMax: false)
            break
        default:
            break
        }
        
        switch sender.identifier?.rawValue{
        case "scale":
            scale_Slider.floatValue = newValue as! Float
            renderer.renderParams.scale = newValue as! Float
            outputView.image = renderer.rendering()
            
        case "zscale":
            zScale_Slider.floatValue = newValue as! Float
            renderer.renderParams.zScale = newValue as! Float
            updateSliceAndScale(currentSliceToMax: true)
            outputView.image = renderer.rendering()
            
        case "slice_current":
            let no = Int(newValue as! UInt)
            slice_Slider.integerValue = no
            renderer.renderParams.sliceNo = no.toUInt16()
            updateSliceAndScale(currentSliceToMax: false)
            outputView.image = renderer.rendering()
            
            
        default:
            break
        }
    }
}

extension ViewController: TCPServerDelegate{
    func startDataTransfer(sender: TCPServer) {
        if let _ = renderer.mainTexture {
            if !closeCurrentSession(){
                sender.stop()
                return
            }else{
                sender.sendVersionInfoToStartTransferSession()
            }
        }else{
            sender.sendVersionInfoToStartTransferSession()
        }
    }
}
