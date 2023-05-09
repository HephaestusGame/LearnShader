// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'


//UnityCG.cginc中一些常用的结构体
//名称				描述					包含变量
//appdata_base		顶点着色器输入		顶点位置、顶点法线、第一组纹理坐标
//appdata_tan		顶点着色器输入		顶点位置、顶点切线、顶点法线、第一组纹理坐标
//appdata_full		顶点着色器输入		顶点位置、顶点切线、顶点法线、四组（或者更多）纹理坐标(纹理坐标的数量和Shader Model有关， Shader Model 2和3中n=8， 4和5中n=16)
//appdata_img		顶点着色器输入		顶点位置、第一组纹理坐标
//v2f_img			顶点着色器输出		裁剪空间中的位置、纹理坐标

//UnityCG.cginc中常用函数
//名称												描述
//float3 WorldSpaceViewDir(float4 v)				输入模型空间坐标得到世界空间中从该点到摄像机的观察方向
//float3 ObjSpaceViewDir(float4 v)					输入模型空间坐标得到模型空间中从该点到摄像机的观察方向
//float3 WorldSpaceLightDir(float4 v)				仅可以用于前向渲染，输入模型空间坐标得到世界空间中从该点到光源的光照方向，没有归一化
//float3 ObjSpaceLightDir(float4 v)					仅可以用于前向渲染，输入模型空间坐标得到模型空间中从该点到光源的光照方向，没有归一化
//float3 UnityObjectToWorldNormal(float3 normal)	把法线从模型空间转换到世界空间中
//float3 UnityObjectToWorldDir(float3 dir)			把方向矢量从模型空间转换到世界空间中
//float3 UnityWorldToObjectDir(float3 dir)			把方向矢量从世界空间转换到模型空间中	

Shader "SimpleShader" 
{

	//ShaderLab 属性类型和Cg变量类型关系
	//     shaderLab                  Cg变量
	//	 Color，Vector			float4, half4, fixed4
	//	 Range, Float			float, half, fixed
	//        2D					sampler2D
	//       Cube					samplerCube
	//		  3D					sampler3D
	Properties
	{
		_Color ("Color Tint", Color) = (1.0, 1.0, 1.0, 1.0)
	}

	//针对显卡A的SubShader
	SubShader
	{
		Pass 
		{
			CGPROGRAM
			#pragma vertex vert//指定顶点着色器函数
			#pragma fragment frag//指定片元着色器函数

			//包含内置文件，可以获取到一些Unity已经内置好的变量和函数，
			//可以从unity3d/cn/get-unity/download/archive上选择下载->内置着色器来下载这些文件
			#include "UnityCG.cginc"

			//在CG代码中，需要定义一个与属性名称和类型都匹配的变量（绑定）
			fixed4 _Color;

			//自定义结构体来定义顶点着色器的输入
			//Unity支持的语义包含POSITION、COLOR、TANGENT、NORMAL、TEXCOORD0、TEXCOORD1、TEXCOORD2、TEXCOORD3...
			struct a2v {
				float4 vertex : POSITION;//模型空间的坐标
				float3 normal : NORMAL;//顶点的模型空间法线向量
				float4 texcoord : TEXCOORD0;//模型的第一套纹理坐标
			};//注意这里不能漏分号

			//自定义输出结构体
			struct v2f {
				float4 pos : SV_POSITION;
				fixed3 color : COLOR0;
			};//注意这里不能漏分号


			//SV_POSITION: 裁剪空间的坐标
			//float4 vert(a2v v) : SV_POSITION {
			//	return mul(UNITY_MATRIX_MVP, v.vertex);
			//}
			
			v2f vert(a2v v) {
				v2f o;
				o.pos = UnityObjectToClipPos(v.vertex); 
				//把顶点的normal（分量范围在[-1, 1]）映射到[0.0, 1.0],并存在color中
				o.color = v.normal * 0.5 + fixed3(0.5, 0.5, 0.5);
				return o;
			}

			//SV_TARGET：把用户的输出颜色存储到一个渲染目标（render target)中,默认是帧缓冲
			fixed4 frag(v2f i) : SV_TARGET {
				return fixed4(i.color * _Color.rgb, 1.0);
			}

			ENDCG
		}
	}
	
	//上述SubShader都失败后用于回调的Unity Shader
    Fallback "Specular"
}