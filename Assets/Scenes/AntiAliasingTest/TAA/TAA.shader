Shader "Learn/AntiAliasing/TAA"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _HistoryTex ("History Texture", 2D) = "white" {}
        _LerpFactor ("Lerp Factor", Float) = 0.1
    }
    SubShader
    {
        Cull Off ZWrite Off ZTest Always
        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"

            struct v2f
            {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
            };

            sampler2D _MainTex;
            sampler2D _HistoryTex;
            float _LerpFactor;

            v2f vert(appdata_base i)
            {
                v2f o;
                o.uv = i.texcoord;
                o.pos = UnityObjectToClipPos(i.vertex);
                return o;
            }

            float4 frag(v2f i) : SV_Target
            {
                float4 curColor = tex2D(_MainTex, i.uv);
                float4 historyColor = tex2D(_HistoryTex, i.uv);
                return lerp(historyColor, curColor, _LerpFactor);
            }
            ENDCG
        }
    }
}
