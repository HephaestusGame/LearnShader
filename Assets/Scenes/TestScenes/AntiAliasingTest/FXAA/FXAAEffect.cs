using System;
using System.Collections;
using System.Collections.Generic;
using Sirenix.OdinInspector;
using UnityEngine;

namespace HephaestusGame
{
    [ExecuteInEditMode, ImageEffectAllowedInSceneView]
    public class FXAAEffect : MonoBehaviour
    {
        public bool lowQuality;
        public bool gammaBlending;
        [Range(0.0312f, 0.0833f)]
        public float contrastThreshold = 0.0312f;
        [Range(0.063f, 0.333f)]
        public float relativeThreshold = 0.063f;
        [Range(0f, 1f)]
        public float subpixelBlending = 1f;
        [HideInInspector]
        public Shader fxaaShader;

        [NonSerialized]
        private Material fxaaMaterial;
        
        public enum LuminanceMode { Alpha, Green , Calculate }

        public LuminanceMode luminanceSource = LuminanceMode.Calculate;

        private const int LuminancePass = 0;
        private const int FxaaPass = 1;
        private void OnRenderImage(RenderTexture source, RenderTexture destination)
        {
            if (fxaaMaterial == null)
            {
                fxaaMaterial = new Material(fxaaShader);
                fxaaMaterial.hideFlags = HideFlags.HideAndDontSave;
            }
            
            fxaaMaterial.SetFloat("_ContrastThreshold", contrastThreshold);
            fxaaMaterial.SetFloat("_RelativeThreshold", relativeThreshold);
            fxaaMaterial.SetFloat("_SubpixelBlending", subpixelBlending);
            if (lowQuality)
            {
                fxaaMaterial.EnableKeyword("LOW_QUALITY");
            }
            else
            {
                fxaaMaterial.DisableKeyword("LOW_QUALITY");
            }
            
            if (gammaBlending) {
                fxaaMaterial.EnableKeyword("GAMMA_BLENDING");
            }
            else {
                fxaaMaterial.DisableKeyword("GAMMA_BLENDING");
            }

            
            if (luminanceSource == LuminanceMode.Calculate) {
                fxaaMaterial.DisableKeyword("LUMINANCE_GREEN");
                RenderTexture luminanceTex = RenderTexture.GetTemporary(
                    source.width, source.height, 0, source.format
                );
                Graphics.Blit(source, luminanceTex, fxaaMaterial, LuminancePass);
                Graphics.Blit(luminanceTex, destination, fxaaMaterial, FxaaPass);
                RenderTexture.ReleaseTemporary(luminanceTex);
            }
            else {
                if (luminanceSource == LuminanceMode.Green) {
                    fxaaMaterial.EnableKeyword("LUMINANCE_GREEN");
                }
                else {
                    fxaaMaterial.DisableKeyword("LUMINANCE_GREEN");
                }
                Graphics.Blit(source, destination, fxaaMaterial, FxaaPass);
            }
        }
    }
}
