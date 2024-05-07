Shader "Unlit/Water"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        
        [Space(30)]
        [Header(Debug)]
        [Space(5)]
        [Toggle(SHOW_FRESNEL)] _ShowFresnel("Show Fresnel", Float) = 1
        [Toggle(SHOW_NORMAL_WS)] _ShowNormalWS("Show World Space Normal", Float) = 1

        
        _SpecularGloss("Specular Gloss", Range(0, 100)) = 10
        _WaterSpeed("Water Speed", Vector) = (1, 1, 1, 1)
        _RefractionStrength("Refraction Strength", Range(0, 10)) = 0.5
        [Header(Water Color)]
        [Space(5)]
        _DeepColor ("Deep Color", Color) = (0, 0, 0, 1)
        _ShallowColor ("Shallow Color", Color) = (0, 0, 0, 1)
        _DeepWaterDistance("Deep Water Distance", Float) = 10
        _DeepWaterLerpPow("Deep Water Lerp Pow", Range(0, 10)) = 1
        
        [Space(30)]
        [Header(Gersnter Wave)]
        [Space(5)]
        _GerstnerDisplacementTex("Gerstner Displacement Texture", 2D) = "black" {}
        _GerstnerNormalTex("Gerstner Normal Texture", 2D) = "black" {}
        _GerstnerTextureSize("Gerstner Texture Size", Float) = 256
        _GerstnerTiling("Gerstner Tiling", Float) = 0.01
        
