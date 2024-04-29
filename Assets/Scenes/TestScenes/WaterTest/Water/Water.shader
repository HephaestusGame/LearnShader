Shader "Unlit/Water"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
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
        [Header(Wind)]
        [Space(5)]
        _NoiseTex("Noise Texture", 2D) = "black" {}
        _NoiseIntensity("Noise Intensity", Float) = 1
        _WindSpeed("Wind Speed", Vector) = (1, 1, 0, 0)
        
        [Space(30)]
        [Header(Normal)]
        [Space(5)]
        _NormalTex_0("Normal Texture 0", 2D) = "bump" {}
        _NormalTex_1("Normal Texture 1", 2D) = "bump" {}
        _NormalScale("Normal Scale", Float) = 1
        
        [Space(30)]
        [Header(SSR)]
        [Space(5)]
        _MaxStep("MaxStep",Float) = 10
        _StepSize("StepSize", Float) = 1
        _MaxDistance("MaxDistance",Float) = 10
        _Thickness("Thickness",Float) = 1
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
            #include "UnityCG.cginc"
            #include "Lighting.cginc"
            #include "WaterSSR.cginc"

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

            sampler2D _MainTex, _NoiseTex;
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

            float ViewSpaceDepthColorFactor(v2f i)
            {
                float depthBufferValue = tex2Dproj(_CameraDepthTexture, i.screenPos).r;
                float bufferEyeDepth = LinearEyeDepth(depthBufferValue);
                float depthDiff = bufferEyeDepth - i.screenPos.w;
                return depthDiff / _DeepWaterDistance;
            }


            float WorldSpaceDepthDiff(float2 uv, float curPixelEyeDepth, float3 viewDirWS, float3 curPixelWorldPos)
            {
                float depthBufferValue = tex2D(_CameraDepthTexture, uv).r;
                float bufferEyeDepth = LinearEyeDepth(depthBufferValue);
                float3 curPiexlDepthBufferWorldPos = _WorldSpaceCameraPos + (bufferEyeDepth / curPixelEyeDepth) * viewDirWS;
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

                float2 uvOffset = normal.xy * _RefractionStrength;
                uvOffset.y *= _CameraDepthTexture_TexelSize.z * abs(_CameraDepthTexture_TexelSize.y);
                float2 uv = (i.screenPos.xy + uvOffset) / i.screenPos.w;

                
                float depthDiff = WorldSpaceDepthDiff(uv, i.screenPos.w, i.viewDirWS, curPixelWorldPos);
                uvOffset *= saturate(pow(depthDiff / _DeepWaterDistance, 1));//depthDiff < 0时，表示在水面上，将偏移置为 0，否则深度越大，偏移越大
                uv = (i.screenPos.xy + uvOffset) / i.screenPos.w;
                depthDiff = WorldSpaceDepthDiff(uv, i.screenPos.w, i.viewDirWS, curPixelWorldPos);

                
                float lerpFactor = saturate(pow(depthDiff / _DeepWaterDistance, _DeepWaterLerpPow));
                float4 background = tex2D(_BackgroundTexture, uv);
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
                float3 ssrColor = SSR(_BackgroundTexture, _CameraDepthTexture,  i.viewDirWS, N);
                float3 reflectColor = specular + ssrColor;
                return reflectColor * colorFactor;
            }

            v2f vert (appdata v)
            {
                v2f o;
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
                normalTS = normalize(normalTS);
                float3 worldNormal = normalize(UnityObjectToWorldNormal(i.normalOS));
                float3 worldTangent = normalize(UnityObjectToWorldNormal(i.tangentOS.xyz));
                float3 worldBinormal = cross(worldNormal, worldTangent) * i.tangentOS.w;
                float3 N = normalize(mul(normalTS, float3x3(worldTangent, worldBinormal, worldNormal)));
                float3 V = normalize(-i.viewDirWS);
                float3 L = _WorldSpaceLightPos0;
                float3 H = normalize(V + L);
                float NDotV = saturate(dot(N, V));
                float fresnel = FresnelSchlick(NDotV, 0.04);
                float3 refractColor = GetRefractColor(i, 1 - fresnel, normalTS);
                return float4(GetReflectColor(i, N, H, 1), 1);
                float3 reflectColor = GetReflectColor(i, N, H, fresnel);
                float3 finalColor = refractColor + reflectColor;
                return float4(finalColor, 1);
            }
            ENDCG
        }
    }
}
