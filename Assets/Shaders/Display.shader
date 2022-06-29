Shader "Borg Stuff/Display"
{
    Properties
    {
        _Cube ("Reflection Map", CUBE) = "" {}
        _MainTex ("Texture", 2D) = "white" {}
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

            struct appdata
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float3 worldPos : TEXCOORD0;
                half3 worldNormal : TEXCOORD1;
                float2 uv : TEXCOORD2;
                float4 vertex : SV_POSITION;
            };

            samplerCUBE _Cube;
            sampler2D _MainTex;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
                o.worldNormal = UnityObjectToWorldNormal(v.normal);
                o.uv = v.uv;
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                half3 worldViewDir = normalize(UnityWorldSpaceViewDir(i.worldPos));
                half3 worldRefl = reflect(-worldViewDir, i.worldNormal);
                float4 val = UNITY_SAMPLE_TEXCUBE(unity_SpecCube0, worldRefl);
                return tex2D(_MainTex, i.uv) + DecodeHDR(val, unity_SpecCube0_HDR).rgbr * 0.25;
            }
            ENDCG
        }
    }
}