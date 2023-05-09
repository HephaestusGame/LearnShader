// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'


//UnityCG.cginc��һЩ���õĽṹ��
//����				����					��������
//appdata_base		������ɫ������		����λ�á����㷨�ߡ���һ����������
//appdata_tan		������ɫ������		����λ�á��������ߡ����㷨�ߡ���һ����������
//appdata_full		������ɫ������		����λ�á��������ߡ����㷨�ߡ����飨���߸��ࣩ��������(���������������Shader Model�йأ� Shader Model 2��3��n=8�� 4��5��n=16)
//appdata_img		������ɫ������		����λ�á���һ����������
//v2f_img			������ɫ�����		�ü��ռ��е�λ�á���������

//UnityCG.cginc�г��ú���
//����												����
//float3 WorldSpaceViewDir(float4 v)				����ģ�Ϳռ�����õ�����ռ��дӸõ㵽������Ĺ۲췽��
//float3 ObjSpaceViewDir(float4 v)					����ģ�Ϳռ�����õ�ģ�Ϳռ��дӸõ㵽������Ĺ۲췽��
//float3 WorldSpaceLightDir(float4 v)				����������ǰ����Ⱦ������ģ�Ϳռ�����õ�����ռ��дӸõ㵽��Դ�Ĺ��շ���û�й�һ��
//float3 ObjSpaceLightDir(float4 v)					����������ǰ����Ⱦ������ģ�Ϳռ�����õ�ģ�Ϳռ��дӸõ㵽��Դ�Ĺ��շ���û�й�һ��
//float3 UnityObjectToWorldNormal(float3 normal)	�ѷ��ߴ�ģ�Ϳռ�ת��������ռ���
//float3 UnityObjectToWorldDir(float3 dir)			�ѷ���ʸ����ģ�Ϳռ�ת��������ռ���
//float3 UnityWorldToObjectDir(float3 dir)			�ѷ���ʸ��������ռ�ת����ģ�Ϳռ���	

Shader "SimpleShader" 
{

	//ShaderLab �������ͺ�Cg�������͹�ϵ
	//     shaderLab                  Cg����
	//	 Color��Vector			float4, half4, fixed4
	//	 Range, Float			float, half, fixed
	//        2D					sampler2D
	//       Cube					samplerCube
	//		  3D					sampler3D
	Properties
	{
		_Color ("Color Tint", Color) = (1.0, 1.0, 1.0, 1.0)
	}

	//����Կ�A��SubShader
	SubShader
	{
		Pass 
		{
			CGPROGRAM
			#pragma vertex vert//ָ��������ɫ������
			#pragma fragment frag//ָ��ƬԪ��ɫ������

			//���������ļ������Ի�ȡ��һЩUnity�Ѿ����úõı����ͺ�����
			//���Դ�unity3d/cn/get-unity/download/archive��ѡ������->������ɫ����������Щ�ļ�
			#include "UnityCG.cginc"

			//��CG�����У���Ҫ����һ�����������ƺ����Ͷ�ƥ��ı������󶨣�
			fixed4 _Color;

			//�Զ���ṹ�������嶥����ɫ��������
			//Unity֧�ֵ��������POSITION��COLOR��TANGENT��NORMAL��TEXCOORD0��TEXCOORD1��TEXCOORD2��TEXCOORD3...
			struct a2v {
				float4 vertex : POSITION;//ģ�Ϳռ������
				float3 normal : NORMAL;//�����ģ�Ϳռ䷨������
				float4 texcoord : TEXCOORD0;//ģ�͵ĵ�һ����������
			};//ע�����ﲻ��©�ֺ�

			//�Զ�������ṹ��
			struct v2f {
				float4 pos : SV_POSITION;
				fixed3 color : COLOR0;
			};//ע�����ﲻ��©�ֺ�


			//SV_POSITION: �ü��ռ������
			//float4 vert(a2v v) : SV_POSITION {
			//	return mul(UNITY_MATRIX_MVP, v.vertex);
			//}
			
			v2f vert(a2v v) {
				v2f o;
				o.pos = UnityObjectToClipPos(v.vertex); 
				//�Ѷ����normal��������Χ��[-1, 1]��ӳ�䵽[0.0, 1.0],������color��
				o.color = v.normal * 0.5 + fixed3(0.5, 0.5, 0.5);
				return o;
			}

			//SV_TARGET�����û��������ɫ�洢��һ����ȾĿ�꣨render target)��,Ĭ����֡����
			fixed4 frag(v2f i) : SV_TARGET {
				return fixed4(i.color * _Color.rgb, 1.0);
			}

			ENDCG
		}
	}
	
	//����SubShader��ʧ�ܺ����ڻص���Unity Shader
    Fallback "Specular"
}