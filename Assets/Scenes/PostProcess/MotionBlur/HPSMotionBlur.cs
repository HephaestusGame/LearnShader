using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class HPSMotionBlur : MonoBehaviour
{
    public Shader motionBlurShader;
    public Material motionBlurMaterial;

    private Material m_Material
    {
        get
        {
            if (motionBlurShader.isSupported)
            {
                
            }

            return null;
        }
    }
    private void OnRenderImage(RenderTexture src, RenderTexture dest)
    {
        
        if (m_Material != null)
        {
            Graphics.Blit(src, dest, motionBlurMaterial);
        }
        else
        {
            Graphics.Blit(src, dest);
        }
    }
}