//        [Space(30)]
//        [Header(Interaction)]
//        [Space(5)]
//        _InteractiveWaterHeightMap("Interactive Water Height Map", 2D) = "black" {}
//        _InteractiveWaterNormalMap("Interactive Water Normal Map", 2D) = "black" {}
        
        [Space(30)]
        [Header(Caustics)]
        [Space(5)]
        _CausticsTex("Caustics Texture", 2D) = "black" {}
        _CausticsTilingAndSpeed("Caustics Tiling", Vector) = (0.01, 0.01, 0.01, 0.01)
        _CausticsIntensity("Caustics Intensity", Float) = 1
        _CausticsJitterScale("Caustics Jitter Scale", Float) = 1
        
        [Space(30)]
        [Header(Wind)]
        [Space(5)]
        _NoiseTex("Noise Texture", 2D) = "black" {}
        _NoiseIntensity("Noise Intensity", Float) = 1
        _WindSpeed("Wind Speed", Vector) = (1, 1, 0, 0)
        
        [Space(30)]
        [Header(Normal)]
        [Space(5)]
        _NormalTex_0("Normal Texture 0", 2D) = "black" {}
        _NormalTex_1("Normal Texture 1", 2D) = "black" {}
        _NormalScale("Normal Scale", Float) = 1
        
        [Space(30)]
        [Header(SSR)]
        [Space(5)]
        [Toggle(ENABLE_SSR)] _EnableSSR("Enable SSR", Float) = 0
        _MaxStep("MaxStep",Float) = 10
        _StepSize("StepSize", Float) = 1
        _MaxDistance("MaxDistance",Float) = 10
        _Thickness("Thickness",Float) = 1
        _StretchIntensity("Stretch Intensity",Range(0, 2)) = 1
        _StretchThreshold("Stretch Threshold",Range(0, 1.0)) = 1
        _VerticalFadeOutScreenBorderWidth("Vertical Fade Out Screen Border Width",Range(0, 1.0)) = 1
        _HorizontalFadeOutScreenBorderWidth("Horizontal Fade Out Screen Border Width",Range(0, 1.0)) = 1
        
        [Space(30)]
        [Header(Foam)]
        [Space(5)]
        _FoamNoiseTex("Foam Noise Texture", 2D) = "white" {}
        _FoamDepth("Foam Depth", Float) = 3
        _FoamColor("Foam Color", Color) = (1, 1, 1, 1)
        
        
        
    }
    SubShader
    {
        Tags { 
            "RenderType" = "Transparent" 
            "Queue" = "Transparent"
        }
        
        GrabPass
        {
            "_BackgroundTexture"
        }

        
//        Blend SrcAlpha OneMinusSrcAlpha
        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_local _ SHOW_FRESNEL
            #pragma multi_compile_local _ SHOW_NORMAL_WS
            #pragma multi_compile_local _ ENABLE_SSR
            
            #include "UnityCG.cginc"
            #include "Lighting.cginc"
            #include "WaterSSR.cginc"
            #include "InteractiveWaterUtils.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float4 tangent : TANGENT;
                float4 normal : NORMAL;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float4 vertex : SV_POSITION;
                float4 uv : TEXCOORD0;
                float4 screenPos : TEXCOORD1;
                float3 viewDirWS : TEXCOORD2;
                float3 normalOS : TEXCOORD3;
                float4 tangentOS : TEXCOORD4;
                float4 normalUV : TEXCOORD5;
            };

            sampler2D _MainTex, _NoiseTex, _CausticsTex;
            float4 _MainTex_ST, _NoiseTex_ST;

            sampler2D _CameraDepthTexture;
            float4 _CameraDepthTexture_TexelSize;
            float _DeepWaterDistance, _DeepWaterLerpPow, _SpecularGloss, _NormalScale, _NoiseIntensity, _RefractionStrength;
            float4 _DeepColor, _ShallowColor, _WaterSpeed;

            float2 _WindSpeed;

            sampler2D _NormalTex_0;
            float4 _NormalTex_0_ST;
            sampler2D _NormalTex_1;
            float4 _NormalTex_1_ST;

            sampler2D _BackgroundTexture;
            float4 _BackgroundTexture_TexelSize;

            float4 _CausticsTilingAndSpeed;
            float _CausticsIntensity, _CausticsJitterScale;


            sampler2D _FoamNoiseTex;
            float4 _FoamNoiseTex_ST;
            float4 _FoamColor;
            float _FoamDepth;

            sampler2D _GerstnerDisplacementTex, _GerstnerNormalTex;
            float _GerstnerTextureSize, _GerstnerTiling;

            sampler2D _InteractiveWaterNormalMap, _InteractiveWaterHeightMap;
            
            float ViewSpaceDepthColorFactor(v2f i)
            {
                float depthBufferValue = tex2Dproj(_CameraDepthTexture, i.screenPos).r;
                float bufferEyeDepth = LinearEyeDepth(depthBufferValue);
                float depthDiff = bufferEyeDepth - i.screenPos.w;
                return depthDiff / _DeepWaterDistance;
            }


            float WorldSpaceDepthDiff(float2 uv, float curPixelEyeDepth, float3 viewDirWS, float3 curPixelWorldPos, out float3 curPiexlDepthBufferWorldPos)
            {
                float depthBufferValue = tex2D(_CameraDepthTexture, uv).r;
                float bufferEyeDepth = LinearEyeDepth(depthBufferValue);
                curPiexlDepthBufferWorldPos = _WorldSpaceCameraPos + (bufferEyeDepth / curPixelEyeDepth) * viewDirWS;
                return  curPixelWorldPos.y - curPiexlDepthBufferWorldPos.y;
            }
            
            float FresnelSchlick(float NDotV, float F0)
            {
                return F0 + (1 - F0) * pow(1 - NDotV, 5);
            }

            float3 GetRefractColor(v2f i, float colorFactor, float3 normal)
            {
                if (colorFactor < 0.0000001)
                    return 0;
                float3 curPixelWorldPos = _WorldSpaceCameraPos + i.viewDirWS;

                float2 uvOffset = normal.xz * _RefractionStrength;
                uvOffset.y *= _CameraDepthTexture_TexelSize.z * abs(_CameraDepthTexture_TexelSize.y);
                float2 uv = (i.screenPos.xy + uvOffset) / i.screenPos.w;

                
                float3 curPiexlDepthBufferWorldPos;
                float depthDiff = WorldSpaceDepthDiff(uv, i.screenPos.w, i.viewDirWS, curPixelWorldPos, curPiexlDepthBufferWorldPos);
                uvOffset *= saturate(pow(depthDiff / _DeepWaterDistance, 1));//depthDiff < 0时，表示在水面上，将偏移置为 0，否则深度越大，偏移越大
                uv = (i.screenPos.xy + uvOffset) / i.screenPos.w;
                depthDiff = WorldSpaceDepthDiff(uv, i.screenPos.w, i.viewDirWS, curPixelWorldPos, curPiexlDepthBufferWorldPos);

    
                float lerpFactor = saturate(pow(depthDiff / _DeepWaterDistance, _DeepWaterLerpPow));
                //background
                float4 background = tex2D(_BackgroundTexture, uv);
                //Caustics
                // float3 caustics = tex2D(_CausticsTex, (curPiexlDepthBufferWorldPos.xz + normal.xy * _CausticsJitterScale) * _CausticsTilingAndSpeed.xy + _Time.y * _CausticsTilingAndSpeed.zw).rgb * _CausticsIntensity * lerpFactor; 
                // background += caustics;
                
                float4 waterColor = lerp(_ShallowColor, _DeepColor, lerpFactor);
                float3 refractedColor = lerp(background, waterColor, lerpFactor);
                return refractedColor * colorFactor;
            }

            float3 GetReflectColor(v2f i, float3 N, float3 H, float colorFactor)
            {
                if (colorFactor < 0.0000001)
                    return 0;
                
                //specular
                float NDotH = saturate(dot(N, H));
                float3 specular = _LightColor0 * pow(NDotH, _SpecularGloss);

                //SSR
                float3 curPixelWorldPos = _WorldSpaceCameraPos + i.viewDirWS;
                float3 ssrColor = SSR(_BackgroundTexture, _CameraDepthTexture,  i.viewDirWS, N, curPixelWorldPos.y);
                float3 reflectColor = specular + ssrColor;
                return reflectColor * colorFactor;
            }

            v2f vert (appdata v)
            {
                v2f o;
                float3 worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
                //Gersnter Wave位移
                // float3 displacement = tex2Dlod(_GerstnerDisplacementTex, float4(worldPos.xz / _GerstnerTextureSize * _GerstnerTiling, 0, 0)).xyz;
                float3 displacement = tex2Dlod(_GerstnerDisplacementTex, float4(v.uv, 0, 0)).xyz;
                //波动方程交互位移
                displacement.y += DecodeHeight(tex2Dlod(_InteractiveWaterHeightMap, float4(v.uv, 0, 0))) * 100;
                
                worldPos += displacement;
                v.vertex.xyz = mul(unity_WorldToObject, float4(worldPos, 1)).xyz;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv.xy = TRANSFORM_TEX(v.uv, _MainTex);
                o.uv.zw = TRANSFORM_TEX(v.uv + _Time.y * _WindSpeed, _NoiseTex);
                o.screenPos = ComputeScreenPos(o.vertex);
                float3 posWS = mul(unity_ObjectToWorld, v.vertex).xyz;
                o.viewDirWS = posWS - _WorldSpaceCameraPos;//这里是摄像机到顶点的向量，用于重建世界坐标

                o.normalOS = v.normal.xyz;
                o.tangentOS = v.tangent;
                o.normalUV = float4(TRANSFORM_TEX(v.uv, _NormalTex_0), TRANSFORM_TEX(v.uv, _NormalTex_1));
                return o;
            }

            float GetFoamMask(v2f i)
            {
                float3 curPixelWorldPos = _WorldSpaceCameraPos + i.viewDirWS;
                float depthBufferValue = tex2D(_CameraDepthTexture, i.screenPos.xy / i.screenPos.w).r;
                float bufferEyeDepth = LinearEyeDepth(depthBufferValue);
                float3 curPiexlDepthBufferWorldPos = _WorldSpaceCameraPos + (bufferEyeDepth / i.screenPos.w) * i.viewDirWS;
                float depthDiff = curPixelWorldPos.y - curPiexlDepthBufferWorldPos.y;
                float foam = depthDiff / _FoamDepth;
                float2 noiseUV = i.uv.xy * _FoamNoiseTex_ST.xy + _FoamNoiseTex_ST.zw;
                float noise = tex2D(_FoamNoiseTex, noiseUV + _Time.y * 0.1).r;
                return step(foam,noise);
            }

            fixed4 frag (v2f i) : SV_Target
            {
                //Normal
                float2 normalUV1 = i.normalUV.xy + _Time.y * _WaterSpeed.xy;
                float2 normalUV2 = i.normalUV.zw + _Time.y * _WaterSpeed.zw;
                float2 noise = tex2D(_NoiseTex, i.uv.zw) * _NoiseIntensity;
                noise = noise * 2 - 1;
                float3 normal0 = UnpackNormal(tex2D(_NormalTex_0, normalUV1 + noise));
                float3 normal1 = UnpackNormal(tex2D(_NormalTex_1, normalUV2 + noise));
                float3 normalTS = normal0 + normal1;
                normalTS.xy *= _NormalScale;


                float3 waveEquationNormal = UnpackNormal(tex2D(_InteractiveWaterNormalMap, i.uv.xy));
                normalTS += waveEquationNormal;
                
                normalTS = normalize(normalTS);
                float3 worldNormal = tex2D(_GerstnerNormalTex, i.uv.xy).xyz;
                worldNormal = float3(0, 1, 0);
                float3 worldTangent = normalize(UnityObjectToWorldNormal(i.tangentOS.xyz));
                float3 worldBinormal = cross(worldNormal, worldTangent) * i.tangentOS.w;
                float3 N = normalize(mul(normalTS, float3x3(worldTangent, worldBinormal, worldNormal)));

                #if defined(SHOW_NORMAL_WS)
                    return float4(N , 1);
                #endif
                
                float3 V = normalize(-i.viewDirWS);
                float3 L = _WorldSpaceLightPos0;
                float3 H = normalize(V + L);
                float NDotV = saturate(dot(N, V));
                float fresnel = FresnelSchlick(NDotV, 0.04);
                #if defined(SHOW_FRESNEL)
                    return fresnel;
                #endif
                
                float3 refractColor = GetRefractColor(i, 1 - fresnel, N);
                float3 reflectColor = GetReflectColor(i, N, H, fresnel);
                // return float4(reflectColor, 1);
                float foamMask = GetFoamMask(i);
                float3 finalColor = lerp(refractColor + reflectColor, _FoamColor, foamMask);
                return float4(finalColor, 1);
            }
            ENDCG
        }
    }
}
