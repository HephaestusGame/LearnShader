using System;
using System.Collections;
using System.Collections.Generic;
using Sirenix.OdinInspector;
using SneakySquirrelLabs.MinMaxRangeAttribute;
using UnityEngine;
using UnityEngine.Rendering.PostProcessing;
using UnityEngine.Serialization;


namespace HepheastusGame
{
    [Serializable]
    [PostProcess(typeof(VolumetricCloudRenderer), PostProcessEvent.AfterStack, "Unity/ColorTint")]
    public class VolumetricCloud : PostProcessEffectSettings
    {
        public BoolParameter enableDirectionalScattering = new BoolParameter { value = true };
        public BoolParameter eanbleDetail = new BoolParameter() { value = false };

        [Range(0.1f, 2.0f)]
        public FloatParameter rtScale = new FloatParameter() { value = 2.0f };
        
        public TextureParameter detailShapeTex = new TextureParameter() { value = null };
        [Range(0.1f, 3.0f)]
        public FloatParameter detailShapeTiling = new FloatParameter() { value = 0.1f };
        [Range(0.0f, 1.0f)]
        public FloatParameter detailFactor = new FloatParameter() { value = 0.5f };
        
        //Wind
        public Vector3Parameter windDirection = new Vector3Parameter() { value = Vector3.zero };
        [Range(0.0f, 5.0f)]
        public FloatParameter windSpeed = new FloatParameter() { value = 0.0f };

        //噪声优化
        public TextureParameter blueNoiseTex = new TextureParameter() { value = null };
        public FloatParameter blueNoiseTexTiling = new FloatParameter() { value = 1.0f };
        [Range(0, 1)]
        public FloatParameter blueNoiseAffectFactor = new FloatParameter() { value = 1.0f };
        
        //云层形状
        public IntParameter rayMarchSteps = new IntParameter { value = 256 };
        [Range(0.0001f, 800)]
        public FloatParameter rayMarchStepSize = new FloatParameter { value = 0.5f };
        [Range(0.0f, 2.0f)]
        public FloatParameter densityScale = new FloatParameter { value = 0.5f };
        [Range(0.0f, 1.0f)]
        public FloatParameter cloudCoverageRate = new FloatParameter() { value = 0.5f };
        public FloatParameter noiseTextureTiling = new FloatParameter { value = 0.00001f };
        public Vector3Parameter noiseTextureOffset = new Vector3Parameter { value = Vector3.zero };
        public TextureParameter noise3D = new TextureParameter { value = null };
        [Range(0.0f, 1.0f)]
        public FloatParameter baseDetailFactor = new FloatParameter() { value = 0.0f };

        //云层光照
        [Range(0.0f, 1.0f)]
        public FloatParameter lightAbsorption = new FloatParameter { value = 0.7f };
        [Range(0, 0.99f)]
        public FloatParameter scatterForward = new FloatParameter { value = 0.7f };
        [Range(0.0f, 1.0f)]
        public FloatParameter scatterForwardIntensity = new FloatParameter { value = 0.5f };
        [Range(0.0f, 1.0f)]
        public FloatParameter scatterBackward = new FloatParameter { value = 0.25f };
        [Range(0.0f, 1.0f)]
        public FloatParameter scatterBackwardIntensity = new FloatParameter { value = 0.5f };
        [Range(0.0f, 1.0f)]
        public FloatParameter scatterBase = new FloatParameter { value = 0.8f };
        [Range(0.0f, 1.0f)]
        public FloatParameter scatterIntensity = new FloatParameter { value = 1.0f };
        
        [Range(0.0f, 1.0f)]
        public FloatParameter midToneColorOffset = new FloatParameter() { value = 0.5f };
        [Range(0.0f, 1.0f)]
        public FloatParameter darknessThreshold = new FloatParameter { value = 1.0f };
        [ColorUsage(false, true)]
        public ColorParameter brightColor = new ColorParameter { value = new Color(1, 1, 1, 1) };
        [ColorUsage(false, true)]
        public ColorParameter midToneColor = new ColorParameter { value = new Color(0.5f, 0.5f, 0.5f, 1) };
        [ColorUsage(false, true)]
        public ColorParameter darkColor = new ColorParameter { value = new Color(0.5f, 0.5f, 0.5f, 1) };

        //云层形状
        public TextureParameter weatherMap = new TextureParameter { value = null };
        public Vector2Parameter stratusRange = new Vector2Parameter() { value = new Vector2(0.1f, 0.2f)};
        [Range(0.0f, 1.0f)]
        public FloatParameter stratusFeather = new FloatParameter() { value = 0.1f };
        public Vector2Parameter cumulusRange = new Vector2Parameter() { value = new Vector2(0.1f, 0.8f)};
        [Range(0.0f, 1.0f)]
        public FloatParameter cumulusFeather = new FloatParameter() { value = 0.1f };
        
