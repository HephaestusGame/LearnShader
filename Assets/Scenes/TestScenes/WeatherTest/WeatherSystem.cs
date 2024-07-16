using System;
using System.Collections;
using System.Collections.Generic;
using Sirenix.OdinInspector;
using UnityEngine;
using UnityEngine.Serialization;
using Random = UnityEngine.Random;

namespace HepheastusGame
{
    
    public class WeatherSystem : MonoBehaviour
    {
        [Range(0.0f, 24.0f)]
        public float dayTime = 12.0f;
        public float sunIntensity = 1;
        public float sunRevolution = -90;
        public float sunAttenuationMultiplier = 1.0f;
        public float moonAttenuation = 0.1f;
        public Material cloudMaterial;
        public Gradient sunColor;
        public Gradient regularSunColor;
        public Gradient stormySunColor;
        private GradientColorKey[] _sunColorKeys;
        public Color moonLightColor;
        public Gradient cloudBaseColor;
        public Gradient cloudLightColor;
        public Gradient regularCloudBaseColor;
        public Gradient stormyCloudBaseColor;
        public Gradient regularCloudLightColor;
        public Gradient stormyCloudLightColor;
        private GradientColorKey[] _cloudLightColorKeys;
        private GradientColorKey[] _cloudBaseColorKeys;
        
        public AnimationCurve sunIntensityCurve = AnimationCurve.Linear(0, 0, 24, 5);
        public AnimationCurve sunAttenuationCurve = AnimationCurve.Linear(0, 1, 24, 3);

        
        public Light sunLight;
        public Transform celestialAxisTransform;

       
        [FoldoutGroup("Weather Transition")]
        public float cloudTransitionDuration = 5.0f;
        [FoldoutGroup("Weather Transition")]
        public float weatherParticleEffectTransitionDuration = 3.0f;
        public List<WeatherConfig> weatherConfigs;

        private void Start()
        {
            Init();
        }

        private Dictionary<WeatherType, ParticleSystem> _weatherEffectDict =
            new Dictionary<WeatherType, ParticleSystem>();
        private void Init()
        {
            _cloudLightColorKeys = new GradientColorKey[regularCloudLightColor.colorKeys.Length];
            _cloudBaseColorKeys = new GradientColorKey[regularCloudBaseColor.colorKeys.Length];
            _sunColorKeys = new GradientColorKey[regularSunColor.colorKeys.Length];
            regularCloudLightColor.colorKeys.CopyTo(_cloudLightColorKeys, 0);
            regularCloudBaseColor.colorKeys.CopyTo(_cloudBaseColorKeys, 0);
            regularSunColor.colorKeys.CopyTo(_sunColorKeys, 0);

            //Particle Effect
            _weatherEffectDict.Clear();
            GameObject weatherEffectRoot = new GameObject("Weather Particle Effect");
            weatherEffectRoot.transform.position = Camera.main.transform.position;
            foreach (var config in weatherConfigs)
            {
                if (config.useWeatherEffect && config.wetherEffect != null)
                {
                    ParticleSystem ps = Instantiate(config.wetherEffect, Vector3.zero, Quaternion.identity,
                        weatherEffectRoot.transform);
                    ps.transform.localPosition = config.particleEffectPos;
                    ParticleSystem.EmissionModule emission = ps.emission;
                    emission.enabled = true;
                    emission.rateOverTime = new ParticleSystem.MinMaxCurve(0);
                    //Burst是在指定的时间点按照指定概率发射一定粒子的事件，这里初始化的时候将其清空
                    emission.SetBursts(new ParticleSystem.Burst[] { });
                    _weatherEffectDict.Add(config.weatherType, ps);
                }
            }
        }
        

        void Update()
        {
            UpdateSunAndMoonPos();
            UpdateColors();
        }

        private void UpdateSunAndMoonPos()
        {
            celestialAxisTransform.eulerAngles = new Vector3(dayTime / 24.0f * 360 - 90, sunRevolution, 0);
        } 

        
        private int _cloudAmbientColorBottomID = Shader.PropertyToID("_CloudAmbientColorBottom");
        private int _cloudAmbientColorTopID = Shader.PropertyToID("_CloudAmbientColorTop");
        private int _sunColorID = Shader.PropertyToID("_SunColor");
        private int _moonColorID = Shader.PropertyToID("_MoonColor");
        private int _attenuationID = Shader.PropertyToID("_Attenuation");
        private int _moonAttenuationID = Shader.PropertyToID("_MoonAttenuation");
        
