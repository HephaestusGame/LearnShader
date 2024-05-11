using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace HephaestusGame
{
    public class InteractiveWaterDragController : MonoBehaviour
    {
        [Min(0.01f)]
        public float interactiveWidth = 1.0f;
        [Min(0.01f)]
        public float interactiveMeshHeight = 1.0f;

        public float interactiveInterval = 0.1f;
        public Mesh interactiveMesh;
        public GameObject waterPlane;
        
        private Camera _camera;
        void Start()
        {
            _camera = GetComponent<Camera>();
        }

        private float _lastInteractiveTime;
        void Update()
        {
            if (Input.GetMouseButton(0))
            {
                if (Time.realtimeSinceStartup - _lastInteractiveTime < interactiveInterval)
                    return;
                Ray ray = _camera.ScreenPointToRay(Input.mousePosition);
                RaycastHit hit;
                if (Physics.Raycast(ray, out hit))
                {
                    if (hit.collider.gameObject == waterPlane)
                    {
                        Vector3 hitpos = hit.point;
                        Matrix4x4 matrix = Matrix4x4.TRS(hitpos, Quaternion.identity, new Vector3(interactiveWidth, interactiveMeshHeight, interactiveWidth));
                        InteractiveLiquid.DrawMesh(interactiveMesh, matrix);
                        _lastInteractiveTime = Time.realtimeSinceStartup;
                    }
                }
            }
        }
    }
}
