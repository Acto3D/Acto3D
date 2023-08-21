//
//  Permission.swift
//  Acto3D
//
//  Created by Naoki Takeshita on 2023/02/17.
//

import Foundation
import Cocoa

class Permission{
    static var securedBookmarksData:[Data] = []
    
    static func checkPermission(url: URL) -> Bool{
        let access_permitted = url.startAccessingSecurityScopedResource()
        print("Permission for ", url, ":", access_permitted)
        
        if(access_permitted == false){
            let openPanel = NSOpenPanel()
            openPanel.directoryURL = url
            openPanel.message = "Need your permission to access to this directory."
            openPanel.prompt = "Grant Access"
            
            openPanel.showsResizeIndicator    = true
            openPanel.showsHiddenFiles        = true
            openPanel.allowsMultipleSelection = false
            openPanel.canChooseDirectories = true
            openPanel.canChooseFiles = false
            
            openPanel.canChooseDirectories = true
            
            if  (openPanel.runModal() == .OK){
                print("Access: ", openPanel.url!.startAccessingSecurityScopedResource())
                
                _ = saveSecurityBookmark(url: openPanel.url!)
            }
            else{
                print("Cannot access the directory.")
                return false
            }
            
        }
        
        
        return true
        
    }
    
    
    static func saveSecurityBookmark(url: URL) -> Bool{
        do{
            let bookmarkData = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
            
//            if(securedBookmarksData == nil){
//                print("Secure Dir is empty and now initialized.")
//                securedBookmarksData = []
//            }
            self.securedBookmarksData.append(bookmarkData)
            
//            securedBookmarksData?.append(bookmarkData)
            
            let userDefaults = UserDefaults.standard
            userDefaults.set(securedBookmarksData, forKey: "PermanentFolderBookmarks")
            
            return true
            
        }catch let error{
            print("Error in saving SecurityBookmark: ",error)
            return false
            
        }
        
    }
    
    static func loadSecurityBookmarks(){
        let userDefaults = UserDefaults.standard
        print("* Load Secured Bookmarks")
        
        guard var securedBookmarksData = userDefaults.array(forKey: "PermanentFolderBookmarks") as? [Data] else{
            print("Secured Bookmarks are empty")
            self.securedBookmarksData = []
            return
        }
        
        let savedDataCount = securedBookmarksData.count
        
        for (i,dat) in securedBookmarksData.enumerated().reversed(){
            do{
                var ExpiredOr = false
                let urlForBookmark = try URL(resolvingBookmarkData: dat, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &ExpiredOr)
                
                print("Secure Dir[\(i)]:", urlForBookmark)
                
                if ExpiredOr {
                    // expired bookmark
                    print(" -> Expired:", urlForBookmark)
                    securedBookmarksData.remove(at: i)
                    //                    _ = saveSecurityBookmarkForURL(url: urlForBookmark)
                    
                } else {
                    // valid
                }
            }catch let error{
                print("error:", error)
                securedBookmarksData.remove(at: i)
            }
        }
        
        self.securedBookmarksData = securedBookmarksData
        userDefaults.set(self.securedBookmarksData, forKey: "PermanentFolderBookmarks")
        
        print(self.securedBookmarksData.count, "out of",savedDataCount,"stored security bookmarks are successfully loaded")
    }
}
