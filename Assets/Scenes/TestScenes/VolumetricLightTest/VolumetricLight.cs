using System;
using System.Collections;
using System.Collections.Generic;
using UnityEditor;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Serialization;

namespace HephaestusGame
{
    [RequireComponent(typeof(Light))]
    public class VolumetricLight : MonoBehaviour
    {
        public enum DitherType
        {
            None,
            Dither_4x4,
            Dither_8x8
        }
        
        public DitherType ditherType = DitherType.None;
        public Texture3D noiseTexture;

        [Range(1, 64)]
        public int sampleCount = 8;
        [Range(0.0f, 1.0f)]
        public float scatteringCoef = 0.5f;
        [Range(0.0f, 0.1f)]
        public float extinctionCoef = 0.01f;
        [Range(0.0f, 1.0f)]
        public float skyboxExtinctionCoef = 0.9f;
        [Range(0.0f, 0.999f)]
        public float mieG = 0.1f;
        public float groundLevel = 0;
        [Range(0.0f, 100.0f)]
        public float intensityScale = 1;
        public bool noise = false;
        public float noiseScale = 0.015f;
        public float noiseIntensity = 1.0f;
        public float noiseIntensityOffset = 0.3f;
        public Vector2 noiseVelocity = new Vector2(3.0f, 3.0f);
        public float maxRayLength = 400.0f;   
        
        public Texture2D ditheringTexture4X4;
        public Texture2D ditheringTexture8X8;
        private Light _sourceLight;
        private Material _volumetricLightMat;
        private RenderTexture _volumetricLightRT;

        private CommandBuffer _commandBuffer;
        private CommandBuffer _cascadeShadowMapCmdBuffer;
        private void Start()
        {
            _sourceLight = GetComponent<Light>();
            
            Shader volumetricLightShader = Shader.Find("Learn/VolumetricLight");
            _volumetricLightMat = new Material(volumetricLightShader);
            
            _volumetricLightRT = RenderTexture.GetTemporary(Screen.width, Screen.height, 0, RenderTextureFormat.Default, RenderTextureReadWrite.Linear);

            //Render CMD
            _commandBuffer = new CommandBuffer();
            _commandBuffer.name = "VolumetricLight";
            _sourceLight.AddCommandBuffer(LightEvent.BeforeScreenspaceMask, _commandBuffer);
            
            //获取 CascadeShadowMap
            _cascadeShadowMapCmdBuffer = new CommandBuffer();
            _cascadeShadowMapCmdBuffer.name = "CascadeShadowMap";
            _cascadeShadowMapCmdBuffer.SetGlobalTexture("_CascadeShadowMapTexture", new RenderTargetIdentifier(BuiltinRenderTextureType.CurrentActive));
            _sourceLight.AddCommandBuffer(LightEvent.AfterShadowMap, _cascadeShadowMapCmdBuffer);

            GenerateDitherTexture();
        }

        private void OnEnable()
        {
            VolumetricLightRenderer.OnPreRenderEvent += VolumetricLightRendererPreRenderEvent;
        }

        private void OnDisable()
        {
            VolumetricLightRenderer.OnPreRenderEvent -= VolumetricLightRendererPreRenderEvent;
        }

