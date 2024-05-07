Shader "Unlit/InteractiveWaterForce"
{
    Properties
    {
    }
    
    //这是一个多 pass 渲染 shader，同一个物体会按照 pass 的顺序渲染两次
    SubShader
    {
        Tags { "RenderType"="Opaque" }

        
        //部分浸入水中的物体，剔除正面，只渲染背面的深度，浸入越多，深度越大
        Pass
        {
            cull front
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "InteractiveWaterUtils.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
            };

            struct v2f
            {
                float depth : TEXCOORD0;
                float4 vertex : SV_POSITION;
            };

            float _InternalForce;
            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.depth = COMPUTE_DEPTH_01;
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                return EncodeHeight(i.depth * _InternalForce);
            }
            ENDCG
        }

        //全部浸入的物体，深度为固定值，用于模拟全部浸入后产生水波强度不变
        Pass
        {
            CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			#include "UnityCG.cginc"

			float4 vert(float4 vertex:POSITION) : SV_POSITION
			{
				return UnityObjectToClipPos(vertex);
			}

			fixed4 frag(float4 i:SV_POSITION) : SV_Target
			{
				return fixed4(0, 0, 0, 1.0);
			}
			ENDCG
        }
    }
}
