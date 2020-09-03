// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "Unlit/Water"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}

        
        //Tesselation
        [Toggle]
        _UseTesselation ("Enable Tesselation", INT) = 1
        _TesselationIntensity ("Tesselation Intensity", FLOAT) = 1

        // Vertex Animation
        _AnimSpeed ("Animation Speed", FLOAT) = 1
        _AnimFrequency ("Animation Frequency", FLOAT) = 1
        _AnimIntensity ("Animation Intensity", FLOAT) = 1
        
        // Colors
        _MainColor ( "Main Water Color", COLOR) = (0,0,0)
        _SecondaryColor ( "Secundary Water Color", COLOR) = (0,0,0)
        _ColorThreashold ("Color adjustment Threashold", Float) = 1
        _FoamColor ("Foam Color", COLOR) = (1,1,1,1)
        // Pattern Textures
        _MainNoise ("Main noise Texture", 2D) = "white"{}
        _NoiseAnim ("Noise Movement Main(XY)/ Secondary(ZW) ", VECTOR) = (0,0,0,0)

        _SecundaryNoise ("Secundary Noise Texture", 2D) = "White" {}
        _AnimIntensity ("Animation Intensity", FLOAT) = 1

        
        //Multiplayers
        _DepthIntensity("Depth Intensity", FLOAT) = 0

        //FOAM
        _FoamIntensity ("Foam Intensity", FLOAT) = 1
        _FoamExponential ("Foam Exponential Factor", FLOAT) = 1


        //Light
        [Toggle]
        _UseFragLight ("Enable Light Per Pixel", INT) = 1
        _SpecularAttn ("Specular attenuation", FLOAT) = 1
        _Shininess ("Specular _Shininess", FLOAT) = 1

         //Noise
        _CellSize ("Voronoi Cell Size", Float) = 1
        _VoronoiThreashold ("Voronoi theashold", Float) = 1


    }
    SubShader
    {
        Tags { "RenderType"="Transparent" "Queue"="Transparent"}
        LOD 100
        blend srcalpha oneminussrcalpha
        Pass
        {


            

            CGPROGRAM
			#pragma target 4.6
            #pragma vertex vert
            #pragma fragment frag
         
            #include "UnityCG.cginc"
            #include "WhiteNoise.cginc"

     

            struct appdata
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0; // Use XW 
                float2 uv2 : TEXCOORD1; // Use XW
                float4 worldPosDepth : TEXCOORD2; // Use other channel 
                float4 screenPos : TEXCOORD3;
                float4 vertex : SV_POSITION;
                float3 normal :  NORMAL;
            };

            int _UseTesselation;
            half4 _LightColor0;
            sampler2D _MainTex, _MainNoise, _SecundaryNoise, _CameraDepthTexture;
            fixed4 _NoiseAnim;
            float4 _MainTex_ST, _MainNoise_ST, _SecundaryNoise_ST;
            half _AnimSpeed, _AnimFrequency, _AnimIntensity;
            half4 _MainColor, _SecondaryColor, _FoamColor;
            half _DepthIntensity , _ColorThreashold;
            half _FoamExponential, _FoamIntensity;
            half _SpecularAttn, _Shininess, _CellSize, _VoronoiThreashold;
         
            v2f vert (appdata v)
            {
                v2f o;
                
                float3 worldPos = mul (unity_ObjectToWorld, v.vertex);
                o.worldPosDepth.xyz = worldPos;
                float3 normalDirection = normalize(
                mul(v.normal, unity_WorldToObject));
                o.normal = normalDirection;
                //UpMovement
                o.vertex = UnityObjectToClipPos(v.vertex);

                o.vertex.y += abs(cos((_Time.y * _AnimSpeed ) + ((worldPos.x + worldPos.z) * _AnimFrequency))) * _AnimIntensity;
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.worldPosDepth.w = -mul(UNITY_MATRIX_MV, v.vertex).z * _ProjectionParams.w;

                o.screenPos = ComputeScreenPos(o.vertex);
                //Vertex Lambert

                //Vertex Specular
                
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                fixed4 tex1 = tex2D(_MainNoise, (i.uv * _MainNoise_ST.xy) + _MainNoise_ST.zw + (_NoiseAnim.xy * _Time.y));
                fixed4 tex2 = tex2D(_SecundaryNoise, (i.uv * _SecundaryNoise_ST.xy) + _SecundaryNoise_ST.zw+ (_NoiseAnim.zw * _Time.y));

                float2 uv = i.screenPos.xy / i.screenPos.w;

                float depth =Linear01Depth(SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, uv+float2(.001,0) * (tex2 * 2 -1)));
                float diff = depth - i.worldPosDepth.w;

                fixed4 color = lerp(_MainColor , _SecondaryColor, i.vertex.y * _ColorThreashold);
                fixed4 finalCol = (_MainColor * tex1+ _SecondaryColor * tex2 + _MainColor);
                finalCol.a = 0.2 + clamp(depth * _DepthIntensity,0,1);
                float intersectGradient = 1 - min(diff / _ProjectionParams.w, 1.0f);
                fixed4 intersectTerm = _FoamColor * pow(intersectGradient, _FoamExponential) * _FoamIntensity;

                finalCol.rgb += intersectTerm;

                //add light
                //Lambert Light


                //NdotL //NdotL*.5-.5

                //Full Lambert
                float3 lambert = saturate(dot(i.normal,_WorldSpaceLightPos0) * .5);
                float3 hlambert = lambert-0.5;
                //Specular light
                float voronoi = voronoiNoise((i.worldPosDepth.xz)/ _CellSize);
                return finalCol + voronoi*_VoronoiThreashold;
                //return finalCol + (float4(hlambert,0));
            }
            ENDCG
        }
    }
}
