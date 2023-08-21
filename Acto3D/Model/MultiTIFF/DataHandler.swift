//
//  DataHandler.swift
//
//  Created by Naoki Takeshita on 2022/01/16.
//

import Foundation



extension Data{
    func getStringWithRange(start:Int, length:Int) -> String{
        return self[start...start+length-1].map{String(Unicode.Scalar($0))}.joined()
    }
    
    var reversedBytes: [UInt8] {
            var values = [UInt8](repeating: 0, count: count)
            copyBytes(to: &values, count: count)
            return values.reversed()
    
    }
    
    
    var reversedData: Data {
          return Data(bytes: reversedBytes, count: count)
      }
    
    func uint32(isBigEndian:Bool = false) -> uint32{
        return isBigEndian ?
        UInt32(bigEndian: withUnsafeBytes { $0.load(as: UInt32.self) }) :
        UInt32(withUnsafeBytes { $0.load(as: UInt32.self) })
    }
    
    func uint16(isBigEndian:Bool = false) -> uint16{
        return isBigEndian ?
        UInt16(bigEndian: withUnsafeBytes { $0.load(as: UInt16.self) }) :
        UInt16(withUnsafeBytes { $0.load(as: UInt16.self) })
    }
    
    
    func uint64(isBigEndian:Bool = false) -> uint64{
        return isBigEndian ?
        UInt64(bigEndian: withUnsafeBytes { $0.load(as: UInt64.self) }) :
        UInt64(withUnsafeBytes { $0.load(as: UInt64.self) })
    }
    
    func extract(offset:Int, length:Int) -> Data{
        return Data(self[offset...(offset+length-1)])
    }
    
    
    func extractToInt(offset:Int, length:Int, isBigEndian:Bool = false) -> Int{
        let range:Range = offset..<offset+length
        
        switch length {
        case 1:
            return self[offset].toInt()
        case 2:
            return subdata(in: range).uint16(isBigEndian: isBigEndian).toInt()
        case 4:
            return subdata(in: range).uint32(isBigEndian: isBigEndian).toInt()
        case 8:
            return subdata(in: range).uint64(isBigEndian: isBigEndian).toInt()
        default:
            return 0
        }
        
    }
    
    func toInt(isBigEndian: Bool = false) -> Int{
//        print("data size", self.count)
        switch self.count {
        case 1:
            return self[0].toInt()
        case 2:
            return self.uint16(isBigEndian: isBigEndian).toInt()
        case 4:
            return self.uint32(isBigEndian: isBigEndian).toInt()
        case 8:
            return self.uint64(isBigEndian: isBigEndian).toInt()
        default:
            return 0
        }
        
    }
    
    func extractToInt(length:Int, isBigEndian:Bool = false) -> Int{
        switch length {
        case 1:
            return self[0].toInt()
        case 2:
            return self[0 ... (length-1)].uint16(isBigEndian: isBigEndian).toInt()
        case 4:
            return self[0 ... (length-1)].uint32(isBigEndian: isBigEndian).toInt()
        case 8:
            return self[0 ... (length-1)].uint64(isBigEndian: isBigEndian).toInt()
        default:
            return 0
        }
        
    }
    
    func printBytes(offset:Int, length:Int){
          let kbData = self.subdata(in: offset..<offset+length)
          let stringArray = kbData.map{String(format: "%02X", $0)}
          let binaryString = "(\(offset))" + stringArray.joined(separator: "-")
          print(binaryString)
    }
    
    func printBytesAll(){
        let stringArray = self.map{String(format: "%02X", $0)}
        let binaryString = "(0)" + stringArray.joined(separator: "-")
        print(binaryString)
    }
    
}

extension Collection where Iterator.Element == UInt8 {
    func printBytes(){
        print(self.map{String(format: "%02X", $0)}.joined(separator: " "))
    }
}
