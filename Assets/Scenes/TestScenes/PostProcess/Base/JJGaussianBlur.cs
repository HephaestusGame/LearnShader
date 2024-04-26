using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[ExecuteInEditMode]
[RequireComponent (typeof(Camera))]
public class JJGaussianBlur : MonoBehaviour
{
    public Shader gaussianBlurShader;

    [Range(1, 8)]
    public int iterations = 3;
    [Range(1, 10)]
    public int downSample = 2; 
    [Range(0.2f, 3.0f)]
    public float blurSpread = 0.6f;
    
    private Material m_gaussianBlurMaterial;
    public Material gaussianBlurMaterial
    {
        get
        {
            if (gaussianBlurShader != null && gaussianBlurShader.isSupported)
            {
                if (m_gaussianBlurMaterial == null)
                {
                    m_gaussianBlurMaterial = new Material(gaussianBlurShader);
                    // m_gaussianBlurMaterial.hideFlags = HideFlags.HideAndDontSave;
                }
                return m_gaussianBlurMaterial;
            }

            return null;
        }
    }

    private void OnRenderImage(RenderTexture src, RenderTexture dest)
    {
        if (gaussianBlurMaterial != null)
        {
            int rtW = src.width / downSample;
            int rtH = src.height / downSample;
            RenderTexture buffer0 = RenderTexture.GetTemporary(rtW, rtH, 0);
            buffer0.filterMode = FilterMode.Bilinear;
            Graphics.Blit(src, buffer0);
            for (int i = 0; i < iterations; i++)
            {
                gaussianBlurMaterial.SetFloat("_BlurSize", 1 + i * blurSpread);

                RenderTexture buffer1 = RenderTexture.GetTemporary(rtW, rtH, 0);
                Graphics.Blit(buffer0, buffer1, gaussianBlurMaterial, 0);
                RenderTexture.ReleaseTemporary(buffer0);
                buffer0 = buffer1;
            
                buffer1 = RenderTexture.GetTemporary(rtW, rtH, 0);
                Graphics.Blit(buffer0, buffer1, gaussianBlurMaterial, 1);
                RenderTexture.ReleaseTemporary(buffer0);
                buffer0 = buffer1;
            }
        
            Graphics.Blit(buffer0, dest);
            RenderTexture.ReleaseTemporary(buffer0);
        }
        else
        {
            Graphics.Blit(src,dest);
        }
    }
}
