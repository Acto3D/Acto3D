//
//  GlobalAlert.swift
//  Acto3D
//
//  Created by Naoki Takeshita on 2023/01/05.
//

import Foundation
import Cocoa

struct Dialog{
    
    static func showDialog(message:String, title:String = "Error", style:NSAlert.Style = .critical, level:Logger.Level = .info){
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "Close")
        alert.alertStyle = style
        
        let response = alert.runModal()
        if(response == .alertFirstButtonReturn){
         
        }
        
        DispatchQueue.main.async {
            Logger.logPrintAndWrite(message: message, level: level)
        }
    }
    
    static func showDialogWithDebug(message:String, functionName:String = #function, line:Int = #line){
        let alert = NSAlert()
        alert.messageText = "Error"
        alert.informativeText = "func: \(functionName), line: \(line) \n \(message)"
        alert.addButton(withTitle: "Close")
        alert.alertStyle = .critical

        let response = alert.runModal()
        if(response == .alertFirstButtonReturn){
            
        }
        
        DispatchQueue.main.async {
            Logger.logPrintAndWrite(message: "func: \(functionName), line: \(line) \n \(message)", level: .warning)
        }

    }
}
