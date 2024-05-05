using System;
using System.Collections;
using System.Collections.Generic;
using Sirenix.OdinInspector;
using UnityEngine;
using UnityEngine.Serialization;
using Random = UnityEngine.Random;

public class GPUGerstnerWaves : MonoBehaviour
{
    [Range(0, 360)]
    public float windDirection = 0;
    public Vector2 steepnessRange;
    public float timescale = 1.0f;
    public float time = 0;
    public uint wavesNum = 16;
    public int textureSize = 256;
    public ComputeShader computeShader;

    public Material waterMaterial;
    public Vector4[] waves;

    public RenderTexture displacementRT;
    public RenderTexture normalRT;
    private int _wavesBufferID = Shader.PropertyToID("gerstnerWavesBuffer");
    private int _wavesNumID = Shader.PropertyToID("wavesNum");
    private int _displacementTextureID = Shader.PropertyToID("_GerstnerDisplacementTex");
    private int _normalTextureID = Shader.PropertyToID("_GerstnerNormalTex");
    private int _GerstnerTextureSizeID = Shader.PropertyToID("_GerstnerTextureSize");
    private int _timeID = Shader.PropertyToID("time");
    
    private int _previousWavesNum = 0;

    private bool _bufferUpdated = true;
    private void Update()
    {
        if (computeShader == null)
            return;

        if (_previousWavesNum != wavesNum)
        {
            _previousWavesNum = (int)wavesNum;
            RegenerateWaves();
        }

        GetRT(ref displacementRT);
        GetRT(ref normalRT);
        int kernelID = computeShader.FindKernel("ComputeGerstnerWave");
        if (_wavesBuffer == null)
        {
            _wavesBuffer = new ComputeBuffer((int)_realWavesNum, sizeof(float) * 4);
        }
        time += Time.deltaTime * timescale;

        if (_bufferUpdated)
        {
            _bufferUpdated = false;
            _wavesBuffer.SetData(waves);
            computeShader.SetBuffer(kernelID, _wavesBufferID, _wavesBuffer);
        }
        computeShader.SetFloat(_timeID, time);
        computeShader.SetInt(_wavesNumID, (int)_realWavesNum);
        computeShader.SetTexture(kernelID, _displacementTextureID, displacementRT);
        computeShader.SetTexture(kernelID, _normalTextureID, normalRT);
        computeShader.Dispatch(kernelID, textureSize / 8, textureSize / 8, 1);


        if (waterMaterial != null)
        {
            waterMaterial.SetTexture(_displacementTextureID, displacementRT);
            waterMaterial.SetTexture(_normalTextureID, normalRT);
            waterMaterial.SetFloat(_GerstnerTextureSizeID, textureSize);
        }
    }


    private void GetRT(ref RenderTexture rt)
    {
        if (rt != null)
        {
            if (rt.width == textureSize)
                return;
            RenderTexture.ReleaseTemporary(rt);
        }
        rt = RenderTexture.GetTemporary(textureSize, textureSize, 0, RenderTextureFormat.ARGBFloat);
        rt.enableRandomWrite = true;
        rt.filterMode = FilterMode.Trilinear;
        rt.wrapMode = TextureWrapMode.Repeat;
    }
    
    [SerializeField]
    private ComputeBuffer _wavesBuffer;
    private int _realWavesNum = 0;
    [Button]
    public void RegenerateWaves()
    {
        _bufferUpdated = true;
        int directionNum = 18;
        _realWavesNum = (int)wavesNum * directionNum;
        _wavesBuffer = new ComputeBuffer((int)_realWavesNum, sizeof(float) * 4);
        waves = new Vector4[_realWavesNum];
        float baseAngle = windDirection * Mathf.Deg2Rad; 
        for (int i = 0; i < wavesNum; i++)
        {
            float angle = baseAngle + i * Mathf.PI * 0.8f / wavesNum;
            float steepness = Random.Range(steepnessRange.x, steepnessRange.y);
            float waveLength = (float)(textureSize * (i + 1)) / wavesNum  * (0.25f + Random.Range(-0.05f, 0.05f));
            for (int j = 0; j < directionNum; j++)
            {
                Vector2 dir = Vector2.one;
                angle += Mathf.PI  / directionNum  + Mathf.PI  / 360  * Random.Range(-40, 40);
                dir.x = Mathf.Cos(angle);
                dir.y = Mathf.Sin(angle);
                waves[i * directionNum + j] = new Vector4(dir.x, dir.y, steepness, waveLength);
            }
        }
    }
}
