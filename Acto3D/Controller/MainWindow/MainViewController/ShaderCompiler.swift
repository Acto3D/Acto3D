//
//  ShaderCompiler.swift
//  Acto3D
//
//  Created by Naoki Takeshita on 2023/07/02.
//

import Foundation
import Metal
import Cocoa

extension ViewController{
    
    
    /// Replace `#include ***.metal` to source code.
    func preprocessShaderSource(_ shaderSource: String, shaderDirURL:URL) throws -> String {
        var processedSource = shaderSource
        
        let regex = try NSRegularExpression(pattern: #"#include\s+"([^"]+)""#)

        // Find `#include` and get additional file name
        let matches = regex.matches(in: shaderSource, range: NSRange(shaderSource.startIndex..., in: shaderSource))
        
        Logger.logOnlyToFile(message: "Appending Acto3D bundled additional shader sources.", level: .info)
        
        for (index, match) in matches.enumerated(){
            guard let filenameRange = Range(match.range(at: 1), in: shaderSource) else {
                continue
            }
            let filename = String(shaderSource[filenameRange])
            
            Logger.logOnlyToFile(message: " [\(String(format: "%02d", index))] \(filename)", level: .info)
            guard let includedSource = try? String(contentsOf: shaderDirURL.appendingPathComponent(filename), encoding: .utf8) else{
                continue
            }
            
            // Replace `#include ...` to source code.
            processedSource = processedSource.replacingOccurrences(of: shaderSource[Range(match.range, in: shaderSource)!], with: includedSource)
        }
        
        return processedSource
    }
    
    func shaderReCompile(onAppLaunch:Bool = false) throws {
        Logger.logOnlyToFile(message: "** Compile shaders", level: .info)
        
        // Main shader files are located at "Acto3D.app/Contents/Resources/Shader/"
        let appURL = Bundle.main.bundleURL
        let mainShadersURL = appURL.appendingPathComponent("Contents").appendingPathComponent("Resources").appendingPathComponent("Shader").appendingPathComponent("Acto3D")
        
        guard let customShadersURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent("Shader") else {
            Logger.logOnlyToFile(message: "Failed to find document directory", level: .error)
            throw NSError(domain: "Failed to find document directory", code: -1, userInfo: nil)
        }
        
        do {
            try FileManager.default.createDirectory(at: customShadersURL, withIntermediateDirectories: true, attributes: nil)
            
        } catch {
            Logger.logOnlyToFile(message: "Error in creating custom shader directory", level: .error)
            throw NSError(domain: "Error in creating custom shader directory", code: -1, userInfo: nil)
            
        }
        
        var customShaderDirUrl:[URL] = [customShadersURL]
        Logger.logOnlyToFile(message: "Main shader directory: \(mainShadersURL.path)", level: .info)
        Logger.logOnlyToFile(message: "Shader directory: \(customShaderDirUrl[0].path)", level: .info)
        
        // Get the sub-directory list for `customShaderDirUrl`
        customShaderDirUrl += fetchDirectoryURLs(directoryURL: customShadersURL)

        var mainShaderURL:URL!

        Logger.logOnlyToFile(message: "** Fetch Acto3D shader files.")
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(at: mainShadersURL, includingPropertiesForKeys: nil)
            let metalFiles = fileURLs.filter { $0.pathExtension == "metal" }

            for fileURL in metalFiles{
                Logger.logOnlyToFile(message: "Main shader file: \(fileURL.path)", level: .info)
                
                if(fileURL.lastPathComponent == "shader.metal"){
                    mainShaderURL = fileURL
                }
            }
            
        } catch {
            Logger.logOnlyToFile(message: "Failed to retrive Acto3D shader files.", level: .error)
            throw NSError(domain: "Error in finding preset shaders", code: -1, userInfo: nil)
        }

        
        shaderList = ShaderManage.getPresetList()
        
        var sourceText = ""
        
        // Create metal shader source code from list of metal files.
        do {
            let shaderSource = try String(contentsOf: mainShaderURL!, encoding: .utf8)
            sourceText = try preprocessShaderSource(shaderSource, shaderDirURL: mainShadersURL)

        } catch {
            Logger.logOnlyToFile(message: "Failed to retrive preset shader files.", level: .error)
        }
        
        
        Logger.logOnlyToFile(message: "** Retrieving custom shaders.", level: .info)
        for dir in customShaderDirUrl{
            do {
                let fileURLs = try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
                let metalFiles = fileURLs.filter { $0.pathExtension == "metal" }
            
                for (index, metalFile) in metalFiles.enumerated(){
                    Logger.logOnlyToFile(message: " [\(String(format: "%02d", index))] \(dir.lastPathComponent)/\(metalFile.lastPathComponent)")
                    guard let source = try? String(contentsOf: metalFile, encoding: .utf8) else{
                        continue
                    }
                    
                    guard let shaderInfo = extractShaderInformation(from: source, path: metalFile.relativePath(from: customShadersURL)!  ) else{
                        // shader file lacks a description of its functionality.
                        // the shader file is invalid
                        Logger.logOnlyToFile(message: "  \(dir.lastPathComponent)/\(metalFile.lastPathComponent) > Invalid shader file. Check metadata.", level: .error)
                        continue
                    }
                    
                    shaderList.append(shaderInfo)
                    sourceText += "\n" + source
                    
                }
            }catch {
                Logger.logOnlyToFile(message: "Failed to retrive shader files.", level: .error)
            }
            
        }
        
        do {
            let compileOption = MTLCompileOptions()
            compileOption.fastMathEnabled = true
            
//            if #available(macOS 13.0, *) {
//                compileOption.optimizationLevel = .default
//            }
            
            compileOption.libraryType = .executable
            
            Logger.logOnlyToFile(message: "** Compiling shader from source code.", level: .info)
            let library = try renderer.device.makeLibrary(source: sourceText, options: compileOption)
            
            renderer.mtlLibrary = library
            renderer.mtlLibrary.label = "Acto3D Metal Library"
            renderer.mtlFunction = nil
            renderer.renderPipeline = nil
            
            Logger.logPrintAndWrite(message: "The shader compilation was successful.")
            
        }catch{
            print(error.localizedDescription)
            Logger.logPrintAndWrite(message: "⚠️ An error occurred during the shader file compilation. \nThe details of the error are documented in the log file. \nPlease check the log by navigating to [Debug] > [Show Log File]. \n\nIf you have updated the version of Acto3D, the error might be due to outdated shaders.", level: .error)
            Logger.logPrintAndWrite(message: error.localizedDescription, level: .error)
            
            if(onAppLaunch == true){
                Dialog.showDialog(message: "Acto3D cannot be started due to an error in the Shader File. Disable the additional shaders and start Acto3D with only the preset shaders enabled.")
                Dialog.showDialog(message: "An error occurred during the shader file compilation. \nThe details of the error are documented in the log file. \nPlease check the log by navigating to [Debug] > [Show Log File]. \n\nIf you have updated the version of Acto3D, the error might be due to outdated shaders.")
            }else{
                Dialog.showDialog(message: "An error occurred during the shader file compilation. \nThe details of the error are documented in the log file. \nPlease check the log by navigating to [Debug] > [Show Log File]. \n\nIf you have updated the version of Acto3D, the error might be due to outdated shaders.")
            }
            
            throw NSError(domain: "Error in compiling custom shaders", code: -1, userInfo: nil)
        }
        
        for (index, shader) in shaderList.enumerated(){
            Logger.logOnlyToFile(message: "Shader \(index)")
            Logger.logOnlyToFile(message: "  \(shader.functionLabel)")
            Logger.logOnlyToFile(message: "  \(shader.kernalName)")
            Logger.logOnlyToFile(message: "  \(shader.authorName)")
            Logger.logOnlyToFile(message: "  \(shader.description)")
            Logger.logOnlyToFile(message: "  \(shader.location)")
            
        }
    }
    
    
    func extractShaderInformation(from source: String, path:String) -> ShaderManage? {
        // Regular expressions patterns
        let patterns = [
            "author": "Author:\\s*(.*)",
            "description": "Description:\\s*(.*)",
            "label": "Label:\\s*(.*)",
            "kernel" : "kernel void (.+?)\\("
        ]
        
        // Variables to store the extracted information
        var author: String?
        var description: String?
        var functionLabel: String?
        var kernelName: String?
        
        // Create regular expressions and search for matches
        for (key, pattern) in patterns {
            do {
                let regex = try NSRegularExpression(pattern: pattern, options: [])
                let matches = regex.matches(in: source, options: [], range: NSRange(source.startIndex..., in: source))
                
                if let match = matches.first {
                    let range = match.range(at: 1)
                    let matchedString = (source as NSString).substring(with: range)
                    
                    switch key {
                    case "author": author = matchedString
                    case "description":
                        description = matchedString
                        if matchedString.contains("\\n") {
                            description = matchedString.replacingOccurrences(of: "\\n", with: "\n    ")
                        }
                        
                    case "label":
                        functionLabel = matchedString
                        
                    case "kernel": kernelName = matchedString
                    default: break
                    }
                }
            } catch {
                return nil
            }
        }
        
        // Return the extracted information
        guard let author = author,
              let description = description,
              let functionLabel = functionLabel,
              let kernelName = kernelName
        else {return nil}
        
        return ShaderManage(functionLabel: functionLabel, kernalName: kernelName, authorName: author, description: description, location: path)
    }
    
    
    // Fetch sub-directories at the url.
    func fetchDirectoryURLs(directoryURL: URL) -> [URL] {
        var result: [URL] = []
        let fileManager = FileManager.default

        do {
            let contents = try fileManager.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: [.isDirectoryKey], options: [])

            for url in contents {
                let resourceValues = try url.resourceValues(forKeys: [.isDirectoryKey])
                if let isDirectory = resourceValues.isDirectory, isDirectory {
                    result.append(url)
                    // Recursively fetch the contents of this directory
                    result.append(contentsOf: fetchDirectoryURLs(directoryURL: url))
                }
            }
        } catch {
            print("Error fetching contents of directory: \(error)")
        }

