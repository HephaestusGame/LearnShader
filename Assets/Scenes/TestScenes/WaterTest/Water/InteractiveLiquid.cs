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

        //k1,k2,k3,d
        private Vector4 _liquidParams;
        private InteractiveSampleCamera _interactiveSampleCamera;
        void Start()
        {
            _instance = this;
            if (CalculateLiquidParams())
            {
                CreateSampleCamera();
            }
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

        private void CreateSampleCamera()
        {
            if (waterPlane == null)
                return;
            
            GameObject cameraGO = new GameObject("InteractiveSampleCamera");
            cameraGO.transform.SetParent(transform);
            cameraGO.transform.position = waterPlane.bounds.center;
            cameraGO.transform.rotation = Quaternion.Euler(90, waterPlane.transform.rotation.eulerAngles.y, 0);

            _interactiveSampleCamera = cameraGO.AddComponent<InteractiveSampleCamera>();
            Bounds bounds = waterPlane.bounds;
            _interactiveSampleCamera.Init(bounds.size.x, bounds.size.z, waterDepth, forceFactor, _liquidParams, heightMapSize, forceShader, waveEquationShader, generateNormalShader);
        }
    }
}
