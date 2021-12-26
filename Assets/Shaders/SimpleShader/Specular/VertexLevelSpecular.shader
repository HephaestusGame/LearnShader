Shader "Learn/Specular"
{
    Properties
    {
        _Diffuse ("Diffuse", Color) = (1, 1, 1, 1)
        _Specular ("Specular", Color) = (1, 1, 1, 1)
        _Gloss ("Gloss", Range(8.0, 256)) = 20
    }
    SubShader
    {
        Pass {
            Tags {"LightMode" = "ForwardBase"}
            CGPROGRAM
            #include "UnityCG.cginc"
            #include "Lighting.cginc"
            #pragma fragment frag
            #pragma vertex vert

            fixed4 _Diffuse;
            fixed4 _Specular;
            float _Gloss;

            struct a2v
            {
                float4 pos : POSITION;
                float3 normal : NORMAL;
            };

            struct v2f
            {
                float4 pos : SV_POSITION;
                fixed3 color : COLOR;
            };

            v2f vert(a2v IN)
            {
                v2f OUT;
                OUT.pos = UnityObjectToClipPos(float4(IN.pos.xyz, 1));
                
                float3 ambient = UNITY_LIGHTMODEL_AMBIENT.rgb;
                
                float3 worldNormal = UnityObjectToWorldNormal(IN.normal);
                float3 worldLightDir = normalize(_WorldSpaceLightPos0.xyz);
                float3 worldViewDir = normalize(_WorldSpaceCameraPos.xyz - mul(unity_ObjectToWorld, IN.pos).xyz);
                fixed3 reflectDir = normalize(reflect(-worldLightDir, worldNormal));
                
                float3 diffuse = _LightColor0.rgb * _Diffuse.rgb * saturate(dot(worldNormal, worldLightDir));
                float3 specular = _LightColor0.rgb * _Specular.rgb * pow(saturate(dot(reflectDir, worldViewDir)), _Gloss);

                OUT.color = ambient + diffuse + specular;
                return OUT;
            }

            fixed4 frag(v2f IN) : SV_Target
            {
                return fixed4(IN.color, 1);
            }
            ENDCG
        }
    }
    FallBack "Specular"
}
