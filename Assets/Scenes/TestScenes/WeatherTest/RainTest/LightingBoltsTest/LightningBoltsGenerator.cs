using System;
using System.Collections;
using System.Collections.Generic;
using Sirenix.OdinInspector;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Serialization;
using Random = UnityEngine.Random;

namespace HephaestusGames
{
    public struct LightningBoltSegment
    {
        public LightningBoltSegment(Vector3 startPoint, Vector3 endPoint, Vector3 positionOnUpperBranch, Vector2 toBranchStartDistance, int branchLevel = 0)
        {
            start = startPoint;
            end = endPoint;
            this.branchLevel = branchLevel;
            this.toBranchStartDistance = toBranchStartDistance;
            this.positionOnUpperBranch = positionOnUpperBranch;
        }
        public Vector3 start;
        public Vector3 end;
        public int branchLevel;
        //当前 Segment 首尾在当前分支中的百分比位置
        public Vector2 toBranchStartDistance;
        //当前分支在上一级分支中的百分比位置
        public Vector3 positionOnUpperBranch;
    }

    [Serializable]
    public class BranchGenerationConfig
    {
        public AnimationCurve widthCure;
        public float width = 150;
        [Range(0, 1)]
        public float twistFactor = 0.3f;
        [Range(0, 1)]
        public float divisionFactor = 0.5f;
        [Range(0, 1)]
        public float divisionFactorRandomValue = 0.1f;
        [Range(0, 1)]
        public float brightness = 1;
        
        [FoldoutGroup("SubBranch"),Range(0, .1f)]
        public float generateNewBranchProbability = 0.03f;
        [FoldoutGroup("SubBranch")]
        public float minBranchRandomAngle = 45;
        [FoldoutGroup("SubBranch")]
        public float maxBranchRandomAngle = 65;
        [FoldoutGroup("SubBranch")]
        public float subBranchLengthFactor = 0.7f;
    }
    [ExecuteInEditMode]
    public class LightningBoltsGenerator : MonoBehaviour
    {
        public List<BranchGenerationConfig> branchGenerationConfigs = new List<BranchGenerationConfig>();
        
        public bool playAnim = false;
        public MeshFilter meshFilter;
        public Transform startPoint;
        public Transform endPoint;
        [FormerlySerializedAs("subBranchWidhtCurve")]
        [FormerlySerializedAs("curve")]
        public AnimationCurve subBranchWidthCurve;
        public AnimationCurve mainBranchWidthCurve;

        [Range(1, 12)]
        public int divideLoop = 10;
        // [Range(0, 3)]
        // public int subBranchLevel = 3;
        // [FormerlySerializedAs("maximumOffset")]
        // [Range(0, 1)]
        // public float twistFactor;
        // [FormerlySerializedAs("segmentLerpValue")]
        // [Range(0, 1)]
        // public float divisionFactor;
        // [FormerlySerializedAs("segmentLerpRandomValue")]
        // [Range(0, 1)]
        // public float divisionFactorRandomValue;
        //
        //
        // [FoldoutGroup("Branch")]
        // public float minBranchRandomAngle = 5;
        // [FoldoutGroup("Branch")]
        // public float maxBranchRandomAngle = 15;
        // [FoldoutGroup("Branch")]
        // public Vector3 branchLengthFactor = Vector3.one * 0.7f;
        // [FoldoutGroup("Branch"),Range(0, .1f)]
        // public float generateNewBranchProbability = 0.1f;

        private List<LightningBoltSegment> _segmentsList = new List<LightningBoltSegment>();
        private List<LightningBoltSegment> _tempList = new List<LightningBoltSegment>();
        private List<LightningBoltSegment> _tempList2 = new List<LightningBoltSegment>();
        
        private List<LightningBoltSegment> _finalList = new List<LightningBoltSegment>();
        private List<LightningBoltSegment> _branchList = new List<LightningBoltSegment>();

        private Vector3 _rotateAxis;
        private void Update()
        {
            RegenerateIfNeed();
        }

