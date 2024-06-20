using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering.PostProcessing;
using UnityEngine.Serialization;

namespace HepheastusGame
{
    [Serializable]
    [PostProcess(typeof(VolumetricCloud2Renderer), PostProcessEvent.AfterStack, "Unity/VolumetricCloud_2")]
    public class VolumetricCloud2 : PostProcessEffectSettings
    {
        public TextureParameter baseNoise = new TextureParameter() { value = null };
        public TextureParameter detailNoise = new TextureParameter() { value = null };
        public FloatParameter cloudBottom = new FloatParameter() { value = 500.0f };
        public FloatParameter cloudHeight = new FloatParameter() { value = 1000.0f };
       
        [Range(1, 1024)]
        public IntParameter cloudMarchSteps = new IntParameter() { value = 100 };

        public FloatParameter cloudBaseScale = new FloatParameter() { value = 1.72f };
        public FloatParameter cloudDetailScale = new FloatParameter() { value = 1000.0f };
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
    }
    
    public sealed class VolumetricCloud2Renderer : PostProcessEffectRenderer<VolumetricCloud2>
    {

        private Shader _shader;

        private int _cloudBottomID = Shader.PropertyToID("_CloudBottom");
        private int _cloudHeightID = Shader.PropertyToID("_CloudHeight");
        private int _cloudMarchStepsID = Shader.PropertyToID("_CloudMarchSteps");
        private int _raymarchOffsetID = Shader.PropertyToID("_RaymarchOffset");
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

        private int _lightningColorID = Shader.PropertyToID("_LightningColor");
        private int _cloudColorID = Shader.PropertyToID("_CloudColor");
        private int _cloudAmbientColorBottomID = Shader.PropertyToID("_CloudAmbientColorBottom");
        private int _cloudAmbientColorTopID = Shader.PropertyToID("_CloudAmbientColorTop");
        
        public override void Init()
        {
            _shader = Shader.Find("PostProcessing/VolumetricCloud2");
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
            
            properties.SetFloat(_attenuationID, settings.attenuation);
            properties.SetFloat(_cloudBottomID, settings.cloudBottom);
            properties.SetFloat(_cloudHeightID, settings.cloudHeight);
            properties.SetInt(_cloudMarchStepsID, settings.cloudMarchSteps);
            properties.SetFloat(_raymarchOffsetID, 0);
            properties.SetFloat(_cloudBaseScaleID, settings.cloudBaseScale);
            properties.SetFloat(_cloudDetailScaleID, settings.cloudDetailScale);
            properties.SetFloat(_cloudDetailStrengthID, settings.cloudDetailStrength);
            properties.SetFloat(_cloudCoverageID, settings.cloudCoverage);
            properties.SetFloat(_cloudCoverageBiasID, settings.cloudCoverageBias);
            properties.SetFloat(_cloudBaseEdgeSoftnessID, settings.cloudBaseEdgeSoftness);
            properties.SetFloat(_cloudBottomSoftnessID, settings.cloudBottomSoftness);
            properties.SetFloat(_cloudDensityID, settings.cloudDensity);
            
            properties.SetColor(_lightningColorID, settings.lightningColor);
            properties.SetColor(_cloudColorID, settings.cloudColor);
            properties.SetColor(_cloudAmbientColorBottomID, settings.cloudAmbientColorBottom);
            properties.SetColor(_cloudAmbientColorTopID, settings.cloudAmbientColorTop);
            
            cmd.BlitFullscreenTriangle(context.source, context.destination, sheet, 0);
            cmd.EndSample("VolumetricCloud");
            
            SetTextures(properties);
        }

        private void SetTextures(MaterialPropertyBlock properties)
        {
            if (settings.baseNoise.value != null)
            {
                properties.SetTexture(_baseNoiseID, settings.baseNoise);
            }

            if (settings.detailNoise.value != null)
            {
                properties.SetTexture(_detailNoiseID, settings.detailNoise);
            }
        }
    }
}
