//
// Generated by Microsoft (R) D3DX9 Shader Compiler 9.08.299.0000
//
//   vsa shaderdump19/SLS2023.vso /Fcshaderdump19/SLS2023.vso.dis
//
//
// Parameters:

float3 LightDirection[3] : register(c13);
float4 LightPosition[3] : register(c16);
row_major float4x4 ModelViewProj : register(c0);

row_major float4x4 TESR_ShadowCameraToLightTransform[2] : register(c34);

// Registers:
//
//   Name           Reg   Size
//   -------------- ----- ----
//   ModelViewProj[0]  const_0        1
//   ModelViewProj[1]  const_1        1
//   ModelViewProj[2]  const_2        1
//   ModelViewProj[3]  const_3        1
//   LightDirection[0] const_13       1
//   LightPosition[0]  const_16       1
//   LightPosition[1]  const_17       1
//   LightPosition[2]  const_18       1
//


// Structures:

struct VS_INPUT {
    float4 position : POSITION;
    float3 tangent : TANGENT;
    float3 binormal : BINORMAL;
    float3 normal : NORMAL;
    float4 texcoord_0 : TEXCOORD0;

#define	TanSpaceProj	float3x3(IN.tangent.xyz, IN.binormal.xyz, IN.normal.xyz)
};

struct VS_OUTPUT {
    float4 position : POSITION;
    float2 texcoord_0 : TEXCOORD0;
    float3 texcoord_1 : TEXCOORD1;
    float3 texcoord_2 : TEXCOORD2;
    float3 texcoord_3 : TEXCOORD3;
    float4 texcoord_4 : TEXCOORD4;
    float4 texcoord_5 : TEXCOORD5;
	float4 texcoord_6 : TEXCOORD6;
    float4 texcoord_7 : TEXCOORD7;

};

// Code:

VS_OUTPUT main(VS_INPUT IN) {
    VS_OUTPUT OUT;

#define	expand(v)		(((v) - 0.5) / 0.5)
#define	compress(v)		(((v) * 0.5) + 0.5)

    float3 lit0;
    float3 lit2;

    OUT.position.xyzw = mul(ModelViewProj, IN.position.xyzw);
    lit2.xyz = LightPosition[2].xyz - IN.position.xyz;
    lit0.xyz = LightPosition[1].xyz - IN.position.xyz;
    OUT.texcoord_0.xy = IN.texcoord_0.xy;
    OUT.texcoord_1.xyz = normalize(mul(TanSpaceProj, LightDirection[0].xyz));
    OUT.texcoord_2.xyz = mul(TanSpaceProj, normalize(lit0.xyz));
    OUT.texcoord_3.xyz = mul(TanSpaceProj, normalize(lit2.xyz));
    OUT.texcoord_4.w = 0.5;
    OUT.texcoord_4.xyz = compress(lit0.xyz / LightPosition[1].w);	// [-1,+1] to [0,1]
    OUT.texcoord_5.w = 0.5;
    OUT.texcoord_5.xyz = compress(lit2.xyz / LightPosition[2].w);	// [-1,+1] to [0,1]
    OUT.texcoord_6.xyzw = mul(OUT.position.xyzw, TESR_ShadowCameraToLightTransform[0]);
	OUT.texcoord_7.xyzw = mul(OUT.position.xyzw, TESR_ShadowCameraToLightTransform[1]);

    return OUT;
};

// approximately 33 instruction slots used