        private int _cloudCoverageID = Shader.PropertyToID("_CloudCoverage");
        private int _cloudCoverageBiasID = Shader.PropertyToID("_CloudCoverageBias");
        private int _cloudBaseEdgeSoftnessID = Shader.PropertyToID("_CloudBaseEdgeSoftness");
        private int _cloudBottomSoftnessID = Shader.PropertyToID("_CloudBottomSoftness");
        private int _cloudBaseScaleID = Shader.PropertyToID("_CloudBaseScale");
        private int _cloudDetailScaleID = Shader.PropertyToID("_CloudDetailScale");
        private int _cloudDetailStrengthID = Shader.PropertyToID("_CloudDetailStrength");
        private int _cloudDensityID = Shader.PropertyToID("_CloudDensity");
        private int _cloudBottomID = Shader.PropertyToID("_CloudBottom");
        private int _cloudHeightID = Shader.PropertyToID("_CloudHeight");
        
        private void UpdateColors()
        {
            sunLight.color = sunColor.Evaluate(dayTime / 24.0f);
            cloudMaterial.SetColor(_cloudAmbientColorBottomID, cloudBaseColor.Evaluate(dayTime / 24.0f));
            cloudMaterial.SetColor(_cloudAmbientColorTopID, cloudLightColor.Evaluate(dayTime / 24.0f));
            cloudMaterial.SetColor(_sunColorID, sunColor.Evaluate(dayTime / 24.0f));
            cloudMaterial.SetColor(_moonColorID, moonLightColor);
            cloudMaterial.SetFloat(_attenuationID, sunAttenuationCurve.Evaluate(dayTime) * sunAttenuationMultiplier);
            cloudMaterial.SetFloat(_moonAttenuationID, moonAttenuation);
            sunLight.intensity = sunIntensityCurve.Evaluate(dayTime) * sunIntensity;
        }


        private WeatherConfig _curWeatherConfig;
        WeatherType _previousWeatherType;
        WeatherType _currentWeatherType;
        [Button]
        public void ChangeWeather(WeatherType weatherType = WeatherType.HeavyRain)
        {
            _curWeatherConfig = FindWeatherConfig(weatherType);
            if (_curWeatherConfig == null)
            {
                Debug.LogError("Can not find weather config for " + weatherType);
                return;
            }
            _previousWeatherType = _currentWeatherType;
            _currentWeatherType = weatherType;
            
            ChangeCloud();
            ChangeSunColor();
            ChangeWeatherEffect();
        }
        
        private Coroutine _weatherEffectCoroutine;
        private Coroutine _weatherEffectFadeCoroutine;
        private void ChangeWeatherEffect()
        {
            if (_weatherEffectCoroutine != null)
            {
                StopCoroutine(_weatherEffectCoroutine);
            }
            if (_curWeatherConfig.useWeatherEffect)
            {
                _weatherEffectCoroutine = StartCoroutine(WeatherEffectSequence());
            }

            if (_weatherEffectFadeCoroutine != null)
            {
                StopCoroutine(_weatherEffectFadeCoroutine);
            }
            _weatherEffectFadeCoroutine = StartCoroutine(WeatherEffectFadeSequence());
        }

        private IEnumerator WeatherEffectSequence()
        {
            //只有属于降雨类型的才需要等待达到目标云层覆盖率之后再播放
            if (_curWeatherConfig.isPrecipitationWeatherType)
            {
                yield return new WaitUntil(() => cloudMaterial.GetFloat(_cloudCoverageID) >= _curWeatherConfig.cloudProfile.coverage);
            }
                
            ParticleSystem ps = _weatherEffectDict[_curWeatherConfig.weatherType];
            ParticleSystem.EmissionModule emission = ps.emission;
            float curValue = emission.rateOverTime.constant;
            float t = 0;
            while (t < weatherParticleEffectTransitionDuration)
            {
                t += Time.deltaTime;
                    
                float value = Mathf.Lerp(curValue, _curWeatherConfig.particleEffectAmount, t / weatherParticleEffectTransitionDuration);
                emission.rateOverTime = new ParticleSystem.MinMaxCurve(value);
                yield return null;
            }
        }