        private Vector3 _lastStartPos;
        private Vector3 _lastEndPos;
        private float _lastMainBranchWidth;
        private void RegenerateIfNeed()
        {
            if (startPoint == null || endPoint == null)
                return;
            
            if (Vector3.Distance(
                    _lastStartPos, startPoint.position) > Mathf.Epsilon || 
                    Vector3.Distance(_lastEndPos, endPoint.position) > Mathf.Epsilon
                    )
            {
                Generate();
                _lastStartPos = startPoint.position;
                _lastEndPos = endPoint.position;
            }

            if (Mathf.Abs(_lastMainBranchWidth - mainBranchWidth) > Mathf.Epsilon)
            {
                _lastMainBranchWidth = mainBranchWidth;
                GenerateMesh();
            }
        }

        [Button]
        public void Generate()
        {
            if (startPoint == null || endPoint == null)
                return;
            
            _finalList.Clear();
            _segmentsList.Clear();
            _branchList.Clear();
            
            Vector3 startPos = startPoint.position;
            Vector3 endPos = endPoint.position;
            _rotateAxis = Camera.main.transform.forward;
            float mainBranchLength = Vector3.Distance(startPos, endPos);
            //Main Branch
            ProcessBranch(startPos, endPos, mainBranchLength, _rotateAxis, 0, Vector4.zero);
            for (int curBranchLevel = 1; curBranchLevel < branchGenerationConfigs.Count; curBranchLevel++)
            {
                _tempList2.Clear();
                _tempList2.AddRange(_branchList);
                _branchList.Clear();

                foreach (var segment in _tempList2)
                {
                    ProcessBranch(segment.start, segment.end, mainBranchLength, _rotateAxis, curBranchLevel, segment.positionOnUpperBranch);
                }
            }
            
            GenerateMesh();
        }

        private void ProcessBranch(Vector3 branchStartPos, Vector3 branchEndPos, float mainBranchLength, Vector3 rotateAxis, int curBranchLevel, Vector4 positionOnUpperBranch)
        {
            _segmentsList.Clear();
            _segmentsList.Add(new LightningBoltSegment(branchStartPos, branchEndPos, positionOnUpperBranch, new Vector2(0, 1), curBranchLevel));
            float curBranchLength = Vector3.Distance(branchStartPos, branchEndPos);
            int branchDivideLoop = Mathf.CeilToInt(divideLoop - Mathf.Log(1.0f / (curBranchLength / mainBranchLength), 2)) - 1; 
            branchDivideLoop = branchDivideLoop < 1 ? 1 : branchDivideLoop;
            
            BranchGenerationConfig curBranchConfig = branchGenerationConfigs[curBranchLevel];
            float curOffset = Mathf.Pow(0.5f, curBranchLevel) * curBranchConfig.twistFactor * curBranchLength;
            for (int i = 0; i < branchDivideLoop; i++)
            {
                int segmentIdx = 0;
                float totalSegments = Mathf.Pow(2, i + 1);
                foreach (var segment in _segmentsList)
                {
                    Vector3 segmentStart = segment.start;
                    Vector3 segmentEnd = segment.end;
                    Vector3 offsetPoint = Vector3.Lerp(segmentStart, segmentEnd, curBranchConfig.divisionFactor + Random.Range(-curBranchConfig.divisionFactorRandomValue, curBranchConfig.divisionFactorRandomValue));

                    Vector3 segmentDir = (segmentEnd - segmentStart).normalized;
                    Vector3 perpendicular = Quaternion.AngleAxis(90 * Mathf.Sign(Random.Range(-1, 1)), rotateAxis) * segmentDir;
                    // perpendicular = Quaternion.AngleAxis(Random.Range(-90, 90), segmentDir) * perpendicular;
                    offsetPoint += perpendicular * curOffset;


                    Vector2 toBranchStartDistance =
                        new Vector2(
                            segmentIdx / totalSegments,
                            (segmentIdx + 1) / totalSegments);
                    _tempList.Add(new LightningBoltSegment(segmentStart, offsetPoint, positionOnUpperBranch, toBranchStartDistance, curBranchLevel));
                    
                    toBranchStartDistance =
                        new Vector2(
                            (segmentIdx + 1) / totalSegments,
                            (segmentIdx + 2) / totalSegments);
                    _tempList.Add(new LightningBoltSegment(offsetPoint, segmentEnd, positionOnUpperBranch, toBranchStartDistance, curBranchLevel));
                    
                    //new branch 
                    if (Random.Range(0.0f, 1.0f) < curBranchConfig.generateNewBranchProbability )
                    {
                        Vector3 dir = (branchEndPos - offsetPoint) * curBranchConfig.subBranchLengthFactor;
                        float rotateAngle = Mathf.Sign(
                                                Random.Range(-1, 1)) *
                                                Random.Range(
                                                    curBranchConfig.minBranchRandomAngle,
                                                    curBranchConfig.maxBranchRandomAngle);
                        Vector3 branchPoint = offsetPoint + Quaternion.AngleAxis(rotateAngle, rotateAxis) * dir;

                        Vector4 subBranchPosOnUpperBranch = positionOnUpperBranch;
                        float pos = (segmentIdx + 1) / totalSegments;
                        switch (curBranchLevel)
                        {
                            case 0:
                                subBranchPosOnUpperBranch.x = pos;
                                break;
                            case 1:
                                subBranchPosOnUpperBranch.y = pos;
                                break;
                            case 2:
                                subBranchPosOnUpperBranch.z = pos;
                                break;
                        }
                        _branchList.Add(
                            new LightningBoltSegment(
                                offsetPoint, 
                                branchPoint,
                                subBranchPosOnUpperBranch,
                                Vector2.zero,
                                curBranchLevel + 1)
                            );
                    }

                    //每次都是一分为 2
                    segmentIdx += 2;
                }

                curOffset *= 0.5f;
                _segmentsList.Clear();
                _segmentsList.AddRange(_tempList);
                _tempList.Clear();
            }

            // Debug.Log($"Processing branch {curBranchLevel}, Add {_segmentsList.Count} segments to final list");
            _finalList.AddRange(_segmentsList);
        }

