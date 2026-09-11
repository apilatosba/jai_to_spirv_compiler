#import "File";
#import,file "ApilaSpirv.jai";

RgenData :: struct {
   tlasOffset: s32;
   imageOffset: s32;
   lights: *s32;
}

RgenPayload :: struct {
   visible: bool;
   hitColor: f32x4;
}

RgenShader :: (data: *RgenData) {
   // // Get the coordinates of the current pixel
   // ivec2 pixelCoords = ivec2(gl_LaunchIDEXT.xy);
   // vec2 dims = vec2(gl_LaunchSizeEXT.xy);

   // // Normalize coordinates to a range from -1.0 to 1.0
   // vec2 uv = (vec2(pixelCoords) + vec2(0.5)) / dims;
   // vec2 d = uv * 2.0 - 1.0;

   // // Set up a simple camera looking forward down the Z axis
   // vec3 origin    = vec3(0.0, 0.0, -2.0);
   // vec3 direction = normalize(vec3(d.x, d.y, 1.0));

   // uint rayFlags = gl_RayFlagsOpaqueEXT;
   // float tMin    = 0.001;
   // float tMax    = 1000.0;

   // // this doesnt terminate (program behaves the same if i put an infinite loop here instead)
   // traceRayEXT(
   //    tlas[rgenData.tlasOffset],           // acceleration structure
   //    rayFlags,       // rayFlags
   //    0xFF,           // cullMask
   //    0,              // sbtRecordOffset
   //    0,              // sbtRecordStride
   //    0,              // missIndex
   //    origin,         // ray origin
   //    tMin,           // ray min range
   //    direction,      // ray direction
   //    tMax,           // ray max range
   //    0               // payload location index
   // );

   // // Write the color returned by the hit or miss shader to our image
   // imageStore(image[rgenData.imageOffset], pixelCoords, vec4(hitColor, 1.0));
   payload: RgenPayload; @payload

   pixelCoordinates := s32x2.{xx launchid.x, xx launchid.y};
   dimensions := f32x2.{xx launchsize.x, xx launchsize.y};
   uv := (cast,force(f32x2, pixelCoordinates) + f32x2.{0.5, 0.5}) / dimensions;
   d := uv * f32x2.{2, 2} - f32x2.{1, 1}; // :broadcast
   origin := f32x3.{0,0,-2};
   direction := normalize(f32x3.{d.x, d.y, 1});
   rayFlags: u32 = 1;
   tMin := 0.0001;
   tMax := 1000.0;

   payload.hitColor = f32x4.{1,0,1,1};
   TraceRay(tlases[data.tlasOffset], rayFlags, 0xFF, 0, 0, 0, origin, tMin, direction, tMax, *payload);
   ImageWrite(images[data.imageOffset], pixelCoordinates, payload.hitColor);
} @rgen

RchitData :: struct {
   imageOffset: s32;
}

RchitShader :: (data: *RchitData) {
   payload: RgenPayload; @payloadin
   payload.visible = false;
} @rchit

MeshOutVertex :: struct {
   uv: f32x2;
}
MeshOutPrimitive :: struct { }
FragmentData :: struct {
   imageIndex:    s32;
   samplerIndex:  s32;
}
MeshData :: struct {
   offset: float;
   xd:     *float;
}

DereferenceTest :: (mOutVertex: [] MeshOutVertex, mOutPrimitive: [] MeshOutPrimitive, data: *MeshData) {
   f := data.xd.*;
   data.xd.* = 6;

   f = (.*) data.xd;
   (.*) data.xd = 9;
} @mesh @1_1_1 @1_1 @triangles

AddressOfTest :: (mOutVertex: [] MeshOutVertex, mOutPrimitive: [] MeshOutPrimitive, data: *MeshData) {
   p := *data.offset;
} @mesh @1_1_1 @1_1 @triangles

MeshShader :: (mOutVertex: [] MeshOutVertex, mOutPrimitive: [] MeshOutPrimitive, data: *MeshData) {
   SetMeshOutputs(4, 2);

   a :s32= 4;
   b :s64= 6;
   if (a < b) {
      meshvertices[0].position = .{ -1, -1, 0.5, 1 };
      meshvertices[1].position = .{  1, -1, 0.5, 1 };
      meshvertices[2].position = .{  1,  1, 0.5, 1 };
      meshvertices[3].position = .{ -1,  1, 0.5, 1 };
   }

   c := 0;
   while true {
      if (c < 10) {
         c += 1;
         continue;
      }
      mOutVertex[0].uv = .{ 0, 0 + data.offset };
      mOutVertex[1].uv = .{ 1, 0 + data.offset };
      mOutVertex[2].uv = .{ 1, 1 + data.offset };
      mOutVertex[3].uv = .{ 0, 1 + data.offset };
      break;
   }

   meshtriangles[0] = .{ 0, 1, 2 };
   meshtriangles[1] = .{ 0, 2, 3 };
} @mesh @1_1_1 @4_2 @triangles

FragmentShader :: (mOutVertex: MeshOutVertex, mOutPrimitive: MeshOutPrimitive, data: *FragmentData) -> f32x4 {
   return texture(images[data.imageIndex], samplers[data.samplerIndex], mOutVertex.uv);
} @fragment


FunctionCallTest :: (mOutVertex: [] MeshOutVertex, mOutPrimitive: [] MeshOutPrimitive, data: *MeshData) {
   FresnelSchlick(0, f32x3.{0, 0, 0});
} @mesh @1_1_1 @1_1 @triangles

main :: () {
   PbrMesh(.[], .[], null);
}


Meshlet :: struct {
	vertexOffset:   u32;
	triangleOffset: u32;
	vertexCount:    u32;
	triangleCount:  u32;
};

// not aligned, will work!
// but align them anyways in real programs :)
LoadedModelVertex :: struct {
	position:   f32x3;
	uv:         f32x2;
	normal:     f32x3;
};

CameraMatrices :: struct {
	view:          mat4;
	projection:    mat4;
};

PointLight :: struct {
	position:   f32x3;
	radius:     f32;
	color:      f32x3;
	intensity:  f32;
};

PbrMeshOutVertex :: struct {
   normal:          f32x3;
   uv:              f32x2;
   worldPosition:   f32x3;
}

PbrMeshOutPrimitive :: struct {

}

PbrData :: struct {
   meshlets:            *Meshlet;
   meshletVertices:     *u32;
   meshletTriangles:    *u8;
   vertices:            *LoadedModelVertex;

   modelMatrices:    *mat4;
   modelMatrixIdx:   u32;
   cameraMatrices:   *CameraMatrices;
   cameraMatrixIdx:  u32;
   pointLights:      *PointLight;
   pointLightCount:  s32;

   irradianceMapIdx:    u32;
   prefilterMapIdx:     u32;
   brdfLutIdx:          u32;
   albedoMapIdx:        u32;
   normalMapIdx:        u32;
   metallicMapIdx:      u32;
   roughnessMapIdx:     u32;
   aoMapIdx:            u32;
   samplerIdx:          u32;

   prefilterMapMipLevels: u32;
}

PbrMesh :: (mOutVertex: [] PbrMeshOutVertex, mOutPrimitive: [] PbrMeshOutPrimitive, data: *PbrData) {
   meshlet := data.meshlets[workgroupid.x]; // (data->meshlets + workgroupid.x).*
   SetMeshOutputs(meshlet.vertexCount, meshlet.triangleCount);

   model := data.modelMatrices[data.modelMatrixIdx];
   camera := data.cameraMatrices[data.cameraMatrixIdx];

   if (localinvocationid.x < meshlet.vertexCount) {
      vertexIdx := data.meshletVertices[meshlet.vertexOffset + localinvocationid.x];
      vertex := data.vertices[vertexIdx];

      // no swizzling. yikes
      worldPosition := model * f32x4.{vertex.position.x, vertex.position.y, vertex.position.z, 1.0};
      meshvertices[localinvocationid.x].position = mul(camera.projection, camera.view) * worldPosition;
      mOutVertex[localinvocationid.x].normal = vertex.normal;
      mOutVertex[localinvocationid.x].uv = vertex.uv;
      mOutVertex[localinvocationid.x].worldPosition = .{worldPosition.x, worldPosition.y, worldPosition.z};
   }

   if (localinvocationid.x < meshlet.triangleCount) {
      offset := meshlet.triangleOffset + localinvocationid.x * 3;
      meshtriangles[localinvocationid.x] = s32x3.{data.meshletTriangles[offset], data.meshletTriangles[offset + 1], data.meshletTriangles[offset + 2]};
   }
} @mesh @128_1_1 @128_128 @triangles

PbrFragment :: (v: PbrMeshOutVertex, p: PbrMeshOutPrimitive, data: *PbrData) -> f32x4 {
   albedo4   := texture(images[data.albedoMapIdx], samplers[data.samplerIdx], v.uv);
   albedo    := f32x3.{albedo4.x, albedo4.y, albedo4.z};
   metallic  := texture(images[data.metallicMapIdx], samplers[data.samplerIdx], v.uv).x;
   roughness := texture(images[data.roughnessMapIdx], samplers[data.samplerIdx], v.uv).x;
   ao        := texture(images[data.aoMapIdx], samplers[data.samplerIdx], v.uv).x;

   camera := data.cameraMatrices[data.cameraMatrixIdx];

   cameraPosition := GetCameraPositionFromViewMatrix(camera.view);
   N := GetNormalFromMap(data.normalMapIdx, data.samplerIdx, v.uv, v.worldPosition, v.normal);
   V := normalize(cameraPosition - v.worldPosition);
   R := reflect(-V, N);

   F0 := f32x3.{0.04, 0.04, 0.04};
   F0 = lerp(F0, albedo, f32x3.{ metallic, metallic, metallic });

   Lo := f32x3.{0, 0, 0};

   {
      i: s32 = 0;
      while (i < data.pointLightCount) {
         light := data.pointLights[i];

         L := normalize(light.position - v.worldPosition);
         H := normalize(V + L);
         distance := length(light.position - v.worldPosition);
         attenuation := 1.0 / (distance * distance);
         radiance := light.color * f32x3.{attenuation, attenuation, attenuation};

         NDF := DistributionGGX(N, H, roughness);
         G := GeometrySmithDirect(N, V, L, roughness);
         F := FresnelSchlick(max(dot(H, V), 0.0), F0);

         numerator := f32x3.{NDF, NDF, NDF} * f32x3.{G, G, G} * F;
         denominator := 4.0 * max(dot(N, V), 0.0) * max(dot(N, L), 0.0) + 0.0001;
         specular := numerator / f32x3.{denominator, denominator, denominator};

         kS := F;
         kD := f32x3.{1.0, 1.0, 1.0} - kS;
         oneMinusMetallic := 1.0 - metallic;
         kD *= f32x3.{oneMinusMetallic, oneMinusMetallic, oneMinusMetallic};

         NdotL := max(dot(N, L), 0.0);
         Lo += (kD * albedo / f32x3.{PI, PI, PI} + specular) * radiance * f32x3.{NdotL, NdotL, NdotL};

         i += 1;
      }
   }

   F := FresnelSchlickRoughness(max(dot(N, V), 0.0), F0, roughness);
   kS := F;
   kD := f32x3.{1.0, 1.0, 1.0} - kS;
   oneMinusMetallic := 1.0 - metallic;
   kD *= f32x3.{oneMinusMetallic, oneMinusMetallic, oneMinusMetallic};
   irradiance4 := texture(images[data.irradianceMapIdx], samplers[data.samplerIdx], DirectionToEquirectangularUv(N));
   irradiance := f32x3.{irradiance4.x, irradiance4.y, irradiance4.z};
   diffuse := irradiance * albedo;

   prefilteredColor4 := texturelod(images[data.prefilterMapIdx], samplers[data.samplerIdx], DirectionToEquirectangularUv(R), roughness * (data.prefilterMapMipLevels - 1));
   prefilteredColor := f32x3.{prefilteredColor4.x, prefilteredColor4.y, prefilteredColor4.z};
   brdf4 := texture(images[data.brdfLutIdx], samplers[data.samplerIdx], f32x2.{max(dot(N, V), 0.0), roughness});
   brdf := f32x2.{brdf4.x, brdf4.y};
   specular := prefilteredColor * (F * f32x3.{brdf.x, brdf.x, brdf.x} + f32x3.{brdf.y, brdf.y, brdf.y});

   ambient := (kD * diffuse + specular) * f32x3.{ao, ao, ao};

   color := ambient + Lo;
   color = color / (color + f32x3.{1.0, 1.0, 1.0});

   return f32x4.{color.x, color.y, color.z, 1.0};
} @fragment

PI: f32 : 3.1415927;

// https://learnopengl.com/PBR/IBL/Diffuse-irradiance
DirectionToEquirectangularUv :: (v_: f32x3) -> f32x2 {
   v := normalize(v_);
   invAtan := f32x2.{0.1591, 0.3183};
   uv := f32x2.{atan2(v.z, v.x), asin(v.y)};
   uv *= invAtan;

   // :broadcast
   uv += f32x2.{0.5, 0.5};
   return uv;
}

// https://learnopengl.com/code_viewer_gh.php?code=src/6.pbr/2.2.2.ibl_specular_textured/2.2.2.pbr.fs
FresnelSchlickRoughness :: (cosTheta: f32, F0: f32x3, roughness: f32) -> f32x3 {
   // :broadcast
   t := pow(clamp(1.0 - cosTheta, 0.0, 1.0), 5.0);
   return F0 + (max(f32x3.{1.0 - roughness, 1.0 - roughness, 1.0 - roughness}, F0) - F0) * f32x3.{t, t, t};
}

// https://learnopengl.com/PBR/Lighting
FresnelSchlick :: (cosTheta: f32, F0: f32x3) -> f32x3 {
   // i did this since i have not yet implemented broadcasting
   t := pow(clamp(1.0 - cosTheta, 0.0, 1.0), 5.0);
   return F0 + (f32x3.{1, 1, 1} - F0) * f32x3.{t, t, t};
}

// https://learnopengl.com/PBR/Lighting
GeometrySchlickGGXDirect :: (NdotV: f32, roughness: f32) -> f32 {
   r := (roughness + 1.0);
   k := (r*r) / 8.0;

   num   := NdotV;
   denom := NdotV * (1.0 - k) + k;

   return num / denom;
}

// https://learnopengl.com/PBR/Lighting
GeometrySmithDirect :: (N: f32x3, V: f32x3, L: f32x3, roughness: f32) -> f32 {
   NdotV := max(dot(N, V), 0.0);
   NdotL := max(dot(N, L), 0.0);
   ggx2  := GeometrySchlickGGXDirect(NdotV, roughness);
   ggx1  := GeometrySchlickGGXDirect(NdotL, roughness);

   return ggx1 * ggx2;
}

DistributionGGX :: (N: f32x3, H: f32x3, roughness: f32) -> f32 {
   a := roughness*roughness;
   a2 := a*a;
   NdotH := max(dot(N, H), 0.0);
   NdotH2 := NdotH*NdotH;

   num := a2;
   denom := (NdotH2 * (a2 - 1.0) + 1.0);
   denom = PI * denom * denom;

   return num / denom;
}

