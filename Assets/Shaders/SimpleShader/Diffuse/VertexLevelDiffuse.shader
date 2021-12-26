// Upgrade NOTE: replaced '_World2Object' with 'unity_WorldToObject'

//�����ɷֳ��Ĳ��֣��Է���(emissive)�������⣨embient��������߹⣨specular���������䣨diffuse��
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
			};//ע�����ﲻҪ©�ֺ�

			struct v2f {
				float4 pos : SV_POSITION;
				fixed3 color : COLOR;
			};

			v2f vert(a2v v) {
				v2f o;
				o.pos = UnityObjectToClipPos(v.vertex);//��ʽд����mul(UNITY_MATRIX_MVP, v.vertex)
				fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz;

				fixed3 worldNormal = normalize(mul(v.normal, (float3x3)unity_WorldToObject));//�����ҳ˾������������˾�����棬����Ҳ���Ǵ�ģ�Ϳռ�任������ռ�
				fixed3 worldLight = normalize(_WorldSpaceLightPos0.xyz);
				fixed3 diffuse = _LightColor0.rgb * _Diffuse.rgb * saturate(dot(worldNormal, worldLight));//saturate(x) ��ʾ��x��ȡ����0��1����Χ�ڣ����x�Ǹ����������ÿ���������˲���
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