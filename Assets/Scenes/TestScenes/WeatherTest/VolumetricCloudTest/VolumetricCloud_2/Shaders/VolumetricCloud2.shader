Shader "Cloud/VolumetricCloud2"
{
    Properties
    {
        
        _SunColor("Sun Color", Color) = (1, 1, 1, 1)
        _MoonColor("Moon Color", Color) = (1, 1, 1, 1)
        _MoonAttenuation("Moon Attenuation", Float) = 0.1
        
        _CloudBottom("Cloud Bottom", Float) = 500
        _CloudHeight("Cloud Height", Float) = 800
        
        _CloudCoverage ("Cloud Coverage", Range(0, 1)) = 0.3
        _CloudCoverageBias ("Cloud Coverage Bias", Range(-1, 1)) = 0.0
        
        _Attenuation("Attenuation", Float) = 1.0
        _CloudMovementSpeed("Cloud Movement Speed", Range(0.0, 150)) = 150
        _CloudTurbulenceSpeed("Cloud Turbulence Speed", Range(0.0, 50)) = 50
        
        _CloudDetailStrength("Cloud Detail Strength", Range(0, 1)) = 0.5
        _CloudBaseEdgeSoftness("Cloud Base Edge Softness", Float) = 0.025
        _CloudBottomSoftness("Cloud Bottom Softness", Float) = 0.4
        _CloudDensity("Cloud Density", Range(0., 1.0)) = 1.0
        

        _CloudAmbientColorTop("Cloud Ambient Color Top", Color) = (0.87674, 0.98235, 1.1764, 0.0)
        _CloudAmbientColorBottom("Cloud Ambient Color Bottom", Color) = (0.2294, 0.3941, 0.5117, 0.0)
        _CloudBaseScale("Cloud Base Scale", Float) = 1.72
        _CloudDetailScale("Cloud Detail Scale", Float) = 1000
       
        _HorizonFadeStart("Horizon Fade Start", Float) = 0
        _HorizonFadeEnd("Horizon Fade End", Float) = 0.18
        _HorizonColorFadeStart("Horizon Color Fade Start", Float) = -0.2
        _HorizonColorFadeEnd("Horizon Color Fade End", Float) = 0.32
        
        _CloudAlpha("Cloud Alpha", Range(0.0, 5)) = 3.25
        
    }
    SubShader
    {
        Cull Off ZWrite Off ZTest Always
        Pass
        {
            CGPROGRAM
            // #include "Packages/com.unity.postprocessing/PostProcessing/Shaders/StdLib.hlsl"
            #include "../../CloudHelper.hlsl"
            #include "UnityCG.cginc"

            #pragma multi_compile_local _ USE_CLOUD_SHAPE_CURVE

            #pragma vertex vert
            #pragma fragment Frag
            #define EARTH_RADIUS  6371000
            

            static const int CLOUD_SELF_SHADOW_STEPS = 5;

            float3 _SunDir, _MoonDir;
            float4 _SunColor, _MoonColor;
            float _TexSize;
            float2 _Jitter;
            
            //Unity 内置变量
            float4 _LightColor0;

            sampler2D _BaseNoise, _BlueNoise, _CloudShapeTexture;
            sampler3D _DetailNoise;

            float4x4 _InverseProjectionMatrix, _InverseViewMatrix;

            float3 _CloudAmbientColorBottom, _CloudAmbientColorTop, _CloudColor;

            float _CloudBearing;
            float _CloudBottom, _CloudHeight, _CloudBaseScale, _CloudDetailScale, _CloudDetailStrength;
            float _CloudBaseEdgeSoftness, _CloudBottomSoftness, _CloudCoverage, _CloudCoverageBias;
            float _CloudDensity, _Attenuation, _MoonAttenuation, _CloudAlpha;
            float _CloudMovementSpeed, _CloudTurbulenceSpeed, _BaseCloudOffset, _DetailCloudOffset;
            int _CloudMarchSteps;

            float3 _LightningColor;
            float _Lightning;

            float _HorizonFadeStart, _HorizonFadeEnd, _HorizonColorFadeStart, _HorizonColorFadeEnd;
            
            float _RaymarchOffset, _BlueNoiseAffectFactor;
            float2 _BlueNoiseTiling;
            
            //计算世界空间坐标
            float4 GetWorldSpacePosition(float depth, float2 uv)
            {
                 float4 viewPos = mul(_InverseProjectionMatrix, float4(2.0 * uv - 1.0, depth, 1.0));
                 viewPos.xyz /= viewPos.w;//详细推导见笔记中深度雾重建世界坐标部分
                 float4 worldPos = mul(_InverseViewMatrix, float4(viewPos.xyz, 1));
                 return worldPos;
            }

            float Remap(float v, float s, float e)
            {
                return (v - s) / (e - s);
            }

            //计算从ro出发的射线与球体的交点距离, 画图理解
            float IntersectCloudSphereInner(float3 ro, float3 rd, float sr)
            {
                float t = dot(-ro, rd);
                float y = length(ro + rd * t);

                float x = sqrt(sr * sr - y * y);
                return t + x;
            }


            //将步进点的 xz 作为 uv 坐标采样噪声图，并且通过函数去模拟云的形状，采样得出当前点云的密度
            float CloudMapBase(float3 p, float norY)
            {
                float3 offset = float3(cos(_CloudBearing), 0.0f, sin(_CloudBearing)) * (_BaseCloudOffset);
                float3 uv = (p + offset) * 0.00005f * _CloudBaseScale;
                float3 cloud = tex2Dlod(_BaseNoise, float4(uv.xz, 0, 1.0f)).rgb - float3(0, 1.0f, 0.0f);

                
                //用函数去模拟云的形状
                #if defined(USE_CLOUD_SHAPE_CURVE)
                    float n = 1 - tex2D(_CloudShapeTexture, float2(norY, 0.5)).r;
                #else
                    float n = norY * norY;
                    n += pow(1.0f - norY, 36);
                #endif
                return Remap(cloud.r - n, cloud.g - n, 1.0f);
            }

            float3 CloudMapDetail(float3 p, float norY, float speed)
            {
                float3 offset = float3(cos(_CloudBearing), 0.0f, sin(_CloudBearing)) * (_DetailCloudOffset);
                float3 uv = abs(p + offset) * 0.00005f * _CloudBaseScale * _CloudDetailScale;
                return tex3Dlod(_DetailNoise, float4(uv * 0.02f, 0.0f)).rgb;
            }
            
            float Linearstep(const float s, const float e, float v)
            {
                return clamp((v - s)*(1.0f / (e - s)), 0.0f, 1.0f);
            }

            float Linearstep0(const float e, float v)
            {
                return min(v*(1.0f / e), 1.0f);
            }

            //顶部、底部羽化渐变
            float CloudGradient(float norY) 
            {
                return Linearstep(0.0f, 0.05f, norY) - Linearstep(0.8f, 1.2f, norY);
            }

            //根据步进点获取当前点的云层密度
            float CloudMap(float3 pos, float3 rd, float norY)
            {
                float fade2 = sqrt((EARTH_RADIUS + _CloudBottom) * (EARTH_RADIUS + _CloudBottom) - EARTH_RADIUS * EARTH_RADIUS);
	            float d2 = length(pos.xz);
	            fade2 = smoothstep(0, fade2, d2 * 2);

                float m = CloudMapBase(pos, lerp(norY * 0.8, norY * 8, fade2 * 0.25));
                m *= CloudGradient(norY);
                // return m;

                //水平距离越近密度越大
                float dstrength = smoothstep(1.0f, 0.5f, fade2 * 0.6);
                //Detail
                if (dstrength > 0.)
                {
                    float3 detail = CloudMapDetail(pos, norY, 1) * dstrength * _CloudDetailStrength;
                    float detailSampleResult = (detail.r * 0.625f) + (detail.g * 0.2f) + (detail.b * 0.125f);
                    m -= detailSampleResult;
                }
                // return m;

                float fade = sqrt((EARTH_RADIUS + _CloudBottom) * (EARTH_RADIUS + _CloudBottom) - EARTH_RADIUS * EARTH_RADIUS);
                float d = length(pos.xz);
                fade = smoothstep(fade * 6, 0, d);//xz距离越大，fade 越小

                //m + (lerp(_CloudCoverage + _CloudCoverageBias - 1.0f, _CloudCoverage + _CloudCoverageBias , fade) - 1.)为考虑了远近、云层覆盖率的当前点的云的密度值
                //通过对该密度值进行smoothstep，_CloudBaseEdgeSoftness越大，插值后的值越小，并且云的边缘更加平滑
                m = smoothstep(
                    0.0f,
                    lerp(2.5f, _CloudBaseEdgeSoftness, fade),
                    m + (lerp(_CloudCoverage + _CloudCoverageBias - 1.0f, _CloudCoverage + _CloudCoverageBias , fade) - 1.));
                m *= Linearstep0(_CloudBottomSoftness, norY);//根据当前点在云层内的高度进行底部平滑

                // return clamp(m * _CloudDensity, 0.0f, 1.0f);
                return clamp(m * _CloudDensity * (1.0f + max((d - 7000.0f)*0.0005f, 0.0f)), 0.0f, 1.0f);//水平距离越远，密度越大，7000m范围内不变
            }


            //根据 Beer 定律计算出当前步进点的光照强度
            float VolumetricShadow(in float3 from , in float3 sunDir)
            {
                float sunDotUp = max(0.0f, dot(float3(0, 1, 0), _SunDir));
                
                float dd = 12;
                float3 rd = -sunDir;//往光源方向步进
                float d = dd * 2.0f;
	            float shadow = 1.0 * lerp(1.5, 1, sunDotUp);
                
                UNITY_LOOP
                for (int step = 0; step < CLOUD_SELF_SHADOW_STEPS; step++)
                {
                    float3 pos = from  + rd * d;
                    float norY = (length(pos) - (EARTH_RADIUS + _CloudBottom)) / _CloudHeight;
                    if (norY > 1.0f)
                        return shadow;

                    float muE =  CloudMap(pos, rd, norY);
                    //Beer衰减， muE * dd为当前步进区间密度,这里除以 8 做调整，让密度更低，透光率更高
                    shadow *= exp(-muE * dd / 8);

                    dd *= 1.0 * lerp(1.8, 1, sunDotUp);//步进方向如果与向上方向夹角太大，步进距离变大（因为此时要穿越云层的距离会变大）
                    d += dd;
                }

                return shadow;
            }            

            float4 RenderCloudsInternal(float3 ro, float3 rd)
            {
                ro.y = EARTH_RADIUS + ro.y;
                float start = IntersectCloudSphereInner(ro, rd, EARTH_RADIUS + _CloudBottom);
                float end = IntersectCloudSphereInner(ro, rd, EARTH_RADIUS + _CloudBottom + _CloudHeight);

                float sunDotRd = dot(rd, -_SunDir);
                float sunDotUp = max(0.0f, dot(float3(0, 1, 0), -_SunDir));

                float moonDotRd = dot(rd, -_MoonDir);
                float moonDotUp = max(0.0f, dot(float3(0, 1, 0), -_MoonDir));


                float rdDotUp = dot(rd, float3(0, 1, 0));
                int nSteps = lerp(20, _CloudMarchSteps, rdDotUp);
                float d = start;
                float dD = min(100.0f, (end - start) / float(nSteps));

                //Raymarch 起始点偏移
                float h = frac(_RaymarchOffset);
                d -= dD * h;

                float scattering = lerp(HenyeyGreensteinNoPi(sunDotRd, 0.8f),
                    HenyeyGreensteinNoPi(sunDotRd, -0.35f), 0.65f);

                float moonScattering = lerp(HenyeyGreensteinNoPi(moonDotRd, 0.3f),
                    HenyeyGreensteinNoPi(moonDotRd, 0.75f), 0.5f);

                float transmittance = 1.0f;
                float3 scatteredLight = 0.0f;

                float3 lightningColorBottom = 0.0f;
                float3 lightningColorTop = _CloudAmbientColorTop + _LightningColor * lerp(0.35f, 0.75f, sunDotUp);
                float lightningBottomFactor = saturate(_Lightning * 3.0f);
                float lightningTopFactor = saturate(_Lightning * 10.0f);
                
                UNITY_LOOP
                for (int step = 0; step < nSteps; step++)
                {
                    float3 p = ro + d * rd;

                    //当前点在云层内高度系数（0.0～1.0）
                    float norY = clamp((length(p) - (EARTH_RADIUS + _CloudBottom)) * (1.0f / _CloudHeight), 0.0f, 1.0f);

                    float alpha = CloudMap(p, rd, norY);//得到当前步进点的线密度
                    if (alpha > 0.005f)//当前步进点有密度（表示在云层里）才需要计算光照
                    {
                        //区间透光率（Beer 定律，用于描述光线不同厚度云层时的能量衰减）
                        float dTrans = exp(-alpha * dD);//alpha * dD为当前步进点区间密度
                        
                        float3 detail2 = CloudMapDetail(p * 0.35, norY, 1.0);
			            float3 detail3 = CloudMapDetail(p * 1, norY, 1.0);
                        //对云层颜色进行微调，减去一定的颜色，顶部减更多
                        float3 cloudBottomColor = _CloudAmbientColorBottom - detail2.r * lerp(0.25, 0.75, sunDotUp) * (lerp(0.2, 0.05, _CloudCoverage) * _Attenuation * 0.4f);
                        float3 cloudTopColor = _CloudAmbientColorTop - detail2.r * lerp(1, 4, sunDotUp) * (0.1 * _Attenuation * 0.9);
                        float3 ambientLight = lerp(
				        lerp(cloudBottomColor, lightningColorBottom, lightningBottomFactor),
				        lerp(cloudTopColor, lightningColorTop, lightningTopFactor),
				        norY) * _CloudColor;


                        float3 light = _SunColor * _Attenuation * 1.5f * smoothstep(0.04, 0.055, sunDotUp);
                        //对光照进行调整，云层底部更暗
                        light *= smoothstep(-0.03f, 0.075f, sunDotUp) -
                            lerp(clamp(lerp(detail2.r * 1.6, detail3.r * 1.6, norY ), 0.75, 0.9),
                                clamp(detail3.r * 1.3, 0, 0.8),
                                norY * 4);
                        //Smooth opposite clouds
			            light *= lerp(smoothstep(0.99f, 0.55f, sunDotRd), 1.0f, smoothstep(0.1, 0.99f, sunDotUp));

                        float3 moonLight = _MoonColor * _MoonAttenuation * 0.6f * smoothstep(0.11, 0.35, moonDotUp);
                        moonLight *= smoothstep(-0.03f, 0.075f, moonDotUp);


                        //一般模拟的光照应该按照如下计算
                        // float3 S = (
                        //         ambientLight + 
                        //         light * (scattering * VolumetricShadow(p, _SunDir))+
                        //         moonLight * (moonScattering * VolumetricShadow(p, _MoonDir))
                        //         )
                        //         * alpha * dD;
                        // scatteredLight += transmittance * S;

                        //这里做了微调，让最终的结果更加平滑（原理未知）
                        float3 S = (
                                ambientLight + 
                                light * (scattering * VolumetricShadow(p, _SunDir))+
                                moonLight * (moonScattering * VolumetricShadow(p, _MoonDir))
                                );
                        float3 Sint = (S - (S * dTrans));
                        scatteredLight += transmittance * Sint;
                        
                        transmittance *= dTrans;
                    }

                    //透光率低于一定数值，对最终光照累加影响已经很小，退出循环
                    if (transmittance <= 0.035f) break;

                    d += dD;
                }

                return float4(scatteredLight, transmittance);
            }

            void RenderClouds(out float4 cloudColor, in float3 ro, in float3 rd)
            {
                cloudColor = float4(0, 0, 0, 1);

                cloudColor = RenderCloudsInternal(ro, rd);
                if (cloudColor.w > 1.0f)
                {
                    cloudColor = float4(0, 0, 0, 1);
                } else
                {
                    cloudColor = float4(clamp(cloudColor.rgb, 0, 0.9), cloudColor.a);
                }
            }

            struct appdata
            {
                float2 uv : TEXCOORD0;
                float4 vertex : POSITION;
            };

            struct v2f
            {
                float4 vertex : SV_POSITION;
                float2 uv : TEXCOORD0;
		        float3 worldPos : TEXCOORD1;
		        float4 position_in_world_space : TEXCOORD2;
            };

            v2f vert(appdata v)
            {
                v2f o;

                UNITY_INITIALIZE_OUTPUT(v2f, o);
		        o.worldPos = mul(unity_ObjectToWorld, v.vertex);

		        o.position_in_world_space = mul(unity_ObjectToWorld, v.vertex);

                o.uv = v.uv;
                o.vertex = UnityObjectToClipPos(v.vertex);
                return o;
            }
            
            float4 Frag(v2f i) : SV_Target
            {
                float2 lon = (i.uv.xy + _Jitter / _TexSize) - 0.5;
                float a1 = length(lon) * 3.181592;
                float sin1 = sin(a1);
                float cos1 = cos(a1);
                float cos2 = lon.x / length(lon);
                float sin2 = lon.y / length(lon);
                float3 pos = float3(sin1 * cos2, cos1, sin1 * sin2);
                float3 rd = normalize(pos);
                
                float4 cloudColor = 0.0;
                RenderClouds(cloudColor, 0, rd);

                float rdDotUp = dot(float3(0, 1, 0), rd);

                float sstep = smoothstep(_HorizonFadeStart, _HorizonFadeEnd, rdDotUp);
                float sstep2 = smoothstep(_HorizonColorFadeStart, _HorizonColorFadeEnd, rdDotUp);
                float4 final = 0;
                

                final = float4(
				lerp(_CloudAmbientColorBottom.rgb * _CloudAlpha * (1.0 - Remap(_CloudCoverage + _CloudCoverageBias, 0.77, 0.25)),
					cloudColor.rgb*1.035 * sstep * sstep2,
					sstep * sstep2),
				lerp(
				    (1.0 - Remap(_CloudCoverage + _CloudCoverageBias, 0.9, 0.185)),
				    (1.0 - cloudColor.a) * sstep,
					sstep)
				);
                cloudColor = final;
                return cloudColor;
            }
            ENDCG
        }

        Pass
        {
            Cull Off ZWrite Off ZTest Always
            CGPROGRAM
            #pragma vertex vert
	        #pragma fragment frag

            #pragma multi_compile __ PREWARM
            
            float _TexSize, _CloudMovementSpeed;
            float2 _Jitter;
            sampler2D _LowResCloudTex, _PreviousCloudTex;
            

            struct appdata
		    {
			    float4 vertex : POSITION;
			    float2 uv : TEXCOORD0;
		    };

		    struct v2f
		    {
			    float4 vertex : SV_POSITION;
			    float2 uv : TEXCOORD0;
		    };

            v2f vert(appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                return o;
            }

            float Remap(float v, float s, float e)
            {
                return (v - s) / (e - s);
            }

            //计算出当前 UV 坐标与 Jitter 坐标的距离，距离越远，用 preTex 里的颜色，距离越近，用当前 tex 的颜色
            half CurrentCorrect(float2 uv, float2 jitter) {
                float2 texelRelativePos = floor(fmod(uv * _TexSize, 4.0)); //between (0, 4.0)

                texelRelativePos = abs(texelRelativePos - jitter);

                return saturate(texelRelativePos.x + texelRelativePos.y);
            }

		    half4 SamplePrev(float2 uv) {
			    return tex2D(_PreviousCloudTex, uv);
		    }

            float4 SampleCurrent(float2 uv) {
                return tex2D(_LowResCloudTex, uv);
            }
            
            half4 frag(v2f i) : SV_Target
            {
                float2 uvN = i.uv * 2.0 - 1.0;

                float4 currSample = SampleCurrent(i.uv);
                half4 prevSample = SamplePrev(i.uv);
                float luvN = length(uvN);

                half correct = CurrentCorrect(i.uv, _Jitter);
                #if defined(PREWARM)
                    return lerp(currSample, prevSample, correct); // No converging on prewarm
                #endif
                float ms01 = Remap(_CloudMovementSpeed, 0, 150);
                //luvN = 0即为穹顶中心位置，此时lerpFactor = lerp(0.4, 0.99, ms01)，速度越大，lerpFactor越大
                //luvN = 1即为海平线位置，此时lerpFactor = lerp(0.15, 0.25, ms01)
                //也即越靠近穹顶中心（距离镜头越近的地方），lerpFactor越大，也即越偏向于当前渲染结果，
                //越靠近海平线，lerpFactor越小，也即越偏向于之前渲染结果
                float lerpFactor = lerp(lerp(0.4, 0.99, ms01), lerp(0.15, 0.25, ms01), luvN);
				return lerp(prevSample, lerp(currSample, prevSample, correct), lerpFactor);
            }
            ENDCG
        }
    }
}