GetNormalFromMap :: (normalMapIdx: u32, samplerIdx: u32, uv: f32x2, worldPosition: f32x3, vertexNormal: f32x3) -> f32x3 {
   tangentNormal4 := texture(images[normalMapIdx], samplers[samplerIdx], uv);
   tangentNormal := f32x3.{tangentNormal4.x, tangentNormal4.y, tangentNormal4.z} * f32x3.{2, 2, 2} - f32x3.{1, 1, 1};

   Q1 := ddx(worldPosition);
   Q2 := ddy(worldPosition);
   st1 := ddx(uv);
   st2 := ddy(uv);

   N := normalize(vertexNormal);
   T := normalize(Q1*f32x3.{st2.y, st2.y, st2.y} - Q2*f32x3.{st1.y, st1.y, st1.y});
   B := -normalize(cross(N, T));
   TBN: mat3;
   TBN[0] = T;
   TBN[1] = B;
   TBN[2] = N;

   return normalize(TBN * tangentNormal);
}

GetCameraPositionFromViewMatrix :: (view: mat4) -> f32x3 {
   v := inverse(view)[3];
   return f32x3.{v.x, v.y, v.z};
}


// #version 460

// #extension GL_EXT_mesh_shader : require
// #extension GL_EXT_shader_8bit_storage : require
// #extension GL_GOOGLE_include_directive: require
// #extension GL_EXT_debug_printf: require

// #include "include/apila.glsl"

// layout(binding = MESHLETS_SSBO_BINDING_POINT)            readonly buffer Meshlets { Meshlet meshlets[]; };
// layout(binding = MESHLETS_VERTICES_SSBO_BINDING_POINT)   readonly buffer MeshletVertices { uint meshletVertices[]; };
// layout(binding = MESHLETS_TRIANGLES_SSBO_BINDING_POINT)  readonly buffer MeshletTriangles { uint8_t meshletTriangles[]; };
// layout(binding = VERTICES_SSBO_BINDING_POINT)            readonly buffer Vertices { LoadedModelVertex vertices[]; };

// layout(binding = MODEL_MATRICES_SSBO_BINDING_POINT) readonly buffer ModelMatrices {
//    mat4 modelMatrices[];
// };

// layout(binding = CAMERA_MATRICES_SSBO_BINDING_POINT) readonly buffer Cameras {
//    CameraMatrices cameraMatrices[];
// };

// layout (binding = POINT_LIGHTS_SSBO_BINDING_POINT) readonly buffer PointLights {
//    uint pointLightCount;
//    uint padding0;
//    uint padding1;
//    uint padding2;
//    PointLight pointLights[];
// };

// layout(binding = PBR_IRRADIANCE_MAP_BINDING_POINT)                uniform sampler2D irradianceMap; // equirectangular
// layout(binding = PBR_PREFILTERED_ENVIRONMENT_MAP_BINDING_POINT)   uniform sampler2D prefilterMap; // equirectangular
// layout(binding = PBR_BRDF_LUT_BINDING_POINT)                      uniform sampler2D brdfLut; // brdf integration map
// layout(binding = PBR_ALBEDO_MAP_BINDING_POINT)                    uniform sampler2D albedoMap;
// layout(binding = PBR_NORMAL_MAP_BINDING_POINT)                    uniform sampler2D normalMap;
// layout(binding = PBR_METALLIC_MAP_BINDING_POINT)                  uniform sampler2D metallicMap;
// layout(binding = PBR_ROUGHNESS_MAP_BINDING_POINT)                 uniform sampler2D roughnessMap;
// layout(binding = PBR_AO_MAP_BINDING_POINT)                        uniform sampler2D aoMap;

// layout(push_constant) uniform PC {
//    uint cameraMatrixIdx;
//    uint modelMatrixIdx;
//    uint prefilterMapMipLevels;
//    // vec3 albedo;
//    // float metallic;
//    // float roughness;
//    // float ao;
// };


// #ifdef APILA_MESH_SHADER

// layout(local_size_x = MESHLET_PIPELINE_LOCAL_SIZE_X) in;
// layout(triangles, max_vertices = MESHLET_PIPELINE_MAX_VERTICES, max_primitives = MESHLET_PIPELINE_MAX_PRIMITIVES) out;

// layout(location = 0) out vec3[] vNormal;
// layout(location = 1) out vec2[] vUv;
// layout(location = 2) out vec3[] vWorldPosition;

// void ApilaMS() {
//    Meshlet meshlet = meshlets[gl_WorkGroupID.x];
//    SetMeshOutputsEXT(meshlet.vertexCount, meshlet.triangleCount);

//    mat4 model = modelMatrices[modelMatrixIdx];
//    CameraMatrices camera = cameraMatrices[cameraMatrixIdx];

//    if (gl_LocalInvocationID.x < meshlet.vertexCount) {
//       uint vertexIndex = meshletVertices[meshlet.vertexOffset + gl_LocalInvocationID.x];
//       LoadedModelVertex vertex = vertices[vertexIndex];

//       vec4 worldPosition = model * vec4(vertex.position.xyz, 1.0);
//       gl_MeshVerticesEXT[gl_LocalInvocationID.x].gl_Position = TransformPosition(camera.projection * camera.view, worldPosition);
//       vNormal[gl_LocalInvocationID.x] = vertex.normal.xyz;
//       vUv[gl_LocalInvocationID.x] = vertex.uv.xy;
//       vWorldPosition[gl_LocalInvocationID.x] = worldPosition.xyz;
//    }

//    if (gl_LocalInvocationID.x < meshlet.triangleCount) {
//       uint offset = meshlet.triangleOffset + gl_LocalInvocationID.x * 3;
//       gl_PrimitiveTriangleIndicesEXT[gl_LocalInvocationID.x] = uvec3(meshletTriangles[offset], meshletTriangles[offset + 1], meshletTriangles[offset + 2]);
//    }
// }

// #endif // APILA_MESH_SHADER


// #ifdef APILA_FRAGMENT_SHADER

// layout(location = 0) in vec3 vNormal;
// layout(location = 1) in vec2 vUv;
// layout(location = 2) in vec3 vWorldPosition;

// layout(location = 0) out vec4 fragColor;

// void ApilaFS() {
//    vec3 albedo     = pow(texture(albedoMap, vUv).rgb, vec3(2.2)); // (apila, 04/07/25) if you set the format to srgb then you dont need this pow
//    float metallic  = texture(metallicMap, vUv).r;
//    float roughness = texture(roughnessMap, vUv).r;
//    float ao        = texture(aoMap, vUv).r;

//    CameraMatrices camera = cameraMatrices[cameraMatrixIdx];

//    vec3 cameraPosition = GetCameraPositionFromViewMatrix(camera.view);
//    vec3 N = GetNormalFromMap(normalMap, vUv, vWorldPosition, vNormal);
//    vec3 V = normalize(cameraPosition - vWorldPosition);
//    vec3 R = reflect(-V, N);

//    vec3 F0 = vec3(0.04);
//    F0 = mix(F0, albedo, metallic);

//    // reflectance equation
//    vec3 Lo = vec3(0.0);
//    for(int i = 0; i < pointLightCount; i++) {
//       PointLight pointLight = pointLights[i];

//       // calculate per-light radiance
//       vec3 L = normalize(pointLight.position - vWorldPosition);
//       vec3 H = normalize(V + L);
//       float distance    = length(pointLight.position - vWorldPosition);
//       float attenuation = 1.0 / (distance * distance);
//       vec3 radiance     = pointLight.color * attenuation;

//       // cook-torrance brdf
//       float NDF = DistributionGGX(N, H, roughness);
//       float G   = GeometrySmithDirect(N, V, L, roughness);
//       vec3 F    = FresnelSchlick(max(dot(H, V), 0.0), F0);

//       vec3 numerator    = NDF * G * F;
//       float denominator = 4.0 * max(dot(N, V), 0.0) * max(dot(N, L), 0.0) + 0.0001;
//       vec3 specular     = numerator / denominator;

//       vec3 kS = F;
//       vec3 kD = vec3(1.0) - kS;
//       kD *= 1.0 - metallic;

//       // add to outgoing radiance Lo
//       float NdotL = max(dot(N, L), 0.0);
//       Lo += (kD * albedo / PI + specular) * radiance * NdotL;
//    }

//    // ambient lighting (we now use IBL as the ambient term)
//    vec3 F = FresnelSchlickRoughness(max(dot(N, V), 0.0), F0, roughness);
//    vec3 kS = F;
//    vec3 kD = 1.0 - kS;
//    kD *= 1.0 - metallic;
//    vec3 irradiance = texture(irradianceMap, DirectionToEquirectangularUv(N)).rgb;
//    vec3 diffuse = irradiance * albedo;

//    vec3 prefilteredColor = textureLod(prefilterMap, DirectionToEquirectangularUv(R),  roughness * (prefilterMapMipLevels - 1)).rgb;
//    vec2 brdf  = texture(brdfLut, vec2(max(dot(N, V), 0.0), roughness)).rg;
//    vec3 specular = prefilteredColor * (F * brdf.x + brdf.y);

//    vec3 ambient = (kD * diffuse + specular) * ao;

//    vec3 color = ambient + Lo;
//    color = color / (color + vec3(1.0));
//    // color = pow(color, vec3(1.0/2.2)); // my swapchain is already srgb nonlinear.

//    fragColor = vec4(color, 1.0);
// }

// #endif // APILA_FRAGMENT_SHADER

// ; SPIR-V
// ; Version: 1.6
// ; Generator: Khronos Glslang Reference Front End; 11
// ; Bound: 249
// ; Schema: 0
//                OpCapability StorageBuffer8BitAccess
//                OpCapability MeshShadingEXT
//                OpExtension "SPV_EXT_mesh_shader"
//           %1 = OpExtInstImport "GLSL.std.450"
//                OpMemoryModel Logical GLSL450
//                OpEntryPoint MeshEXT %ApilaMS "ApilaMS" %_ %gl_WorkGroupID %__0 %__1 %__2 %gl_LocalInvocationID %__3 %__4 %gl_MeshVerticesEXT %vNormal %vUv %vWorldPosition %gl_PrimitiveTriangleIndicesEXT %__5 %__6 %irradianceMap %prefilterMap %brdfLut %albedoMap %normalMap %metallicMap %roughnessMap %aoMap
//                OpExecutionModeId %ApilaMS LocalSizeId %uint_128 %uint_1 %uint_1
//                OpExecutionMode %ApilaMS OutputVertices 128
//                OpExecutionMode %ApilaMS OutputPrimitivesEXT 128
//                OpExecutionMode %ApilaMS OutputTrianglesEXT

//                ; Debug Information
//                OpSource GLSL 460
//                OpSourceExtension "GL_EXT_debug_printf"
//                OpSourceExtension "GL_EXT_mesh_shader"
//                OpSourceExtension "GL_EXT_shader_8bit_storage"
//                OpSourceExtension "GL_GOOGLE_cpp_style_line_directive"
//                OpSourceExtension "GL_GOOGLE_include_directive"
//                OpName %ApilaMS "ApilaMS"            ; id %4
//                OpName %TransformPosition_mf44_vf4_ "TransformPosition(mf44;vf4;"    ; id %17
//                OpName %mvp "mvp"                                                    ; id %15
//                OpName %position "position"                                          ; id %16
//                OpName %Meshlet "Meshlet"                                            ; id %24
//                OpMemberName %Meshlet 0 "vertexOffset"
//                OpMemberName %Meshlet 1 "triangleOffset"
//                OpMemberName %Meshlet 2 "vertexCount"
//                OpMemberName %Meshlet 3 "triangleCount"
//                OpName %meshlet "meshlet"            ; id %26
//                OpName %Meshlet_0 "Meshlet"          ; id %27
//                OpMemberName %Meshlet_0 0 "vertexOffset"
//                OpMemberName %Meshlet_0 1 "triangleOffset"
//                OpMemberName %Meshlet_0 2 "vertexCount"
//                OpMemberName %Meshlet_0 3 "triangleCount"
//                OpName %Meshlets "Meshlets"          ; id %29
//                OpMemberName %Meshlets 0 "meshlets"
//                OpName %_ ""                         ; id %31
//                OpName %gl_WorkGroupID "gl_WorkGroupID"  ; id %36
//                OpName %model "model"                    ; id %52
//                OpName %ModelMatrices "ModelMatrices"    ; id %54
//                OpMemberName %ModelMatrices 0 "modelMatrices"
//                OpName %__0 ""                       ; id %56
//                OpName %PC "PC"                      ; id %57
//                OpMemberName %PC 0 "cameraMatrixIdx"
//                OpMemberName %PC 1 "modelMatrixIdx"
//                OpMemberName %PC 2 "prefilterMapMipLevels"
//                OpName %__1 ""                       ; id %59
//                OpName %CameraMatrices "CameraMatrices"  ; id %67
//                OpMemberName %CameraMatrices 0 "view"
//                OpMemberName %CameraMatrices 1 "projection"
//                OpName %camera "camera"              ; id %69
//                OpName %CameraMatrices_0 "CameraMatrices"    ; id %70
//                OpMemberName %CameraMatrices_0 0 "view"
//                OpMemberName %CameraMatrices_0 1 "projection"
//                OpName %Cameras "Cameras"            ; id %72
//                OpMemberName %Cameras 0 "cameraMatrices"
//                OpName %__2 ""                       ; id %74
//                OpName %gl_LocalInvocationID "gl_LocalInvocationID"  ; id %81
//                OpName %vertexIndex "vertexIndex"                    ; id %90
//                OpName %MeshletVertices "MeshletVertices"            ; id %92
//                OpMemberName %MeshletVertices 0 "meshletVertices"
//                OpName %__3 ""                       ; id %94
//                OpName %LoadedModelVertex "LoadedModelVertex"    ; id %105
//                OpMemberName %LoadedModelVertex 0 "position"
//                OpMemberName %LoadedModelVertex 1 "padding0"
//                OpMemberName %LoadedModelVertex 2 "uv"
//                OpMemberName %LoadedModelVertex 3 "padding1"
//                OpMemberName %LoadedModelVertex 4 "normal"
//                OpMemberName %LoadedModelVertex 5 "padding2"
//                OpName %vertex "vertex"              ; id %107
//                OpName %LoadedModelVertex_0 "LoadedModelVertex"  ; id %108
//                OpMemberName %LoadedModelVertex_0 0 "position"
//                OpMemberName %LoadedModelVertex_0 1 "padding0"
//                OpMemberName %LoadedModelVertex_0 2 "uv"
//                OpMemberName %LoadedModelVertex_0 3 "padding1"
//                OpMemberName %LoadedModelVertex_0 4 "normal"
//                OpMemberName %LoadedModelVertex_0 5 "padding2"
//                OpName %Vertices "Vertices"          ; id %110
//                OpMemberName %Vertices 0 "vertices"
//                OpName %__4 ""                       ; id %112
//                OpName %worldPosition "worldPosition"    ; id %118
//                OpName %gl_MeshPerVertexEXT "gl_MeshPerVertexEXT"    ; id %130
//                OpMemberName %gl_MeshPerVertexEXT 0 "gl_Position"
//                OpMemberName %gl_MeshPerVertexEXT 1 "gl_PointSize"
//                OpMemberName %gl_MeshPerVertexEXT 2 "gl_ClipDistance"
//                OpMemberName %gl_MeshPerVertexEXT 3 "gl_CullDistance"
//                OpName %gl_MeshVerticesEXT "gl_MeshVerticesEXT"  ; id %133
//                OpName %param "param"                            ; id %141
//                OpName %param_0 "param"                          ; id %142
//                OpName %vNormal "vNormal"                        ; id %149
//                OpName %vUv "vUv"                                ; id %159
//                OpName %vWorldPosition "vWorldPosition"          ; id %167
//                OpName %offset "offset"                          ; id %180
//                OpName %gl_PrimitiveTriangleIndicesEXT "gl_PrimitiveTriangleIndicesEXT"  ; id %190
//                OpName %MeshletTriangles "MeshletTriangles"                              ; id %195
//                OpMemberName %MeshletTriangles 0 "meshletTriangles"
//                OpName %__5 ""                       ; id %197
//                OpName %PointLight "PointLight"      ; id %232
//                OpMemberName %PointLight 0 "position"
//                OpMemberName %PointLight 1 "radius"
//                OpMemberName %PointLight 2 "color"
//                OpMemberName %PointLight 3 "intensity"
//                OpName %PointLights "PointLights"    ; id %234
//                OpMemberName %PointLights 0 "pointLightCount"
//                OpMemberName %PointLights 1 "padding0"
//                OpMemberName %PointLights 2 "padding1"
//                OpMemberName %PointLights 3 "padding2"
//                OpMemberName %PointLights 4 "pointLights"
//                OpName %__6 ""                       ; id %236
//                OpName %irradianceMap "irradianceMap"    ; id %240
//                OpName %prefilterMap "prefilterMap"      ; id %241
//                OpName %brdfLut "brdfLut"                ; id %242
//                OpName %albedoMap "albedoMap"            ; id %243
//                OpName %normalMap "normalMap"            ; id %244
//                OpName %metallicMap "metallicMap"        ; id %245
//                OpName %roughnessMap "roughnessMap"      ; id %246
//                OpName %aoMap "aoMap"                    ; id %247

