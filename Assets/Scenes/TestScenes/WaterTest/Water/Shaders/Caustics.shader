Shader "Unlit/Caustics"
{
    Properties
	{
		_GerstnerNormalTex("Gerstner Normal Texture", 2D) = "black" {}
		_GerstnerNormalScale("Gerstner Normal Scale", Range(0, 100)) = 1
		_Refract ("Refract", float) = 0.2
	}
	SubShader
	{
		Tags { "RenderType"="Opaque" }
		
		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			
			#include "UnityCG.cginc"

			struct appdata
			{
				float4 vertex : POSITION;
			};

			struct v2f
			{
				float4 vertex : SV_POSITION;
				float2 oldPos : TEXCOORD1;
				float2 newPos : TEXCOORD2;
			};

			sampler2D _InteractiveWaterNormalMap, _GerstnerNormalTex;
			half _Refract, _GerstnerNormalScale;
			
			v2f vert (appdata_full v)
			{
				v2f o;
				float3 gerstnerNormal = tex2Dlod(_GerstnerNormalTex, float4(v.texcoord.xy, 0, 0)).xyz;
				float3 normal = UnpackNormal(tex2Dlod(_InteractiveWaterNormalMap, float4(v.texcoord.xy, 0, 0)));
				normal.xy +=  gerstnerNormal.xz * _GerstnerNormalScale;
				o.oldPos = v.vertex.xz;
				v.vertex.xz += normal.xy*_Refract;
				o.newPos = v.vertex.xz;
				

				o.vertex = UnityObjectToClipPos(v.vertex);
				return o;
			}
			
			fixed4 frag (v2f i) : SV_Target
			{
				float oldArea = length(ddx(i.oldPos)) * length(ddy(i.oldPos));
				float newArea = length(ddx(i.newPos)) * length(ddy(i.newPos));

				float area = (oldArea / newArea) * 0.5 - 0.5;

				return float4(area, area, area, 1);
			}
			ENDCG
		}
	}
}
