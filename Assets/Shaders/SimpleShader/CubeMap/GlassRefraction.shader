Shader "Learn/GlassRefraction"
{
    Properties 
    {
        _MainTex ("MainTexture", 2D) = "white" {}
        _BumpMap ("NormalMap", 2D) = "bump" {}
        _CubeMap ("Environment CubeMap", Cube) = "_SkyBox" {}
        _Distortion ("Distortion", Range(0,100)) = 10
        _RefractAmount ("Refract Amount", Range(0.0, 1.0)) = 1.0
    }
    
    SubShader 
    {
        Tags { "Queue" = "Transparent" "RenderType" = "Opaque" }//"Queue" = "Transparent"是为了渲染该物体时所有的不透明物体已经被渲染
        
        GrabPass {"_RefractionTex"}//抓取屏幕图像存到_RefractionTex，也可以选择不填这个纹理字符串，但是填入的话，性能会好一些
        
        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"

            sampler2D _MainTex;
            float4 _MainTex_ST;
            sampler2D _BumpMap;
            float4 _BumpMap_ST;
            samplerCUBE _CubeMap;
            float _Distortion;
            float _RefractAmount;
            sampler2D _RefractionTex;
            float4 _RefrectionTex_TexelSize;//???

            struct a2v
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
                float2 texcoord : TEXCOORD0;
            };

            struct v2f
            {
                float4 pos : SV_POSITION;
                float4 scrPos : TEXCOORD0;
                float4 uv : TEXCOORD1;
                float4 TtoW0 : TEXCOORD2;
                float4 TtoW1 : TEXCOORD3;
                float4 TtoW2 : TEXCOORD4;
            };

            v2f vert(a2v v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.scrPos = ComputeScreenPos(o.pos);

                o.uv.xy = TRANSFORM_TEX(v.texcoord, _MainTex);
                o.uv.zw = TRANSFORM_TEX(v.texcoord, _BumpMap);

                float3 worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
                fixed3 worldNormal = UnityObjectToWorldNormal(v.normal);
                fixed3 worldTangent = UnityObjectToWorldDir(v.tangent.xyz);
                fixed3 worldBinormal = cross(worldNormal, worldTangent) * v.vertex.w;
                o.TtoW0 = float4(worldTangent.x, worldBinormal.x, worldNormal.x, worldPos.x);
                o.TtoW1 = float4(worldTangent.y, worldBinormal.y, worldNormal.y, worldPos.y);
                o.TtoW2 = float4(worldTangent.z, worldBinormal.z, worldNormal.z, worldPos.z);
                
                return o;
            }

            fixed4 frag(v2f i) : SV_Target
            {
                float3 worldPos = float3(i.TtoW0.x, i.TtoW0.y, i.TtoW0.z);
                fixed3 worldViewDir = normalize(UnityWorldSpaceViewDir(worldPos));

                fixed3 bump = UnpackNormal(tex2D(_BumpMap, i.uv.zw));

                //偏移计算原因见 https://github.com/candycat1992/Unity_Shaders_Book/issues/64
                float2 offset = bump.xy * _Distortion * _RefrectionTex_TexelSize.xy;//XX_TexelSize表示的是这个纹理的像素大小：Vector4(1 / width, 1 / height, width, height)
                i.scrPos.xy = offset * i.scrPos.z + i.scrPos.xy;
                
                fixed3 refrCol = tex2D(_RefractionTex, i.scrPos.xy / i.scrPos.w).rgb;//i.scrPos.xy / i.scrPos.w 为透视除法，计算出屏幕坐标系下的纹理坐标

                bump = normalize(half3(dot(i.TtoW0.xyz, bump), dot(i.TtoW1.xyz, bump), dot(i.TtoW2.xyz, bump)));
				fixed3 reflDir = reflect(-worldViewDir, bump);
				fixed4 texColor = tex2D(_MainTex, i.uv.xy);
				fixed3 reflCol = texCUBE(_CubeMap, reflDir).rgb * texColor.rgb;
				
				fixed3 finalColor = reflCol * (1 - _RefractAmount) + refrCol * _RefractAmount;
				
				return fixed4(finalColor, 1);
            }
            
            ENDCG
        }    
    }
    
    FallBack "Diffuse"
}