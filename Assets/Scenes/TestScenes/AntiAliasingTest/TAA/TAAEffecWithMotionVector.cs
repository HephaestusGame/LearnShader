using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using Sirenix.OdinInspector;

namespace HephaestusGame
{
    [RequireComponent(typeof(Camera)), ExecuteInEditMode]
    public class TAAEffecWithMotionVector : MonoBehaviour
    {
        public Shader taaShader;
        private Material _taaMat;

        private Material taaMat
        {
            get
            {
                if (_taaMat == null)
                {
                    taaShader = Shader.Find("Learn/AntiAliasing/TAAWithMotionVector");
                    
                    _taaMat = new Material(taaShader);
                }

                return _taaMat;
            }
        }

        private int changeNum = 0;
        [Button]
        public void ChangeMat()
        {
            changeNum++;
            if ((changeNum %= 2) == 1)
            {
                taaShader = Shader.Find("TAAHLSL");
            }
            else
            {
                taaShader = Shader.Find("Learn/AntiAliasing/TAAWithMotionVector");
            }
            _taaMat = new Material(taaShader);

        }
        
        private int _frameCount = 0;
        private Vector2 _jitter;
        private Camera _camera;
        private RenderTexture[] m_HistoryTextures = new RenderTexture[2];
        private bool m_ResetHistory = true;
        private Vector2[] haltonSequence = new Vector2[]
        {
            new Vector2(0.5f, 1.0f / 3),
            new Vector2(0.25f, 2.0f / 3),
            new Vector2(0.75f, 1.0f / 9),
            new Vector2(0.125f, 4.0f / 9),
            new Vector2(0.625f, 7.0f / 9),
            new Vector2(0.375f, 2.0f / 9),
            new Vector2(0.875f, 5.0f / 9),
            new Vector2(0.0625f, 8.0f / 9),
        };

        private new Camera camera
        {
            get
            {
                if (_camera == null)
                {
                    _camera = GetComponent<Camera>();
                }
                return _camera;
            }
        }

        private void OnEnable()
        {
            camera.depthTextureMode = DepthTextureMode.Depth | DepthTextureMode.MotionVectors;
            camera.useJitteredProjectionMatrixForTransparentRendering = true;
        }

        private void OnPreCull()
        {
            var projMatrix = camera.projectionMatrix;
            camera.nonJitteredProjectionMatrix = projMatrix;
            _frameCount++;
            int index = _frameCount % 8;
            _jitter = new Vector2(
                (haltonSequence[index].x - 0.5f) / camera.pixelWidth,
                (haltonSequence[index].y - 0.5f)/ camera.pixelHeight
                );
            projMatrix.m02 += _jitter.x * 2;
            projMatrix.m12 += _jitter.y * 2;
            camera.projectionMatrix = projMatrix;
        }

        private void OnPostRender()
        {
            camera.ResetProjectionMatrix();
        }

       
        private void OnRenderImage(RenderTexture source, RenderTexture destination)
        {
            var historyRead = m_HistoryTextures[_frameCount % 2];
            if (historyRead == null || historyRead.width != Screen.width || historyRead.height != Screen.height)
            {
                if(historyRead) RenderTexture.ReleaseTemporary(historyRead);
                historyRead = RenderTexture.GetTemporary(Screen.width, Screen.height, 0, RenderTextureFormat.ARGBHalf);
                m_HistoryTextures[_frameCount % 2] = historyRead;
                m_ResetHistory = true;
            }
            var historyWrite = m_HistoryTextures[(_frameCount + 1) % 2];
            if (historyWrite == null || historyWrite.width != Screen.width || historyWrite.height != Screen.height)
            {
                if(historyWrite) RenderTexture.ReleaseTemporary(historyWrite);
                historyWrite = RenderTexture.GetTemporary(Screen.width, Screen.height, 0, RenderTextureFormat.ARGBHalf);
                m_HistoryTextures[(_frameCount + 1) % 2] = historyWrite;
            }
        
            taaMat.SetVector("_Jitter", _jitter);
            taaMat.SetTexture("_HistoryTex", historyRead);
            taaMat.SetInt("_IgnoreHistory", m_ResetHistory ? 1 : 0);
        
            Graphics.Blit(source, historyWrite, taaMat, 0);
            Graphics.Blit(historyWrite, destination);
            m_ResetHistory = false;
        }

        private RenderTexture _historyTexture;
        private RenderTexture _curFrameTexture;
        // private void OnRenderImage(RenderTexture source, RenderTexture destination)
        // {
        //     if (_historyTexture == null)
        //     {
        //         _historyTexture = RenderTexture.GetTemporary(Screen.width, Screen.height, 0, RenderTextureFormat.Default);
        //         Graphics.Blit(source, _historyTexture);
        //     }
        //
        //     if (_curFrameTexture == null)
        //     {
        //         _curFrameTexture = RenderTexture.GetTemporary(Screen.width, Screen.height, 0, RenderTextureFormat.Default);
        //     }
        //     
        //     taaMat.SetTexture("_HistoryTex", _historyTexture);
        //     taaMat.SetFloat("_LerpFactor", 0.1f);
        //     taaMat.SetVector("_Jitter", _jitter);
        //     
        //     
        //     Graphics.Blit(source, _curFrameTexture, taaMat, 0);
        //     Graphics.Blit(_curFrameTexture, destination);
        //     Graphics.Blit(_curFrameTexture, _historyTexture);
        // }
    }
}