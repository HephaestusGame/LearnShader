Shader "PostProcessing/VolumetricCloud2"
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
            #define EARTH_RADIUS  6371000

            static const int CLOUD_SELF_SHADOW_STEPS = 5;

            //Unity 内置变量
            float3 _WorldSpaceLightPos0;
            float4 _LightColor0;

            sampler2D _BaseNoise;
            sampler3D _DetailNoise;
            TEXTURE2D_SAMPLER2D(_MainTex, sampler_MainTex);
            TEXTURE2D_SAMPLER2D(_CameraDepthTexture, sampler_CameraDepthTexture);

            float4x4 _InverseProjectionMatrix, _InverseViewMatrix;

            float4 _CloudAmbientColorBottom, _CloudAmbientColorTop, _CloudColor;

            float _CloudBottom, _CloudHeight, _CloudBaseScale, _CloudDetailScale, _CloudDetailStrength;
            float _CloudBaseEdgeSoftness, _CloudBottomSoftness, _CloudCoverage, _CloudCoverageBias;
            float _CloudDensity, _Attenuation;
            int _CloudMarchSteps;

            float4 _LightningColor;
            float _Lightning;

            
            float _RaymarchOffset;
            
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

            float CloudMapBase(float3 p, float norY)
            {
                float3 uv = p * 0.00005f * _CloudBaseScale;
                float3 cloud = tex2Dlod(_BaseNoise, float4(uv.xz, 0, 0.0f)).rgb - float3(0, 1.0f, 0.0f);

                float n = norY * norY;
                n += pow(1.0f - norY, 36);
                return Remap(cloud.r - n, cloud.g - n, 1.0f);
            }

            float CloudMapDetail(float3 p, float norY, float speed)
            {
                float3 uv = abs(p) * 0.00005f * _CloudBaseScale * _CloudDetailScale;
                return tex3Dlod(_DetailNoise, float4(uv * 0.02f, 0.0f));
            }
            
            float Linearstep(const float s, const float e, float v)
            {
                return clamp((v - s)*(1.0f / (e - s)), 0.0f, 1.0f);
            }

            float Linearstep0(const float e, float v)
            {
                return min(v*(1.0f / e), 1.0f);
            }

            float CloudGradient(float norY) 
            {
                return Linearstep(0.0f, 0.05f, norY) - Linearstep(0.8f, 1.2f, norY);
            }

            float CloudMap(float3 pos, float3 rd, float norY)
            {
                float fade2 = sqrt((EARTH_RADIUS) * (EARTH_RADIUS)-EARTH_RADIUS * EARTH_RADIUS +
		                        (EARTH_RADIUS + _CloudBottom) * (EARTH_RADIUS + _CloudBottom) - EARTH_RADIUS * EARTH_RADIUS);
	            float d2 = length(pos.xz);
	            fade2 = smoothstep(0, fade2, d2 * 2);

                float m = CloudMapBase(pos, lerp(norY * 0.8, norY * 8, fade2 * 0.25));
                m *= CloudGradient(norY);

                //水平距离越近密度越大
                float dstrength = smoothstep(1.0f, 0.5f, fade2 * 0.6);


                //Detail
                if (dstrength > 0.)
                {
                    float3 detail = CloudMapDetail(pos, norY, 1) * dstrength * _CloudDetailStrength;
                    float detailSampleResult = (detail.r * 0.625f) + (detail.g * 0.2f) + (detail.b * 0.125f);
                    m -= detailSampleResult;
                }

                float fade = sqrt((EARTH_RADIUS) * (EARTH_RADIUS) - EARTH_RADIUS * EARTH_RADIUS +
                            (EARTH_RADIUS + _CloudBottom) * (EARTH_RADIUS + _CloudBottom) - EARTH_RADIUS * EARTH_RADIUS);
                float d = length(pos.xz);
                fade = smoothstep(fade * 6, 0, d);

                m = smoothstep(0.0f, lerp(2.5f, _CloudBaseEdgeSoftness, fade), m + (lerp(_CloudCoverage + _CloudCoverageBias - 1.0f, _CloudCoverage + _CloudCoverageBias , fade) - 1.));
                m *= Linearstep0(_CloudBottomSoftness, norY);

                return clamp(m * _CloudDensity * (1.0f + max((d - 7000.0f)*0.0005f, 0.0f)), 0.0f, 1.0f);
            }

            float VolumetricShadow(in float3 from , in float lightDotup, in float3 lightDir)
            {
                float dd = 12;
                float d = dd * 2.0f;
	            float shadow = 1.0 * lerp(1.5, 1, lightDotup);
                
                UNITY_LOOP
                for (int step = 0; step < CLOUD_SELF_SHADOW_STEPS; step++)
                {
                    float3 pos = from  + lightDir * d;
                    float norY = (length(pos) - (EARTH_RADIUS + _CloudBottom)) / _CloudHeight;
                    if (norY > 1.0f)
                        return shadow;

                    float muE =  CloudMap(pos, lightDir, norY);
                    shadow *= exp(-muE * dd / 8);//Beer衰减

                    dd *= 1.0 * lerp(1.8, 1, lightDotup);
                    d += dd;
                }

                return shadow;
            }            

            float4 RenderCloudsInternal(float3 ro, float3 rd)
            {
                ro.y = EARTH_RADIUS + ro.y;
                float start = IntersectCloudSphereInner(ro, rd, EARTH_RADIUS + _CloudBottom);
                float end = IntersectCloudSphereInner(ro, rd, EARTH_RADIUS + _CloudBottom + _CloudHeight);


                float3 lightDir = normalize(_WorldSpaceLightPos0.xyz);
                float viewDotLight = dot(rd, -lightDir);
                float lightDotUp = max(0.0f, dot(float3(0, 1, 0), lightDir));


                int nSteps = lerp(10, _CloudMarchSteps, dot(rd, float3(0, 1, 0)));
                float d = start;
                float dD = min(100.0f, (end - start) / float(nSteps));

                //Raymarch 起始点偏移
                float h = frac(_RaymarchOffset);
                d -= dD * h;

                float scattering = lerp(HenyeyGreensteinNoPi(viewDotLight, 0.8f),
                    HenyeyGreensteinNoPi(viewDotLight, -0.35f), 0.65f);

                float transmittance = 1.0f;
                float3 scatteredLight = 0.0f;
                float dist = EARTH_RADIUS;

                UNITY_LOOP
                for (int step = 0; step < nSteps; step++)
                {
                    float3 p = ro + d * rd;

                    //当前点在云层内高度系数（0.0～1.0）
                    float norY = clamp((length(p) - (EARTH_RADIUS + _CloudBottom)) * (1.0f / _CloudHeight), 0.0f, 1.0f);

                    float alpha = CloudMap(p, rd, norY);
                    if (alpha > 0.005f)
                    {
                        float3 detail2 = CloudMapDetail(p * 0.35, norY, 1.0);
			            float3 detail3 = CloudMapDetail(p * 1, norY, 1.0);
                        dist = min(dist, d);

                        float3 ambientLight = lerp(
				        lerp(_CloudAmbientColorBottom - (detail2.r * lerp(0.25, 0.75, lightDotUp)) * (lerp(0.2, 0.05, (_CloudCoverage)) * _Attenuation * 0.4f), 0.0f, saturate(_Lightning * 3.0f)),
				        lerp(_CloudAmbientColorTop - detail2.r * lerp(1, 4, lightDotUp) * (0.1 * _Attenuation * 0.9), _CloudAmbientColorTop + (_LightningColor * lerp(0.35f, 0.75f, lightDotUp)), saturate(_Lightning * 10.0f)),
				        norY) * _CloudColor;


                        //由于这里模拟的是从云层底下往上看，因此只有光照方向为由下往上照时云层才会更亮
                        float3 light = _LightColor0 * _Attenuation * 1.5f * smoothstep(0.04, 0.055, lightDotUp);
                        light *= smoothstep(-0.03f, 0.075f, lightDotUp) - lerp(clamp(lerp(detail2.r * 1.6, detail3.r * 1.6, norY ), 0.75, 0.9), clamp(detail3.r * 1.3, 0, 0.8), norY * 4);
                        //Smooth opposite clouds
			            light *= lerp(smoothstep(0.99f, 0.55f, lightDotUp), 1.0f, smoothstep(0.1, 0.99f, lightDotUp));


                         float3 S = (
                                ambientLight + 
                                light * (scattering * VolumetricShadow(p, viewDotLight, lightDir))
                                )
                                * alpha;

                        float dTrans = exp(-alpha * dD);
                        float3 Sint = (S - (S * dTrans)) * (1.0f / alpha);

                        scatteredLight += transmittance * Sint;
                        transmittance *= dTrans;
                    }

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

            
            float4 Frag(VaryingsDefault i) : SV_Target
            {
                float depth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_CameraDepthTexture, i.texcoord);
                float4 worldPos = GetWorldSpacePosition(depth, i.texcoord);
                float3 rayPos = _WorldSpaceCameraPos;
                float3 worldViewDir = worldPos.xyz - rayPos.xyz;

                float4 cloudColor;
                RenderClouds(cloudColor, 0, normalize(worldViewDir));
                float4 color = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.texcoord);
                color.rgb *= cloudColor.a;
                color.rgb += cloudColor.rgb;
                return float4(cloudColor.rgb + color.rgb * cloudColor.a,  cloudColor.a + color.a * cloudColor.a);
            }
            ENDHLSL
        }
    }
}
