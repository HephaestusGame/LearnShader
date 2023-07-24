using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace HephaestusGame
{
    [ExecuteInEditMode]
    [RequireComponent(typeof(Renderer))]
    public class PlaneShadowCaster : MonoBehaviour
    {
        public Transform receiver;
        private void Update()
        {
            if (receiver == null)
                return;

            Renderer renderer = GetComponent<Renderer>();
            renderer.sharedMaterial.SetMatrix("_World2Ground", receiver.worldToLocalMatrix);
            renderer.sharedMaterial.SetMatrix("_Ground2World", receiver.localToWorldMatrix);
        }
    }
}

