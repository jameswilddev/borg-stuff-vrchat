Shader "Borg Stuff/Display"
{
    Properties
    {
        _Cube ("Reflection Map", CUBE) = "" {}
        _MainTex ("Texture", 2D) = "white" {}
        _AmbientOcclusion ("Ambient Occlusion", 2D) = "white" {}
        [NoScaleOffset] _BumpMap ("Normalmap", 2D) = "bump" {}
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"
            #pragma multi_compile_fog
            #define USING_FOG (defined(FOG_LINEAR) || defined(FOG_EXP) || defined(FOG_EXP2))

            // uniforms
            float4 _MainTex_ST;
            float4 _AmbientOcclusion_ST;

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv0 : TEXCOORD0;
                float2 uv1 : TEXCOORD1;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct v2f
            {
                float3 worldPos : TEXCOORD0;
#if USING_FOG
                fixed fog : TEXCOORD1;
#endif
                float2 uv0 : TEXCOORD2;
                float2 uv1 : TEXCOORD3;
                float2 uv2 : TEXCOORD4;
                float4 vertex : SV_POSITION;
                float3 normal : TEXCOORD5;
                float3 tangent : TEXCOORD6;
                float3 bitangent : TEXCOORD7;
                UNITY_VERTEX_OUTPUT_STEREO
            };

            samplerCUBE _Cube;
            sampler2D _MainTex;
            sampler2D _AmbientOcclusion;
            UNITY_DECLARE_TEX2D(_BumpMap);

            v2f vert (appdata v)
            {
                v2f o;
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
                o.uv0 = v.uv0 * _MainTex_ST.xy + _MainTex_ST.zw;
                o.uv1 = v.uv1;
                o.uv2 = v.uv1;// * _AmbientOcclusion_ST.xy + _AmbientOcclusion_ST.zw;

                // fog
#if USING_FOG
                float3 eyePos = UnityObjectToViewPos(v.vertex);
                float fogCoord = length(eyePos.xyz);  // radial fog distance
                UNITY_CALC_FOG_FACTOR_RAW(fogCoord);
                o.fog = saturate(unityFogFactor);
#endif

                float3x3 tangentToWorld = (float3x3)unity_ObjectToWorld;

				half3 worldNormal = mul(tangentToWorld, v.normal);
				half3 worldTangent = mul(tangentToWorld, v.tangent);

				o.normal = normalize(worldNormal);
				o.tangent = normalize(worldTangent);
				o.bitangent = normalize(mul(tangentToWorld, cross(v.normal, v.tangent.xyz) * v.tangent.w));

                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                half3 normal = UnpackNormal(UNITY_SAMPLE_TEX2D(_BumpMap, i.uv1));
                float3x3 tangentToWorld = float3x3(normalize(i.tangent), normalize(i.bitangent), normalize(i.normal));
                half3 worldNormal = mul(normal, tangentToWorld);

                half3 worldViewDir = normalize(UnityWorldSpaceViewDir(i.worldPos));
                half3 worldRefl = reflect(-worldViewDir, worldNormal);
                float4 val = UNITY_SAMPLE_TEXCUBE(unity_SpecCube0, worldRefl);
                fixed4 col = tex2D(_MainTex, i.uv0) + DecodeHDR(val, unity_SpecCube0_HDR).rgbr * tex2D(_AmbientOcclusion, i.uv2).r;

                // fog
#if USING_FOG
                col.rgb = lerp(unity_FogColor.rgb, col.rgb, i.fog);
#endif

                return col;
            }
            ENDCG
        }
    }
}