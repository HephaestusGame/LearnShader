Shader "Custom/DistortionFlow"
{
    Properties
    {
        _Color ("Color", Color) = (1,1,1,1)
        _MainTex ("Albedo (RGB)", 2D) = "white" {}
        [NoScaleOffset]_FlowMap("Flow Map (RG, A noise)", 2D) = "black" {}
        [NoScaleOffset]_DeriveHeightmap("Deriv (AG) Height(B)", 2D) = "Black" {}
        _UJump ("U jump per phase", Range(-0.25, 0.25)) = 0.25
		_VJump ("V jump per phase", Range(-0.25, 0.25)) = 0.25
        _Tiling("Tiling", Float) = 1.0
        _Speed("Speed", Float) = 1.0
        _FlowStrength("Flow Stength", Float) = 1.0
        _FlowOffset("Flow Offset", Float) = 0.0
        _HeightScale ("Height Scale", Float) = 1
        _HeightScaleModulated ("Height Scale, Modulated", Float) = 0.75
    	_WaterFogColor ("Water Fog Color", Color) = (0, 0, 0, 0)
		_WaterFogDensity ("Water Fog Density", Range(0, 2)) = 0.1
    	_RefractionStrength ("Refraction Strength", Range(0, 1)) = 0.25
        _Glossiness ("Smoothness", Range(0,1)) = 0.5
        _Metallic ("Metallic", Range(0,1)) = 0.0
    }
    SubShader
    {
        Tags { "RenderType"="Transparent" "Queue"="Transparent" }
        LOD 200

        GrabPass {"_WaterBackground"}
        CGPROGRAM
        // Physically based Standard lighting model, and enable shadows on all light types
        #pragma surface surf Standard alpha finalcolor:ResetAlpha
        #include "LookingThroughWater.cginc"

        
        
        // Use shader model 3.0 target, to get nicer looking lighting
        #pragma target 3.0

        sampler2D _MainTex, _FlowMap, _DeriveHeightmap;

        float _UJump, _VJump, _Speed, _Tiling, _FlowStrength;
        float _HeightScale, _HeightScaleModulated;
        float _FlowOffset;


        struct Input
        {
            float2 uv_MainTex;
        	float4 screenPos;
        };

        half _Glossiness;
        half _Metallic;
        fixed4 _Color;

        //ColorBelowWater中已经对水底的背景颜色进行了混合，因此在输出最终颜色时将其 alpha 设置为 1，避免再次与 ColorBuffer 中的背景颜色进行混合
        void ResetAlpha (Input IN, SurfaceOutputStandard o, inout fixed4 color) {
			color.a = 1;
		}

        // sample flow map  
        float3 FlowUVW(float2 uv, float2 flowVec, float2 jump,
            float flowOffset, float tiling, float time, bool flowB)
        {
            float phaseOffset = flowB ? 0.5 : 0;
			float progress = frac(time + phaseOffset);
			float3 uvw;
			uvw.xy = uv - flowVec * (progress + flowOffset);
			uvw.xy *= tiling;
			uvw.xy += phaseOffset;
			uvw.xy += (time - progress) * jump;
			uvw.z = 1 - abs(1 - 2 * progress);
			return uvw;
        }

        float3 UnpackDerivativeHeight (float4 textureData) {
			float3 dh = textureData.agb;
			dh.xy = dh.xy * 2 - 1;
			return dh;
		}


        void surf (Input IN, inout SurfaceOutputStandard o)
        {
            float3 flow = tex2D(_FlowMap, IN.uv_MainTex);
            flow.xy = flow.rg * 2.0 - 1.0;
            flow *= _FlowStrength;
            
            float noise = tex2D(_FlowMap, IN.uv_MainTex).a;
			float time = _Time.y * _Speed + noise;
            float2 jump = float2(_UJump, _VJump);
            
            float3 uvwA = FlowUVW(
				IN.uv_MainTex, flow.xy, jump,
				_FlowOffset, _Tiling, time, false
			);
			float3 uvwB = FlowUVW(
				IN.uv_MainTex, flow.xy, jump,
				_FlowOffset, _Tiling, time, true
			);

            float finalHeightScale = flow.z * _HeightScaleModulated + _HeightScale;
            float3 dhA = UnpackDerivativeHeight(tex2D(_DeriveHeightmap, uvwA.xy)) * uvwA.z * finalHeightScale;
            float3 dhB = UnpackDerivativeHeight(tex2D(_DeriveHeightmap, uvwB.xy)) * uvwB.z * finalHeightScale;
            o.Normal = normalize(float3(-(dhA.xy + dhB.xy), 1));

        	fixed4 texA = tex2D(_MainTex, uvwA.xy) * uvwA.z;
			fixed4 texB = tex2D(_MainTex, uvwB.xy) * uvwB.z;

        	fixed4 c = (texA + texB) * _Color;
            o.Albedo = c.rgb;
        	o.Alpha = c.a;
        	o.Metallic = _Metallic;
            o.Smoothness = _Glossiness;

        	o.Emission = ColorBelowWater(IN.screenPos, o.Normal) * (1 - c.a);
        }
        ENDCG
    }
}
