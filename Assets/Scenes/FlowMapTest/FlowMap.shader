Shader "Learn/FlowMap"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _FlowMap ("FlowMap", 2D) = "white" {}
        _Speed ("Speed", Float) = 1
    }
    SubShader
    {

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
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
            sampler2D _FlowMap;
            float _Speed;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                float3 flowDir = tex2D(_FlowMap, i.uv) * 2.0 - 1.0;
                float phase0 = frac(_Time.x * _Speed);
                float phase1 = frac(_Time.x * _Speed + 0.5);
                
                
                fixed4 col1 = tex2D(_MainTex, i.uv - flowDir * phase0);
                fixed4 col2 = tex2D(_MainTex, i.uv - flowDir * phase1);
                float flowLerp = abs((0.5 - phase0) / 0.5);
                fixed4 col = lerp(col1, col2, flowLerp);
                return col;
            }
            ENDCG
        }
    }
}
