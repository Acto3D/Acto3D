//
//  AppDelegate.swift
//  Acto3D
//
//  Created by Naoki TAKESHITA on 2021/12/18.
//

import Cocoa

protocol MenuAction:AnyObject {
    func menuAction(sender : NSMenuItem)
}

@main



class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    
    @IBOutlet weak var performanceMenu:NSMenu!
    @IBOutlet weak var debug_mode: NSMenuItem!
    @IBOutlet weak var allow_tcp: NSMenuItem!
    @IBOutlet weak var portnumber: NSMenuItem!
    @IBOutlet weak var ipaddress: NSMenuItem!
    @IBOutlet weak var debug_menu: NSMenu!
    @IBOutlet weak var netConnection: NSMenu!
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
        performanceMenu.delegate = self
        debug_menu.delegate = self
        netConnection.delegate = self
        
        // Obtein command line arguments
        let arguments = CommandLine.arguments
        for argument in arguments {
        }

        if arguments.contains("--input") {
        }
        

    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
    
    func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        Logger.logPrintAndWrite(message: filename)
        return true
    }
    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        Logger.logPrintAndWrite(message: filenames[0])
    }

    @IBAction func quit(_ sender: Any) {
//        let windowCount = NSApplication.shared.windows.count
        
        // find a main view controller in window
        var mainViewController:ViewController?
        for window in NSApplication.shared.windows{
            if let mainVC = window.contentViewController as? ViewController{
                mainViewController = mainVC
            }
            if let imageOptionView = window.contentViewController as? ImageOptionView{
                imageOptionView.delegate?.closeView(sender: imageOptionView)
            }
        }
        
        guard let _ = mainViewController else{
            NSApplication.shared.terminate(self)
            return
        }
        
        NSApplication.shared.terminate(self)
        
    }
    
    @IBAction func menuAction(_ sender: NSMenuItem) {
        // find a main view controller in window
        var mainViewController:ViewController?
        for window in NSApplication.shared.windows{
            if let mainVC = window.contentViewController as? ViewController{
                mainViewController = mainVC
            }
        }
        
        if let mainViewController = mainViewController{
            mainViewController.menuAction(sender)
        }
    }
    
    
    func menuWillOpen(_ menu: NSMenu) {
        ipaddress.isEnabled = false
        switch menu.identifier?.rawValue {
        case "debug":
            debug_mode.state = AppConfig.IS_DEBUG_MODE ? .on : .off
            
        case "connect":
            allow_tcp.state = AppConfig.ACCEPT_TCP_CONNECTION ? .on : .off
            portnumber.title = "Change Port: \(AppConfig.TCP_PORT)"
            
            // 使用例
            if let localIPAddress = TCPServer.getLocalIPAddress(){
                ipaddress.title = "IP Address: \(localIPAddress) (Click To Copy)"
                ipaddress.identifier = NSUserInterfaceItemIdentifier(localIPAddress)
                ipaddress.target = self
                ipaddress.action = #selector(copyIPAddress(_:))
                ipaddress.isEnabled = true
                
            } else {
                ipaddress.title = "No Network Connection"
                ipaddress.identifier = nil
                ipaddress.isEnabled = false
                ipaddress.action = nil
            }
            
            
        case "performance_test":
            menu.removeAllItems()
            
           let xy_size = [480, 720, 960, 1200, 1440, 1680, 1920]
           let z_size = [900, 900, 900, 900, 900, 900, 900]
            
            
            for i in 0..<xy_size.count{
                let sizeGB = Double(xy_size[i]*xy_size[i]*z_size[i]*4)/1024.0/1024.0/1024.0
                let item = NSMenuItem(title: "\(xy_size[i]) x \(xy_size[i]) x \(z_size[i]) x 4 (\(String(format: "%.1f", sizeGB)) GB)", action: #selector(menuAction(_:)), keyEquivalent: "")
            
                item.identifier = NSUserInterfaceItemIdentifier("performance_test_item")
                item.tag = i
                item.target = self
                
                menu.addItem(item)
            }
            
            menu.addItem(NSMenuItem.separator())
            
            let item = NSMenuItem(title: "Start test...", action: #selector(menuAction(_:)), keyEquivalent: "")
        
            item.identifier = NSUserInterfaceItemIdentifier("performance_test_item")
            item.tag = -1
            item.target = self
            
            menu.addItem(item)
          
        default:
            break
        }
    }
    

    @objc func copyIPAddress(_ sender: NSMenuItem) {
        if let ipAddress = sender.identifier?.rawValue {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(ipAddress, forType: .string)
        }
    }
}

