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
        [Toggle(USE_WORLD_SPACE_DEPTH_DIFFERENCE)] _UseWorldSpaceDepthDifference("Use World Space Depth Difference", Float) = 1

        
        _SpecularGloss("Specular Gloss", Range(0, 500)) = 10
        _SpecularIntensity("Specular Intensity", Range(0, 100)) = 1
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
        [Toggle(ENABLE_GERSTNER_WAVE)] _EnableGerstnerWave("Enable Gerstner Wave", Float) = 0
        _GerstnerDisplacementTex("Gerstner Displacement Texture", 2D) = "black" {}
        _GerstnerNormalTex("Gerstner Normal Texture", 2D) = "black" {}
        _GerstnerTextureSize("Gerstner Texture Size", Float) = 256
        _GerstnerTiling("Gerstner Tiling", Float) = 0.01
        
        
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
        _WaterSpeed("Water Speed", Vector) = (1, 1, 1, 1)

        
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
        [Toggle(ENABLE_FOAM)] _EnableFoam("Enable Foam", Float) = 0
        _FoamTex("Foam Texture", 2D) = "white" {}
        _FoamNoiseTex("Foam Noise Texture", 2D) = "white" {}
        _FoamDepth("Foam Depth", Float) = 3
        _FoamColor("Foam Color", Color) = (1, 1, 1, 1)
        _FoamFactor1("Foam Factor 1", Range(0, 1)) = 0.1
        _FoamFactor2("Foam Factor 2", Range(0, 1)) = 0.05
        _FoamEdgeChangeSpeed("Foam Edge Change Speed", Range(0, 10)) = 0.1
        _FoamSpeed("Foam Speed", Range(0, 10)) = 1
        _FoamUVOffsetFactor("Foam UV Offset Factor", Range(0, 1)) = 1
    }
    SubShader
    {
        Tags 
        { 
            "RenderType" = "Transparent" 
            "Queue" = "Transparent"
            "LightMode"="ForwardBase"
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
            #pragma multi_compile_local _ ENABLE_GERSTNER_WAVE
            #pragma multi_compile_local _ USE_WORLD_SPACE_DEPTH_DIFFERENCE
            #pragma multi_compile_local _ ENABLE_FOAM
            #pragma multi_compile_fwdbase
            
            #include "UnityCG.cginc"
            #include "Lighting.cginc"
            #include "AutoLight.cginc"
            #include "WaterSSR.cginc"
            #include "InteractiveWaterUtils.cginc"
            #include "Foam.cginc"
            #include "DepthUtils.cginc"

            struct appdata
            {
                float4 vertex : POSITION;//使用内置阴影的话，这里的变量名必须是vertex
                float4 tangent : TANGENT;
                float4 normal : NORMAL;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float4 pos : SV_POSITION;//使用内置阴影的话，这里的变量名必须是pos
                float4 uv : TEXCOORD0;
                float4 screenPos : TEXCOORD1;
                float3 viewDirWS : TEXCOORD2;
                float3 normalOS : TEXCOORD3;
                float4 tangentOS : TEXCOORD4;
                float4 normalUV : TEXCOORD5;
                SHADOW_COORDS(6)
            };

            sampler2D _MainTex, _NoiseTex, _CausticsTex;
            float4 _MainTex_ST, _NoiseTex_ST;

            
            float _DeepWaterDistance, _DeepWaterLerpPow, _SpecularGloss, _SpecularIntensity, _NormalScale, _NoiseIntensity, _RefractionStrength;
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


           

            sampler2D _GerstnerDisplacementTex, _GerstnerNormalTex;
            float _GerstnerTextureSize, _GerstnerTiling;

            sampler2D _InteractiveWaterNormalMap, _InteractiveWaterHeightMap;
            float _InteractiveWaterMaxHeight;
            
            
            float FresnelSchlick(float NDotV, float F0)
            {
                return F0 + (1 - F0) * pow(1 - NDotV, 5);
            }

            float3 GetRefractColor(v2f i, float colorFactor, float3 normal)
            {
                if (colorFactor < 0.0000001)
                    return 0;

                float2 uvOffset = normal.xz * _RefractionStrength;
                uvOffset.y *= _CameraDepthTexture_TexelSize.z * abs(_CameraDepthTexture_TexelSize.y);
                float2 uv = (i.screenPos.xy + uvOffset) / i.screenPos.w;

                
                float depthDiff = WorldSpaceDepthDiff(uv, i.screenPos.w, i.viewDirWS);
                uvOffset *= saturate(pow(depthDiff / _DeepWaterDistance, 1));//depthDiff < 0时，表示在水面上，将偏移置为 0，否则深度越大，偏移越大
                uv = (i.screenPos.xy + uvOffset) / i.screenPos.w;
                depthDiff = WorldSpaceDepthDiff(uv, i.screenPos.w, i.viewDirWS);

    
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

                float3 curPixelWorldPos = _WorldSpaceCameraPos + i.viewDirWS;
                
                //specular
                float shadow = SHADOW_ATTENUATION(i);
                float NDotH = saturate(dot(N, H));
                float3 specular = _LightColor0 * pow(NDotH, _SpecularGloss) * _SpecularIntensity * shadow;

                //SSR
                
                float3 ssrColor = SSR(_BackgroundTexture, _CameraDepthTexture,  i.viewDirWS, N, curPixelWorldPos.y);
                float3 reflectColor = specular + ssrColor;
                return reflectColor * colorFactor;
            }

            v2f vert (appdata v)
            {
                v2f o;
                float3 worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
                float3 displacement = 0;
                #if defined(ENABLE_GERSTNER_WAVE)
                    //Gersnter Wave位移
                    displacement += tex2Dlod(_GerstnerDisplacementTex, float4(v.uv, 0, 0)).xyz;
                #endif
                //波动方程交互位移
                displacement.y += DecodeHeight(tex2Dlod(_InteractiveWaterHeightMap, float4(v.uv, 0, 0))) * _InteractiveWaterMaxHeight;
                
                worldPos += displacement;
                v.vertex.xyz = mul(unity_WorldToObject, float4(worldPos, 1)).xyz;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv.xy = TRANSFORM_TEX(v.uv, _MainTex);
                o.uv.zw = TRANSFORM_TEX(v.uv + _Time.y * _WindSpeed, _NoiseTex);
                o.screenPos = ComputeScreenPos(o.pos);
                float3 posWS = mul(unity_ObjectToWorld, v.vertex).xyz;
                o.viewDirWS = posWS - _WorldSpaceCameraPos;//这里是摄像机到顶点的向量，用于重建世界坐标

                o.normalOS = v.normal.xyz;
                o.tangentOS = v.tangent;
                o.normalUV = float4(TRANSFORM_TEX(v.uv, _NormalTex_0), TRANSFORM_TEX(v.uv, _NormalTex_1));
                TRANSFER_SHADOW(o);
                return o;
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

                #if defined(ENABLE_GERSTNER_WAVE)
                    float3 worldNormal = tex2D(_GerstnerNormalTex, i.uv.xy).xyz;
                #else
                    float3 worldNormal = UnityObjectToWorldNormal(i.normalOS);
                #endif
                
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
                #if defined(ENABLE_FOAM)
                    float foamMask = GetFoamMask(i.uv, i.screenPos, i.viewDirWS, N);
                    float3 finalColor = lerp(refractColor + reflectColor, _FoamColor, foamMask);
                    return float4(finalColor, 1);
                #endif
                return float4(refractColor + reflectColor, 1);
            }
            ENDCG
        }
    }
}
