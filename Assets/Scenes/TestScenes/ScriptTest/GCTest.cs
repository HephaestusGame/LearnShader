using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class GCTest : MonoBehaviour
{
    public RenderTexture rt;

    public bool setName;
    public bool useConstString;
    private const string CONST_STRING = "Testing!";
    void Update()
    {
        if (rt == null)
        {
            rt = RenderTexture.GetTemporary(1024, 1024);
        }

        if (setName)
        {
            string s1 = "Testing!";
            string s2 = "Ter";
            rt.name = s1 + s2;
            return;
        }
        

        if (useConstString)
        {
            rt.name = CONST_STRING;
        }
    }
}
