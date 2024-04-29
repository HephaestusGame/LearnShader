#if !defined(WATER_SSR_INCLUDED)
#define WATER_SSR_INCLUDED

float _MaxStep;
float _StepSize;
float _MaxDistance;
float _Thickness;
float _StretchIntensity;
float _StretchThreshold;
float _VerticalFadeOutScreenBorderWidth;
float _HorizontalFadeOutScreenBorderWidth;


float4 TransformViewToHScreen(float3 vpos)
{
    float4 cpos = mul(unity_CameraProjection, float4(vpos, 1));
    cpos.xy = float2(cpos.x, cpos.y) * 0.5 + 0.5 * cpos.w;//[-w,w] remap to [0,w]
    cpos.xy *= _ScreenParams.xy;
    return cpos;
}

float3 SampleSky(float3 reflectWS)
{
    float4 skyData = UNITY_SAMPLE_TEXCUBE(unity_SpecCube0, reflectWS);
    float3 skyColor = DecodeHDR(skyData, unity_SpecCube0_HDR);
    return skyColor;
}

float2 StretchUV(float2 uv, float2 viewDirWS, float3 reflectPosWS, float curPixelWaterPlaneHeight)
{
    float heightStretch = (reflectPosWS.y - curPixelWaterPlaneHeight) * 0.01;
    float angleStretch = -viewDirWS.y;
    float screenStretch = saturate(abs(uv.x * 2 - 1) - _StretchThreshold);

    uv.x = uv.x * 2 - 1;
    uv.x *= 1 - heightStretch * angleStretch * screenStretch * _StretchIntensity;
    uv.x = saturate(uv.x * 0.5 + 0.5);
    return uv;
}

float GetFadeOutAlpha(float2 screenUV, float reflectedPosWSy, float curPixelWaterPlaneHeight)
{
    float fadeoutAlpha = smoothstep(1, 1 - _VerticalFadeOutScreenBorderWidth, screenUV.y);
    fadeoutAlpha *= smoothstep(
        1,
        1 - _HorizontalFadeOutScreenBorderWidth * (reflectedPosWSy - curPixelWaterPlaneHeight),
        abs(screenUV.x * 2 - 1));
    return fadeoutAlpha;
}

float3 SSR(sampler2D screenTex, sampler2D cameraDepthTex, float3 viewDirWS, float3 normalWS, float curPixelWaterPlaneHeight)
{
    float3 viewDirVS = mul(unity_WorldToCamera, float4(viewDirWS, 0)).xyz;
    viewDirVS.z *= -1;
    float3 curPixelPosVS = viewDirVS;
    viewDirVS = normalize(viewDirVS);

    float3 normalVS = mul(unity_WorldToCamera, float4(normalWS, 0)).xyz;
    normalVS.z *= -1;


    viewDirWS = normalize(viewDirWS);
    float3 reflectWS = reflect(viewDirWS, normalWS);
    float3 reflectDirVS = normalize(reflect(viewDirVS, normalVS));
    float magnitude = _MaxDistance;
    float endZ = curPixelPosVS.z + reflectDirVS.z * magnitude;
    if (endZ > -_ProjectionParams.y)//如果反射的终点深度在近平面前面（观察空间，相机前方 z 值为负值，所以条件为大于）
    {
        magnitude = (-_ProjectionParams.y - curPixelPosVS.z) / reflectDirVS.z;
    }
    float3 endPosVS = curPixelPosVS + reflectDirVS * magnitude;

    //此时得到的是裁剪空间的齐次坐标
    float4 startHScreen = TransformViewToHScreen(curPixelPosVS);
    float4 endHScreen = TransformViewToHScreen(endPosVS);

    // 1 / w
    float startK = 1.0 / startHScreen.w;
    float endK = 1.0 / endHScreen.w;
    
    float2 startScreen = startHScreen.xy * startK;
    float2 endScreen = endHScreen.xy * endK;

    float3 startQ = curPixelPosVS * startK;
    float3 endQ = endPosVS * endK;

    float2 diff = endScreen - startScreen;
    bool permute = false;
    if (abs(diff.x) < abs(diff.y))
    {
        permute = true;
        diff = diff.yx;
        startScreen = startScreen.yx;
        endScreen = endScreen.yx;
    }

    float dir = sign(diff.x);
    float invdx = dir / diff.x;
    float2 dp = float2(dir, invdx * diff.y);
    float3 dq = (endQ - startQ) * invdx;
    float dk = (endK - startK) * invdx;

    dp *= _StepSize;
    dq *= _StepSize;
    dk *= _StepSize;
   
    float2 P = startScreen;
    float3 Q = startQ;
    float K = startK;

    float endX = endScreen.x * dir;

    float3 skyColor = SampleSky(reflectWS);

    float startPosEyeDepth = -curPixelPosVS.z;
    float endPosEyeDepth = -endPosVS.z;
    float eyeDepthDiff = endPosEyeDepth - startPosEyeDepth;
    float3 raymarchingRay = endPosVS - curPixelPosVS;
    float3 temp = raymarchingRay * rcp(eyeDepthDiff);//raymarchingRay / eyeDepthDiff
    UNITY_LOOP//不进行循环展开
    for (int i = 0; i < _MaxStep && P.x * dir <= endX; ++i)
    {
        P += dp;
        Q.z += dq.z;
        K += dk;

        float reflectEyeDepth = (dq.z * 0.5 + Q.z) / (dk * 0.5 + K);//获取像素中间的观察空间深度
        reflectEyeDepth = abs(reflectEyeDepth);

        float2 hitUV = permute ? P.yx : P;
        hitUV *= (_ScreenParams.zw - 1);
        
        float3 reflectPosVS = curPixelPosVS + temp *  (reflectEyeDepth - startPosEyeDepth);
        reflectPosVS.z *= -1;
        float3 reflectPosWS = mul(unity_CameraToWorld, float4(reflectPosVS, 1)).xyz;
        //stretch 效果并不好
        // hitUV = StretchUV(hitUV, viewDirWS, reflectPosWS, curPixelWaterPlaneHeight);
        
        if (any(hitUV < 0.0) || any(hitUV > 1.0))
            return skyColor;

        float curStepSceneDepth = tex2D(cameraDepthTex, hitUV).r;
        float curStepEyeDepth = LinearEyeDepth(curStepSceneDepth);
        if (reflectEyeDepth > curStepEyeDepth + 0.03 && reflectEyeDepth < curStepEyeDepth + _Thickness)
        {
            float3 reflectColor = tex2D(screenTex, hitUV).rgb;
            float fade = GetFadeOutAlpha(hitUV, reflectPosWS.y, curPixelWaterPlaneHeight);
            return fade * reflectColor  + (1 - fade) * skyColor;
        }
        
    }
    
    return skyColor;
}
#endif