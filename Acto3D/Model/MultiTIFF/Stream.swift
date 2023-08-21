import Foundation

class StreamData{
    
    var isBigEndian = true
    var fileHandle: FileHandle?
    
    var data:Data?
    
    func read(offset: Int, length: Int) -> Data? {
        do {
            try fileHandle?.seek(toOffset: UInt64(offset))
            self.data = try fileHandle?.read(upToCount: length)
        } catch {
            print("Error reading bytes: \(error)")
        }
        
        return self.data
    }
    
    func convertedDataToInt() -> Int? {
        return self.data?.toInt(isBigEndian: self.isBigEndian)
    }
    
    func convertedDataToDouble() -> Double {
        guard let data = self.data else {
            return 0
        }
        
        let finalData = isBigEndian ? data.reversedData : data
        return finalData.withUnsafeBytes { $0.load(as: Double.self) }
    }
    
}
