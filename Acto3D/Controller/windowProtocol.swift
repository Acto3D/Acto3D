//
//  windowProtocol.swift
//  Acto3D
//
//  Created by Naoki TAKESHITA on 2021/12/18.
//

import Foundation
import Cocoa

extension ViewController: NSWindowDelegate{
    override func viewWillAppear() {
        self.view.window?.delegate = self
    }
    
    func windowWillClose(_ notification: Notification) {
        // terminate this app when window will close
        NSApplication.shared.terminate(self)
    }
}
