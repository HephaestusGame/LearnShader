#ifndef CASCADE_SHADOW_UTILS_INCLUDED
#define CASCADE_SHADOW_UTILS_INCLUDED
#include "UnityCG.cginc"

UNITY_DECLARE_SHADOWMAP(_CascadeShadowMapTexture);
//-----------------------------------------------------------------------------------------
// GetCascadeWeights_SplitSpheres
//-----------------------------------------------------------------------------------------
inline float4 GetCascadeWeights_SplitSpheres(float3 wpos)
{
	float3 fromCenter0 = wpos.xyz - unity_ShadowSplitSpheres[0].xyz;
	float3 fromCenter1 = wpos.xyz - unity_ShadowSplitSpheres[1].xyz;
	float3 fromCenter2 = wpos.xyz - unity_ShadowSplitSpheres[2].xyz;
	float3 fromCenter3 = wpos.xyz - unity_ShadowSplitSpheres[3].xyz;
	float4 distances2 = float4(dot(fromCenter0, fromCenter0), dot(fromCenter1, fromCenter1), dot(fromCenter2, fromCenter2), dot(fromCenter3, fromCenter3));
	//unity_ShadowSplitSqRadii为四个 Cascade 阴影球的半径平方
	float4 weights = float4(distances2 < unity_ShadowSplitSqRadii);
	weights.yzw = saturate(weights.yzw - weights.xyz);
	return weights;
}

//-----------------------------------------------------------------------------------------
// GetCascadeShadowCoord
//-----------------------------------------------------------------------------------------
inline float4 GetCascadeShadowCoord(float4 wpos, float4 cascadeWeights)
{
	float3 sc0 = mul(unity_WorldToShadow[0], wpos).xyz;
	float3 sc1 = mul(unity_WorldToShadow[1], wpos).xyz;
	float3 sc2 = mul(unity_WorldToShadow[2], wpos).xyz;
	float3 sc3 = mul(unity_WorldToShadow[3], wpos).xyz;
			
	float4 shadowMapCoordinate = float4(sc0 * cascadeWeights[0] + sc1 * cascadeWeights[1] + sc2 * cascadeWeights[2] + sc3 * cascadeWeights[3], 1);
#if defined(UNITY_REVERSED_Z)
	float  noCascadeWeights = 1 - dot(cascadeWeights, 1);
	shadowMapCoordinate.z += noCascadeWeights;
#endif
	return shadowMapCoordinate;
}

//-----------------------------------------------------------------------------------------
// GetLightAttenuation
//-----------------------------------------------------------------------------------------
float GetLightAttenuation(float3 wpos)
{
	float atten = 0;
	// sample cascade shadow map
	float4 cascadeWeights = GetCascadeWeights_SplitSpheres(wpos);
	bool inside = dot(cascadeWeights, float4(1, 1, 1, 1)) < 4;
	float3 samplePos = GetCascadeShadowCoord(float4(wpos, 1), cascadeWeights);
	atten = inside ? UNITY_SAMPLE_SHADOW(_CascadeShadowMapTexture, samplePos.xyz) : 1.0f;
	// _LightShadowData.x - shadow strength
	// _LightShadowData.y - Appears to be unused
	// _LightShadowData.z - 1.0 / shadow far distance
	// _LightShadowData.w - shadow near distance
	atten = _LightShadowData.r + atten * (1 - _LightShadowData.r);
	return atten;
}
#endif
