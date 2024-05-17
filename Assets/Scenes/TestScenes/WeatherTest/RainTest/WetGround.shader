// Upgrade NOTE: replaced 'defined SHOW_VERTEX_COLOR' with 'defined (SHOW_VERTEX_COLOR)'

// Upgrade NOTE: replaced 'defined ENABLE_RELIEF_MAPPING' with 'defined (ENABLE_RELIEF_MAPPING)'

Shader "Weather/WetGround"
{
    Properties
    {
        [Toggle(USE_TIMELINE)] _UseTimeline("Use Timeline", Float) = 0
        _AnimationLength("Animation Length", Float) = 10
        _PuddleAnimTime("Puddle Animation Time", Range(1, 10)) = 1
        _CrackAndHoleAnimTime("Crack And Hole Animation Time", Range(1, 10)) = 1
        _TimelineTexture("Timeline Texture", 2D) = "black" {}
        
        [Space(30)]
        _MainTex ("Texture", 2D) = "white" {}
        _NormalMap ("Normal Map", 2D) = "bump" {}
        _HeightMap ("Height Map", 2D) = "white" {}
        _RippleTexture ("Ripple Normal", 2D) = "black" {}
        _RippleTiling ("Ripple Tiling", Float) = 0.05
        _HeightScale ("Height Scale", Range(0, 1)) = 0.01
        _LightIntensity ("Light Intensity", Range(0, 8)) = 1
        _SkyboxIntensity("Skybox Intensity", Range(0, 1)) = 0.5
        [Space(30)]
        _CrackAndHoleFloodLevel("Crack And Hole Flood Level", Range(0, 1)) = 0
        _PuddleFloodLevel("Puddle Flood Level", Range(0, 1)) = 0
        _PuddleMargin("Puddle Margin", Range(0.001, 1)) = 0.1
        _WetLevel("Base Wet Level", Range(0, 1)) = 0
        _BaseGlossiness("Base Glossiness", Range(0, 1)) = 0.5
        _RainIntensity("Rain Intensity", Range(0, 1)) = 0
        
        [Toggle(ENABLE_RELIEF_MAPPING)] _EnableReliefMapping ("Enable Relief Mapping", Float) = 0
        [Toggle(SHOW_VERTEX_COLOR)] _ShowVertexColor ("Show Vertex Color", Float) = 0
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
            #pragma multi_compile_local _ USE_TIMELINE
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
                float2 uv : TEXCOORD0;
                float3 normalWS : TEXCOORD1;
                float4 tangentWS : TEXCOORD2;
                float3 worldPos : TEXCOORD3;
                float4 vertexColor : TEXCOORD4;
            };

            sampler2D _MainTex, _NormalMap, _HeightMap, _RippleTexture;
            float4 _MainTex_ST;
            float _HeightScale, _LightIntensity, _SkyboxIntensity, _CrackAndHoleFloodLevel, _PuddleFloodLevel, _WetLevel, _BaseGlossiness;
            float _PuddleMargin, _RainIntensity, _RippleTiling;

            sampler2D _TimelineTexture;
            float _AnimationLength, _PuddleAnimTime, _CrackAndHoleAnimTime;

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

            // Compute a ripple layer for the current time
            float3 ComputeRipple(float2 UV, float CurrentTime, float Weight)
            {
               float4 Ripple = tex2D(_RippleTexture, UV);
               Ripple.yz = Ripple.yz * 2.0 - 1.0;
                        
               float DropFrac = frac(Ripple.w + CurrentTime);
               float TimeFrac = DropFrac - 1.0 + Ripple.x;
               float DropFactor = saturate(0.2 + Weight * 0.8 - DropFrac);
               float FinalFactor = DropFactor * Ripple.x * sin( clamp(TimeFrac * 9.0, 0.0f, 3.0) * PI);
               
               return float3(Ripple.yz * FinalFactor * 0.35, 1.0);
            }

            float3 GetRippleNormal(float2 UV, float rainIntensity)
            {
                // #if USE_TIMELINE
                //    float  AnimTime = fmod(_Time.y, _AnimationLength); // Time is in seconds
                //    float4 AnimateValues = tex2Dlod(_TimelineTexture, float4(AnimTime / _AnimationLength, 0.5, 0.0, 0.0));
                //    float  RainIntensity = AnimateValues.x;
                // #endif
                float4 TimeMul = float4(1.0f, 0.85f, 0.93f, 1.13f);
                float4 TimeAdd  = float4(0.0f, 0.2f, 0.45f, 0.7f);
                float GlobalMul = 1.6f;

                float4 Times = (_Time.y * TimeMul + TimeAdd) * GlobalMul;
               
                Times = frac(Times);
                    
                float2 UVRipple = UV;
               
                float4 Weights = rainIntensity - float4(0, 0.25, 0.5, 0.75);
                Weights = saturate(Weights * 4);   
               
                float3 Ripple1 = ComputeRipple(UVRipple + float2( 0.25f,0.0f), Times.x, Weights.x);
                float3 Ripple2 = ComputeRipple(UVRipple + float2(-0.55f,0.3f), Times.y, Weights.y);
                float3 Ripple3 = ComputeRipple(UVRipple + float2(0.6f, 0.85f), Times.z, Weights.z);
                float3 Ripple4 = ComputeRipple(UVRipple + float2(0.5f,-0.75f), Times.w, Weights.w);

                // Merge the 4 layers
                float4 Z = lerp(1, float4(Ripple1.z, Ripple2.z, Ripple3.z, Ripple4.z), Weights);
                float3 Normal = float3( Weights.x * Ripple1.xy +
                                       Weights.y * Ripple2.xy + 
                                       Weights.z * Ripple3.xy + 
                                       Weights.w * Ripple4.xy, 
                                       Z.x * Z.y * Z.z * Z.w);
               
                float3 TextureNormal = normalize(Normal);
                return TextureNormal;
            }

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
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


                float crackAndHoleFloodLevel = _CrackAndHoleFloodLevel;
                float puddleFloodLevel = _PuddleFloodLevel;
                float wetLevel = _WetLevel;
                float rainIntensity = _RainIntensity;
                
                #if USE_TIMELINE
                    // float  AnimTime = fmod(_Time.y, _AnimationLength); // Time is in seconds
                    // float4 AnimateValues = tex2Dlod(_TimelineTexture, float4(AnimTime / _AnimationLength, 0.5, 0.0, 0.0));
                    // crackAndHoleFloodLevel = AnimateValues.z;
                    // puddleFloodLevel = AnimateValues.w;
                    // wetLevel = AnimateValues.y;
                    // rainIntensity = AnimateValues.x;
                    float totalTime = 2 * (_PuddleAnimTime + _CrackAndHoleAnimTime);
                    float  animTime = fmod(_Time.y, totalTime);
                    if (animTime < _CrackAndHoleAnimTime)
                    {
                        rainIntensity = wetLevel = crackAndHoleFloodLevel =  animTime / _CrackAndHoleAnimTime;
                        puddleFloodLevel = 0;
                    } else if (animTime < _CrackAndHoleAnimTime + _PuddleAnimTime)
                    {
                        rainIntensity = wetLevel = crackAndHoleFloodLevel = 1;
                        puddleFloodLevel = (animTime - _CrackAndHoleAnimTime) / _PuddleAnimTime;
                    } else if (animTime < 2 * _CrackAndHoleAnimTime + _PuddleAnimTime)
                    {
                        rainIntensity = wetLevel = crackAndHoleFloodLevel = 1 - (animTime - _CrackAndHoleAnimTime - _PuddleAnimTime) / _CrackAndHoleAnimTime;
                        puddleFloodLevel = 1;
                    } else
                    {
                        rainIntensity = wetLevel = crackAndHoleFloodLevel = 0;
                        puddleFloodLevel = 1 - (animTime - 2 * _CrackAndHoleAnimTime - _PuddleAnimTime) / _PuddleAnimTime;
                    }
                #endif
                
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

                // Glossiness store in alpha channel of the normal map
                float Gloss = tex2D(_NormalMap, uv).a * _BaseGlossiness;
                float3 Specular = 0.04;// Default specular value for dieletric

                ////////////////
                //湿润度计算
                float2 accumulatedWaters = float2(0, 0);//x: HeightMap, y: vertexColor
                float heightMap = tex2D(_HeightMap, uv).r;
                accumulatedWaters.x = min(crackAndHoleFloodLevel, 1 - heightMap);
                accumulatedWaters.y = saturate((puddleFloodLevel - (1 - i.vertexColor.g * 2)) / _PuddleMargin);
                float accumulatedWater = max(accumulatedWaters.x, accumulatedWaters.y);

                float3 waterNormal = float3(0, 1, 0);
                // Ripple part
                float3 RippleNormal  = GetRippleNormal(i.worldPos.xz * _RippleTiling, rainIntensity);
               
                // return float4(RippleNormal, 1);
                RippleNormal = mul(RippleNormal, WorldToTangent); 
                // saturate(RainIntensity * 100.0) to be 1 when RainIntensity is > 0 and 0 else
                waterNormal  = lerp(waterNormal, RippleNormal, saturate(rainIntensity)); 

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
