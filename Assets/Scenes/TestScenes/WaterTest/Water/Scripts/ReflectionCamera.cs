using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace HephaestusGame
{
    public class ReflectionCamera : MonoBehaviour
    {
        public RenderTexture reflectionTexture;
        private Material _targetMaterial;
        private Camera _reflectionCamera;
        private Transform _reflectionPlaneTransform;
        public void Init(Material mat, Transform reflectionPlane, int textureSize)
        {
            _targetMaterial = mat;
            reflectionTexture = RenderTexture.GetTemporary(textureSize, textureSize, 16);
            reflectionTexture.name = "_ReflectionTex";
            mat.SetTexture("_ReflectionTex", reflectionTexture);
            
            _reflectionCamera = new GameObject("ReflectionCamera").AddComponent<Camera>();
            _reflectionCamera.enabled = false;
            LayerMask mask = -1;
            _reflectionCamera.cullingMask = ~(1 << 4) & mask.value;//4为 Unity 内置的WaterLayer， 这里反射相机只反射除了 Water 以外的所有层
            _reflectionCamera.targetTexture = reflectionTexture;
            _reflectionCamera.transform.position = reflectionPlane.position;
            _reflectionCamera.transform.rotation = reflectionPlane.rotation;
            _reflectionPlaneTransform = reflectionPlane;
        }

        private void OnDestroy()
        {
            if (reflectionTexture != null)
            {
                RenderTexture.ReleaseTemporary(reflectionTexture);
            }
        }


        static void CalculateReflectionMatrix(ref Matrix4x4 reflectionMatrix, Vector4 reflectionPlane)
        {
            reflectionMatrix.m00 = (1F - 2F * reflectionPlane[0] * reflectionPlane[0]);
            reflectionMatrix.m01 = (-2F * reflectionPlane[0] * reflectionPlane[1]);
            reflectionMatrix.m02 = (-2F * reflectionPlane[0] * reflectionPlane[2]);
            reflectionMatrix.m03 = (-2F * reflectionPlane[3] * reflectionPlane[0]);

            reflectionMatrix.m10 = (-2F * reflectionPlane[1] * reflectionPlane[0]);
            reflectionMatrix.m11 = (1F - 2F * reflectionPlane[1] * reflectionPlane[1]);
            reflectionMatrix.m12 = (-2F * reflectionPlane[1] * reflectionPlane[2]);
            reflectionMatrix.m13 = (-2F * reflectionPlane[3] * reflectionPlane[1]);

            reflectionMatrix.m20 = (-2F * reflectionPlane[2] * reflectionPlane[0]);
            reflectionMatrix.m21 = (-2F * reflectionPlane[2] * reflectionPlane[1]);
            reflectionMatrix.m22 = (1F - 2F * reflectionPlane[2] * reflectionPlane[2]);
            reflectionMatrix.m23 = (-2F * reflectionPlane[3] * reflectionPlane[2]);

            reflectionMatrix.m30 = 0F;
            reflectionMatrix.m31 = 0F;
            reflectionMatrix.m32 = 0F;
            reflectionMatrix.m33 = 1F;
        }
        
        Vector4 CameraSpacePlane(Camera cam, Vector3 pos, Vector3 normal, float sideSign)
        {
            Matrix4x4 m = cam.worldToCameraMatrix;
            Vector3 cpos = m.MultiplyPoint(pos);
            Vector3 cnormal = m.MultiplyVector(normal).normalized * sideSign;
            return new Vector4(cnormal.x, cnormal.y, cnormal.z, -Vector3.Dot(cpos, cnormal));
        }
        
        void CopyCamera(Camera src, Camera dest)
        {
            dest.clearFlags = src.clearFlags;
            dest.backgroundColor = src.backgroundColor;
            dest.farClipPlane = src.farClipPlane;
            dest.nearClipPlane = src.nearClipPlane;
            dest.orthographic = src.orthographic;
            dest.fieldOfView = src.fieldOfView;
            dest.aspect = src.aspect;
            dest.orthographicSize = src.orthographicSize;
            dest.depthTextureMode = DepthTextureMode.None;
            dest.renderingPath = RenderingPath.Forward;
        }

        private int _reflectionTexID = Shader.PropertyToID("_ReflectionTex");
        private void OnWillRenderObject()
        {
            Camera currentCamera = Camera.current;
            if (currentCamera == null)
            {
                return;
            }

            Vector3 reflectionPlanePos = _reflectionPlaneTransform.position;
            Vector3 reflectionPlaneNormal = _reflectionPlaneTransform.up;
            CopyCamera(currentCamera, _reflectionCamera);
            float d = -Vector3.Dot(reflectionPlaneNormal, reflectionPlanePos);
            Vector4 reflectionPlane = new Vector4(reflectionPlaneNormal.x, reflectionPlaneNormal.y, reflectionPlaneNormal.z, d);
            Matrix4x4 reflectionMatrix = Matrix4x4.zero;
            CalculateReflectionMatrix(ref reflectionMatrix, reflectionPlane);
            Vector3 oldPos = currentCamera.transform.position;
            Vector3 newPos = reflectionMatrix.MultiplyPoint(oldPos);
            _reflectionCamera.worldToCameraMatrix = currentCamera.worldToCameraMatrix * reflectionMatrix;
            
            Vector4 viewSpaceNearPlane = CameraSpacePlane(_reflectionCamera, reflectionPlanePos, reflectionPlaneNormal, 1.0f);
            Matrix4x4 projection = currentCamera.CalculateObliqueMatrix(viewSpaceNearPlane);
            _reflectionCamera.projectionMatrix = projection;

            GL.invertCulling = true;
            _reflectionCamera.transform.position = newPos;
            Vector3 euler = currentCamera.transform.eulerAngles;
            _reflectionCamera.transform.eulerAngles = new Vector3(0, euler.y, euler.z);
            _reflectionCamera.Render();
            _targetMaterial.SetTexture(_reflectionTexID, reflectionTexture);
            GL.invertCulling = false;
        }
    }
    
}
