Shader "Learn/NormalMapInTangentSpace"
{
    Properties
    {
        _Color ("Color", Color) = (1, 1, 1,  1)
        _Diffuse ("Diffuse", Color) = (1, 1, 1,  1)
        _Specular ("Specular", Color) = (1, 1, 1, 1)
        _Gloss ("Gloss", Range(2, 256)) = 20
        _MainTex ("Main Texture", 2D) = "white" {} //注意不要漏这个花括号
        _BumpMap ("Bump Map", 2D) = "bump" {}
        _BumpScale ("Bump Scale", Float) = 1
    }
    SubShader
    {
        Pass 
        {
            Tags { "LightMode" = "ForwardBase" }
            CGPROGRAM
            #include "UnityCG.cginc"
            #include "Lighting.cginc"
            #pragma vertex vert
            #pragma fragment frag

            fixed4 _Color;
            sampler2D _MainTex;
            float4 _MainTex_ST;
            sampler2D _BumpMap;
            float4 _BumpMap_ST;
            float _BumpScale;
            fixed4 _Specular;
            fixed4 _Diffuse;
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
                float4 uv : TEXCOORD0;
                float3 lightDir : TEXCOORD1;
                float3 viewDir : TEXCOORD2;
            };

            v2f vert(a2v v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);

                o.uv.xy = v.texcoord.xy * _MainTex_ST.xy + _MainTex_ST.zw;//等价于o.uv.xy = TRANSFORM_TEX(v.texcoord, _MainTex);
                o.uv.zw = v.texcoord.xy * _BumpMap_ST.xy + _BumpMap_ST.zw;//等价于o.uv.zw = TRANSFORM_TEX(v.texcoord, _BumpMap);

                fixed3 worldNormal = UnityObjectToWorldNormal(v.normal);
                fixed3 worldTangent = UnityObjectToWorldDir(v.tangent.xyz);
                fixed3 worldBiNormal = cross(worldNormal, worldTangent) * v.tangent.w;//乘上w是因为tangent.w控制了tangent的正负，如果是1，则是正方向，如果是-1，则是负方向

                /*
                 *知道各个切线空间坐标轴在世界空间的表示，则将其按列填充矩阵既可以得到从切线空间到世界空间的转换矩阵
                 *又因为坐标轴组成的矩阵为正交矩阵（各轴两两垂直，可以通过矩阵运算验证），所以从世界空间到切线空间的矩阵等于上面的矩阵的转置矩阵（正交矩阵的逆等于其转置矩阵）
                 *所以只需要将各坐标轴在世界空间的表示按照行填充
				float4x4 tangentToWorld = float4x4(worldTangent.x, worldBinormal.x, worldNormal.x, 0.0,
												   worldTangent.y, worldBinormal.y, worldNormal.y, 0.0,
												   worldTangent.z, worldBinormal.z, worldNormal.z, 0.0,
												   0.0, 0.0, 0.0, 1.0);
				// 
				float3x3 worldToTangent = inverse(tangentToWorld);
				*/
                float3x3 worldToTangent = float3x3(worldTangent, worldBiNormal, worldNormal);//行填充
                o.lightDir = mul(worldToTangent, WorldSpaceLightDir(v.vertex));
                o.viewDir = mul(worldToTangent, WorldSpaceViewDir(v.vertex));

                return o;
            }

            fixed4 frag(v2f i): SV_Target {
                fixed3 tangentLightDir = normalize(i.lightDir);
                fixed3 tangentViewDir = normalize(i.viewDir);

                
                fixed4 packedNormal = tex2D(_BumpMap, i.uv.zw);
                fixed3 tangentNormal;
                //如果texture没有标志为“Normal Map",则应如下计算，但是Unity会根据平台来选择不同的压缩方法，这时候用这种方法来计算就会得到错误的结果
                //因为此时_BumpMap的rgb分量并不再是切线空间下法线方向的xyz了
                //tangentNormal.xy = (packedNormal.xy * 2 - 1) * _BumpScale;
				//tangentNormal.z = sqrt(1.0 - saturate(dot(tangentNormal.xy, tangentNormal.xy)));
                //如果标志为“Normal Map"
                tangentNormal = UnpackNormal(packedNormal);
				tangentNormal.xy *= _BumpScale;
				tangentNormal.z = sqrt(1.0 - saturate(dot(tangentNormal.xy, tangentNormal.xy)));//因为法线都是单位矢量，知道xy则可以求z

                fixed3 albedo = tex2D(_MainTex, i.uv).rgb * _Color.rgb;
                fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz * albedo;
                fixed3 diffuse = _LightColor0.rgb * albedo * max(0, dot(tangentNormal, tangentLightDir));
                fixed3 halfDir = normalize(tangentLightDir + tangentViewDir);
                fixed3 specular = _LightColor0.rgb * albedo * _Specular.rgb * pow(saturate(dot(tangentNormal, halfDir)), _Gloss);

                return fixed4(ambient + diffuse + specular, 1.0);
            }
            ENDCG
        }
    }
    FallBack "Diffuse"
}