// Volumetric Fog fullscreen shader for Oblivion/Skyrim Reloaded

float4 TESR_FogColor;
float4 TESR_FogData;
float4 TESR_VolumetricFogLow; // Low Fog
float4 TESR_ReciprocalResolution;
float4 TESR_SunDirection;
float4 TESR_SunPosition;
float4 TESR_SunColor;
float4 TESR_SunAmbient;
float4 TESR_HorizonColor;
float4 TESR_SkyLowColor;
float4 TESR_SkyColor; // top sky color
float4 TESR_SkyData; // x: athmosphere thickness, y: sun influence, z: sun strength w: sky strength
float4 TESR_DebugVar; 
float4 TESR_SunsetColor; // color boost for sun when near the horizon
float4 TESR_SunAmount; // x: isDaytime
float4 TESR_VolumetricFogHigh; // General Fog
float4 TESR_VolumetricFogSimple; // Simple Fog
float4 TESR_VolumetricFogBlend; // Simple Fog

sampler2D TESR_RenderedBuffer : register(s0) = sampler_state { ADDRESSU = CLAMP; ADDRESSV = CLAMP; MAGFILTER = LINEAR; MINFILTER = LINEAR; MIPFILTER = LINEAR; };
sampler2D TESR_DepthBuffer : register(s1) = sampler_state { ADDRESSU = CLAMP; ADDRESSV = CLAMP; MAGFILTER = LINEAR; MINFILTER = LINEAR; MIPFILTER = LINEAR; };

/*Height-based fog settings*/
static const float fogHeight = 4096; 
static const float NOISE_SCALE = 4.2;
static const float sunScatter = 8.0; //raise to decrease the intensity of sun fog
static const float FOG_GROUND =	15000;
static const float FOG_HEIGHT = 25000;

static const float nearFogDistance = TESR_FogData.x;
static const float farFogDistance = TESR_FogData.y;
static const float SunGlare = TESR_FogData.z;
static const float FogPower = TESR_FogData.w;

static const float SUNINFLUENCE = 1/TESR_SkyData.y;

//static const float4x4 ditherMat = {{0.0588, 0.5294, 0.1765, 0.6471},
//									{0.7647, 0.2941, 0.8824, 0.4118},
//									{0.2353, 0.7059, 0.1176, 0.5882},
//									{0.9412, 0.4706, 0.8235, 0.3259}};

#include "Includes/Depth.hlsl"
#include "Includes/Helpers.hlsl"
#include "Includes/Sky.hlsl"

struct VSOUT
{
	float4 vertPos : POSITION;
	float2 UVCoord : TEXCOORD0;
};

struct VSIN
{
	float4 vertPos : POSITION0;
	float2 UVCoord : TEXCOORD0;
};

VSOUT FrameVS(VSIN IN)
{
	VSOUT OUT = (VSOUT)0.0f;
	OUT.vertPos = IN.vertPos;
	OUT.UVCoord = IN.UVCoord;
	return OUT;
}

float nightTime (float input, float dayTime) {
	return ((1.0 - dayTime) * input) + dayTime;
}

float applyHeightFog(float distance, float distanceFactor, float3 cameraToPoint, float fogFactor, float densityFactor, float falloffFactor)
{
	// calculate fog amount
	float density = 0.08 * densityFactor * 0.000006; //0.0002
	float falloff = 0.02 * falloffFactor * 0.00225;
    float fogAmount = max(0.0,density/falloff) * exp(-TESR_CameraPosition.z*falloff) * (1.0-exp(-distance*cameraToPoint.z*falloff))/cameraToPoint.z;
	// color with fog
    return pows(fogAmount * distanceFactor,fogFactor);
}

float3 applySimpleFog(float3 color, float3 fogColor, float distance, float be, float bi)
{
	return color * exp(-distance*be) + fogColor * (1.0-exp(-distance*bi));
}

