//
//  FileListTable.swift
//  Acto3D
//
//  Created by Naoki TAKESHITA on 2021/12/18.
//

import Foundation
import Cocoa
import simd



extension ViewController:NSTableViewDataSource, NSTableViewDelegate{

    func numberOfRows(in tableView: NSTableView) -> Int {
        
        if(tableView.tag == 0){
            guard let filePackage = filePackage else {
                return 0
            }
            
            return filePackage.fileList.count
            
        }else if(tableView.tag == 1){
            
        }else if(tableView.tag == 2){
            return renderer.pointClouds.pointSet.count
        }
        
        return 0
        
    }
    
    func tableView_fileList(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        
        guard let filePackage = filePackage else {return nil}
        
        let workingDir = filePackage.fileDir // URL(fileURLWithPath: pathField.stringValue, isDirectory: true)
        let filePath = filePackage.fileDir.appendingPathComponent(filePackage.fileList[row])

        
        var fileSize = 0
        var w = 0
        var h = 0
        
        if(filePackage.fileType == .multiFileStacks){
            do {
                let attribute = try FileManager.default.attributesOfItem(atPath: filePath.path)
                
                // Filesize
                fileSize = attribute[FileAttributeKey.size] as! Int
                
                // Width & Height
                if let imageSource = CGImageSourceCreateWithURL(filePath as CFURL, nil) {
                    if let imageProperties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as Dictionary? {
                        w = imageProperties[ kCGImagePropertyPixelWidth] as! Int
                        h = imageProperties[kCGImagePropertyPixelHeight] as! Int
                    }
                }
                
            } catch {
                print("File attributes cannot be read")
            }
        }
        
        switch tableColumn?.title {
        case "Name":
            return filePackage.fileList[row]
            
        case "Size":
            if(filePackage.fileType == .multiFileStacks){
                return "\(w) x \(h) px, \(fileSize / 1000) kb"
            }else{
                if(row == 0){
                    let workingDir = filePackage.fileDir
                    
                    let filePathMTIF = workingDir.appendingPathComponent(filePackage.fileList[0])
                    
                    
                    guard let mTiff = MTIFF(fileURL: filePathMTIF) else{
                        print("error in loading file")
                        Logger.log(message: "⚠️ Error in loading file.", level: .error, writeToLogfile: true)
                        
                        return nil
                    }
                    
                    mTiff.getMetaData()
                    
                    return "\(mTiff.width) x \(mTiff.height) px"
                }else{
                    return "---"
                }
            }
        default:
            return nil
        }
        
    }
    
