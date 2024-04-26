Shader "Learn/AntiAliasing/TAAWithMotionVector"
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

            Texture2D _MainTex;
            SamplerState sampler_LinearClamp;
            SamplerState sampler_PointClamp;
            Texture2D _HistoryTex;
            Texture2D _CameraMotionVectorsTexture;
            Texture2D _CameraDepthTexture;
            float4 _CameraDepthTexture_TexelSize;
            float _LerpFactor;
            float2 _Jitter;
            int _IgnoreHistory;

            static const int2 kOffsets3x3[9] =
            {
	            int2(-1, -1),
	            int2( 0, -1),
	            int2( 1, -1),
	            int2(-1,  0),
                int2( 0,  0),
	            int2( 1,  0),
	            int2(-1,  1),
	            int2( 0,  1),
	            int2( 1,  1),
            };

            float3 RGBToYCoCg( float3 RGB )
            {
	            float Y  = dot( RGB, float3(  1, 2,  1 ) );
	            float Co = dot( RGB, float3(  2, 0, -2 ) );
	            float Cg = dot( RGB, float3( -1, 2, -1 ) );
	            
	            float3 YCoCg = float3( Y, Co, Cg );
	            return YCoCg;
            }
                
            float3 YCoCgToRGB( float3 YCoCg )
            {
	            float Y  = YCoCg.x * 0.25;
	            float Co = YCoCg.y * 0.25;
	            float Cg = YCoCg.z * 0.25;
            
	            float R = Y + Co - Cg;
	            float G = Y + Cg;
	            float B = Y - Co - Cg;
            
	            float3 RGB = float3( R, G, B );
	            return RGB;
            }
                
                
            float3 ClipHistory(float3 History, float3 BoxMin, float3 BoxMax)
            {
                float3 Filtered = (BoxMin + BoxMax) * 0.5f;
                float3 RayOrigin = History;
                float3 RayDir = Filtered - History;
                RayDir = abs( RayDir ) < (1.0/65536.0) ? (1.0/65536.0) : RayDir;
                float3 InvRayDir = rcp( RayDir );
            
                float3 MinIntersect = (BoxMin - RayOrigin) * InvRayDir;
                float3 MaxIntersect = (BoxMax - RayOrigin) * InvRayDir;
                float3 EnterIntersect = min( MinIntersect, MaxIntersect );
                float ClipBlend = max( EnterIntersect.x, max(EnterIntersect.y, EnterIntersect.z ));
                ClipBlend = saturate(ClipBlend);
                return lerp(History, Filtered, ClipBlend);
            }
            
            float2 GetClosestFragment(float2 uv)
            {
                float2 k = _CameraDepthTexture_TexelSize.xy;
                const float4 neighborhood = float4(
                    _CameraDepthTexture.Sample(sampler_PointClamp, uv - k).r,
                    _CameraDepthTexture.Sample(sampler_PointClamp, uv + float2(k.x, -k.y)).r,
                    _CameraDepthTexture.Sample(sampler_PointClamp, uv + float2(-k.x, k.y)).r,
                    _CameraDepthTexture.Sample(sampler_PointClamp, uv + k).r
                );
            #if UNITY_REVERSED_Z
                #define COMPARE_DEPTH(a, b) step(b, a)
            #else
                #define COMPARE_DEPTH(a, b) step(a, b)
            #endif
                float3 result = float3(0.0, 0.0,  _CameraDepthTexture.Sample(sampler_PointClamp, uv).r);
                result = lerp(result, float3(-1.0, -1.0, neighborhood.x), COMPARE_DEPTH(neighborhood.x, result.z));
                result = lerp(result, float3( 1.0, -1.0, neighborhood.y), COMPARE_DEPTH(neighborhood.y, result.z));
                result = lerp(result, float3(-1.0,  1.0, neighborhood.z), COMPARE_DEPTH(neighborhood.z, result.z));
                result = lerp(result, float3( 1.0,  1.0, neighborhood.w), COMPARE_DEPTH(neighborhood.w, result.z));
                return (uv + result.xy * k);
            }
            
            v2f vert(appdata_base i)
            {
                v2f o;
                o.uv = i.texcoord;
                o.pos = UnityObjectToClipPos(i.vertex);
                return o;
            }

            float4 frag(v2f i) : SV_Target
            {
                float2 uv = i.uv - _Jitter;
                float4 curColor = _MainTex.Sample(sampler_LinearClamp, uv);
                if (_IgnoreHistory)
                {
                    return curColor;
                }
                float2 motion = _CameraMotionVectorsTexture.Sample(sampler_LinearClamp, uv).xy;
                float2 historyUV = i.uv - motion;
                float4 historyColor = _HistoryTex.Sample(sampler_LinearClamp, historyUV);

                // 在 YCoCg色彩空间中进行Clip判断
                float3 AABBMin, AABBMax;
                AABBMax = AABBMin = RGBToYCoCg(curColor);
                for(int k = 0; k < 9; k++)
                {
                    float3 C = RGBToYCoCg(_MainTex.Sample(sampler_PointClamp, uv, kOffsets3x3[k]));
                    AABBMin = min(AABBMin, C);
                    AABBMax = max(AABBMax, C);
                }
                float3 HistoryYCoCg = RGBToYCoCg(historyColor);
                //根据AABB包围盒进行Clip计算:
                historyColor.rgb = YCoCgToRGB(ClipHistory(HistoryYCoCg, AABBMin, AABBMax));
                
                //跟随速度变化混合系数
                float BlendFactor = saturate(0.05 + length(motion) * 1000);
                if(historyUV.x < 0 || historyUV.y < 0 || historyUV.x > 1.0f || historyUV.y > 1.0f)
                {
                    BlendFactor = 1.0f;
                }
                return lerp(historyColor, curColor, BlendFactor);
            }
            ENDCG
        }
    }
}
