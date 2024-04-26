Shader "Learn/Fog/HeightFog"
{
    Properties
    {
        [KeywordEnum(VIEWSPACE, WORLDSPACE)] _DIST_TYPE("Distance Type", int) = 0
        [KeywordEnum(LINEAR, EXP, EXP2)] _FUNC_TYPE("Calculate Func Type", int) = 0
         
        _MainTex ("Texture", 2D) = "white" {}
        _NoiseTex ("Noise Texture", 2D) = "white" {}
        _FogColor("", Color) = (0.5, 0.5, 0.5, 1)
        
        _HeightStart ("Height Start", Float) = 1                                    // 淡入雾效的开始高度
        _HeightEnd ("Height End", Float) = 0                                        // 完全雾效的结束高度
        _WorldPosScale("World Pos Scale", Range(0, 10)) = 1
        _NoiseSpeedX("Noise Speed X", Float) = 1
        _NoiseSpeedY("Noise Speed Y", Float) = 1
        _NoiseScale("Noise Scale", Float) = 1
        
        _Density("Density", Range(0, 1)) = 0.3
    }
    SubShader
    {
        ZWrite Off
        ZTest Always
        Cull Off

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile _DIST_TYPE_VIEWSPACE _DIST_TYPE_WORLDSPACE
            #pragma multi_compile _FUNC_TYPE_LINEAR _FUNC_TYPE_EXP _FUNC_TYPE_EXP2
            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float4 vertex : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 viewVec : TEXCOORD1;
            };

            sampler2D _CameraDepthTexture;
            sampler2D _NoiseTex;
            float4 _NoiseTex_ST;
            sampler2D _MainTex;
            float4 _MainTex_ST;
            fixed4 _FogColor;
            float _HeightStart;
            float _HeightEnd;
            float _Density;
            float _WorldPosScale;
            float _NoiseSpeedX;
            float _NoiseSpeedY;
            float _NoiseScale;
            

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);

                float4 screenPos = ComputeScreenPos(o.vertex);
                
                #ifdef UNITY_REVERSED_Z
                float4 viewVec = float4(screenPos.xy * 2 - 1,  0, 1);
                #else
                float4 viewVec = float4(o.uv * 2 - 1,  1, 1);
                #endif
                viewVec *= _ProjectionParams.z;//反向透视除法
                o.viewVec = mul(unity_CameraInvProjection, viewVec).xyz;
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                float depth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, i.uv);
                float linear01Depth = Linear01Depth(depth);
                float3 viewVec = i.viewVec * linear01Depth;
                float3 wp = _WorldSpaceCameraPos + viewVec;
                
                 // move the noise fog
                float2 noiseUV = wp.xz * _WorldPosScale + _Time.x * fixed2(_NoiseSpeedX, _NoiseSpeedY);
                float noise = tex2D(_NoiseTex, TRANSFORM_TEX(noiseUV, _NoiseTex)).r;
                float heightNoise = noise * _NoiseScale;

                // height fog
                float factor = (_HeightEnd - wp.y - heightNoise) / (_HeightEnd - _HeightStart);
                factor = saturate(factor);
                fixed4 texCol = tex2D(_MainTex, i.uv);
                return lerp(texCol, _FogColor, factor);
            }
            ENDCG
        }
    }
}
