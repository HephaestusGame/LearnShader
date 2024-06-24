using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.PostProcessing;
using UnityEngine.Serialization;

namespace HepheastusGame
{
    [Serializable]
    [PostProcess(typeof(VolumetricCloud2Renderer), PostProcessEvent.AfterStack, "Unity/VolumetricCloud_2")]
    public class VolumetricCloud2 : PostProcessEffectSettings
    {
        [Max(2048)]
        public IntParameter cloudTexSize = new IntParameter() { value = 1024};
        public BoolParameter useHaltonSequence = new BoolParameter() { value = true };

        public TextureParameter blueNoise = new TextureParameter() { value = null };
        [Range(0.0f, 1.0f)]
        public FloatParameter blueNoiseAffectFactor = new FloatParameter() { value = 1.0f };
        public Vector2Parameter blueNoiseTiling = new Vector2Parameter() { value = new Vector2(1.7f, 1.0f) };
        public TextureParameter baseNoise = new TextureParameter() { value = null };
        public TextureParameter detailNoise = new TextureParameter() { value = null };
        public FloatParameter cloudBottom = new FloatParameter() { value = 500.0f };
        public FloatParameter cloudHeight = new FloatParameter() { value = 1000.0f };
       
        [Range(1, 1024)]
        public IntParameter cloudMarchSteps = new IntParameter() { value = 100 };

        public FloatParameter cloudBaseScale = new FloatParameter() { value = 1.72f };
        public FloatParameter cloudDetailScale = new FloatParameter() { value = 1000.0f };
        public FloatParameter horizonFadeStart = new FloatParameter() { value = 0.0f };
        public FloatParameter horizonFadeEnd = new FloatParameter() { value = 0.0f };
        [Range(0.0f, 5.0f)]
        public FloatParameter cloudAlpha = new FloatParameter() { value = 1.0f };
        
        public FloatParameter cloudDetailStrength = new FloatParameter() { value = 0.072f };
        [Range(0.0f, 1.0f)]
        public FloatParameter cloudCoverage = new FloatParameter() { value = 0.5f };
        [Range(-1.0f, 1.0f)]
        public FloatParameter cloudCoverageBias = new FloatParameter() { value = 0.02f };

        public FloatParameter attenuation = new FloatParameter() { value = 1.5f };
        public FloatParameter cloudBaseEdgeSoftness = new FloatParameter() { value = 0.025f };
        public FloatParameter cloudBottomSoftness = new FloatParameter() { value = 0.4f };
        [Range(0.0f, 1.0f)]
        public FloatParameter cloudDensity = new FloatParameter() { value = 0.313f };

        public ColorParameter lightningColor = new ColorParameter() { value = new Color(.76f, .83f, .88f, 1.0f) };
        public ColorParameter cloudColor = new ColorParameter() { value = new Color( 0.8431f, 0.8431f, 0.8431f, 1.0f) };
        public ColorParameter cloudAmbientColorBottom = new ColorParameter() { value = new Color(0.7549f, .7903f, .8207f, 1.0f)  };
        public ColorParameter cloudAmbientColorTop = new ColorParameter() { value = new Color(.51f, .55f, .60f, 1.0f) };
        public FloatParameter lightning = new FloatParameter();
        [Range(0.0f, 150.0f)]
        public FloatParameter cloudMovementSpeed = new FloatParameter() { value = 20.0f };
        [Range(0.0f, 150.0f)]
        public FloatParameter cloudTurbulenceSpeed = new FloatParameter() { value = 50.0f};
    }
    
    
    public sealed class VolumetricCloud2Renderer : PostProcessEffectRenderer<VolumetricCloud2>
    {

        private Shader _shader;

