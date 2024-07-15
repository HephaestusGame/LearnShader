using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Serialization;

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
        public Color moonLightColor;
        public Gradient cloudLightColor;
        public Gradient cloudBaseColor;
        public AnimationCurve sunIntensityCurve = AnimationCurve.Linear(0, 0, 24, 5);
        public AnimationCurve sunAttenuationCurve = AnimationCurve.Linear(0, 1, 24, 3);

        
        public Light sunLight;
        public Transform celestialAxisTransform;

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
        
        
    }
}