    func tableView_pointSet(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        switch tableColumn?.title {
        case "No":
            return row
        case "Coordinate":
            return self.renderer.pointClouds.pointSet[row].stringValue
        default:
            return nil
        }
        
    }
    
    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        
        if(tableView.tag == 0){
            return tableView_fileList(tableView, objectValueFor: tableColumn, row: row)
        }else if(tableView.tag == 1){
            
        }else if(tableView.tag == 2){
            return tableView_pointSet(tableView, objectValueFor: tableColumn, row: row)
        }
        return nil
        
    }
    
    func tableView_fileList(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        guard let filePackage = filePackage else {return false}
        
        if(filePackage.fileType == .multiFileStacks){
            
            
            let filePath = filePackage.fileDir.appendingPathComponent(filePackage.fileList[row])
            
            imgPreview.image = NSImage(contentsOf: filePath)
            
        }else if(filePackage.fileType == .singleFileMultiPage){
            
            let filePathMTIF = filePackage.fileDir.appendingPathComponent(filePackage.fileList[0])
            
            guard let mTiff = MTIFF(fileURL: filePathMTIF) else{
                print("error in loading file")
                Logger.log(message: "⚠️ Error in loading file.", level: .error, writeToLogfile: true)
                return true
            }
            
            mTiff.getMetaData()
            
            imgPreview.image = mTiff.image(pageNo: row)
            
        }
        
        return true
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        guard let table = notification.object as? NSTableView else {return}
        
        if table.tag == 2{
            if(pointSetTable.selectedRowIndexes.count > 0){
                removeSelectedButton.isEnabled = true
            }else{
                removeSelectedButton.isEnabled = false
            }
            
            if(pointSetTable.selectedRowIndexes.count == 2){
                var index:[Int] = []
                for (_, i) in pointSetTable.selectedRowIndexes.enumerated() {
                    index.append(i)
                }
                
                let point1 = renderer.pointClouds.pointSet[index[0]]
                let point2 = renderer.pointClouds.pointSet[index[1]]
                calculateDistance(p1: point1, p2: point2)
            }else{
                distane_2pointsField.stringValue = "Distance:"
                distane_2pointsField.sizeToFit()
            }
            
            if (pointSetTable.selectedRowIndexes.count == 3){
                planeSectionButton1.isEnabled = true
                planeSectionButton2.isEnabled = true
            }else{
                planeSectionButton1.isEnabled = false
                planeSectionButton2.isEnabled = false
            }
            
            if (renderer.pointClouds.pointSet.count > 0){
                removeAllButton.isEnabled = true
            }else{
                removeAllButton.isEnabled = false
            }
        }
    }
    
    
    @IBAction func removeSelectedPointSet(_ sender:NSButton){
        var index:[Int] = []
        for (_, i) in pointSetTable.selectedRowIndexes.enumerated() {
            index.append(i)
        }
        
        index.reversed().forEach {
            renderer.pointClouds.pointSet.remove(at: $0)
        }
        
        pointSetTable.reloadData()
        
        removeSelectedButton.isEnabled = false
        
        if (renderer.pointClouds.pointSet.count > 0){
            removeAllButton.isEnabled = true
        }else{
            removeAllButton.isEnabled = false
        }
        
            outputView.image = renderer.rendering()
    }
    
    
    @IBAction func removeAllPointSet(_ sender:Any){
        renderer.pointClouds = PointClouds()
        pointSetTable.reloadData()
        
        removeSelectedButton.isEnabled = false
        removeAllButton.isEnabled = false
        planeSectionButton1.isEnabled = false
        
        outputView.image = renderer.rendering()
    }
    
    func tableView_pointSet(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        renderer.pointClouds.selectedIndex = row.toUInt16()
        
        let scale_Z = renderer.renderParams.zScale;
        
        let matrix_centering_toView = float4x4(float4(1, 0, 0, 0),
                                               float4(0, 1, 0, 0),
                                               float4(0, 0, 1, 0),
                                               float4(renderer.volumeData.inputImageWidth.toFloat() / 2.0,
                                                      renderer.volumeData.inputImageHeight.toFloat() / 2.0,
                                                      renderer.volumeData.inputImageDepth.toFloat() * scale_Z / 2.0, 1))
        
        let radius:Float = renderer.renderParams.sliceMax.toFloat() / 2.0
        let directionVector = float3(0, 0, 1)
        let directionVector_rotate = renderer.quaternion.act(directionVector)
        
        let c1 = renderer.pointClouds.pointSet[row]
        let c2 = matrix_centering_toView.inverse * float4(c1, 1)
        
        let ln = directionVector_rotate.x * c2.x + directionVector_rotate.y * c2.y + directionVector_rotate.z * c2.z
        slice_Slider.floatValue = radius - ln
        renderer.renderParams.sliceNo = slice_Slider.integerValue.toUInt16()
        
        outputView.image = renderer.rendering()
        
        return true
    }

    
    
    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        
        if(tableView.tag == 0){
            return tableView_fileList(tableView, shouldSelectRow: row)
        }else if(tableView.tag == 1){
            return true
        }else if(tableView.tag == 2){
            return tableView_pointSet(tableView, shouldSelectRow: row)
        }
        return true
    }
    
    
}