        public BoolParameter useCloudLayerBoudingBox = new BoolParameter { value = true };
        [FoldoutGroup("BoundingBox"), UnityEngine.Rendering.PostProcessing.Min(0)]
        public FloatParameter cloudLayerHeightMin = new FloatParameter { value = 1500.0f };
        [FoldoutGroup("BoundingBox"), UnityEngine.Rendering.PostProcessing.Min(0)]
        public FloatParameter cloudLayerHeightMax = new FloatParameter { value = 2000.0f };
    }

    public sealed class VolumetricCloudRenderer : PostProcessEffectRenderer<VolumetricCloud>
    {
        private Shader _shader;
        private Transform _cloudTransform;
        public override void Init()
        {
            _shader = Shader.Find("Hidden/PostProcessing/VolumetricCloud");

            GameObject go = GameObject.Find("VolumetricCloud");
            if (go != null)
            {
                _cloudTransform = go.GetComponent<Transform>();
            }
        }
        
        private int _detailShapeTexID = Shader.PropertyToID("_DetailShapeTex");
        private int _detailShapeTilingID = Shader.PropertyToID("_DetailShapeTiling");
        private int _detailFactorID = Shader.PropertyToID("_DetailFactor");

        private int _windDirectionID = Shader.PropertyToID("_WindDirection");
        private int _windSpeedID = Shader.PropertyToID("_WindSpeed");

        private int _blueNoiseTexID = Shader.PropertyToID("_BlueNoiseTex");
        private int _blueNoiseTexTilingID = Shader.PropertyToID("_BlueNoiseTexTiling");
        private int _blueNoiseAffectFactorID = Shader.PropertyToID("_BlueNoiseAffectFactor");

        private int _boundsMinID = Shader.PropertyToID("_BoundsMin");
        private int _boundsMaxID = Shader.PropertyToID("_BoundsMax");
        private int _rayMarchStepsID = Shader.PropertyToID("_RayMarchSteps");
        private int _rayMarchStepSizeID = Shader.PropertyToID("_RayMarchStepSize");
        private int _lightAbsorptionID = Shader.PropertyToID("_LightAbsorption");
        private int _scatterForwardID = Shader.PropertyToID("_ScatterForward");
        private int _scatterForwardIntensityID = Shader.PropertyToID("_ScatterForwardIntensity");
        private int _scatterBackwardID = Shader.PropertyToID("_ScatterBackward");
        private int _scatterBackwardIntensityID = Shader.PropertyToID("_ScatterBackwardIntensity");
        private int _scatterBaseID = Shader.PropertyToID("_ScatterBase");
        private int _scatterIntensityID = Shader.PropertyToID("_ScatterIntensity");
        
        
        private int _noise3DTextureID = Shader.PropertyToID("_NoiseTexture3D");
        private int _noiseTextureTilingID = Shader.PropertyToID("_NoiseTextureTiling");
        private int _noiseTextureOffsetID = Shader.PropertyToID("_NoiseTextureOffset");
        private int _densityScaleID = Shader.PropertyToID("_DensityScale");
        private int _cloudCoverageRateID = Shader.PropertyToID("_CloudCoverageRate");
        private int _baseDetailFactorID = Shader.PropertyToID("_BaseDetailFactor");

        //云层颜色设置
        private int _darknessThresholdID = Shader.PropertyToID("_DarknessThreshold");
        private int _brighColorID = Shader.PropertyToID("_BrightColor");
        private int _midToneColorID = Shader.PropertyToID("_MidToneColor");
        private int _darkColorID = Shader.PropertyToID("_DarkColor");
        private int _midToneColorOffsetID = Shader.PropertyToID("_MidToneColorOffset");
        
        private int _cloudLayerHeightMinID = Shader.PropertyToID("_CloudLayerHeightMin");
        private int _cloudLayerHeightMaxID = Shader.PropertyToID("_CloudLayerHeightMax");

