using System;
using System.Collections;
using System.Collections.Generic;
using Sirenix.OdinInspector;
using UnityEngine;

namespace HephaestusGame
{
    public class InteractiveLiquid : MonoBehaviour
    {
        private static InteractiveLiquid _instance;
        
        public static void DrawMesh(Mesh mesh, Matrix4x4 matrix)
        {
            if (_instance == null)
                return;
            _instance._interactiveSampleCamera.DrawMesh(mesh, matrix);
        }
        
        public Shader forceShader;
        public Shader waveEquationShader;
        public Shader generateNormalShader;
        
        public MeshRenderer waterPlane;
        [Min(0.00001f)]
        public float viscosity = 0.1f;
        [Range(0.00001f, 0.99f)]
        public float speed = 0.1f;

        public float forceFactor = 1.0f;
        public float waterDepth = 10;
        [Min(1)]
        public int heightMapSize = 128;

        
        [FoldoutGroup("Caustics")]
        public Material causticsMaterial;
        [FoldoutGroup("Caustics")]
        public float causticsIntensity = 1.0f;
        
        [FoldoutGroup("ReflectionCamera")]
        public int reflectionTextureSize = 512;
        
        //k1,k2,k3,d
        private Vector4 _liquidParams;
        private InteractiveSampleCamera _interactiveSampleCamera;
        private ReflectionCamera _reflectionCamera;
        void Start()
        {
            _instance = this;
            if (CalculateLiquidParams())
            {
                CreateSampleCamera();
            }

            CreateReflectionCamera();
            // Application.targetFrameRate = 120;
        }

        private void CreateReflectionCamera()
        {
            _reflectionCamera = gameObject.AddComponent<ReflectionCamera>();
            MeshRenderer filter = GetComponent<MeshRenderer>();
            Material mat = filter.sharedMaterial;
            _reflectionCamera.Init(mat, waterPlane.transform, reflectionTextureSize);
        }
        
        private bool CalculateLiquidParams()
        {
            float d = 1.0f / heightMapSize;
            float t = Time.fixedDeltaTime;


            float muTPlus2 = viscosity * t + 2;//μt + 2

            float maxVelocity = d / (2 * t) * Mathf.Sqrt(muTPlus2);
            float c = maxVelocity * speed;//公式中的 c
            float cSquare = c * c;//c^2
            float muSquare = viscosity * viscosity;//μ^2
            float dSquare = d * d;//d^2
            
            float maxT = (viscosity + Mathf.Sqrt(muSquare + 32 * cSquare / dSquare)) / (8 * cSquare / dSquare);
            if (t > maxT)
            {
                Debug.LogError("粘度系数不符合要求");
                return false;
            }
            
            float k1 = (4 - 8 * cSquare * t * t / dSquare) / muTPlus2;
            float k2 = (viscosity * t - 2) / muTPlus2;
            float k3 = 2 * cSquare * t * t / dSquare / muTPlus2;

            _liquidParams = new Vector4(k1, k2, k3, d);
            return true;
        }

        private void Update()
        {
            if (_interactiveSampleCamera != null)
            {
                UpdateWaterParamsIfNeed();
                _interactiveSampleCamera.UpdateForceFactor(forceFactor);
            }

            if (_causticsRenderer != null)
            {
                _causticsRenderer.causticsIntensity = causticsIntensity;
            }
        }

        
        private float _previousViscosity;
        private float _previousSpeed;
        private void UpdateWaterParamsIfNeed()
        {
            if (Math.Abs(viscosity - _previousViscosity) < Mathf.Epsilon && Math.Abs(speed - _previousSpeed) < Mathf.Epsilon)
                return;
            if (CalculateLiquidParams())
            {
                _previousViscosity = viscosity;
                _previousSpeed = speed;
                _interactiveSampleCamera.UpdateWaveParams(_liquidParams);
            }
        }

        private void CreateSampleCamera()
        {
            if (waterPlane == null)
                return;

            CreateWaveCamera();
            CreateCausticsCamera();
            Shader.SetGlobalFloat("_InteractiveWaterMaxHeight", waterDepth);
        }

        private void CreateWaveCamera()
        {
            GameObject cameraGO = new GameObject("InteractiveSampleCamera");
            cameraGO.transform.SetParent(transform);
            cameraGO.transform.position = waterPlane.bounds.center;
            cameraGO.transform.rotation = Quaternion.Euler(90, waterPlane.transform.rotation.eulerAngles.y, 0);
            

            _interactiveSampleCamera = cameraGO.AddComponent<InteractiveSampleCamera>();
            Bounds bounds = waterPlane.bounds;
            _interactiveSampleCamera.Init(bounds.size.x, bounds.size.z, waterDepth, forceFactor, _liquidParams, heightMapSize, 
                forceShader, waveEquationShader, generateNormalShader);
        }
        
        private CausticsRenderer _causticsRenderer;
        private void CreateCausticsCamera()
        {
            GameObject causticsRenderer = new GameObject("CausticsRenderer");
            causticsRenderer.transform.SetParent(transform);
            causticsRenderer.transform.position = waterPlane.bounds.center;
            causticsRenderer.transform.rotation = Quaternion.Euler(90, waterPlane.transform.rotation.eulerAngles.y, 0);
            _causticsRenderer = causticsRenderer.AddComponent<CausticsRenderer>();
            _causticsRenderer.Init(causticsIntensity, waterDepth, waterPlane, causticsMaterial);
        }
    }
}
