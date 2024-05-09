#ifndef WATER_FOAM_INCLUDED
#define WATER_FOAM_INCLUDED

#include "DepthUtils.cginc"
sampler2D _FoamNoiseTex, _FoamTex;
float4 _FoamTex_TexelSize;
float4 _FoamNoiseTex_ST, _FoamTex_ST;
float4 _FoamColor;
float _FoamDepth;
float _FoamFactor1;
float _FoamFactor2;
float _FoamEdgeChangeSpeed;
float _FoamSpeed;
float _FoamUVOffsetFactor;

float GetFoamMaskWithNoise(float2 uv, float4 screenPos, float3 viewDirWS)
{
    #if defined(USE_WORLD_SPACE_DEPTH_DIFFERENCE)
        float depthDiff = WorldSpaceDepthDiff(screenPos.xy / screenPos.w, screenPos.w, viewDirWS);
    #else
        float depthDiff = ViewSpaceDepthDiff(screenPos);
    #endif
    float foam = depthDiff / _FoamDepth;
    float2 noiseUV = uv.xy * _FoamNoiseTex_ST.xy + _FoamNoiseTex_ST.zw;
    float noise = tex2D(_FoamNoiseTex, noiseUV + _Time.y * _FoamEdgeChangeSpeed).r;
    return step(foam,noise);
}

float GetFoamMask(float2 uv, float4 screenPos, float3 viewDirWS, float3 worldNormal)
{
    #if defined(USE_WORLD_SPACE_DEPTH_DIFFERENCE)
        float depthDiff = WorldSpaceDepthDiff(screenPos.xy / screenPos.w, screenPos.w, viewDirWS);
    #else
        float depthDiff = ViewSpaceDepthDiff(screenPos);
    #endif
    float depthMask = depthDiff / _FoamDepth;
    //用 nosie 对 Foam边缘进行不规则截边
    float2 noiseUV = uv.xy * _FoamNoiseTex_ST.xy + _FoamNoiseTex_ST.zw;
    float noise = tex2D(_FoamNoiseTex, noiseUV + _Time.y * _FoamEdgeChangeSpeed * 0.1f).r;
    float cutoff = smoothstep(0, depthMask,noise);
    
    float foamMask = saturate(1 - depthMask + _FoamFactor1);
    float speed = _Time.y * _FoamSpeed * 0.1f;
    float2 foamUVOffset = worldNormal.xz * _FoamUVOffsetFactor;
    float foamTex = tex2D(_FoamTex, uv.xy * _FoamTex_ST.xy + _FoamTex_ST.zw + speed + foamUVOffset).g;
    foamTex += tex2D(_FoamTex, uv.xy * _FoamTex_ST.xy * 1.3f + speed + foamUVOffset).g;
    
    foamMask *= foamTex;
    foamMask -= _FoamFactor2;
    return saturate(foamMask * cutoff);
}


#endif