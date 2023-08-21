//
//  DiceCoeff.swift
//  Acto3D
//
//  Created by Naoki Takeshita on 2023/05/16.
//

/*
 Description:
  This function calculates the DICE error.

  Main Features:
  - Computes the DICE coefficient, which measures the similarity between two sets.
  - Returns a value between 0 (no overlap) and 1 (perfect overlap).
*/

import Foundation

func calcDiceCoeff(pixel1:[UInt8], pixel2:[UInt8], smooth:Float = 0.01) -> Float{
    guard pixel1.count == pixel2.count else {
            fatalError("Both images must have the same number of pixels.")
    }
    
    let zippedArray = zip(pixel1, pixel2)
    
    var intersection = 0
    var union = 0
    
    for (p1, p2) in zippedArray {
        if p1 != 0 && p2 != 0 {
            intersection += 1
            union += 2
        } else if p1 != 0 || p2 != 0 {
            union += 1
        }
    }
    
    let dice = ((2.0 * intersection.toFloat() + smooth) / (union.toFloat() + smooth ))
        
    return dice
}
