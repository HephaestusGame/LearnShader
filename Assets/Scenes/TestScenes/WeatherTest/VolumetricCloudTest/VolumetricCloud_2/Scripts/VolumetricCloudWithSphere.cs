using Sirenix.OdinInspector;
using UnityEngine;
using UnityEngine.Rendering;

namespace HepheastusGame
{
    public class VolumetricCloudWithSphere : MonoBehaviour
    {
        public Material skyMaterial;
        public Material cloudSphereMaterial;

        public Light sun;
        public Light moon;
        #region settings

        [FoldoutGroup("CloudShapeTexture")]
        public bool useCloudShapeCurve = true;
        [FoldoutGroup("CloudShapeTexture")]
        public AnimationCurve cloudShapeCurve = AnimationCurve.Linear(0, 0, 1, 1);
        [FoldoutGroup("CloudShapeTexture")]
        public Texture2D cloudShapeTexture = null;
        [FoldoutGroup("CloudShapeTexture"), Range(8, 1024)]
        public int cloudShapeTextureResolution = 512;
        
        [Range(10, 200)]
        public int cloudDomeTrisCountX = 100;
        [Range(10, 50)]
        public int cloudDomeTrisCountY = 50;
        [Range(128, 4096)]
        public int cloudTexSize = 1024;

        public bool useHaltonSequence = true;
        public Texture baseNoise = null;
        public Texture detailNoise = null;
        public float cloudBottom = 500;
        public float cloudHeight = 1000;

        [Range(1, 1024)]
        public int cloudMarchSteps = 100;

        public float cloudBaseScale = 1.72f;
        public float cloudDetailScale = 1000;
        public float horizonFadeStart = 0.0f;
        public float horizonFadeEnd = 0.18f;

        [Range(0.0f, 5.0f)]
        public float cloudAlpha = 1.0f;

        public float cloudDetailStrength = 0.072f;

        public float attenuation = 1.5f;
        public float moonAttenuation = 0.1f;
        public float cloudBaseEdgeSoftness = 0.025f;
        public float cloudBottomSoftness = 0.4f;

        [Range(0.0f, 1.0f)]
        public float cloudDensity = 0.313f;

        public Color lightningColor = new Color(.76f, .83f, .88f, 1.0f);
        public Color cloudColor = new Color(0.8431f, 0.8431f, 0.8431f, 1.0f);
        public Color cloudAmbientColorBottom = new Color(0.7549f, .7903f, .8207f, 1.0f);
        public Color cloudAmbientColorTop = new Color(.51f, .55f, .60f, 1.0f);
        public float lightning = 0;

        [Range(0.0f, 150.0f)]
        public float cloudMovementSpeed = 20.0f;
        [Range(0.0f, 50f)]
        public float cloudTurbulenceSpeed = 50.0f;

        #endregion

        private int _sunDirID = Shader.PropertyToID("_SunDir");
        private int _moonDirID = Shader.PropertyToID("_MoonDir");
       
        private int _attenuationID = Shader.PropertyToID("_Attenuation");
        private int _moonAttenuationID = Shader.PropertyToID("_MoonAttenuation");
        
        private int _cloudAlphaID = Shader.PropertyToID("_CloudAlpha");
        private int _cloudShapeTextureID = Shader.PropertyToID("_CloudShapeTexture");

        private int _cloudMarchStepsID = Shader.PropertyToID("_CloudMarchSteps");
        private int _cloudCoverageID = Shader.PropertyToID("_CloudCoverage");
        private int _cloudCoverageBiasID = Shader.PropertyToID("_CloudCoverageBias");
        private int _cloudBaseEdgeSoftnessID = Shader.PropertyToID("_CloudBaseEdgeSoftness");
        private int _cloudBottomSoftnessID = Shader.PropertyToID("_CloudBottomSoftness");
        private int _cloudBaseScaleID = Shader.PropertyToID("_CloudBaseScale");
        private int _cloudDetailScaleID = Shader.PropertyToID("_CloudDetailScale");
        private int _cloudDetailStrengthID = Shader.PropertyToID("_CloudDetailStrength");
        private int _cloudDensityID = Shader.PropertyToID("_CloudDensity");
        