        private readonly int _inverseProjectionMatrixID = Shader.PropertyToID("_InverseProjectionMatrix");
        private readonly int _inverseViewMatrixID = Shader.PropertyToID("_InverseViewMatrix");
        private readonly int _sampleCountID = Shader.PropertyToID("_SampleCount");
        private readonly int _noiseVelocityID = Shader.PropertyToID("_NoiseVelocity");
        private readonly int _noiseDataID = Shader.PropertyToID("_NoiseData");
        private readonly int _mieGID = Shader.PropertyToID("_MieG");
        private readonly int _volumetricLightID = Shader.PropertyToID("_VolumetricLight");
        private readonly int _intensityScaleID = Shader.PropertyToID("_IntensityScale");
        private void VolumetricLightRendererPreRenderEvent(VolumetricLightRenderer renderer, Camera camera)
        {
            if (_sourceLight == null || _sourceLight.gameObject == null)
            {
                VolumetricLightRenderer.OnPreRenderEvent -= VolumetricLightRendererPreRenderEvent;
                return;
            }

            if (!_sourceLight.gameObject.activeInHierarchy || _sourceLight.enabled == false)
            {
                return;
            }
            
            
            Matrix4x4 projectionMatrix = GL.GetGPUProjectionMatrix(camera.projectionMatrix, false);
            _volumetricLightMat.SetMatrix(_inverseProjectionMatrixID, projectionMatrix.inverse);
            _volumetricLightMat.SetMatrix(_inverseViewMatrixID, camera.cameraToWorldMatrix);
            
            _volumetricLightMat.SetInt(_sampleCountID, sampleCount);
            _volumetricLightMat.SetVector(_noiseVelocityID, new Vector4(noiseVelocity.x, noiseVelocity.y) * noiseScale);
            _volumetricLightMat.SetVector(_noiseDataID, new Vector4(noiseScale, noiseIntensity, noiseIntensityOffset));
            _volumetricLightMat.SetVector(_mieGID, new Vector4(1 - mieG * mieG, 1 + mieG * mieG, 2 * mieG, 1.0f / (4.0f * Mathf.PI)));
            _volumetricLightMat.SetVector(_volumetricLightID, new Vector4(scatteringCoef, extinctionCoef, _sourceLight.range, 1.0f - skyboxExtinctionCoef));
            _volumetricLightMat.SetFloat(_intensityScaleID, intensityScale);

            SetupDirectionalLight(renderer);
        }

        
        private readonly int _lightDirID = Shader.PropertyToID("_LightDir");
        private readonly int _lightColorID = Shader.PropertyToID("_LightColor");
        private readonly int _maxRayLengthID = Shader.PropertyToID("_MaxRayLength");
        private void SetupDirectionalLight(VolumetricLightRenderer renderer)
        {
            _commandBuffer.Clear();
            if (noise)
            {
                _volumetricLightMat.SetTexture(_noiseTextureID, noiseTexture);
                _volumetricLightMat.EnableKeyword("NOISE");
            }
            else
            {
                _volumetricLightMat.DisableKeyword("NOISE");
            }

            UpdateDitherTexture();
            
            _volumetricLightMat.SetVector(_lightDirID, 
                new Vector4(
                    _sourceLight.transform.forward.x, 
                    _sourceLight.transform.forward.y, 
                    _sourceLight.transform.forward.z, 
                    1.0f / (_sourceLight.range * _sourceLight.range)));
            
            _volumetricLightMat.SetColor(_lightColorID, _sourceLight.color * _sourceLight.intensity);
            _volumetricLightMat.SetFloat(_maxRayLengthID, maxRayLength);
            RenderTexture lightBuffer = renderer.GetVolumeLightBuffer();
            _commandBuffer.SetRenderTarget(lightBuffer);
            _commandBuffer.ClearRenderTarget(false, true, Color.black);
            _commandBuffer.Blit(null, renderer.GetVolumeLightBuffer(), _volumetricLightMat, 0);
        }

        
        private readonly int _ditherTextureID = Shader.PropertyToID("_DitherTexture");
        private readonly int _noiseTextureID = Shader.PropertyToID("_NoiseTexture");
        private void UpdateDitherTexture()
        {
            if (ditherType == DitherType.None)
            {
                _volumetricLightMat.DisableKeyword("DITHER");
            }
            else
            {
                _volumetricLightMat.EnableKeyword("DITHER");
                if (ditherType == DitherType.Dither_4x4)
                {
                    _volumetricLightMat.EnableKeyword("DITHER_4_4");
                    _volumetricLightMat.DisableKeyword("DITHER_8_8");
                }
                else
                {
                    _volumetricLightMat.EnableKeyword("DITHER_8_8");
                    _volumetricLightMat.DisableKeyword("DITHER_4_4");
                }
            }
            
            switch (ditherType)
            {
                case DitherType.Dither_4x4:
                    _volumetricLightMat.SetTexture(_ditherTextureID, ditheringTexture4X4);
                    break;
                case DitherType.Dither_8x8:
                    _volumetricLightMat.SetTexture(_ditherTextureID, ditheringTexture8X8);
                    break;
                default:
                    _volumetricLightMat.SetTexture(_ditherTextureID, null);
                    break;
            }
        }


        private void GenerateDitherTexture()
        {
            GenerateDitherTexture4X4();
            GenerateDitherTexture8X8();
        }

