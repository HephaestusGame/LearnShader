using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Serialization;

[RequireComponent(typeof(Camera)), ExecuteInEditMode]
public class HeightFogEffect : MonoBehaviour
{
    public Color fogColor = Color.grey;
        [FormerlySerializedAs("start")] public float heightStart = 0;
        [FormerlySerializedAs("end")] public float heightEnd = 100;
        public float worldPosScale = 1;
        public float noiseSpeedX = 1;
        public float noiseSpeedY = 1;
        public float noiseScale = 1;
        public Texture noiseTex;
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
            FogMaterial.SetFloat("_HeightStart", heightStart);
            FogMaterial.SetFloat("_HeightEnd", heightEnd);
            FogMaterial.SetFloat("_Density", density);
            FogMaterial.SetFloat("_WorldPosScale", worldPosScale);
            FogMaterial.SetFloat("_NoiseSpeedX", noiseSpeedX);
            FogMaterial.SetFloat("_NoiseSpeedY", noiseSpeedY);
            FogMaterial.SetFloat("_NoiseScale", noiseScale);
            FogMaterial.SetTexture("_NoiseTex", noiseTex);
            FogMaterial.SetColor("_FogColor", fogColor);

            Graphics.Blit(source, destination, FogMaterial);
        }
}
