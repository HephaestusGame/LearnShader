using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEditor;
using System.IO;

namespace HephaestusGame
{
    public class PlaneMeshGenerator : EditorWindow
    {
        float width = 100;
        float height = 100;
        int widthSegments = 100;
        int heightSegments = 100;
        string assetPath = "Assets/";

        [MenuItem("Tools/Plane Mesh Generator")]
        public static void ShowWindow()
        {
            GetWindow(typeof(PlaneMeshGenerator), false, "Plane Mesh Generator");
        }

        void OnGUI()
        {
            GUILayout.Label("Base Settings", EditorStyles.boldLabel);
            width = EditorGUILayout.FloatField("Width", width);
            height = EditorGUILayout.FloatField("Height", height);
            widthSegments = EditorGUILayout.IntField("Width Segments", widthSegments);
            heightSegments = EditorGUILayout.IntField("Height Segments", heightSegments);
            assetPath = EditorGUILayout.TextField("Asset Path", assetPath);

            if (GUILayout.Button("Generate Mesh"))
            {
                GeneratePlaneMesh(width, height, widthSegments, heightSegments, assetPath);
            }
        }

        void GeneratePlaneMesh(float width, float height, int widthSegments, int heightSegments, string path)
        {
            Mesh mesh = new Mesh();
            mesh.name = "CustomPlane";

            int vertexCount = (widthSegments + 1) * (heightSegments + 1);
            Vector3[] vertices = new Vector3[vertexCount];
            Vector2[] uv = new Vector2[vertexCount];
            int[] triangles = new int[widthSegments * heightSegments * 6];

            float hw = width / 2;
            float hh = height / 2;
            float dx = width / widthSegments;
            float dz = height / heightSegments;

            int vertIndex = 0;
            int triIndex = 0;

            for (int z = 0; z <= heightSegments; z++)
            {
                for (int x = 0; x <= widthSegments; x++)
                {
                    float xPos = x * dx - hw;
                    float zPos = z * dz - hh;
                    vertices[vertIndex] = new Vector3(xPos, 0, zPos);
                    uv[vertIndex] = new Vector2((float)x / widthSegments, (float)z / heightSegments);

                    if (x < widthSegments && z < heightSegments)
                    {
                        triangles[triIndex++] = vertIndex;
                        triangles[triIndex++] = vertIndex + widthSegments + 1;
                        triangles[triIndex++] = vertIndex + 1;
                        triangles[triIndex++] = vertIndex + 1;
                        triangles[triIndex++] = vertIndex + widthSegments + 1;
                        triangles[triIndex++] = vertIndex + widthSegments + 2;
                    }

                    vertIndex++;
                }
            }

            mesh.vertices = vertices;
            mesh.uv = uv;
            mesh.triangles = triangles;
            mesh.RecalculateNormals();

            SaveMesh(mesh, path);
        }

        void SaveMesh(Mesh mesh, string path)
        {
            if (!Directory.Exists(Path.GetDirectoryName(path)))
            {
                Directory.CreateDirectory(Path.GetDirectoryName(path));
            }

            AssetDatabase.CreateAsset(mesh, AssetDatabase.GenerateUniqueAssetPath(path + mesh.name + ".asset"));
            AssetDatabase.SaveAssets();
            Debug.Log("Mesh saved to " + path + mesh.name + ".asset");
        }
    }
}
