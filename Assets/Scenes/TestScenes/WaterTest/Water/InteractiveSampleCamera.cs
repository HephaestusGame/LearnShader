using System;
using System.Collections;
using System.Collections.Generic;
using Sirenix.OdinInspector;
using UnityEngine;
using UnityEngine.Rendering;

namespace HephaestusGame
{
    public class InteractiveSampleCamera : MonoBehaviour
    {
        private Vector4 _waveParams;
        private Camera _camera;
        private CommandBuffer _commandBuffer;
        private Material _forceMaterial;
        private Material _waveEquationMaterial;
        private Material _generateNormalMaterial;
        
        public RenderTexture _curTexture;
        public RenderTexture _preTexture;
        public RenderTexture _heightMap;
        public RenderTexture _normalMap;

        public void DrawMesh(Mesh mesh, Matrix4x4 matrix)
        {
            if (!mesh)
                return;
            _commandBuffer.DrawMesh(mesh, matrix, _forceMaterial);
        }

        public void Init(
            float width, float height, float depth, float forceFactor, Vector4 waveParams, int texSize,
            Shader forceShader, Shader waveEquationShader, Shader generateNormalShader)
        {
            _waveParams = waveParams;

            _camera = gameObject.AddComponent<Camera>();
            _camera.aspect = width / height;
            _camera.backgroundColor = Color.black;
            _camera.cullingMask = 0;
            _camera.depth = 0;
            _camera.farClipPlane = depth;
            _camera.nearClipPlane = 0;
            _camera.orthographic = true;
            _camera.orthographicSize = height * 0.5f;
            _camera.clearFlags = CameraClearFlags.Depth;
            _camera.allowHDR = false;

            _commandBuffer = new CommandBuffer();
            _camera.AddCommandBuffer(CameraEvent.AfterImageEffectsOpaque, _commandBuffer);
            _forceMaterial = new Material(forceShader);

            RenderTextureReadWrite readWrite = RenderTextureReadWrite.Linear;
            _curTexture = RenderTexture.GetTemporary(texSize, texSize, 16, RenderTextureFormat.ARGB32, readWrite);
            _curTexture.name = "CurTexture";
            _preTexture = RenderTexture.GetTemporary(texSize, texSize, 16, RenderTextureFormat.ARGB32, readWrite);
            _preTexture.name = "PreTexture";
            _heightMap = RenderTexture.GetTemporary(texSize, texSize, 16, RenderTextureFormat.ARGB32, readWrite);
            _heightMap.name = "HeightMap";
            _normalMap = RenderTexture.GetTemporary(texSize, texSize, 16, RenderTextureFormat.ARGB32, readWrite);
            _normalMap.name = "NormalMap";
            // _normalMap.anisoLevel = 1;

            ClearRT();

            _camera.targetTexture = _curTexture;
            Shader.SetGlobalFloat("_InternalForce", forceFactor);
            
            _waveEquationMaterial = new Material(waveEquationShader);
            _waveEquationMaterial.SetVector("_WaveParams", _waveParams);
            _generateNormalMaterial = new Material(generateNormalShader);
        }

        [Button]
        private void ClearRT()
        {
            RenderTexture tmp = RenderTexture.active;
            RenderTexture.active = _curTexture;
            GL.Clear(false, true, new Color(0, 0, 0, 0));
            RenderTexture.active = _preTexture;
            GL.Clear(false, true, new Color(0, 0, 0, 0));
            RenderTexture.active = _heightMap;
            GL.Clear(false, true, new Color(0, 0, 0, 0));
            RenderTexture.active = tmp;
        }

        /// <summary>
        /// 在CameraEvent.AfterImageEffectsOpaque之后执行
        /// </summary>
        private void OnPostRender()
        {
            _commandBuffer.Clear();
            _commandBuffer.ClearRenderTarget(true, false, Color.black);
            
            _waveEquationMaterial.SetTexture("_PreTex", _preTexture);
            _commandBuffer.Blit(_curTexture, _heightMap, _waveEquationMaterial);
            _commandBuffer.Blit(_heightMap, _normalMap, _generateNormalMaterial);
            _commandBuffer.Blit(_curTexture, _preTexture);
            _commandBuffer.Blit(_heightMap, _curTexture);


            Shader.SetGlobalTexture("_InteractiveWaterHeightMap", _heightMap);
            Shader.SetGlobalTexture("_InteractiveWaterNormalMap", _normalMap);
        }

        private void OnDestroy()
        {
            if (_forceMaterial)
                Destroy(_forceMaterial);
            if (_waveEquationMaterial)
                Destroy(_waveEquationMaterial);
            if (_generateNormalMaterial)
                Destroy(_generateNormalMaterial);
            
            if (_curTexture != null)
                RenderTexture.ReleaseTemporary(_curTexture);
            if (_preTexture != null)
                RenderTexture.ReleaseTemporary(_preTexture);
            if (_heightMap != null)
                RenderTexture.ReleaseTemporary(_heightMap);
            if (_normalMap != null)
                RenderTexture.ReleaseTemporary(_normalMap);
            
            if (_commandBuffer != null)
                _commandBuffer.Release();
        }
    }
}
