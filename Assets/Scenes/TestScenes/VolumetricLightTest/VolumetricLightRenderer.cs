using System;
using System.Collections;
using System.Collections.Generic;
using UnityEditor;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Serialization;

namespace HephaestusGame
{
    [RequireComponent(typeof(Camera))]
    public class VolumetricLightRenderer : MonoBehaviour
    {
        public enum VolumtericResolution
        {
            Full,
            Half,
            Quarter
        };
        
       
        
        public static event Action<VolumetricLightRenderer, Camera> OnPreRenderEvent;
        
        
       
        public VolumtericResolution resolution = VolumtericResolution.Half;
        public bool blur = true;
        public bool useDepthTextureToBlur = true;
        private Camera _camera;
        private RenderTexture _volumeLightTexture;
        private RenderTexture _halfVolumeLightTexture;
        private RenderTexture _quarterVolumeLightTexture;
        
        private RenderTexture _halfDepthBuffer;
        private RenderTexture _quarterDepthBuffer;
        private VolumtericResolution _currentResolution = VolumtericResolution.Half;
        private Material _bilateralBlurMat;
        private Material _blitAddMat;

        private CommandBuffer _commandBuffer;
        private void Awake()
        {
            _camera = GetComponent<Camera>();

            _commandBuffer = new CommandBuffer();
            _commandBuffer.name = "PreLight";
            _currentResolution = resolution;
            ChangeResolution();
            
            Shader bilateralBlurShader = Shader.Find("Learn/BilateralBlur");
            _bilateralBlurMat = new Material(bilateralBlurShader);
            
            Shader shader = Shader.Find("Hidden/BlitAdd");
            _blitAddMat = new Material(shader);
        }

        private void OnEnable()
        {
            _camera.AddCommandBuffer(CameraEvent.AfterDepthTexture, _commandBuffer);
        }

        private void OnDisable()
        {
            _camera.RemoveCommandBuffer(CameraEvent.AfterDepthTexture, _commandBuffer);
        }

        private void ChangeResolution()
        {
            int width = _camera.pixelWidth;
            int height = _camera.pixelHeight;
            
            if (_volumeLightTexture != null)
                Destroy(_volumeLightTexture);
            if (_halfVolumeLightTexture != null)
                Destroy(_halfVolumeLightTexture);
            if (_quarterVolumeLightTexture != null)
                Destroy(_quarterVolumeLightTexture);
            
            if (_halfDepthBuffer != null)
                Destroy(_halfDepthBuffer);
            if (_quarterDepthBuffer != null)
                Destroy(_quarterDepthBuffer);


            _volumeLightTexture = new RenderTexture(width, height, 0, RenderTextureFormat.ARGBHalf);
            _volumeLightTexture.filterMode = FilterMode.Bilinear;
            _volumeLightTexture.name = "VolumeLightBuffer";
            
            if (resolution == VolumtericResolution.Half || resolution == VolumtericResolution.Quarter)
            {
                _halfVolumeLightTexture = new RenderTexture(width / 2, height / 2, 0, RenderTextureFormat.ARGBHalf);
                _halfVolumeLightTexture.filterMode = FilterMode.Bilinear;
                _halfVolumeLightTexture.name = "VolumeLightBufferHalf";
                
                _halfDepthBuffer = new RenderTexture(width / 2, height / 2, 0, RenderTextureFormat.RFloat);
                _halfDepthBuffer.name = "VolumeLightHalfDepth";
                _halfDepthBuffer.Create();
                _halfDepthBuffer.filterMode = FilterMode.Point;
            }
            
            if (resolution == VolumtericResolution.Quarter)
            {
                _quarterVolumeLightTexture = new RenderTexture(width / 4, height / 4, 0, RenderTextureFormat.ARGBHalf);
                _quarterVolumeLightTexture.filterMode = FilterMode.Bilinear;
                _quarterVolumeLightTexture.name = "VolumeLightBufferQuater";
                
                _quarterDepthBuffer = new RenderTexture(width / 4, height / 4, 0, RenderTextureFormat.RFloat);
                _quarterDepthBuffer.name = "VolumeLightQuarterDepth";
                _quarterDepthBuffer.Create();
                _quarterDepthBuffer.filterMode = FilterMode.Point;
            }
            
            
            _currentResolution = resolution;
        }
        
        

