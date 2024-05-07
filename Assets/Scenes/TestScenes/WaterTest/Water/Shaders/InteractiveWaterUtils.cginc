#ifndef INTERACTIVE_WATER_UTILS
#define INTERACTIVE_WATER_UTILS

#include "UnityCG.cginc"

float4 EncodeHeight(float height)
{
    float2 rg = EncodeFloatRG(height >= 0 ? height : 0);
    float2 ba = EncodeFloatRG(height < 0 ? -height : 0);

    return float4(rg, ba);
}

float DecodeHeight(float4 rgba) {
    float d1 = DecodeFloatRG(rgba.rg);
    float d2 = DecodeFloatRG(rgba.ba);

    if (d1 >= d2)
        return d1;
    else
        return -d2;
}

float4 EncodeNormal(float3 normal)
{
    #if defined(UNITY_NO_DXT5nm)
        return float4(normal*0.5 + 0.5, 1.0);
    #else
        #if UNITY_VERSION > 2018
            return float4(normal.x*0.5 + 0.5, normal.y*0.5 + 0.5, 0, 1); //2018修改了法线压缩方式，增加了一种BC5压缩
        #else
            return float4(0, normal.y*0.5 + 0.5, 0, normal.x*0.5 + 0.5);
        #endif
    #endif
}
#endif