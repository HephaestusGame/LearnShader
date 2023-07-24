#if UNITY_EDITOR
using UnityEngine;
using UnityEditor;
using System.IO;

public class GeneratePerlinNoiseTextureEditor : EditorWindow
{
    int width = 512;
    int height = 512;
    float scale = 20f;
    string savePath = "Assets/Res/PerlinNoise.png";
    Texture2D previewTexture;
    bool saveTexture = false;
    Vector2 offset = Vector2.zero;

    [MenuItem("Tools/Generate Perlin Noise Texture")]
    public static void ShowWindow()
    {
        GetWindow<GeneratePerlinNoiseTextureEditor>("Generate Perlin Noise Texture");
    }

    void OnGUI()
    {
        GUILayout.Label("Settings", EditorStyles.boldLabel);
        width = EditorGUILayout.IntField("Width", width);
        height = EditorGUILayout.IntField("Height", height);
        scale = EditorGUILayout.FloatField("Scale", scale);
        savePath = EditorGUILayout.TextField("Save Path", savePath);

        offset = new Vector2(Random.value * 100, Random.value * 100); // Generate a random offset
        if (GUILayout.Button("Generate"))
        {
            saveTexture = true;
            Generate();
        }

        if (previewTexture != null)
        {
            GUILayout.Label("Preview:");
            float aspectRatio = (float)previewTexture.width / previewTexture.height;
            float previewWidth = Mathf.Min(position.width - 20, previewTexture.width);
            float previewHeight = previewWidth / aspectRatio;
            Rect rect = GUILayoutUtility.GetRect(previewWidth, previewHeight);
            EditorGUI.DrawPreviewTexture(rect, previewTexture);
        }

        if (GUI.changed)
        {
            saveTexture = false;
            Generate();
        }
    }

    void Generate()
    {
        Texture2D tex = new Texture2D(width, height);

        for (int x = 0; x < width; x++)
        {
            for (int y = 0; y < height; y++)
            {
                float xCoord = (float)x / width * scale + offset.x;
                float yCoord = (float)y / height * scale + offset.y;
                float sample = Mathf.PerlinNoise(xCoord, yCoord);
                tex.SetPixel(x, y, new Color(sample, sample, sample));
            }
        }

        tex.Apply();

        if (saveTexture)
        {
            string dir = Path.GetDirectoryName(savePath);
            if (!Directory.Exists(dir))
            {
                Directory.CreateDirectory(dir);
            }

            byte[] bytes = tex.EncodeToPNG();
            File.WriteAllBytes(savePath, bytes);
            AssetDatabase.Refresh();
        }

        previewTexture = tex;
    }
}
#endif
