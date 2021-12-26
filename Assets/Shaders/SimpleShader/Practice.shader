Shader "Learn/Practice" 
{
	Properties {
		_Diffuse ("Diffuse", Color) = (1, 1, 1, 1)
	}

	SubShader
	{
		Pass {
			Tags { "LightMode" = "ForwardBase"}

			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#include "Lighting.cginc"

			fixed4 _Diffuse;

			struct a2v {
				fixed4 pos : POSITION;
				fixed3 normal : NORMAL;
			};

			struct v2f {
				fixed4 pos : SV_POSITION;
				fixed3 worldNormal : TEXCOORD0;
			};

			v2f vert(a2v v) {
				v2f o;
				o.pos = UnityObjectToClipPos(v.pos);
				o.worldNormal = normalize(mul(v.normal, unity_WorldToObject));
				return o;
			}

			fixed4 frag(v2f i) : SV_TARGET {
				fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz;
				fixed3 worldNormal = normalize(i.worldNormal);
				fixed3 worldLightDir = normalize(_WorldSpaceLightPos0.xyz);
				fixed3 diffuse = _LightColor0.rgb * _Diffuse.rgb * saturate(dot(worldLightDir, worldNormal));
				fixed3 color = ambient + diffuse;
				return fixed4(color, 1.0);
			}
			ENDCG
		}
	}

	Fallback "Diffuse"
}