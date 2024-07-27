using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
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
        private VolumtericResolution _currentResolution = VolumtericResolution.Half;
        private Material _bilateralBlurMat;
        private Material _blitAddMat;
        private void Start()
        {
            _camera = GetComponent<Camera>();
            _currentResolution = resolution;
            ChangeResolution();
            
            Shader bilateralBlurShader = Shader.Find("Learn/BilateralBlur");
            _bilateralBlurMat = new Material(bilateralBlurShader);
            
            Shader shader = Shader.Find("Hidden/BlitAdd");
            _blitAddMat = new Material(shader);
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

            if (resolution == VolumtericResolution.Full)
            {
                _volumeLightTexture = new RenderTexture(width, height, 0, RenderTextureFormat.ARGBHalf);
                _volumeLightTexture.filterMode = FilterMode.Bilinear;
                _volumeLightTexture.name = "VolumeLightBuffer";
            }
            else if (resolution == VolumtericResolution.Half)
            {
                _halfVolumeLightTexture = new RenderTexture(width / 2, height / 2, 0, RenderTextureFormat.ARGBHalf);
                _halfVolumeLightTexture.filterMode = FilterMode.Bilinear;
                _halfVolumeLightTexture.name = "VolumeLightBufferHalf";
            }
            else
            {
                _quarterVolumeLightTexture = new RenderTexture(width / 4, height / 4, 0, RenderTextureFormat.ARGBHalf);
                _quarterVolumeLightTexture.filterMode = FilterMode.Bilinear;
                _quarterVolumeLightTexture.name = "VolumeLightBufferQuater";
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

        private void OnPreRender()
        {
            if (resolution != _currentResolution)
            {
                ChangeResolution();
            }
            
            OnPreRenderEvent?.Invoke(this, _camera);
        }

        private void OnRenderImage(RenderTexture source, RenderTexture destination)
        {
            RenderTexture lightBuffer = GetVolumeLightBuffer();
            if (blur)
            {
                RenderTexture temp = RenderTexture.GetTemporary(lightBuffer.width, lightBuffer.height, 0, RenderTextureFormat.ARGBHalf);
                if (useDepthTextureToBlur)
                {
                    _bilateralBlurMat.EnableKeyword("USE_DEPTH_TEXTURE");
                }
                else
                {
                    _bilateralBlurMat.DisableKeyword("USE_DEPTH_TEXTURE");
                }
                Graphics.Blit(lightBuffer, temp, _bilateralBlurMat, 0);
                Graphics.Blit(temp, lightBuffer, _bilateralBlurMat, 1);
                RenderTexture.ReleaseTemporary(temp);
            }
            _blitAddMat.SetTexture(Shader.PropertyToID("_Source"), source);
            Graphics.Blit(lightBuffer, destination, _blitAddMat);
        }
        
        private void OnDestroy()
        {
            Destroy(_bilateralBlurMat);
            Destroy(_blitAddMat);
        }
    }
}
