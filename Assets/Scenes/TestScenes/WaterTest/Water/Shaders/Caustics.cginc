#ifndef CAUSTICS_INCLUDED
#define CAUSTICS_INCLUDED

#include "DepthUtils.cginc"
float _CausticsIntensity;
float4 _CausticsPlane;//xyz:waterPlane 的世界空间法向量，w : waterPlane的原点世界坐标向量在其法向量上的投影
float4 _CausticsRange;//xy:waterPlane原点世界坐标的 xz, z：0.5 * waterPlaneWidth w: 0.5 * waterPlaneHeight
float2 _CausticsDepthRange;

sampler2D _CausticsMap;

float3 GetCaustics(float2 screenUV, float curPixelEyeDepth, float3 viewDirWS, float3 lightDir)
{
    float3 curPixelDepthBufferWorldPos = GetCurPiexlDepthBufferWorldPos(screenUV, curPixelEyeDepth, viewDirWS);

    //当前点到水面的高度
    float curPosToWaterPlaneHeight = _CausticsPlane.w - dot(curPixelDepthBufferWorldPos, _CausticsPlane.xyz);
    //光照方向与水面法向量的夹角cos值
    float lightDirWaterPlaneNormalCosTheta = dot(lightDir, _CausticsPlane.xyz);
    //水底的当前点受到光照在水面的世界坐标
    float3 lightOnWaterPlaneWorldPos = curPixelDepthBufferWorldPos + lightDir * curPosToWaterPlaneHeight / lightDirWaterPlaneNormalCosTheta;
    float2 uv = (lightOnWaterPlaneWorldPos.xz - _CausticsRange.xy) / _CausticsRange.zw*0.5 + 0.5;
    if (any(uv < 0) || any(uv > 1))
    {
        return 0;
    }
    // float3 caustics = saturate(tex2D(_CausticsMap, uv).rgb - 0.5);
    float3 caustics = tex2D(_CausticsMap, uv).rgb;
    caustics = lerp(caustics, 0, step(caustics, 0));
    float fade = 1.0 - saturate((curPixelDepthBufferWorldPos.y - _CausticsDepthRange.x) / _CausticsDepthRange.y);
    return caustics * _CausticsIntensity * fade;
}
#endif