//                ; Annotations
//                OpMemberDecorate %Meshlet_0 0 Offset 0
//                OpMemberDecorate %Meshlet_0 1 Offset 4
//                OpMemberDecorate %Meshlet_0 2 Offset 8
//                OpMemberDecorate %Meshlet_0 3 Offset 12
//                OpDecorate %_runtimearr_Meshlet_0 ArrayStride 16
//                OpDecorate %Meshlets Block
//                OpMemberDecorate %Meshlets 0 NonWritable
//                OpMemberDecorate %Meshlets 0 Offset 0
//                OpDecorate %_ NonWritable
//                OpDecorate %_ Binding 3
//                OpDecorate %_ DescriptorSet 0
//                OpDecorate %gl_WorkGroupID BuiltIn WorkgroupId
//                OpDecorate %_runtimearr_mat4v4float ArrayStride 64
//                OpDecorate %ModelMatrices Block
//                OpMemberDecorate %ModelMatrices 0 ColMajor
//                OpMemberDecorate %ModelMatrices 0 MatrixStride 16
//                OpMemberDecorate %ModelMatrices 0 NonWritable
//                OpMemberDecorate %ModelMatrices 0 Offset 0
//                OpDecorate %__0 NonWritable
//                OpDecorate %__0 Binding 1
//                OpDecorate %__0 DescriptorSet 0
//                OpDecorate %PC Block
//                OpMemberDecorate %PC 0 Offset 0
//                OpMemberDecorate %PC 1 Offset 4
//                OpMemberDecorate %PC 2 Offset 8
//                OpMemberDecorate %CameraMatrices_0 0 ColMajor
//                OpMemberDecorate %CameraMatrices_0 0 MatrixStride 16
//                OpMemberDecorate %CameraMatrices_0 0 Offset 0
//                OpMemberDecorate %CameraMatrices_0 1 ColMajor
//                OpMemberDecorate %CameraMatrices_0 1 MatrixStride 16
//                OpMemberDecorate %CameraMatrices_0 1 Offset 64
//                OpDecorate %_runtimearr_CameraMatrices_0 ArrayStride 128
//                OpDecorate %Cameras Block
//                OpMemberDecorate %Cameras 0 NonWritable
//                OpMemberDecorate %Cameras 0 Offset 0
//                OpDecorate %__2 NonWritable
//                OpDecorate %__2 Binding 0
//                OpDecorate %__2 DescriptorSet 0
//                OpDecorate %gl_LocalInvocationID BuiltIn LocalInvocationId
//                OpDecorate %_runtimearr_uint ArrayStride 4
//                OpDecorate %MeshletVertices Block
//                OpMemberDecorate %MeshletVertices 0 NonWritable
//                OpMemberDecorate %MeshletVertices 0 Offset 0
//                OpDecorate %__3 NonWritable
//                OpDecorate %__3 Binding 4
//                OpDecorate %__3 DescriptorSet 0
//                OpMemberDecorate %LoadedModelVertex_0 0 Offset 0
//                OpMemberDecorate %LoadedModelVertex_0 1 Offset 12
//                OpMemberDecorate %LoadedModelVertex_0 2 Offset 16
//                OpMemberDecorate %LoadedModelVertex_0 3 Offset 24
//                OpMemberDecorate %LoadedModelVertex_0 4 Offset 32
//                OpMemberDecorate %LoadedModelVertex_0 5 Offset 44
//                OpDecorate %_runtimearr_LoadedModelVertex_0 ArrayStride 48
//                OpDecorate %Vertices Block
//                OpMemberDecorate %Vertices 0 NonWritable
//                OpMemberDecorate %Vertices 0 Offset 0
//                OpDecorate %__4 NonWritable
//                OpDecorate %__4 Binding 6
//                OpDecorate %__4 DescriptorSet 0
//                OpDecorate %gl_MeshPerVertexEXT Block
//                OpMemberDecorate %gl_MeshPerVertexEXT 0 BuiltIn Position
//                OpMemberDecorate %gl_MeshPerVertexEXT 1 BuiltIn PointSize
//                OpMemberDecorate %gl_MeshPerVertexEXT 2 BuiltIn ClipDistance
//                OpMemberDecorate %gl_MeshPerVertexEXT 3 BuiltIn CullDistance
//                OpDecorate %vNormal Location 0
//                OpDecorate %vUv Location 1
//                OpDecorate %vWorldPosition Location 2
//                OpDecorate %gl_PrimitiveTriangleIndicesEXT BuiltIn PrimitiveTriangleIndicesEXT
//                OpDecorate %_runtimearr_uchar ArrayStride 1
//                OpDecorate %MeshletTriangles Block
//                OpMemberDecorate %MeshletTriangles 0 NonWritable
//                OpMemberDecorate %MeshletTriangles 0 Offset 0
//                OpDecorate %__5 NonWritable
//                OpDecorate %__5 Binding 5
//                OpDecorate %__5 DescriptorSet 0
//                OpMemberDecorate %PointLight 0 Offset 0
//                OpMemberDecorate %PointLight 1 Offset 12
//                OpMemberDecorate %PointLight 2 Offset 16
//                OpMemberDecorate %PointLight 3 Offset 28
//                OpDecorate %_runtimearr_PointLight ArrayStride 32
//                OpDecorate %PointLights Block
//                OpMemberDecorate %PointLights 0 NonWritable
//                OpMemberDecorate %PointLights 0 Offset 0
//                OpMemberDecorate %PointLights 1 NonWritable
//                OpMemberDecorate %PointLights 1 Offset 4
//                OpMemberDecorate %PointLights 2 NonWritable
//                OpMemberDecorate %PointLights 2 Offset 8
//                OpMemberDecorate %PointLights 3 NonWritable
//                OpMemberDecorate %PointLights 3 Offset 12
//                OpMemberDecorate %PointLights 4 NonWritable
//                OpMemberDecorate %PointLights 4 Offset 16
//                OpDecorate %__6 NonWritable
//                OpDecorate %__6 Binding 2
//                OpDecorate %__6 DescriptorSet 0
//                OpDecorate %irradianceMap Binding 12
//                OpDecorate %irradianceMap DescriptorSet 0
//                OpDecorate %prefilterMap Binding 13
//                OpDecorate %prefilterMap DescriptorSet 0
//                OpDecorate %brdfLut Binding 14
//                OpDecorate %brdfLut DescriptorSet 0
//                OpDecorate %albedoMap Binding 7
//                OpDecorate %albedoMap DescriptorSet 0
//                OpDecorate %normalMap Binding 8
//                OpDecorate %normalMap DescriptorSet 0
//                OpDecorate %metallicMap Binding 9
//                OpDecorate %metallicMap DescriptorSet 0
//                OpDecorate %roughnessMap Binding 10
//                OpDecorate %roughnessMap DescriptorSet 0
//                OpDecorate %aoMap Binding 11
//                OpDecorate %aoMap DescriptorSet 0

//                ; Types, variables and constants
//        %void = OpTypeVoid
//           %3 = OpTypeFunction %void
//        %uint = OpTypeInt 32 0
//    %uint_128 = OpConstant %uint 128
//      %uint_1 = OpConstant %uint 1
//       %float = OpTypeFloat 32
//     %v4float = OpTypeVector %float 4
// %mat4v4float = OpTypeMatrix %v4float 4
// %_ptr_Function_mat4v4float = OpTypePointer Function %mat4v4float
// %_ptr_Function_v4float = OpTypePointer Function %v4float
//          %14 = OpTypeFunction %v4float %_ptr_Function_mat4v4float %_ptr_Function_v4float
//     %Meshlet = OpTypeStruct %uint %uint %uint %uint
// %_ptr_Function_Meshlet = OpTypePointer Function %Meshlet
//   %Meshlet_0 = OpTypeStruct %uint %uint %uint %uint
// %_runtimearr_Meshlet_0 = OpTypeRuntimeArray %Meshlet_0  ; ArrayStride 16
//    %Meshlets = OpTypeStruct %_runtimearr_Meshlet_0      ; Block
// %_ptr_StorageBuffer_Meshlets = OpTypePointer StorageBuffer %Meshlets
//           %_ = OpVariable %_ptr_StorageBuffer_Meshlets StorageBuffer    ; NonWritable, Binding 3, DescriptorSet 0
//         %int = OpTypeInt 32 1
//       %int_0 = OpConstant %int 0
//      %v3uint = OpTypeVector %uint 3
// %_ptr_Input_v3uint = OpTypePointer Input %v3uint
// %gl_WorkGroupID = OpVariable %_ptr_Input_v3uint Input   ; BuiltIn WorkgroupId
//      %uint_0 = OpConstant %uint 0
// %_ptr_Input_uint = OpTypePointer Input %uint
// %_ptr_StorageBuffer_Meshlet_0 = OpTypePointer StorageBuffer %Meshlet_0
//       %int_2 = OpConstant %int 2
// %_ptr_Function_uint = OpTypePointer Function %uint
//       %int_3 = OpConstant %int 3
// %_runtimearr_mat4v4float = OpTypeRuntimeArray %mat4v4float  ; ArrayStride 64
// %ModelMatrices = OpTypeStruct %_runtimearr_mat4v4float      ; Block
// %_ptr_StorageBuffer_ModelMatrices = OpTypePointer StorageBuffer %ModelMatrices
//         %__0 = OpVariable %_ptr_StorageBuffer_ModelMatrices StorageBuffer   ; NonWritable, Binding 1, DescriptorSet 0
//          %PC = OpTypeStruct %uint %uint %uint                               ; Block
// %_ptr_PushConstant_PC = OpTypePointer PushConstant %PC
//         %__1 = OpVariable %_ptr_PushConstant_PC PushConstant
//       %int_1 = OpConstant %int 1
// %_ptr_PushConstant_uint = OpTypePointer PushConstant %uint
// %_ptr_StorageBuffer_mat4v4float = OpTypePointer StorageBuffer %mat4v4float
// %CameraMatrices = OpTypeStruct %mat4v4float %mat4v4float
// %_ptr_Function_CameraMatrices = OpTypePointer Function %CameraMatrices
// %CameraMatrices_0 = OpTypeStruct %mat4v4float %mat4v4float
// %_runtimearr_CameraMatrices_0 = OpTypeRuntimeArray %CameraMatrices_0    ; ArrayStride 128
//     %Cameras = OpTypeStruct %_runtimearr_CameraMatrices_0               ; Block
// %_ptr_StorageBuffer_Cameras = OpTypePointer StorageBuffer %Cameras
//         %__2 = OpVariable %_ptr_StorageBuffer_Cameras StorageBuffer     ; NonWritable, Binding 0, DescriptorSet 0
// %_ptr_StorageBuffer_CameraMatrices_0 = OpTypePointer StorageBuffer %CameraMatrices_0
// %gl_LocalInvocationID = OpVariable %_ptr_Input_v3uint Input     ; BuiltIn LocalInvocationId
//        %bool = OpTypeBool
// %_runtimearr_uint = OpTypeRuntimeArray %uint        ; ArrayStride 4
// %MeshletVertices = OpTypeStruct %_runtimearr_uint   ; Block
// %_ptr_StorageBuffer_MeshletVertices = OpTypePointer StorageBuffer %MeshletVertices
//         %__3 = OpVariable %_ptr_StorageBuffer_MeshletVertices StorageBuffer     ; NonWritable, Binding 4, DescriptorSet 0
// %_ptr_StorageBuffer_uint = OpTypePointer StorageBuffer %uint
//     %v3float = OpTypeVector %float 3
//     %v2float = OpTypeVector %float 2
// %LoadedModelVertex = OpTypeStruct %v3float %float %v2float %v2float %v3float %float
// %_ptr_Function_LoadedModelVertex = OpTypePointer Function %LoadedModelVertex
// %LoadedModelVertex_0 = OpTypeStruct %v3float %float %v2float %v2float %v3float %float
// %_runtimearr_LoadedModelVertex_0 = OpTypeRuntimeArray %LoadedModelVertex_0  ; ArrayStride 48
//    %Vertices = OpTypeStruct %_runtimearr_LoadedModelVertex_0                ; Block
// %_ptr_StorageBuffer_Vertices = OpTypePointer StorageBuffer %Vertices
//         %__4 = OpVariable %_ptr_StorageBuffer_Vertices StorageBuffer    ; NonWritable, Binding 6, DescriptorSet 0
// %_ptr_StorageBuffer_LoadedModelVertex_0 = OpTypePointer StorageBuffer %LoadedModelVertex_0
// %_ptr_Function_v3float = OpTypePointer Function %v3float
//     %float_1 = OpConstant %float 1
// %_arr_float_uint_1 = OpTypeArray %float %uint_1
// %gl_MeshPerVertexEXT = OpTypeStruct %v4float %float %_arr_float_uint_1 %_arr_float_uint_1   ; Block
// %_arr_gl_MeshPerVertexEXT_uint_128 = OpTypeArray %gl_MeshPerVertexEXT %uint_128
// %_ptr_Output__arr_gl_MeshPerVertexEXT_uint_128 = OpTypePointer Output %_arr_gl_MeshPerVertexEXT_uint_128
// %gl_MeshVerticesEXT = OpVariable %_ptr_Output__arr_gl_MeshPerVertexEXT_uint_128 Output
// %_ptr_Output_v4float = OpTypePointer Output %v4float
// %_arr_v3float_uint_128 = OpTypeArray %v3float %uint_128
// %_ptr_Output__arr_v3float_uint_128 = OpTypePointer Output %_arr_v3float_uint_128
//     %vNormal = OpVariable %_ptr_Output__arr_v3float_uint_128 Output     ; Location 0
//       %int_4 = OpConstant %int 4
// %_ptr_Output_v3float = OpTypePointer Output %v3float
// %_arr_v2float_uint_128 = OpTypeArray %v2float %uint_128
// %_ptr_Output__arr_v2float_uint_128 = OpTypePointer Output %_arr_v2float_uint_128
//         %vUv = OpVariable %_ptr_Output__arr_v2float_uint_128 Output     ; Location 1
// %_ptr_Function_v2float = OpTypePointer Function %v2float
// %_ptr_Output_v2float = OpTypePointer Output %v2float
// %vWorldPosition = OpVariable %_ptr_Output__arr_v3float_uint_128 Output  ; Location 2
//      %uint_3 = OpConstant %uint 3
// %_arr_v3uint_uint_128 = OpTypeArray %v3uint %uint_128
// %_ptr_Output__arr_v3uint_uint_128 = OpTypePointer Output %_arr_v3uint_uint_128
// %gl_PrimitiveTriangleIndicesEXT = OpVariable %_ptr_Output__arr_v3uint_uint_128 Output   ; BuiltIn PrimitiveTriangleIndicesEXT
//       %uchar = OpTypeInt 8 0
// %_runtimearr_uchar = OpTypeRuntimeArray %uchar      ; ArrayStride 1
// %MeshletTriangles = OpTypeStruct %_runtimearr_uchar     ; Block
// %_ptr_StorageBuffer_MeshletTriangles = OpTypePointer StorageBuffer %MeshletTriangles
//         %__5 = OpVariable %_ptr_StorageBuffer_MeshletTriangles StorageBuffer    ; NonWritable, Binding 5, DescriptorSet 0
// %_ptr_StorageBuffer_uchar = OpTypePointer StorageBuffer %uchar
//      %uint_2 = OpConstant %uint 2
// %_ptr_Output_v3uint = OpTypePointer Output %v3uint
//      %uint_4 = OpConstant %uint 4
//      %uint_5 = OpConstant %uint 5
//      %uint_6 = OpConstant %uint 6
//     %uint_64 = OpConstant %uint 64
//      %uint_7 = OpConstant %uint 7
//      %uint_8 = OpConstant %uint 8
//      %uint_9 = OpConstant %uint 9
//     %uint_10 = OpConstant %uint 10
//     %uint_11 = OpConstant %uint 11
//     %uint_12 = OpConstant %uint 12
//     %uint_13 = OpConstant %uint 13
//     %uint_14 = OpConstant %uint 14
// %float_3_14159274 = OpConstant %float 3.14159274
// %float_0_0174532924 = OpConstant %float 0.0174532924
// %float_57_2957802 = OpConstant %float 57.2957802
//  %PointLight = OpTypeStruct %v3float %float %v3float %float
// %_runtimearr_PointLight = OpTypeRuntimeArray %PointLight    ; ArrayStride 32
// %PointLights = OpTypeStruct %uint %uint %uint %uint %_runtimearr_PointLight     ; Block
// %_ptr_StorageBuffer_PointLights = OpTypePointer StorageBuffer %PointLights
//         %__6 = OpVariable %_ptr_StorageBuffer_PointLights StorageBuffer     ; NonWritable, Binding 2, DescriptorSet 0
//         %237 = OpTypeImage %float 2D 0 0 0 1 Unknown
//         %238 = OpTypeSampledImage %237
// %_ptr_UniformConstant_238 = OpTypePointer UniformConstant %238
// %irradianceMap = OpVariable %_ptr_UniformConstant_238 UniformConstant   ; Binding 12, DescriptorSet 0
// %prefilterMap = OpVariable %_ptr_UniformConstant_238 UniformConstant    ; Binding 13, DescriptorSet 0
//     %brdfLut = OpVariable %_ptr_UniformConstant_238 UniformConstant     ; Binding 14, DescriptorSet 0
//   %albedoMap = OpVariable %_ptr_UniformConstant_238 UniformConstant     ; Binding 7, DescriptorSet 0
//   %normalMap = OpVariable %_ptr_UniformConstant_238 UniformConstant     ; Binding 8, DescriptorSet 0
// %metallicMap = OpVariable %_ptr_UniformConstant_238 UniformConstant     ; Binding 9, DescriptorSet 0
// %roughnessMap = OpVariable %_ptr_UniformConstant_238 UniformConstant    ; Binding 10, DescriptorSet 0
//       %aoMap = OpVariable %_ptr_UniformConstant_238 UniformConstant     ; Binding 11, DescriptorSet 0
//         %248 = OpConstantComposite %v3uint %uint_128 %uint_1 %uint_1

