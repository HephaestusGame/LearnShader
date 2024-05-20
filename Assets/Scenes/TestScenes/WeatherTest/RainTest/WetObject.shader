Shader "Weather/WetObject"
{
    Properties
    {
        [Header(Debug)]
        [Toggle(SHOW_VERTEX_COLOR)] _ShowVertexColor ("Show Vertex Color", Float) = 0
        
        [Space(30)]
        _MainTex ("Texture", 2D) = "white" {}
        _MetalicRAmbientOcclusionGSmoothnessA("Metalic (R) Ambient Occlusion (G) Smoothness (A)", 2D) = "white" {}
        _NormalMap ("Normal Map", 2D) = "bump" {}
        
        _LightIntensity ("Light Intensity", Range(0, 8)) = 1
        _SkyboxIntensity("Skybox Intensity", Range(0, 1)) = 0.5
        [Space(30)]
        [Toggle(USE_VERTEX_COLOR_G_FOR_PUDDLE)] _UseVertexColorGForPuddle ("Use Vertex Color G For Puddle", Float) = 0
        _PuddleFloodLevel("Puddle Flood Level", Range(0, 1)) = 0
        _PuddleMargin("Puddle Margin", Range(0.001, 1)) = 0.1
        _WetLevel("Base Wet Level", Range(0, 1)) = 0
        _BaseGlossiness("Base Glossiness", Range(0, 1)) = 0.5
        
        [Space(30)]
        [Header(Relief Mapping)]
        [Toggle(ENABLE_RELIEF_MAPPING)] _EnableReliefMapping ("Enable Relief Mapping", Float) = 0
        _HeightMap ("Height Map", 2D) = "black" {}
        _HeightScale ("Height Scale", Range(0, 1)) = 0.01
        

        [Space(30)]
        [Header(Wave)]
        [Toggle(ENABLE_WAVE)] _EnableWave ("Enable Wave", Float) = 1
        _WaveNormalMap ("Wave Normal Map", 2D) = "black" {}
        _WaveNormalFactor("Wave Normal Factor", Range(0.01, 20)) = 1
        _FlowSpeed("Flow Speed", Range(0.001, 1)) = 0.03
        
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_local _ ENABLE_RELIEF_MAPPING
            #pragma multi_compile_local _ SHOW_VERTEX_COLOR
            #pragma multi_compile_local _ ENABLE_WAVE
            #pragma multi_compile_local _ USE_VERTEX_COLOR_G_FOR_PUDDLE
            #include "UnityCG.cginc"
            #define PI 3.141592653
            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float4 tangent : TANGENT;
                float3 normal : NORMAL;
                float4 color : COLOR;
            };

            struct v2f
            {
                float4 vertex : SV_POSITION;
                float4 uv : TEXCOORD0;
                float3 normalWS : TEXCOORD1;
                float4 tangentWS : TEXCOORD2;
                float3 worldPos : TEXCOORD3;
                float4 vertexColor : TEXCOORD4;
            };

            sampler2D _MainTex, _NormalMap, _HeightMap, _MetalicRAmbientOcclusionGSmoothnessA;
            float4 _MainTex_ST;
            float _HeightScale, _LightIntensity, _SkyboxIntensity, _PuddleFloodLevel, _WetLevel, _BaseGlossiness;
            float _PuddleMargin;

            //Wave
            sampler2D _WaveNormalMap;
            float4 _WaveNormalMap_ST;
            float _WaveNormalFactor, _FlowSpeed;

            //浮雕视差映射
            float2 ReliefMappiing(float2 uv, float3 viewDirTS)
            {
                if (_HeightScale < 0.0000001f)
                    return uv;
                float2 offlayerUV = viewDirTS.xy / viewDirTS.z * _HeightScale;
                float RayNumber = 20;
                float layerHeight = 1.0 / RayNumber;
                float2 SteppingUV = offlayerUV / RayNumber;
                float offlayerUVL = length(offlayerUV);
                float currentLayerHeight = 0;
                
                float2 offuv= float2(0,0);
                for (int i = 0; i < RayNumber; i++)
                {
                    offuv += SteppingUV;

                    float currentHeight = tex2D(_HeightMap, uv + offuv).r;
                    currentLayerHeight += layerHeight;
                    if (currentHeight < currentLayerHeight)
                    {
                        break;
                    }
                }

                float2 T0 = uv-SteppingUV, T1 = uv + offuv;

                for (int j = 0;j<20;j++)
                {
                    float2 P0 = (T0 + T1) / 2;

                    float P0Height = tex2D(_HeightMap, P0).r;

                    float P0LayerHeight = length(P0) / offlayerUVL;

                    if (P0Height < P0LayerHeight)
                    {
                        T0 = P0;

                    }
                    else
                    {
                        T1= P0;
                    }

                }

                return (T0 + T1) / 2;
            }

            float3 SampleSky(float3 reflectWS, float gloss)
            {
                float4 skyData = UNITY_SAMPLE_TEXCUBE_LOD(unity_SpecCube0, reflectWS, (1.0 - gloss) * 8.0);
                float3 skyColor = DecodeHDR(skyData, unity_SpecCube0_HDR);
                return skyColor;
            }

            void DoWetProcess(inout float3 diffuse, inout float gloss, float wetLevel)
            {
                // Water influence on material BRDF
                diffuse    *= lerp(1.0, 0.3, wetLevel);                   // Attenuate diffuse
                gloss       = min(gloss * lerp(1.0, 2.5, wetLevel), 1.0); // Boost gloss
            }

            float3 GetWaveNormal(float3 worldPos, float3 worldNormal, float accumulatedWater)
            {
                #ifndef ENABLE_WAVE
                    return float3(0, 0, 1);
                #endif

                float flowFactor = smoothstep(0.95, 1.0, accumulatedWater);
                float2 offsetUV = float2(0, _Time.y * _FlowSpeed);
                float3 waveNormal1 = UnpackNormal(tex2D(_WaveNormalMap, worldPos.xy / float2(150, 300) * _WaveNormalMap_ST.xy + offsetUV));
                float3 waveNormal2 = UnpackNormal(tex2D(_WaveNormalMap, worldPos.xy / float2(75, 150) * _WaveNormalMap_ST.xy + offsetUV));
                
                float3 waveNormal3 = UnpackNormal(tex2D(_WaveNormalMap, worldPos.zy / float2(150, 300) * _WaveNormalMap_ST.xy + offsetUV));
                float3 waveNormal4 = UnpackNormal(tex2D(_WaveNormalMap, worldPos.zy / float2(75, 150) * _WaveNormalMap_ST.xy + offsetUV));
                float flowIntensity = pow(saturate(1.0f - saturate(worldNormal.y)), 2);
                float3 waveNormal = ((waveNormal1 + waveNormal2) * abs(worldNormal.z) + (waveNormal3 + waveNormal4) * abs(worldNormal.x)) * flowIntensity;
                waveNormal.xy *= _WaveNormalFactor;
                waveNormal = normalize(waveNormal);
                waveNormal = lerp(float3(0, 0, 1), waveNormal, flowFactor);
                return waveNormal;
            }

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv.xy = TRANSFORM_TEX(v.uv, _MainTex);
                o.uv.zw = TRANSFORM_TEX(v.uv, _WaveNormalMap);
                o.normalWS = UnityObjectToWorldNormal(v.normal);
                o.tangentWS = float4(UnityObjectToWorldNormal(v.tangent), v.tangent.w);
                o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
                o.vertexColor = v.color;
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                #if defined (SHOW_VERTEX_COLOR)
                    return i.vertexColor;
                #endif

                float puddleFloodLevel = _PuddleFloodLevel;
                float wetLevel = _WetLevel;
                
                float3 V = normalize(_WorldSpaceCameraPos - i.worldPos);
                float3 normalWS = normalize(i.normalWS);
                float3 tangentWS = normalize(i.tangentWS.xyz);
                float3 binormalWS = cross(normalWS, tangentWS) * i.tangentWS.w;
                float3x3 WorldToTangent = float3x3(tangentWS, binormalWS, normalWS);
                #if defined (ENABLE_RELIEF_MAPPING)
                    float3 V_TS = mul(WorldToTangent, V);
                    float2 uv = ReliefMappiing(i.uv, V_TS);
                #else
                    float2 uv = i.uv;
                #endif
                float3 baseDiffuse = tex2D(_MainTex, uv).rgb;
                
                float3 normalTS = UnpackNormal(tex2D(_NormalMap, uv));
                float3 N = mul(normalTS, WorldToTangent);
                
                
                float3 L = normalize(_WorldSpaceLightPos0);
                float3 H = normalize(V + L);

                float Gloss = tex2D(_MetalicRAmbientOcclusionGSmoothnessA, uv).a * _BaseGlossiness;
                float3 Specular = 0.04;// Default specular value for dieletric

                ////////////////
                //湿润度计算
                #if defined (USE_VERTEX_COLOR_G_FOR_PUDDLE)
                    float accumulatedWater = saturate((puddleFloodLevel - (1 - i.vertexColor.g)) / _PuddleMargin);
                #else
                    float accumulatedWater = puddleFloodLevel;
                #endif
               

                //wave Normal
                float3 waveNormal = GetWaveNormal(i.worldPos, N, accumulatedWater);
                waveNormal = mul(waveNormal, WorldToTangent);
                float3 waterNormal = normalize(waveNormal + N);

                float newWetLevel = saturate(wetLevel + accumulatedWater);
                DoWetProcess(baseDiffuse, Gloss, newWetLevel);
                Gloss = lerp(Gloss, 1.0, accumulatedWater);
                // Water F0 specular is 0.02 (based on IOR of 1.33)
                Specular = lerp(Specular, 0.02, accumulatedWater);
                N = lerp(N, waterNormal, accumulatedWater);
                ///////////////


                //光照计算
                float  dotVH = saturate(dot(V, H));
                float  dotNH = saturate(dot(N, H));
                float  dotNL = saturate(dot(N, L));
                float  dotNV = saturate(dot(N, V));
                
                float3 R = reflect(-V, N);
                float3 reflecColor = SampleSky(R, Gloss);
                // return float4(reflecColor, 1.0);
                // Fresnel for cubemap and Fresnel for direct lighting
                float3 SpecVH = Specular + (1.0 - Specular) * pow(1.0 - dotVH, 5.0);//FresnelSchlick  F0 + (1 - F0) * pow(1 - VDotH, 5)
                // Use fresnel attenuation from Call of duty siggraph 2011 talk
                float3 SpecNV = Specular + (1.0 - Specular) * pow(1.0 - dotNV, 5.0) / (4.0 - 3.0 * Gloss);
                // Convert Gloss [0..1] to SpecularPower [0..2048]
                float  SpecPower = exp2(Gloss * 11);
                // Lighting
                float3 DiffuseLighting     = dotNL * baseDiffuse;
                // Normalized specular lighting
                float3 SpecularLighting    = SpecVH * ((SpecPower + 2.0) / 8.0) * pow(dotNH, SpecPower) * dotNL;
                float3 AmbientSpecLighting = SpecNV * reflecColor;
               
                float3 FinalColor = _LightIntensity * (DiffuseLighting + SpecularLighting) + AmbientSpecLighting * _SkyboxIntensity;
                return float4(FinalColor, 1.0);
            }
            ENDCG
        }
    }
}
