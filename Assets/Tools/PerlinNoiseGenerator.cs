using System;
using UnityEngine;
using System.IO;
using Sirenix.OdinInspector;


public class GeneratePerlinNoiseTexture : MonoBehaviour
{
    public int width = 512;
    public int height = 512;
    public float scale = 20f;
    public string savePath = "Assets/PerlinNoise.png";

    [Button]
    private void Generate()
    {
        Texture2D tex = new Texture2D(width, height);
        
        for (int x = 0; x < width; x++)
        {
            for (int y = 0; y < height; y++)
            {
                float xCoord = (float)x / width * scale;
                float yCoord = (float)y / height * scale;
                float sample = Mathf.PerlinNoise(xCoord, yCoord);
                tex.SetPixel(x, y, new Color(sample, sample, sample));
            }
        }

        tex.Apply();

        byte[] bytes = tex.EncodeToPNG();
        File.WriteAllBytes(savePath, bytes);
    }
}