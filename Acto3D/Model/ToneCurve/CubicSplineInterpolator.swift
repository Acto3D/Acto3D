//
//  CubicSplineInterpolator.swift
//  Acto3D
//
//  Created by Naoki Takeshita on 2022/08/27.
//

import Foundation
import Accelerate
import simd


class CubicSplineInterpolator{
    var xPoints: [Float]
    var yPoints: [Float]
    var coefficients: [[Float]]?
    
    enum InterpolateMode{
        case cubicSpline
        case linear
    }
    
    var interpolateMode:InterpolateMode = .cubicSpline
    
    func xValues()-> [Float]{
        return self.xPoints
    }
    func yValues()-> [Float]{
        return self.yPoints
    }

    init(xPoints: [Float], yPoints: [Float]) {
        // at least 2 control points are needed
        self.xPoints = xPoints
        self.yPoints = yPoints
        
        self.updateSpline(xPoints: xPoints, yPoints: yPoints)
    }
    
    func updateSpline(xPoints: [Float], yPoints: [Float]) {
        self.xPoints = xPoints
        self.yPoints = yPoints
        
        self.calculateCoefficients()
    }
    
    private func calculateCoefficients() {
        let n = xPoints.count // 制御点の数
        let a = yPoints // 制御点のy座標配列
        var b = [Float](repeating: 0.0, count: n) // Spline多項式の第二項の係数を格納する配列
        var d = [Float](repeating: 0.0, count: n) // Spline多項式の第四項の係数を格納する配列
        var h = [Float](repeating: 0.0, count: n) // 隣接する制御点のx座標の差を格納する配列
        var alpha = [Float](repeating: 0.0, count: n) // 三重対角線系の右側の項を格納する配列
        var c = [Float](repeating: 0.0, count: n) // Spline多項式の第三項の係数を格納する配列
        var l = [Float](repeating: 0.0, count: n) // 三重対角線系を解くための対角成分を格納する配列
        var mu = [Float](repeating: 0.0, count: n) // 三重対角線系を解くための下側の対角成分を格納する配列
        var z = [Float](repeating: 0.0, count: n) // 三重対角線系を解くための作業配列

        for i in 0..<n-1 {
            h[i] = xPoints[i + 1] - xPoints[i]
        }
        
        for i in 1..<n-1 {
            alpha[i] = (3 / h[i]) * (a[i + 1] - a[i]) - (3 / h[i - 1]) * (a[i] - a[i - 1])
        }
        
        l[0] = 1
        mu[0] = 0
        z[0] = 0

        for i in 1..<n-1 {
            l[i] = 2 * (xPoints[i + 1] - xPoints[i - 1]) - h[i - 1] * mu[i - 1]
            mu[i] = h[i] / l[i]
            z[i] = (alpha[i] - h[i - 1] * z[i - 1]) / l[i]
        }
        
        l[n - 1] = 1
        z[n - 1] = 0
        c[n - 1] = 0

        for j in (0..<n-1).reversed() {
            c[j] = z[j] - mu[j] * c[j + 1]
            b[j] = (a[j + 1] - a[j]) / h[j] - (h[j] * (c[j + 1] + 2 * c[j])) / 3
            d[j] = (c[j + 1] - c[j]) / (3 * h[j])
        }

        coefficients = []
        for j in 0..<n-1 {
            coefficients?.append([a[j], b[j], c[j], d[j]])
        }
    }
    
    func interpolate(_ x: Float) -> Float {
        if(interpolateMode == .linear){
            // 線形補間を行う
            guard let lastX = xPoints.last, let lastY = yPoints.last else {
                return x
            }
            
            if x <= xPoints.first! {
                return yPoints.first!
            } else if x >= lastX {
                return lastY
            }
            
            var i = 0
            while i < xPoints.count - 1 {
                if x >= xPoints[i] && x <= xPoints[i + 1] {
                    break
                }
                i += 1
            }
            
            let x0 = xPoints[i]
            let x1 = xPoints[i + 1]
            let y0 = yPoints[i]
            let y1 = yPoints[i + 1]
            
            let slope = (y1 - y0) / (x1 - x0)
            let result = y0 + slope * (x - x0)
            return result
            
        }else{
            guard let coefficients = self.coefficients else {
                return x
            }

            let n = xPoints.count
            var i = 0
            while i < n - 1 {
                if x >= xPoints[i] && x <= xPoints[i + 1] {
                    break
                }
                i += 1
            }

            let dx = x - xPoints[i]
            
            let result = coefficients[i][0] + coefficients[i][1] * dx + coefficients[i][2] * pow(dx, 2) + coefficients[i][3] * pow(dx, 3)
            return result
        }
    }
}
