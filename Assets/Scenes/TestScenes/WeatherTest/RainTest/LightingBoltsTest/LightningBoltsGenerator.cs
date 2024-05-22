using System;
using System.Collections;
using System.Collections.Generic;
using Sirenix.OdinInspector;
using UnityEngine;
using Random = UnityEngine.Random;

namespace HephaestusGames
{
    public struct LightningBoltSegment
    {
        public LightningBoltSegment(Vector3 startPoint, Vector3 endPoint, int branchLevel = 0)
        {
            start = startPoint;
            end = endPoint;
            this.branchLevel = branchLevel;
        }
        public Vector3 start;
        public Vector3 end;
        public int branchLevel;
    }
    [ExecuteInEditMode]
    public class LightningBoltsGenerator : MonoBehaviour
    {
        [Range(1, 12)]
        public int divideLoop = 10;
        [Range(0, 10)]
        public int subBranchLevel = 4;
        [Range(0, 1)]
        public float maximumOffset;
        [Range(0, 1)]
        public float segmentLerpValue;
        [Range(0, 1)]
        public float segmentLerpRandomValue;
        public Transform startPoint;
        public Transform endPoint;
        public float branchRandomAngle = 5;
        [Range(0, 1)]
        public float branchLengthFactor = 0.1f;
        [Range(0, 1)]
        public float generateNewBranchProbability = 0.1f;

        private List<LightningBoltSegment> _segmentsList = new List<LightningBoltSegment>();
        private List<LightningBoltSegment> _tempList = new List<LightningBoltSegment>();
        private List<LightningBoltSegment> _tempList2 = new List<LightningBoltSegment>();
        
        private List<LightningBoltSegment> _finalList = new List<LightningBoltSegment>();
        private List<LightningBoltSegment> _branchList = new List<LightningBoltSegment>();
        

        private void Update()
        {
            RegenerateIfNeed();
        }

        private Vector3 _lastStartPos;
        private Vector3 _lastEndPos;
        private void RegenerateIfNeed()
        {
            if (startPoint == null || endPoint == null)
                return;
            
            if (Vector3.Distance(_lastStartPos, startPoint.position) > Mathf.Epsilon || Vector3.Distance(_lastEndPos, endPoint.position) > Mathf.Epsilon)
            {
                Generate();
                _lastStartPos = startPoint.position;
                _lastEndPos = endPoint.position;
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
            Vector3 forward = transform.forward;
            float mainBranchLength = Vector3.Distance(startPos, endPos);
            //Main Branch
            ProcessBranch(startPos, endPos, mainBranchLength, forward, 0);
            for (int curBranchLevel = 1; curBranchLevel <= subBranchLevel; curBranchLevel++)
            {
                _tempList2.Clear();
                _tempList2.AddRange(_branchList);
                _branchList.Clear();

                foreach (var segment in _tempList2)
                {
                    ProcessBranch(segment.start, segment.end, mainBranchLength, forward, curBranchLevel);
                }
            }
        }

        private void ProcessBranch(Vector3 branchStartPos, Vector3 branchEndPos, float mainBranchLength, Vector3 rotateAxis, int curBranchLevel)
        {
            // Debug.Log($"Processing branch {curBranchLevel}");
            _segmentsList.Clear();
            _segmentsList.Add(new LightningBoltSegment(branchStartPos, branchEndPos));
            float curBranchLength = Vector3.Distance(branchStartPos, branchEndPos);
            // int branchDivideLoop = Mathf.CeilToInt(divideLoop * curBranchLength / mainBranchLength);
            int branchDivideLoop = Mathf.CeilToInt(divideLoop - Mathf.Log(1.0f / (curBranchLength / mainBranchLength), 2)) - 1; 
            branchDivideLoop = branchDivideLoop < 1 ? 1 : branchDivideLoop;
            float curOffset = Mathf.Pow(0.5f, curBranchLevel) * maximumOffset * curBranchLength;
            for (int i = 0; i < branchDivideLoop; i++)
            {
                foreach (var segment in _segmentsList)
                {
                    Vector3 segmentStart = segment.start;
                    Vector3 segmentEnd = segment.end;
                    Vector3 offsetPoint = Vector3.Lerp(segmentStart, segmentEnd, segmentLerpValue + Random.Range(-segmentLerpRandomValue, segmentLerpRandomValue));
                    
                    Vector3 perpendicular = Quaternion.AngleAxis(90 * Mathf.Sign(Random.Range(-1, 1)), rotateAxis) * (segmentEnd - segmentStart).normalized;
                    offsetPoint += perpendicular * curOffset;
                    
                    
                    _tempList.Add(new LightningBoltSegment(segmentStart, offsetPoint, curBranchLevel));
                    _tempList.Add(new LightningBoltSegment(offsetPoint, segmentEnd, curBranchLevel));
                    
                    //new branch 
                    if (Random.Range(0.0f, 1.0f) < generateNewBranchProbability )
                    {
                        Vector3 dir = (branchEndPos - offsetPoint) * branchLengthFactor;
                        Vector3 branchPoint = offsetPoint + Quaternion.AngleAxis(Random.Range(-branchRandomAngle / (curBranchLevel + 1), branchRandomAngle / (curBranchLevel + 1)), rotateAxis) * dir;
                        _branchList.Add(new LightningBoltSegment(offsetPoint, branchPoint, curBranchLevel + 1));
                    }
                }

                curOffset *= 0.5f;
                _segmentsList.Clear();
                _segmentsList.AddRange(_tempList);
                _tempList.Clear();
            }

            // Debug.Log($"Processing branch {curBranchLevel}, Add {_segmentsList.Count} segments to final list");
            _finalList.AddRange(_segmentsList);
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
                    // Vector3 center = (segment.start + segment.end) * 0.5f;
                    //
                    // Gizmos.DrawCube(center, new Vector3(segment.end.x - segment.start.x, gizmosWidth, gizmosWidth));
                }
            }
        }
    }
}
