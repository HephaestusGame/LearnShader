Shader "Learn/SSAO"
{
    Properties
    {
        [HideInInspector]_MainTex ("Texture", 2D) = "white" {}
    }
    
    CGINCLUDE
    #include "UnityCG.cginc"
    struct appdata
    {
        float4 vertex : POSITION;
        float2 uv : TEXCOORD0;
    };

    struct v2f
    {
        float2 uv : TEXCOORD0;
        float4 vertex : SV_POSITION;
        float3 viewVec : TEXCOORD1;
    };

    #define MAX_SAMPLE_KERNEL_COUNT 64

    float3 _randomVec;
    bool _isRandom;
    bool _useRangeCheck;
    bool _useRangeHardCheck;

    sampler2D _MainTex;
    half4 _MainTex_TexelSize;
    sampler2D _CameraDepthNormalsTexture;

    sampler2D _NoiseTex;
    float4 _SampleKernelArray[MAX_SAMPLE_KERNEL_COUNT];
    float _SampleKernelCount;
    float _SampleKeneralRadius;
    float _DepthBiasValue;
    float _RangeStrength;
    float _AOStrength;
    int _NoiseUnit;
    v2f vertAO(appdata v)
    {
        v2f o;
        o.vertex = UnityObjectToClipPos(v.vertex);
        o.uv = v.uv;

        //根据像素屏幕坐标计算从摄像机原点到像素点形成的向量的在观察空间中的表示（viewVec）
        float4 screenPos = ComputeScreenPos(o.vertex);
        float4 ndcPos = (screenPos / screenPos.w) * 2 - 1;
        float3 clipVec = float3(ndcPos.xy, 1.0) * _ProjectionParams.z;//计算像素点对应的远平面的点的裁剪空间坐标（反向透视除法）
        o.viewVec = mul(unity_CameraInvProjection, clipVec.xyzz).xyz;

        return o;
    }

    fixed4 fragAO(v2f i) : SV_Target
    {
        //采样屏幕纹理
        fixed4 col = tex2D(_MainTex, i.uv);
        
        float3 viewNormal;
        float linear01Depth;
        float4 depthnormal = tex2D(_CameraDepthNormalsTexture, i.uv);
        DecodeDepthNormal(depthnormal, linear01Depth, viewNormal);
  
        //渲染像素点的观察空间坐标
        float3 viewPos = linear01Depth * i.viewVec;
  
        //TBN
        float3 randVec = normalize(float3(1, 1, 1));
        if (_isRandom)
        {
            float2 noiseScale = _ScreenParams.xy / _NoiseUnit;
            float2 noiseUV = i.uv * noiseScale;
            randVec = tex2D(_NoiseTex, noiseUV).xyz;
            randVec = randVec * 0.5 + 0.5;
            randVec = normalize(randVec);
        }
  
        //Gramm-Schimidt构建正交基
        viewNormal = normalize(viewNormal) * float3(1, 1, 1);
        float3 tangent = normalize(randVec - viewNormal * dot(randVec, viewNormal));
        float3 bitangent = cross(viewNormal, tangent);
        float3x3 TBN = float3x3(tangent, bitangent, viewNormal);
  
        //AO计算
        float ao = 0;
        for(int i = 0;i < _SampleKernelCount; i++)
        {
            float3 randomVec = mul(_SampleKernelArray[i].xyz, TBN);
            float3 randomPos = viewPos + randomVec * _SampleKeneralRadius;
            float3 rClipPos = mul((float3x3)unity_CameraProjection, randomPos);
            float2 rScreenPos = (rClipPos.xy / rClipPos.z) * 0.5 + 0.5;
  
            float randomDepth;
            float3 randomNormal;
            float4 rcdn = tex2D(_CameraDepthNormalsTexture, rScreenPos);
            DecodeDepthNormal(rcdn, randomDepth, randomNormal);
            float randomPosLinear01Depth = -randomPos.z * _ProjectionParams.w;
            float tempAO = randomPosLinear01Depth >= randomDepth ? 1.0 : 0.0;

            if (_useRangeCheck)
            {
                if (_useRangeHardCheck)
                {
                    float range = abs(randomDepth - linear01Depth) > _RangeStrength ? 0.0 : 1.0;
                    tempAO = tempAO * range;
                } else
                {
                    float range = smoothstep(0, 1.0, _RangeStrength / (abs(randomDepth - linear01Depth) *_ProjectionParams.z));
                    tempAO = tempAO * range;
                }
            }
            
            ao += tempAO;
        }
        ao = ao / _SampleKernelCount;
        ao = max(0.0, 1 - ao * _AOStrength);
        return fixed4(ao, ao, ao, 1);
    }


    //Blur
	float _BilaterFilterFactor;
	float2 _BlurRadius;

	///基于法线的双边滤波（Bilateral Filter）
	//https://blog.csdn.net/puppet_master/article/details/83066572
	float3 GetNormal(float2 uv)
	{
		float4 cdn = tex2D(_CameraDepthNormalsTexture, uv);	
		return DecodeViewNormalStereo(cdn);
	}

	half CompareNormal(float3 nor1,float3 nor2)
	{
		return smoothstep(_BilaterFilterFactor,1.0,dot(nor1,nor2));
	}
	
	fixed4 frag_Blur (v2f i) : SV_Target
	{
		//_MainTex_TexelSize -> https://forum.unity.com/threads/_maintex_texelsize-whats-the-meaning.110278/
		float2 delta = _MainTex_TexelSize.xy * _BlurRadius.xy;
		
		float2 uv = i.uv;
		float2 uv0a = i.uv - delta;
		float2 uv0b = i.uv + delta;	
		float2 uv1a = i.uv - 2.0 * delta;
		float2 uv1b = i.uv + 2.0 * delta;
		float2 uv2a = i.uv - 3.0 * delta;
		float2 uv2b = i.uv + 3.0 * delta;
		
		float3 normal = GetNormal(uv);
		float3 normal0a = GetNormal(uv0a);
		float3 normal0b = GetNormal(uv0b);
		float3 normal1a = GetNormal(uv1a);
		float3 normal1b = GetNormal(uv1b);
		float3 normal2a = GetNormal(uv2a);
		float3 normal2b = GetNormal(uv2b);
		
		fixed4 col = tex2D(_MainTex, uv);
		fixed4 col0a = tex2D(_MainTex, uv0a);
		fixed4 col0b = tex2D(_MainTex, uv0b);
		fixed4 col1a = tex2D(_MainTex, uv1a);
		fixed4 col1b = tex2D(_MainTex, uv1b);
		fixed4 col2a = tex2D(_MainTex, uv2a);
		fixed4 col2b = tex2D(_MainTex, uv2b);
		
		half w = 0.37004405286;
		half w0a = CompareNormal(normal, normal0a) * 0.31718061674;
		half w0b = CompareNormal(normal, normal0b) * 0.31718061674;
		half w1a = CompareNormal(normal, normal1a) * 0.19823788546;
		half w1b = CompareNormal(normal, normal1b) * 0.19823788546;
		half w2a = CompareNormal(normal, normal2a) * 0.11453744493;
		half w2b = CompareNormal(normal, normal2b) * 0.11453744493;
		
		half3 result;
		result = w * col.rgb;
		result += w0a * col0a.rgb;
		result += w0b * col0b.rgb;
		result += w1a * col1a.rgb;
		result += w1b * col1b.rgb;
		result += w2a * col2a.rgb;
		result += w2b * col2b.rgb;
		
		result /= w + w0a + w0b + w1a + w1b + w2a + w2b;
		return fixed4(result, 1.0);
	}


    sampler2D _AOTex;
    fixed4 fragComposite(v2f i) : SV_Target
    {
        fixed4 col = tex2D(_MainTex, i.uv);
        fixed4 ao = tex2D(_AOTex, i.uv);
        col.rgb *= ao.r;
        return col;
    }
    
    ENDCG

    SubShader
    {
        Cull Off ZWrite Off ZTest Always
        Pass
        {
            CGPROGRAM
            #pragma vertex vertAO;
            #pragma fragment fragAO;
            ENDCG
        }
    	
    	Pass 
    	{
    		CGPROGRAM
    		#pragma vertex vertAO;
    		#pragma fragment frag_Blur;
    		ENDCG
		}
        
        Pass 
        {
            CGPROGRAM
            #pragma vertex vertAO
            #pragma fragment fragComposite
            ENDCG
        }
    }
}
