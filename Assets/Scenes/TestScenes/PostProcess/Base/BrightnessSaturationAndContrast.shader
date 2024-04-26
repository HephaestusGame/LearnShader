Shader "Learn/BrightnessSaturationAndContrast"
{
    Properties
    {
        _MainTex("Main Texture", 2D) = "white" {}
        _Brightness("Brightness", Float) = 1
        _Saturation("Saturation", Float) = 1
        _Contrast("Contrast", Float) = 1
    }
    SubShader
    {
        Pass
        {
            ZTest Always Cull Off ZWrite off
            CGPROGRAM
            #include "UnityCG.cginc"
            #pragma vertex vert
            #pragma fragment frag
            sampler2D _MainTex;
            float _Brightness;
            float _Saturation;
            float _Contrast;
            
            struct v2f
            {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
            };

            v2f vert(appdata_img i)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(i.vertex);
                o.uv = i.texcoord;
                return o;
            }

            fixed4 frag(v2f i): SV_Target
            {
                fixed4 texColor = tex2D(_MainTex, i.uv);

                //亮度
                fixed3 finalColor = texColor.rgb * _Brightness;

                //饱和度
                fixed lumiance = 0.2125 * texColor.r + 0.7154 * texColor.g  +  0.0721 * texColor.b;
                fixed3 lumianceColor = fixed3(lumiance, lumiance, lumiance);
                finalColor = lerp(lumianceColor, finalColor, _Saturation);

                //对比度
                fixed3 avgColor = fixed3(0.5, 0.5, 0.5);
                finalColor = lerp(avgColor, finalColor, _Contrast);

                return fixed4(finalColor, texColor.a);
            }
            ENDCG
        }
    }
    FallBack "Diffuse"
}
