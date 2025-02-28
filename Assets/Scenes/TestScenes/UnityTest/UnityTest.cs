using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[RequireComponent(typeof(Camera)), ExecuteAlways]
public class UnityTest : MonoBehaviour
{
    public bool renderIntoTexture = false;
    public bool getGPUMatrix = false;
    public bool showScreenUV = false;
    public bool showRealScreenUV = false;
    public Material mat;
    private Camera _camera;

    // Update is called once per frame
    void Update()
    {
        if (_camera == null)
        {
            _camera = GetComponent<Camera>();
        }
        if (mat != null)
        {
            if (showRealScreenUV)
            {
                mat.EnableKeyword("_SHOW_REAL_SCREEN_POS");
                mat.DisableKeyword("_SHOW_SCREEN_POS");
            }
            else
            {
                mat.DisableKeyword("_SHOW_REAL_SCREEN_POS");
                if (showScreenUV)
                {
                    mat.EnableKeyword("_SHOW_SCREEN_POS");
                }
                else
                {
                    mat.DisableKeyword("_SHOW_SCREEN_POS");
                }
            }
            
            mat.SetMatrix("_VPMatrix", getGPUMatrix ? GL.GetGPUProjectionMatrix(_camera.projectionMatrix, renderIntoTexture) * _camera.worldToCameraMatrix : _camera.projectionMatrix * _camera.worldToCameraMatrix);
        }
    }
}
