Shader "shader/GeometryGrass"
{
	Properties
	{
		_BottomColor("Bottom Color", Color) = (0,1,0,1)
		_TopColor("Top Color", Color) = (1,1,0,1)
		_GrassHeight("Grass Height", Float) = 1
		_GrassWidth("Grass Width", Float) = 0.06
		_RandomHeight("Grass Height Randomness", Float) = 0.25
		_WindSpeed("Wind Speed", Float) = 100
		_WindStrength("Wind Strength", Float) = 0.05
		_Radius("Interactor Radius", Float) = 0.3
		_Power("Interactor Strength", Float) = 5
        
		_BladeRad("Blade Radius", Range(0,1)) = 0.6
		_BladeForward("Blade Forward Amount", Float) = 0.38
		_BladeCurve("Blade Curvature Amount", Range(1, 4)) = 2
		_AmbientStrength("Ambient Strength",  Range(0,1)) = 0.5
        
		_MinDist("Min Distance", Float) = 40
		_MaxDist("Max Distance", Float) = 60
		_EmitInt("Emission Strength", range(1,10)) = 1
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
		//the position of a vertex
		o.worldPos = vertexInput.positionWS;
		return o;
	}
	[maxvertexcount(60)]
	/*   [maxvertexcount(3)]  
  void geom(triangle v2g input[3], inout TriangleStream<g2f> outStream)  
  {  
        g2f o;  

        for(int i = 0; i < 3; i++)  
        {  
              o.vertex = UnityObjectToClipPos(input[i].vertex);  
              o.uv = input[i].uv;  
              outStream.Append(o);  
        }  
  
        outStream.RestartStrip();  
  }
     */
	 /*TriangleStream is a type provided by the Unity engine's shader language, HLSL. It is used to output vertex data to the graphics pipeline, specifically to generate triangles that will be rendered on screen.
The definition of TriangleStream is provided by the HLSL language and implemented by the Unity engine.*/
	void geom(point v2g input[1], inout TriangleStream<g2f> oStream)
	{
		
		float forward =rand( _BladeForward);
		float3 RotationNormal = float3(0, 1, 0);
		//y axis
		float3 worldPos = TransformObjectToWorld(input[0].pos.xyz);
		float distanceFromCamera = distance(worldPos, _WorldSpaceCameraPos);	
		float distanceFade = 1 - saturate((distanceFromCamera - _MinDist) /( _MaxDist-_MinDist));	
		//0 can't see ,1 can see.
		float3 vertex0 = input[0].pos.xyz;
		float3 wind1 = float3(sin(_Time.x * _WindSpeed + vertex0.x) + sin(_Time.x * _WindSpeed + vertex0.z * 2) + sin(_Time.x * _WindSpeed * 0.1 + vertex0.x), 0,
			cos(_Time.x * _WindSpeed + vertex0.x * 2) + cos(_Time.x * _WindSpeed + vertex0.z));
		wind1 *= _WindStrength;		
		float3 dis = distance(_PositionMoving, worldPos); 
		float3 radius = 1 - saturate(dis / _Radius); 
		float3 sphereDisp = worldPos - _PositionMoving; 
		sphereDisp *= radius; 
		sphereDisp = clamp(sphereDisp.xyz * _Power, -1, 1);
		float3 color = (input[0].color).rgb;
		_GrassHeight *= input[0].uv.y;
		_GrassWidth *= input[0].uv.x;
		_GrassHeight *= clamp(rand(input[0].pos.xyz), 1 - _RandomHeight, 1 + _RandomHeight);

		for (int j = 0; j < (GrassBlades * distanceFade) ; j++)
		{
			float3x3 RRotationMatrix = AngleAxis3x3(rand(input[0].pos.xyz) * TWO_PI+2*j, float3(0, 1, -0.1));
			RotationNormal = mul(RotationNormal, RRotationMatrix);
			float radius = j / (float)GrassBlades;
			float offset = (1 - radius) * _BladeRad;
			for (int i = 0; i < GrassSegments; i++)
			{
				//5 blades per grass, 6 grasses per vertex
				//the width and height of segments of the blade
				float t = i / (float)GrassSegments;//i/5 same
				float segmentHeight = _GrassHeight * t; //part
				float segmentWidth = _GrassWidth * t;
				for(int m = 0; m<6;m++){
					if(m<3){
						continue;
					}
					else{
						segmentWidth = _GrassWidth * t/2;
					}
				float segmentForward = pow(abs(t), _BladeCurve) * forward;
				float3x3 transformMatrix = i == 0 ? RRotationMatrix : RRotationMatrix;	
				float3 newPos = i == 0 ? vertex0 : vertex0 + ((float3(sphereDisp.x, sphereDisp.y, sphereDisp.z) + wind1) * t);
				oStream.Append(GrassVertex(newPos, segmentWidth, segmentHeight, offset, segmentForward, float2(0, t), transformMatrix, RotationNormal, color));
				oStream.Append(GrassVertex(newPos, -segmentWidth, segmentHeight, offset, segmentForward, float2(1, t), transformMatrix, RotationNormal, color));
				//oStream.Append(GrassVertex(newPos, 0.5*segmentWidth, 0.5*segmentHeight, offset, segmentForward, float2(0.5, t), transformMatrix, RotationNormal, color));
				//appends a triangle to the output stream.
				oStream.Append(GrassVertex(vertex0 + float3(sphereDisp.x * 1.5, sphereDisp.y, sphereDisp.z * 1.5) + wind1, 0, _GrassHeight, offset, forward, float2(0.5, 1), RRotationMatrix, RotationNormal, color));
			    oStream.RestartStrip();
				}
			}		
		}
	}
	ENDHLSL
		SubShader
	{
		Tags{ "RenderType" = "Opaque" "RenderPipeline" = "UniversalRenderPipeline" }
		Cull Off
		Pass
	{
		HLSLPROGRAM
	float4 _TopColor;
	float4 _BottomColor;
	float _EmitInt;
	float _AmbientStrength;
	half4 frag(g2f i) : SV_Target
	{
		float4 shadowCoord = TransformWorldToShadowCoord(i.worldPos);
#if _MAIN_LIGHT_SHADOWS
	Light mainLight = GetMainLight(shadowCoord);
#else
	Light mainLight = GetMainLight();
#endif
	float shadow = mainLight.shadowAttenuation;
	float4 baseColor = lerp(_BottomColor, _TopColor, i.uv.y) * float4(i.diffuseColor, 1);
	float4 litColor = (baseColor * float4(mainLight.color,1));
	//float3 emission = i.diffuseColor.rgb*_EmitInt;
	float3 randStrenth = rand(i.diffuseColor.r)+rand(i.diffuseColor.g)+rand(i.diffuseColor.b);
	randStrenth*=float3(0, 0, 1);
	_EmitInt=sin(_Time.y*_EmitInt);
	float4 emission = float4(randStrenth * _EmitInt, 0);
	//float3 emission = float3(1.0, 0.0, 0.0) ;
	float4 final = litColor * shadow ;
	final += emission*0.2;
	final += saturate((1 - shadow) * baseColor * 0.2);
	final.rgb+= (unity_AmbientSky * _AmbientStrength);
   return final;
   }
	   ENDHLSL
   }
	Pass{
		Name "ShadowCaster"
		Tags{ "LightMode" = "ShadowCaster" }
		ZWrite On
		HLSLPROGRAM
		#define SHADERPASS_SHADOWCASTER
		#pragma shader_feature_local _ DISTANCE_DETAIL
		half4 frag(g2f input) : SV_TARGET{
			SHADOW_CASTER_FRAGMENT(input);
		 }
		ENDHLSL
		}
	}
} 