//                ; Function ApilaMS
//     %ApilaMS = OpFunction %void None %3
//           %5 = OpLabel
//     %meshlet = OpVariable %_ptr_Function_Meshlet Function
//       %model = OpVariable %_ptr_Function_mat4v4float Function
//      %camera = OpVariable %_ptr_Function_CameraMatrices Function
// %vertexIndex = OpVariable %_ptr_Function_uint Function
//      %vertex = OpVariable %_ptr_Function_LoadedModelVertex Function
// %worldPosition = OpVariable %_ptr_Function_v4float Function
//       %param = OpVariable %_ptr_Function_mat4v4float Function
//     %param_0 = OpVariable %_ptr_Function_v4float Function
//      %offset = OpVariable %_ptr_Function_uint Function
//          %39 = OpAccessChain %_ptr_Input_uint %gl_WorkGroupID %uint_0
//          %40 = OpLoad %uint %39
//          %42 = OpAccessChain %_ptr_StorageBuffer_Meshlet_0 %_ %int_0 %40
//          %43 = OpLoad %Meshlet_0 %42
//          %44 = OpCopyLogical %Meshlet %43
//                OpStore %meshlet %44
//          %47 = OpAccessChain %_ptr_Function_uint %meshlet %int_2
//          %48 = OpLoad %uint %47
//          %50 = OpAccessChain %_ptr_Function_uint %meshlet %int_3
//          %51 = OpLoad %uint %50
//                OpSetMeshOutputsEXT %48 %51
//          %62 = OpAccessChain %_ptr_PushConstant_uint %__1 %int_1
//          %63 = OpLoad %uint %62
//          %65 = OpAccessChain %_ptr_StorageBuffer_mat4v4float %__0 %int_0 %63
//          %66 = OpLoad %mat4v4float %65
//                OpStore %model %66
//          %75 = OpAccessChain %_ptr_PushConstant_uint %__1 %int_0
//          %76 = OpLoad %uint %75
//          %78 = OpAccessChain %_ptr_StorageBuffer_CameraMatrices_0 %__2 %int_0 %76
//          %79 = OpLoad %CameraMatrices_0 %78
//          %80 = OpCopyLogical %CameraMatrices %79
//                OpStore %camera %80
//          %82 = OpAccessChain %_ptr_Input_uint %gl_LocalInvocationID %uint_0
//          %83 = OpLoad %uint %82
//          %84 = OpAccessChain %_ptr_Function_uint %meshlet %int_2
//          %85 = OpLoad %uint %84
//          %87 = OpULessThan %bool %83 %85
//                OpSelectionMerge %89 None
//                OpBranchConditional %87 %88 %89
//          %88 = OpLabel
//          %95 = OpAccessChain %_ptr_Function_uint %meshlet %int_0
//          %96 = OpLoad %uint %95
//          %97 = OpAccessChain %_ptr_Input_uint %gl_LocalInvocationID %uint_0
//          %98 = OpLoad %uint %97
//          %99 = OpIAdd %uint %96 %98
//         %101 = OpAccessChain %_ptr_StorageBuffer_uint %__3 %int_0 %99
//         %102 = OpLoad %uint %101
//                OpStore %vertexIndex %102
//         %113 = OpLoad %uint %vertexIndex
//         %115 = OpAccessChain %_ptr_StorageBuffer_LoadedModelVertex_0 %__4 %int_0 %113
//         %116 = OpLoad %LoadedModelVertex_0 %115
//         %117 = OpCopyLogical %LoadedModelVertex %116
//                OpStore %vertex %117
//         %119 = OpLoad %mat4v4float %model
//         %121 = OpAccessChain %_ptr_Function_v3float %vertex %int_0
//         %122 = OpLoad %v3float %121
//         %124 = OpCompositeExtract %float %122 0
//         %125 = OpCompositeExtract %float %122 1
//         %126 = OpCompositeExtract %float %122 2
//         %127 = OpCompositeConstruct %v4float %124 %125 %126 %float_1
//         %128 = OpMatrixTimesVector %v4float %119 %127
//                OpStore %worldPosition %128
//         %134 = OpAccessChain %_ptr_Input_uint %gl_LocalInvocationID %uint_0
//         %135 = OpLoad %uint %134
//         %136 = OpAccessChain %_ptr_Function_mat4v4float %camera %int_1
//         %137 = OpLoad %mat4v4float %136
//         %138 = OpAccessChain %_ptr_Function_mat4v4float %camera %int_0
//         %139 = OpLoad %mat4v4float %138
//         %140 = OpMatrixTimesMatrix %mat4v4float %137 %139
//                OpStore %param %140
//         %143 = OpLoad %v4float %worldPosition
//                OpStore %param_0 %143
//         %144 = OpFunctionCall %v4float %TransformPosition_mf44_vf4_ %param %param_0
//         %146 = OpAccessChain %_ptr_Output_v4float %gl_MeshVerticesEXT %135 %int_0
//                OpStore %146 %144
//         %150 = OpAccessChain %_ptr_Input_uint %gl_LocalInvocationID %uint_0
//         %151 = OpLoad %uint %150
//         %153 = OpAccessChain %_ptr_Function_v3float %vertex %int_4
//         %154 = OpLoad %v3float %153
//         %156 = OpAccessChain %_ptr_Output_v3float %vNormal %151
//                OpStore %156 %154
//         %160 = OpAccessChain %_ptr_Input_uint %gl_LocalInvocationID %uint_0
//         %161 = OpLoad %uint %160
//         %163 = OpAccessChain %_ptr_Function_v2float %vertex %int_2
//         %164 = OpLoad %v2float %163
//         %166 = OpAccessChain %_ptr_Output_v2float %vUv %161
//                OpStore %166 %164
//         %168 = OpAccessChain %_ptr_Input_uint %gl_LocalInvocationID %uint_0
//         %169 = OpLoad %uint %168
//         %170 = OpLoad %v4float %worldPosition
//         %171 = OpVectorShuffle %v3float %170 %170 0 1 2
//         %172 = OpAccessChain %_ptr_Output_v3float %vWorldPosition %169
//                OpStore %172 %171
//                OpBranch %89
//          %89 = OpLabel
//         %173 = OpAccessChain %_ptr_Input_uint %gl_LocalInvocationID %uint_0
//         %174 = OpLoad %uint %173
//         %175 = OpAccessChain %_ptr_Function_uint %meshlet %int_3
//         %176 = OpLoad %uint %175
//         %177 = OpULessThan %bool %174 %176
//                OpSelectionMerge %179 None
//                OpBranchConditional %177 %178 %179
//         %178 = OpLabel
//         %181 = OpAccessChain %_ptr_Function_uint %meshlet %int_1
//         %182 = OpLoad %uint %181
//         %183 = OpAccessChain %_ptr_Input_uint %gl_LocalInvocationID %uint_0
//         %184 = OpLoad %uint %183
//         %186 = OpIMul %uint %184 %uint_3
//         %187 = OpIAdd %uint %182 %186
//                OpStore %offset %187
//         %191 = OpAccessChain %_ptr_Input_uint %gl_LocalInvocationID %uint_0
//         %192 = OpLoad %uint %191
//         %198 = OpLoad %uint %offset
//         %200 = OpAccessChain %_ptr_StorageBuffer_uchar %__5 %int_0 %198
//         %201 = OpLoad %uchar %200
//         %202 = OpUConvert %uint %201
//         %203 = OpLoad %uint %offset
//         %204 = OpIAdd %uint %203 %uint_1
//         %205 = OpAccessChain %_ptr_StorageBuffer_uchar %__5 %int_0 %204
//         %206 = OpLoad %uchar %205
//         %207 = OpUConvert %uint %206
//         %208 = OpLoad %uint %offset
//         %210 = OpIAdd %uint %208 %uint_2
//         %211 = OpAccessChain %_ptr_StorageBuffer_uchar %__5 %int_0 %210
//         %212 = OpLoad %uchar %211
//         %213 = OpUConvert %uint %212
//         %214 = OpCompositeConstruct %v3uint %202 %207 %213
//         %216 = OpAccessChain %_ptr_Output_v3uint %gl_PrimitiveTriangleIndicesEXT %192
//                OpStore %216 %214
//                OpBranch %179
//         %179 = OpLabel
//                OpReturn
//                OpFunctionEnd

//                ; Function TransformPosition_mf44_vf4_
// %TransformPosition_mf44_vf4_ = OpFunction %v4float None %14
//         %mvp = OpFunctionParameter %_ptr_Function_mat4v4float
//    %position = OpFunctionParameter %_ptr_Function_v4float
//          %18 = OpLabel
//          %19 = OpLoad %mat4v4float %mvp
//          %20 = OpLoad %v4float %position
//          %21 = OpMatrixTimesVector %v4float %19 %20
//                OpReturnValue %21
//                OpFunctionEnd





// ; SPIR-V
// ; Version: 1.6
// ; Generator: Khronos Glslang Reference Front End; 11
// ; Bound: 645
// ; Schema: 0
//                OpCapability Shader
//                OpCapability StorageBuffer8BitAccess
//           %1 = OpExtInstImport "GLSL.std.450"
//                OpMemoryModel Logical GLSL450
//                OpEntryPoint Fragment %ApilaFS "ApilaFS" %albedoMap %vUv %metallicMap %roughnessMap %aoMap %_ %__0 %normalMap_0 %vWorldPosition %vNormal %__1 %irradianceMap %prefilterMap %brdfLut %fragColor %__2 %__3 %__4 %__5 %__6
//                OpExecutionMode %ApilaFS OriginUpperLeft

