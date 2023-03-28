Shader "shader/GeometryGrass"
{
	Properties
	{
		 [Header(Main)]
		_BottomColor("Bottom Color", Color) = (0,1,0,1)
		_TopColor("Top Color", Color) = (1,1,0,1)
		_GrassHeight("Grass Height", Float) = 1
		_GrassWidth("Grass Width", Float) = 0.06
		_RandomHeight("Grass Height Randomness", Float) = 0.25
		_EmitInt("Emission Strength", range(1,10)) = 1
		_AmbientStrength("Ambient Strength",  Range(0,1)) = 0.5
		[Header(Wind)]
		_WindSpeed("Wind Speed", Float) = 100
		_WindStrength("Wind Strength", Float) = 0.05
		[Header(Interactive)]
		_Radius("Interactor Radius", Float) = 0.3
		_Power("Interactor Strength", Float) = 5
        	[Header(Blade)]
		_BladeRad("Blade Radius", Range(0,1)) = 0.6
		_BladeForward("Blade Forward Amount", Float) = 0.38
		_BladeCurve("Blade Curvature Amount", Range(1, 4)) = 2
        	[Header(Visible)]
		_MinDist("Min Distance", Float) = 40
		_MaxDist("Max Distance", Float) = 60
		
	}
HLSLINCLUDE
#pragma vertex vert
#pragma fragment frag
#pragma require geometry
#pragma geometry geom
#pragma multi_compile _ _MAIN_LIGHT_SHADOWS
#pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
#pragma multi_compile_fwdbase
#pragma multi_compile_fragment _ _SHADOWS_SOFT
#pragma multi_compile _ LIGHTMAP_SHADOW_MIXING
#pragma multi_compile _ SHADOWS_SHADOWMASK
#pragma multi_compile _ DIRLIGHTMAP_COMBINED
#pragma multi_compile _ LIGHTMAP_ON
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"	
		struct a2v
	{
		float4 pos : POSITION;
		float3 normal :NORMAL;
		float2 texcoord : TEXCOORD0;
		float4 color : COLOR;
		float4 tangent :TANGENT;
	};
	struct v2g
	{
		float4 pos : SV_POSITION;
		float2 uv : TEXCOORD0;
		float3 worldNormal : TEXCOORD1;
		float4 color : COLOR;
		float4 tangent : TANGENT;

	};
	struct g2f
	{
		float4 pos : SV_POSITION;
		float2 uv : TEXCOORD0;
		float3 worldNormal : TEXCOORD1;
		float3 worldPos : TEXCOORD2;
		float3 diffuseColor : COLOR;
	
	};
	     half _GrassHeight;
		 half _GrassWidth;

		 half _WindSpeed;
		 float _WindStrength;
		//Interactive
		 half _Radius, _Power;
		float _BladeRad;
	    float _RandomHeight;
		float _BladeForward;
		 float _BladeCurve;
		 float _MinDist, _MaxDist;
		 float3 _PositionMoving;
#define GrassSegments 5 
#define GrassBlades 6
	v2g vert(a2v v)
	{
		float3 vertex0 = v.pos;
		v2g o;    
		o.pos = v.pos;  
		o.uv = v.texcoord;
		o.color = v.color;
		o.worldNormal = TransformObjectToWorldNormal(v.normal);
		o.tangent = v.tangent;
		return o;
	}
	float rand(float3 input)
	{
		return frac(sin(dot(input.xyz, float3(12, 78, 53))) * 876557);
	}
	    // Construct a rotation matrix that rotates around the provided axis, sourced from:
// https://gist.github.com/keijiro/ee439d5e7388f3aafc5296005c8c3f33
	float3x3 AngleAxis3x3(float angle, float3 axis)
	{
		
		float c, s;  
		sincos(angle, s, c);
		float t = 1 - c;
		float x = axis.x;
		float y = axis.y;
		float z = axis.z;
		return float3x3(
			t * x * x + c,        t * x * y - s * z,   t * x * z + s * y,
			t * y * x + s * z,    t * y * y + c,       t * y * z - s * x,
			t * z * x - s * y,    t * z * y + s * x,   t * z * z + c
			);
	}
	float4 GetShadowPositionHClip(float3 input, float3 normal)
	{
		float3 positionWS = TransformObjectToWorld(input.xyz);
		float3 normalWS = TransformObjectToWorldNormal(normal);
		float4 positionCS = TransformWorldToHClip(ApplyShadowBias(positionWS, normalWS, 0));
		return positionCS;
	
	}

	g2f GrassVertex(float3 vertexPos, float width, float height, float offset, float curve, float2 uv, float3x3 rotation, float3 RotationNormal, float3 color) {
		g2f o;
		float3 offsetvertices = vertexPos + mul(rotation, float3(width, height, curve) + float3(0, 0, offset));
		o.pos = GetShadowPositionHClip(offsetvertices, RotationNormal);
		o.worldNormal = RotationNormal;
		o.diffuseColor = color;
		//	float3 color = (input[0].color).rgb; from geom. This will be the diffuseColor.
		o.uv = uv;
		VertexPositionInputs vertexInput = GetVertexPositionInputs(vertexPos + mul(rotation, float3(width, height, curve)));
		//the position of 
