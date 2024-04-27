Shader "Custom/DirectionalFlow"
{
    Properties
    {
    	_Color ("Color", Color) = (1,1,1,1)
        [NoScaleOffset] _MainTex ("Deriv (AG) Height (B)", 2D) = "black" {}
		[NoScaleOffset] _FlowMap ("Flow (RG)", 2D) = "black" {}
    	[Toggle(_DUAL_GRID)] _DualGrid ("Dual Grid", Int) = 0
		_Tiling ("Tiling", Float) = 1
    	_TilingModulated ("Tiling, Modulated", Float) = 1
    	_GridResolution ("Grid Resolution", Float) = 10
		_Speed ("Speed", Float) = 1
		_FlowStrength ("Flow Strength", Float) = 1
		_HeightScale ("Height Scale, Constant", Float) = 0.25
		_HeightScaleModulated ("Height Scale, Modulated", Float) = 0.75
		_Glossiness ("Smoothness", Range(0,1)) = 0.5
		_Metallic ("Metallic", Range(0,1)) = 0.0
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 200

        CGPROGRAM
        // Physically based Standard lighting model, and enable shadows on all light types
        #pragma surface surf Standard fullforwardshadows

        // Use shader model 3.0 target, to get nicer looking lighting
        #pragma target 3.0

        #pragma shader_feature _DUAL_GRID

		sampler2D _MainTex, _FlowMap;
		float _Tiling, _TilingModulated, _GridResolution, _Speed, _FlowStrength;
		float _HeightScale, _HeightScaleModulated;

        struct Input
        {
            float2 uv_MainTex;
        };

        half _Glossiness;
        half _Metallic;
        fixed4 _Color;


        // sample flow map  
        float3 FlowUVW(float2 uv, float2 flowVec,float flowOffset, float tiling, float time, bool flowB)
        {
            float phaseOffset = flowB ? 0.5 : 0;
			float progress = frac(time + phaseOffset);
			float3 uvw;
			uvw.xy = uv - flowVec * (progress + flowOffset);
			uvw.xy *= tiling;
			uvw.xy += phaseOffset;
			uvw.z = 1 - abs(1 - 2 * progress);
			return uvw;
        }

        float2 DirectionalFlowUV(
        	float2 uv, float3 flowVectorAndSpeed, float tiling, float time,
        	out float2x2 rotation)
        {
        	float2 dir = normalize(flowVectorAndSpeed.xy);
        	rotation = float2x2(dir.y, dir.x, -dir.x, dir.y);//视觉上顺时针旋转，即纹理进行了顺时针旋转，因此法向量顺时针旋转
			uv = mul(float2x2(dir.y, -dir.x, dir.x, dir.y), uv);//视觉上要顺时针旋转，则UV坐标要逆时针旋转
			uv.y -= time * flowVectorAndSpeed.z;
			return uv * tiling;
		}

        float3 UnpackDerivativeHeight (float4 textureData)
        {
			float3 dh = textureData.agb;
			dh.xy = dh.xy * 2 - 1;
			return dh;
		}

        float3 FlowCell (float2 uv, float2 offset, float time, float gridB)
        {
        	float2 shift = 1 - offset;
		    shift *= 0.5;
        	offset *= 0.5;
        	if (gridB) {
		        offset += 0.25;
		        shift -= 0.25;
		    }
		    float2x2 derivRotation;
			float2 uvTiled = (floor(uv * _GridResolution + offset) + shift) / _GridResolution;
			float3 flow = tex2D(_FlowMap, uvTiled).rgb;
			flow.xy = flow.xy * 2 - 1;
			flow.z *= _FlowStrength;

        	float tiling = flow.z * _TilingModulated + _Tiling;//flow.z流动速度，速度越大，_Tiling越大，Ripple 越小
			float2 uvFlow = DirectionalFlowUV(
				uv + offset, flow, tiling, time,
				derivRotation
			);
			float3 dh = UnpackDerivativeHeight(tex2D(_MainTex, uvFlow));
			dh.xy = mul(derivRotation, dh.xy);
        	dh *= flow.z * _HeightScaleModulated + _HeightScale;
			return dh;
		}

        float3 FlowGrid (float2 uv, float time, bool gridB) {
		    float3 dhA = FlowCell(uv, float2(0, 0), time, gridB);
			float3 dhB = FlowCell(uv, float2(1, 0), time, gridB);
			float3 dhC = FlowCell(uv, float2(0, 1), time, gridB);
			float3 dhD = FlowCell(uv, float2(1, 1), time, gridB);

			float2 t = uv * _GridResolution;
			if (gridB)
				{
			    t += 0.25;
			}
			t = abs(2 * frac(t) - 1);
			float wA = (1 - t.x) * (1 - t.y);
			float wB = t.x * (1 - t.y);
			float wC = (1 - t.x) * t.y;
			float wD = t.x * t.y;

			return dhA * wA + dhB * wB + dhC * wC + dhD * wD;
		}

        void surf (Input IN, inout SurfaceOutputStandard o)
        {
            float time = _Time.y * _Speed;
        	float2 uv = IN.uv_MainTex;
			float3 dh = FlowGrid(uv, time, false);
			#if defined(_DUAL_GRID)
				dh = (dh + FlowGrid(uv, time, true)) * 0.5;
			#endif
			fixed4 c = dh.z * dh.z * _Color;
			o.Albedo = c.rgb;
			o.Normal = normalize(float3(-dh.xy, 1));
			o.Metallic = _Metallic;
			o.Smoothness = _Glossiness;
			o.Alpha = c.a;
        }
        ENDCG
    }
    FallBack "Diffuse"
}
