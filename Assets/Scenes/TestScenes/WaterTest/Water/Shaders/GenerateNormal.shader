Shader "Unlit/GenerateNormal"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
    }
    SubShader
    {
        Cull Off ZWrite Off ZTest Always

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // make fog work
            #pragma multi_compile_fog

            #include "InteractiveWaterUtils.cginc"

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
            float4 _MainTex_TexelSize;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                float lh = DecodeHeight(tex2D(_MainTex, i.uv + float2(-_MainTex_TexelSize.x, 0.0)));
				float rh = DecodeHeight(tex2D(_MainTex, i.uv + float2(_MainTex_TexelSize.x, 0.0)));
				float bh = DecodeHeight(tex2D(_MainTex, i.uv + float2(0.0, -_MainTex_TexelSize.y)));
				float th = DecodeHeight(tex2D(_MainTex, i.uv + float2(0.0, _MainTex_TexelSize.y)));

                // float3 T = normalize(float3(2.0 * _MainTex_TexelSize.x, 0.0, rh - lh));
                // float3 B = normalize(float3(0.0, 2.0 * _MainTex_TexelSize.y, th - bh));
                // float3 N = normalize(cross(T, B));
                //当_MainTex_TexelSize 的 xy 相等时，可以简化为
                float3 N = normalize(float3(rh - lh, th - bh, 2.0 * _MainTex_TexelSize.x));
                return EncodeNormal(N);
            }
            ENDCG
        }
    }
}