        //4x4的均匀随机（halton 序列？）
        private void GenerateDitherTexture4X4()
        {
            int size = 4;
            ditheringTexture4X4 = new Texture2D(size, size, TextureFormat.Alpha8, false, true);
            ditheringTexture4X4.filterMode = FilterMode.Point;
            Color32[] c = new Color32[size * size];

            byte b;
            b = (byte)(0.0f / 16.0f * 255); c[0] = new Color32(b, b, b, b);
            b = (byte)(8.0f / 16.0f * 255); c[1] = new Color32(b, b, b, b);
            b = (byte)(2.0f / 16.0f * 255); c[2] = new Color32(b, b, b, b);
            b = (byte)(10.0f / 16.0f * 255); c[3] = new Color32(b, b, b, b);

            b = (byte)(12.0f / 16.0f * 255); c[4] = new Color32(b, b, b, b);
            b = (byte)(4.0f / 16.0f * 255); c[5] = new Color32(b, b, b, b);
            b = (byte)(14.0f / 16.0f * 255); c[6] = new Color32(b, b, b, b);
            b = (byte)(6.0f / 16.0f * 255); c[7] = new Color32(b, b, b, b);

            b = (byte)(3.0f / 16.0f * 255); c[8] = new Color32(b, b, b, b);
            b = (byte)(11.0f / 16.0f * 255); c[9] = new Color32(b, b, b, b);
            b = (byte)(1.0f / 16.0f * 255); c[10] = new Color32(b, b, b, b);
            b = (byte)(9.0f / 16.0f * 255); c[11] = new Color32(b, b, b, b);

            b = (byte)(15.0f / 16.0f * 255); c[12] = new Color32(b, b, b, b);
            b = (byte)(7.0f / 16.0f * 255); c[13] = new Color32(b, b, b, b);
            b = (byte)(13.0f / 16.0f * 255); c[14] = new Color32(b, b, b, b);
            b = (byte)(5.0f / 16.0f * 255); c[15] = new Color32(b, b, b, b);
            
            ditheringTexture4X4.SetPixels32(c);
            ditheringTexture4X4.Apply();
        }