        private int _cloudAlphaID = Shader.PropertyToID("_CloudAlpha");
        private int _blueNoiseID = Shader.PropertyToID("_BlueNoise");
        private int _blueNoiseAffectFactor = Shader.PropertyToID("_BlueNoiseAffectFactor");
        private int _blueNoiseTilingID = Shader.PropertyToID("_BlueNoiseTiling");
        private int _cloudBottomID = Shader.PropertyToID("_CloudBottom");
        private int _cloudHeightID = Shader.PropertyToID("_CloudHeight");
        private int _cloudMarchStepsID = Shader.PropertyToID("_CloudMarchSteps");
        private int _cloudCoverageID = Shader.PropertyToID("_CloudCoverage");
        private int _cloudCoverageBiasID = Shader.PropertyToID("_CloudCoverageBias");
        private int _cloudBaseEdgeSoftnessID = Shader.PropertyToID("_CloudBaseEdgeSoftness");
        private int _cloudBottomSoftnessID = Shader.PropertyToID("_CloudBottomSoftness");
        private int _cloudBaseScaleID = Shader.PropertyToID("_CloudBaseScale");
        private int _cloudDetailScaleID = Shader.PropertyToID("_CloudDetailScale");
        private int _baseNoiseID = Shader.PropertyToID("_BaseNoise");
        private int _detailNoiseID = Shader.PropertyToID("_DetailNoise");
        private int _cloudDetailStrengthID = Shader.PropertyToID("_CloudDetailStrength");
        private int _cloudDensityID = Shader.PropertyToID("_CloudDensity");
        private int _attenuationID = Shader.PropertyToID("_Attenuation");
        private int _lightningID = Shader.PropertyToID("_Lightning");
        private int _horizonFadeStartID = Shader.PropertyToID("_HorizonFadeStart");
        private int _horizonFadeEndID = Shader.PropertyToID("_HorizonFadeEnd");

        private int _lightningColorID = Shader.PropertyToID("_LightningColor");
        private int _cloudColorID = Shader.PropertyToID("_CloudColor");
        private int _cloudAmbientColorBottomID = Shader.PropertyToID("_CloudAmbientColorBottom");
        private int _cloudAmbientColorTopID = Shader.PropertyToID("_CloudAmbientColorTop");

        private int _cloudMovementSpeedID = Shader.PropertyToID("_CloudMovementSpeed");
        private int _baseCloudOffsetID = Shader.PropertyToID("_BaseCloudOffset");
        private int _detailCloudOffsetID = Shader.PropertyToID("_DetailCloudOffset");
        private int _texSizeID = Shader.PropertyToID("_TexSize");
        private int _jitterID = Shader.PropertyToID("_Jitter");

        private float _baseCloudOffset = 0;
        private float _detailCloudOffset = 0;
        public override void Init()
        {
            _shader = Shader.Find("PostProcessing/VolumetricCloud2");
            
            InitCloudBuffers();
        }

