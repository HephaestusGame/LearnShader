Shader "Unlit/RainOnScreen"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
    	_RainAmount("Rain Amount", Range(0, 1)) = 0.3
    	_MinBlur("Min Blur", Range(0, 2)) = 1
    	_MaxBlur("Max Blur", Range(3, 6)) = 3
    	_StaticRainDropSpeed("Static Rain Drop Speed", Range(0, 10)) = 0.2
    	_DynamicRainDropSpeed("Dynamic Rain Drop Speed", Range(0, 10)) = 0.2
    	
    	_DynamicRainGridX("Dynamic Rain Grid X", Range(1, 10)) = 6
    	_DynamicRainGridY("Dynamic Rain Grid Y", Range(1, 10)) = 1
    	_DynamiceLayer1Tiling("Dynamic Layer 1 Tiling", Range(0.1, 10)) = 1
    	_DynamiceLayer2Tiling("Dynamic Layer 2 Tiling", Range(0.1, 10)) = 1.85
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"
			#define S(a, b, t) smoothstep(a, b, t)

			sampler2D _MainTex;
            float4 _MainTex_ST;
            float _RainAmount, _MinBlur, _MaxBlur, _DynamicRainGridX, _DynamicRainGridY, _StaticRainDropSpeed, _DynamicRainDropSpeed;
            float _DynamiceLayer1Tiling, _DynamiceLayer2Tiling;
            
            float3 N13(float p) {
				//  from DAVE HOSKINS
				float3 p3 = frac(float3(p, p, p) * float3(.1031, .11369, .13787));
				p3 += dot(p3, p3.yzx + 19.19);
				return frac(float3((p3.x + p3.y)*p3.z, (p3.x + p3.z)*p3.y, (p3.y + p3.z)*p3.x));
			}

			float4 N14(float t) {
				return frac(sin(t*float4(123., 1024., 1456., 264.))*float4(6547., 345., 8799., 1564.));
			}
            
			float N(float t) {
				return frac(sin(t*12345.564)*7658.76);
			}

			float Saw(float b, float t) {
				return S(0., b, t)*S(1., b, t);
			}
            
            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
            };

            

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                return o;
            }

            float StaticDrops(float2 uv, float t) {
				uv *= 30.;

				float2 id = floor(uv);
				uv = frac(uv) - .5;
				float3 n = N13(id.x*107.45 + id.y*3543.654);
				float2 p = (n.xy - .5)*.7;
				float d = length(uv - p);

				float fade = Saw(.025, frac(t + n.z));
				float c = S(.3, 0., d)*frac(n.z*10.)*fade;
				return c;
			}

            float2 DropLayer2(float2 uv, float t) {
				float2 UV = uv;

				uv.y += t*0.75;
				float2 a = float2(_DynamicRainGridX, _DynamicRainGridY);
				float2 grid = a*2.;
            	
				float2 id = floor(uv*grid);
				float colShift = N(id.x);
				uv.y += colShift;

				float2 st = frac(uv*grid) - float2(.5, 0);

            	id = floor(uv*grid);
            	float3 n = N13(id.x*35.2 + id.y*2376.1);
				float x = n.x - .5;
				float y = UV.y*20.;
            	// return x;
				float wiggle = sin(y + sin(y));
            	// return  wiggle;
            	// return wiggle*(.5 - abs(x));
            	// return wiggle*(.5 - abs(x))*(n.z - .5);
				x += wiggle*(.5 - abs(x))*(n.z - .5);
            	
				x *= .7;
            	// return x;
				float ti = frac(t + n.z);
				y = (Saw(.85, ti) - .5)*.9 + .5;
            	// return  y;
				float2 p = float2(x, y);
            	// return p;
				float d = length((st - p)*a.yx);
				// return d;
				float mainDrop = S(.4, .0, d);
				// return mainDrop;

            	
				float r = sqrt(S(1., y, st.y));
				float cd = abs(st.x - x);
				float trail = S(.23*r, .15*r*r, cd);
				float trailFront = S(-.02, .02, st.y - y);
				trail *= trailFront*r*r;
            	// return trail;

				y = UV.y;
				float trail2 = S(.2*r, .0, cd);
				float droplets = max(0., (sin(y*(1. - y)*120.) - st.y))*trail2*trailFront*n.z;
            	// return droplets;
				y = frac(y*10.) + (st.y - .5);
				float dd = length(st - float2(x, y));
				droplets = S(.3, 0., dd);
            	// return droplets*r*trailFront;
				float m = mainDrop + droplets*r*trailFront;

				return float2(m, trail);
			}

            float2 Drops(float2 uv, float l0, float l1, float l2) {
                float staticRainDropTime = _Time.y * _StaticRainDropSpeed;
            	float dynamicRainDropTime = _Time.y * _DynamicRainDropSpeed;
				float s = StaticDrops(uv, staticRainDropTime)*l0;
				float2 m1 = DropLayer2(uv * _DynamiceLayer1Tiling, dynamicRainDropTime)*l1;
				float2 m2 = DropLayer2(uv* _DynamiceLayer2Tiling, dynamicRainDropTime)*l2;

            	//融合静态雨滴和流动雨滴的厚度
				float c = s + m1.x + m2.x;
				c = S(.3, 1., c);

            	//x 表示雨滴厚度，y 表示动态雨水拖尾 Intensity
				return float2(c, max(m1.y*l0, m2.y*l1));
			}

            fixed4 frag (v2f i) : SV_Target
            {
                float2 uv = ((i.uv * _ScreenParams.xy) - .5*_ScreenParams.xy) / _ScreenParams.y;
            	// return float4(frac(uv * 30) - .5, 0, 0);
				float2 UV = i.uv.xy;

               
                float rainAmount = _RainAmount;
                float maxBlur = lerp(3, _MaxBlur, rainAmount);
				float minBlur = _MinBlur;

                float staticDrops = smoothstep(-.5, 1., rainAmount) * 2;
                float layer1 = smoothstep(.25, .75, rainAmount);
                float layer2 = smoothstep(.0, .5, rainAmount);

            	//x 表示雨滴厚度，y 表示动态雨水拖尾 Intensity
            	float2 c = Drops(uv, staticDrops, layer1, layer2);

            	// return float4(DropLayer2(uv, _Time.y * 0.2), 0, 0);

            	//求出 uv 方向水珠厚度的变化率
            	float2 e = float2(.001, 0.);
				float cx = Drops(uv + e, staticDrops, layer1, layer2).x;
				float cy = Drops(uv + e.yx, staticDrops, layer1, layer2).x;
				float2 n = float2(cx - c.x, cy - c.x);

            	//水滴越厚，越清晰，拖尾 Intensity 越大，越清晰
				float focus = lerp(maxBlur - c.y, minBlur, S(.1, .2, c.x));
            	float4 texCoord = float4(UV.x + n.x, UV.y + n.y, 0, focus);
				float4 lod = tex2Dlod(_MainTex, texCoord);
				float3 col = lod.rgb;

            	
            	return float4(col, 1);
            }
            ENDCG
        }
    }
}
