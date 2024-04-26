Shader "Custom/BumpMapping"
{
    Properties
    {
        _Color("Color Tint", Color) = (1,1,1,1)
        _MainTex("Main Tex", 2D) = "white" {}
        _BumpMap("Normal Map", 2D) = "bump" {}
        _BumpScale("Bump Scale", Float) = 1.0
        _Specular("Specular", Color) = (1,1,1,1)
        _Gloss ("Gloss", Range(8.0, 256)) = 20
        [Toggle(PARALLAX)] _ParallaxMapping("Parallax Mapping", Float) = 0
        [Toggle(STEEP_PARALLAX)] _SteepParallaxMapping("Steep Parallax Mapping", Float) = 0
        [Toggle(PARALLAX_OCCLUSION)] _ParallaxOcclusionMapping("Parallax Occlusion Mapping", Float) = 0
        _ParallaxMap("Parallax Map", 2D) = "white" {}
        _HeightScale("Height Scale", Float) = 1.0
        _SteepHeightScale("Steep Height Scale", Float) = 1.0
        
    }
    SubShader
    {
       Pass 
        {
            Tags { "LightMOde" = "ForwardBase"}
            
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile _ PARALLAX
            #pragma multi_compile _ STEEP_PARALLAX
            #pragma multi_compile _ PARALLAX_OCCLUSION
            #pragma multi_compile_fwdbase//支持多光源
            #include "Lighting.cginc"
            
            fixed4 _Color;
            sampler2D _MainTex;
            float4 _MainTex_ST;
            sampler2D _BumpMap;
            float4 _BumpMap_ST;
            sampler2D _ParallaxMap;
            float4 _ParallaxMap_ST;
            float _BumpScale;
            float _HeightScale;
            float _SteepHeightScale;
            fixed4 _Specular;
            float _Gloss;

            struct a2v
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
                float4 texcoord : TEXCOORD0;
            };

            struct v2f
            {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 lightDir : TEXCOORD1;
                float3 viewDir : TEXCOORD2;
            };

            v2f vert(a2v v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);

                o.uv = v.texcoord.xy * _MainTex_ST.xy + _MainTex_ST.zw;

                fixed3 worldNormal = UnityObjectToWorldNormal(v.normal);
                fixed3 worldTangent = UnityObjectToWorldDir(v.tangent.xyz);
                fixed3 worldBitangent = cross(worldNormal, worldTangent) * v.tangent.w;
                float3x3 worldToTangent = transpose(float3x3(worldTangent, worldBitangent, worldNormal));

                o.lightDir = mul(worldToTangent, WorldSpaceLightDir(v.vertex));
                o.viewDir = mul(worldToTangent, WorldSpaceViewDir(v.vertex));
                
                return o;
            }

            float2 Parallax(float2 uv, fixed3 viewDir)
            {
                float depth = tex2D(_ParallaxMap, uv).r;
                float2 p = viewDir.xy * depth * _HeightScale;
                return uv - p;
            }

            float2 SteepParallax(float2 uv, fixed3 viewDir)
            {
                float depth = tex2D(_ParallaxMap, uv).r;
                float2 p = viewDir.xy * depth * _SteepHeightScale;

                int numLayers = 20;
                float2 deltaUV = p / numLayers;
                float2 curUV = uv;
                float layerDepth = 1.0 / numLayers;
                float curLayerDepth = 0;
                float curDepthMapValue = tex2D(_ParallaxMap, curUV).r;

                //ERROR
                // while (curDepthMapValue > curLayerDepth)
                // {
                //     curLayerDepth += layerDepth;
                //     curUV -= deltaUV;
                //     curDepthMapValue = tex2D(_ParallaxMap, curUV).r;
                // }
                
                for (int i = 0; i < numLayers; i++)
                {
                    if (curDepthMapValue < curLayerDepth)
                    {
                        break;
                    }
                    curLayerDepth += layerDepth;
                    curUV -= deltaUV;
                    curDepthMapValue = tex2D(_ParallaxMap, curUV).r;
                }

                #if PARALLAX_OCCLUSION
                float2 prevUV = curUV + deltaUV;
                float afterDepth = curDepthMapValue - curLayerDepth;
                float beforeDepth = tex2D(_ParallaxMap, prevUV).r  - curLayerDepth + layerDepth;
                if (beforeDepth != afterDepth)
                {
                    float weight = afterDepth / (afterDepth - beforeDepth);
                    curUV = prevUV * weight + curUV * (1.0 - weight);
                }
                #endif
                
                
                return  curUV;
            }

            fixed4 frag(v2f i) : SV_Target
            {
                fixed3 tangentLightDir = normalize(i.lightDir);
                fixed3 tangentViewDir = normalize(i.viewDir);


                
                
                #if PARALLAX
                    #if STEEP_PARALLAX
                    float2 uv = SteepParallax(i.uv, tangentViewDir);
                    #else
                    float2 uv = Parallax(i.uv, tangentViewDir);
                    #endif
                #else
                float2 uv = i.uv;
                #endif

                // #if STEEP_PARALLAX
                // float2 uv = SteepParallax(i.uv, tangentViewDir);
                // #else
                // float2 uv = Parallax(i.uv, tangentViewDir);
                // #endif
                
                fixed4 packedNormal = tex2D(_BumpMap, uv);
                fixed3 tangentNormal = UnpackNormal(packedNormal);
                tangentNormal.xy *= _BumpScale;
                tangentNormal.z = sqrt(1.0 - saturate(dot(tangentNormal.xy, tangentNormal.xy)));

                fixed3 albebdo = tex2D(_MainTex, uv).rgb * _Color.rgb;

                fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz * albebdo;

                fixed3 diffuse = _LightColor0.rgb * albebdo * max(0, dot(tangentNormal, tangentLightDir));
                fixed3 halfDir = normalize(tangentLightDir + tangentViewDir);
                fixed3 specular = _LightColor0.rgb * _Specular.rgb * pow(max(0, dot(tangentNormal, halfDir)), _Gloss);

                return fixed4(ambient + diffuse + specular, 1.0);
                
            }
            ENDCG
        }
    }
    FallBack "Diffuse"
}
