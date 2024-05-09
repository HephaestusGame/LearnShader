using System;
using System.Collections;
using System.Collections.Generic;
using Sirenix.OdinInspector;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Serialization;

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
        
        public RenderTexture curTexture;
        public RenderTexture preTexture;
        public RenderTexture heightMap;
        public RenderTexture normalMap;

        private int _waveParamsID = Shader.PropertyToID("_WaveParams");
        private int _internalForceID = Shader.PropertyToID("_InternalForce");
        private int _interactiveWaterHeightMapID = Shader.PropertyToID("_InteractiveWaterHeightMap");
        private int _interactiveWaterNormalMapID = Shader.PropertyToID("_InteractiveWaterNormalMap");
        private int _preTexID = Shader.PropertyToID("_PreTex");
        
        public void DrawMesh(Mesh mesh, Matrix4x4 matrix)
        {
            if (!mesh)
                return;
            _commandBuffer.DrawMesh(mesh, matrix, _forceMaterial);
        }

        public void UpdateWaveParams(Vector4 waveParams)
        {
            _waveParams = waveParams;
            if (_waveEquationMaterial != null)
                _waveEquationMaterial.SetVector(_waveParamsID, _waveParams);
        }

        public void UpdateForceFactor(float forceFactor)
        {
            Shader.SetGlobalFloat(_internalForceID, forceFactor);
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
            curTexture = RenderTexture.GetTemporary(texSize, texSize, 16, RenderTextureFormat.ARGB32, readWrite);
            curTexture.name = "CurTexture";
            curTexture.filterMode = FilterMode.Trilinear;
            preTexture = RenderTexture.GetTemporary(texSize, texSize, 16, RenderTextureFormat.ARGB32, readWrite);
            preTexture.name = "PreTexture";
            preTexture.filterMode = FilterMode.Trilinear;
            heightMap = RenderTexture.GetTemporary(texSize, texSize, 16, RenderTextureFormat.ARGB32, readWrite);
            heightMap.name = "HeightMap";
            heightMap.filterMode = FilterMode.Trilinear;
            normalMap = RenderTexture.GetTemporary(texSize, texSize, 16, RenderTextureFormat.ARGB32, readWrite);
            normalMap.name = "NormalMap";
            normalMap.filterMode = FilterMode.Trilinear;
            // _normalMap.anisoLevel = 1;

            ClearRT();

            _camera.targetTexture = curTexture;
            Shader.SetGlobalFloat(_internalForceID, forceFactor);
            
            _waveEquationMaterial = new Material(waveEquationShader);
            _waveEquationMaterial.SetVector(_waveParamsID, _waveParams);
            _generateNormalMaterial = new Material(generateNormalShader);
            
            Shader.SetGlobalTexture(_interactiveWaterHeightMapID, heightMap);
            Shader.SetGlobalTexture(_interactiveWaterNormalMapID, normalMap);
        }

        [Button]
        private void ClearRT()
        {
            RenderTexture tmp = RenderTexture.active;
            RenderTexture.active = curTexture;
            GL.Clear(false, true, new Color(0, 0, 0, 0));
            RenderTexture.active = preTexture;
            GL.Clear(false, true, new Color(0, 0, 0, 0));
            RenderTexture.active = heightMap;
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
            
            _waveEquationMaterial.SetTexture(_preTexID, preTexture);
            _commandBuffer.Blit(curTexture, heightMap, _waveEquationMaterial);
            _commandBuffer.Blit(heightMap, normalMap, _generateNormalMaterial);
            _commandBuffer.Blit(curTexture, preTexture);
            _commandBuffer.Blit(heightMap, curTexture);
        }

        private void OnDestroy()
        {
            if (_forceMaterial)
                Destroy(_forceMaterial);
            if (_waveEquationMaterial)
                Destroy(_waveEquationMaterial);
            if (_generateNormalMaterial)
                Destroy(_generateNormalMaterial);
            
            if (curTexture != null)
                RenderTexture.ReleaseTemporary(curTexture);
            if (preTexture != null)
                RenderTexture.ReleaseTemporary(preTexture);
            if (heightMap != null)
                RenderTexture.ReleaseTemporary(heightMap);
            if (normalMap != null)
                RenderTexture.ReleaseTemporary(normalMap);
            
            if (_commandBuffer != null)
                _commandBuffer.Release();
        }
    }
}