        public override void Render(PostProcessRenderContext context)
        {
            var cmd = context.command;
            cmd.BeginSample("VolumetricCloud");

            var sheet = context.propertySheets.Get(_shader);
            MaterialPropertyBlock properties = sheet.properties;
        
            Matrix4x4 projectionMatrix = GL.GetGPUProjectionMatrix(context.camera.projectionMatrix, false);
            properties.SetMatrix(Shader.PropertyToID("_InverseProjectionMatrix"), projectionMatrix.inverse);
            properties.SetMatrix(Shader.PropertyToID("_InverseViewMatrix"), context.camera.cameraToWorldMatrix);
            
            
            properties.SetFloat(_cloudMovementSpeedID, settings.cloudMovementSpeed);
            _baseCloudOffset += settings.cloudMovementSpeed * Time.deltaTime;
            _detailCloudOffset += settings.cloudTurbulenceSpeed * Time.deltaTime;
            properties.SetFloat(_baseCloudOffsetID, _baseCloudOffset);
            properties.SetFloat(_detailCloudOffsetID, _detailCloudOffset);
            
            properties.SetFloat(_texSizeID, settings.cloudTexSize);

            properties.SetFloat(_blueNoiseAffectFactor, settings.blueNoiseAffectFactor);
            properties.SetVector(_blueNoiseTilingID, settings.blueNoiseTiling);
            properties.SetFloat(_attenuationID, settings.attenuation);
            properties.SetFloat(_cloudBottomID, settings.cloudBottom);
            properties.SetFloat(_cloudHeightID, settings.cloudHeight);
            properties.SetInt(_cloudMarchStepsID, settings.cloudMarchSteps);
            properties.SetFloat(_cloudBaseScaleID, settings.cloudBaseScale);
            properties.SetFloat(_cloudDetailScaleID, settings.cloudDetailScale);
            properties.SetFloat(_cloudDetailStrengthID, settings.cloudDetailStrength);
            properties.SetFloat(_cloudCoverageID, settings.cloudCoverage);
            properties.SetFloat(_cloudCoverageBiasID, settings.cloudCoverageBias);
            properties.SetFloat(_cloudBaseEdgeSoftnessID, settings.cloudBaseEdgeSoftness);
            properties.SetFloat(_cloudBottomSoftnessID, settings.cloudBottomSoftness);
            properties.SetFloat(_cloudDensityID, settings.cloudDensity);
            properties.SetFloat(_horizonFadeStartID, settings.horizonFadeStart);
            properties.SetFloat(_horizonFadeEndID, settings.horizonFadeEnd);
            properties.SetFloat(_cloudAlphaID, settings.cloudAlpha);
            
            properties.SetColor(_lightningColorID, settings.lightningColor);
            properties.SetColor(_cloudColorID, settings.cloudColor);
            properties.SetColor(_cloudAmbientColorBottomID, settings.cloudAmbientColorBottom);
            properties.SetColor(_cloudAmbientColorTopID, settings.cloudAmbientColorTop);
            
            properties.SetFloat(_lightningID, settings.lightning);
            SetRayMarchOffset(properties);
            SetTextures(properties);

            RenderCloud(cmd, context, sheet);
            
           
            cmd.EndSample("VolumetricCloud");
        }
        
        private int _fullBufferIndex = 0;

        private int _lowResCloudBufferID = Shader.PropertyToID("_LowResCloudTex");
        private int _previousCloudBufferID = Shader.PropertyToID("_PreviousCloudTex");
        private int _cloudTexID = Shader.PropertyToID("_CloudTex");
        private int _frameCount = 0;
        private void RenderCloud(CommandBuffer cmd, PostProcessRenderContext context, PropertySheet sheet)
        {
            _frameCount++;
            if (_frameCount < 32)
            {
                sheet.EnableKeyword("PREWARM");
            }
            else
            {
                sheet.DisableKeyword("PREWARM");
            }
            
            _fullBufferIndex = _fullBufferIndex ^ 1;


            cmd.BlitFullscreenTriangle(context.source, _lowResCloudBuffer, sheet, 0);

            sheet.properties.SetTexture(_lowResCloudBufferID, _lowResCloudBuffer);
            sheet.properties.SetTexture(_previousCloudBufferID, _fullCloudBuffer[_fullBufferIndex]);
            cmd.BlitFullscreenTriangle(context.source, _fullCloudBuffer[_fullBufferIndex ^ 1], sheet, 1);
            // Shader.SetGlobalTexture(_cloudTexID, _fullCloudBuffer[_fullBufferIndex ^ 1]);
         
            // cmd.Blit(_fullCloudBuffer[_fullBufferIndex ^ 1], context.destination);
            // cmd.Blit(_lowResCloudBuffer, context.destination);
            cmd.Blit(context.source, context.destination);
        }
        
        

        private void SetTextures(MaterialPropertyBlock properties)
        {
            if (settings.blueNoise.value != null)
            {
                properties.SetTexture(_blueNoiseID, settings.blueNoise);    
            }
            
            if (settings.baseNoise.value != null)
            {
                properties.SetTexture(_baseNoiseID, settings.baseNoise);
            }

            if (settings.detailNoise.value != null)
            {
                properties.SetTexture(_detailNoiseID, settings.detailNoise);
            }
        }

