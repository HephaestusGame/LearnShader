using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Serialization;

namespace HepheastusGame
{
    [CreateAssetMenu(fileName = "New Cloud Profile", menuName = "Weather System/New Cloud Profile")]
    public class CloudProfile : ScriptableObject
    {
        public string profileName = "New Cloud Profile Name";
        /// <summary>
        /// 云层底部高度
        /// </summary>
        public float bottom = 500;
        /// <summary>
        /// 云层厚度
        /// </summary>
        public float height = 800;
        public float coverage = 0.3f;
        public float coverageBias = 0.0175f;
        public float baseEdgeSoftness = 0.025f;
        public float bottomSoftness = 0.4f;
        public float density = 1f;

        public float baseScale = 1.72f;
        public float detailScale = 1000;
        public float detailStrength = 0.072f;
    }
}