//                ; Debug Information
//                OpSource GLSL 460
//                OpSourceExtension "GL_EXT_debug_printf"
//                OpSourceExtension "GL_EXT_mesh_shader"
//                OpSourceExtension "GL_EXT_shader_8bit_storage"
//                OpSourceExtension "GL_GOOGLE_cpp_style_line_directive"
//                OpSourceExtension "GL_GOOGLE_include_directive"
//                OpName %ApilaFS "ApilaFS"            ; id %4
//                OpName %GetCameraPositionFromViewMatrix_mf44_ "GetCameraPositionFromViewMatrix(mf44;"    ; id %13
//                OpName %view "view"                                                                      ; id %12
//                OpName %DistributionGGX_vf3_vf3_f1_ "DistributionGGX(vf3;vf3;f1;"                        ; id %21
//                OpName %N "N"                                                                            ; id %18
//                OpName %H "H"                                                                            ; id %19
//                OpName %roughness "roughness"                                                            ; id %20
//                OpName %GeometrySchlickGGXDirect_f1_f1_ "GeometrySchlickGGXDirect(f1;f1;"                ; id %26
//                OpName %NdotV "NdotV"                                                                    ; id %24
//                OpName %roughness_0 "roughness"                                                          ; id %25
//                OpName %GeometrySmithDirect_vf3_vf3_vf3_f1_ "GeometrySmithDirect(vf3;vf3;vf3;f1;"        ; id %33
//                OpName %N_0 "N"                                                                          ; id %29
//                OpName %V "V"                                                                            ; id %30
//                OpName %L "L"                                                                            ; id %31
//                OpName %roughness_1 "roughness"                                                          ; id %32
//                OpName %FresnelSchlick_f1_vf3_ "FresnelSchlick(f1;vf3;"                                  ; id %38
//                OpName %cosTheta "cosTheta"                                                              ; id %36
//                OpName %F0 "F0"                                                                          ; id %37
//                OpName %FresnelSchlickRoughness_f1_vf3_f1_ "FresnelSchlickRoughness(f1;vf3;f1;"          ; id %44
//                OpName %cosTheta_0 "cosTheta"                                                            ; id %41
//                OpName %F0_0 "F0"                                                                        ; id %42
//                OpName %roughness_2 "roughness"                                                          ; id %43
//                OpName %SampleSphericalMap_vf3_ "SampleSphericalMap(vf3;"                                ; id %49
//                OpName %v "v"                                                                            ; id %48
//                OpName %DirectionToEquirectangularUv_vf3_ "DirectionToEquirectangularUv(vf3;"            ; id %52
//                OpName %direction "direction"                                                            ; id %51
//                OpName %GetNormalFromMap_s21_vf2_vf3_vf3_ "GetNormalFromMap(s21;vf2;vf3;vf3;"            ; id %63
//                OpName %normalMap "normalMap"                                                            ; id %59
//                OpName %uv "uv"                                                                          ; id %60
//                OpName %worldPosition "worldPosition"                                                    ; id %61
//                OpName %vertexNormal "vertexNormal"                                                      ; id %62
//                OpName %a "a"                                                                            ; id %73
//                OpName %a2 "a2"                                                                          ; id %77
//                OpName %NdotH "NdotH"                                                                    ; id %81
//                OpName %NdotH2 "NdotH2"                                                                  ; id %87
//                OpName %num "num"                                                                        ; id %91
//                OpName %denom "denom"                                                                    ; id %93
//                OpName %r "r"                                                                            ; id %110
//                OpName %k "k"                                                                            ; id %113
//                OpName %num_0 "num"                                                                      ; id %119
//                OpName %denom_0 "denom"                                                                  ; id %121
//                OpName %NdotV_0 "NdotV"                                                                  ; id %133
//                OpName %NdotL "NdotL"                                                                    ; id %138
//                OpName %ggx2 "ggx2"                                                                      ; id %143
//                OpName %param "param"                                                                    ; id %144
//                OpName %param_0 "param"                                                                  ; id %146
//                OpName %ggx1 "ggx1"                                                                      ; id %149
//                OpName %param_1 "param"                                                                  ; id %150
//                OpName %param_2 "param"                                                                  ; id %152
//                OpName %invAtan "invAtan"                                                                ; id %191
//                OpName %uv_0 "uv"                                                                        ; id %195
//                OpName %param_3 "param"                                                                  ; id %219
//                OpName %tangentNormal "tangentNormal"                                                    ; id %224
//                OpName %Q1 "Q1"                                                                          ; id %233
//                OpName %Q2 "Q2"                                                                          ; id %236
//                OpName %st1 "st1"                                                                        ; id %239
//                OpName %st2 "st2"                                                                        ; id %242
//                OpName %N_1 "N"                                                                          ; id %245
//                OpName %T "T"                                                                            ; id %248
//                OpName %B "B"                                                                            ; id %259
//                OpName %TBN "TBN"                                                                        ; id %267
//                OpName %albedo "albedo"                                                                  ; id %290
//                OpName %albedoMap "albedoMap"                                                            ; id %291
//                OpName %vUv "vUv"                                                                        ; id %294
//                OpName %metallic "metallic"                                                              ; id %301
//                OpName %metallicMap "metallicMap"                                                        ; id %302
//                OpName %roughness_3 "roughness"                                                          ; id %307
//                OpName %roughnessMap "roughnessMap"                                                      ; id %308
//                OpName %ao "ao"                                                                          ; id %313
//                OpName %aoMap "aoMap"                                                                    ; id %314
//                OpName %CameraMatrices "CameraMatrices"                                                  ; id %319
//                OpMemberName %CameraMatrices 0 "view"
//                OpMemberName %CameraMatrices 1 "projection"
//                OpName %camera "camera"              ; id %321
//                OpName %CameraMatrices_0 "CameraMatrices"    ; id %322
//                OpMemberName %CameraMatrices_0 0 "view"
//                OpMemberName %CameraMatrices_0 1 "projection"
//                OpName %Cameras "Cameras"            ; id %324
//                OpMemberName %Cameras 0 "cameraMatrices"
//                OpName %_ ""                         ; id %326
//                OpName %PC "PC"                      ; id %328
//                OpMemberName %PC 0 "cameraMatrixIdx"
//                OpMemberName %PC 1 "modelMatrixIdx"
//                OpMemberName %PC 2 "prefilterMapMipLevels"
//                OpName %__0 ""                       ; id %330
//                OpName %cameraPosition "cameraPosition"  ; id %338
//                OpName %param_4 "param"                  ; id %339
//                OpName %N_2 "N"                          ; id %343
//                OpName %normalMap_0 "normalMap"          ; id %344
//                OpName %vWorldPosition "vWorldPosition"  ; id %346
//                OpName %vNormal "vNormal"                ; id %347
//                OpName %param_5 "param"                  ; id %348
//                OpName %param_6 "param"                  ; id %350
//                OpName %param_7 "param"                  ; id %352
//                OpName %V_0 "V"                          ; id %355
//                OpName %R "R"                            ; id %360
//                OpName %F0_1 "F0"                        ; id %365
//                OpName %Lo "Lo"                          ; id %373
//                OpName %i "i"                            ; id %376
//                OpName %PointLight "PointLight"          ; id %384
//                OpMemberName %PointLight 0 "position"
//                OpMemberName %PointLight 1 "radius"
//                OpMemberName %PointLight 2 "color"
//                OpMemberName %PointLight 3 "intensity"
//                OpName %PointLights "PointLights"    ; id %386
//                OpMemberName %PointLights 0 "pointLightCount"
//                OpMemberName %PointLights 1 "padding0"
//                OpMemberName %PointLights 2 "padding1"
//                OpMemberName %PointLights 3 "padding2"
//                OpMemberName %PointLights 4 "pointLights"
//                OpName %__1 ""                       ; id %388
//                OpName %PointLight_0 "PointLight"    ; id %394
//                OpMemberName %PointLight_0 0 "position"
//                OpMemberName %PointLight_0 1 "radius"
//                OpMemberName %PointLight_0 2 "color"
//                OpMemberName %PointLight_0 3 "intensity"
//                OpName %pointLight "pointLight"      ; id %396
//                OpName %L_0 "L"                      ; id %403
//                OpName %H_0 "H"                      ; id %409
//                OpName %distance "distance"          ; id %414
//                OpName %attenuation "attenuation"    ; id %420
//                OpName %radiance "radiance"          ; id %425
//                OpName %NDF "NDF"                    ; id %431
//                OpName %param_8 "param"              ; id %432
//                OpName %param_9 "param"              ; id %434
//                OpName %param_10 "param"             ; id %436
//                OpName %G "G"                        ; id %439
//                OpName %param_11 "param"             ; id %440
//                OpName %param_12 "param"             ; id %442
//                OpName %param_13 "param"             ; id %444
//                OpName %param_14 "param"             ; id %446
//                OpName %F "F"                        ; id %449
//                OpName %param_15 "param"             ; id %454
//                OpName %param_16 "param"             ; id %455
//                OpName %numerator "numerator"        ; id %458
//                OpName %denominator "denominator"    ; id %464
//                OpName %specular "specular"          ; id %478
//                OpName %kS "kS"                      ; id %483
//                OpName %kD "kD"                      ; id %485
//                OpName %NdotL_0 "NdotL"              ; id %493
//                OpName %F_0 "F"                      ; id %514
//                OpName %param_17 "param"             ; id %519
//                OpName %param_18 "param"             ; id %520
//                OpName %param_19 "param"             ; id %522
//                OpName %kS_0 "kS"                    ; id %525
//                OpName %kD_0 "kD"                    ; id %527
//                OpName %irradiance "irradiance"      ; id %535
//                OpName %irradianceMap "irradianceMap"    ; id %536
//                OpName %param_20 "param"                 ; id %538
//                OpName %diffuse "diffuse"                ; id %543
//                OpName %prefilteredColor "prefilteredColor"  ; id %547
//                OpName %prefilterMap "prefilterMap"          ; id %548
//                OpName %param_21 "param"                     ; id %550
//                OpName %brdf "brdf"                          ; id %561
//                OpName %brdfLut "brdfLut"                    ; id %562
//                OpName %specular_0 "specular"                ; id %572
//                OpName %ambient "ambient"                    ; id %583
//                OpName %color "color"                        ; id %591
//                OpName %fragColor "fragColor"                ; id %600
//                OpName %Meshlet "Meshlet"                    ; id %622
//                OpMemberName %Meshlet 0 "vertexOffset"
//                OpMemberName %Meshlet 1 "triangleOffset"
//                OpMemberName %Meshlet 2 "vertexCount"
//                OpMemberName %Meshlet 3 "triangleCount"
//                OpName %Meshlets "Meshlets"          ; id %624
//                OpMemberName %Meshlets 0 "meshlets"
//                OpName %__2 ""                       ; id %626
//                OpName %MeshletVertices "MeshletVertices"    ; id %628
//                OpMemberName %MeshletVertices 0 "meshletVertices"
//                OpName %__3 ""                       ; id %630
//                OpName %MeshletTriangles "MeshletTriangles"  ; id %633
//                OpMemberName %MeshletTriangles 0 "meshletTriangles"
//                OpName %__4 ""                       ; id %635
//                OpName %LoadedModelVertex "LoadedModelVertex"    ; id %636
//                OpMemberName %LoadedModelVertex 0 "position"
//                OpMemberName %LoadedModelVertex 1 "padding0"
//                OpMemberName %LoadedModelVertex 2 "uv"
//                OpMemberName %LoadedModelVertex 3 "padding1"
//                OpMemberName %LoadedModelVertex 4 "normal"
//                OpMemberName %LoadedModelVertex 5 "padding2"
//                OpName %Vertices "Vertices"          ; id %638
//                OpMemberName %Vertices 0 "vertices"
//                OpName %__5 ""                       ; id %640
//                OpName %ModelMatrices "ModelMatrices"    ; id %642
//                OpMemberName %ModelMatrices 0 "modelMatrices"
//                OpName %__6 ""                       ; id %644

//                ; Annotations
//                OpDecorate %albedoMap Binding 7
//                OpDecorate %albedoMap DescriptorSet 0
//                OpDecorate %vUv Location 1
//                OpDecorate %metallicMap Binding 9
//                OpDecorate %metallicMap DescriptorSet 0
//                OpDecorate %roughnessMap Binding 10
//                OpDecorate %roughnessMap DescriptorSet 0
//                OpDecorate %aoMap Binding 11
//                OpDecorate %aoMap DescriptorSet 0
//                OpMemberDecorate %CameraMatrices_0 0 ColMajor
//                OpMemberDecorate %CameraMatrices_0 0 MatrixStride 16
//                OpMemberDecorate %CameraMatrices_0 0 Offset 0
//                OpMemberDecorate %CameraMatrices_0 1 ColMajor
//                OpMemberDecorate %CameraMatrices_0 1 MatrixStride 16
//                OpMemberDecorate %CameraMatrices_0 1 Offset 64
//                OpDecorate %_runtimearr_CameraMatrices_0 ArrayStride 128
//                OpDecorate %Cameras Block
//                OpMemberDecorate %Cameras 0 NonWritable
//                OpMemberDecorate %Cameras 0 Offset 0
//                OpDecorate %_ NonWritable
//                OpDecorate %_ Binding 0
//                OpDecorate %_ DescriptorSet 0
//                OpDecorate %PC Block
//                OpMemberDecorate %PC 0 Offset 0
//                OpMemberDecorate %PC 1 Offset 4
//                OpMemberDecorate %PC 2 Offset 8
//                OpDecorate %normalMap_0 Binding 8
//                OpDecorate %normalMap_0 DescriptorSet 0
//                OpDecorate %vWorldPosition Location 2
//                OpDecorate %vNormal Location 0
//                OpMemberDecorate %PointLight 0 Offset 0
//                OpMemberDecorate %PointLight 1 Offset 12
//                OpMemberDecorate %PointLight 2 Offset 16
//                OpMemberDecorate %PointLight 3 Offset 28
//                OpDecorate %_runtimearr_PointLight ArrayStride 32
//                OpDecorate %PointLights Block
//                OpMemberDecorate %PointLights 0 NonWritable
//                OpMemberDecorate %PointLights 0 Offset 0
//                OpMemberDecorate %PointLights 1 NonWritable
//                OpMemberDecorate %PointLights 1 Offset 4
//                OpMemberDecorate %PointLights 2 NonWritable
//                OpMemberDecorate %PointLights 2 Offset 8
//                OpMemberDecorate %PointLights 3 NonWritable
//                OpMemberDecorate %PointLights 3 Offset 12
//                OpMemberDecorate %PointLights 4 NonWritable
//                OpMemberDecorate %PointLights 4 Offset 16
//                OpDecorate %__1 NonWritable
//                OpDecorate %__1 Binding 2
//                OpDecorate %__1 DescriptorSet 0
//                OpDecorate %irradianceMap Binding 12
//                OpDecorate %irradianceMap DescriptorSet 0
//                OpDecorate %prefilterMap Binding 13
//                OpDecorate %prefilterMap DescriptorSet 0
//                OpDecorate %brdfLut Binding 14
//                OpDecorate %brdfLut DescriptorSet 0
//                OpDecorate %fragColor Location 0
//                OpMemberDecorate %Meshlet 0 Offset 0
//                OpMemberDecorate %Meshlet 1 Offset 4
//                OpMemberDecorate %Meshlet 2 Offset 8
//                OpMemberDecorate %Meshlet 3 Offset 12
//                OpDecorate %_runtimearr_Meshlet ArrayStride 16
//                OpDecorate %Meshlets Block
//                OpMemberDecorate %Meshlets 0 NonWritable
//                OpMemberDecorate %Meshlets 0 Offset 0
//                OpDecorate %__2 NonWritable
//                OpDecorate %__2 Binding 3
//                OpDecorate %__2 DescriptorSet 0
//                OpDecorate %_runtimearr_uint ArrayStride 4
//                OpDecorate %MeshletVertices Block
//                OpMemberDecorate %MeshletVertices 0 NonWritable
//                OpMemberDecorate %MeshletVertices 0 Offset 0
//                OpDecorate %__3 NonWritable
//                OpDecorate %__3 Binding 4
//                OpDecorate %__3 DescriptorSet 0
//                OpDecorate %_runtimearr_uchar ArrayStride 1
//                OpDecorate %MeshletTriangles Block
//                OpMemberDecorate %MeshletTriangles 0 NonWritable
//                OpMemberDecorate %MeshletTriangles 0 Offset 0
//                OpDecorate %__4 NonWritable
//                OpDecorate %__4 Binding 5
//                OpDecorate %__4 DescriptorSet 0
//                OpMemberDecorate %LoadedModelVertex 0 Offset 0
//                OpMemberDecorate %LoadedModelVertex 1 Offset 12
//                OpMemberDecorate %LoadedModelVertex 2 Offset 16
//                OpMemberDecorate %LoadedModelVertex 3 Offset 24
//                OpMemberDecorate %LoadedModelVertex 4 Offset 32
//                OpMemberDecorate %LoadedModelVertex 5 Offset 44
//                OpDecorate %_runtimearr_LoadedModelVertex ArrayStride 48
//                OpDecorate %Vertices Block
//                OpMemberDecorate %Vertices 0 NonWritable
//                OpMemberDecorate %Vertices 0 Offset 0
//                OpDecorate %__5 NonWritable
//                OpDecorate %__5 Binding 6
//                OpDecorate %__5 DescriptorSet 0
//                OpDecorate %_runtimearr_mat4v4float ArrayStride 64
//                OpDecorate %ModelMatrices Block
//                OpMemberDecorate %ModelMatrices 0 ColMajor
//                OpMemberDecorate %ModelMatrices 0 MatrixStride 16
//                OpMemberDecorate %ModelMatrices 0 NonWritable
//                OpMemberDecorate %ModelMatrices 0 Offset 0
//                OpDecorate %__6 NonWritable
//                OpDecorate %__6 Binding 1
//                OpDecorate %__6 DescriptorSet 0

