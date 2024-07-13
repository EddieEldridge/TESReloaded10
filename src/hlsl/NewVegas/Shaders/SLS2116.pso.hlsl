//  Terrain shader with blending of 4 textures
//
// Parameters:
sampler2D BaseMap[7] : register(s0);
sampler2D NormalMap[7] : register(s7);

float4 AmbientColor : register(c1);
float4 PSLightColor[10] : register(c3);
float4 PSLightDir : register(c18);


// Registers:
//
//   Name         Reg   Size
//   ------------ ----- ----
//   AmbientColor const_1       1
//   PSLightColor[0] const_3       1
//   PSLightDir   const_18      1
//   BaseMap      texture_0       4
//   NormalMap    texture_7       4
//


// Structures:

struct VS_INPUT {
    float2 texcoord_0 : TEXCOORD0;
    float3 texcoord_1 : TEXCOORD1_centroid;
    float3 texcoord_2 : TEXCOORD2_centroid;
    float3 texcoord_3 : TEXCOORD3_centroid;
    float3 texcoord_4 : TEXCOORD4_centroid;
    float3 texcoord_5 : TEXCOORD5_centroid;
    float4 color_0 : COLOR0;
    float4 color_1 : COLOR1;
    float4 texcoord_7 : TEXCOORD7_centroid;
};

struct VS_OUTPUT {
    float4 color_0 : COLOR0;
};

#define tint magenta
#include "includes/Helpers.hlsl"
#include "includes/Terrain.hlsl"


// Code:

VS_OUTPUT main(VS_INPUT IN) {
    VS_OUTPUT OUT;

    float4 normal0 = tex2D(NormalMap[0], IN.texcoord_0.xy);
    float4 normal1 = tex2D(NormalMap[1], IN.texcoord_0.xy);
    float4 normal2 = tex2D(NormalMap[2], IN.texcoord_0.xy);
    float4 normal3 = tex2D(NormalMap[3], IN.texcoord_0.xy);

    float3 texture0 = tex2D(BaseMap[0], IN.texcoord_0.xy).rgb;
    float3 texture1 = tex2D(BaseMap[1], IN.texcoord_0.xy).rgb;
    float3 texture2 = tex2D(BaseMap[2], IN.texcoord_0.xy).rgb;
    float3 texture3 = tex2D(BaseMap[3], IN.texcoord_0.xy).rgb;

    float3 tangent = normalize(IN.texcoord_3.xyz);
    float3 binormal = normalize(IN.texcoord_4.xyz);
    float3 normal = normalize(IN.texcoord_5.xyz);
    float3x3 tbn = float3x3(tangent, binormal, normal);
    float3 eyeDir = -mul(tbn, normalize(IN.texcoord_7.xyz));

    float3 baseColor = blendTextures(IN.color_0, IN.color_1, IN.texcoord_1, texture0, texture1, texture2, texture3);
    float3 combinedNormal = normalize(expand(normal0.xyz) * IN.color_0.r + expand(normal1.xyz) * IN.color_0.g + expand(normal2.xyz) * IN.color_0.b + expand(normal3.xyz) * IN.color_0.a);
    float roughness = combineRoughness(IN.color_0, IN.color_1, normal0.a, normal1.a, normal2.a, normal3.a);

    float3 lighting = getSunLighting(tbn, PSLightDir.xyz, PSLightColor[0].rgb, eyeDir, IN.texcoord_7.xyz, combinedNormal, AmbientColor.rgb, baseColor, roughness);

    // apply fog
    // float3 finalColor = (IN.texcoord_7.w * (IN.texcoord_7.xyz - (IN.texcoord_1.xyz * lighting * baseColor))) + (lighting * baseColor * IN.texcoord_1.xyz);
    float3 finalColor = getFinalColor(lighting, baseColor);

    OUT.color_0.a = 1;
    OUT.color_0.rgb = finalColor;

    return OUT;
};

// approximately 49 instruction slots used (8 texture, 41 arithmetic)
