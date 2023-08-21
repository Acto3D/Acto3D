//
//  Math.swift
//  Acto3D
//
//  Created by Naoki Takeshita on 2021/12/20.
//

import Foundation
import simd

//let π = Float(M_PI)
let PI = Float.pi

func radians(fromDegrees degrees: Float) -> Float {
  return (degrees / 180) * PI
}

func degrees(fromRadians radians: Float) -> Float {
  return (radians / PI) * 180
}

extension Float {
  var radiansToDegrees: Float {
    return (self / PI) * 180
  }
  var degreesToRadians: Float {
    return (self / 180) * PI
  }
}

///
/// Quaternion to Eular
func quatToEulerAngles(_ quat: simd_quatf) -> SIMD3<Float>{
    var angles = SIMD3<Float>()
    let qfloat = quat.vector
    
    // heading = x, attitude = y, bank = z
    
    let test = qfloat.x * qfloat.y + qfloat.z * qfloat.w;
    
    if (test > 0.499) { // singularity at north pole
        angles.x = 2 * atan2(qfloat.x,qfloat.w)
        angles.y = (.pi / 2)
        angles.z = 0
        return angles
    }
    
    if (test < -0.499) { // singularity at south pole
        angles.x = -2 * atan2(qfloat.x,qfloat.w)
        angles.y = -(.pi / 2)
        angles.z = 0
        return angles
    }
    
    
    let sqx = qfloat.x*qfloat.x
    let sqy = qfloat.y*qfloat.y
    let sqz = qfloat.z*qfloat.z
    angles.x = atan2(2*qfloat.y*qfloat.w-2*qfloat.x*qfloat.z , 1 - 2*sqy - 2*sqz)
    angles.y = asin(2*test)
    angles.z = atan2(2*qfloat.x*qfloat.w-2*qfloat.y*qfloat.z , 1 - 2*sqx - 2*sqz)
    
    
    return angles
}

extension float3x3{
    init (rotationMatrix3x3_Y theta : Float){
        self.init()
        columns = (
            float3(cos(theta), 0, sin(theta)),
            float3(0,1,0),
            float3(-sin(theta),0,cos(theta))
         )
        //return matrix_float3x3(columns)
    }
    
    init (rotationMatrix3x3_Z theta : Float){
        self.init()
        columns = (
            float3(cos(theta), sin(theta),0),
            float3(-sin(theta),cos(theta),0),
            float3(0,0,1)
         )
        //return matrix_float3x3(columns)
    }
    
    init (rotationMatrix3x3_X theta : Float){
        self.init()
        
        columns = (
            float3(1,0,0),
            float3(0, cos(theta), -sin(theta)),
            float3(0,sin(theta),cos(theta))
         )
        //return matrix_float3x3(columns)
    }
    
    
    
    
    init (rotationMatrix_RodoriguesWith_dx dx:Float, dy:Float, dz:Float, theta:Float){
        self.init()
        columns = (
            float3(dx*dx*(1-cos(theta))+cos(theta),     dx*dy*(1-cos(theta))+dz*sin(theta), dx*dz*(1-cos(theta))-dy*sin(theta)),
            float3(dx*dy*(1-cos(theta))-dz*sin(theta),  dy*dy*(1-cos(theta))+cos(theta),    dy*dz*(1-cos(theta))+dx*sin(theta)),
            float3(dx*dz*(1-cos(theta))+dy*sin(theta),  dy*dz*(1-cos(theta))-dx*sin(theta), dz*dz*(1-cos(theta))+cos(theta))
        )
    }
    init (rotationMatrix_RodoriguesWith_float3 vec:float3, theta:Float){
        self.init()
        let normalizedVec = normalize(vec)
        
        let dx = normalizedVec.x
        let dy = normalizedVec.y
        let dz = normalizedVec.z
        
        
        columns = (
            float3(dx*dx*(1-cos(theta))+cos(theta),     dx*dy*(1-cos(theta))+dz*sin(theta), dx*dz*(1-cos(theta))-dy*sin(theta)),
            float3(dx*dy*(1-cos(theta))-dz*sin(theta),  dy*dy*(1-cos(theta))+cos(theta),    dy*dz*(1-cos(theta))+dx*sin(theta)),
            float3(dx*dz*(1-cos(theta))+dy*sin(theta),  dy*dz*(1-cos(theta))-dx*sin(theta), dz*dz*(1-cos(theta))+cos(theta))
        )
        
    }

}

extension float4{
    var xyz: float3 {
        get{
            return float3(self.x, self.y, self.z)

        }
    }
    
}
extension float3{
    
    var stringValue: String {
        get{
            let s_x = self.x.toFormatString(format: "%.3f")
            let s_y = self.y.toFormatString(format: "%.3f")
            let s_z = self.z.toFormatString(format: "%.3f")
            return "x:\(s_x), y:\(s_y), z:\(s_z)"

        }
    }
    
    var floatXYZ:[Float]{
        get {
            return [self.x,self.y,self.z]
        }
    }
}


extension float4x4{
    func matrix4x4_translation(_ translationX: Float, _ translationY: Float, _ translationZ: Float) -> matrix_float4x4 {
        return matrix_float4x4.init(columns:(vector_float4(1, 0, 0, 0),
                                             vector_float4(0, 1, 0, 0),
                                             vector_float4(0, 0, 1, 0),
                                             vector_float4(translationX, translationY, translationZ, 1)))
    }
}
