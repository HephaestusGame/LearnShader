using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace HephaestusGame
{
    [RequireComponent(typeof(Camera)), ExecuteInEditMode]
    public class TAAEffect : MonoBehaviour
    {
        public Shader taaShader;
        [Range(0, 1)]
        public float lerpFactor;
        [Range(0, 1)]
        public float jitterAmount = 1;
        private Material _taaMat;

        private Material taaMat
        {
            get
            {
                if (_taaMat == null)
                {
                    taaShader = Shader.Find("Learn/AntiAliasing/TAA");
                    _taaMat = new Material(taaShader);
                }

                return _taaMat;
            }
        }
        
        private int _sampleCount = 8;
        public int sampleCount
        {
            get
            {
                return _sampleCount;
            }
            set
            {
                _sampleCount = value;
                _haltonSequence = HaltonSequence.GenerateSequence(value, 2, 3);
            }
        }
        private Vector2[] _haltonSequence= new Vector2[]
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
        private int _frameCount = 0;
        private Vector2 _jitter;
        private Camera _camera;

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
        
        private void Start()
        {
            sampleCount = 8;
            _camera = GetComponent<Camera>();

        }

        private void OnPreCull()
        {
            _frameCount++;
            int index = _frameCount % sampleCount;
            _jitter = new Vector2(
                (_haltonSequence[index].x * 2 - 1) / camera.pixelWidth,
                (_haltonSequence[index].y * 2 - 1) / camera.pixelHeight
                );
            _jitter *= jitterAmount;
            var projMatrix = camera.projectionMatrix;
            projMatrix.m02 += _jitter.x;
            projMatrix.m12 += _jitter.y;
            camera.projectionMatrix = projMatrix;
        }

        private void OnPostRender()
        {
            camera.ResetProjectionMatrix();
        }


        private RenderTexture _historyTexture;
        private RenderTexture _curFrameTexture;
        private void OnRenderImage(RenderTexture source, RenderTexture destination)
        {
            if (_historyTexture == null)
            {
                _historyTexture = RenderTexture.GetTemporary(Screen.width, Screen.height, 0, RenderTextureFormat.Default);
                Graphics.Blit(source, _historyTexture);
            }

            if (_curFrameTexture == null)
            {
                _curFrameTexture = RenderTexture.GetTemporary(Screen.width, Screen.height, 0, RenderTextureFormat.Default);
            }
            
            taaMat.SetTexture("_HistoryTex", _historyTexture);
            taaMat.SetFloat("_LerpFactor", lerpFactor);
            
            Graphics.Blit(source, _curFrameTexture, taaMat, 0);
            Graphics.Blit(_curFrameTexture, destination);
            Graphics.Blit(_curFrameTexture, _historyTexture);
        }
    }
}