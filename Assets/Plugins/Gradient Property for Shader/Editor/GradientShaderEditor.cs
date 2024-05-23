using UnityEngine;
using UnityEditor;
using GradientDrawer;


public class GradientShaderEditor : ShaderGUI
{

    private const string regex = "GradientTexture"; // naming convention (what the "reference" of a gradient should include)
    private const int resolution = 256;             // resolution of the generated texture for each gradient



    private readonly GradientGUIDrawer gradientGUIDrawer = new GradientGUIDrawer(resolution);


    public override void OnGUI(MaterialEditor editor, MaterialProperty[] properties)
    {
        foreach (MaterialProperty property in properties)
        {
            bool hideInInspector = (property.flags & MaterialProperty.PropFlags.HideInInspector) != 0;
            if (hideInInspector) continue;

            string displayName = property.displayName;

            if (property.type == MaterialProperty.PropType.Texture && property.name.Contains(regex))
            {
                gradientGUIDrawer.OnGUI(Rect.zero, property, new GUIContent(property.displayName, ""), editor);
            }
            else
                editor.ShaderProperty(property, displayName);
        }

        EditorGUILayout.Space();
        EditorGUILayout.Space();

        base.OnGUI(editor, new MaterialProperty[0]);
    }

}