//                ; Types, variables and constants
//        %void = OpTypeVoid
//           %3 = OpTypeFunction %void
//       %float = OpTypeFloat 32
//     %v4float = OpTypeVector %float 4
// %mat4v4float = OpTypeMatrix %v4float 4
// %_ptr_Function_mat4v4float = OpTypePointer Function %mat4v4float
//     %v3float = OpTypeVector %float 3
//          %11 = OpTypeFunction %v3float %_ptr_Function_mat4v4float
// %_ptr_Function_v3float = OpTypePointer Function %v3float
// %_ptr_Function_float = OpTypePointer Function %float
//          %17 = OpTypeFunction %float %_ptr_Function_v3float %_ptr_Function_v3float %_ptr_Function_float
//          %23 = OpTypeFunction %float %_ptr_Function_float %_ptr_Function_float
//          %28 = OpTypeFunction %float %_ptr_Function_v3float %_ptr_Function_v3float %_ptr_Function_v3float %_ptr_Function_float
//          %35 = OpTypeFunction %v3float %_ptr_Function_float %_ptr_Function_v3float
//          %40 = OpTypeFunction %v3float %_ptr_Function_float %_ptr_Function_v3float %_ptr_Function_float
//     %v2float = OpTypeVector %float 2
//          %47 = OpTypeFunction %v2float %_ptr_Function_v3float
//          %54 = OpTypeImage %float 2D 0 0 0 1 Unknown
//          %55 = OpTypeSampledImage %54
// %_ptr_UniformConstant_55 = OpTypePointer UniformConstant %55
// %_ptr_Function_v2float = OpTypePointer Function %v2float
//          %58 = OpTypeFunction %v3float %_ptr_UniformConstant_55 %_ptr_Function_v2float %_ptr_Function_v3float %_ptr_Function_v3float
//         %int = OpTypeInt 32 1
//       %int_3 = OpConstant %int 3
//     %float_0 = OpConstant %float 0
//     %float_1 = OpConstant %float 1
// %float_3_14159274 = OpConstant %float 3.14159274
//     %float_8 = OpConstant %float 8
//     %float_5 = OpConstant %float 5
// %float_0_159099996 = OpConstant %float 0.159099996
// %float_0_318300009 = OpConstant %float 0.318300009
//         %194 = OpConstantComposite %v2float %float_0_159099996 %float_0_318300009
//        %uint = OpTypeInt 32 0
//      %uint_2 = OpConstant %uint 2
//      %uint_0 = OpConstant %uint 0
//      %uint_1 = OpConstant %uint 1
//   %float_0_5 = OpConstant %float 0.5
//     %float_2 = OpConstant %float 2
// %mat3v3float = OpTypeMatrix %v3float 3
// %_ptr_Function_mat3v3float = OpTypePointer Function %mat3v3float
//   %albedoMap = OpVariable %_ptr_UniformConstant_55 UniformConstant  ; Binding 7, DescriptorSet 0
// %_ptr_Input_v2float = OpTypePointer Input %v2float
//         %vUv = OpVariable %_ptr_Input_v2float Input     ; Location 1
// %float_2_20000005 = OpConstant %float 2.20000005
//         %299 = OpConstantComposite %v3float %float_2_20000005 %float_2_20000005 %float_2_20000005
// %metallicMap = OpVariable %_ptr_UniformConstant_55 UniformConstant  ; Binding 9, DescriptorSet 0
// %roughnessMap = OpVariable %_ptr_UniformConstant_55 UniformConstant     ; Binding 10, DescriptorSet 0
//       %aoMap = OpVariable %_ptr_UniformConstant_55 UniformConstant      ; Binding 11, DescriptorSet 0
// %CameraMatrices = OpTypeStruct %mat4v4float %mat4v4float
// %_ptr_Function_CameraMatrices = OpTypePointer Function %CameraMatrices
// %CameraMatrices_0 = OpTypeStruct %mat4v4float %mat4v4float
// %_runtimearr_CameraMatrices_0 = OpTypeRuntimeArray %CameraMatrices_0    ; ArrayStride 128
//     %Cameras = OpTypeStruct %_runtimearr_CameraMatrices_0               ; Block
// %_ptr_StorageBuffer_Cameras = OpTypePointer StorageBuffer %Cameras
//           %_ = OpVariable %_ptr_StorageBuffer_Cameras StorageBuffer     ; NonWritable, Binding 0, DescriptorSet 0
//       %int_0 = OpConstant %int 0
//          %PC = OpTypeStruct %uint %uint %uint       ; Block
// %_ptr_PushConstant_PC = OpTypePointer PushConstant %PC
//         %__0 = OpVariable %_ptr_PushConstant_PC PushConstant
// %_ptr_PushConstant_uint = OpTypePointer PushConstant %uint
// %_ptr_StorageBuffer_CameraMatrices_0 = OpTypePointer StorageBuffer %CameraMatrices_0
// %normalMap_0 = OpVariable %_ptr_UniformConstant_55 UniformConstant  ; Binding 8, DescriptorSet 0
// %_ptr_Input_v3float = OpTypePointer Input %v3float
// %vWorldPosition = OpVariable %_ptr_Input_v3float Input  ; Location 2
//     %vNormal = OpVariable %_ptr_Input_v3float Input     ; Location 0
// %float_0_0399999991 = OpConstant %float 0.0399999991
//         %367 = OpConstantComposite %v3float %float_0_0399999991 %float_0_0399999991 %float_0_0399999991
//         %374 = OpConstantComposite %v3float %float_0 %float_0 %float_0
// %_ptr_Function_int = OpTypePointer Function %int
//  %PointLight = OpTypeStruct %v3float %float %v3float %float
// %_runtimearr_PointLight = OpTypeRuntimeArray %PointLight    ; ArrayStride 32
// %PointLights = OpTypeStruct %uint %uint %uint %uint %_runtimearr_PointLight     ; Block
// %_ptr_StorageBuffer_PointLights = OpTypePointer StorageBuffer %PointLights
//         %__1 = OpVariable %_ptr_StorageBuffer_PointLights StorageBuffer     ; NonWritable, Binding 2, DescriptorSet 0
// %_ptr_StorageBuffer_uint = OpTypePointer StorageBuffer %uint
//        %bool = OpTypeBool
// %PointLight_0 = OpTypeStruct %v3float %float %v3float %float
// %_ptr_Function_PointLight_0 = OpTypePointer Function %PointLight_0
//       %int_4 = OpConstant %int 4
// %_ptr_StorageBuffer_PointLight = OpTypePointer StorageBuffer %PointLight
//       %int_2 = OpConstant %int 2
//     %float_4 = OpConstant %float 4
// %float_9_99999975en05 = OpConstant %float 9.99999975e-05
//         %486 = OpConstantComposite %v3float %float_1 %float_1 %float_1
//       %int_1 = OpConstant %int 1
// %irradianceMap = OpVariable %_ptr_UniformConstant_55 UniformConstant    ; Binding 12, DescriptorSet 0
// %prefilterMap = OpVariable %_ptr_UniformConstant_55 UniformConstant     ; Binding 13, DescriptorSet 0
//     %brdfLut = OpVariable %_ptr_UniformConstant_55 UniformConstant      ; Binding 14, DescriptorSet 0
// %_ptr_Output_v4float = OpTypePointer Output %v4float
//   %fragColor = OpVariable %_ptr_Output_v4float Output   ; Location 0
//      %uint_3 = OpConstant %uint 3
//      %uint_4 = OpConstant %uint 4
//      %uint_5 = OpConstant %uint 5
//      %uint_6 = OpConstant %uint 6
//     %uint_64 = OpConstant %uint 64
//      %uint_7 = OpConstant %uint 7
//      %uint_8 = OpConstant %uint 8
//      %uint_9 = OpConstant %uint 9
//     %uint_10 = OpConstant %uint 10
//     %uint_11 = OpConstant %uint 11
//     %uint_12 = OpConstant %uint 12
//     %uint_13 = OpConstant %uint 13
//     %uint_14 = OpConstant %uint 14
//    %uint_128 = OpConstant %uint 128
// %float_0_0174532924 = OpConstant %float 0.0174532924
// %float_57_2957802 = OpConstant %float 57.2957802
//     %Meshlet = OpTypeStruct %uint %uint %uint %uint
// %_runtimearr_Meshlet = OpTypeRuntimeArray %Meshlet  ; ArrayStride 16
//    %Meshlets = OpTypeStruct %_runtimearr_Meshlet    ; Block
// %_ptr_StorageBuffer_Meshlets = OpTypePointer StorageBuffer %Meshlets
//         %__2 = OpVariable %_ptr_StorageBuffer_Meshlets StorageBuffer    ; NonWritable, Binding 3, DescriptorSet 0
// %_runtimearr_uint = OpTypeRuntimeArray %uint                            ; ArrayStride 4
// %MeshletVertices = OpTypeStruct %_runtimearr_uint                       ; Block
// %_ptr_StorageBuffer_MeshletVertices = OpTypePointer StorageBuffer %MeshletVertices
//         %__3 = OpVariable %_ptr_StorageBuffer_MeshletVertices StorageBuffer     ; NonWritable, Binding 4, DescriptorSet 0
//       %uchar = OpTypeInt 8 0
// %_runtimearr_uchar = OpTypeRuntimeArray %uchar      ; ArrayStride 1
// %MeshletTriangles = OpTypeStruct %_runtimearr_uchar     ; Block
// %_ptr_StorageBuffer_MeshletTriangles = OpTypePointer StorageBuffer %MeshletTriangles
//         %__4 = OpVariable %_ptr_StorageBuffer_MeshletTriangles StorageBuffer    ; NonWritable, Binding 5, DescriptorSet 0
// %LoadedModelVertex = OpTypeStruct %v3float %float %v2float %v2float %v3float %float
// %_runtimearr_LoadedModelVertex = OpTypeRuntimeArray %LoadedModelVertex  ; ArrayStride 48
//    %Vertices = OpTypeStruct %_runtimearr_LoadedModelVertex              ; Block
// %_ptr_StorageBuffer_Vertices = OpTypePointer StorageBuffer %Vertices
//         %__5 = OpVariable %_ptr_StorageBuffer_Vertices StorageBuffer    ; NonWritable, Binding 6, DescriptorSet 0
// %_runtimearr_mat4v4float = OpTypeRuntimeArray %mat4v4float              ; ArrayStride 64
// %ModelMatrices = OpTypeStruct %_runtimearr_mat4v4float                  ; Block
// %_ptr_StorageBuffer_ModelMatrices = OpTypePointer StorageBuffer %ModelMatrices
//         %__6 = OpVariable %_ptr_StorageBuffer_ModelMatrices StorageBuffer   ; NonWritable, Binding 1, DescriptorSet 0

