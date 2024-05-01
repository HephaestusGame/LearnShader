using System;
using System.Collections;
using System.Collections.Generic;
using Sirenix.OdinInspector;
using UnityEngine;
using UnityEngine.Serialization;
using Random = UnityEngine.Random;

public class GPUGerstnerWaves : MonoBehaviour
{
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
    
    private void Update()
    {
        if (computeShader == null)
            return;

        GetRT(ref displacementRT);
        GetRT(ref normalRT);
        int kernelID = computeShader.FindKernel("ComputeGerstnerWave");
        if (_wavesBuffer == null)
        {
            _wavesBuffer = new ComputeBuffer((int)wavesNum, sizeof(float) * 4);
        }
        time += Time.deltaTime * timescale;

        _wavesBuffer.SetData(waves);
        computeShader.SetBuffer(kernelID, _wavesBufferID, _wavesBuffer);
        computeShader.SetFloat(_timeID, time);
        computeShader.SetInt(_wavesNumID, (int)wavesNum);
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
    [Button]
    public void RegenerateWaves()
    {
        _wavesBuffer = new ComputeBuffer((int)wavesNum, sizeof(float) * 4);
        waves = new Vector4[wavesNum];
        for (int i = 0; i < wavesNum; i++)
        {
            Vector2 dir = Random.insideUnitCircle.normalized;
            float steepness = Random.Range(0.001f, .5f);

            int waveLengthDivide = Mathf.CeilToInt(Random.Range(0.1f, textureSize));
            float waveLength = textureSize / waveLengthDivide;
            waves[i] = new Vector4(dir.x, dir.y, steepness, waveLength);
        }
    }
}
