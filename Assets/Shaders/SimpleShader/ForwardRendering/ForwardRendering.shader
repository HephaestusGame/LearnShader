Shader "Learn/ForwardRendering"
{
    Properties 
    {
        _Diffuse ("Diffuse", Color) = (1,1,1,1)
        _Specular ("Specular", Color) = (1,1,1,1)
        _Gloss ("Gloss", Range(8, 256)) = 20
    }
    SubShader 
    {
        Tags { "RenderType" = "Opaque" }
        Pass 
        {
            //标记为ForwardBase的pass仅会被第一个逐像素光源调用，同时环境光、自发光（本例不包含）也应在该pass中计算（即只计算一次）
            Tags { "LightMode" = "ForwardBase" }
            
            CGPROGRAM
            #pragma multi_compile_fwdbase //用于保证Unity为此Shader提供正确的变种，以确保各种参数被正确填充，比如光照衰减值等
            #include "Lighting.cginc"

            #pragma vertex vert
            #pragma fragment frag
            
            fixed4 _Diffuse;
            fixed4 _Specular;
            float _Gloss;

            struct a2v
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
            };

            struct v2f
            {
                float4 pos : SV_POSITION;
                float3 worldNormal : TEXCOORD0;
                float3 worldPos : TEXCOORD1;
            };

            v2f vert(a2v v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.worldNormal = UnityObjectToWorldNormal(v.normal);
                o.worldPos = mul(unity_ObjectToWorld, v.vertex);

                return o;
            }

            fixed4 frag(v2f i): SV_Target
            {
                fixed3 worldNormal = normalize(i.worldNormal);
                fixed3 worldLightDir = normalize(_WorldSpaceLightPos0.xyz);

                fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz;
                fixed3 diffuse = _LightColor0.rgb * _Diffuse.rgb * saturate(dot(worldNormal, worldLightDir));

                fixed3 viewDir = normalize(_WorldSpaceCameraPos.xyz - i.worldPos);
                fixed3 halfDir = normalize(viewDir + worldLightDir);
                fixed3 specular = _LightColor0.rgb * _Specular.rgb * pow(saturate(dot(i.worldNormal, halfDir)), _Gloss);

                fixed atten = 1.0;//光照衰减度，平行光无衰减，即为1

                return fixed4(ambient + (diffuse + specular) * atten, 1.0);
            }
            ENDCG
        }
        Pass
        {
            //AdditionalPass 其他影响该物体的逐像素光源，每个光源执行一次pass
            Tags { "LightMode" = "ForwardAdd"}
            Blend One One //源因子（当前采样），目标因子（帧缓冲），这里设置为One One是因为我们希望这个pass可以和上面的BasePass的光照结果在帧缓冲中叠加，从而得到最终的有多个光照的渲染效果
            CGPROGRAM
            #include "Lighting.cginc"
            #include "AutoLight.cginc"
            #pragma multi_compile_fwdadd
            
            #pragma vertex vert
            #pragma fragment frag

            fixed4 _Diffuse;
			fixed4 _Specular;
			float _Gloss;
            
            struct a2v {
				float4 vertex : POSITION;
				float3 normal : NORMAL;
			};
			
			struct v2f {
				float4 pos : SV_POSITION;
				float3 worldNormal : TEXCOORD0;
				float3 worldPos : TEXCOORD1;
			};
			
			v2f vert(a2v v) {
				v2f o;
				o.pos = UnityObjectToClipPos(v.vertex);
				
				o.worldNormal = UnityObjectToWorldNormal(v.normal);
				
				o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
				
				return o;
			}
			
			fixed4 frag(v2f i) : SV_Target {
				fixed3 worldNormal = normalize(i.worldNormal);
				#ifdef USING_DIRECTIONAL_LIGHT
					fixed3 worldLightDir = normalize(_WorldSpaceLightPos0.xyz);
				#else
					fixed3 worldLightDir = normalize(_WorldSpaceLightPos0.xyz - i.worldPos.xyz);
				#endif
				
				fixed3 diffuse = _LightColor0.rgb * _Diffuse.rgb * max(0, dot(worldNormal, worldLightDir));
				
				fixed3 viewDir = normalize(_WorldSpaceCameraPos.xyz - i.worldPos.xyz);
				fixed3 halfDir = normalize(worldLightDir + viewDir);
				fixed3 specular = _LightColor0.rgb * _Specular.rgb * pow(max(0, dot(worldNormal, halfDir)), _Gloss);
				
				#ifdef USING_DIRECTIONAL_LIGHT
					fixed atten = 1.0;
				#else
					#if defined (POINT)
				        float3 lightCoord = mul(unity_WorldToLight, float4(i.worldPos, 1)).xyz;
						//_LightTexture0是Unity为了简化计算光的衰减而提前准备好的一张衰减纹理
				        fixed atten = tex2D(_LightTexture0, dot(lightCoord, lightCoord).rr).UNITY_ATTEN_CHANNEL;
				    #elif defined (SPOT)
				        float4 lightCoord = mul(unity_WorldToLight, float4(i.worldPos, 1));
				        fixed atten = (lightCoord.z > 0) * tex2D(_LightTexture0, lightCoord.xy / lightCoord.w + 0.5).w * tex2D(_LightTextureB0, dot(lightCoord, lightCoord).rr).UNITY_ATTEN_CHANNEL;
				    #else
				        fixed atten = 1.0;
				    #endif
				#endif

				return fixed4((diffuse + specular) * atten, 1.0);
			}
			
            ENDCG
        }
    }
    FallBack "Specular"   
}