        [FoldoutGroup("Anim"), Range(0, 1)]
        public float subBranchShowTime_1 = 0.2f;
        [FoldoutGroup("Anim"), Range(0, 1)]
        public float subBranchShowTime_2 = 0.1f;
        [FoldoutGroup("Anim"), Range(0, 1)]
        public float subBranchShowTime_3 = 0.05f;
        private float CalculateVerticeShowTime(Vector3 positionOnUpperBranch, float positionOnCurBranch, int curBranch)
        {
            float showTime = 0;

            switch (curBranch)
            {
                case 0:
                    showTime = positionOnCurBranch;
                    break;
                case 1:
                    showTime = positionOnUpperBranch.x + subBranchShowTime_1 * positionOnCurBranch;
                    break;
                case 2:
                    showTime = positionOnUpperBranch.x + subBranchShowTime_1 * positionOnUpperBranch.y  + subBranchShowTime_2 * positionOnCurBranch;
                    break;
                case 3:
                    showTime = positionOnUpperBranch.x + subBranchShowTime_1 * positionOnUpperBranch.y + subBranchShowTime_2 * positionOnUpperBranch.z + subBranchShowTime_3 * positionOnCurBranch;
                    break;
            }
            return showTime;
        }


        [Range(0.1f, 1000f)]
        public float mainBranchWidth = 0.5f;
        