//                ; Function ApilaFS
//     %ApilaFS = OpFunction %void None %3
//           %5 = OpLabel
//      %albedo = OpVariable %_ptr_Function_v3float Function
//    %metallic = OpVariable %_ptr_Function_float Function
// %roughness_3 = OpVariable %_ptr_Function_float Function
//          %ao = OpVariable %_ptr_Function_float Function
//      %camera = OpVariable %_ptr_Function_CameraMatrices Function
// %cameraPosition = OpVariable %_ptr_Function_v3float Function
//     %param_4 = OpVariable %_ptr_Function_mat4v4float Function
//         %N_2 = OpVariable %_ptr_Function_v3float Function
//     %param_5 = OpVariable %_ptr_Function_v2float Function
//     %param_6 = OpVariable %_ptr_Function_v3float Function
//     %param_7 = OpVariable %_ptr_Function_v3float Function
//         %V_0 = OpVariable %_ptr_Function_v3float Function
//           %R = OpVariable %_ptr_Function_v3float Function
//        %F0_1 = OpVariable %_ptr_Function_v3float Function
//          %Lo = OpVariable %_ptr_Function_v3float Function
//           %i = OpVariable %_ptr_Function_int Function
//  %pointLight = OpVariable %_ptr_Function_PointLight_0 Function
//         %L_0 = OpVariable %_ptr_Function_v3float Function
//         %H_0 = OpVariable %_ptr_Function_v3float Function
//    %distance = OpVariable %_ptr_Function_float Function
// %attenuation = OpVariable %_ptr_Function_float Function
//    %radiance = OpVariable %_ptr_Function_v3float Function
//         %NDF = OpVariable %_ptr_Function_float Function
//     %param_8 = OpVariable %_ptr_Function_v3float Function
//     %param_9 = OpVariable %_ptr_Function_v3float Function
//    %param_10 = OpVariable %_ptr_Function_float Function
//           %G = OpVariable %_ptr_Function_float Function
//    %param_11 = OpVariable %_ptr_Function_v3float Function
//    %param_12 = OpVariable %_ptr_Function_v3float Function
//    %param_13 = OpVariable %_ptr_Function_v3float Function
//    %param_14 = OpVariable %_ptr_Function_float Function
//           %F = OpVariable %_ptr_Function_v3float Function
//    %param_15 = OpVariable %_ptr_Function_float Function
//    %param_16 = OpVariable %_ptr_Function_v3float Function
//   %numerator = OpVariable %_ptr_Function_v3float Function
// %denominator = OpVariable %_ptr_Function_float Function
//    %specular = OpVariable %_ptr_Function_v3float Function
//          %kS = OpVariable %_ptr_Function_v3float Function
//          %kD = OpVariable %_ptr_Function_v3float Function
//     %NdotL_0 = OpVariable %_ptr_Function_float Function
//         %F_0 = OpVariable %_ptr_Function_v3float Function
//    %param_17 = OpVariable %_ptr_Function_float Function
//    %param_18 = OpVariable %_ptr_Function_v3float Function
//    %param_19 = OpVariable %_ptr_Function_float Function
//        %kS_0 = OpVariable %_ptr_Function_v3float Function
//        %kD_0 = OpVariable %_ptr_Function_v3float Function
//  %irradiance = OpVariable %_ptr_Function_v3float Function
//    %param_20 = OpVariable %_ptr_Function_v3float Function
//     %diffuse = OpVariable %_ptr_Function_v3float Function
// %prefilteredColor = OpVariable %_ptr_Function_v3float Function
//    %param_21 = OpVariable %_ptr_Function_v3float Function
//        %brdf = OpVariable %_ptr_Function_v2float Function
//  %specular_0 = OpVariable %_ptr_Function_v3float Function
//     %ambient = OpVariable %_ptr_Function_v3float Function
//       %color = OpVariable %_ptr_Function_v3float Function
//         %292 = OpLoad %55 %albedoMap
//         %295 = OpLoad %v2float %vUv
//         %296 = OpImageSampleImplicitLod %v4float %292 %295
//         %297 = OpVectorShuffle %v3float %296 %296 0 1 2
//         %300 = OpExtInst %v3float %1 Pow %297 %299
//                OpStore %albedo %300
//         %303 = OpLoad %55 %metallicMap
//         %304 = OpLoad %v2float %vUv
//         %305 = OpImageSampleImplicitLod %v4float %303 %304
//         %306 = OpCompositeExtract %float %305 0
//                OpStore %metallic %306
//         %309 = OpLoad %55 %roughnessMap
//         %310 = OpLoad %v2float %vUv
//         %311 = OpImageSampleImplicitLod %v4float %309 %310
//         %312 = OpCompositeExtract %float %311 0
//                OpStore %roughness_3 %312
//         %315 = OpLoad %55 %aoMap
//         %316 = OpLoad %v2float %vUv
//         %317 = OpImageSampleImplicitLod %v4float %315 %316
//         %318 = OpCompositeExtract %float %317 0
//                OpStore %ao %318
//         %332 = OpAccessChain %_ptr_PushConstant_uint %__0 %int_0
//         %333 = OpLoad %uint %332
//         %335 = OpAccessChain %_ptr_StorageBuffer_CameraMatrices_0 %_ %int_0 %333
//         %336 = OpLoad %CameraMatrices_0 %335
//         %337 = OpCopyLogical %CameraMatrices %336
//                OpStore %camera %337
//         %340 = OpAccessChain %_ptr_Function_mat4v4float %camera %int_0
//         %341 = OpLoad %mat4v4float %340
//                OpStore %param_4 %341
//         %342 = OpFunctionCall %v3float %GetCameraPositionFromViewMatrix_mf44_ %param_4
//                OpStore %cameraPosition %342
//         %349 = OpLoad %v2float %vUv
//                OpStore %param_5 %349
//         %351 = OpLoad %v3float %vWorldPosition
//                OpStore %param_6 %351
//         %353 = OpLoad %v3float %vNormal
//                OpStore %param_7 %353
//         %354 = OpFunctionCall %v3float %GetNormalFromMap_s21_vf2_vf3_vf3_ %normalMap_0 %param_5 %param_6 %param_7
//                OpStore %N_2 %354
//         %356 = OpLoad %v3float %cameraPosition
//         %357 = OpLoad %v3float %vWorldPosition
//         %358 = OpFSub %v3float %356 %357
//         %359 = OpExtInst %v3float %1 Normalize %358
//                OpStore %V_0 %359
//         %361 = OpLoad %v3float %V_0
//         %362 = OpFNegate %v3float %361
//         %363 = OpLoad %v3float %N_2
//         %364 = OpExtInst %v3float %1 Reflect %362 %363
//                OpStore %R %364
//                OpStore %F0_1 %367
//         %368 = OpLoad %v3float %F0_1
//         %369 = OpLoad %v3float %albedo
//         %370 = OpLoad %float %metallic
//         %371 = OpCompositeConstruct %v3float %370 %370 %370
//         %372 = OpExtInst %v3float %1 FMix %368 %369 %371
//                OpStore %F0_1 %372
//                OpStore %Lo %374
//                OpStore %i %int_0
//                OpBranch %377
//         %377 = OpLabel
//                OpLoopMerge %379 %380 None
//                OpBranch %381
//         %381 = OpLabel
//         %382 = OpLoad %int %i
//         %383 = OpBitcast %uint %382
//         %390 = OpAccessChain %_ptr_StorageBuffer_uint %__1 %int_0
//         %391 = OpLoad %uint %390
//         %393 = OpULessThan %bool %383 %391
//                OpBranchConditional %393 %378 %379
//         %378 = OpLabel
//         %398 = OpLoad %int %i
//         %400 = OpAccessChain %_ptr_StorageBuffer_PointLight %__1 %int_4 %398
//         %401 = OpLoad %PointLight %400
//         %402 = OpCopyLogical %PointLight_0 %401
//                OpStore %pointLight %402
//         %404 = OpAccessChain %_ptr_Function_v3float %pointLight %int_0
//         %405 = OpLoad %v3float %404
//         %406 = OpLoad %v3float %vWorldPosition
//         %407 = OpFSub %v3float %405 %406
//         %408 = OpExtInst %v3float %1 Normalize %407
//                OpStore %L_0 %408
//         %410 = OpLoad %v3float %V_0
//         %411 = OpLoad %v3float %L_0
//         %412 = OpFAdd %v3float %410 %411
//         %413 = OpExtInst %v3float %1 Normalize %412
//                OpStore %H_0 %413
//         %415 = OpAccessChain %_ptr_Function_v3float %pointLight %int_0
//         %416 = OpLoad %v3float %415
//         %417 = OpLoad %v3float %vWorldPosition
//         %418 = OpFSub %v3float %416 %417
//         %419 = OpExtInst %float %1 Length %418
//                OpStore %distance %419
//         %421 = OpLoad %float %distance
//         %422 = OpLoad %float %distance
//         %423 = OpFMul %float %421 %422
//         %424 = OpFDiv %float %float_1 %423
//                OpStore %attenuation %424
//         %427 = OpAccessChain %_ptr_Function_v3float %pointLight %int_2
//         %428 = OpLoad %v3float %427
//         %429 = OpLoad %float %attenuation
//         %430 = OpVectorTimesScalar %v3float %428 %429
//                OpStore %radiance %430
//         %433 = OpLoad %v3float %N_2
//                OpStore %param_8 %433
//         %435 = OpLoad %v3float %H_0
//                OpStore %param_9 %435
//         %437 = OpLoad %float %roughness_3
//                OpStore %param_10 %437
//         %438 = OpFunctionCall %float %DistributionGGX_vf3_vf3_f1_ %param_8 %param_9 %param_10
//                OpStore %NDF %438
//         %441 = OpLoad %v3float %N_2
//                OpStore %param_11 %441
//         %443 = OpLoad %v3float %V_0
//                OpStore %param_12 %443
//         %445 = OpLoad %v3float %L_0
//                OpStore %param_13 %445
//         %447 = OpLoad %float %roughness_3
//                OpStore %param_14 %447
//         %448 = OpFunctionCall %float %GeometrySmithDirect_vf3_vf3_vf3_f1_ %param_11 %param_12 %param_13 %param_14
//                OpStore %G %448
//         %450 = OpLoad %v3float %H_0
//         %451 = OpLoad %v3float %V_0
//         %452 = OpDot %float %450 %451
//         %453 = OpExtInst %float %1 FMax %452 %float_0
//                OpStore %param_15 %453
//         %456 = OpLoad %v3float %F0_1
//                OpStore %param_16 %456
//         %457 = OpFunctionCall %v3float %FresnelSchlick_f1_vf3_ %param_15 %param_16
//                OpStore %F %457
//         %459 = OpLoad %float %NDF
//         %460 = OpLoad %float %G
//         %461 = OpFMul %float %459 %460
//         %462 = OpLoad %v3float %F
//         %463 = OpVectorTimesScalar %v3float %462 %461
//                OpStore %numerator %463
//         %466 = OpLoad %v3float %N_2
//         %467 = OpLoad %v3float %V_0
//         %468 = OpDot %float %466 %467
//         %469 = OpExtInst %float %1 FMax %468 %float_0
//         %470 = OpFMul %float %float_4 %469
//         %471 = OpLoad %v3float %N_2
//         %472 = OpLoad %v3float %L_0
//         %473 = OpDot %float %471 %472
//         %474 = OpExtInst %float %1 FMax %473 %float_0
//         %475 = OpFMul %float %470 %474
//         %477 = OpFAdd %float %475 %float_9_99999975en05
//                OpStore %denominator %477
//         %479 = OpLoad %v3float %numerator
//         %480 = OpLoad %float %denominator
//         %481 = OpCompositeConstruct %v3float %480 %480 %480
//         %482 = OpFDiv %v3float %479 %481
//                OpStore %specular %482
//         %484 = OpLoad %v3float %F
//                OpStore %kS %484
//         %487 = OpLoad %v3float %kS
//         %488 = OpFSub %v3float %486 %487
//                OpStore %kD %488
//         %489 = OpLoad %float %metallic
//         %490 = OpFSub %float %float_1 %489
//         %491 = OpLoad %v3float %kD
//         %492 = OpVectorTimesScalar %v3float %491 %490
//                OpStore %kD %492
//         %494 = OpLoad %v3float %N_2
//         %495 = OpLoad %v3float %L_0
//         %496 = OpDot %float %494 %495
//         %497 = OpExtInst %float %1 FMax %496 %float_0
//                OpStore %NdotL_0 %497
//         %498 = OpLoad %v3float %kD
//         %499 = OpLoad %v3float %albedo
//         %500 = OpFMul %v3float %498 %499
//         %501 = OpCompositeConstruct %v3float %float_3_14159274 %float_3_14159274 %float_3_14159274
//         %502 = OpFDiv %v3float %500 %501
//         %503 = OpLoad %v3float %specular
//         %504 = OpFAdd %v3float %502 %503
//         %505 = OpLoad %v3float %radiance
//         %506 = OpFMul %v3float %504 %505
//         %507 = OpLoad %float %NdotL_0
//         %508 = OpVectorTimesScalar %v3float %506 %507
//         %509 = OpLoad %v3float %Lo
//         %510 = OpFAdd %v3float %509 %508
//                OpStore %Lo %510
//                OpBranch %380
//         %380 = OpLabel
//         %511 = OpLoad %int %i
//         %513 = OpIAdd %int %511 %int_1
//                OpStore %i %513
//                OpBranch %377
//         %379 = OpLabel
//         %515 = OpLoad %v3float %N_2
//         %516 = OpLoad %v3float %V_0
//         %517 = OpDot %float %515 %516
//         %518 = OpExtInst %float %1 FMax %517 %float_0
//                OpStore %param_17 %518
//         %521 = OpLoad %v3float %F0_1
//                OpStore %param_18 %521
//         %523 = OpLoad %float %roughness_3
//                OpStore %param_19 %523
//         %524 = OpFunctionCall %v3float %FresnelSchlickRoughness_f1_vf3_f1_ %param_17 %param_18 %param_19
//                OpStore %F_0 %524
//         %526 = OpLoad %v3float %F_0
//                OpStore %kS_0 %526
//         %528 = OpLoad %v3float %kS_0
//         %529 = OpCompositeConstruct %v3float %float_1 %float_1 %float_1
//         %530 = OpFSub %v3float %529 %528
//                OpStore %kD_0 %530
//         %531 = OpLoad %float %metallic
//         %532 = OpFSub %float %float_1 %531
//         %533 = OpLoad %v3float %kD_0
//         %534 = OpVectorTimesScalar %v3float %533 %532
//                OpStore %kD_0 %534
//         %537 = OpLoad %55 %irradianceMap
//         %539 = OpLoad %v3float %N_2
//                OpStore %param_20 %539
//         %540 = OpFunctionCall %v2float %DirectionToEquirectangularUv_vf3_ %param_20
//         %541 = OpImageSampleImplicitLod %v4float %537 %540
//         %542 = OpVectorShuffle %v3float %541 %541 0 1 2
//                OpStore %irradiance %542
//         %544 = OpLoad %v3float %irradiance
//         %545 = OpLoad %v3float %albedo
//         %546 = OpFMul %v3float %544 %545
//                OpStore %diffuse %546
//         %549 = OpLoad %55 %prefilterMap
//         %551 = OpLoad %v3float %R
//                OpStore %param_21 %551
//         %552 = OpFunctionCall %v2float %DirectionToEquirectangularUv_vf3_ %param_21
//         %553 = OpLoad %float %roughness_3
//         %554 = OpAccessChain %_ptr_PushConstant_uint %__0 %int_2
//         %555 = OpLoad %uint %554
//         %556 = OpISub %uint %555 %uint_1
//         %557 = OpConvertUToF %float %556
//         %558 = OpFMul %float %553 %557
//         %559 = OpImageSampleExplicitLod %v4float %549 %552 Lod %558
//         %560 = OpVectorShuffle %v3float %559 %559 0 1 2
//                OpStore %prefilteredColor %560
//         %563 = OpLoad %55 %brdfLut
//         %564 = OpLoad %v3float %N_2
//         %565 = OpLoad %v3float %V_0
//         %566 = OpDot %float %564 %565
//         %567 = OpExtInst %float %1 FMax %566 %float_0
//         %568 = OpLoad %float %roughness_3
//         %569 = OpCompositeConstruct %v2float %567 %568
//         %570 = OpImageSampleImplicitLod %v4float %563 %569
//         %571 = OpVectorShuffle %v2float %570 %570 0 1
//                OpStore %brdf %571
//         %573 = OpLoad %v3float %prefilteredColor
//         %574 = OpLoad %v3float %F_0
//         %575 = OpAccessChain %_ptr_Function_float %brdf %uint_0
//         %576 = OpLoad %float %575
//         %577 = OpVectorTimesScalar %v3float %574 %576
//         %578 = OpAccessChain %_ptr_Function_float %brdf %uint_1
//         %579 = OpLoad %float %578
//         %580 = OpCompositeConstruct %v3float %579 %579 %579
//         %581 = OpFAdd %v3float %577 %580
//         %582 = OpFMul %v3float %573 %581
//                OpStore %specular_0 %582
//         %584 = OpLoad %v3float %kD_0
//         %585 = OpLoad %v3float %diffuse
//         %586 = OpFMul %v3float %584 %585
//         %587 = OpLoad %v3float %specular_0
//         %588 = OpFAdd %v3float %586 %587
//         %589 = OpLoad %float %ao
//         %590 = OpVectorTimesScalar %v3float %588 %589
//                OpStore %ambient %590
//         %592 = OpLoad %v3float %ambient
//         %593 = OpLoad %v3float %Lo
//         %594 = OpFAdd %v3float %592 %593
//                OpStore %color %594
//         %595 = OpLoad %v3float %color
//         %596 = OpLoad %v3float %color
//         %597 = OpFAdd %v3float %596 %486
//         %598 = OpFDiv %v3float %595 %597
//                OpStore %color %598
//         %601 = OpLoad %v3float %color
//         %602 = OpCompositeExtract %float %601 0
//         %603 = OpCompositeExtract %float %601 1
//         %604 = OpCompositeExtract %float %601 2
//         %605 = OpCompositeConstruct %v4float %602 %603 %604 %float_1
//                OpStore %fragColor %605
//                OpReturn
//                OpFunctionEnd

