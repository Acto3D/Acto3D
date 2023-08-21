//
//  Logger.swift
//  Acto3D
//
//  Created by Naoki TAKESHITA on 2021/12/18.
//
//
import Foundation
import Cocoa

class Logger: NSObject, NSTableViewDataSource, NSTableViewDelegate, NSPopoverDelegate{
    enum Level: String {
        case info
        case warning
        case error
        case coordinate
    }
    
    struct LogEntry{
        let level: Level
        let message: String
    }
    
    
    private static var timers: [String: Date] = [:]
    
    static let shared = Logger()
    
    var table:NSTableView!
    
    /// message array for showing tableView
    private var logEntries: [LogEntry] = []
    
    private var logDir: URL!
    private var logFile: URL!
    
    
    private override init() {
        super.init()
        
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
        log(message: "Created a log file", level: .info, writeToLogfile: true, onlyToFile: true)
        
        deleteOldLogFiles()
    }
    
    private func deleteOldLogFiles() {
        let fileManager = FileManager.default
        
        do {
            // Get all files in the directory
            var fileURLs = try fileManager.contentsOfDirectory(at: logDir, includingPropertiesForKeys: [.creationDateKey])
            
            // Sort files by creation date, oldest first
            fileURLs.sort(by: { (url1, url2) -> Bool in
                do {
                    let values1 = try url1.resourceValues(forKeys: [.creationDateKey])
                    let values2 = try url2.resourceValues(forKeys: [.creationDateKey])
                    return values1.creationDate! < values2.creationDate!
                } catch {
                    return false
                }
            })
            
            // If there are more files than CONST_KEEP_LOG_NUM, delete the oldest ones
            while fileURLs.count > AppConfig.KEEP_LOG_NUM {
                let fileURLToDelete = fileURLs.removeFirst()
                try fileManager.removeItem(at: fileURLToDelete)
                
                log(message: "Deleted old log file: \(fileURLToDelete.lastPathComponent)", level: .info, writeToLogfile: true, onlyToFile: true)
            }
        } catch {
            log(message: "Error while deleting old log files: \(error.localizedDescription)", level: .error, writeToLogfile: true, onlyToFile: true)
        }
    }

    
    
    
    private func setTableView(_ tableView: NSTableView) {
        self.table = tableView
        self.table?.dataSource = self
        self.table?.delegate = self
        
        let column = tableView.tableColumns[0]
        column.width = tableView.frame.width - 12
        
        tableView.tableColumns[0].resizingMask = .autoresizingMask
    }
    
    
    static func setTableView(_ tableView: NSTableView){
        shared.setTableView(tableView)
    }
    
    private func log(message: String, level:Level, writeToLogfile:Bool = false, onlyToFile:Bool = false){
        if(!onlyToFile){
            let msg = dateStringForView + " " + message
            logEntries.append(LogEntry(level: level, message: msg))
            
            table.reloadData()
            table.scrollRowToVisible(logEntries.count - 1)
        }
        
        if(writeToLogfile){
            
            let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .medium)
            let logMessage = "[\(timestamp)][\(level.rawValue)] \(message)\n"
            
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
    }
    
