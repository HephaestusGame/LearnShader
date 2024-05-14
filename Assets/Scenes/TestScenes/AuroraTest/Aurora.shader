Shader "Custom/Enviroment/Aurora"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _SkyColor ("Sky Color", Color) = (1,1,1,1)
        _SkylineColor ("Skyline Color", Color) = (1,1,1,1)
        _GroundColor ("Color 3", Color) = (1,1,1,1)
        _BaseColorIntensity ("Base Color Intensity", Range(0, 1)) = 1
        
        _StarIntensity ("Star Intensity", Range(0, 1)) = 1
        _StarSpeed ("Star Speed", Range(0, 1)) = 1
        _StarCount("Star Count", Range(1, 512)) = 32
        _StarColor("Star Color", Color) = (1,1,1,1)
        
        _AuroraSpeed("Aurora Speed", Range(0, 1)) = 1
        _SurAuroraColFactor("Sur Aurora Color Factor", Range(0, 1)) = 1
        [HDR]_AuroraColor("Aurora Color", Color) = (2.15,-.5, 1.2, 1)
        
        _RayMarchingMaxStep("Ray Marching Max Step", Range(1, 100)) = 30
        
        _RayMarchingDistance("Ray Marching Distance", Range(0, 100)) = 30
        _AurorasTiling("Auroras Tiling", Range(0, 100)) = 1
        _SkyCurvature("Sky Curvature", Range(0, 100)) = 1
        _AurorasNoiseTex("Auroras Noise Texture", 2D) = "black" {}
        _AuroraAttenuation("Aurora Attenuation", Range(0, 1)) = 1
    }
    SubShader
    {
        Tags { 
            "RenderType"="Background" 
            "Queue" = "Background"
        }
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float3 uv : TEXCOORD0;
            };

            struct v2f
            {
                float3 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;

            float4 _SkyColor, _SkylineColor, _GroundColor;
            float _BaseColorIntensity;

            float _AuroraSpeed, _SurAuroraColFactor, _RayMarchingMaxStep;
            float4 _AuroraColor;

            float _SkyCurvature, _AurorasTiling, _RayMarchingDistance, _AuroraAttenuation;
            sampler2D _AurorasNoiseTex;
            float4 _AurorasNoiseTex_ST;
            
            //Star
            float4 _StarColor;
            float _StarIntensity, _StarSpeed, _StarCount;

            // 星空散列哈希
            float StarAuroraHash(float3 x) {
	            float3 p = float3(dot(x,float3(214.1 ,127.7,125.4)),
			                dot(x,float3(260.5,183.3,954.2)),
                            dot(x,float3(209.5,571.3,961.2)) );

	            return -0.001 + _StarIntensity * frac(sin(p)*43758.5453123);
            }

            // 星空噪声
            float StarNoise(float3 st){
                // 卷动星空
                st += float3(0,_Time.y * _StarSpeed,0);

                // fbm
                float3 i = floor(st);
                float3 f = frac(st);
            
	            float3 u = f*f*(3.0-1.0*f);

                return lerp(lerp(dot(StarAuroraHash( i + float3(0.0,0.0,0.0)), f - float3(0.0,0.0,0.0) ), 
                                 dot(StarAuroraHash( i + float3(1.0,0.0,0.0)), f - float3(1.0,0.0,0.0) ), u.x),
                            lerp(dot(StarAuroraHash( i + float3(0.0,1.0,0.0)), f - float3(0.0,1.0,0.0) ), 
                                 dot(StarAuroraHash( i + float3(1.0,1.0,0.0)), f - float3(1.0,1.0,0.0) ), u.y), u.z) ;
            }

            //极光噪声
            float AuroraHash(float n ) { 
                return frac(sin(n)*758.5453); 
            }

            float AuroraNoise(float3 x)
            {
                float3 p = floor(x);
                float3 f = frac(x);
                float n = p.x + p.y*57.0 + p.z*800.0;
                float res = lerp(lerp(lerp( AuroraHash(n+  0.0), AuroraHash(n+  1.0),f.x), lerp( AuroraHash(n+ 57.0), AuroraHash(n+ 58.0),f.x),f.y),
	    	            lerp(lerp( AuroraHash(n+800.0), AuroraHash(n+801.0),f.x), lerp( AuroraHash(n+857.0), AuroraHash(n+858.0),f.x),f.y),f.z);
                return res;
            }
   

            float2x2 RotateMatrix(float a){
                float c = cos(a);
                float s = sin(a);
                return float2x2(c,s,-s,c);
            }

            float tri(float x){
                return clamp(abs(frac(x)-0.5),0.01,0.49);
            }

            float2 tri2(float2 p){
                return float2(tri(p.x)+tri(p.y),tri(p.y+tri(p.x)));
            }

            // 极光噪声
            float SurAuroraNoise(float2 pos)
            {
                float intensity=1.8;
                float size=2.5;
    	        float rz = 0;
                pos = mul(RotateMatrix(pos.x*0.06),pos);
                float2 bp = pos;
    	        for (int i=0; i<5; i++)
    	        {
                    float2 dg = tri2(bp*1.85)*.75;
                    dg = mul(RotateMatrix(_Time.y*_AuroraSpeed),dg);
                    pos -= dg/size;

                    bp *= 1.3;
                    size *= .45;
                    intensity *= .42;
    		        pos *= 1.21 + (rz-1.0)*.02;

                    rz += tri(pos.x+tri(pos.y))*intensity;
                    pos = mul(-float2x2(0.95534, 0.29552, -0.29552, 0.95534),pos);
    	        }
                return clamp(1.0/pow(rz*29., 1.3),0,0.55);
            }

             float SurHash(float2 n){
                 return frac(sin(dot(n, float2(12.9898, 4.1414))) * 43758.5453); 
            }

            float4 SurAurora(float3 pos,float3 ro)
            {
                float4 col = float4(0,0,0,0);
                float4 avgCol = float4(0,0,0,0);

                // 逐层
                for(int i=0;i<_RayMarchingMaxStep;i++)
                {
                    // 坐标
                    float of = 0.006*SurHash(pos.xy)*smoothstep(0,15, i);       
                    float pt = ((0.8+pow(i,1.4)*0.002)-ro.y)/(pos.y*2.0+0.8);
                    pt -= of;
        	        float3 bpos = ro + pt*pos;
                    float2 p = bpos.zx;

                    // 颜色
                    float noise = SurAuroraNoise(p);
                    float4 col2 = float4(0,0,0, noise);
                    col2.rgb = (sin(1.0- 6 * _AuroraColor.rgb+i*_SurAuroraColFactor*0.1)*0.5+0.5)*noise;
                    avgCol =  lerp(avgCol, col2, 0.5);
                    col += avgCol*exp2(-i*0.065 - 2.5)*smoothstep(0.,5., i);

                }

                col *= (clamp(pos.y*15.+.4,0.,1.));

                return col*1.8;

            }

            //带状极光
            float4 GetAuroraWithRunTimeNoise(float3 uv)
            {
                return smoothstep(
                    0.0,
                    1.5,
                    SurAurora(float3(uv.x,abs(uv.y),uv.z),float3(0,0,-6.7))) ;
            }

            float4 GetAuroraWithNoiseTex(float3 rayDir)
            {
                rayDir = normalize(rayDir);
                // 天空曲率
                float skyCurvatureFactor = rcp(rayDir.y + _SkyCurvature);
                // 本质为模拟地球大气
                // 无数条射线像外发射 就会形成一个球面 *天空曲率 就可以把它拍成一个球
                float3 basicRayPlane = rayDir * skyCurvatureFactor * _AurorasTiling * 0.01;
                // 从哪开始步进
                float3 rayMarchBegin = basicRayPlane;
                
                float4 aurora;
                float3 color = 0;
                float3 avgColor = 0;
                float stepSize = rcp(_RayMarchingMaxStep);
                for(int i = 0; i < _RayMarchingMaxStep; i += 1)
                {
                    float curStep = stepSize * i;
                    // 初始的几次采样贡献更大, 我们用二次函数着重初始采样
                    curStep = curStep * curStep;
                    // 当前步进距离
                    float curDistance = curStep * _RayMarchingDistance * 0.01;
                    // 步进后的位置
                    float3 curPos = rayMarchBegin + rayDir * curDistance * skyCurvatureFactor;
                    float2 uv = float2(curPos.x,curPos.z);

                     // =====  极光动起来
                    // 计算扰动uv
                    float2 warp_vec = tex2D(_AurorasNoiseTex,TRANSFORM_TEX((uv * 2 + _Time.y * _AuroraSpeed),_AurorasNoiseTex));
                    // 采样当前的噪声强度
                    float curNoise = tex2D(_MainTex, TRANSFORM_TEX((uv + warp_vec * 0.1), _MainTex)).r;
                    // =======================

                    // 最后加强度衰减
                    curNoise = curNoise * saturate(1 - pow(curDistance, 1 - _AuroraAttenuation));

                    // 极光色彩累积计算
                    // 由于sin的范围是-1到1，所以要先把颜色范围转换到-1到1之间，这通过i计算出当前步进层的色彩
                    // 最后 * 0.5再加0.5就返回到了原本的0-1的范围区间
                    float3 curColor = sin((_AuroraColor * 2 - 1) + i * 0.043) * 0.5 + 0.5;

                    // 取两步色彩的平均值 使颜色更接近于本色 
                    avgColor = (avgColor + curColor) / 2;

                    // 混合颜色
                    color += avgColor * curNoise * stepSize;
                }

                return float4(color,1);
            }

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                //sky color
                float p = normalize(i.uv).y;
                float p1 = 1.0f - pow (min (1.0f, 1.0f - p), 20);
                float p3 = 1.0f - pow (min (1.0f, 1.0f + p), 30);
                float p2 = 1.0f - p1 - p3;
                float4 skyCol = (_SkyColor * p1 + _SkylineColor * p2 + _GroundColor * p3) * _BaseColorIntensity;

                //star
                float inSky = step(0, i.uv.y);
                float star = StarNoise(float3(i.uv.x, i.uv.y, i.uv.z) * _StarCount);
                star = smoothstep(0.81,0.98,star) * inSky;
                float4 starCol = fixed4((_StarColor * star).rgb,star);

                skyCol += starCol;

                //Aurora
                float4 surAuroraCol = GetAuroraWithRunTimeNoise(i.uv) * inSky;
                // float4 surAuroraCol = GetAuroraWithNoiseTex(i.uv) * inSky;
                skyCol = lerp(skyCol, surAuroraCol * 0.9, surAuroraCol.a);
                return skyCol;
                return skyCol + starCol;
            }
            ENDCG
        }
    }
}
