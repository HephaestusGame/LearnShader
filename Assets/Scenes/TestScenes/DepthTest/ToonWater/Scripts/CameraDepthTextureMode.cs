using UnityEngine;

namespace HephaestusGame
{
    public class CameraDepthTextureMode : MonoBehaviour
    {
        [SerializeField] DepthTextureMode depthTextureMode;

        private void OnValidate()
        {
            SetCameraDepthTextureMode();
        }

        private void Awake()
        {
            SetCameraDepthTextureMode();
        }

        private void SetCameraDepthTextureMode()
        {
            GetComponent<Camera>().depthTextureMode = depthTextureMode;
        }
    }  
}