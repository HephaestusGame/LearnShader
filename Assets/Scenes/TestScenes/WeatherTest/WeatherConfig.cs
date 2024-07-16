using System.Collections;
using System.Collections.Generic;
using Sirenix.OdinInspector;
using UnityEngine;

namespace HepheastusGame
{
    public enum WeatherType
    {
        HeavyRain = 0,
        Cloudy = 1,
    }
    
    [CreateAssetMenu(fileName = "New Weather Config", menuName = "Weather System/New Weather Config")]
    public class WeatherConfig : ScriptableObject
    {
        public string weatherConfigName = "New Weather Config";
        public WeatherType weatherType;
        

        public bool isPrecipitationWeatherType = false;
        
        
        public float sunIntensity = 1;
        
        //Cloud
        [FoldoutGroup("Cloud")]
        public CloudProfile cloudProfile;
        [FoldoutGroup("Cloud")]
        
        //Audio
        [FoldoutGroup("Audio")]
        public bool useWeatherSound = false;
        [FoldoutGroup("Audio")]
        public float weatherVolume = 1;
        [FoldoutGroup("Audio")]
        public AudioClip weatherSound;
        
        //Particle Effect
        [FoldoutGroup("Particle Effect")]
        public bool useWeatherEffect = false;
        [FoldoutGroup("Particle Effect")]
        public ParticleSystem wetherEffect;
        [FoldoutGroup("Particle Effect")]
        public int particleEffectAmount = 200;
        [FoldoutGroup("Particle Effect")]
        public Vector3 particleEffectPos = new Vector3(0, 28, 0);
    }
}
