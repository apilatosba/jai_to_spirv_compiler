//
// compile with from the current directory:
//    jai compile_examples.jai -import_dir "../modules"
//

#import,file "../ApilaSpirv.jai";

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

MeshShader :: (mOutVertex: [] MeshOutVertex, mOutPrimitive: [] MeshOutPrimitive, data: *MeshData) {
   SetMeshOutputs(4, 2);

   meshvertices[0].position = .{ -1, -1, 0.5, 1 };
   meshvertices[1].position = .{  1, -1, 0.5, 1 };
   meshvertices[2].position = .{  1,  1, 0.5, 1 };
   meshvertices[3].position = .{ -1,  1, 0.5, 1 };

   mOutVertex[0].uv = .{ 0, 0 + data.offset };
   mOutVertex[1].uv = .{ 1, 0 + data.offset };
   mOutVertex[2].uv = .{ 1, 1 + data.offset };
   mOutVertex[3].uv = .{ 0, 1 + data.offset };

   meshtriangles[0] = .{ 0, 1, 2 };
   meshtriangles[1] = .{ 0, 2, 3 };
} @mesh @1_1_1 @4_2 @triangles

FragmentShader :: (mOutVertex: MeshOutVertex, mOutPrimitive: MeshOutPrimitive, data: *FragmentData) -> f32x4 {
   return texture(images[data.imageIndex], samplers[data.samplerIndex], mOutVertex.uv);
} @fragment

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
