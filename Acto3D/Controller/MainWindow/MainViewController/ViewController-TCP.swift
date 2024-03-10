//
//  ViewController-TCP.swift
//  Acto3D
//
//  Created by Naoki Takeshita on 2024/03/11.
//

import Foundation
import Cocoa

extension ViewController{
    internal func startTcpServer(){
        AppConfig.ACCEPT_TCP_CONNECTION = true
        
        if self.tcpServer == nil{
            self.initTcpServer(with: 0)
            
        }else{
            self.tcpServer?.stop()
            autoreleasepool{
                self.tcpServer = nil
            }
            Logger.logPrintAndWrite(message: "Restarting TCP Server...")
            
            self.initTcpServer(with: 2)
        }
        
    }
    
    private func initTcpServer(with interval:TimeInterval = 0){
        DispatchQueue.global(qos: .default).async {[weak self] in
            Thread.sleep(forTimeInterval: interval)
            
            guard let tcpServer = TCPServer(port: AppConfig.TCP_PORT) else{
                Logger.logPrintAndWrite(message: "Failed in creating TCP connection.", level: .error)
                return
            }
            
            tcpServer.delegate = self
            tcpServer.renderer = self?.renderer
            tcpServer.vc = self
            tcpServer.start()
            
            self?.tcpServer = tcpServer
        }
    }
    
    internal func showChangePortDialog(){
        // Show dialog to change TCP port setting.
        let alert = NSAlert()
        alert.messageText = "Enter a new port number:"
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        alert.addButton(withTitle: "Reset to Default")
        
        let textField = ValidatingTextField(frame: NSRect(x: 0, y: 0, width: 90, height: 24))
        let defaultValue = AppConfig.TCP_PORT
        textField.integerValue = defaultValue.toInt()
        textField.inputValueType = .UInt16
        textField.alignment = .center
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .none
        formatter.usesGroupingSeparator = false
        textField.formatter = formatter
        
        let accessory = FlippedView(frame: NSRect(x: 0, y: 0, width: textField.frame.maxX, height: 50))
        accessory.addSubview(textField)
        
        accessory.adjustHeightOfView()
        
        alert.accessoryView = accessory
        
        let modalResult = alert.runModal()
        let firstButtonNo = NSApplication.ModalResponse.alertFirstButtonReturn.rawValue
        
        
        switch modalResult.rawValue {
        case firstButtonNo:
            if let _ = UInt16(textField.stringValue){
                AppConfig.TCP_PORT = UInt16(textField.integerValue)
                Logger.logPrintAndWrite(message: "New port number: \(AppConfig.TCP_PORT)")
            }else{
                Dialog.showDialog(message: "The port number is invalid.\nPlease enter a value between 0 and 65535.")
            }
            
        case firstButtonNo + 1:
            break
            
        case firstButtonNo + 2:
            AppConfig.TCP_PORT = 41233
            Logger.logPrintAndWrite(message: "New port number: \(AppConfig.TCP_PORT)")
            
        default:
            break
            
        }
    }
}


extension ViewController: TCPServerDelegate{
    func startDataTransfer(sender: TCPServer, connectionID: Int) {
        print("TCP responsed from Connection \(connectionID)")
        sender.sendVersionInfoToStartTransferSession(connectionID: connectionID)
    }
    
    func portInUse(sender: TCPServer, port: UInt16) {
        Logger.logPrintAndWrite(message: "Port(\(port)) already in use. Failed in creating TCP listener.")
        self.tcpServer = nil
    }
    
    func listenerInReady(sender: TCPServer, port: UInt16) {
        Logger.logPrintAndWrite(message: "Acto3D is accepting data input (Port: \(port))")
    }
}