        private IEnumerator WeatherEffectFadeSequence()
        {
            if (_previousWeatherType == _currentWeatherType || !_weatherEffectDict.ContainsKey(_previousWeatherType))
                yield break;
            
            ParticleSystem ps = _weatherEffectDict[_previousWeatherType];
            ParticleSystem.EmissionModule emission = ps.emission;
            float curValue = emission.rateOverTime.constant;
            float t = 0;
            while (t < weatherParticleEffectTransitionDuration)
            {
                t += Time.deltaTime;
                    
                float value = Mathf.Lerp(curValue, 0, t / weatherParticleEffectTransitionDuration);
                emission.rateOverTime = new ParticleSystem.MinMaxCurve(value);
                yield return null;
            }
        }
        

        private Coroutine _changeSunColorCoroutine;
        private void ChangeSunColor()
        {
            if (_changeSunColorCoroutine != null)
            {
                StopCoroutine(_changeSunColorCoroutine);
            }

            _changeSunColorCoroutine = StartCoroutine(SunColorSequence());
        }

        private IEnumerator SunColorSequence()
        {
            if (_curWeatherConfig.isPrecipitationWeatherType)
            {
                yield return new WaitUntil(() =>
                    cloudMaterial.GetFloat(_cloudCoverageID) >= _curWeatherConfig.cloudProfile.coverage);
                float t = 0;
                while (t < cloudTransitionDuration)
                {
                    t += Time.deltaTime;
                    
                    for (int i = 0; i < _sunColorKeys.Length; i++)
                    {
                        _sunColorKeys[i].color = Color.Lerp(
                            regularSunColor.colorKeys[i].color,
                            stormySunColor.colorKeys[i].color,
                            t / cloudTransitionDuration
                        );
                    }
                    sunColor.SetKeys(_sunColorKeys, regularSunColor.alphaKeys);
                    yield return null;
                }
            }
            else
            {
                sunColor.SetKeys(regularSunColor.colorKeys, regularSunColor.alphaKeys);
                yield break;
            }
        }
        
        
        private WeatherConfig FindWeatherConfig(WeatherType targetType)
        {
            foreach (var config in weatherConfigs)
            {
                if (config.weatherType == targetType)
                {
                    return config;
                }
            }
            return null;
        }

        private IEnumerator ChangeFloatProperties(int propertiesID, float targetValue, float duration)
        {
            float curValue = cloudMaterial.GetFloat(propertiesID);
            float t = 0.0f;
            while (t < duration)
            {
                t += Time.deltaTime;
                float value = Mathf.Lerp(curValue, targetValue, t / duration);
                cloudMaterial.SetFloat(propertiesID, value);
                yield return null;
            }
        }

        #region Change Cloud
        private Coroutine _cloudCoroutine;
        private Coroutine _cloudColorCoroutine;

        private void ChangeCloud()
        {
            if (_cloudCoroutine != null)
            {
                StopCoroutine(_cloudCoroutine);
            }
            _cloudCoroutine = StartCoroutine(ChangeCloudSequence());

            if (_cloudColorCoroutine != null)
            {
                StopCoroutine(_cloudColorCoroutine);
            }
            _cloudColorCoroutine = StartCoroutine(ChangeCloudColorSequence());
        }