        //8x8的均匀随机（halton 序列？）
        private void GenerateDitherTexture8X8()
        {
             int size = 8;

            // again, I couldn't make it work with Alpha8
            ditheringTexture8X8 = new Texture2D(size, size, TextureFormat.Alpha8, false, true);
            ditheringTexture8X8.filterMode = FilterMode.Point;
            Color32[] c = new Color32[size * size];

            byte b;
            int i = 0;
            b = (byte)(1.0f / 65.0f * 255); c[i++] = new Color32(b, b, b, b);
            b = (byte)(49.0f / 65.0f * 255); c[i++] = new Color32(b, b, b, b);
            b = (byte)(13.0f / 65.0f * 255); c[i++] = new Color32(b, b, b, b);
            b = (byte)(61.0f / 65.0f * 255); c[i++] = new Color32(b, b, b, b);
            b = (byte)(4.0f / 65.0f * 255); c[i++] = new Color32(b, b, b, b);
            b = (byte)(52.0f / 65.0f * 255); c[i++] = new Color32(b, b, b, b);
            b = (byte)(16.0f / 65.0f * 255); c[i++] = new Color32(b, b, b, b);
            b = (byte)(64.0f / 65.0f * 255); c[i++] = new Color32(b, b, b, b);

            b = (byte)(33.0f / 65.0f * 255); c[i++] = new Color32(b, b, b, b);
            b = (byte)(17.0f / 65.0f * 255); c[i++] = new Color32(b, b, b, b);
            b = (byte)(45.0f / 65.0f * 255); c[i++] = new Color32(b, b, b, b);
            b = (byte)(29.0f / 65.0f * 255); c[i++] = new Color32(b, b, b, b);
            b = (byte)(36.0f / 65.0f * 255); c[i++] = new Color32(b, b, b, b);
            b = (byte)(20.0f / 65.0f * 255); c[i++] = new Color32(b, b, b, b);
            b = (byte)(48.0f / 65.0f * 255); c[i++] = new Color32(b, b, b, b);
            b = (byte)(32.0f / 65.0f * 255); c[i++] = new Color32(b, b, b, b);

            b = (byte)(9.0f / 65.0f * 255); c[i++] = new Color32(b, b, b, b);
            b = (byte)(57.0f / 65.0f * 255); c[i++] = new Color32(b, b, b, b);
            b = (byte)(5.0f / 65.0f * 255); c[i++] = new Color32(b, b, b, b);
            b = (byte)(53.0f / 65.0f * 255); c[i++] = new Color32(b, b, b, b);
            b = (byte)(12.0f / 65.0f * 255); c[i++] = new Color32(b, b, b, b);
            b = (byte)(60.0f / 65.0f * 255); c[i++] = new Color32(b, b, b, b);
            b = (byte)(8.0f / 65.0f * 255); c[i++] = new Color32(b, b, b, b);
            b = (byte)(56.0f / 65.0f * 255); c[i++] = new Color32(b, b, b, b);

            b = (byte)(41.0f / 65.0f * 255); c[i++] = new Color32(b, b, b, b);
            b = (byte)(25.0f / 65.0f * 255); c[i++] = new Color32(b, b, b, b);
            b = (byte)(37.0f / 65.0f * 255); c[i++] = new Color32(b, b, b, b);
            b = (byte)(21.0f / 65.0f * 255); c[i++] = new Color32(b, b, b, b);
            b = (byte)(44.0f / 65.0f * 255); c[i++] = new Color32(b, b, b, b);
            b = (byte)(28.0f / 65.0f * 255); c[i++] = new Color32(b, b, b, b);
            b = (byte)(40.0f / 65.0f * 255); c[i++] = new Color32(b, b, b, b);
            b = (byte)(24.0f / 65.0f * 255); c[i++] = new Color32(b, b, b, b);

            b = (byte)(3.0f / 65.0f * 255); c[i++] = new Color32(b, b, b, b);
            b = (byte)(51.0f / 65.0f * 255); c[i++] = new Color32(b, b, b, b);
            b = (byte)(15.0f / 65.0f * 255); c[i++] = new Color32(b, b, b, b);
            b = (byte)(63.0f / 65.0f * 255); c[i++] = new Color32(b, b, b, b);
            b = (byte)(2.0f / 65.0f * 255); c[i++] = new Color32(b, b, b, b);
            b = (byte)(50.0f / 65.0f * 255); c[i++] = new Color32(b, b, b, b);
            b = (byte)(14.0f / 65.0f * 255); c[i++] = new Color32(b, b, b, b);
            b = (byte)(62.0f / 65.0f * 255); c[i++] = new Color32(b, b, b, b);

            b = (byte)(35.0f / 65.0f * 255); c[i++] = new Color32(b, b, b, b);
            b = (byte)(19.0f / 65.0f * 255); c[i++] = new Color32(b, b, b, b);
            b = (byte)(47.0f / 65.0f * 255); c[i++] = new Color32(b, b, b, b);
            b = (byte)(31.0f / 65.0f * 255); c[i++] = new Color32(b, b, b, b);
            b = (byte)(34.0f / 65.0f * 255); c[i++] = new Color32(b, b, b, b);
            b = (byte)(18.0f / 65.0f * 255); c[i++] = new Color32(b, b, b, b);
            b = (byte)(46.0f / 65.0f * 255); c[i++] = new Color32(b, b, b, b);
            b = (byte)(30.0f / 65.0f * 255); c[i++] = new Color32(b, b, b, b);

            b = (byte)(11.0f / 65.0f * 255); c[i++] = new Color32(b, b, b, b);
            b = (byte)(59.0f / 65.0f * 255); c[i++] = new Color32(b, b, b, b);
            b = (byte)(7.0f / 65.0f * 255); c[i++] = new Color32(b, b, b, b);
            b = (byte)(55.0f / 65.0f * 255); c[i++] = new Color32(b, b, b, b);
            b = (byte)(10.0f / 65.0f * 255); c[i++] = new Color32(b, b, b, b);
            b = (byte)(58.0f / 65.0f * 255); c[i++] = new Color32(b, b, b, b);
            b = (byte)(6.0f / 65.0f * 255); c[i++] = new Color32(b, b, b, b);
            b = (byte)(54.0f / 65.0f * 255); c[i++] = new Color32(b, b, b, b);

            b = (byte)(43.0f / 65.0f * 255); c[i++] = new Color32(b, b, b, b);
            b = (byte)(27.0f / 65.0f * 255); c[i++] = new Color32(b, b, b, b);
            b = (byte)(39.0f / 65.0f * 255); c[i++] = new Color32(b, b, b, b);
            b = (byte)(23.0f / 65.0f * 255); c[i++] = new Color32(b, b, b, b);
            b = (byte)(42.0f / 65.0f * 255); c[i++] = new Color32(b, b, b, b);
            b = (byte)(26.0f / 65.0f * 255); c[i++] = new Color32(b, b, b, b);
            b = (byte)(38.0f / 65.0f * 255); c[i++] = new Color32(b, b, b, b);
            b = (byte)(22.0f / 65.0f * 255); c[i++] = new Color32(b, b, b, b);

            ditheringTexture8X8.SetPixels32(c);
            ditheringTexture8X8.Apply();
        }


        private void OnDestroy()
        {
            RenderTexture.ReleaseTemporary(_volumetricLightRT);
            Destroy(_volumetricLightMat);
        }
    }
}
