Shader "Learn/AttenuationAndShadowUseBuildInFunctions"
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
            Cull Off
            CGPROGRAM
            #pragma multi_compile_fwdbase //用于保证Unity为此Shader提供正确的变种，以确保各种参数被正确填充，比如光照衰减值等
            #include "Lighting.cginc"
            #include "AutoLight.cginc"//阴影相关的各种宏都在里面

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
            	//声明一个对阴影纹理采样的坐标，参数为可以用的插值寄存器的索引值，这里为2，
            	//由于这些宏都会使用上下文变量来进行计算，为了能正常工作，需要保证a2v结构体的顶点坐标变量名为vertex，顶点着色器输入结构体a2v必须命名为v，v2f中的顶点变量名必须为pos
            	SHADOW_COORDS(2)
            };

            v2f vert(a2v v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.worldNormal = UnityObjectToWorldNormal(v.normal);
                o.worldPos = mul(unity_ObjectToWorld, v.vertex);

            	TRANSFER_SHADOW(o);//计算阴影纹理采样坐标到上面声明的变量中
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

    //             fixed atten = 1.0;//光照衰减度，平行光无衰减，即为1
				// fixed shadow = SHADOW_ATTENUATION(i);

            	UNITY_LIGHT_ATTENUATION(atten, i, i.worldPos);//unity内部处理光照衰减和阴影衰减atten（相乘得出的结果），宏内部会自动声明这个atten变量
            	
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
            // #pragma multi_compile_fwdadd
            #pragma multi_compile_fwdadd_fullshadows//为除了平行光外的光源添加阴影，添加了这个之后就不需要multi_compile_fwdadd了
            
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
				SHADOW_COORDS(2)
			};
			
			v2f vert(a2v v) {
				v2f o;
				o.pos = UnityObjectToClipPos(v.vertex);
				
				o.worldNormal = UnityObjectToWorldNormal(v.normal);
				
				o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;

				TRANSFER_SHADOW(o);
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
				
				// #ifdef USING_DIRECTIONAL_LIGHT
				// 	fixed atten = 1.0;
				// #else
				// 	#if defined (POINT)
				//         float3 lightCoord = mul(unity_WorldToLight, float4(i.worldPos, 1)).xyz;
				// 		//_LightTexture0是Unity为了简化计算光的衰减而提前准备好的一张衰减纹理
				//         fixed atten = tex2D(_LightTexture0, dot(lightCoord, lightCoord).rr).UNITY_ATTEN_CHANNEL;
				//     #elif defined (SPOT)
				//         float4 lightCoord = mul(unity_WorldToLight, float4(i.worldPos, 1));
				//         fixed atten = (lightCoord.z > 0) * tex2D(_LightTexture0, lightCoord.xy / lightCoord.w + 0.5).w * tex2D(_LightTextureB0, dot(lightCoord, lightCoord).rr).UNITY_ATTEN_CHANNEL;
				//     #else
				//         fixed atten = 1.0;
				//     #endif
				// #endif

				UNITY_LIGHT_ATTENUATION(atten, i, i.worldPos);//用了这个宏，就不再需要通过上面注释的代码判断光源类型来计算衰减
				return fixed4((diffuse + specular) * atten, 1.0);
			}
			
            ENDCG
        }
    }
    FallBack "Specular"   
}