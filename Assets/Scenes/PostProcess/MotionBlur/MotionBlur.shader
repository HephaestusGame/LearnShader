Shader "Learn/MotionBlur"
{
    Properties
    {
        _MainTex("MainTex", 2D) = "white" {}
        _BlurAmount("BlurAmount", Float) = 0.5
    }
    SubShader
    {
        CGINCLUDE
        #include "UnityCG.cginc"
        sampler2D _MainTex;
        float _BlurAmount;

        struct v2f
        {
            float4 pos : SV_POSITION;
            half2 uv : TEXCOORD0;
        };

        v2f vert(appdata_img i)
        {
            v2f o;
            o.pos = UnityObjectToClipPos(i.vertex);
            o.uv = i.texcoord;
            return o;
        }

        fixed4 fragRGB(v2f i): SV_Target
        {
            return fixed4(tex2D(_MainTex, i.uv).rgb, _BlurAmount);
        }

        fixed4 fragA(v2f i): SV_Target
        {
            return tex2D(_MainTex, i.uv);
        }
        ENDCG
        Cull Off ZTest Always ZWrite Off
        Pass
        {
            Blend SrcAlpha OneMinusSrcAlpha
            ColorMask RGB
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment fragRGB
            ENDCG
        }
        Pass
        {
            Blend One Zero
            ColorMask A
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment fragA
            ENDCG
        }
    }
    FallBack "Diffuse"
}
