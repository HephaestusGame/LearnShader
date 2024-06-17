using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace HepheastusGame
{
    public class VolumetricCloudGizmos : MonoBehaviour
    {
        private void OnDrawGizmos()
        {
            
        }

        private void OnDrawGizmosSelected()
        {
            Gizmos.color = Color.green;
            Gizmos.DrawWireCube(transform.position, transform.localScale);
        }
    }
}
