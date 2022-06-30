// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'

// Unity built-in shader source. Copyright (c) 2016 Unity Technologies. MIT license (see license.txt)

// Unlit shader. Simplest possible textured shader.
// - SUPPORTS lightmap
// - no lighting
// - no per-material color

// Further modified from VRChat SDK:
// - Includes directional lightmap support.
// - Accepts an AO bake, not RGB diffuse.

Shader "Borg Stuff/Metal"
{
    Properties
    {
        _MainTex ("Ambient Occlusion", 2D) = "white" {}
        [NoScaleOffset] _BumpMap ("Normalmap", 2D) = "bump" {}
    }

    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        // Non-lightmapped
        Pass
        {
            Tags { "LightMode" = "Vertex" }
            Lighting Off
            SetTexture [_MainTex]
            {
                constantColor (1,1,1,1)
                combine texture, constant // UNITY_OPAQUE_ALPHA_FFP
            }
        }

        // Lightmapped
        Pass
        {
            Tags{ "LIGHTMODE" = "VertexLM" "RenderType" = "Opaque" }

            CGPROGRAM

            #pragma vertex vert
            #pragma fragment frag
            #pragma target 2.0
            #include "UnityCG.cginc"
            #pragma multi_compile_fog
            #define USING_FOG (defined(FOG_LINEAR) || defined(FOG_EXP) || defined(FOG_EXP2))

            // uniforms
            float4 _MainTex_ST;

            // vertex shader input data
            struct appdata
            {
                float3 pos : POSITION;
                float3 uv1 : TEXCOORD1;
                float3 uv0 : TEXCOORD0;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            // vertex-to-fragment interpolators
            struct v2f
            {
                float2 uv0 : TEXCOORD0;
                float2 uv1 : TEXCOORD1;
#if USING_FOG
                fixed fog : TEXCOORD2;
#endif
                float4 pos : SV_POSITION;
                float3 normal : TEXCOORD3;
                float3 tangent : TEXCOORD4;
                float3 bitangent : TEXCOORD5;
                UNITY_VERTEX_OUTPUT_STEREO
            };

            // vertex shader
            v2f vert(appdata IN)
            {
                v2f o;
                UNITY_SETUP_INSTANCE_ID(IN);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

                // compute texture coordinates
                o.uv0 = IN.uv1.xy * unity_LightmapST.xy + unity_LightmapST.zw;
                o.uv1 = IN.uv0.xy * _MainTex_ST.xy + _MainTex_ST.zw;

                // fog
#if USING_FOG
                float3 eyePos = UnityObjectToViewPos(float4(IN.pos, 1));
                float fogCoord = length(eyePos.xyz);  // radial fog distance
                UNITY_CALC_FOG_FACTOR_RAW(fogCoord);
                o.fog = saturate(unityFogFactor);
#endif

                // transform position
                o.pos = UnityObjectToClipPos(IN.pos);

                float3x3 tangentToWorld = (float3x3)unity_ObjectToWorld;

				half3 worldNormal = mul(tangentToWorld, IN.normal);
				half3 worldTangent = mul(tangentToWorld, IN.tangent);

				o.normal = normalize(worldNormal);
				o.tangent = normalize(worldTangent);
				o.bitangent = normalize(mul(tangentToWorld, cross(IN.normal, IN.tangent.xyz) * IN.tangent.w));

                return o;
            }

            // textures
            sampler2D _MainTex;
            UNITY_DECLARE_TEX2D(_BumpMap);

            // fragment shader
            fixed4 frag(v2f IN) : SV_Target
            {
                // Fetch lightmap
                fixed4 col;
                col.rgb = DecodeLightmap(UNITY_SAMPLE_TEX2D(unity_Lightmap, IN.uv0.xy));
                half4 bakedColorTex = UNITY_SAMPLE_TEX2D_SAMPLER(unity_LightmapInd, unity_Lightmap, IN.uv0.xy);
                half3 normal = UnpackNormal(UNITY_SAMPLE_TEX2D(_BumpMap, IN.uv1));
                float3x3 tangentToWorld = float3x3(normalize(IN.tangent), normalize(IN.bitangent), normalize(IN.normal));
				

                half3 worldNormal = mul(normal, tangentToWorld);
                
                col.rgb = DecodeDirectionalLightmap(col.rgb, bakedColorTex, worldNormal);
                col.rgb *= tex2D(_MainTex, IN.uv1.xy).r * 0.125;
                col.a = 1;

                // fog
#if USING_FOG
                col.rgb = lerp(unity_FogColor.rgb, col.rgb, IN.fog);
#endif
                return col;
            }

            ENDCG
        }
    }
}
