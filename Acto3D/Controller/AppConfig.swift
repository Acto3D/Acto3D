//
//  AppConfig.swift
//  Acto3D
//
//  Created by Naoki Takeshita on 2023/07/17.
//

import Foundation
import Cocoa

@propertyWrapper
struct CachedUserDefault<T> {
    let key: String
    let defaultValue: T
    var cachedValue: T?
    
    var wrappedValue: T {
        mutating get {
            if let value = cachedValue {
                return value
            } else {
                let value = UserDefaults.standard.object(forKey: key) as? T ?? defaultValue
                cachedValue = value
                return value
            }
        }
        set {
            UserDefaults.standard.set(newValue, forKey: key)
            cachedValue = newValue
        }
    }
}


class AppConfig {
    static let shared = AppConfig()

    
    /// This constant represents whether debug mode.
    @CachedUserDefault(key: "IS_DEBUG_MODE", defaultValue: false) static var IS_DEBUG_MODE: Bool
     
    /// This constant represents the number of file usage histories that the application will retain.
    @CachedUserDefault(key: "KEEP_RECENT_NUM", defaultValue: 35) static var KEEP_RECENT_NUM: Int
    
    /// This constant represents the number of log files to be retained.
    @CachedUserDefault(key: "KEEP_LOG_NUM", defaultValue: 30) static var KEEP_LOG_NUM: Int
    
    /// This constant represents the image size during mouse dragging.
    @CachedUserDefault(key: "PREVIEW_SIZE", defaultValue: 256) static var PREVIEW_SIZE: UInt16
    
    /// This constant represents the image size when capture or copy.
    @CachedUserDefault(key: "HQ_SIZE", defaultValue: 2048) static var HQ_SIZE: UInt16
    
    /// This constant represents the default shader index.
    @CachedUserDefault(key: "DEFAULT_SHADER_NO", defaultValue: 0) static var DEFAULT_SHADER_NO: Int
    
    /// This constant represents ...
    @CachedUserDefault(key: "CLIPBOARD_WHEN_SNAPSHOT", defaultValue: true) static var CLIPBOARD_WHEN_SNAPSHOT: Bool
    
    /// This constant represents whether.
    @CachedUserDefault(key: "ACCEPT_TCP_CONNECTION", defaultValue: false) static var ACCEPT_TCP_CONNECTION: Bool
    
    /// This constant represents TCP port.
    @CachedUserDefault(key: "TCP_PORT", defaultValue: 54847) static var TCP_PORT: UInt16

    private init() {
    }
    
    static func reset(_ key: String) {
        // When reset the cached value, use as self._TCP_PORT.defaultValue.
        UserDefaults.standard.removeObject(forKey: key)
    }
}