        private RenderTexture[] _fullCloudBuffer = new RenderTexture[2];
        private RenderTexture _lowResCloudBuffer;

        public bool EnsureRenderTarget(ref RenderTexture rt, int width, int height, RenderTextureFormat format, FilterMode filterMode, string name, int depthBits = 0, int antiAliasing = 1)
        {
            if (rt != null && (rt.width != width || rt.height != height || rt.format != format || rt.filterMode != filterMode || rt.antiAliasing != antiAliasing))
            {
                RenderTexture.ReleaseTemporary(rt);
                rt = null;
            }
            if (rt == null)
            {
                rt = RenderTexture.GetTemporary(width, height, depthBits, format, RenderTextureReadWrite.Default, antiAliasing);
                rt.name = name;
                rt.filterMode = filterMode;
                rt.wrapMode = TextureWrapMode.Repeat;
                return true;// new target
            }

            #if UNITY_ANDROID || UNITY_IPHONE
                        rt.DiscardContents();
            #endif

            return false;// same target
        }
        
        private void InitCloudBuffers()
        {
            int size = settings.cloudTexSize;
            EnsureRenderTarget(ref _fullCloudBuffer[0], size, size, RenderTextureFormat.ARGBHalf, FilterMode.Bilinear, "fullCloudBuff0");
            EnsureRenderTarget(ref _fullCloudBuffer[1], size, size, RenderTextureFormat.ARGBHalf, FilterMode.Bilinear, "fullCloudBuff1");
            EnsureRenderTarget(ref _lowResCloudBuffer, size / 4, size / 4, RenderTextureFormat.ARGBFloat, FilterMode.Point, "quarterCloudBuff");
        }

        private void ReleaseCloudBuffers()
        {
            foreach (var rt in _fullCloudBuffer)
            {
                RenderTexture.ReleaseTemporary(rt);
            }
            RenderTexture.ReleaseTemporary(_lowResCloudBuffer);
        }

        public override void Release()
        {
            base.Release();
            ReleaseCloudBuffers();
        }

        #region HaltonSequence Offset

        static readonly int[] _haltonSequence = {
            8, 4, 12, 2, 10, 6, 14, 1
        };

        static readonly int[,] _offset = {
            {2,1}, {1,2 }, {2,0}, {0,1},
            {2,3}, {3,2}, {3,1}, {0,3},
            {1,0}, {1,1}, {3,3}, {0,0},
            {2,2}, {1,3}, {3,0}, {0,2}
        };

        static readonly int[,] _bayerOffsets = {
            {0,8,2,10 },
            {12,4,14,6 },
            {3,11,1,9 },
            {15,7,13,5 }
        };

        private int _frameIndex = 0;
        private int _haltonSequenceIndex = 0;
        private int _raymarchOffsetID = Shader.PropertyToID("_RaymarchOffset");
        private void SetRayMarchOffset(MaterialPropertyBlock properties)
        {

            if (!settings.useHaltonSequence)
            {
                properties.SetFloat(_raymarchOffsetID, 0);
                return;
            }
            _frameIndex = (_frameIndex + 1) % 16;
            if (_frameIndex == 0)
                _haltonSequenceIndex = (_haltonSequenceIndex + 1) % _haltonSequence.Length;
            
            float offsetX = _offset[_frameIndex, 0];
            float offsetY = _offset[_frameIndex, 1];
            properties.SetVector(_jitterID, new Vector2(offsetX, offsetY));
            properties.SetFloat(_raymarchOffsetID, (_haltonSequence[_haltonSequenceIndex] / 16.0f + _bayerOffsets[_offset[_frameIndex, 0], _offset[_frameIndex, 1]] / 16.0f));

        }
        #endregion



    }
}
