//
//  FileLoad.swift
//  Acto3D
//
//  Created by Naoki TAKESHITA on 2021/12/18.
//

import Foundation
import Cocoa

func getFilesFromDirectory(path: String, withAllowedExtensions extensions: [String]) -> [String]? {
    var fileNameList: [String] = []
    
    let enumerator = FileManager.default.enumerator(at: URL(fileURLWithPath: path),
                                                    includingPropertiesForKeys: [.isDirectoryKey],
                                                    options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants])
    for element in enumerator! {
        guard let url = element as? URL else { return nil }
        let resourceValue = try! url.resourceValues(forKeys: [.isDirectoryKey, .nameKey])
        
        if resourceValue.isDirectory == false, extensions.contains(url.pathExtension) {
            fileNameList.append(resourceValue.name!)
        }
    }
    
    fileNameList.sort()
    return fileNameList.isEmpty ? nil : fileNameList
}

func getDirectoryAndFilesWithPanel() -> (path: String, items:[String]?)? {
    let dialog = NSOpenPanel()
    dialog.title = "Choose Directory"
    dialog.showsResizeIndicator = true
    dialog.showsHiddenFiles = true
    dialog.allowsMultipleSelection = false
    dialog.canChooseDirectories = true
    dialog.canChooseFiles = false
    
    guard dialog.runModal() ==  NSApplication.ModalResponse.OK, let result = dialog.url else { return nil }
    let path = result.path
    let items = getFilesFromDirectory(path: path, withAllowedExtensions: ["tif", "tiff", "jpg", "png"])
    return (path, items)
}

func getDirectoryAndFilesWithDirectoryPath(dirPath: String) -> (path: String, items:[String]?)? {
    let items = getFilesFromDirectory(path: dirPath, withAllowedExtensions: ["tif", "tiff", "jpg", "png"])
    return (dirPath, items)
}

func getPathAndFileFromURL(_ url: URL) -> (path: String, item: String) {
    let path = "/" + url.pathComponents[1..<url.pathComponents.count-1].joined(separator: "/")
    let fileName = url.lastPathComponent
    return (path, fileName)
}

func getTiffFile() -> (path: String, item:String)? {
    let dialog = NSOpenPanel()
    dialog.title = "Choose TIFF File"
    dialog.showsResizeIndicator = true
    dialog.showsHiddenFiles = true
    dialog.allowsMultipleSelection = false
    dialog.canChooseDirectories = false
    dialog.allowedFileTypes = ["tif","tiff"]
    
    guard dialog.runModal() ==  NSApplication.ModalResponse.OK, let result = dialog.url else { return nil }
    return getPathAndFileFromURL(result)
}

func getTiffFileFromFile(filePath: String) -> (path: String, item:String)? {
    let url = URL(fileURLWithPath: filePath)
    return getPathAndFileFromURL(url)
}
