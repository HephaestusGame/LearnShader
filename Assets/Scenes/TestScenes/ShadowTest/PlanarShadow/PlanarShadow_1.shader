Shader "Learn/Shadow/PlanarShadow_1"
{
    SubShader
    {
        //老式写法，用于渲染阴影投射物自身，https://docs.unity3d.com/Manual/SL-Material.html
        Pass 
        {
            Tags { "LightMode" = "ForwardBase" }
            Material {Diffuse(1,1,1,1)}
            Lighting On   
        }
        
        //Shadow
        Pass 
        {
            Tags { "LightMode" = "ForwardBase" }
            Blend DstColor SrcColor
            //使渲染的像素更靠近摄像机
            Offset -1, -1
            
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"

            float4x4 _World2Ground;
            float4x4 _Ground2World;

            float4 vert(float4 vertex: POSITION) : SV_POSITION
            {
                float3 lightDir;
                lightDir = WorldSpaceLightDir(vertex);
                lightDir = mul(_World2Ground, float4(lightDir, 0)).xyz;
                lightDir = normalize(lightDir);

                float4 vt;
                vt = mul(unity_ObjectToWorld, vertex);
                vt = mul(_World2Ground, vt);
                vt.xz=vt.xz-(vt.y/lightDir.y)*lightDir.xz;
                //上面这行代码可拆解为如下的两行代码，这样子可能在进行三角形相似计算时更好理解
                //vt.x=vt.x-(vt.y/lightDir.y)*lightDir.x;
                //vt.z=vt.z-(vt.y/lightDir.y)*lightDir.z;
                // vt.y=0;

                vt = mul(_Ground2World, vt);
                vt = mul(unity_WorldToObject, vt);
                return UnityObjectToClipPos(vt);
            }

            float4 frag(void) : COLOR 
            {
                return float4(0.3,0.3,0.3,1);
            }
            
            ENDCG
        }     
    }
    FallBack "Diffuse"
}
