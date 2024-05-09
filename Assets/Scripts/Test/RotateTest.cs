using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class RotateTest : MonoBehaviour
{
    public bool rotate = false;
    public bool zxy = false;
    public Vector4 origin;
    public Vector3 rotateAngle;

    public Transform indicator;

    private void ResetToOrigin()
    {
        transform.position = origin;


        indicator.rotation = Quaternion.identity;
    }

    private void Rotate()
    {
        float xAngle = Mathf.PI * rotateAngle.x / 180.0f;
        float yAngle = Mathf.PI * rotateAngle.y / 180.0f;
        float zAngle = Mathf.PI * rotateAngle.z / 180.0f;
        Matrix4x4 matrixX = new Matrix4x4();
        float xSin = Mathf.Sin(xAngle);
        float xCos = Mathf.Cos(xAngle);
        matrixX.SetRow(0, new Vector4(1,    0,     0,       0));
        matrixX.SetRow(1, new Vector4(0,    xCos,  -xSin,   0));
        matrixX.SetRow(2, new Vector4(0,    xSin,  xCos,    0));
        matrixX.SetRow(3, new Vector4(0,    0,     0,       1));


        Matrix4x4 matrixY = new Matrix4x4();
        float ySin = Mathf.Sin(yAngle);
        float yCos = Mathf.Cos(yAngle);
        matrixY.SetRow(0, new Vector4(yCos,     0,      ySin,   0));
        matrixY.SetRow(1, new Vector4(0,        1,      0,      0));
        matrixY.SetRow(2, new Vector4(-ySin,     0,     yCos,   0));
        matrixY.SetRow(3, new Vector4(0,        0,      0,      1));


        Matrix4x4 matrixZ = new Matrix4x4();
        float zSin = Mathf.Sin(zAngle);
        float zCos = Mathf.Cos(zAngle);
        matrixZ.SetRow(0, new Vector4(zCos, -zSin, 0, 0));
        matrixZ.SetRow(1, new Vector4(zSin, zCos, 0, 0));
        matrixZ.SetRow(2, new Vector4(0,    0,    1, 0));
        matrixZ.SetRow(3, new Vector4(0,    0,    0, 1));

        Vector3 targetPos = matrixZ * (matrixX * (matrixY * origin));
        if (zxy)
        {
            targetPos = matrixY * (matrixX * (matrixZ * origin));
        }

        //Vector3 targetPos = matrixY.MultiplyVector(matrixX.MultiplyVector(matrixZ.MultiplyVector(origin)));
        transform.position = targetPos;

        Quaternion rot = Quaternion.identity;
        rot.eulerAngles = rotateAngle;
        indicator.rotation = rot;
    }

    void Update()
    {
        if (rotate)
        {
            Rotate();
        } else
        {
            ResetToOrigin();
        }
    }
}