        private int _baseNoiseID = Shader.PropertyToID("_BaseNoise");
        private int _detailNoiseID = Shader.PropertyToID("_DetailNoise");
        private int _lightningID = Shader.PropertyToID("_Lightning");
        private int _horizonFadeStartID = Shader.PropertyToID("_HorizonFadeStart");
        private int _horizonFadeEndID = Shader.PropertyToID("_HorizonFadeEnd");

        private int _lightningColorID = Shader.PropertyToID("_LightningColor");
        private int _cloudColorID = Shader.PropertyToID("_CloudColor");
        private int _cloudAmbientColorBottomID = Shader.PropertyToID("_CloudAmbientColorBottom");
        private int _cloudAmbientColorTopID = Shader.PropertyToID("_CloudAmbientColorTop");

        private int _cloudMovementSpeedID = Shader.PropertyToID("_CloudMovementSpeed");
        private int _cloudTurbulenceSpeedID = Shader.PropertyToID("_CloudTurbulenceSpeed");
        private int _baseCloudOffsetID = Shader.PropertyToID("_BaseCloudOffset");
        private int _detailCloudOffsetID = Shader.PropertyToID("_DetailCloudOffset");
        private int _texSizeID = Shader.PropertyToID("_TexSize");
        private int _jitterID = Shader.PropertyToID("_Jitter");

        private float _baseCloudOffset = 0;
        private float _detailCloudOffset = 0;


        private CommandBuffer _cmd;

        static public VolumetricCloudWithSphere instance; 
        private void Start()
        {
            _cmd = new CommandBuffer();
            _cmd.name = "VolumetricCloud";
            Camera.main.AddCommandBuffer(CameraEvent.AfterSkybox, _cmd);
            instance = this;
            
            GetComponent<MeshFilter>().sharedMesh = ProceduralHemispherePolarUVs.hemisphere;
        }

        private void Update()
        {
            if (skyMaterial != null)
            {
                InitCloudBuffers();
                
                skyMaterial.SetVector(_sunDirID, sun.transform.forward);
                skyMaterial.SetVector(_moonDirID, moon.transform.forward);
                skyMaterial.SetFloat(_cloudMovementSpeedID, cloudMovementSpeed);
                skyMaterial.SetFloat(_cloudTurbulenceSpeedID, cloudTurbulenceSpeed);
                _baseCloudOffset += cloudMovementSpeed * Time.deltaTime;
                _detailCloudOffset += cloudTurbulenceSpeed * Time.deltaTime;
                skyMaterial.SetFloat(_baseCloudOffsetID, _baseCloudOffset);
                skyMaterial.SetFloat(_detailCloudOffsetID, _detailCloudOffset);
                
                skyMaterial.SetFloat(_texSizeID, cloudTexSize);


                skyMaterial.SetInt(_cloudMarchStepsID, cloudMarchSteps);
                
                skyMaterial.SetFloat(_horizonFadeStartID, horizonFadeStart);
                skyMaterial.SetFloat(_horizonFadeEndID, horizonFadeEnd);
                skyMaterial.SetFloat(_cloudAlphaID, cloudAlpha);
                
                skyMaterial.SetColor(_lightningColorID, lightningColor);
                skyMaterial.SetColor(_cloudColorID, cloudColor);

                
                skyMaterial.SetFloat(_lightningID, lightning);
                SetRayMarchOffset();

                CreateCloudShapeTextureFromCurve();
                SetTextures();

                RenderCloud();
                
            }
        }

        
        
