using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace HephaestusGame
{
    public class BloomTest : PostEffectsBase
    {
        [Range(0, 4)]
        public int iterations = 3;
        [Range(1, 8)] 
        public int downSample = 2;
        [Range(0.2f, 3.0f)]
        public float blurSpread = 0.6f;

        [Range(0.0f, 4.0f)]
        public float luminanceThreshold = 0.6f;
        
        public Shader bloomShader;
        private Material bloomMaterial;

        private Material material
        {
            get
            {
                bloomMaterial = CheckShaderAndCreateMaterial(bloomShader, bloomMaterial);
                return bloomMaterial;
            }
        }
        
        private void OnRenderImage(RenderTexture src, RenderTexture dest)
        {
            if (material != null)
            {
                material.SetFloat("_LuminanceThreshold", luminanceThreshold);
                int rtW = src.width / downSample;
                int rtH = src.height / downSample;

                RenderTexture buffer0 = RenderTexture.GetTemporary(rtW, rtH, 0);
                buffer0.filterMode = FilterMode.Bilinear;
                
                Graphics.Blit(src, buffer0, material, 0);//提取亮部

                for (int i = 0; i < iterations; i++)
                {
                    material.SetFloat("_BlurSize", 1.0f + i * blurSpread);//模糊范围
                    RenderTexture buffer1 = RenderTexture.GetTemporary(rtW, rtH, 0);
                    Graphics.Blit(buffer0, buffer1, material, 1);
                
                    RenderTexture.ReleaseTemporary(buffer0);
                    buffer0 = RenderTexture.GetTemporary(rtW, rtH, 0);
                    Graphics.Blit(buffer1, buffer0, material, 2);
                    
                    RenderTexture.ReleaseTemporary(buffer1);
                }
                
                material.SetTexture("_Bloom", buffer0);
                Graphics.Blit(src, dest, material, 3);
                RenderTexture.ReleaseTemporary(buffer0);
            }
            else
            {
                Graphics.Blit(src, dest);
            }
        }
    }
}
 