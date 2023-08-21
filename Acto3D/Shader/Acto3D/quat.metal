//
//  quat.metal
//  Acto3D
//
//  Created by Naoki Takeshita on 2022/08/08.
//



float4 quatInv(const float4 q) {
    return float4( -q.xyz, q.w );
}


/// Quaternion multiplication
float4 quatDot(const float4 q1, const float4 q2) {
    float scalar = q1.w * q2.w - dot(q1.xyz, q2.xyz);
    float3 v = cross(q1.xyz, q2.xyz) + q1.w * q2.xyz + q2.w * q1.xyz;
    return float4(v, scalar);
}

/// Apply unit quaternion to vector (rotate vector)
float3 quatMul(const float4 q, const float3 v) {
    float4 r = quatDot(q, quatDot(float4(v, 0), quatInv(q)));
    return r.xyz;
}

float4 quatMul(const float4 q, const float4 v) {
    float4 r = quatDot(q, quatDot(v, quatInv(q)));
    return r;
}

half4 quatMul(const float4 q, const half3 v) {
    float4 r = quatDot(q, quatDot(float4(float3(v), 0), quatInv(q)));
    return half4(r);
}
