Shader "Unlit/TestUnityMatrix"
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
            #pragma multi_compile_fo
            #pragma multi_compile _ _SHOW_SCREEN_POS
            #pragma multi_compile _ _SHOW_REAL_SCREEN_POS

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
                float4 vertex : SV_POSITION;
                float3 posWS : TEXCOORD1;
                float color: TEXCOORD2;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;

            float4x4 _VPMatrix;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                UNITY_TRANSFER_FOG(o,o.vertex);
                o.posWS = mul(unity_ObjectToWorld, v.vertex);

                float4 screenPos;
                #if defined(_SHOW_REAL_SCREEN_POS)
                    screenPos = ComputeScreenPos(o.vertex);
                    o.color = screenPos.y / screenPos.w;
                    return o;
                #endif
                

                float4 clipPos = mul(_VPMatrix, mul(unity_ObjectToWorld, v.vertex));
                #if defined(_SHOW_SCREEN_POS)
                    screenPos = ComputeScreenPos(clipPos);
                    screenPos /= screenPos.w;
                    o.color = screenPos.y;
                #else
                    clipPos /= clipPos.w;
                    clipPos.y = clipPos.y * 0.5 + 0.5;
                    o.color = clipPos.y;
                #endif
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                return i.color;
            }
            ENDCG
        }
    }
}
