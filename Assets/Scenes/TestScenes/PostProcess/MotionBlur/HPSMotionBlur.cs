using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class HPSMotionBlur : MonoBehaviour
{
    public Shader motionBlurShader;
    [Range(0, 0.9f)]
    public float blurAmount = 0.5f;
    private Material motionBlurMaterial;
    private RenderTexture accumulationTexture;

    private void OnDisable()
    {
        DestroyImmediate(accumulationTexture);
    }

    private Material material
    {
        get
        {
            if (motionBlurMaterial == null && motionBlurShader.isSupported)
            {
                motionBlurMaterial = new Material(motionBlurShader);
            }

            return motionBlurMaterial;
        }
    }
    private void OnRenderImage(RenderTexture src, RenderTexture dest)
    {
        
        if (material != null)
        {
            if (accumulationTexture == null || accumulationTexture.width != src.width ||
                accumulationTexture.height != src.height)
            {
                //depth表示深度缓冲的位数，只可以是0，16，24，只有24位才有模板缓冲 https://docs.unity3d.com/ScriptReference/RenderTexture-ctor.html
                accumulationTexture = new RenderTexture(src.width, src.height, 0);
                accumulationTexture.hideFlags = HideFlags.HideAndDontSave;
                Graphics.Blit(src, accumulationTexture);
            }
            
            //因为需要把当前帧图像和accumulationTexture叠加，所以给accumulationTexture标记恢复操作（发生在渲染到纹理而该纹理又没有被提前清空或销毁的情况下）
            //也就是保留前面一帧的图像
            accumulationTexture.MarkRestoreExpected();
            material.SetFloat("_BlurAmount", blurAmount);
            Graphics.Blit(src, accumulationTexture, material);
            Graphics.Blit(accumulationTexture, dest);
        }
        else
        {
            Graphics.Blit(src, dest);
        }
    }
}