        return result
    }
    
    func copySampleShadersToShaderDirectory(){
        
        let appURL = Bundle.main.bundleURL
        let mainShadersURL = appURL.appendingPathComponent("Contents").appendingPathComponent("Resources").appendingPathComponent("Shader").appendingPathComponent("SampleShaders")
        
        // get custom shader dir
        guard let customShadersURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent("Shader").appendingPathComponent("SampleShaders") else {
            Logger.logPrintAndWrite(message: "Could not obtein shader directory")
            return
        }
        do {
            try FileManager.default.createDirectory(at: customShadersURL, withIntermediateDirectories: true, attributes: nil)
        } catch {
            Logger.logPrintAndWrite(message: "Error in creating custom shader directory", level: .error)
            return
        }
        
        guard let mainShadersFiles = try? FileManager.default.contentsOfDirectory(at: mainShadersURL,
                                                                                  includingPropertiesForKeys: nil,
                                                                                  options: .skipsHiddenFiles)
        else{
            Logger.logPrintAndWrite(message: "could not obtein files in: \(mainShadersURL.path)")
            return
        }
        
        let metalFiles = mainShadersFiles.filter{$0.pathExtension == "metal"}
        if(metalFiles.count == 0){
            Logger.logPrintAndWrite(message: "no metal files in :\(mainShadersURL.path)")
            return
        }
        
        var overwriteAll = false
        
        for fileURL in metalFiles {
            let destinationURL = customShadersURL.appendingPathComponent(fileURL.lastPathComponent)
            if FileManager.default.fileExists(atPath: destinationURL.path){
                if (overwriteAll){
                    // first, delete the existing file
                    do{
                        try FileManager.default.removeItem(at: destinationURL)
                        Logger.logPrintAndWrite(message: "delete existing shader file: \(destinationURL.path)")
                    }catch{
                        Logger.log(message: "error in overwrite \(destinationURL)")
                    }
                    
                }else{
                    let alert = NSAlert()
                    alert.messageText = "Would you like to overwrite the existing file?"
                    alert.informativeText = "\(destinationURL.path) already exists."
                    alert.addButton(withTitle: "Overwrite")
                    alert.addButton(withTitle: "Skip")
                    alert.addButton(withTitle: "Overwrite All")
                    let response = alert.runModal()
                    
                    switch response {
                    case .alertFirstButtonReturn:  // User chose to overwrite
                        do{
                            try FileManager.default.removeItem(at: destinationURL)
                            Logger.logPrintAndWrite(message: "delete existing shader file: \(destinationURL.path)")
                        }catch{
                            Logger.logPrintAndWrite(message: "error in handling file:\(destinationURL.path)")
                        }
                        
                    case .alertSecondButtonReturn:  // User chose to skip
                        Logger.logPrintAndWrite(message: "skip shader file: \(destinationURL.path)")
                        continue
                        
                    case .alertThirdButtonReturn:  // User chose to overwrite all
                        overwriteAll = true
                        do{
                            try FileManager.default.removeItem(at: destinationURL)
                            Logger.logPrintAndWrite(message: "delete existing shader file: \(destinationURL.path)")
                        }catch{
                            Logger.logPrintAndWrite(message: "error in handling file:\(destinationURL.path)")
                        }
                        
                    default:
                        break
                    }
                }
            }
            do{
                try FileManager.default.copyItem(at: fileURL, to: destinationURL)
                Logger.logPrintAndWrite(message: "copy shader file: \(destinationURL.path)")
            }catch{
                Logger.logPrintAndWrite(message: "error in handling file:\(destinationURL.path)")
            }
        }
        NSWorkspace.shared.activateFileViewerSelecting([customShadersURL])
        
    }
        
}
