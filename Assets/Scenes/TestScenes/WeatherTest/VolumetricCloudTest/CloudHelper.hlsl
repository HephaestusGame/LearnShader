#ifndef CLOUD_HELPER_HLSL
#define CLOUD_HELPER_HLSL

// #define PI 3.141592653

struct CloudInfo
{
    float density;
    float absorptivity;
};

//计算射线与 AABB Box的距离， invRayDir为射线方向的倒数
float2 RayBoxDist(float3 boundsMin, float3 boundsMax, float3 rayOrigin, float3 invRayDir)
{
    float3 t0 = (boundsMin.xyz - rayOrigin) * invRayDir;//射线原点到AABB最小点的距离
    float3 t1 = (boundsMax.xyz - rayOrigin) * invRayDir;//射线原点到AABB最大点的距离
    float3 tmin = min(t0, t1);//xyz三个分量分别取最小值
    float3 tmax = max(t0, t1);//xyz三个分量分别取最大值

    float enterDst = max(max(tmin.x, tmin.y), tmin.z);//xyz三个平面的最大值即为进入包围盒的距离
    float exitDst = min(min(tmax.x, tmax.y), tmax.z);//xyz三个平面的最小值即为离开包围盒的距离

    float dstToBox = max(0, enterDst);//如果进入包围盒的距离小于0，则说明射线不与包围盒相交，返回0
    float dstInsideBox = max(0, exitDst - dstToBox);
    return float2(dstToBox, dstInsideBox);
}

//返回射线到球体的距离以及射线在球体内的长度
float2 RaySphereDist(float3 sphereCenter, float sphereRadius, float3 rayOrigin, float3 rayDir)
{
    float3 oc = rayOrigin - sphereCenter;
    float a = dot(rayDir, rayDir);
    float b = 2.0 * dot(oc, rayDir);
    float c = dot(oc, oc) - sphereRadius * sphereRadius;
    float discriminant = b * b - 4.0 * a * c;
    if (discriminant < 0.0)//无交点
    {
        return 0;
    }

    float sqrtDiscriminant = sqrt(discriminant);
    float enterDist = (-b - sqrtDiscriminant) / (2.0 * a);
    enterDist = max(0, enterDist);
    float exitDist = (-b + sqrtDiscriminant) / (2.0 * a);
    exitDist = max(0, exitDist);

    return float2(enterDist, exitDist - enterDist);
}

float2 RayCloudLayerDist(
    float3 sphereCenter,
    float earthRaidus,
    float cloudLayerHeightMin,
    float cloudLayerHeightMax,
    float3 pos,
    float3 rayDir,
    bool isShape = true)
{
    float2 cloudDistMin = RaySphereDist(sphereCenter, earthRaidus + cloudLayerHeightMin, pos, rayDir);
    float2 cloudDistMax = RaySphereDist(sphereCenter, earthRaidus + cloudLayerHeightMax, pos, rayDir);

    //射线起点到云层到距离
    float distToCloudLayer = 0;
    //射线穿过云层的距离
    float distInCloudLayer = 0;


    //计算云形状时
    if (isShape)
    {
        //在地表上
        if (pos.y <= cloudLayerHeightMin)
        {
            float3 startPos = pos + rayDir * cloudDistMin.y;

            //开始步进的点在水平面上时才计算云，地平线以下没有云
            if (startPos.y > 0)
            {
                return float2(cloudDistMin.y, cloudDistMax.y - cloudDistMin.y);
            }
            else
            {
                return float2(0, 0);
            }
        }

        //云层内
        if (pos.y > cloudLayerHeightMin && pos.y <= cloudLayerHeightMax)
        {
            //如果射线与内层云相交，射线在云层内长度为到内层云距离，如果射线与外层云相交，射线在云层内长度为在外层云内的长度
            return float2(0, cloudDistMin.y > 0 ? cloudDistMin.x : cloudDistMax.y);
        }

        //云层外
        if (pos.y > cloudLayerHeightMax)
        {
            //与外围云层都不相交，则与云层肯定不相交
            if (cloudDistMax.y == 0)
                return float2(0, 0);

           
            if (cloudDistMax.y > 0)
            {

                //只与外围云层相交  
                if (cloudDistMin.y == 0)
                {
                    return cloudDistMax;
                }
                
                //与两层云都相交
                return float2(cloudDistMax.x,  cloudDistMin.x - cloudDistMax.x);
            }
        }
        return float2(0, 0);
    }
    else//计算云层光照时，肯定在云层内部
    {
        //如果射线与内层云相交，射线在云层内长度为到内层云距离，如果射线与外层云相交，射线在云层内长度为在外层云内的长度
        return float2(0, cloudDistMin.y > 0 ? cloudDistMin.x : cloudDistMax.y);
    }
}