float4 VolumetricFog(VSOUT IN) : COLOR0 
{
	float3 color = tex2D(TESR_RenderedBuffer, IN.UVCoord).rgb;
	float3 linearColor = pows(color,2.2); //linearise
	float3 fogColor = pows(TESR_FogColor.rgb,2.2); //linearise

    float depth = readDepth(IN.UVCoord);
	float3 eyeVector = toWorld(IN.UVCoord);
    float height = reconstructWorldPosition(IN.UVCoord).z;
	float3 eyeDirection = normalize(eyeVector);
	float fogDepth = length(eyeVector * depth);

    float isDayTime = smoothstep(0, 0.5, TESR_SunAmount.x);

	float nearDist = nearFogDistance;
	// apply weather impact
	float distance = max(0.00001, invlerps(nearDist, max(nearDist,farFogDistance), fogDepth));
	height = saturate(exp( -height/(5500.0 * TESR_DebugVar.x)));
	distance = distance * height; // fade with height

	// calculate sun & sky color
	float3 up = blue.xyz;
    float sunHeight = shade(TESR_SunPosition.xyz, up);
    float sunDir = dot(eyeDirection, TESR_SunPosition.xyz);
	float sunInfluence = pows(compress(sunDir), SUNINFLUENCE);
    float3 sunColor = GetSunColor(sunHeight, 1, TESR_SunAmount.x, TESR_SunColor.rgb, TESR_SunsetColor.rgb);
	float3 skyColor = GetSkyColor(0, 0.5, sunHeight, sunInfluence, TESR_SkyData.z, TESR_SkyColor.rgb, TESR_SkyLowColor.rgb, TESR_HorizonColor.rgb, sunColor);

	// calculate sun color area
    float sunAmount = dot(eyeDirection, TESR_SunDirection.xyz);
    //fogColor = lerp(fogColor, sunColor, sunAmount);
	
	// use luminance to color bright parts of the night sky, simulating light within the fog
	//float lumaDiff = 1.0 - saturate(luma(fogColor) / luma(linearColor));
	//fogColor = lerp(fogColor, luma(fogColor) * color, lumaDiff * (1.0 - isDayTime));

	// low height fog uses fog color and a stronger sun factor
	float4 lowFog = float4(fogColor,applyHeightFog(fogDepth, distance, eyeDirection, 0.45 * TESR_VolumetricFogLow.z, 50 * TESR_VolumetricFogLow.x * (1.0 + saturate(1.0-FogPower)), 8.5 * TESR_VolumetricFogLow.y) * TESR_VolumetricFogBlend.x);
	
	
	// general fog, uses skyColor (includes Sun)
	
	fogColor = lerp(pows(TESR_FogColor.rgb,2.2), skyColor, pows(depth/farZ, 0.1 * TESR_VolumetricFogHigh.w) * isDayTime); // fade color between fog to horizon based on depth
    fogColor = lerp(fogColor, sunColor, sunAmount * saturate(TESR_VolumetricFogLow.w * isDayTime));
	//float4 heightFog = float4(fogColor * 2.0,applyHeightFog(fogDepth, fogDepth, eyeDirection, 0.15, 1.8, 4.0, isDayTime, 1.0));
	float4 heightFog = float4(fogColor, applyHeightFog(fogDepth, distance, eyeDirection, 0.74 * TESR_VolumetricFogHigh.z * 0.7, 50 * TESR_VolumetricFogHigh.x, 2.5 * TESR_VolumetricFogHigh.y) * TESR_VolumetricFogBlend.y);
	
	float2 colorScalar = normalize(float2(lowFog.a, heightFog.a));
	fogColor = (lowFog.rgb * colorScalar.x + heightFog.rgb * colorScalar.y) / (colorScalar.x + colorScalar.y);
	
	// use luminance to color bright parts of the night sky, simulating light within the fog
	//float lumaDiff = 1.0 - saturate(luma(fogColor) / luma(linearColor));
	//fogColor = lerp(fogColor, luma(fogColor) * color, lumaDiff * (1.0 - isDayTime));
	
	heightFog.rgb = min(1.6e+6f, lerp(linearColor, fogColor.rgb, saturate(pows(max(heightFog.a,lowFog.a), 1.0 / TESR_VolumetricFogBlend.z)))); // fade color between fog to horizon based on depth

	//fogColor = (lowFog.rgb + generalFog.rgb) / 2.0; // fade color between fog to horizon based on depth	
	//lowFog.a = 0.0;
	//fogColor = generalFog.rgb; // fade color between fog to horizon based on depth
	fogColor = lerp(pows(TESR_FogColor.rgb,2.2), skyColor, pows(depth/farZ, 0.22 * TESR_VolumetricFogSimple.w) * isDayTime); // fade color between fog to horizon based on depth
    fogColor = lerp(fogColor, sunColor, sunAmount * saturate(TESR_VolumetricFogLow.w * isDayTime));

	// use luminance to color bright parts of the night sky, simulating light within the fog
	float lumaDiff = 1.0 - saturate(luma(fogColor) / luma(linearColor));
	fogColor = lerp(fogColor, luma(fogColor) * color, lumaDiff * (1.0 - isDayTime));

	float3 simpleFog = applySimpleFog(linearColor, fogColor, distance, 5.0 * TESR_VolumetricFogSimple.x * nightTime(2.5 * TESR_VolumetricFogSimple.z, isDayTime), 8.25 * TESR_VolumetricFogSimple.y);
	

    fogColor = lerp(simpleFog.rgb, heightFog.rgb, saturate(1.25 * TESR_VolumetricFogBlend.w * FogPower) * isDayTime);

	linearColor = pows(max(0.0,fogColor),1.0/2.2); //delinearise
	return float4(linearColor, 1.0f);
}

technique
{
	pass
	{
		VertexShader = compile vs_3_0 FrameVS();
		PixelShader  = compile ps_3_0 VolumetricFog();
	}
}
