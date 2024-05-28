Shader "Unlit/LightningBolt"
{
    Properties
    {
        _GradientTexture ("GradientTexture", 2D) = "white" {}
        _AnimProgress ("Anim Progress", Range(0, 1)) = 0
    }
    SubShader
    {
        Tags { "RenderType"="Transparent" "Queue" = "Transparent" }
        LOD 100

        Blend One One
        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
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

            sampler2D _GradientTexture;
            
            float4 _GradientTexture_ST;
            float _AnimProgress, _TotalAnimDuration = 1;

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
                if (i.vertexColor.a > _AnimProgress * _TotalAnimDuration)
                    discard;

                fixed4 col = tex2D(_GradientTexture, float2(i.vertexColor.a, 0.5));
               
                col *= i.vertexColor.b;
                col.rgb = min(col.rgb, 60.0);
                col.rgb /= col.rgb + 1.0f;//Reinhard Tonemapping
                return col;
            }
            ENDCG
        }
    }

    CustomEditor "GradientShaderEditor"
    FallBack "Diffuse" 
}
