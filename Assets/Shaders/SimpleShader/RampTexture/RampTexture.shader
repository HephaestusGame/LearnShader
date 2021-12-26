Shader "Learn/RampTexture" 
{
    Properties 
    {
        _Color ("Color Tint", Color) = (1, 1, 1, 1)
        _RampTex("Ramp Texture", 2D) = "white" {}
        _Specular("Specular", Color) = (1, 1, 1, 1)
        _Gloss ("Glossiness", Range(8, 256)) = 1
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
            sampler2D _RampTex;
            float4 _RampTex_ST;
            fixed4 _Specular;
            float _Gloss;

            struct a2v
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float4 texcoord : TEXCOORD0;
            };

            struct v2f
            {
                float4 pos : SV_POSITION;
                float3 worldNormal : TEXCOORD0;
                float3 worldPos : TEXCOORD1;
                float2 uv : TEXCOORD2;
            };

            v2f vert(a2v v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.worldNormal = UnityObjectToWorldNormal(v.normal);
                o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
                o.uv = TRANSFORM_TEX(v.texcoord, _RampTex);

                return o;
            }

            fixed4 frag(v2f i) : SV_Target
            {
                fixed3 worldNormal = normalize(i.worldNormal);
                fixed3 worldLightDir = normalize(UnityWorldSpaceLightDir(i.worldPos));
                fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz;

                fixed halflambert = 0.5 * dot(worldNormal, worldLightDir) + 0.5;//半兰伯特模型，使其结果在0-1之间
                fixed3 diffuse = tex2D(_RampTex, fixed2(halflambert, halflambert)).rgb * _Color.rgb;//因为RampTexture(渐变纹理)实际上是个一维纹理，即纵轴方向颜色不变，因此uv取相同的值即可

                fixed3 viewDir = normalize(UnityWorldSpaceViewDir(i.worldPos));
                fixed3 halfDir = normalize(viewDir + worldLightDir);
                fixed3 specular = _Color.rgb * _Specular.rgb * pow(max(0, dot(halfDir, worldNormal)), _Gloss);

                return fixed4(ambient + diffuse + specular, 1.0);
                
            }
            ENDCG
        }
    }
    
    FallBack "Specular"
}