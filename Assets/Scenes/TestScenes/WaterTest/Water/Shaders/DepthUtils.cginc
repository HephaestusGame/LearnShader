#ifndef DEPTH_UTILS_INCLUDED
#define DEPTH_UTILS_INCLUDED
#include "UnityCG.cginc"

sampler2D _CameraDepthTexture;
float4 _CameraDepthTexture_TexelSize;

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
    float depthBufferValue = tex2D(_CameraDepthTexture, screenUV).r;
    float bufferEyeDepth = LinearEyeDepth(depthBufferValue);
    float3 curPiexlDepthBufferWorldPos = _WorldSpaceCameraPos + (bufferEyeDepth / curPixelEyeDepth) * viewDirWS;
    return  curPixelWorldPos.y - curPiexlDepthBufferWorldPos.y;
}

#endif