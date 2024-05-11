using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Serialization;

namespace HephaestusGame
{
    public class CausticsRenderer : MonoBehaviour
    {
        public MeshRenderer waterPlane;
        /// <summary>
        /// 焦散强度
        /// </summary>
        public float causticsIntensity = 1.0f;
        /// <summary>
        /// 深度范围（该参数目前实现比较简单，只是简单的传入世界空间的最小高度和有效高度范围，以计算焦散的有效高度范围（线性插值），暂时没有实现复杂的范围计算效果）
        /// </summary>
        public Vector2 causticsDepthRange;

        public Material material;

        public Mesh mesh;

        private Camera _camera;

        private RenderTexture _renderTexture;
        private CommandBuffer _commandBuffer;

        private float _width = 10;
        private float _height = 10;
        public void Init(float causticsIntensity, float waterDepth, MeshRenderer waterPlane, Material material)
        {
            this.waterPlane = waterPlane;
            this.causticsIntensity = causticsIntensity;
            this.material = material;
            causticsDepthRange.x = transform.position.y - waterDepth;
            causticsDepthRange.y = waterDepth;
            Bounds bounds = waterPlane.bounds;
            _width = bounds.size.x;
            _height = bounds.size.z;
            
            _camera = gameObject.AddComponent<Camera>();
            _camera.aspect = _width / _height;
            _camera.backgroundColor = Color.black;
            _camera.depth = 0;
            _camera.farClipPlane = 5;
            _camera.nearClipPlane = -5;
            _camera.orthographic = true;
            _camera.orthographicSize = _height * 0.5f;
            _camera.clearFlags = CameraClearFlags.SolidColor;
            _camera.allowHDR = false;//如果开启，Camera 会进行一次 ToneMapping 的后处理，这里渲染焦散，不希望 ToneMapping，所以需要关闭
            _camera.backgroundColor = Color.black;
            _camera.cullingMask = 0;

            _renderTexture = RenderTexture.GetTemporary(2048, 2048, 16, RenderTextureFormat.ARGBFloat);
            _renderTexture.name = "CausticMap";
            _camera.targetTexture = _renderTexture;

            _commandBuffer = new CommandBuffer();
            _commandBuffer.name = "CausticCommandBuffer";
            _camera.AddCommandBuffer(CameraEvent.AfterImageEffectsOpaque, _commandBuffer);

            mesh = waterPlane.GetComponent<MeshFilter>()?.mesh;

        }

        private int _causticPlaneID = Shader.PropertyToID("_CausticsPlane");
        private int _causticRangeID = Shader.PropertyToID("_CausticsRange");
        private int _causticMapID = Shader.PropertyToID("_CausticsMap");
        private int _causticDepthRangeID = Shader.PropertyToID("_CausticsDepthRange");
        private int _causticIntensityID = Shader.PropertyToID("_CausticsIntensity");
        void OnPostRender()
        {
            Vector3 position = transform.position;

            //绘制焦散mesh
            Matrix4x4 trs = Matrix4x4.TRS(position, Quaternion.identity, Vector3.one);
            _commandBuffer.Clear();
            _commandBuffer.ClearRenderTarget(true, true, Color.black);
            _commandBuffer.SetRenderTarget(_renderTexture);
            _commandBuffer.DrawMesh(mesh, trs, material);

            Vector4 plane = new Vector4(0, 1, 0, Vector3.Dot(new Vector3(0, 1, 0), position));
            Vector4 range = new Vector4(position.x, position.z, _width * 0.5f, _height * 0.5f);

            Shader.SetGlobalVector(_causticPlaneID, plane);
            Shader.SetGlobalVector(_causticRangeID, range);
            Shader.SetGlobalTexture(_causticMapID, _renderTexture);
            Shader.SetGlobalVector(_causticDepthRangeID, causticsDepthRange);
            Shader.SetGlobalFloat(_causticIntensityID, causticsIntensity);
        }

        void OnDestroy()
        {
            if (_renderTexture != null)
                RenderTexture.ReleaseTemporary(_renderTexture);
            if (_commandBuffer != null)
            {
                _commandBuffer.Release();
                _commandBuffer = null;
            }
        }
    }
}
