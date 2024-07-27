Shader "Learn/BilateralBlur"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }

        Cull Off ZWrite Off ZTest Always        
        CGINCLUDE
		#pragma multi_compile_local _ USE_DEPTH_TEXTURE
        #define BLUR_DEPTH_FACTOR 0.5
        #define GAUSS_BLUR_DEVIATION 1.5        
        #define FULL_RES_BLUR_KERNEL_SIZE 7
        #define PI 3.1415927f

        #include "UnityCG.cginc"

        struct appdata
        {
            float4 vertex : POSITION;
            float2 uv : TEXCOORD0;
        };

        struct v2f
        {
            float2 uv : TEXCOORD0;
            float4 vertex : SV_POSITION;
        };

        UNITY_DECLARE_TEX2D(_CameraDepthTexture);
        UNITY_DECLARE_TEX2D(_MainTex);

        float4 _CameraDepthTexture_TexelSize;
        float GaussianWeight(float offset, float deviation)
		{
			float weight = 1.0f / sqrt(2.0f * PI * deviation * deviation);
			weight *= exp(-(offset * offset) / (2.0f * deviation * deviation));
			return weight;
		}
        
        v2f vert (appdata v)
        {
            v2f o;
            o.vertex = UnityObjectToClipPos(v.vertex);
            o.uv = v.uv;
            return o;
        }

        float4 BilateralBlur(v2f input, int2 direction, Texture2D depth, SamplerState depthSampler, const int kernelRadius, float2 pixelSize)
		{
			const float deviation = kernelRadius / GAUSS_BLUR_DEVIATION;

			float2 uv = input.uv;
			float4 centerColor = _MainTex.Sample(sampler_MainTex, uv);
			float3 color = centerColor.xyz;
			//return float4(color, 1);
			float centerDepth = (LinearEyeDepth(depth.Sample(depthSampler, uv)));

			float weightSum = 0;

			// gaussian weight is computed from constants only -> will be computed in compile time
            float weight = GaussianWeight(0, deviation);
			color *= weight;
			weightSum += weight;
						
			[unroll] for (int i = -kernelRadius; i < 0; i += 1)
			{
                float2 offset = (direction * i);
                float3 sampleColor = _MainTex.Sample(sampler_MainTex, input.uv, offset);
                float sampleDepth = (LinearEyeDepth(depth.Sample(depthSampler, input.uv, offset)));

				#if defined(USE_DEPTH_TEXTURE)
					float depthDiff = abs(centerDepth - sampleDepth);
	                float dFactor = depthDiff * BLUR_DEPTH_FACTOR;
					float w = exp(-(dFactor * dFactor));
				#else
					float w = 1;
				#endif
				
				

				// gaussian weight is computed from constants only -> will be computed in compile time
				weight = GaussianWeight(i, deviation) * w;

				color += weight * sampleColor;
				weightSum += weight;
			}

			[unroll] for (int i = 1; i <= kernelRadius; i += 1)
			{
				float2 offset = (direction * i);
                float3 sampleColor = _MainTex.Sample(sampler_MainTex, input.uv, offset);
                float sampleDepth = (LinearEyeDepth(depth.Sample(depthSampler, input.uv, offset)));

				#if defined(USE_DEPTH_TEXTURE)
					float depthDiff = abs(centerDepth - sampleDepth);
	                float dFactor = depthDiff * BLUR_DEPTH_FACTOR;
					float w = exp(-(dFactor * dFactor));
				#else
					float w = 1;
				#endif
				
				// gaussian weight is computed from constants only -> will be computed in compile time
				weight = GaussianWeight(i, deviation) * w;

				color += weight * sampleColor;
				weightSum += weight;
			}

			color /= weightSum;
			return float4(color, centerColor.w);
		}
        ENDCG

		//Pass 0, Full Size Horizontally Blur
        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment fragHorizontal


            fixed4 fragHorizontal(v2f input) : SV_Target
            {
            	return BilateralBlur(input, int2(1, 0), _CameraDepthTexture, sampler_CameraDepthTexture, FULL_RES_BLUR_KERNEL_SIZE, _CameraDepthTexture_TexelSize.xy);
            }
            ENDCG
        }

		//Pass 1, Full Size Vertically Blur
		Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment fragVertical


            fixed4 fragVertical(v2f input) : SV_Target
            {
            	return BilateralBlur(input, int2(0, 1), _CameraDepthTexture, sampler_CameraDepthTexture, FULL_RES_BLUR_KERNEL_SIZE, _CameraDepthTexture_TexelSize.xy);
            }
            ENDCG
        }
    }
}