        public Vector4 brightness = Vector4.one;
        private List<Vector3> _vertices = new List<Vector3>();
        private List<int> _triangles = new List<int>();
        private List<Color> _colors = new List<Color>();
        private List<Vector2> _uvs = new List<Vector2>();
        [Button]
        private void GenerateMesh()
        {
            if (_finalList.Count == 0)
                return;
            
            Mesh mesh = new Mesh();
            mesh.indexFormat = IndexFormat.UInt32;
            
            
            _vertices.Clear();
            _triangles.Clear();
            _colors.Clear();
            _uvs.Clear();;
            int vertexIndex = 0;


            Vector3 lightningStartPos = startPoint.position;
            Vector3 previousPoint1 = lightningStartPos, previousPoint2 = lightningStartPos, previousPoint3 = lightningStartPos;
            foreach (var segment in _finalList)
            {
                Vector3 start = segment.start;
                Vector3 end = segment.end;
                Vector2 toBranchStartDistance = segment.toBranchStartDistance;

                float curBranchWidth = mainBranchWidth * 0.0001f / (segment.branchLevel + 1);
                AnimationCurve widthCurve = segment.branchLevel == 0 ? mainBranchWidthCurve : subBranchWidthCurve;
                float startWidth = widthCurve.Evaluate(toBranchStartDistance.x) * curBranchWidth;
                float endWidth = widthCurve.Evaluate(toBranchStartDistance.y) * curBranchWidth;

                Vector3 segmentDir = (end - start).normalized;
                Vector3 point1Dir = Quaternion.AngleAxis(90, _rotateAxis) * segmentDir;
                Vector3 point2Dir = Quaternion.AngleAxis(120, segmentDir) * point1Dir;
                Vector3 point3Dir = Quaternion.AngleAxis(240, segmentDir) * point1Dir;

                // Vector3 startPos = start - lightningStartPos - (end - start) * 0.1f;
                // Vector3 endPos = end - lightningStartPos +  (end - start) * 0.1f;
                
                Vector3 startPos = start - lightningStartPos;//移动到原点
                Vector3 endPos = end - lightningStartPos;//移动到原点

                bool shouldUsePreviousVertices = toBranchStartDistance.x > Mathf.Epsilon;
                //u：存储当前顶点在当前分支中的百分比位置 v：存储当前顶点的亮度因子
                if (!shouldUsePreviousVertices)
                {
                    Vector2 startUV = new Vector2(toBranchStartDistance.x, brightness[segment.branchLevel]);
                    _uvs.Add(startUV);
                    _uvs.Add(startUV);
                    _uvs.Add(startUV);
                }
                Vector2 endUV = new Vector2(toBranchStartDistance.y, brightness[segment.branchLevel]);
                _uvs.Add(endUV);
                _uvs.Add(endUV);
                _uvs.Add(endUV);
                
                //顶点色存储雷电出现时间
                if (!shouldUsePreviousVertices)
                {
                    float startVertexShowTime = CalculateVerticeShowTime(segment.positionOnUpperBranch, toBranchStartDistance.x, segment.branchLevel);
                    Color startColor = new Color(
                        segment.positionOnUpperBranch.x, segment.positionOnUpperBranch.y,
                        segment.positionOnUpperBranch.z, startVertexShowTime);
                    _colors.Add(startColor);
                    _colors.Add(startColor);
                    _colors.Add(startColor);
                }
                float endVertexShowTime = CalculateVerticeShowTime(segment.positionOnUpperBranch, toBranchStartDistance.y, segment.branchLevel);
                Color endColor = new Color(
                    segment.positionOnUpperBranch.x, segment.positionOnUpperBranch.y,
                    segment.positionOnUpperBranch.z, endVertexShowTime);
                _colors.Add(endColor);
                _colors.Add(endColor);
                _colors.Add(endColor);
                
                //起点三角形三个点
                if (!shouldUsePreviousVertices)
                {
                    _vertices.Add(startPos + point1Dir * startWidth);
                    _vertices.Add(startPos + point2Dir * startWidth);
                    _vertices.Add(startPos + point3Dir * startWidth);
                }
                // else
                // {
                //     _vertices.Add(previousPoint1);
                //     _vertices.Add(previousPoint2);
                //     _vertices.Add(previousPoint3);
                // }

                
                
                //终点三角形三个点
                previousPoint1 = endPos + point1Dir * endWidth;
                previousPoint2 = endPos + point2Dir * endWidth;
                previousPoint3 = endPos + point3Dir * endWidth;
                _vertices.Add(previousPoint1);
                _vertices.Add(previousPoint2);
                _vertices.Add(previousPoint3);
                
                //六个点组成六个三角形
                if (!shouldUsePreviousVertices)
                {
                    _triangles.Add(vertexIndex);
                    _triangles.Add(vertexIndex + 5);
                    _triangles.Add(vertexIndex + 2);
                    _triangles.Add(vertexIndex + 0);
                    _triangles.Add(vertexIndex + 3);
                    _triangles.Add(vertexIndex + 5);
                
                    _triangles.Add(vertexIndex + 1);
                    _triangles.Add(vertexIndex + 2);
                    _triangles.Add(vertexIndex + 4);
                    _triangles.Add(vertexIndex + 2);
                    _triangles.Add(vertexIndex + 5);
                    _triangles.Add(vertexIndex + 4);
                
                    _triangles.Add(vertexIndex + 0);
                    _triangles.Add(vertexIndex + 1);
                    _triangles.Add(vertexIndex + 3);
                    _triangles.Add(vertexIndex + 1);
                    _triangles.Add(vertexIndex + 4);
                    _triangles.Add(vertexIndex + 3);
                    vertexIndex += 6;
                }
                else
                {
                    _triangles.Add(vertexIndex - 3);
                    _triangles.Add(vertexIndex + 5 - 3);
                    _triangles.Add(vertexIndex + 2 - 3);
                    _triangles.Add(vertexIndex + 0 - 3);
                    _triangles.Add(vertexIndex + 3 - 3);
                    _triangles.Add(vertexIndex + 5 - 3);
                
                    _triangles.Add(vertexIndex + 1 - 3);
                    _triangles.Add(vertexIndex + 2 - 3);
                    _triangles.Add(vertexIndex + 4 - 3);
                    _triangles.Add(vertexIndex + 2 - 3);
                    _triangles.Add(vertexIndex + 5 - 3);
                    _triangles.Add(vertexIndex + 4 - 3);
                
                    _triangles.Add(vertexIndex + 0 - 3);
                    _triangles.Add(vertexIndex + 1 - 3);
                    _triangles.Add(vertexIndex + 3 - 3);
                    _triangles.Add(vertexIndex + 1 - 3);
                    _triangles.Add(vertexIndex + 4 - 3);
                    _triangles.Add(vertexIndex + 3 - 3);
                    vertexIndex += 3;
                }
            }
            
            mesh.vertices = _vertices.ToArray();
            mesh.triangles = _triangles.ToArray();
            mesh.colors = _colors.ToArray();
            mesh.uv = _uvs.ToArray();

            meshFilter.mesh = mesh;
            
            LightningAnim();
        }