//在三个值间进行插值, value1 -> value2 -> value3， x < offset时在[value1, value2]插值, x >= offset时在 [value2, value3]插值
float Interpolation3(float value1, float value2, float value3, float x, float offset = 0.5)
{
    offset = clamp(offset, 0.0001, 0.9999);
    return lerp(lerp(value1, value2, min(x, offset) / offset), value3, max(0, x - offset) / (1.0 - offset));
}

//在三个值间进行插值, value1 -> value2 -> value3，  x < offset时在[value1, value2]插值, x >= offset时在 [value2, value3]插值
float3 Interpolation3(float3 value1, float3 value2, float3 value3, float x, float offset = 0.5)
{
    offset = clamp(offset, 0.0001, 0.9999);
    return lerp(lerp(value1, value2, min(x, offset) / offset), value3, max(0, x - offset) / (1.0 - offset));
}

//计算当前点在云层内的高度比例（0-1）
float GetHeightFraction(float3 sphereCenter, float earthRadius, float3 pos, float heightMin, float heightMax)
{
    float height = length(pos - sphereCenter) - earthRadius;
    return saturate((height - heightMin) / (heightMax - heightMin));
}

//重映射 将[original_min, original_max]范围的值重新映射为[new_min, new_max]范围的值
float Remap(float original_value, float original_min, float original_max, float new_min, float new_max)
{
    return new_min + ((original_value - original_min) / (original_max - original_min)) * (new_max - new_min);
}

//获取云类型密度
//[cloud_min, cloud_max]为当前云类型的高度比例范围, feather为云的羽化程度, heightFraction为当前点在云层内的高度比例
//在[cloud_min, cloud_min + feather * 0.5]范围的密度为[0,1]
//在[cloud_min + feather * 0.5, cloud_max - feather]范围的密度为1
//在[cloud_max - feather, cloud_max]范围的密度为[1, 0]
float GetCloudTypeDensity(float heightFraction, float cloud_min, float cloud_max, float feather)
{
    //云的底部羽化需要弱一些，所以乘0.5
    return saturate(Remap(heightFraction, cloud_min, cloud_min + feather * 0.5, 0, 1)) *
            saturate(Remap(heightFraction, cloud_max - feather, cloud_max, 1, 0));
}

//Beer衰减
float Beer(float density, float absorptivity = 1)
{
    return exp(-density * absorptivity);
}

//粉糖效应，模拟云的内散射影响
float BeerPowder(float density, float absorptivity = 1)
{
    return 2.0 * exp(-density * absorptivity) * (1.0 - exp(-2.0 * density));
}

//Henyey-Greenstein相位函数
float HenyeyGreenstein(float angle, float g)
{
    float g2 = g * g;
    return(1.0 - g2) / (4.0 * PI * pow(1.0 + g2 - 2.0 * g * angle, 1.5));
}

//两层Henyey-Greenstein散射，使用Max混合。同时兼顾向前 向后散射
float HGScatterMax(float angle, float g_1, float intensity_1, float g_2, float intensity_2)
{
    return max(intensity_1 * HenyeyGreenstein(angle, g_1), intensity_2 * HenyeyGreenstein(angle, g_2));
}

//两层Henyey-Greenstein散射，使用Lerp混合。同时兼顾向前 向后散射
float HGScatterLerp(float angle, float g_1, float g_2, float weight)
{
    return lerp(HenyeyGreenstein(angle, g_1), HenyeyGreenstein(angle, g_2), weight);
}

//获取光照亮度
float GetLightEnergy(float density, float absorptivity, float darknessThreshold)
{
    float energy = BeerPowder(density, absorptivity);
    return darknessThreshold + (1.0 - darknessThreshold) * energy;
}

#endif