        private IEnumerator ChangeCloudColorSequence()
        {
            if (!_curWeatherConfig.isPrecipitationWeatherType)
            {
                cloudBaseColor.SetKeys(regularCloudBaseColor.colorKeys, regularCloudBaseColor.alphaKeys);
                cloudLightColor.SetKeys(regularCloudLightColor.colorKeys, regularCloudLightColor.alphaKeys);
                yield break;
            }

            yield return new WaitUntil(() =>
                cloudMaterial.GetFloat(_cloudCoverageID) >= _curWeatherConfig.cloudProfile.coverage);
            
            float t = 0;
            while (t < cloudTransitionDuration)
            {
                t += Time.deltaTime;
                float progress = t / cloudTransitionDuration;
                for (int i = 0; i < _cloudBaseColorKeys.Length; i++)
                {
                    _cloudBaseColorKeys[i].color = Color.Lerp(
                        _cloudBaseColorKeys[i].color,
                        stormyCloudBaseColor.colorKeys[i].color, 
                        progress);
                }
                cloudBaseColor.SetKeys(_cloudBaseColorKeys, cloudBaseColor.alphaKeys);


                for (int i = 0; i < _cloudLightColorKeys.Length; i++)
                {
                    _cloudLightColorKeys[i].color = Color.Lerp(
                        _cloudLightColorKeys[i].color,
                        stormyCloudLightColor.colorKeys[i].color,
                        progress);
                }
                cloudLightColor.SetKeys(_cloudLightColorKeys, cloudLightColor.alphaKeys);
                yield return null;
            }
        }


        private IEnumerator ChangeCloudSequence()
        {
            CloudProfile cloudProfile = _curWeatherConfig.cloudProfile;
            float targetCoverage = cloudProfile.coverage;
            float curCoverage = cloudMaterial.GetFloat(_cloudCoverageID);
            
            float targetCoverageBias = cloudProfile.coverageBias;
            float curCoverageBias = cloudMaterial.GetFloat(_cloudCoverageBiasID);
                
            float targetBottom = cloudProfile.bottom;
            float curBottom = cloudMaterial.GetFloat(_cloudBottomID);
            
            float targetHeight = cloudProfile.height;
            float curHeight = cloudMaterial.GetFloat(_cloudHeightID);
            
            float targetBaseEdgeSoftness = cloudProfile.baseEdgeSoftness;
            float curBaseEdgeSoftness = cloudMaterial.GetFloat(_cloudBaseEdgeSoftnessID);
            
            float targetBottomSoftness = cloudProfile.bottomSoftness;
            float curBottomSoftness = cloudMaterial.GetFloat(_cloudBottomSoftnessID);
            
            float targetDensity = cloudProfile.density;
            float curDensity = cloudMaterial.GetFloat(_cloudDensityID);

            float targetBaseScale = cloudProfile.baseScale;
            float curBaseScale = cloudMaterial.GetFloat(_cloudBaseScaleID);
            
            float targetDetailScale = cloudProfile.detailScale;
            float curDetailScale = cloudMaterial.GetFloat(_cloudDetailScaleID);
            
            float targetDetailStrength = cloudProfile.detailStrength;
            float curDetailStrength = cloudMaterial.GetFloat(_cloudDetailStrengthID);

            float t = 0;

            while (t < cloudTransitionDuration)
            {
                t += Time.deltaTime;

                float progress = t / cloudTransitionDuration;
                cloudMaterial.SetFloat(_cloudCoverageID, Mathf.Lerp(curCoverage, targetCoverage, progress));
                cloudMaterial.SetFloat(_cloudCoverageBiasID, Mathf.Lerp(curCoverageBias, targetCoverageBias, progress));
                cloudMaterial.SetFloat(_cloudBottomID, Mathf.Lerp(curBottom, targetBottom, progress));
                cloudMaterial.SetFloat(_cloudHeightID, Mathf.Lerp(curHeight, targetHeight, progress));
                cloudMaterial.SetFloat(_cloudBaseEdgeSoftnessID, Mathf.Lerp(curBaseEdgeSoftness, targetBaseEdgeSoftness, progress));
                cloudMaterial.SetFloat(_cloudBottomSoftnessID, Mathf.Lerp(curBottomSoftness, targetBottomSoftness, progress));
                cloudMaterial.SetFloat(_cloudDensityID, Mathf.Lerp(curDensity, targetDensity, progress));
                cloudMaterial.SetFloat(_cloudBaseScaleID, Mathf.Lerp(curBaseScale, targetBaseScale, progress));
                cloudMaterial.SetFloat(_cloudDetailScaleID, Mathf.Lerp(curDetailScale, targetDetailScale, progress));
                cloudMaterial.SetFloat(_cloudDetailStrengthID, Mathf.Lerp(curDetailStrength, targetDetailStrength, progress));
                
                
                
                yield return null;
            }
        }
        #endregion
    }
}
