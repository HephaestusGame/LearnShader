Shader "Learn/HBAO"
{
    Properties
    {
        _Color ("Color", Color) = (1,1,1,1)
        _MainTex ("Albedo (RGB)", 2D) = "white" {}
    }
    SubShader
    {
        Cull Off ZWrite Off ZTest Always
        Tags { "RenderType"="Opaque" }
        
        CGINCLUDE
        #include "UnityCG.cginc"
        #define FLT_EPSILON 1.192092896e-07

        float4 _UV2View;
        float4 _TexelSize;
        float _AOStrength;
        float _MaxRadiusPixel;
        float _RadiusPixel;
        float _Radius;
        float _AngleBias;
        float _BlurRadiusPixel;
        int _BlurSamples;
        float2 _BlurDir;
        
        UNITY_DECLARE_SCREENSPACE_TEXTURE(_CameraDepthNormalsTexture)
        half4 _CameraDepthNormalsTexture_TexelSize;
        sampler2D _MainTex;
        half4 _MainTex_TexelSize;
        sampler2D _HbaoTex;
        sampler2D _HbaoBlurTex;
        UNITY_DECLARE_DEPTH_TEXTURE(_CameraDepthTexture);//depth should use high precise

        float2 TransformTriangleVertexToUV(float2 vertex)
        {
            return (vertex + 1.0) * 0.5;
        }

        struct appdata
        {
            float4 vertex : POSITION;
            float2 uv : TEXCOORD0;
        };

        struct v2f
        {
            float2 uv : TEXCOORD0;
            float4 vertex : SV_POSITION;
            float3 viewVec : TEXCOORD1;
        };

        v2f vert (appdata v)
        {
            v2f o;
            o.vertex = UnityObjectToClipPos(v.vertex);
            o.uv = v.uv;
            // #if UNITY_UV_STARTS_AT_TOP
            //     o.uv = float2(o.uv.x, 1 - o.uv.y);
            // #endif

            //根据像素屏幕坐标计算从摄像机原点到像素点形成的向量的在观察空间中的表示（viewVec）
            float4 screenPos = ComputeScreenPos(o.vertex);
            float4 ndcPos = (screenPos / screenPos.w) * 2 - 1;
            float3 clipVec = float3(ndcPos.xy, 1.0) * _ProjectionParams.z;//计算像素点对应的远平面的点的裁剪空间坐标（反向透视除法）
            o.viewVec = mul(unity_CameraInvProjection, clipVec.xyzz).xyz;
            return o;
        }

        
        float PositivePow(float base, float power)
        {
            return pow(max(abs(base), float(FLT_EPSILON)), power);
        }

        inline float FallOff(float dist)
        {
            // return 1;
            return 1 - dist / _Radius;
        }

        inline float SimpleAO(float3 pos, float3 stepPos, float3 normal, inout float angleBias)
        {
            float3 h = stepPos - pos;
            float dist = sqrt(dot(h,h));
            float sinBlock = dot(normal, h) / dist;
            return saturate(sinBlock - angleBias) * saturate(FallOff(dist));
        }

        //value-noise https://thebookofshaders.com/11/
        inline float random(float2 uv) {
            return frac(sin(dot(uv.xy, float2(12.9898, 78.233))) * 43758.5453123);
        }
        ENDCG
        
        Pass 
        {
            CGPROGRAM
            #pragma multi_compile DIRECTION_4 DIRECTION_6 DIRECTION_8
            #pragma multi_compile STEPS_4 STEPS_6 STEPS_8

            #if DIRECTION_4
                #define DIRECTION 4
            #elif DIRECTION_6   
                #define DIRECTION 6
            #elif DIRECTION_8
                #define DIRECTION 8
            #endif

            #if STEPS_4
                #define STEPS       4
            #elif STEPS_6
                #define STEPS       6
            #elif STEPS_8
                #define STEPS       8
            #endif

            #pragma vertex vert
            #pragma fragment hbao

            inline float3 FetchViewPos(float2 uv, float3 viewVec)
            {
                float linear01Depth;
                float3 viewNormal;
                float4 depthNormal = tex2D(_CameraDepthNormalsTexture, uv);
                DecodeDepthNormal(depthNormal, linear01Depth, viewNormal);
                return linear01Depth * viewVec;
            }
            
            float4 hbao(v2f input) : SV_Target
            {
                float ao = 0;
                float3 viewNormal;
                float linear01Depth;
                float4 depthNormal = tex2D(_CameraDepthNormalsTexture, input.uv);
                DecodeDepthNormal(depthNormal, linear01Depth, viewNormal);
                float3 viewPos = linear01Depth * input.viewVec;
                // viewNormal = normalize(cross(ddx(viewPos), ddy(viewPos)));


                float stepSize = 1;
                
                // float stepSize = min((_RadiusPixel / abs(viewPos.z)), _MaxRadiusPixel) / STEPS;
                // if (stepSize < 1)
                //     return float4(1,0,1,1);

                float delta = 2.0 * UNITY_PI / DIRECTION;
                float rnd = random(input.uv);

                UNITY_UNROLL
                for (int i = 0; i < DIRECTION; ++i)
                {
                    float angle = delta * (float(i) + rnd);
                    float cos, sin;
                    sincos(angle, sin, cos);
                    float2 dir = float2(cos, sin);
                    float rayPixel = 1;
                    UNITY_UNROLL
                    for(int j = 0; j < STEPS; ++j)
                    {
                        float2 stepUV = round(rayPixel * dir) * _MainTex_TexelSize.xy + input.uv;
                        float3 stepViewPos = FetchViewPos(stepUV, input.viewVec);
                        ao += SimpleAO(viewPos, stepViewPos, viewNormal, _AngleBias);
                        rayPixel += stepSize;
                    }
                }
                ao /= STEPS * DIRECTION;
                // ao *= _AOStrength;
                // ao = PositivePow(ao * _AOStrength, 0.6);
                float col = saturate(1 - ao);
                return float4(col, col, col, 1);
            }
            ENDCG
        }
        
        Pass 
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment compositeFrag
            sampler2D _AOTex;
            fixed4 compositeFrag(v2f i): SV_Target
            {
                fixed4 col = tex2D(_MainTex, i.uv);
                fixed4 ao = tex2D(_AOTex, i.uv);
                col.rgb *= ao.r;
                return col;
            }
            ENDCG
        }
    }
    FallBack "Diffuse"
}
