using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace HephaestusGame
{
    [ExecuteInEditMode]
    [RequireComponent(typeof(Camera))]
    public class HBAO : MonoBehaviour
    {
        public bool onlyShowAO = true;
        
        /// <summary>
        /// HBAO检测方向
        /// </summary>
        public enum DIRECTION
        {
            DIRECTION_4,
            DIRECTION_6,
            DIRECTION_8,
        }
        /// <summary>
        /// HBAO特定方向统计次数
        /// </summary>
        public enum STEP
        {
            STEPS_4,
            STEPS_6,
            STEPS_8,
        }
        [SerializeField]
        DIRECTION mDir = DIRECTION.DIRECTION_4;
        [SerializeField]
        STEP mStep = STEP.STEPS_4;
        /// <summary>
        /// AO强度
        /// </summary>
        [SerializeField]
        [Range(0, 3f)]
        float mAOStrength = 0.5f;
        /// <summary>
        /// 最大检测像素半径
        /// </summary>
        [SerializeField]
        [Range(16, 256)]
        int mMaxRadiusPixel = 32;
        /// <summary>
        /// 检测半径
        /// </summary>
        [SerializeField]
        [Range(0.1f, 50)]
        float mRadius = 0.5f;
        /// <summary>
        /// 偏移角
        /// </summary>
        [SerializeField]
        [Range(0, 0.9f)]
        float mAngleBias = 0.1f;
        /// <summary>
        /// 模糊采样次数
        /// </summary>
        [SerializeField]
        bool mEnableBlur = true;
        /// <summary>
        /// 模糊半径
        /// </summary>
        [SerializeField]
        [Range(5, 20)]
        int mBlurRadiusPixel = 10;
        /// <summary>
        /// 模糊采样次数
        /// </summary>
        [SerializeField]
        [Range(2, 10)]
        int mBlurSamples = 4;
        [SerializeField]
        /// <summary>
        // 是否开启高斯模糊
        /// </summary>
        bool mGuassBlur = false;
        
        Camera _camera;
        private Camera mCamera
        {
            get
            {
                if (_camera != null)
                    return _camera;
                _camera = GetComponent<Camera>();
                _camera.depthTextureMode = DepthTextureMode.DepthNormals;
                return _camera;
            }
        }
        
        private static class ShaderProperties
        {
            public static int MainTex;
            public static int HbaoTex;
            public static int HbaoBlurTex;
            public static int UV2View;
            public static int TexelSize;
            public static int AOStrength;
            public static int MaxRadiusPixel;
            public static int RadiusPixel;
            public static int Radius;
            public static int AngleBias;
            public static int BlurRadiusPixel;
            public static int BlurSamples;
            public static int BlurDir;
            
            static ShaderProperties()
            {
                MainTex = Shader.PropertyToID("_MainTex");
                HbaoTex = Shader.PropertyToID("_HbaoTex");
                HbaoBlurTex = Shader.PropertyToID("_HbaoBlurTex");
                AOStrength = Shader.PropertyToID("_AOStrengh");
                MaxRadiusPixel = Shader.PropertyToID("_MaxRadiusPixel");
                RadiusPixel = Shader.PropertyToID("_RadiusPixel");
                Radius = Shader.PropertyToID("_Radius");
                AngleBias = Shader.PropertyToID("_AngleBias");
                BlurRadiusPixel = Shader.PropertyToID("_BlurRadiusPixel");
                BlurSamples = Shader.PropertyToID("_BlurSamples");
                BlurDir = Shader.PropertyToID("_BlurDir");
            }
        }
        private string[] mShaderKeywords = new string[4] 
        {
            "DIRECTION_4" ,
            "STEPS_4",
            "ENABLEBLUR",
            "GUASSBLUR",
        };
        
        private Material hbaoMat;
        private void Awake()
        {
            var hbaoShader = Shader.Find("Learn/HBAO");
            hbaoMat = new Material(hbaoShader);
        }
        
        void UpdateMaterialProperties()
        {
            var tanHalfFovY = Mathf.Tan(mCamera.fieldOfView * 0.5f * Mathf.Deg2Rad);
            var tanHalfFovX = tanHalfFovY * ((float)mCamera.pixelWidth / mCamera.pixelHeight);
            //当z=1时,半径为radius对应的屏幕像素
            hbaoMat.SetFloat(ShaderProperties.RadiusPixel, mCamera.pixelHeight * mRadius / tanHalfFovY / 2);
            hbaoMat.SetFloat(ShaderProperties.Radius, mRadius);
            hbaoMat.SetFloat(ShaderProperties.MaxRadiusPixel, mMaxRadiusPixel);
            hbaoMat.SetFloat(ShaderProperties.AngleBias, mAngleBias);
            hbaoMat.SetFloat(ShaderProperties.BlurRadiusPixel, mBlurRadiusPixel);
            hbaoMat.SetInt(ShaderProperties.BlurSamples, mBlurSamples);
            hbaoMat.SetFloat(ShaderProperties.AOStrength, mAOStrength);
        }
        
        void UpdateShaderKeywords()
        {
            mShaderKeywords[0] = mDir.ToString();
            mShaderKeywords[1] = mStep.ToString();
            mShaderKeywords[2] = mEnableBlur ? "ENABLEBLUR" : "__";
            mShaderKeywords[3] = mGuassBlur ? "GUASSBLUR" : "__";

            hbaoMat.shaderKeywords = mShaderKeywords;
        }

        private void OnRenderImage(RenderTexture src, RenderTexture dest)
        {
            UpdateMaterialProperties();
            UpdateShaderKeywords();
            if (onlyShowAO)
            {
                Graphics.Blit(src, dest, hbaoMat, 0);
            }
            else
            {
                RenderTexture aoTex = RenderTexture.GetTemporary(_camera.pixelWidth, _camera.pixelHeight, 0);
                Graphics.Blit(src, aoTex, hbaoMat, 0);
                hbaoMat.SetTexture("_AOTex", aoTex);
                Graphics.Blit(src, dest, hbaoMat, 1);
                RenderTexture.ReleaseTemporary(aoTex);
            }
        }
    }
}