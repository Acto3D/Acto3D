//
//  NSDate+TimeStamp.swift
//  Acto3D
//
//  Created by Naoki Takeshita on 2022/02/28.
//

import Foundation

extension NSDate{
    func timeStampYYYYMMDDHHMMSS() -> String{
        let timeInterval = NSDate().timeIntervalSince1970
        let myTimeInterval = TimeInterval(timeInterval)
        let time = NSDate(timeIntervalSince1970: TimeInterval(myTimeInterval))
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HH_mm_ss"
        let timestamp = formatter.string(from: time as Date)
        return timestamp
    }
}
