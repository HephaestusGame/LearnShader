// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "Learn/FragmentLevelSpecular"
{
    Properties 
    {
        _Diffuse ("Diffuse", Color) = (1, 1, 1, 1)
        _Specular ("Specular", Color) = (1, 1, 1, 1)
        _Gloss ("Gloss", Range(1, 256)) = 20
        [MaterialToggle]
        _BlinnPhong ("BlinnPhont", Float) = 0 
    }
    SubShader 
    {
        Pass 
        {
            Tags { "LightMode" = "ForwardBase" }
            
            CGPROGRAM
            #include "Lighting.cginc"
            #include "UnityCG.cginc"
            #pragma vertex vert
            #pragma fragment frag
            fixed4 _Diffuse;
            fixed4 _Specular;
            float _Gloss;
            bool _BlinnPhong;

            struct a2v
            {
                fixed4 pos : POSITION;
                fixed3 normal : NORMAL;
            };

            struct v2f
            {
                float4 pos : SV_POSITION;
                float3 worldNormal : TEXCOORD0;
                float3 worldPos : TEXCOORD1;
            };

            v2f vert(a2v IN)
            {
                v2f OUT;
                OUT.pos = UnityObjectToClipPos(IN.pos);
                OUT.worldNormal = UnityObjectToWorldNormal(IN.normal);
                OUT.worldPos = mul(unity_ObjectToWorld, IN.pos);
                return OUT;
            }

            fixed4 frag(v2f IN): SV_Target {
                float3 worldNormal = normalize(IN.worldNormal);
                float3 worldLightDir = normalize(_WorldSpaceLightPos0);
                float3 worldViewDir = normalize(_WorldSpaceCameraPos.xyz - IN.worldPos.xyz);
                float3 reflectDir = normalize(reflect(-worldLightDir, worldNormal));

                float3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz;
                float3 diffuse = _LightColor0.rgb * _Diffuse.rgb * saturate(dot(worldNormal, worldLightDir));

                float3 specular;
                if (_BlinnPhong)
                {
                    float3 halfDir = normalize(worldLightDir + worldViewDir);
                    specular = _LightColor0.rgb * _Specular.rgb * pow(saturate(dot(halfDir, worldNormal)), _Gloss);
                } else
                {
                    specular = _LightColor0.rgb * _Specular.rgb * pow(saturate(dot(reflectDir, worldViewDir)), _Gloss);
                }

                return fixed4(ambient + diffuse + specular, 1);
            }
            ENDCG
        }    
    }
}