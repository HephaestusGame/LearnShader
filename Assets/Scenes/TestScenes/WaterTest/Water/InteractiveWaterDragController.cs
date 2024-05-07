using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace HephaestusGame
{
    public class InteractiveWaterDragController : MonoBehaviour
    {
        public float interactiveMeshSize = 1.0f;
        public Mesh interactiveMesh;
        public GameObject waterPlane;
        
        private Camera _camera;
        void Start()
        {
            _camera = GetComponent<Camera>();
        }

        void Update()
        {
            if (Input.GetMouseButton(0))
            {
                Ray ray = _camera.ScreenPointToRay(Input.mousePosition);
                RaycastHit hit;
                if (Physics.Raycast(ray, out hit))
                {
                    if (hit.collider.gameObject == waterPlane)
                    {
                        Vector3 hitpos = hit.point;
                        Matrix4x4 matrix = Matrix4x4.TRS(hitpos, Quaternion.identity, Vector3.one * interactiveMeshSize);
                        InteractiveLiquid.DrawMesh(interactiveMesh, matrix);
                    }
                }
            }
        }
    }
}
