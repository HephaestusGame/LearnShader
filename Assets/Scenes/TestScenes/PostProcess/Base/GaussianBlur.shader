Shader "Learn/GaussianBlur"
{
    Properties
    {
        _MainTex("Main Texture", 2D) = "white" {}
        _BlurSize("Blur Size", Range(0, 10)) = 1
    }
    SubShader
    {
        ZTest Always Cull Off ZWrite Off
        
        //定义通用fragment
        CGINCLUDE
        #include "UnityCG.cginc"

        sampler2D _MainTex;
        float4 _MainTex_TexelSize;
        float _BlurSize;

        struct v2f
        {
            float4 pos : SV_POSITION;
            half2 uv[5] : TEXCOORD0;
        };

        v2f vertHorizon(appdata_img i)
        {
            v2f o;
            o.pos = UnityObjectToClipPos(i.vertex);
            o.uv[0] = i.texcoord;
            o.uv[1] = i.texcoord + float2( _MainTex_TexelSize.x * _BlurSize * 1.0, 0);
            o.uv[2] = i.texcoord + float2( _MainTex_TexelSize.x * _BlurSize * -1.0, 0);
            o.uv[3] = i.texcoord + float2( _MainTex_TexelSize.x * _BlurSize * 2.0, 0);
            o.uv[4] = i.texcoord + float2( _MainTex_TexelSize.x * _BlurSize * -2.0, 0);

            return o;
        }

        v2f vertVertical(appdata_img i)
        {
            v2f o;
            o.pos = UnityObjectToClipPos(i.vertex);
            o.uv[0] = i.texcoord;
            o.uv[1] = i.texcoord + float2(0, _MainTex_TexelSize.y * _BlurSize * 1.0);
            o.uv[2] = i.texcoord + float2(0, _MainTex_TexelSize.y * _BlurSize * -1.0);
            o.uv[3] = i.texcoord + float2(0, _MainTex_TexelSize.y * _BlurSize * 2.0);
            o.uv[4] = i.texcoord + float2(0, _MainTex_TexelSize.y * _BlurSize * -2.0);

            return o;
        }
        
        fixed4 fragBlur(v2f i): SV_TARGET {
            float weights[3] = {0.4026, 0.2442, 0.0545};
            fixed3 col = tex2D(_MainTex, i.uv[0]).rgb * weights[0];
            for (int it = 1; it < 3; it++)
            {
                col += tex2D(_MainTex, i.uv[it * 2]).rgb * weights[it];
                col += tex2D(_MainTex, i.uv[it * 2 - 1]).rgb * weights[it];
            }

            return fixed4(col, 1);
        }
        ENDCG
        
        Pass 
        {
            NAME "GAUSSIAN_BLUR_HORIZONTAL"
            CGPROGRAM
            #pragma vertex vertHorizon
            #pragma fragment fragBlur
            ENDCG
        }
        
        Pass 
        {
            NAME "GAUSSIAN_BLUR_VERTICAL"
            CGPROGRAM
            #pragma vertex vertVertical
            #pragma fragment fragBlur
            ENDCG
        }
    }
    FallBack "Diffuse"
}