//                ; Function GetCameraPositionFromViewMatrix_mf44_
// %GetCameraPositionFromViewMatrix_mf44_ = OpFunction %v3float None %11
//        %view = OpFunctionParameter %_ptr_Function_mat4v4float
//          %14 = OpLabel
//          %65 = OpLoad %mat4v4float %view
//          %66 = OpExtInst %mat4v4float %1 MatrixInverse %65
//          %69 = OpCompositeExtract %v4float %66 3
//          %70 = OpVectorShuffle %v3float %69 %69 0 1 2
//                OpReturnValue %70
//                OpFunctionEnd

//                ; Function DistributionGGX_vf3_vf3_f1_
// %DistributionGGX_vf3_vf3_f1_ = OpFunction %float None %17
//           %N = OpFunctionParameter %_ptr_Function_v3float
//           %H = OpFunctionParameter %_ptr_Function_v3float
//   %roughness = OpFunctionParameter %_ptr_Function_float
//          %22 = OpLabel
//           %a = OpVariable %_ptr_Function_float Function
//          %a2 = OpVariable %_ptr_Function_float Function
//       %NdotH = OpVariable %_ptr_Function_float Function
//      %NdotH2 = OpVariable %_ptr_Function_float Function
//         %num = OpVariable %_ptr_Function_float Function
//       %denom = OpVariable %_ptr_Function_float Function
//          %74 = OpLoad %float %roughness
//          %75 = OpLoad %float %roughness
//          %76 = OpFMul %float %74 %75
//                OpStore %a %76
//          %78 = OpLoad %float %a
//          %79 = OpLoad %float %a
//          %80 = OpFMul %float %78 %79
//                OpStore %a2 %80
//          %82 = OpLoad %v3float %N
//          %83 = OpLoad %v3float %H
//          %84 = OpDot %float %82 %83
//          %86 = OpExtInst %float %1 FMax %84 %float_0
//                OpStore %NdotH %86
//          %88 = OpLoad %float %NdotH
//          %89 = OpLoad %float %NdotH
//          %90 = OpFMul %float %88 %89
//                OpStore %NdotH2 %90
//          %92 = OpLoad %float %a2
//                OpStore %num %92
//          %94 = OpLoad %float %NdotH2
//          %95 = OpLoad %float %a2
//          %97 = OpFSub %float %95 %float_1
//          %98 = OpFMul %float %94 %97
//          %99 = OpFAdd %float %98 %float_1
//                OpStore %denom %99
//         %101 = OpLoad %float %denom
//         %102 = OpFMul %float %float_3_14159274 %101
//         %103 = OpLoad %float %denom
//         %104 = OpFMul %float %102 %103
//                OpStore %denom %104
//         %105 = OpLoad %float %num
//         %106 = OpLoad %float %denom
//         %107 = OpFDiv %float %105 %106
//                OpReturnValue %107
//                OpFunctionEnd

//                ; Function GeometrySchlickGGXDirect_f1_f1_
// %GeometrySchlickGGXDirect_f1_f1_ = OpFunction %float None %23
//       %NdotV = OpFunctionParameter %_ptr_Function_float
// %roughness_0 = OpFunctionParameter %_ptr_Function_float
//          %27 = OpLabel
//           %r = OpVariable %_ptr_Function_float Function
//           %k = OpVariable %_ptr_Function_float Function
//       %num_0 = OpVariable %_ptr_Function_float Function
//     %denom_0 = OpVariable %_ptr_Function_float Function
//         %111 = OpLoad %float %roughness_0
//         %112 = OpFAdd %float %111 %float_1
//                OpStore %r %112
//         %114 = OpLoad %float %r
//         %115 = OpLoad %float %r
//         %116 = OpFMul %float %114 %115
//         %118 = OpFDiv %float %116 %float_8
//                OpStore %k %118
//         %120 = OpLoad %float %NdotV
//                OpStore %num_0 %120
//         %122 = OpLoad %float %NdotV
//         %123 = OpLoad %float %k
//         %124 = OpFSub %float %float_1 %123
//         %125 = OpFMul %float %122 %124
//         %126 = OpLoad %float %k
//         %127 = OpFAdd %float %125 %126
//                OpStore %denom_0 %127
//         %128 = OpLoad %float %num_0
//         %129 = OpLoad %float %denom_0
//         %130 = OpFDiv %float %128 %129
//                OpReturnValue %130
//                OpFunctionEnd

//                ; Function GeometrySmithDirect_vf3_vf3_vf3_f1_
// %GeometrySmithDirect_vf3_vf3_vf3_f1_ = OpFunction %float None %28
//         %N_0 = OpFunctionParameter %_ptr_Function_v3float
//           %V = OpFunctionParameter %_ptr_Function_v3float
//           %L = OpFunctionParameter %_ptr_Function_v3float
// %roughness_1 = OpFunctionParameter %_ptr_Function_float
//          %34 = OpLabel
//     %NdotV_0 = OpVariable %_ptr_Function_float Function
//       %NdotL = OpVariable %_ptr_Function_float Function
//        %ggx2 = OpVariable %_ptr_Function_float Function
//       %param = OpVariable %_ptr_Function_float Function
//     %param_0 = OpVariable %_ptr_Function_float Function
//        %ggx1 = OpVariable %_ptr_Function_float Function
//     %param_1 = OpVariable %_ptr_Function_float Function
//     %param_2 = OpVariable %_ptr_Function_float Function
//         %134 = OpLoad %v3float %N_0
//         %135 = OpLoad %v3float %V
//         %136 = OpDot %float %134 %135
//         %137 = OpExtInst %float %1 FMax %136 %float_0
//                OpStore %NdotV_0 %137
//         %139 = OpLoad %v3float %N_0
//         %140 = OpLoad %v3float %L
//         %141 = OpDot %float %139 %140
//         %142 = OpExtInst %float %1 FMax %141 %float_0
//                OpStore %NdotL %142
//         %145 = OpLoad %float %NdotV_0
//                OpStore %param %145
//         %147 = OpLoad %float %roughness_1
//                OpStore %param_0 %147
//         %148 = OpFunctionCall %float %GeometrySchlickGGXDirect_f1_f1_ %param %param_0
//                OpStore %ggx2 %148
//         %151 = OpLoad %float %NdotL
//                OpStore %param_1 %151
//         %153 = OpLoad %float %roughness_1
//                OpStore %param_2 %153
//         %154 = OpFunctionCall %float %GeometrySchlickGGXDirect_f1_f1_ %param_1 %param_2
//                OpStore %ggx1 %154
//         %155 = OpLoad %float %ggx1
//         %156 = OpLoad %float %ggx2
//         %157 = OpFMul %float %155 %156
//                OpReturnValue %157
//                OpFunctionEnd

//                ; Function FresnelSchlick_f1_vf3_
// %FresnelSchlick_f1_vf3_ = OpFunction %v3float None %35
//    %cosTheta = OpFunctionParameter %_ptr_Function_float
//          %F0 = OpFunctionParameter %_ptr_Function_v3float
//          %39 = OpLabel
//         %160 = OpLoad %v3float %F0
//         %161 = OpLoad %v3float %F0
//         %162 = OpCompositeConstruct %v3float %float_1 %float_1 %float_1
//         %163 = OpFSub %v3float %162 %161
//         %164 = OpLoad %float %cosTheta
//         %165 = OpFSub %float %float_1 %164
//         %166 = OpExtInst %float %1 FClamp %165 %float_0 %float_1
//         %168 = OpExtInst %float %1 Pow %166 %float_5
//         %169 = OpVectorTimesScalar %v3float %163 %168
//         %170 = OpFAdd %v3float %160 %169
//                OpReturnValue %170
//                OpFunctionEnd

//                ; Function FresnelSchlickRoughness_f1_vf3_f1_
// %FresnelSchlickRoughness_f1_vf3_f1_ = OpFunction %v3float None %40
//  %cosTheta_0 = OpFunctionParameter %_ptr_Function_float
//        %F0_0 = OpFunctionParameter %_ptr_Function_v3float
// %roughness_2 = OpFunctionParameter %_ptr_Function_float
//          %45 = OpLabel
//         %173 = OpLoad %v3float %F0_0
//         %174 = OpLoad %float %roughness_2
//         %175 = OpFSub %float %float_1 %174
//         %176 = OpCompositeConstruct %v3float %175 %175 %175
//         %177 = OpLoad %v3float %F0_0
//         %178 = OpExtInst %v3float %1 FMax %176 %177
//         %179 = OpLoad %v3float %F0_0
//         %180 = OpFSub %v3float %178 %179
//         %181 = OpLoad %float %cosTheta_0
//         %182 = OpFSub %float %float_1 %181
//         %183 = OpExtInst %float %1 FClamp %182 %float_0 %float_1
//         %184 = OpExtInst %float %1 Pow %183 %float_5
//         %185 = OpVectorTimesScalar %v3float %180 %184
//         %186 = OpFAdd %v3float %173 %185
//                OpReturnValue %186
//                OpFunctionEnd

//                ; Function SampleSphericalMap_vf3_
// %SampleSphericalMap_vf3_ = OpFunction %v2float None %47
//           %v = OpFunctionParameter %_ptr_Function_v3float
//          %50 = OpLabel
//     %invAtan = OpVariable %_ptr_Function_v2float Function
//        %uv_0 = OpVariable %_ptr_Function_v2float Function
//         %189 = OpLoad %v3float %v
//         %190 = OpExtInst %v3float %1 Normalize %189
//                OpStore %v %190
//                OpStore %invAtan %194
//         %198 = OpAccessChain %_ptr_Function_float %v %uint_2
//         %199 = OpLoad %float %198
//         %201 = OpAccessChain %_ptr_Function_float %v %uint_0
//         %202 = OpLoad %float %201
//         %203 = OpExtInst %float %1 Atan2 %199 %202
//         %205 = OpAccessChain %_ptr_Function_float %v %uint_1
//         %206 = OpLoad %float %205
//         %207 = OpExtInst %float %1 Asin %206
//         %208 = OpCompositeConstruct %v2float %203 %207
//                OpStore %uv_0 %208
//         %209 = OpLoad %v2float %invAtan
//         %210 = OpLoad %v2float %uv_0
//         %211 = OpFMul %v2float %210 %209
//                OpStore %uv_0 %211
//         %213 = OpLoad %v2float %uv_0
//         %214 = OpCompositeConstruct %v2float %float_0_5 %float_0_5
//         %215 = OpFAdd %v2float %213 %214
//                OpStore %uv_0 %215
//         %216 = OpLoad %v2float %uv_0
//                OpReturnValue %216
//                OpFunctionEnd

//                ; Function DirectionToEquirectangularUv_vf3_
// %DirectionToEquirectangularUv_vf3_ = OpFunction %v2float None %47
//   %direction = OpFunctionParameter %_ptr_Function_v3float
//          %53 = OpLabel
//     %param_3 = OpVariable %_ptr_Function_v3float Function
//         %220 = OpLoad %v3float %direction
//                OpStore %param_3 %220
//         %221 = OpFunctionCall %v2float %SampleSphericalMap_vf3_ %param_3
//                OpReturnValue %221
//                OpFunctionEnd

//                ; Function GetNormalFromMap_s21_vf2_vf3_vf3_
// %GetNormalFromMap_s21_vf2_vf3_vf3_ = OpFunction %v3float None %58
//   %normalMap = OpFunctionParameter %_ptr_UniformConstant_55
//          %uv = OpFunctionParameter %_ptr_Function_v2float
// %worldPosition = OpFunctionParameter %_ptr_Function_v3float
// %vertexNormal = OpFunctionParameter %_ptr_Function_v3float
//          %64 = OpLabel
// %tangentNormal = OpVariable %_ptr_Function_v3float Function
//          %Q1 = OpVariable %_ptr_Function_v3float Function
//          %Q2 = OpVariable %_ptr_Function_v3float Function
//         %st1 = OpVariable %_ptr_Function_v2float Function
//         %st2 = OpVariable %_ptr_Function_v2float Function
//         %N_1 = OpVariable %_ptr_Function_v3float Function
//           %T = OpVariable %_ptr_Function_v3float Function
//           %B = OpVariable %_ptr_Function_v3float Function
//         %TBN = OpVariable %_ptr_Function_mat3v3float Function
//         %225 = OpLoad %55 %normalMap
//         %226 = OpLoad %v2float %uv
//         %227 = OpImageSampleImplicitLod %v4float %225 %226
//         %228 = OpVectorShuffle %v3float %227 %227 0 1 2
//         %230 = OpVectorTimesScalar %v3float %228 %float_2
//         %231 = OpCompositeConstruct %v3float %float_1 %float_1 %float_1
//         %232 = OpFSub %v3float %230 %231
//                OpStore %tangentNormal %232
//         %234 = OpLoad %v3float %worldPosition
//         %235 = OpDPdx %v3float %234
//                OpStore %Q1 %235
//         %237 = OpLoad %v3float %worldPosition
//         %238 = OpDPdy %v3float %237
//                OpStore %Q2 %238
//         %240 = OpLoad %v2float %uv
//         %241 = OpDPdx %v2float %240
//                OpStore %st1 %241
//         %243 = OpLoad %v2float %uv
//         %244 = OpDPdy %v2float %243
//                OpStore %st2 %244
//         %246 = OpLoad %v3float %vertexNormal
//         %247 = OpExtInst %v3float %1 Normalize %246
//                OpStore %N_1 %247
//         %249 = OpLoad %v3float %Q1
//         %250 = OpAccessChain %_ptr_Function_float %st2 %uint_1
//         %251 = OpLoad %float %250
//         %252 = OpVectorTimesScalar %v3float %249 %251
//         %253 = OpLoad %v3float %Q2
//         %254 = OpAccessChain %_ptr_Function_float %st1 %uint_1
//         %255 = OpLoad %float %254
//         %256 = OpVectorTimesScalar %v3float %253 %255
//         %257 = OpFSub %v3float %252 %256
//         %258 = OpExtInst %v3float %1 Normalize %257
//                OpStore %T %258
//         %260 = OpLoad %v3float %N_1
//         %261 = OpLoad %v3float %T
//         %262 = OpExtInst %v3float %1 Cross %260 %261
//         %263 = OpExtInst %v3float %1 Normalize %262
//         %264 = OpFNegate %v3float %263
//                OpStore %B %264
//         %268 = OpLoad %v3float %T
//         %269 = OpLoad %v3float %B
//         %270 = OpLoad %v3float %N_1
//         %271 = OpCompositeExtract %float %268 0
//         %272 = OpCompositeExtract %float %268 1
//         %273 = OpCompositeExtract %float %268 2
//         %274 = OpCompositeExtract %float %269 0
//         %275 = OpCompositeExtract %float %269 1
//         %276 = OpCompositeExtract %float %269 2
//         %277 = OpCompositeExtract %float %270 0
//         %278 = OpCompositeExtract %float %270 1
//         %279 = OpCompositeExtract %float %270 2
//         %280 = OpCompositeConstruct %v3float %271 %272 %273
//         %281 = OpCompositeConstruct %v3float %274 %275 %276
//         %282 = OpCompositeConstruct %v3float %277 %278 %279
//         %283 = OpCompositeConstruct %mat3v3float %280 %281 %282
//                OpStore %TBN %283
//         %284 = OpLoad %mat3v3float %TBN
//         %285 = OpLoad %v3float %tangentNormal
//         %286 = OpMatrixTimesVector %v3float %284 %285
//         %287 = OpExtInst %v3float %1 Normalize %286
//                OpReturnValue %287
//                OpFunctionEnd
