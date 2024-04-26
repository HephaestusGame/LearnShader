using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

namespace HephaestusGame 
{
    public class ProjectorShadow : MonoBehaviour
    {
        public float projectorSize = 23;
        public int renderTexSize = 2048;
        public LayerMask layerCaster;
        public LayerMask layerIgnoreReceiver;
        public Transform followObj;
        public List<GameObject> casterObjList;

        private bool _useCommandBuf = false;
        private Projector _projector;
        private Camera _shadowCam;
        private RenderTexture _shadowRT;
        private CommandBuffer _commandBuf;

        private Material _replaceMat;
        void Start()
        {
            _shadowRT = new RenderTexture(renderTexSize, renderTexSize, 0, RenderTextureFormat.R8);
            _shadowRT.name = "ShadowRT";
            _shadowRT.antiAliasing = 1;
            _shadowRT.filterMode = FilterMode.Bilinear;
            _shadowRT.wrapMode = TextureWrapMode.Clamp;
            
            //init projector
            _projector = GetComponent<Projector>();
            _projector.orthographic = true;
           
            
            //init camera
            _shadowCam = gameObject.AddComponent<Camera>();
            _shadowCam.clearFlags = CameraClearFlags.Color;
            _shadowCam.backgroundColor = Color.black;
            _shadowCam.depth = -100.0f;
            _shadowCam.orthographic = true;
            
            


            SwitchtCommandBuffer();
        }
    
        void Update()
        {
            _projector.orthographicSize = projectorSize;
            _projector.ignoreLayers = layerIgnoreReceiver;
            _projector.material.SetTexture("_ShadowTex", _shadowRT);
            
            _shadowCam.orthographicSize = projectorSize;
            _shadowCam.nearClipPlane = _projector.nearClipPlane;
            _shadowCam.farClipPlane = _projector.farClipPlane;
            _shadowCam.targetTexture = _shadowRT;
            
            
            if (Input.GetKeyDown(KeyCode.Space))
            {
                _useCommandBuf = !_useCommandBuf;
                SwitchtCommandBuffer();
            }

            if (_useCommandBuf)
            {
                FillCommandBuffer();
            }
        }

        private void SwitchtCommandBuffer()
        {
            Shader replaceShader = Shader.Find("ProjectorShadow/ShadowCaster");

            if (!_useCommandBuf)
            {
                _shadowCam.cullingMask = layerCaster;
                _shadowCam.SetReplacementShader(replaceShader, "RenderType");
            }
            else
            {
                _shadowCam.cullingMask = 0;
                _shadowCam.RemoveAllCommandBuffers();
                if (_commandBuf != null)
                {
                    _commandBuf.Dispose();
                    _commandBuf = null;
                }

                _commandBuf = new CommandBuffer();
                _shadowCam.AddCommandBuffer(CameraEvent.BeforeImageEffectsOpaque, _commandBuf);

                if (_replaceMat == null)
                {
                    _replaceMat = new Material(replaceShader);
                    _replaceMat.hideFlags = HideFlags.HideAndDontSave;
                }
            }
        }

        private void FillCommandBuffer()
        {
            _commandBuf.Clear();
            Plane[] camfrustum = GeometryUtility.CalculateFrustumPlanes(_shadowCam);

            foreach (var go in casterObjList)
            {
                if (go == null)
                {
                    continue;
                }

                Collider collider = go.GetComponentInChildren<Collider>();
                if (collider == null)
                    continue;

                bool bound = GeometryUtility.TestPlanesAABB(camfrustum, collider.bounds);
                if (!bound)
                    continue;

                Renderer[] rendererList = go.GetComponentsInChildren<Renderer>();
                if (rendererList.Length <= 0)
                    continue;

                bool hasvis = false;
                foreach (var renderer in rendererList)
                {
                    if (renderer == null)
                        continue;

                    RenderVis rendervis = renderer.GetComponent<RenderVis>();
                    if (rendervis == null)
                        continue;

                    if (rendervis.IsVisible)
                    {
                        hasvis = true;
                        break;
                    }
                }

                if (!hasvis)
                    continue;

                foreach (var renderer  in rendererList)
                {
                    if (renderer == null)
                        continue;
                    
                    _commandBuf.DrawRenderer(renderer, _replaceMat);
                }
            }
        }
    }
}
