Shader "Test/ViewNormalShader"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // make fog work
            #pragma multi_compile_fog

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                UNITY_FOG_COORDS(1)
                float3 viewVec : TEXCOORD2;
                float4 vertex : SV_POSITION;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
            //获取深度法线图
	        sampler2D _CameraDepthNormalsTexture;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                //屏幕纹理坐标
		        float4 screenPos = ComputeScreenPos(o.vertex);
		        // NDC position
		        float4 ndcPos = (screenPos / screenPos.w) * 2 - 1;
		        // 计算至远屏幕方向
		        float3 clipVec = float3(ndcPos.x, ndcPos.y, 1.0) * _ProjectionParams.z;
		        o.viewVec = mul(unity_CameraInvProjection, clipVec.xyzz).xyz;
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                float3 viewNormal;
		        float linear01Depth;
		        float4 depthnormal = tex2D(_CameraDepthNormalsTexture,i.uv);
		        DecodeDepthNormal(depthnormal,linear01Depth,viewNormal);


                
                // return linear01Depth > 0 ? fixed4(linear01Depth, 0, 0, 1) : fixed4(0, -linear01Depth, 0, 1);
                // return i.viewVec.z > 0 ? fixed4(i.viewVec.z, 0, 0, 1) : fixed4(0, -i.viewVec.z, 0, 1);
                return viewNormal.z > 0 ? fixed4(viewNormal.z, 0, 0, 1) : fixed4(0, -viewNormal.z, 0, 1);
            }
            ENDCG
        }
    }
}
