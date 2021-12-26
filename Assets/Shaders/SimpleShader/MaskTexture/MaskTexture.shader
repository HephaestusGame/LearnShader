Shader "Learn/MaskTexture"
{
    Properties 
    {
        _Color ("Color Tint", Color) = (1,1,1,1)
        _MainTex ("Main Texture", 2D) = "white" {}
        _BumpMap ("Normal Map", 2D) = "bump" {}
        _BumpScale ("Bump Scale", Float) = 1
        _SpecularMask ("Specular Mask", 2D) = "white" {}
        _SpecularScale ("Specular Mask Scale", Float) = 1
        _Specular ("Specular Color", Color) = (0,0,0,1)
        _Gloss ("Glossiness", Range(8,256)) = 20
    }
    
    SubShader 
    {
        Pass
        {
            Tags { "LightMode" = "ForwardBase"}
            CGPROGRAM
            #include "Lighting.cginc"
            #pragma vertex vert
            #pragma fragment frag

            fixed4 _Color;
            sampler2D _MainTex;
            float4 _MainTex_ST;
            sampler2D _BumpMap;
            float4 _BumpMap_ST;
            float _BumpScale;
            sampler2D _SpecularMask;
            float4 _SpecularMask_ST;
            float _SpecularScale;
            fixed4 _Specular;
            float _Gloss;

            struct a2v {
            float4 vertex : POSITION;
            float4 normal : NORMAL;
            float4 tangent : TANGENT;
            float4 texcoord : TEXCOORD0;
            };

            struct v2f
            {
                float4 pos : SV_POSITION;
                float4 uv : TEXCOORD0;
                float3 lightDir : TEXCOORD1;
                float3 viewDir : TEXCOORD2;
            };

            v2f vert(a2v i)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(i.vertex);
                o.uv.xy = TRANSFORM_TEX(i.texcoord, _MainTex);
                o.uv.zw = TRANSFORM_TEX(i.texcoord, _BumpMap);

                fixed3 worldLightDir = UnityWorldSpaceLightDir(i.vertex);
                fixed3 worldViewDir = UnityWorldSpaceViewDir(i.vertex);

                fixed3 worldNormal = UnityObjectToWorldNormal(i.normal);
                fixed3 worldTangent = UnityObjectToWorldDir(i.tangent);
                fixed3 worldBinormal = cross(worldNormal, worldTangent).xyz * i.tangent.w;

                float3x3 worldToTangent = float3x3(worldTangent, worldBinormal, worldNormal);
                o.lightDir = mul(worldToTangent, worldLightDir).xyz;
                o.viewDir = mul(worldToTangent, worldViewDir).xyz;
                
                return o;
            }

            fixed4 frag(v2f i): SV_Target
            {
                fixed3 lightDir = normalize(i.lightDir);
                fixed3 viewDir = normalize(i.viewDir);

                fixed4 packedNormal = tex2D(_BumpMap, i.uv.zw);
                fixed3 tangentSpaceNormal = normalize(UnpackNormal(packedNormal));
                tangentSpaceNormal.xy *= _BumpScale;
                tangentSpaceNormal.z = sqrt(1 - saturate(dot(tangentSpaceNormal.xy, tangentSpaceNormal.xy)));

                fixed3 albedo = tex2D(_MainTex, i.uv.xy).rgb * _Color.rgb;
                fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.rgb;
                fixed3 diffuse = saturate(dot(lightDir, tangentSpaceNormal)) * albedo * _LightColor0.rgb;
                fixed3 halfDir = normalize(lightDir + viewDir);
                fixed specularMask = tex2D(_SpecularMask, i.uv).r * _SpecularScale;
                fixed3 specular = albedo * _LightColor0.rgb * _Specular.rgb * pow(saturate(dot(halfDir, tangentSpaceNormal)), _Gloss) * specularMask;

                return fixed4(ambient + diffuse + specular, 1);
            }
            ENDCG
        }
        
        
        
    }
    Fallback "Specular"
}