using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace HephaestusGame
{
    public class HaltonSequence 
    {
        public static float halton(int index, int baseNum)
        {
            float result = 0;
            float f = 1;
            while (index > 0)
            {
                f = f / baseNum;
                result += f * (index % baseNum);
                index = index / baseNum; 
                //index = int(floor(float(index) / float(base)));
            }
            return result;
        }


        public static Vector2[] GenerateSequence(int count, int base1, int base2)
        {
            Vector2[] result = new Vector2[count];
            for (int i = 0; i < count; i++)
            {
                result[i].x = halton(i, base1);
                result[i].y = halton(i, base2); 
            }
            return result;
        }
    }
}
