using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Serialization;


[ExecuteInEditMode]
[RequireComponent (typeof(Camera))]
public class JJBloom : MonoBehaviour
{
    public Shader bloomShader;

    [Range(1, 8)]
    public int iterations = 3;
    [Range(1, 10)]
    public int downSample = 2; 
    [Range(0.2f, 3.0f)]
    public float blurSpread = 0.6f;
    [Range(0, 4)]
    public float luminanceThreshold = 0.6f;
    
    private Material m_bloomMaterial;
    public Material bloomMaterial
    {
        get
        {
            if (bloomShader != null && bloomShader.isSupported)
            {
                if (m_bloomMaterial == null)
                {
                    m_bloomMaterial = new Material(bloomShader);
                    // m_gaussianBlurMaterial.hideFlags = HideFlags.HideAndDontSave;
                }
                return m_bloomMaterial;
            }

            return null;
        }
    }

    private void OnRenderImage(RenderTexture src, RenderTexture dest)
    {
        if (bloomMaterial != null)
        {
            bloomMaterial.SetFloat("_LuminanceThreshold", luminanceThreshold);
            int rtW = src.width / downSample;
            int rtH = src.height / downSample;
            
            RenderTexture buffer0 = RenderTexture.GetTemporary(rtW, rtH, 0);
            buffer0.filterMode = FilterMode.Bilinear;
            
            Graphics.Blit(src, buffer0, bloomMaterial, 0);
            
            for (int i = 0; i < iterations; i++)
            {
                bloomMaterial.SetFloat("_BlurSize", 1 + i * blurSpread);

                RenderTexture buffer1 = RenderTexture.GetTemporary(rtW, rtH, 0);
                Graphics.Blit(buffer0, buffer1, bloomMaterial, 1);
                RenderTexture.ReleaseTemporary(buffer0);
                buffer0 = buffer1;
            
                buffer1 = RenderTexture.GetTemporary(rtW, rtH, 0);
                Graphics.Blit(buffer0, buffer1, bloomMaterial, 2);
                RenderTexture.ReleaseTemporary(buffer0);
                buffer0 = buffer1;
            }
        
            bloomMaterial.SetTexture("_Bloom", buffer0);
            Graphics.Blit(src, dest, bloomMaterial, 3);
            RenderTexture.ReleaseTemporary(buffer0);
        }
        else
        {
            Graphics.Blit(src,dest);
        }
    }
}
