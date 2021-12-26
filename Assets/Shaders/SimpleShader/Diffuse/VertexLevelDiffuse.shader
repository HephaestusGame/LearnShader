// Upgrade NOTE: replaced '_World2Object' with 'unity_WorldToObject'

//光的组成分成四部分：自发光(emissive)、环境光（embient）、镜面高光（specular）、漫反射（diffuse）
Shader "Learn/DiffuseLight" 
{
	Properties {
		_Diffuse ("Diffuse", Color) = (1, 1, 1, 1)
	}

	SubShader {
		Pass {
			Tags { "LightMode" = "ForwardBase" }

			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			#include "Lighting.cginc"

			fixed4 _Diffuse;

			struct a2v {
				float4 vertex : POSITION;
				float3 normal : NORMAL;
			};//注意这里不要漏分号

			struct v2f {
				float4 pos : SV_POSITION;
				fixed3 color : COLOR;
			};

			v2f vert(a2v v) {
				v2f o;
				o.pos = UnityObjectToClipPos(v.vertex);//老式写法：mul(UNITY_MATRIX_MVP, v.vertex)
				fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz;

				fixed3 worldNormal = normalize(mul(v.normal, (float3x3)unity_WorldToObject));//向量右乘矩阵等于向量左乘矩阵的逆，这里也就是从模型空间变换到世界空间
				fixed3 worldLight = normalize(_WorldSpaceLightPos0.xyz);
				fixed3 diffuse = _LightColor0.rgb * _Diffuse.rgb * saturate(dot(worldNormal, worldLight));//saturate(x) 表示把x截取到（0，1）范围内，如果x是个向量，则对每个分量做此操作
				o.color = ambient + diffuse;
				return o;
			}

			fixed4 frag(v2f i) : SV_TARGET {
				return fixed4(i.color, 1.0);
			}
			ENDCG
		}
	}
	FallBack "Diffuse"
}