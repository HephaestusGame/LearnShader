Shader "Cloud/CloudSphere"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
    }
    SubShader
    {
        Tags{ "Queue" = "Transparent-400" "RenderType" = "Transparent" "IgnoreProjector" = "True" }
		LOD 100
        Blend One OneMinusSrcAlpha
        ZWrite Off
        Cull Off

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
                float4 vertex : SV_POSITION;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;

            v2f vert (appdata v)
            {
                v2f o;
                float farPlane = _ProjectionParams.z;


                //将V矩阵的位移部分变成0，同时将V矩阵的w部分变成1.1，这样经过透视除法后，设置在远平面上的球面点就会在远平面回来一点的位置上
                float4x4 viewMatrixWithNoTranslation =
                    float4x4(
                        float4(UNITY_MATRIX_V[0].xyz, 0.0f),
                        float4(UNITY_MATRIX_V[1].xyz, 0.0f),
                        float4(UNITY_MATRIX_V[2].xyz, 0.0f),
                        float4(0.0f, 0.0f, 0.0f, 1.1f)
                        );

                //将球面点的位置变换到远平面上
                float4 vertexPos = v.vertex * float4(farPlane, farPlane, farPlane, 1);
                o.vertex = mul(mul(UNITY_MATRIX_P, viewMatrixWithNoTranslation), vertexPos);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                // sample the texture
                fixed4 col = tex2D(_MainTex, i.uv);
                return col;
            }
            ENDCG
        }
    }
}
