Shader "Learn/XRay"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _XRayColor ("XRayColor", Color) = (1, 1, 1, 1)
    }
    SubShader
    {
        Pass 
        {
            Tags {"RenderType" = "Transparent" "Queue" = "Transparent"}
            Blend SrcAlpha One
            ZTest Greater
            ZWrite Off
            
            CGPROGRAM
            #pragma vertex vertXRay
            #pragma fragment fragXRay
            #include "UnityCG.cginc"
            fixed4 _XRayColor;

            struct v2f2
            {
                float4 pos : SV_POSITION;
                fixed4 color : COLOR;
            };

            v2f2 vertXRay(appdata_base v)
            {
                v2f2 o;
                o.pos = UnityObjectToClipPos(v.vertex);
                float3 cameraObjectSpacePos = mul(unity_WorldToObject, _WorldSpaceCameraPos);
                float3 viewDir = cameraObjectSpacePos - v.vertex;
                float3 normal = normalize(v.normal);
                viewDir = normalize(viewDir);
                float rim = 1 - dot(normal, viewDir);
                o.color = _XRayColor * rim;
                return o;
            }

            fixed4 fragXRay(v2f2 i) : SV_Target
            {
                return i.color;
            }
            ENDCG
        }
        
        Pass
        {
            Tags { "RenderType"="Opaque" }
            ZTest LEqual
            ZWrite On
            
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // make fog work
            #pragma multi_compile_fog

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                UNITY_FOG_COORDS(1)
                float4 vertex : SV_POSITION;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                // sample the texture
                fixed4 col = tex2D(_MainTex, i.uv);
                // apply fog
                UNITY_APPLY_FOG(i.fogCoord, col);
                return col;
            }
            ENDCG
        }
    }
}
