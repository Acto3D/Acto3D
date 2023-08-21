//
//  URL+relative.swift
//  Acto3D
//
//  Created by Naoki Takeshita on 2023/06/25.
//

import Foundation

extension URL {
    func relativePath(from baseURL: URL) -> String? {
        guard scheme == baseURL.scheme, host == baseURL.host else { return nil }

        let relativePath = path.replacingOccurrences(of: baseURL.path, with: "")
        return relativePath.isEmpty ? nil : relativePath
    }
}