        public RenderTexture GetVolumeLightBuffer()
        {
            switch (resolution)
            {
                case VolumtericResolution.Quarter:
                    return _quarterVolumeLightTexture;
                case VolumtericResolution.Half:
                    return _halfVolumeLightTexture;
                default:
                    return _volumeLightTexture;
            }
        }
        
        public RenderTexture GetVolumeLightDepthBuffer()
        {
            if (resolution == VolumtericResolution.Quarter)
                return _quarterDepthBuffer;
            else if (resolution == VolumtericResolution.Half)
                return _halfDepthBuffer;
            else
                return null;
        }

        private void OnPreRender()
        {
            if (resolution != _currentResolution)
            {
                ChangeResolution();
            }
            _commandBuffer.Clear();

            bool dx11 = SystemInfo.graphicsShaderLevel > 40;
            if (resolution == VolumtericResolution.Quarter)
            {
                // down sample depth to half res
                _commandBuffer.Blit(null, _halfDepthBuffer, _bilateralBlurMat, dx11 ? 4 : 10);
                // down sample depth to quarter res
                _commandBuffer.Blit(null, _quarterDepthBuffer, _bilateralBlurMat, dx11 ? 6 : 11);
            } else if (resolution == VolumtericResolution.Half)
            {
                _commandBuffer.Blit(null, _halfDepthBuffer, _bilateralBlurMat, dx11 ? 4 : 10);
            }
            
            OnPreRenderEvent?.Invoke(this, _camera);
        }

        private readonly int _halfResDepthBufferID = Shader.PropertyToID("_HalfResDepthBuffer");
        private readonly int _halfResColorID = Shader.PropertyToID("_HalfResColor");
        private readonly int _quarterResDepthBufferID = Shader.PropertyToID("_QuarterResDepthBuffer");
        private readonly int _quarterResColorID = Shader.PropertyToID("_QuarterResColor");
        private void OnRenderImage(RenderTexture source, RenderTexture destination)
        {
            RenderTexture lightBuffer = GetVolumeLightBuffer();
            if (blur)
            {
                
                _bilateralBlurMat.SetTexture(_halfResDepthBufferID, _halfDepthBuffer);
                _bilateralBlurMat.SetTexture(_halfResColorID, _halfVolumeLightTexture);
                _bilateralBlurMat.SetTexture(_quarterResDepthBufferID, _quarterDepthBuffer);
                _bilateralBlurMat.SetTexture(_quarterResColorID, _quarterVolumeLightTexture);
                RenderTexture temp = RenderTexture.GetTemporary(lightBuffer.width, lightBuffer.height, 0, RenderTextureFormat.ARGBHalf);
                temp.filterMode = FilterMode.Bilinear;
                if (useDepthTextureToBlur)
                {
                    _bilateralBlurMat.EnableKeyword("USE_DEPTH_TEXTURE");
                }
                else
                {
                    _bilateralBlurMat.DisableKeyword("USE_DEPTH_TEXTURE");
                }

                if (resolution == VolumtericResolution.Quarter)
                {
                    Graphics.Blit(lightBuffer, temp, _bilateralBlurMat, 8);
                    Graphics.Blit(temp, lightBuffer, _bilateralBlurMat, 9);
                    
                    // upscale to full res
                    Graphics.Blit(lightBuffer, _volumeLightTexture, _bilateralBlurMat, 7);
                }
                else if (resolution == VolumtericResolution.Half)
                {
                    Graphics.Blit(lightBuffer, temp, _bilateralBlurMat, 2);
                    Graphics.Blit(temp, lightBuffer, _bilateralBlurMat, 3);
                    
                    // upscale to full res
                    Graphics.Blit(lightBuffer, _volumeLightTexture, _bilateralBlurMat, 5);
                }
                else
                {
                    Graphics.Blit(lightBuffer, temp, _bilateralBlurMat, 0);
                    Graphics.Blit(temp, lightBuffer, _bilateralBlurMat, 1);
                }
               
                RenderTexture.ReleaseTemporary(temp);
            }
            _blitAddMat.SetTexture(Shader.PropertyToID("_Source"), source);
            Graphics.Blit(_volumeLightTexture, destination, _blitAddMat, 0);
        }
        
        private void OnDestroy()
        {
            Destroy(_bilateralBlurMat);
            Destroy(_blitAddMat);
        }
    }
}
