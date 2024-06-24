Shader "Hidden/PostProcessing/VolumetricCloud"
{
    
    SubShader
    {
        Cull Off ZWrite Off ZTest Always
        Pass
        {
            HLSLPROGRAM
            #include "Packages/com.unity.postprocessing/PostProcessing/Shaders/StdLib.hlsl"
            #include "../CloudHelper.hlsl"

             
            #pragma vertex VertDefault
            #pragma fragment Frag
            #pragma multi_compile_local _ ENABLE_DIRECTIONAL_SCATTERING
            #pragma multi_compile_local USE_AABB_BOUNDING_BOX  USE_CLOUD_LAYER_BOUNDING_BOX
            #pragma multi_compile_local _ USE_DETAIL_SHAPE_TEX
           
            TEXTURE2D_SAMPLER2D(_MainTex, sampler_MainTex);
            TEXTURE2D_SAMPLER2D(_CameraDepthTexture, sampler_CameraDepthTexture);

            #define EARTH_RADIUS  6371000

            sampler3D _NoiseTexture3D;
            
            

            //Unity 内置变量
            float3 _WorldSpaceLightPos0;
            float4 _LightColor0;
            
            int _RayMarchSteps;
            float _RayMarchStepSize, _DensityScale, _LightAbsorption;

            float _BaseDetailFactor;
            //云层覆盖率
            float _CloudCoverageRate;

            //散射
            float _ScatterForward, _ScatterForwardIntensity, _ScatterBackward, _ScatterBackwardIntensity;
            float _ScatterBase, _ScatterIntensity;
            
            float _NoiseTextureTiling;
            float3 _NoiseTextureOffset;
            
            float4x4 _InverseProjectionMatrix, _InverseViewMatrix;
            float _DarknessThreshold, _MidToneColorOffset;
            float4 _BrightColor, _MidToneColor, _DarkColor;

            //AABB BoundingBox
            float3 _BoundsMin;
            float3 _BoundsMax;

            //Cloud Layer BoungdingBox
            float _CloudLayerHeightMin;
            float _CloudLayerHeightMax;

            //云分布、形状控制
            sampler2D _WeatherMap;
            float3 _StratusRangeAndFeather;
            float3 _CumulusRangeAndFeather;

            sampler3D _DetailShapeTex;
            float _DetailShapeTiling;
            float _DetailFactor;

            sampler2D _BlueNoiseTex;
            float _BlueNoiseTexTiling;
            float _BlueNoiseAffectFactor;

            //Wind
            float3 _WindDirection;
            float _WindSpeed;

            //计算世界空间坐标
            float4 GetWorldSpacePosition(float depth, float2 uv)
            {
                 float4 viewPos = mul(_InverseProjectionMatrix, float4(2.0 * uv - 1.0, depth, 1.0));
                 viewPos.xyz /= viewPos.w;//详细推导见笔记中深度雾重建世界坐标部分
                 float4 worldPos = mul(_InverseViewMatrix, float4(viewPos.xyz, 1));
                 return worldPos;
            }
            
            

            CloudInfo SampleDensity(float3 sphereCenter, float3 worldPos, bool useDetail = true)
            {
                CloudInfo o;
                //采样天气纹理，默认按照100km平铺, r 密度, g 吸收率, b 云类型(0~1 => 层云~积云)
                float3 wind = _WindDirection * _WindSpeed * _Time.y;
                float3 position = worldPos + wind * 100;

                
                float3 weatherData = tex2D(_WeatherMap, worldPos.xz * 0.00001 + wind.xz * 0.01).xyz;
                float density = Interpolation3(0, weatherData.r, 1.0, _CloudCoverageRate);
                float cloudType = Interpolation3(0, weatherData.b, 1.0, _CloudCoverageRate);
                if (density <= 0)
                {
                    o.density = 0;
                    o.absorptivity = 1;
                    return o;    
                }

                float heightFraction = GetHeightFraction(sphereCenter, EARTH_RADIUS, worldPos, _CloudLayerHeightMin, _CloudLayerHeightMax);
                float stratusDensity = GetCloudTypeDensity(heightFraction, _StratusRangeAndFeather.x, _StratusRangeAndFeather.y, _StratusRangeAndFeather.z);
                float cumulusDensity = GetCloudTypeDensity(heightFraction, _CumulusRangeAndFeather.x, _CumulusRangeAndFeather.y, _CumulusRangeAndFeather.z);
                float cloudTypeDensity = lerp(stratusDensity, cumulusDensity, cloudType);
                if (cloudTypeDensity <= 0)
                {
                    o.density = 0;
                    o.absorptivity = 1;
                    return o;
                }


                float4 baseTex = tex3D(_NoiseTexture3D, position * _NoiseTextureTiling * 0.0001);
                //构建基础纹理的FBM
                float baseTexFBM = dot(baseTex.gba, float3(0.5, 0.25, 0.125));
                float baseShape = Remap(baseTex.r, saturate((1.0 - baseTexFBM) * _BaseDetailFactor), 1.0, 0.0, 1.0);      
                float cloudDensity = baseShape * density * cloudTypeDensity;

               
                
                #if defined(USE_DETAIL_SHAPE_TEX)
                    if (cloudDensity > 0 && useDetail)
                    {
                        position += (_WindDirection + float3(0, 0.1, 0)) * _WindSpeed * _Time.y * 0.1;
                        float3 detailTex = tex3D(_DetailShapeTex, position * _DetailShapeTiling * 0.0001).rgb;
                        float detailTexFBM = dot(detailTex, float3(0.5, 0.25, 0.125));
                        cloudDensity = Remap(cloudDensity, detailTexFBM * _DetailFactor, 1.0, 0.0, 1.0);
                    }
                    
                #endif
                
                    
                o.density = cloudDensity * _DensityScale * 0.01;
                o.absorptivity = Interpolation3(0.0, weatherData.g, 1.0, _LightAbsorption);
                return o;
            }

            float3 LightRayMarching(float3 startPoint, float absorptivity)
            {
                float3 lightDir = normalize(_WorldSpaceLightPos0.xyz);

                float3 cameraPosWS = _WorldSpaceCameraPos.xyz;
                float3 sphereCenter = float3(cameraPosWS.x, -EARTH_RADIUS, cameraPosWS.z);
                
                #if defined(USE_AABB_BOUNDING_BOX)
                    float distInsideBox = RayBoxDist(_BoundsMin, _BoundsMax, startPoint, 1.0 / lightDir).y;
                #else
                    float distInsideBox = RayCloudLayerDist(
                    sphereCenter, EARTH_RADIUS,
                    _CloudLayerHeightMin, _CloudLayerHeightMax,
                    startPoint, lightDir, false).y;
                #endif
                
                float stepSize = distInsideBox / 8.0;
                float totalDensity = 0;
                float3 curPos = startPoint;
                for(int step = 0; step < 8; step++)
                {
                    curPos += lightDir * stepSize;
                    totalDensity += SampleDensity(sphereCenter, curPos, false).density * stepSize;
                }

                //透光率公式
                float lightTransmittance = BeerPowder(totalDensity, absorptivity);
                lightTransmittance = saturate(_DarknessThreshold + lightTransmittance * (1.0 - _DarknessThreshold));
                

                float3 cloudColor = Interpolation3(_DarkColor.xyz, _MidToneColor.xyz, _BrightColor.xyz, lightTransmittance, _MidToneColorOffset);
                cloudColor *= _LightColor0.rgb;
                return cloudColor;
            }

            float4 CloudRayMarching(float2 uv, float3 cameraOrigin, float3 viewDir)
            {
                
                float originToSceneObjDist = length(viewDir);
                viewDir = normalize(viewDir);
                float3 invDir = 1.0 / viewDir;


                float3 sphereCenter = float3(cameraOrigin.x, -EARTH_RADIUS, cameraOrigin.z);
                #if defined(USE_AABB_BOUNDING_BOX)
                    float2 dist = RayBoxDist(_BoundsMin, _BoundsMax, cameraOrigin, invDir);
                #else
                    
                    float2 dist = RayCloudLayerDist(
                    sphereCenter, EARTH_RADIUS,
                    _CloudLayerHeightMin, _CloudLayerHeightMax,
                    cameraOrigin, viewDir);
                #endif
                
                
                //包围盒入口点到场景物体的距离
                float boxEntranceToSceneObjDist = originToSceneObjDist - dist.x;
                //体积云被场景遮盖，不需要进行步进
                if (boxEntranceToSceneObjDist <= 0 || dist.y <= 0)
                {
                    return float4(0, 0, 0, 1);
                }
                float rayMarchDist = min(dist.y, boxEntranceToSceneObjDist);
                float3 curPos = cameraOrigin + viewDir * dist.x;

                int rayMarchStep = floor(rayMarchDist / _RayMarchStepSize);
                rayMarchStep = min(rayMarchStep, _RayMarchSteps);

                //蓝噪声偏移起始点
                float blueNoise = tex2D(_BlueNoiseTex, float2(uv.x * 1.7, uv.y) * _BlueNoiseTexTiling).r;
                curPos += viewDir * blueNoise * _RayMarchStepSize * _BlueNoiseAffectFactor;


                
                //描述方向散射（云层主要为向前散射）
                #if defined(ENABLE_DIRECTIONAL_SCATTERING)
                    float3 lightDir = normalize(_WorldSpaceLightPos0.xyz);
                    // float phase = HGScatterLerp(dot(viewDir, lightDir), _ScatterForward, -_ScatterForward, 0.5f);
                    float phase = HGScatterMax(dot(viewDir, lightDir), _ScatterForward, _ScatterForwardIntensity, -_ScatterBackward, _ScatterBackwardIntensity);
                    phase = _ScatterBase + phase * _ScatterIntensity;
                #else
                    float phase = 1.0f;
                #endif
                
                float totalDensity = 0, lightAttenuation = 1.0f;
                float3 totalLum = 0;
                
                UNITY_LOOP
                for (int i = 0; i < rayMarchStep; i++)
                {
                    curPos += viewDir * _RayMarchStepSize;
                    CloudInfo cloudInfo = SampleDensity(sphereCenter, curPos);

                    //步进区间密度
                    float density = cloudInfo.density * _RayMarchStepSize;
                    if (density > 0.01)
                    {
                        //当前位置光照
                        float3 color = LightRayMarching(curPos, cloudInfo.absorptivity);
                        //当前步进区间光照
                        color *= density;
                        //根据Beer定律对视线方向进行衰减，加上方向散射的影响
                        totalLum += lightAttenuation * color * phase;
                        totalDensity += density;

                        //根据Beer定律对视线方向进行衰减
                        lightAttenuation *= Beer(density, cloudInfo.absorptivity);
                        if (lightAttenuation < 0.01)
                        {
                            break;
                        }
                    }
                }

               
                totalLum = pow(totalLum, 1 / 2.2f);
                // totalLum.rgb = min(totalLum.rgb, 60.0);
                // totalLum.rgb /= totalLum.rgb + 1.0f;//Reinhard Tonemapping
                return float4(totalLum, lightAttenuation);
            }
            

            
            float4 Frag(VaryingsDefault i) : SV_Target
            {
                float depth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_CameraDepthTexture, i.texcoord);
                float4 worldPos = GetWorldSpacePosition(depth, i.texcoord);
                float3 rayPos = _WorldSpaceCameraPos;
                float3 worldViewDir = worldPos.xyz - rayPos.xyz;
                
                float4 cloudColor = CloudRayMarching(i.texcoord, _WorldSpaceCameraPos.xyz, worldViewDir);

                float4 color = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.texcoord);
                return float4(cloudColor.rgb + color.rgb * cloudColor.a,  cloudColor.a + color.a * cloudColor.a);
            }
            ENDHLSL
        }
    }
}