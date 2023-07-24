Shader "Custom/Bloom"
{
    Properties
    {
        _MainTex ("Main Texture", 2D) = "white" {}
        _Bloom ("Bloom", 2D) = "black" {}
        _LuminanceThreshold ("Luminance Threshold", Float) = 0.5
        _BlurSize("Blur Size", Float) = 1.0
    }
    SubShader
    {
        CGINCLUDE
        #include "UnityCG.cginc"
        sampler2D _MainTex;
        half4 _MainTex_TexelSize;
        sampler2D _Bloom;
        float _LuminanceThreshold;
        float _BlurSize;

        struct v2fExtractBright
        {
            float4 pos : SV_POSITION;
            half2 uv : TEXCOORD0;
        };

        v2fExtractBright vertExtractBright(appdata_img v)
        {
            v2fExtractBright o;
            o.pos = UnityObjectToClipPos(v.vertex);
            o.uv = v.texcoord;
            return o;
        }

        fixed luminance(fixed4 color)
        {
            return 0.2125 * color.r + 0.7154 * color.g + 0.0721 * color.b;
        }

        fixed4 fragExtractBright(v2fExtractBright i) : SV_Target0
        {
            fixed4 c = tex2D(_MainTex, i.uv);
            fixed val = clamp(luminance(c) - _LuminanceThreshold, 0.0, 1.0);
            return c * val;
        }

        struct v2fBlur
        {
            float4 pos : SV_POSITION;
            half2 uv[5]: TEXCOORD0;
        };

        v2fBlur vertBlurVertical(appdata_img v)
        {
            v2fBlur o;
            o.pos = UnityObjectToClipPos(v.vertex);

            half2 uv = v.texcoord;
            o.uv[0] = uv;
            o.uv[1] = uv + float2(0.0, _MainTex_TexelSize.y * 1.0) * _BlurSize;
            o.uv[2] = uv - float2(0.0, _MainTex_TexelSize.y * 1.0) * _BlurSize;
            o.uv[3] = uv + float2(0.0, _MainTex_TexelSize.y * 2.0) * _BlurSize;
            o.uv[4] = uv - float2(0.0, _MainTex_TexelSize.y * 2.0) * _BlurSize;

            return o;
        }

        v2fBlur vertBlurHorizontal(appdata_img v)
        {
            v2fBlur o;
            o.pos = UnityObjectToClipPos(v.vertex);

            half2 uv = v.texcoord;
            o.uv[0] = uv;
            o.uv[1] = uv + float2(_MainTex_TexelSize.x * 1.0, 0.0) * _BlurSize;
            o.uv[2] = uv - float2(_MainTex_TexelSize.x * 1.0, 0.0) * _BlurSize;
            o.uv[3] = uv + float2(_MainTex_TexelSize.x * 2.0, 0.0) * _BlurSize;
            o.uv[4] = uv - float2(_MainTex_TexelSize.x * 2.0, 0.0) * _BlurSize;

            return o;
        }

        fixed4 fragBlur(v2fBlur i) : SV_Target {
            float weight[3] = {0.4026, 0.2442, 0.0545};//一维高斯函数的对称性{0.0545,0.2442,0.4026, 0.2442, 0.0545}
            fixed3 sum = tex2D(_MainTex, i.uv[0]).rgb * weight[0];
            //卷积运算
            /*
            第一次循环：uv[1]*weight[1]  uv[2]*weight[1]
            第二次循环：uv[3]*weight[2]  uv[4]*weight[2]
            */
            for(int it = 1; it < 3; it++){
				sum += tex2D(_MainTex, i.uv[it*2-1]).rgb * weight[it];
				sum += tex2D(_MainTex, i.uv[it*2]).rgb * weight[it];
            }

            return fixed4(sum, 1.0);
        }

        struct v2fBloom
        {
            float4 pos : SV_POSITION;
            half4 uv : TEXCOORD0;
        };

        v2fBloom vertBloom(appdata_img v)
        {
            v2fBloom o;
            o.pos = UnityObjectToClipPos(v.vertex);

             /*
            两个纹理坐标，储存在half4变量uv 
            xy分量：_MainTex 纹理
            zw分量：_Bloom 纹理
            */
            o.uv.xy = v.texcoord;
            o.uv.zw = v.texcoord;

            #if UNITY_UV_STARTS_AT_TOP
            if(_MainTex_TexelSize.y < 0.0)//平台差异处理，对于主纹理Unity会自动翻转纹理，其他的纹理需要手动翻转
                o.uv.w = 1.0 - o.uv.w;
            #endif

            return o;
        }

        fixed4 fragBloom(v2fBloom i) : SV_Target
        {
            return tex2D(_MainTex, i.uv.xy) + tex2D(_Bloom, i.uv.zw);
        }
        ENDCG
        
        ZTest Always Cull off ZWrite Off
        Pass 
        {
            CGPROGRAM
            #pragma vertex vertExtractBright
            #pragma fragment fragExtractBright
            ENDCG
        }
        
        Pass 
        {
            CGPROGRAM
            #pragma vertex vertBlurVertical
            #pragma fragment fragBlur
            ENDCG
        }
        
        
        Pass 
        {
            CGPROGRAM
            #pragma vertex vertBlurHorizontal
            #pragma fragment fragBlur
            ENDCG
        }
        
        Pass 
        {
            CGPROGRAM
            #pragma vertex vertBloom
            #pragma fragment fragBloom
            ENDCG
        }
    }
    FallBack "Diffuse"
}
