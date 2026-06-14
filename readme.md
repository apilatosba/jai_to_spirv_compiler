This compiler is not ready to use for anything. Dont use it.

## Example Shader Program

Outputs a single fullscreen quad and displays an image
```jai
#import "ApilaSpirv";

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
```

spirv sucks. storage classes are as bad as image layouts.