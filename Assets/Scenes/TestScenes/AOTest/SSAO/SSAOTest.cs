using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using Random = UnityEngine.Random;
using UnityEditor;
using System.IO;
using Sirenix.OdinInspector;

namespace HephaestusGame 
{
    [ExecuteInEditMode]
    [RequireComponent(typeof(Camera))]
    public class SSAOTest : MonoBehaviour
    {
        public bool useNoise = false;
        public bool useRangeCheck;
        public bool useRangeHardCheck;
        public bool blur;
        [Range(0f,1f)]
        public float aoStrength = 0f; 
        [Range(4, 64)]
        public int SampleKernelCount = 64;
        private List<Vector4> sampleKernelList = new List<Vector4>();
        [Range(0.0001f,10f)]
        public float sampleKeneralRadius = 0.01f;
        [Range(0.0001f,1f)]
        public float rangeStrength = 0.001f;
        [Range(1, 4)]
        public int BlurRadius = 2;
        [Range(0, 0.2f)]
        public float bilaterFilterStrength = 0.2f;
        [Range(0, 2)]
        public int DownSample = 0;
        public bool OnlyShowAO = false;
        public bool OnlyShowVisualize = false;
        private Material ssaoMat;
        private Material visualizeMat;
        private void Awake()
        {
            var ssaoShader = Shader.Find("Learn/SSAO");
            ssaoMat = new Material(ssaoShader);
            var visualizeShader = Shader.Find("Test/ViewNormalShader");
            visualizeMat = new Material(visualizeShader);
        }

        private void Start()
        {
            Camera cam = GetComponent<Camera>();
            cam.depthTextureMode = cam.depthTextureMode | DepthTextureMode.DepthNormals;
        }
        
        private void OnRenderImage(RenderTexture src, RenderTexture dest)
        {
            if (OnlyShowVisualize)
            {
                Graphics.Blit(src, dest, visualizeMat);
                return;
            }
            
            GenerateAOSampleKernel();
            int rtW = src.width >> DownSample;
            int rtH = src.height >> DownSample;
            
            //AO
            ssaoMat.SetVectorArray("_SampleKernelArray", sampleKernelList.ToArray());
            ssaoMat.SetFloat("_RangeStrength", rangeStrength);
            ssaoMat.SetFloat("_AOStrength", aoStrength);
            ssaoMat.SetFloat("_SampleKernelCount", sampleKernelList.Count);
            ssaoMat.SetFloat("_SampleKeneralRadius",sampleKeneralRadius);
            ssaoMat.SetTexture("_NoiseTex", Nosie);
            ssaoMat.SetInt("_isRandom", useNoise ? 1 : 0);
            ssaoMat.SetInt("_useRangeCheck", useRangeCheck ? 1 : 0);
            ssaoMat.SetInt("_useRangeHardCheck", useRangeHardCheck ? 1 : 0);
            ssaoMat.SetInt("_NoiseUnit", Nosie.width);
            RenderTexture aoRT = RenderTexture.GetTemporary(rtW,rtH,0);
            Graphics.Blit(src, aoRT, ssaoMat, 0);
            
            //Blur
            RenderTexture blurRT = RenderTexture.GetTemporary(rtW,rtH,0);
            if (blur)
            {
                ssaoMat.SetFloat("_BilaterFilterFactor", 1.0f - bilaterFilterStrength);
                ssaoMat.SetVector("_BlurRadius", new Vector4(BlurRadius, 0, 0, 0));
                Graphics.Blit(aoRT, blurRT, ssaoMat, 1);
                ssaoMat.SetVector("_BlurRadius", new Vector4(0, BlurRadius, 0, 0));
                Graphics.Blit(blurRT, aoRT, ssaoMat, 1);
            }
            
            
            if (OnlyShowAO)
            {
                Graphics.Blit(aoRT, dest);
            }
            else
            {
                
                ssaoMat.SetTexture("_AOTex", aoRT);
                Graphics.Blit(src, dest, ssaoMat, 2);
            }
            
            RenderTexture.ReleaseTemporary(aoRT);
            
            
            RenderTexture.ReleaseTemporary(blurRT);
        }

        private void GenerateAOSampleKernel()
        { 
            if (SampleKernelCount == sampleKernelList.Count)
                return;
            sampleKernelList.Clear();
            for (int i = 0; i < SampleKernelCount; i++)
            {
                var vec = new Vector4(Random.Range(-1.0f, 1.0f), Random.Range(-1.0f, 1.0f), Random.Range(0, 1.0f), 1.0f);
                vec.Normalize();
                var scale = (float)i / SampleKernelCount;
                //使分布符合二次方程的曲线
                scale = Mathf.Lerp(0.01f, 1.0f, scale * scale);
                vec *= scale;
                sampleKernelList.Add(vec);
            }
        }

        [FoldoutGroup("Noise")]
        public Texture Nosie;//噪声贴图
        [FoldoutGroup("Noise")]
        public int noiseUnit = 4;
        [FoldoutGroup("Noise")]
        public float scale = 1;
        
        [Button]
        private void GenerateNoise()
        {
            var tex = new Texture2D(noiseUnit, noiseUnit);
            tex.filterMode = FilterMode.Point;
            tex.wrapMode = TextureWrapMode.Repeat;
            for (int x = 0; x < noiseUnit; x++)
            {
                for (int y = 0; y < noiseUnit; y++)
                {
                    Vector3 randVec = new Vector3(Random.Range(-1.0f, 1.0f), Random.Range(-1.0f, 1.0f), Random.Range(0, 1.0f));
                    randVec = randVec * 2 - Vector3.one;
                    randVec.Normalize();
                    tex.SetPixel(x, y, new Color(randVec.x, randVec.y, randVec.z));
                }
            }

            tex.Apply();
            Nosie = tex;
        }
    }
}
