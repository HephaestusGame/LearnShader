Shader "Learn/VolumetricLight"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100
        Cull Off ZWrite Off ZTest Always

        CGINCLUDE
        #include "UnityCG.cginc"
        #include "Lighting.cginc"
        #include "AutoLight.cginc"
        #include "Assets/Scenes/TestScenes/ShaderUtils/DepthUtils.cginc"
        #include "Assets/Scenes/TestScenes/ShaderUtils/CascadeShadowUtils.cginc"

        #pragma multi_compile_local _ DITHER
        #pragma mutli_compile_local DITHER_4_4 DITHER_8_8

      
        sampler3D _NoiseTexture;
        sampler2D _MainTex, _DitherTexture;
        // x: scattering coef, y: extinction coef, z: range w: skybox extinction coef
		float4 _VolumetricLight;
        // x: 1 - g^2, y: 1 + g^2, z: 2*g, w: 1/4pi
        float4 _MieG;

		// x: scale, y: intensity, z: intensity offset
		float4 _NoiseData;
        // x: x velocity, y: z velocity
		float4 _NoiseVelocity;
        float4 _LightDir;
        float4 _LightColor;

        float _IntensityScale;
        

		float _MaxRayLength;

		int _SampleCount;
        
        struct Attributes
        {
            float4 vertex : POSITION;//使用内置阴影的话，这里的变量名必须是vertex
            float2 uv : TEXCOORD0;
        };

        struct Varyings
        {
            float4 pos : SV_POSITION;//使用内置阴影的话，这里的变量名必须是pos
            float2 uv : TEXCOORD0;
        };

        float GetDensity(float3 wpos)
		{
            float density = 1;
            #ifdef NOISE
			    float noise = tex3D(_NoiseTexture, frac(wpos * _NoiseData.x + float3(_Time.y * _NoiseVelocity.x, 0, _Time.y * _NoiseVelocity.y)));
			    noise = saturate(noise - _NoiseData.z) * _NoiseData.y;
			    density = saturate(noise);
            #endif

            return density;
		}

        float MieScattering(float cosAngle, float4 g)
		{
            return g.w * (g.x / (pow(g.y - g.z * cosAngle, 1.5)));			
		}

        float4 RayMarch(float2 screenPos, float3 rayStart, float3 rayDir, float rayLength)
        {
            float offset = 1;

            #if defined(DITHER)
                #if defined(DITHER_4_4)
                    float2 interleavedPos = (fmod(floor(screenPos.xy), 4.0));
			        offset = tex2D(_DitherTexture, interleavedPos / 4.0 + float2(0.5 / 4.0, 0.5 / 4.0)).w;
                #else
                    float2 interleavedPos = (fmod(floor(screenPos.xy), 8.0));
			        offset = tex2D(_DitherTexture, interleavedPos / 8.0 + float2(0.5 / 8.0, 0.5 / 8.0)).w;
                #endif
            #endif
            
            int stepCount = _SampleCount;

            float stepSize = rayLength / stepCount;
            float3 step = rayDir * stepSize;

            float3 curPos = rayStart + step * offset;
            float4 vLight = 0;
            float cosAngle;
            float extinction = 0;
            cosAngle = dot(_LightDir.xyz, -rayDir);

            UNITY_LOOP
            for (int i = 0; i < stepCount; ++i)
            {
                float atten = GetLightAttenuation(curPos);
                float density = GetDensity(curPos);

                //_VolumetricLight x: scattering coef, y: extinction coef, z: range w: skybox extinction coef
                float scattering = _VolumetricLight.x * stepSize * density;
                extinction += _VolumetricLight.y * stepSize * density;//累计气溶胶密度
                float4 light = atten * scattering * exp(-extinction);
                vLight += light;
                curPos += step;
            }

            //_MieG x: 1 - g^2, y: 1 + g^2, z: 2*g, w: 1/4pi
            vLight *= MieScattering(cosAngle, _MieG);

            vLight *= _LightColor * _IntensityScale;

            vLight = max(0, vLight);
            vLight.w = exp(-extinction);
            return vLight;
        }

     
        ENDCG
        Pass
        {
            Blend One One, One Zero
            CGPROGRAM
            #pragma multi_compile_local _ NOISE
            #pragma vertex vert
            #pragma fragment frag
            Varyings vert(Attributes IN)
            {
                Varyings o;
                o.pos = UnityObjectToClipPos(IN.vertex);
                o.uv = IN.uv;
                return o;
            }

            float4 frag(Varyings i) : SV_Target
            {
                float3 worldPos = GetWorldSpacePosition(i.uv);
                // return float4(worldPos, 1);

                float3 rayStart = _WorldSpaceCameraPos;
                float3 rayDir = worldPos - _WorldSpaceCameraPos;

                float rayLength = length(rayDir);
                rayDir /= rayLength;
                rayLength = min(rayLength, _MaxRayLength);

                float4 color = RayMarch(i.pos.xy, rayStart, rayDir, rayLength);
                return color;
            }
            ENDCG
        }
    }
}