        private AnimationCurve _previousCurve = new AnimationCurve();
        private void CreateCloudShapeTextureFromCurve()
        {
            if (!useCloudShapeCurve)
            {
                skyMaterial.DisableKeyword("USE_CLOUD_SHAPE_CURVE");
                return;
            }
            skyMaterial.EnableKeyword("USE_CLOUD_SHAPE_CURVE");
            
            if (cloudShapeTexture == null)
            {
                cloudShapeTexture = new Texture2D(cloudShapeTextureResolution, 1, TextureFormat.RHalf, false, true);
                cloudShapeTexture.filterMode = FilterMode.Bilinear;
                cloudShapeTexture.wrapMode = TextureWrapMode.Clamp;
            }
            

            if (cloudShapeCurve.Equals(_previousCurve))
            {
                // Debug.Log("Same curve, skipping texture creation");
                return;
            }
            // Debug.Log("Creating new cloud shape texture");
            
            _previousCurve.CopyFrom(cloudShapeCurve);

            for (int i = 0; i < cloudShapeTextureResolution; i++)
            {
                float percent = (float)i / cloudShapeTextureResolution;
                float density = cloudShapeCurve.Evaluate(percent);
                cloudShapeTexture.SetPixel(i, 0, new Color(density, density, density, 1));
            }
            cloudShapeTexture.Apply();
        }
        
        private int _lowResCloudBufferID = Shader.PropertyToID("_LowResCloudTex");
        private int _previousCloudBufferID = Shader.PropertyToID("_PreviousCloudTex");
        private int _cloudTexID = Shader.PropertyToID("_CloudTex");
        private int _frameCount = 0;
        private int _fullBufferIndex = 0;
        private void RenderCloud()
        {
            _frameCount++;
            if (_frameCount < 32)
            {
                skyMaterial.EnableKeyword("PREWARM");
            }
            else
            {
                skyMaterial.DisableKeyword("PREWARM");
            }
            
            _fullBufferIndex = _fullBufferIndex ^ 1;

            _cmd.Clear();
            _cmd.Blit(null, _lowResCloudBuffer, skyMaterial, 0);

            skyMaterial.SetTexture(_lowResCloudBufferID, _lowResCloudBuffer);
            skyMaterial.SetTexture(_previousCloudBufferID, _fullCloudBuffer[_fullBufferIndex]);
            _cmd.Blit(_fullCloudBuffer[_fullBufferIndex], _fullCloudBuffer[_fullBufferIndex ^ 1], skyMaterial, 1);
            cloudSphereMaterial.SetTexture("_MainTex", _fullCloudBuffer[_fullBufferIndex ^ 1]);
        }
        
        private void SetTextures()
        {
            if (cloudShapeTexture != null)
            {
                skyMaterial.SetTexture(_cloudShapeTextureID, cloudShapeTexture);
            }
            
            if (baseNoise != null)
            {
                skyMaterial.SetTexture(_baseNoiseID, baseNoise);
            }

            if (detailNoise != null)
            {
                skyMaterial.SetTexture(_detailNoiseID, detailNoise);
            }
        }

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
        
        private RenderTexture[] _fullCloudBuffer = new RenderTexture[2];
        private RenderTexture _lowResCloudBuffer;
        private void InitCloudBuffers()
        {
            int size = cloudTexSize;
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
        private void SetRayMarchOffset()
        {
            if (!useHaltonSequence)
            {
                skyMaterial.SetFloat(_raymarchOffsetID, 0);
                return;
            }
            _frameIndex = (_frameIndex + 1) % 16;
            if (_frameIndex == 0)
                _haltonSequenceIndex = (_haltonSequenceIndex + 1) % _haltonSequence.Length;
            
            float offsetX = _offset[_frameIndex, 0];
            float offsetY = _offset[_frameIndex, 1];
            skyMaterial.SetVector(_jitterID, new Vector2(offsetX, offsetY));
            skyMaterial.SetFloat(_raymarchOffsetID, (_haltonSequence[_haltonSequenceIndex] / 16.0f + _bayerOffsets[_offset[_frameIndex, 0], _offset[_frameIndex, 1]] / 16.0f));

        }
        #endregion

        private void OnDestroy()
        {
            ReleaseCloudBuffers();
        }
    }
}
