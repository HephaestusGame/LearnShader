using System.Collections;
using System.Collections.Generic;
using HephaestusGames;
using UnityEngine;
using UnityEngine.Serialization;

namespace HephaestusGame
{

    public enum LightningBoltsAnimType
    {
        NONE = 0,
        LIGHTNING_STRIKE = 1,
        LOOP = 2,
        STRIKE_AND_LOOP = 3
    }
    [RequireComponent(typeof(LightningBoltsGenerator))]
    public class LightningBoltsAnimController : MonoBehaviour
    {
        
        public LightningBoltsAnimType animType = LightningBoltsAnimType.NONE;
        [FormerlySerializedAs("animDuration")]
        public float strikeDuration = 0.2f;
        public float loopInterval = 0.1f;
        
        private int _animProgressID = Shader.PropertyToID("_AnimProgress");
        private int _animTotalDurationID = Shader.PropertyToID("_TotalAnimDuration");
        private Coroutine _coroutine;
        private LightningBoltsGenerator _lightningBoltsGenerator;
        private float TotalAnimDuration => 1 + _lightningBoltsGenerator.subBranchShowTime_1 + _lightningBoltsGenerator.subBranchShowTime_2 + _lightningBoltsGenerator.subBranchShowTime_3;
        
        void Start()
        {
            _lightningBoltsGenerator = GetComponent<LightningBoltsGenerator>();
        }

        private LightningBoltsAnimType _lastAnimType = LightningBoltsAnimType.NONE;
        void Update()
        {

            if (_lightningBoltsGenerator.mat == null)
                return;
            
            _lightningBoltsGenerator.mat.SetFloat(_animTotalDurationID, TotalAnimDuration);

            //把上一个动画类型中断
            bool changed = animType != _lastAnimType;
            _lastAnimType = animType;
            if (changed && _coroutine != null)
            {
                StopCoroutine(_coroutine);
                _coroutine = null;
            }
            
            switch (animType)
            {
                case LightningBoltsAnimType.NONE:
                    _lightningBoltsGenerator.mat.SetFloat(_animProgressID, 1);
                    break;
                case LightningBoltsAnimType.LOOP:
                    if (changed)
                    {
                        _coroutine = StartCoroutine(LoopAnim());
                    }
                    break;
                case LightningBoltsAnimType.LIGHTNING_STRIKE:
                    if (changed)
                    {
                        _coroutine = StartCoroutine(Strike());
                    }
                    break;
                case LightningBoltsAnimType.STRIKE_AND_LOOP:
                    if (changed)
                    {
                        _coroutine = StartCoroutine(StrikeAndLoop());
                    }
                    break;
            }
        }

        IEnumerator Strike()
        {
            while (true)
            {
                float startTime = Time.realtimeSinceStartup;

                while (Time.realtimeSinceStartup - startTime <= strikeDuration)
                {
                    _lightningBoltsGenerator.mat.SetFloat(_animTotalDurationID, TotalAnimDuration);
                    _lightningBoltsGenerator.mat.SetFloat(_animProgressID, (Time.realtimeSinceStartup - startTime) / strikeDuration);
                    yield return null;
                }

                _lightningBoltsGenerator.mat.SetFloat(_animProgressID, 1);
                _lightningBoltsGenerator.Generate();
            }
        }

        IEnumerator LoopAnim()
        {
            float lastLoopTime = -9999;
            while (true)
            {
                if (Time.realtimeSinceStartup - lastLoopTime >= loopInterval)
                {
                    lastLoopTime = Time.realtimeSinceStartup;
                    _lightningBoltsGenerator.mat.SetFloat(_animProgressID, 1);
                    _lightningBoltsGenerator.Generate();
                }

                yield return null;
            }
        }

        IEnumerator StrikeAndLoop()
        {
            yield return Strike();
            yield return LoopAnim();
        }
    }
}
