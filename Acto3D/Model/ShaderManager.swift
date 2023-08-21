//
//  ShaderManager.swift
//  Acto3D
//
//  Created by Naoki Takeshita on 2023/06/25.
//

import Foundation

struct ShaderManage: Codable{
    var functionLabel = ""
    var kernalName = ""
    var authorName = ""
    var description = ""
    var location = ""
    
    static func getPresetList() -> [ShaderManage]{
        return [ShaderManage(functionLabel: "Front to back", kernalName: "preset_FTB", authorName: "Naoki Takeshita", description: "Standard Front to back", location: "/../Acto3D/preset_FTB.metal"),
                ShaderManage(functionLabel: "Back to Front", kernalName: "preset_BTF", authorName: "Naoki Takeshita", description: "Standard Back to Front", location: "/../Acto3D/preset_BTF.metal"),
                ShaderManage(functionLabel: "MIP", kernalName: "preset_MIP", authorName: "Naoki Takeshita", description: "Standard MIP", location: "/../Acto3D/preset_MIP.metal")]
    }
    
}
