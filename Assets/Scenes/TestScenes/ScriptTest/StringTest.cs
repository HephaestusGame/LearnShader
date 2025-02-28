using System;
using System.Collections;
using System.Collections.Generic;
using System.Text;
using Sirenix.OdinInspector;
using UnityEngine;

public class StringTest : MonoBehaviour
{
    private Action _testAction;

    private void Start()
    {
        _sb.Append("Test String Builder");
    }

    private void OnTriggerEnter(Collider other)
    {
    }

    [Button]
    public void ToStringTest(int count = 1)
    {
        //触发 GC.Alloc
        _testAction = () =>
        {
            for (int i = 0; i < count; i++)
            {
                int test = 123;
                string str = test.ToString();
            }
        };
    }

    [Button]
    public void StringJointTest1()
    {
        //触发 GC.Alloc
        _testAction = () =>
        {
            string s1 = "Hello";
            string s2 = s1 + " World";
        };
    }
    
    [Button]
    public void StringJointTest2()
    {
        //不触发 GC.Alloc
        _testAction = () =>
        {
            string s2 = "Hello" + " World";
        };
    }

    private StringBuilder _sb = new StringBuilder(32);
    [Button]
    public void StringBuilderTest(int count = 1)
    {
        _testAction = () =>
        {
            //每次循环触发 GC.Alloc
            for (int i = 0; i < count; i++)
            {
                _sb.ToString();
            }
        };
    }

    [Button]
    public void StringInterpolation(int count = 1)
    {
        
        _testAction = () =>
        {
            int test = 123;
            //每次循环触发 GC.Alloc
            for (int i = 0; i < count; i++)
            {
                string s = $"Insertion {test}";
            }
        };
    }
    
    

    private void Update()
    {
        _testAction?.Invoke();
    }
}
