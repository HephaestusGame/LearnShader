#ifndef DEPTH_UTILS_INCLUDED
#define DEPTH_UTILS_INCLUDED
#include "UnityCG.cginc"

sampler2D _CameraDepthTexture;
float4 _CameraDepthTexture_TexelSize;
float4x4 _InverseProjectionMatrix, _InverseViewMatrix;

float3 GetCurPiexlDepthBufferWorldPos(float2 screenUV, float curPixelEyeDepth, float3 viewDirWS)
{
    float depthBufferValue = tex2D(_CameraDepthTexture, screenUV).r;
    float bufferEyeDepth = LinearEyeDepth(depthBufferValue);
    float3 curPiexlDepthBufferWorldPos = _WorldSpaceCameraPos + (bufferEyeDepth / curPixelEyeDepth) * viewDirWS;
    return curPiexlDepthBufferWorldPos;
}

float ViewSpaceDepthDiff(float4 screenPos)
{
    float depthBufferValue = tex2Dproj(_CameraDepthTexture, screenPos).r;
    float bufferEyeDepth = LinearEyeDepth(depthBufferValue);
    float depthDiff = bufferEyeDepth - screenPos.w;
    return depthDiff;
}

float WorldSpaceDepthDiff(float2 screenUV, float curPixelEyeDepth, float3 viewDirWS)
{
    float3 curPixelWorldPos = _WorldSpaceCameraPos + viewDirWS;
    float3 curPiexlDepthBufferWorldPos = GetCurPiexlDepthBufferWorldPos(screenUV, curPixelEyeDepth, viewDirWS);
    return  curPixelWorldPos.y - curPiexlDepthBufferWorldPos.y;
}

//计算世界空间坐标
float4 GetWorldSpacePosition(float2 screenUV)
{
    float depthBufferValue = tex2D(_CameraDepthTexture, screenUV).r;
    float4 viewPos = mul(_InverseProjectionMatrix, float4(2.0 * screenUV - 1.0, depthBufferValue, 1.0));
    viewPos.xyz /= viewPos.w;//详细推导见笔记中深度雾重建世界坐标部分
    float4 worldPos = mul(_InverseViewMatrix, float4(viewPos.xyz, 1));
    return worldPos;
}

#endif