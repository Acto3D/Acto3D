//
//  Benchmark.swift
//  Acto3D
//
//  Created by Naoki Takeshita on 2022/08/07.
//

import Foundation
import Cocoa

class Benchmark {
    
    private var startTime: Date
    private var key: String
    
    init() {
        self.startTime = Date()
        self.key = ""
    }
    
    public func start(key: String){
        self.startTime = Date()
        self.key = key
        print(" [ \(key) ] start")
    }
    
    public func finish() {
        let elapsed = NSDate().timeIntervalSince(self.startTime) * 1000
        let formatedElapsed = String(format: "%.3f", elapsed)
        print("  ** time: \(formatedElapsed) ms.")
    }
    
    
}
