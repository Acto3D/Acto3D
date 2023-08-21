//
//  ViewController-renderer.swift
//  Acto3D
//
//  Created by Naoki Takeshita on 2023/07/23.
//

import Foundation
import Cocoa
import simd


extension ViewController:VolumeRendererDelegate{
    func didCompleteCalculateHistogram(sender: VoluemeRenderer, histogram: [[UInt32]]) {
        toneCh1.histogram = histogram[0]
        toneCh2.histogram = histogram[1]
        toneCh3.histogram = histogram[2]
        toneCh4.histogram = histogram[3]
    }
}
