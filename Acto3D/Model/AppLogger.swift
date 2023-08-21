//
//  AppLogger.swift
//  Acto3D
//
//  Created by Naoki Takeshita on 2023/06/28.
//

import Foundation
import Cocoa

class AppLogger{
    // Singleton instance
    static let shared = AppLogger()
    
    private var logDir: URL!
    private var logFile: URL!
    
    private init() {
        guard let logDir = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first?.appendingPathComponent("Logs") else {
            print("Failed to find logs directory")
            return
        }
        
        self.logDir = logDir
        
        do {
            try FileManager.default.createDirectory(at: logDir, withIntermediateDirectories: true, attributes: nil)
        } catch {
            print("Error creating logs directory: \(error)")
            return
        }
        
        // Formatting the date for the file name
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd-HH-mm-ss"
        let dateString = dateFormatter.string(from: Date())
        
        // File URL for the log file
        self.logFile = logDir.appendingPathComponent("Acto3D-\(dateString).log")
    }
    
    func log(message: String) {
        guard let logFile = logFile else {
            print("Log file not available")
            return
        }
        
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .medium)
        let logMessage = "[\(timestamp)] \(message)\n"
        
        if let data = logMessage.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: logFile.path) {
                do {
                    let fileHandle = try FileHandle(forWritingTo: logFile)
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(data)
                    fileHandle.closeFile()
                } catch {
                    print("Error while writing to existing file: \(error)")
                }
            } else {
                do {
                    try data.write(to: logFile)
                } catch {
                    print("Error while creating new file: \(error)")
                }
            }
        }
    }
    static func log(message: String) {
        shared.log(message: message)
    }
    
    
    func showLogDir() {
        var isDir: ObjCBool = false
        
        if FileManager.default.fileExists(atPath: logDir.path, isDirectory: &isDir) {
            NSWorkspace.shared.activateFileViewerSelecting([logDir])
        }
    }
    
    static func showLogDir(){
        shared.showLogDir()
    }
}