        private int _weatherMapID = Shader.PropertyToID("_WeatherMap");
        private int _stratusRangeAndFeatherID = Shader.PropertyToID("_StratusRangeAndFeather");
        private int _cumulusRangeAndFeatherID = Shader.PropertyToID("_CumulusRangeAndFeather");
        
        
        public override void Render(PostProcessRenderContext context)
        {
            var cmd = context.command;
            cmd.BeginSample("VolumetricCloud");
        
            var sheet = context.propertySheets.Get(_shader);
            MaterialPropertyBlock properties = sheet.properties;
        
            Matrix4x4 projectionMatrix = GL.GetGPUProjectionMatrix(context.camera.projectionMatrix, false);
            properties.SetMatrix(Shader.PropertyToID("_InverseProjectionMatrix"), projectionMatrix.inverse);
            properties.SetMatrix(Shader.PropertyToID("_InverseViewMatrix"), context.camera.cameraToWorldMatrix);

            if (_cloudTransform != null)
            {
                Vector3 boundsMin = _cloudTransform.position - _cloudTransform.localScale / 2;
                Vector3 boundsMax = _cloudTransform.position + _cloudTransform.localScale / 2;
                properties.SetVector(_boundsMinID, boundsMin);
                properties.SetVector(_boundsMaxID, boundsMax);
            }
            
            properties.SetFloat(_detailShapeTilingID, settings.detailShapeTiling.value);
            properties.SetFloat(_detailFactorID, settings.detailFactor.value);
            
            properties.SetVector(_windDirectionID, Vector3.Normalize(settings.windDirection.value));
            properties.SetFloat(_windSpeedID, settings.windSpeed);
            
            properties.SetFloat(_cloudLayerHeightMinID, settings.cloudLayerHeightMin);
            properties.SetFloat(_cloudLayerHeightMaxID, settings.cloudLayerHeightMax);
            properties.SetInt(_rayMarchStepsID, settings.rayMarchSteps.value);
            properties.SetFloat(_rayMarchStepSizeID, settings.rayMarchStepSize.value);
            properties.SetFloat(_densityScaleID, settings.densityScale.value);
            properties.SetFloat(_lightAbsorptionID, settings.lightAbsorption.value);
            properties.SetFloat(_cloudCoverageRateID, settings.cloudCoverageRate.value);
            properties.SetFloat(_baseDetailFactorID, settings.baseDetailFactor.value);
            
            //方向散射
            properties.SetFloat(_scatterForwardID, settings.scatterForward.value);
            properties.SetFloat(_scatterForwardIntensityID, settings.scatterForwardIntensity.value);
            properties.SetFloat(_scatterBackwardID, settings.scatterBackward.value);
            properties.SetFloat(_scatterBackwardIntensityID, settings.scatterBackwardIntensity.value);
            properties.SetFloat(_scatterBaseID, settings.scatterBase.value);
            properties.SetFloat(_scatterIntensityID, settings.scatterIntensity.value);
            
            properties.SetFloat(_noiseTextureTilingID, settings.noiseTextureTiling.value);
            properties.SetVector(_noiseTextureOffsetID, settings.noiseTextureOffset.value);
            
            properties.SetFloat(_darknessThresholdID, settings.darknessThreshold.value);
            properties.SetFloat(_midToneColorOffsetID, settings.midToneColorOffset.value);
            properties.SetColor(_brighColorID, settings.brightColor.value);
            properties.SetColor(_midToneColorID, settings.midToneColor.value);
            properties.SetColor(_darkColorID, settings.darkColor.value);

            properties.SetVector(_stratusRangeAndFeatherID, new Vector3(settings.stratusRange.value.x, settings.stratusRange.value.y, settings.stratusFeather.value));
            properties.SetVector(_cumulusRangeAndFeatherID, new Vector3(settings.cumulusRange.value.x, settings.cumulusRange.value.y, settings.cumulusFeather.value));

            SetKeywords(sheet);
            SetTextures(sheet);


            RenderTexture temp = RenderTexture.GetTemporary(
                Mathf.FloorToInt(Screen.width * settings.rtScale.value) , 
                Mathf.FloorToInt(Screen.height * settings.rtScale.value), 0, 
                RenderTextureFormat.ARGB32);
            context.command.BlitFullscreenTriangle(context.source, temp, sheet, 0);
            context.command.BlitFullscreenTriangle(temp, context.destination);
            
            RenderTexture.ReleaseTemporary(temp);
            cmd.EndSample("VolumetricCloud");
        }
        

        private void SetKeywords(PropertySheet sheet)
        {
            if (settings.enableDirectionalScattering.value)
            {
                sheet.EnableKeyword("ENABLE_DIRECTIONAL_SCATTERING");
            }
            else
            {
                sheet.DisableKeyword("ENABLE_DIRECTIONAL_SCATTERING");
            }

            if (settings.eanbleDetail)
            {
                sheet.EnableKeyword("USE_DETAIL_SHAPE_TEX");
            }
            else
            {
                sheet.DisableKeyword("USE_DETAIL_SHAPE_TEX");
            }

            if (settings.useCloudLayerBoudingBox)
            {
                sheet.EnableKeyword("USE_CLOUD_LAYER_BOUNDING_BOX");
                sheet.DisableKeyword("USE_AABB_BOUNDING_BOX");
            }
            else
            {
                sheet.EnableKeyword("USE_AABB_BOUNDING_BOX");
                sheet.DisableKeyword("USE_CLOUD_LAYER_BOUNDING_BOX");
            }
        }

        private void SetTextures(PropertySheet sheet)
        {
            if (settings.detailShapeTex.value != null)
                sheet.properties.SetTexture(_detailShapeTexID, settings.detailShapeTex.value);
            
            if (settings.blueNoiseTex.value != null)
            {
                sheet.properties.SetTexture(_blueNoiseTexID, settings.blueNoiseTex.value);
                sheet.properties.SetFloat(_blueNoiseTexTilingID, settings.blueNoiseTexTiling.value);
                sheet.properties.SetFloat(_blueNoiseAffectFactorID, settings.blueNoiseAffectFactor.value);
            }
            if (settings.noise3D.value != null)
                sheet.properties.SetTexture(_noise3DTextureID, settings.noise3D.value);
            
            if (settings.weatherMap.value != null)
                sheet.properties.SetTexture(_weatherMapID, settings.weatherMap.value);
        }
    }
}
