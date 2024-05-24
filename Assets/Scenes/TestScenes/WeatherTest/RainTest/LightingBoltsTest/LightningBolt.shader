Shader "Unlit/LightningBolt"
{
    Properties
    {
        _GradientTexture ("GradientTexture", 2D) = "white" {}
        _BrighterGradientTexture("Brighter Gradient Texture", 2D) = "white" {}
        _ShowPercent ("Show Percent", Range(0, 1)) = 0
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
                float4 color : COLOR;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float4 vertexColor : TEXCOORD1;
            };

            sampler2D _GradientTexture, _BrighterGradientTexture;
            
            float4 _GradientTexture_ST;
            float _ShowPercent;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                o.vertexColor = v.color;
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                if (i.vertexColor.a > _ShowPercent)
                    discard;
                // sample the texture
                fixed4 col;
                if (i.uv.y > 0.8f)
                {
                    col = tex2D(_BrighterGradientTexture, float2(i.uv.x, 0.5));
                } else
                {
                    col = tex2D(_GradientTexture, float2(i.uv.x, 0.5));
                }
               
                col *= i.uv.y;
                return col;
            }
            ENDCG
        }
    }

    CustomEditor "GradientShaderEditor"
    FallBack "Diffuse" 
}