        public Material mat;
        [FormerlySerializedAs("showTime")]
        public float animTime = 1.0f;
        private int _showPercentID = Shader.PropertyToID("_ShowPercent");
        private Coroutine _coroutine;
        [Button]
        public void LightningAnim()
        {
            if (mat == null)
                return;

            if (!playAnim)
            {
                mat.SetFloat(_showPercentID, 1);
                return;
            }
            if (_coroutine != null)
            {
                StopCoroutine(_coroutine);
            }
            _coroutine = StartCoroutine(DoAnim());
        }

        IEnumerator DoAnim()
        {
            float startTime = Time.realtimeSinceStartup;
            while (Time.realtimeSinceStartup - startTime <= animTime)
            {
                mat.SetFloat(_showPercentID, (Time.realtimeSinceStartup - startTime) / animTime);
                yield return null;
            }

            mat.SetFloat(_showPercentID, 1);
        }
        private void OnDrawGizmos()
        {
            if (_finalList.Count > 0)
            {
                foreach (var segment in _finalList)
                {
                    float colorFactor = 1.0f / (segment.branchLevel + 1);
                    colorFactor = Mathf.Pow(colorFactor, 0.8f);
                    Gizmos.color = Color.cyan * colorFactor ;
                    Gizmos.DrawLine(segment.start, segment.end);
                }
            }
        }
    }
}
