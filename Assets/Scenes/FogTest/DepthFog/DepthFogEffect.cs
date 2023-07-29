using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Serialization;

namespace HephaestusGame
{
    [RequireComponent(typeof(Camera)), ExecuteInEditMode]
    public class DepthFogEffect : MonoBehaviour
    {
        public Color fogColor = Color.grey;
        public float start = 0;
        public float end = 100;
        public float worldPosScale = 1;
        public float noiseSpeedX = 1;
        public float noiseSpeedY = 1;
        public float noiseScale = 1;
        public Texture noiseTex;
        public enum DisType
        {
            VIEWSPACE = 0,
            WORLDSPACE
        }

        public enum CalFuncType
        {
            LINEAR = 0,
            EXP = 1,
            EXP2 = 2
        }

        public DisType disType = DisType.VIEWSPACE;
        [FormerlySerializedAs("calFuncTYpe")] public CalFuncType calFuncType = CalFuncType.LINEAR;
        [Range(0,1)]
        public float density = 0.3f;
        
        private Camera _camera;
        public Camera Camera
        {
            get
            {
                if (_camera == null)
                {
                    _camera = GetComponent<Camera>();
                }
                return _camera;
            }
        }

        public Material FogMaterial;

        private void OnEnable()
        {
            Camera.depthTextureMode |= DepthTextureMode.Depth;
        }

        private void OnRenderImage(RenderTexture source, RenderTexture destination)
        {
            if (FogMaterial == null)
            {
                Graphics.Blit(source, destination);
                return;
            }
            FogMaterial.SetFloat("_Start", start);
            FogMaterial.SetFloat("_End", end);
            FogMaterial.SetFloat("_Density", density);
            FogMaterial.SetFloat("_WorldPosScale", worldPosScale);
            FogMaterial.SetFloat("_NoiseSpeedX", noiseSpeedX);
            FogMaterial.SetFloat("_NoiseSpeedY", noiseSpeedY);
            FogMaterial.SetFloat("_NoiseScale", noiseScale);
            FogMaterial.SetTexture("_NoiseTex", noiseTex);
            FogMaterial.SetColor("_FogColor", fogColor);

            switch (disType)
            {
                case DisType.VIEWSPACE:
                    FogMaterial.EnableKeyword("_DIST_TYPE_VIEWSPACE");
                    FogMaterial.DisableKeyword("_DIST_TYPE_WORLDSPACE");
                    break;
                case DisType.WORLDSPACE:
                    FogMaterial.EnableKeyword("_DIST_TYPE_WORLDSPACE");
                    FogMaterial.DisableKeyword("_DIST_TYPE_VIEWSPACE");
                    break;
            }

            switch (calFuncType)
            {
                case CalFuncType.LINEAR:
                    FogMaterial.EnableKeyword("_FUNC_TYPE_LINEAR");
                    FogMaterial.DisableKeyword("_FUNC_TYPE_EXP");
                    FogMaterial.DisableKeyword("_FUNC_TYPE_EXP2");
                    break;
                case CalFuncType.EXP:
                    FogMaterial.EnableKeyword("_FUNC_TYPE_EXP");
                    FogMaterial.DisableKeyword("_FUNC_TYPE_LINEAR");
                    FogMaterial.DisableKeyword("_FUNC_TYPE_EXP2");
                    break;
                case CalFuncType.EXP2:
                    FogMaterial.EnableKeyword("_FUNC_TYPE_EXP2");
                    FogMaterial.DisableKeyword("_FUNC_TYPE_LINEAR");
                    FogMaterial.DisableKeyword("_FUNC_TYPE_EXP");
                    break;
            }
            Graphics.Blit(source, destination, FogMaterial);
        }
    }
}