    static func log(message: String, level:Level = .info, writeToLogfile:Bool = false, onlyToFile:Bool = false){
        shared.log(message: message, level:level, writeToLogfile: writeToLogfile, onlyToFile: onlyToFile)
    }
    static func logPrintAndWrite(message: String, level:Level = .info){
        shared.log(message: message, level:level, writeToLogfile: true, onlyToFile: false)
    }
    static func logOnlyToFile(message: String, level:Level = .info){
        shared.log(message: message, level:level, writeToLogfile: true, onlyToFile: true)
    }
    
    
    private var dateStringForView: String {
        let date = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
    private var dateStringForLogfile: String {
        let date = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HH-mm-ss"
        return formatter.string(from: date)
    }
    
    
    
    private func clearLog(){
        logEntries.removeAll()
        table.reloadData()
    }
    static func clearLog(){
        shared.clearLog()
    }
    
    /// If the end of the entries is a log showing coordinates, update it
    private func logCoorginate(message: String){
        if(logEntries.last?.level == .coordinate){
            logEntries.removeLast()
            log(message: message, level: .coordinate, writeToLogfile: false)
        }else{
            log(message: message, level: .coordinate, writeToLogfile: false)
        }
    }
    static func logCoorginate(message: String){
        shared.logCoorginate(message: message)
    }
    
    
    
    
    
    private func showLogDirectory() {
        var isDir: ObjCBool = false
        
        if FileManager.default.fileExists(atPath: logFile.path, isDirectory: &isDir) {
            NSWorkspace.shared.activateFileViewerSelecting([logFile])
        }
    }
    
    static func showLogDirectory(){
        shared.showLogDirectory()
    }
    
    //MARK: Timer
    static func start(for key: String) {
        timers[key] = Date()
    }

    static func stop(for key: String) -> Double {
        guard let startDate = timers[key] else {
            print("No timer found for key \(key)")
            return 0
        }
        
        let timeInterval = Date().timeIntervalSince(startDate)
        print("Time elapsed for \(key): \(timeInterval * 1000) ms")
        
        timers.removeValue(forKey: key)
        
        return timeInterval * 1000
    }
    
}

//MARK: - TableView
extension Logger{
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return logEntries.count
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let view = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "Cell"), owner: self) as? NSTableCellView
        
        // Set the text of the cell
        view?.textField?.stringValue = logEntries[row].message
        
        // Set the tooltip of the cell
        view?.textField?.toolTip = logEntries[row].message
        
        
        view?.textField?.lineBreakMode = .byWordWrapping
        view?.textField?.usesSingleLineMode = false
        view?.textField?.cell?.wraps = true
//        print(view?.textField?.frame)
        
        
        return view
    }
    
    /// show popover for context
    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
         let popover = NSPopover()
         popover.behavior = .transient
         
        let label = NSTextField(wrappingLabelWithString: logEntries[row].message)
         label.lineBreakMode = .byWordWrapping
         label.font = NSFont(name: "PT Mono Bold", size: 14)
         
         let maxLabelWidth = tableView.bounds.width - 50
         let requiredSize = label.sizeThatFits(NSSize(width: maxLabelWidth, height: CGFloat.greatestFiniteMagnitude))
         
         // Calculate the size of the popover's content view
         let padding: CGFloat = 10
         let contentWidth = requiredSize.width + 2 * padding
         let contentHeight = requiredSize.height + 2 * padding
         
         let explanationViewController = NSViewController()
         let contentRect = NSRect(x: 0, y: 0, width: contentWidth, height: contentHeight)
         explanationViewController.view = NSView(frame: contentRect)
         
         label.frame = NSRect(x: padding, y: padding, width: requiredSize.width, height: requiredSize.height)
         
         popover.contentViewController = explanationViewController
         explanationViewController.view.addSubview(label)
       
        // Get the mouse location in screen coordinates
        let mouseLocationInScreenCoordinates = NSEvent.mouseLocation
        let mouseLocationInWindowCoordinates = tableView.window?.convertFromScreen(NSRect(origin: mouseLocationInScreenCoordinates, size: .zero)).origin ?? .zero
        let mouseLocationInViewCoordinates = tableView.convert(mouseLocationInWindowCoordinates, from: nil)
        
        //let positioningRect = NSRect(x: mouseLocationInViewCoordinates.x, y: mouseLocationInViewCoordinates.y, width: 1, height: 1)
        
        let cellRect = tableView.frameOfCell(atColumn: 0, row: row)
        
        popover.show(relativeTo: NSRect(x: mouseLocationInViewCoordinates.x, y: cellRect.midY, width: 1, height: 1), of: tableView, preferredEdge: .maxX)
        

        
        return true
    }
    
}
