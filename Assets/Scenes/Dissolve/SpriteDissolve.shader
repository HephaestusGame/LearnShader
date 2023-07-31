// Unity built-in shader source. Copyright (c) 2016 Unity Technologies. MIT license (see license.txt)

Shader "Learn/Dissolve/SpriteDissolve"
{
    Properties
    {
        [PerRendererData] _MainTex ("Sprite Texture", 2D) = "white" {}
        _DissolveTex("Dissolve Texture", 2D) = "white" {}
        _Color ("Tint", Color) = (1,1,1,1)
        _DissolveThreshold("Dissolve Threshold", Range(0, 1)) = 0
        _DissolveDir("Dissolve Direction", Vector) = (1, 1, 1, 1)
        [MaterialToggle] PixelSnap ("Pixel snap", Float) = 0
        [HideInInspector] _RendererColor ("RendererColor", Color) = (1,1,1,1)
        [HideInInspector] _Flip ("Flip", Vector) = (1,1,1,1)
        [PerRendererData] _AlphaTex ("External Alpha", 2D) = "white" {}
        [PerRendererData] _EnableExternalAlpha ("Enable External Alpha", Float) = 0
    }

    SubShader
    {
        Tags
        {
            "Queue"="Transparent"
            "IgnoreProjector"="True"
            "RenderType"="Transparent"
            "PreviewType"="Plane"
            "CanUseSpriteAtlas"="True"
        }

        Cull Off
        Lighting Off
        ZWrite Off
        Blend One OneMinusSrcAlpha

        Pass
        {
        CGPROGRAM
            #pragma vertex SpriteDissolveVert
            #pragma fragment SpriteDissolveFrag
            #pragma target 2.0
            #pragma multi_compile_instancing
            #pragma multi_compile_local _ PIXELSNAP_ON
            #pragma multi_compile _ ETC1_EXTERNAL_ALPHA
            #include "UnitySprites.cginc"

            sampler2D _DissolveTex;
            float4 _DissolveTex_ST;
            float _DissolveThreshold;
            float4 _DissolveDir;

            struct v2fDissolve
            {
                float4 vertex   : SV_POSITION;
                fixed4 color    : COLOR;
                float2 texcoord : TEXCOORD0;
                float worldFactor : TEXCOORD1;
                UNITY_VERTEX_OUTPUT_STEREO
            };
        
            v2fDissolve SpriteDissolveVert(appdata_t IN)
            {
                v2fDissolve OUT;

                UNITY_SETUP_INSTANCE_ID (IN);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(OUT);

                OUT.vertex = UnityFlipSprite(IN.vertex, _Flip);
                
                float3 vertWorldPos = mul(unity_ObjectToWorld, OUT.vertex);
                float3 centroidWorldPos = float3(unity_ObjectToWorld[0].w, unity_ObjectToWorld[1].w, unity_ObjectToWorld[2].w);//由矩阵的定义可知这三个分量组成了当前渲染物体的质心的世界坐标
                OUT.worldFactor = dot(normalize(_DissolveDir.xyz), vertWorldPos - centroidWorldPos);//计算当前质心到当前顶点的向量到溶解方向的投影，沿着投影方向的顶点溶解值会增加，从而晚一点溶解
                
                OUT.vertex = UnityObjectToClipPos(OUT.vertex);
                OUT.texcoord = IN.texcoord;
                OUT.color = IN.color * _Color * _RendererColor;

                
               
                #ifdef PIXELSNAP_ON
                OUT.vertex = UnityPixelSnap (OUT.vertex);
                #endif
            
                return OUT;
            }
        
            fixed4 SpriteDissolveFrag(v2fDissolve IN) : SV_Target
            {
                float2 dissolveUV = TRANSFORM_TEX(IN.texcoord, _DissolveTex);
                fixed dissolveColor = tex2D(_DissolveTex, dissolveUV).r;
                clip(dissolveColor - _DissolveThreshold + IN.worldFactor);
                fixed4 c = SampleSpriteTexture (IN.texcoord) * IN.color;
                c.rgb *= c.a;
                return c;
            }
        ENDCG
        }
    }
}
