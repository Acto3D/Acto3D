//
//  FilePackage.swift
//  Acto3D
//
//  Created by Naoki Takeshita on 2023/06/14.
//

import Foundation
import Cocoa

struct FilePackage{
    /// stack files or tiff directory
    var fileDir:URL
    
    var fileType:FileType
    
    /// stack filenames. if single tiff file, fileList[0] is filename
    var fileList:[String]
    
    var parameterDir:URL?{
        get{
            return urlForDirectoryName(directoryName: "parameter")
        }
    }
    
    var workingDir:URL?{
        get{
            _ = Permission.checkPermission(url: fileDir)
            
            var dir:URL?
            if(fileType == .multiFileStacks){
                dir = fileDir
                
            }else if(fileType == .singleFileMultiPage){
                dir = fileDir.appendingPathComponent(fileList[0]).deletingPathExtension()
                
            }else{
                return nil
            }
            return dir
        }
    }
    
    private func urlForDirectoryName(directoryName:String) -> URL?{
        var dir:URL?
        _ = Permission.checkPermission(url: fileDir)
        
        if(fileType == .multiFileStacks){
            dir = fileDir.appendingPathComponent(directoryName)
            
        }else if(fileType == .singleFileMultiPage){
            dir = fileDir.appendingPathComponent(fileList[0]).deletingPathExtension().appendingPathComponent(directoryName)
            
        }else{
            return nil
        }
        
        guard let dir = dir else {return nil}
        
        let fileManager = FileManager.default
        do {
            try fileManager.createDirectory(at: dir, withIntermediateDirectories: true, attributes: nil)
        } catch {
            Dialog.showDialog(message: "failed to create directory: \(dir.path)")
            return nil
        }
        
        return dir
    }
    
    public func createSubdirectoryForUrl(url: URL, directoryName:String) -> URL{
        let fileManager = FileManager.default
        
        let newDirUrl = url.appendingPathComponent(directoryName)
        
        do {
            try fileManager.createDirectory(at: newDirUrl, withIntermediateDirectories: true, attributes: nil)
        } catch {
            Dialog.showDialog(message: "failed to create directory: \(newDirUrl.path)")
        }
        
        return newDirUrl
    }
    
    var snapshotDir:URL?{
        get{
            return urlForDirectoryName(directoryName: "snapshot")
        }
    }
    
    
    var movieDir:URL?{
        get{
            return urlForDirectoryName(directoryName: "movie")
        }
    }
    
    var segmentDir:URL?{
        get{
            return urlForDirectoryName(directoryName: "segment")
        }
    }
    
    var tmpDir:URL?{
        get{
            return urlForDirectoryName(directoryName: "tmp")
        }
    }
    
    var exportDir:URL?{
        get{
            return urlForDirectoryName(directoryName: "export")
        }
    }
    
    public func openUrlInFinder(url: URL){
        var isDir:ObjCBool  = false
        
        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }
        
    }
    
    /// get file list of JSON and thumbnails if available
    public func enumerateParameterFiles() -> [(String, NSImage?)]?{
        guard let paramDir = self.parameterDir else {return nil}
        
        let enumerator = FileManager.default.enumerator(at: paramDir,
                                                        includingPropertiesForKeys: [.isDirectoryKey],
                                                        options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]) {
            (url, error) -> Bool in
            print(error)
            return true
        }
        
        var jsonFileList:[String] = []
        
        for element in enumerator! {
            guard let url = element as? URL else { return nil }
            let resourceValue = try! url.resourceValues(forKeys: [.isDirectoryKey, .nameKey, .isHiddenKey])
            
            if resourceValue.isDirectory == false{
                if (url.pathExtension == "json") {
                    jsonFileList.append(resourceValue.name!)
                }
            }
        }
        
        jsonFileList.sort()
        
        var fileSet:[(String, NSImage?)] = []
        
        for fileName in jsonFileList{
            let thumbnailForItem = paramDir.appendingPathComponent(fileName).deletingPathExtension().appendingPathExtension("jpg")
            
            let fileManager = FileManager.default
            
            if(fileManager.fileExists(atPath: thumbnailForItem.path)){
                let thumbnailImage = NSImage(contentsOf: thumbnailForItem)
                thumbnailImage?.size = NSSize(width: 128, height: 128)
                
                fileSet.append((fileName, thumbnailImage))
                
            }else{
                fileSet.append((fileName, nil))
                
            }
        }
        
        if(jsonFileList.count == 0){
            return nil
        }
        
        return fileSet
        
    }
    
    /// get filename list of JSON
    public func getJsonFiles(url: URL) -> [String]{
        
        let enumerator = FileManager.default.enumerator(at: url,
                                                        includingPropertiesForKeys: [.isDirectoryKey],
                                                        options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]) {
            (url, error) -> Bool in
            print(error)
            return true
        }
        
        var jsonFileList:[String] = []
        
        for element in enumerator! {
            guard let url = element as? URL else { return [] }
            let resourceValue = try! url.resourceValues(forKeys: [.isDirectoryKey, .nameKey, .isHiddenKey])
            
            if resourceValue.isDirectory == false{
                if (url.pathExtension == "json") {
                    jsonFileList.append(resourceValue.name!)
                }
            }
        }
        
        jsonFileList.sort()
        
        return jsonFileList
        
    }
    
}
