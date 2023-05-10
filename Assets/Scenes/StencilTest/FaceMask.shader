Shader "Unlit/FaceMask"
{
    Properties
    {
        _ID("Mask ID", Int) = 1
        [Enum(UnityEngine.Rendering.CompareFunction)] _SComp("Stencil Comp", Float) = 8
        [Enum(UnityEngine.Rendering.StencilOp)] _SOp("Stencil Op", Float) = 2
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" "Queue" = "Geometry+1"}
        ZWrite off
        ColorMask 0
        Stencil 
        {
            Ref[_ID]
            Comp[_SComp]
            Pass[_SOp]
        }
        Pass
        {
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
                UNITY_FOG_COORDS(1)
                float4 vertex : SV_POSITION;
            };


            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
               return fixed4(1, 1, 1, 1);
            }
            ENDCG
        }
    }
}
