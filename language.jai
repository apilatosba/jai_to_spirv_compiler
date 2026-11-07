//
// the shader language: the types, the builtin variables and the intrinsics. this is what a shader (and the cpu code that shares its structs) imports.
// it doesnt depend on the compiler, the compiler (compiler.jai) is only loaded when the module is imported with METAPROGRAM = true.
//

#import "Basic";
#import "Math";
#import "String";
#import "SpirvHeaders"; // only enums, the tables below use them

//
// swizzling:
// i want to define the instrinsic vectors like this:
//    s32x4 :: [4] s32;
//
// if i do that i can only use indices, i cant use xyzw. or any other character.
// i want my spirv compiler to work without a need of metaprogram. so i cant support any swizzle operation, simply becasue jai doesnt have support for them.
// i proposed a syntax suggestion on discord regarding the swizzle #swizzle but i think it didnt catch attention of jblow. but i do want to support swizzling because a shading langauge without swizzling is no good.
// so i think my next project is to write a metaprogram that implements swizzling. this is what i have in mind right now (it is different than what ive proposed on discord):
//    s32x4 :: [4] s32; @"swizzle(xr, yg, zb, wa)"
//
// for this i need to first traverse all the declarations and check to see if they have @swizzle, if they have i need to add them into a table. and when traversing the syntax tree when i see an identifier of a swizzled type
// im gonna decipher it into something that the jai compiler understands.
// i need to first trverse through all the declarations to figure out if an identifier is swizzled. because if i dont do it and traverse the syntax tree directly then i cant get the notes (the swizzle data) from just the type itself.
// i think jblow can make it so that there is a function that returns the *Code_Node from given Type or *Type_Info during compilation.
//
//                   - apila, 07/05/26
//

//
// there is a weird thing that if you using struct literals without typing its type front (before the dot)
// then some fields of Code_Node inside the struct literal expression is null. weird.
//       - apila, 14/05/26
//

//
// new vector type stuff:
// im thinking to have this:
//    f32x2 :: #type,distinct [2] f32;
// #type,distinct because in spirv OpTypeArray and OpTypeVector exist.
// i thought maybe doing "[2] f32 @vector" but then the jai type checking wont help me and i have to do vector vs array distinction in DetermineCodeNodeTypes(), which i dont want to do.
// the reason im doing this is beacuse i want to have proper vector types rather than hard coding every vector type like i do know.
// but i think i cant get proper vector types if i use #type,distinct. i still have to compare one by one. i think what im gonna do is im gonna add one more flag to Type_Info_Array.Array_Type: .VECTOR.
// then i need to update the code node types in DetermineCodeNodeTypes(). if i have something like that then i can just check "tia.array_flags" to see if it is a vector or not.
// i think i can apply the same idea to matrix types which uses #type,distinct as of yet. they should be something like:
//    f32x2x2 :: [2] f32x2 @matrix;
// without @matrix it would mean an array of f32x2 (an OpTypeArray of f32x2). @matrix requires that the element type must be a vector type which i can check during compilation.
// this would mean that a new entry to Type_Info_Array.Array_Type: .MATRIX;
// but i dont think this is gonna work out because if i declare a variable of, lets say, a vector type, lets say, f32x3 then since jai compiler thinks that it is just [3] f32, i will basically
// cannot make use of this type because jai will report the type as [3] float. holy shit i just realized you cant add notes to constant declarations. crazy.
// anyways then it doesnt matter wheter you keep the structs or you just turn them into #type,distinct arrays. either way you have to compare types one by one.
//             - apila, 16/09/26
//

// vvvvvv intrinsics vvvvvvvv
// bool :: bool;
bool2 :: struct { x: bool; y: bool; };
bool3 :: struct { x: bool; y: bool; z: bool; };
bool4 :: struct { x: bool; y: bool; z: bool; w: bool; };

u8x2 :: struct { x: u8; y: u8; };
u8x3 :: struct { x: u8; y: u8; z: u8; };
u8x4 :: struct { x: u8; y: u8; z: u8; w: u8; };

s8x2 :: struct { x: s8; y: s8; };
s8x3 :: struct { x: s8; y: s8; z: s8; };
s8x4 :: struct { x: s8; y: s8; z: s8; w: s8; };

s16x2 :: struct { x: s16; y: s16; };
s16x3 :: struct { x: s16; y: s16; z: s16; };
s16x4 :: struct { x: s16; y: s16; z: s16; w: s16; };

u16x2 :: struct { x: u16; y: u16; };
u16x3 :: struct { x: u16; y: u16; z: u16; };
u16x4 :: struct { x: u16; y: u16; z: u16; w: u16; };

s32x2 :: struct { x: s32; y: s32; };
s32x3 :: struct { x: s32; y: s32; z: s32; };
s32x4 :: struct { x: s32; y: s32; z: s32; w: s32; };

u32x2 :: struct { x: u32; y: u32; };
u32x3 :: struct { x: u32; y: u32; z: u32; };
u32x4 :: struct { x: u32; y: u32; z: u32; w: u32; };

s64x2 :: struct { x: s64; y: s64; };
s64x3 :: struct { x: s64; y: s64; z: s64; };
s64x4 :: struct { x: s64; y: s64; z: s64; w: s64; };

u64x2 :: struct { x: u64; y: u64; };
u64x3 :: struct { x: u64; y: u64; z: u64; };
u64x4 :: struct { x: u64; y: u64; z: u64; w: u64; };

f32   :: float;
f32x2 :: struct { x: f32; y: f32; };
f32x3 :: struct { x: f32; y: f32; z: f32; };
f32x4 :: struct { x: f32; y: f32; z: f32; w: f32; };

f64   :: float64;
f64x2 :: struct { x: f64; y: f64; };
f64x3 :: struct { x: f64; y: f64; z: f64; };
f64x4 :: struct { x: f64; y: f64; z: f64; w: f64; };

// if you define matrix types like these then you cant define operators on them.
// yikes. so two options here:
//    - define a function for the matrix operations.
//    - declare them as struct.
// declaring them as struct requires me to modify some other stuff so that indexing works.
// i guess im gonna go with the function approach
//          - apila, 14/05/26
f32x2x2 :: #type,distinct [2] f32x2;
f32x3x3 :: #type,distinct [3] f32x3;
f32x4x4 :: #type,distinct [4] f32x4;
f32x3x4 :: #type,distinct [4] f32x3; // 4 columns, 3 rows (column major). the type of objecttoworld and worldtoobject

mat2 :: f32x2x2;
mat3 :: f32x3x3;
mat4 :: f32x4x4;

MeshPerVertex :: struct {
   position:   f32x4;
   pointSize:  f32;
}

// the builtins a mesh shader writes for each primitive (gl_MeshPrimitivesEXT). a fragment shader reads primitiveId as primitiveid
MeshPerPrimitive :: struct {
   primitiveId:    s32;
   layer:          s32;
   viewportIndex:  s32;
   cullPrimitive:  bool;
}

// the bodies are the cpu implementations (see cpu.jai), the backend doesnt look at them
operator *  :: (m: mat4, v: f32x4)  -> f32x4 { return mul(m, v); };
operator *  :: (m: mat3, v: f32x3)  -> f32x3 { return mul(m, v); };
operator *  :: (m: f32x3x4, v: f32x4) -> f32x3 { return m[0] * v.x + m[1] * v.y + m[2] * v.z + m[3] * v.w; };
operator *  :: (a: mat4, b: mat4)   -> mat4  { return mul(a, b); }; // this is not valid jai operation unfortunately :(  - apila, 14/05/26

// arithmetic on vectors. jai typechecks the shader with these, the backend generates the instructions from the operator node itself. their bodies are the cpu implementations (see cpu.jai).
// a scalar operand is broadcast to a vector (vector + scalar is vector + .{ scalar, scalar, ... }), see DoBinaryArithmetic.
#insert #run -> string {
   builder: String_Builder;

   Vector :: struct { name: string; scalar: string; isInt: bool; isSigned: bool; }
   VECTORS :: Vector.[
      .{ "u8x2",  "u8",  true,  false }, .{ "u8x3",  "u8",  true,  false }, .{ "u8x4",  "u8",  true,  false },
      .{ "s8x2",  "s8",  true,  true  }, .{ "s8x3",  "s8",  true,  true  }, .{ "s8x4",  "s8",  true,  true  },
      .{ "s16x2", "s16", true,  true  }, .{ "s16x3", "s16", true,  true  }, .{ "s16x4", "s16", true,  true  },
      .{ "u16x2", "u16", true,  false }, .{ "u16x3", "u16", true,  false }, .{ "u16x4", "u16", true,  false },
      .{ "s32x2", "s32", true,  true  }, .{ "s32x3", "s32", true,  true  }, .{ "s32x4", "s32", true,  true  },
      .{ "u32x2", "u32", true,  false }, .{ "u32x3", "u32", true,  false }, .{ "u32x4", "u32", true,  false },
      .{ "s64x2", "s64", true,  true  }, .{ "s64x3", "s64", true,  true  }, .{ "s64x4", "s64", true,  true  },
      .{ "u64x2", "u64", true,  false }, .{ "u64x3", "u64", true,  false }, .{ "u64x4", "u64", true,  false },
      .{ "f32x2", "f32", false, true  }, .{ "f32x3", "f32", false, true  }, .{ "f32x4", "f32", false, true  },
      .{ "f64x2", "f64", false, true  }, .{ "f64x3", "f64", false, true  }, .{ "f64x4", "f64", false, true  },
   ];

   for v: VECTORS {
      INT_OPERATORS   :: string.["+", "-", "*", "/", "%", "&", "|", "^"];
      FLOAT_OPERATORS :: string.["+", "-", "*", "/", "%"];
      operators: [] string = FLOAT_OPERATORS;
      if (v.isInt) operators = INT_OPERATORS;
      for op: operators {
         print_to_builder(*builder, "operator % :: (a: %, b: %) -> % { % }\n", op, v.name, v.name,   v.name, VectorOperatorBody(op, v.name, true,  true));
         print_to_builder(*builder, "operator % :: (a: %, b: %) -> % { % }\n", op, v.name, v.scalar, v.name, VectorOperatorBody(op, v.name, true,  false));
         print_to_builder(*builder, "operator % :: (a: %, b: %) -> % { % }\n", op, v.scalar, v.name, v.name, VectorOperatorBody(op, v.name, false, true));
      }

      if (v.isSigned) print_to_builder(*builder, "operator - :: (a: %) -> % { % }\n", v.name, v.name, VectorNegateBody(v.name));
   }

   return builder_to_string(*builder);
};

#insert #run sprint("%: [] MeshPerVertex; @%", MESH_VERTICES_NAME, INTRINSIC_NOTE_NAME); // gl_MeshVerticesEXT
#insert #run sprint("%: [] MeshPerPrimitive; @%", MESH_PRIMITIVES_NAME, INTRINSIC_NOTE_NAME); // gl_MeshPrimitivesEXT
// the indices of the primitives a mesh shader outputs. the one of the topology of the shader is used (@points, @lines, @triangles)
MeshPrimitiveIndices :: struct {
   topology:   PrimitiveTopology;
   name:       string;
   typeName:   string;
   builtIn:    SpvBuiltIn;
}

MESH_PRIMITIVE_INDICES :: MeshPrimitiveIndices.[
   .{ .Points,    "meshpoints",     "s32",   .PrimitivePointIndicesEXT    }, // gl_PrimitivePointIndicesEXT
   .{ .Lines,     "meshlines",      "s32x2", .PrimitiveLineIndicesEXT     }, // gl_PrimitiveLineIndicesEXT
   .{ .Triangles, MESH_TRIANGLES_NAME, "s32x3", .PrimitiveTriangleIndicesEXT }, // gl_PrimitiveTriangleIndicesEXT
];

#insert #run -> string {
   builder: String_Builder;
   for MESH_PRIMITIVE_INDICES  print_to_builder(*builder, "%: [] %; @%\n", it.name, it.typeName, INTRINSIC_NOTE_NAME);
   return builder_to_string(*builder);
};
#insert #run sprint("%: [] __Image__; @%", IMAGE_HEAP_VARIABLE_NAME, INTRINSIC_NOTE_NAME);
#insert #run sprint("%: [] __Sampler__; @%", SAMPLER_HEAP_VARIABLE_NAME, INTRINSIC_NOTE_NAME);

#insert #run sprint("% :: (vertexCount: u32, primitiveCount: u32) {} @%", SET_MESH_OUTPUTS_NAME, INTRINSIC_NOTE_NAME); // SetMeshOutputsEXT

// OpEmitMeshTasksEXT. ends the invocation, nothing after it runs. every invocation of a task shader has to reach it, in uniform control flow. it is undefined behaviour if one doesnt.
// the group counts are taken from the first invocation of the workgroup. payload is the address of the @taskpayload variable, the mesh shader reads it from its own @taskpayload variable
#insert #run sprint("% :: (groupCountX: u32, groupCountY: u32, groupCountZ: u32) { } @%", EMIT_MESH_TASKS_NAME, INTRINSIC_NOTE_NAME);
#insert #run sprint("% :: (groupCountX: u32, groupCountY: u32, groupCountZ: u32, payload: *$T) { } @%", EMIT_MESH_TASKS_NAME, INTRINSIC_NOTE_NAME);

// maybe rayFlags should be an enum. tho i never dealt with enums so im skipping it for now.
// payload is the address of the payload variable.
//          - apila, 07/09/26
//
// rayFlags is an enum now, RayFlags.
//
// tlas is the device address of the tlas, see GenerateTlasFromAddress.
#insert #run sprint("% :: (tlas: u64, rayFlags: RayFlags, cullMask: u32, sbtOffset: u32, sbtStride: u32, missIndex: u32, rayOrigin: f32x3, rayTMin: f32, rayDirection: f32x3, rayTMax: f32, payload: *$T) { } @%", TRACE_RAY_FUNCTION_NAME, INTRINSIC_NOTE_NAME);

// the resources a function can take, see RESOURCE_FUNCTIONS
HeapResource :: enum u8 {
   Image;
   Sampler;
}

ResourceFunction :: struct {
   name:          string;
   resources:     [] HeapResource; // the first parameters
   parameters:    string;          // the parameters after the resources
   returnType:    string;          // empty if the function doesnt return anything
   kind:          ImageKind;       // the image the function uses (its OpTypeImage), see GenerateTextureFunction
   operation:     ImageOperation;  // what the function does
}

ImageKind :: enum u8 {
   _2D;
   _3D;
   Cube;
   Array;   // 2D array. the coordinate is the uv and the layer
}

ImageOperation :: enum u8 {
   Sample;        // the lod is implicit, only in fragment shaders
   SampleLod;
   SampleBias;    // the lod is implicit, only in fragment shaders
   SampleGrad;
   Gather;
   Compare;       // depth compare. the lod is implicit, only in fragment shaders
   CompareLod;
   Fetch;         // a texel of a sampled image (no sampler)
   Size;
   Levels;
   Read;          // storage images
   StorageSize;
   Write;         // ImageWrite. it is not generated by GenerateTextureFunction
}

//
// the functions that take images or samplers. each one is declared twice:
//    the intrinsic, it takes the resources:            texture :: (image: __Image__, sampler: __Sampler__, uv: f32x2) -> f32x4
//    a macro that takes their indices in the heaps:    texture :: (imageIndex: u32, samplerIndex: u32, uv: f32x2) -> f32x4 #expand { return texture(images[imageIndex], samplers[samplerIndex], uv); }
// it is a macro so the heap accesses are the arguments of the intrinsic (the type of an image is decided by how it is used, see accessChainBaseArrayElementTypeIfImageHeap).
// the indices are u32 like spirv wants them, a signed index has to be cast.
//
RESOURCE_FUNCTIONS :: ResourceFunction.[
   // each texture variant corresponds to sampling of one single OpTypeImage. the component of gather must be a constant.
   .{ TEXTURE_FLOAT_2D_FUNCTION_NAME,     .[.Image, .Sampler], "uv: f32x2",                           "f32x4", ._2D, .Sample },
   .{ TEXTURE_FLOAT_2D_LOD_FUNCTION_NAME, .[.Image, .Sampler], "uv: f32x2, lod: f32",                 "f32x4", ._2D, .SampleLod },
   .{ TEXTURE_INT_2D_FUNCTION_NAME,       .[.Image, .Sampler], "uv: f32x2",                           "s32x4", ._2D, .Sample },
   .{ TEXTURE_BIAS_FUNCTION_NAME,         .[.Image, .Sampler], "uv: f32x2, bias: f32",                "f32x4", ._2D, .SampleBias },
   .{ TEXTURE_GRAD_FUNCTION_NAME,         .[.Image, .Sampler], "uv: f32x2, ddx: f32x2, ddy: f32x2",   "f32x4", ._2D, .SampleGrad },
   .{ TEXTURE_GATHER_FUNCTION_NAME,       .[.Image, .Sampler], "uv: f32x2, component: s32",           "f32x4", ._2D, .Gather },
   .{ TEXTURE_CMP_FUNCTION_NAME,          .[.Image, .Sampler], "uv: f32x2, reference: f32",           "f32",   ._2D, .Compare },
   .{ TEXTURE_CMP_LOD_FUNCTION_NAME,      .[.Image, .Sampler], "uv: f32x2, reference: f32, lod: f32", "f32",   ._2D, .CompareLod },

   // sampled images without a sampler
   .{ TEXEL_FETCH_FUNCTION_NAME,          .[.Image], "coordinate: s32x2, lod: s32",     "f32x4", ._2D, .Fetch },
   .{ TEXEL_FETCH_INT_FUNCTION_NAME,      .[.Image], "coordinate: s32x2, lod: s32",     "s32x4", ._2D, .Fetch },
   .{ TEXTURE_SIZE_FUNCTION_NAME,         .[.Image], "lod: s32",                        "s32x2", ._2D, .Size },
   .{ TEXTURE_LEVELS_FUNCTION_NAME,       .[.Image], "",                                "s32",   ._2D, .Levels },

   // 3D: the name of the 2D function + 3d
   .{ TEXTURE_FLOAT_3D_FUNCTION_NAME,     .[.Image, .Sampler], "uvw: f32x3",                          "f32x4", ._3D, .Sample },
   .{ TEXTURE_LOD_3D_FUNCTION_NAME,       .[.Image, .Sampler], "uvw: f32x3, lod: f32",                "f32x4", ._3D, .SampleLod },
   .{ TEXTURE_BIAS_3D_FUNCTION_NAME,      .[.Image, .Sampler], "uvw: f32x3, bias: f32",               "f32x4", ._3D, .SampleBias },
   .{ TEXTURE_GRAD_3D_FUNCTION_NAME,      .[.Image, .Sampler], "uvw: f32x3, ddx: f32x3, ddy: f32x3",  "f32x4", ._3D, .SampleGrad },
   .{ TEXEL_FETCH_3D_FUNCTION_NAME,       .[.Image], "coordinate: s32x3, lod: s32",                   "f32x4", ._3D, .Fetch },
   .{ TEXTURE_SIZE_3D_FUNCTION_NAME,      .[.Image], "lod: s32",                                      "s32x3", ._3D, .Size },
   .{ TEXTURE_LEVELS_3D_FUNCTION_NAME,    .[.Image], "",                                              "s32",   ._3D, .Levels },

   // cube: the name of the 2D function + cube
   .{ TEXTURE_CUBE_FUNCTION_NAME,         .[.Image, .Sampler], "direction: f32x3",                           "f32x4", .Cube, .Sample },
   .{ TEXTURE_LOD_CUBE_FUNCTION_NAME,     .[.Image, .Sampler], "direction: f32x3, lod: f32",                 "f32x4", .Cube, .SampleLod },
   .{ TEXTURE_BIAS_CUBE_FUNCTION_NAME,    .[.Image, .Sampler], "direction: f32x3, bias: f32",                "f32x4", .Cube, .SampleBias },
   .{ TEXTURE_GRAD_CUBE_FUNCTION_NAME,    .[.Image, .Sampler], "direction: f32x3, ddx: f32x3, ddy: f32x3",   "f32x4", .Cube, .SampleGrad },
   .{ TEXTURE_GATHER_CUBE_FUNCTION_NAME,  .[.Image, .Sampler], "direction: f32x3, component: s32",           "f32x4", .Cube, .Gather },
   .{ TEXTURE_CMP_CUBE_FUNCTION_NAME,     .[.Image, .Sampler], "direction: f32x3, reference: f32",           "f32",   .Cube, .Compare },
   .{ TEXTURE_CMP_LOD_CUBE_FUNCTION_NAME, .[.Image, .Sampler], "direction: f32x3, reference: f32, lod: f32", "f32",   .Cube, .CompareLod },
   .{ TEXTURE_SIZE_CUBE_FUNCTION_NAME,    .[.Image], "lod: s32",                                             "s32x2", .Cube, .Size },
   .{ TEXTURE_LEVELS_CUBE_FUNCTION_NAME,  .[.Image], "",                                                     "s32",   .Cube, .Levels },

   // 2D array: the name of the 2D function + array. the layer is after the uv
   .{ TEXTURE_ARRAY_FUNCTION_NAME,          .[.Image, .Sampler], "uv: f32x2, layer: f32",                           "f32x4", .Array, .Sample },
   .{ TEXTURE_LOD_ARRAY_FUNCTION_NAME,      .[.Image, .Sampler], "uv: f32x2, layer: f32, lod: f32",                 "f32x4", .Array, .SampleLod },
   .{ TEXTURE_BIAS_ARRAY_FUNCTION_NAME,     .[.Image, .Sampler], "uv: f32x2, layer: f32, bias: f32",                "f32x4", .Array, .SampleBias },
   .{ TEXTURE_GRAD_ARRAY_FUNCTION_NAME,     .[.Image, .Sampler], "uv: f32x2, layer: f32, ddx: f32x2, ddy: f32x2",   "f32x4", .Array, .SampleGrad },
   .{ TEXTURE_GATHER_ARRAY_FUNCTION_NAME,   .[.Image, .Sampler], "uv: f32x2, layer: f32, component: s32",           "f32x4", .Array, .Gather },
   .{ TEXTURE_CMP_ARRAY_FUNCTION_NAME,      .[.Image, .Sampler], "uv: f32x2, layer: f32, reference: f32",           "f32",   .Array, .Compare },
   .{ TEXTURE_CMP_LOD_ARRAY_FUNCTION_NAME,  .[.Image, .Sampler], "uv: f32x2, layer: f32, reference: f32, lod: f32", "f32",   .Array, .CompareLod },
   .{ TEXEL_FETCH_ARRAY_FUNCTION_NAME,      .[.Image], "coordinate: s32x2, layer: s32, lod: s32",                   "f32x4", .Array, .Fetch },
   .{ TEXTURE_SIZE_ARRAY_FUNCTION_NAME,     .[.Image], "lod: s32",                                                  "s32x3", .Array, .Size },
   .{ TEXTURE_LEVELS_ARRAY_FUNCTION_NAME,   .[.Image], "",                                                          "s32",   .Array, .Levels },

   // storage images. overloads determine the type of some stuff: the type of the texel of ImageWrite determines the sampled type of OpTypeImage.
   .{ IMAGE_WRITE_FUNCTION_NAME,          .[.Image], "coordinate: s32x2, texel: f32x4", "",      ._2D, .Write },
   .{ IMAGE_READ_FUNCTION_NAME,           .[.Image], "coordinate: s32x2",               "f32x4", ._2D, .Read },
   .{ IMAGE_SIZE_FUNCTION_NAME,           .[.Image], "",                                "s32x2", ._2D, .StorageSize },
];

#insert #run -> string {
   builder: String_Builder;

   // "uv: f32x2, lod: f32" is called with "uv, lod"
   ArgumentNames :: (parameters: string, names: *[..] string) {
      for parameter: split(parameters, ",") {
         found, name := split_from_left(parameter, #char ":");
         assert(found, "parameter: %", parameter);
         array_add(names, trim(name));
      }
   }

   for RESOURCE_FUNCTIONS {
      intrinsicParameters: [..] string;
      macroParameters:     [..] string;
      callArguments:       [..] string;
      for resource: it.resources {
         name, typeName, heap := GetHeapResourceInfo(resource);
         array_add(*intrinsicParameters, sprint("%: %", name, typeName));
         array_add(*macroParameters, sprint("%Index: u32", name));
         array_add(*callArguments, sprint("%[%Index]", heap, name));
      }

      if (it.parameters) {
         array_add(*intrinsicParameters, it.parameters);
         array_add(*macroParameters, it.parameters);
         ArgumentNames(it.parameters, *callArguments);
      }

      // texture :: (image: __Image__, sampler: __Sampler__, uv: f32x2) -> f32x4 { result: f32x4; return result; } @intrinsic
      // texture :: (imageIndex: u32, samplerIndex: u32, uv: f32x2) -> f32x4 #expand { return texture(images[imageIndex], samplers[samplerIndex], uv); }
      call := sprint("%(%)", it.name, join(..callArguments, ", "));
      if (it.returnType) {
         print_to_builder(*builder, "% :: (%) -> % { result: %; return result; } @%\n", it.name, join(..intrinsicParameters, ", "), it.returnType, it.returnType, INTRINSIC_NOTE_NAME);
         print_to_builder(*builder, "% :: (%) -> % #expand { return %; }\n", it.name, join(..macroParameters, ", "), it.returnType, call);
      } else {
         print_to_builder(*builder, "% :: (%) { } @%\n", it.name, join(..intrinsicParameters, ", "), INTRINSIC_NOTE_NAME);
         print_to_builder(*builder, "% :: (%) #expand { %; }\n", it.name, join(..macroParameters, ", "), call);
      }
   }

   return builder_to_string(*builder);
};

// the parameter of the intrinsic that takes the resource, and the heap the resource is in
GetHeapResourceInfo :: (resource: HeapResource) -> name: string, typeName: string, heap: string {
   if resource == {
      case .Image;   return "image",   "__Image__",   IMAGE_HEAP_VARIABLE_NAME;
      case .Sampler; return "sampler", "__Sampler__", SAMPLER_HEAP_VARIABLE_NAME;
   }

   assert(false, "resource: %", resource);
   return "", "", "";
}

// the flags of TraceRay (and of incomingrayflags), the bits are the ones of the RayFlagsMask of spirv
RayFlags :: enum_flags u32 {
   Opaque;
   NoOpaque;
   TerminateOnFirstHit;
   SkipClosestHitShader;
   CullBackFacingTriangles;
   CullFrontFacingTriangles;
   CullOpaque;
   CullNoOpaque;
   SkipTriangles;
   SkipAABBs;
}

#run {
   #assert cast(u32) RayFlags.Opaque                    == cast(u32) SpvRayFlagsMask.OpaqueKHRMask;
   #assert cast(u32) RayFlags.NoOpaque                  == cast(u32) SpvRayFlagsMask.NoOpaqueKHRMask;
   #assert cast(u32) RayFlags.TerminateOnFirstHit       == cast(u32) SpvRayFlagsMask.TerminateOnFirstHitKHRMask;
   #assert cast(u32) RayFlags.SkipClosestHitShader      == cast(u32) SpvRayFlagsMask.SkipClosestHitShaderKHRMask;
   #assert cast(u32) RayFlags.CullBackFacingTriangles   == cast(u32) SpvRayFlagsMask.CullBackFacingTrianglesKHRMask;
   #assert cast(u32) RayFlags.CullFrontFacingTriangles  == cast(u32) SpvRayFlagsMask.CullFrontFacingTrianglesKHRMask;
   #assert cast(u32) RayFlags.CullOpaque                == cast(u32) SpvRayFlagsMask.CullOpaqueKHRMask;
   #assert cast(u32) RayFlags.CullNoOpaque              == cast(u32) SpvRayFlagsMask.CullNoOpaqueKHRMask;
   #assert cast(u32) RayFlags.SkipTriangles             == cast(u32) SpvRayFlagsMask.SkipTrianglesKHRMask;
   #assert cast(u32) RayFlags.SkipAABBs                 == cast(u32) SpvRayFlagsMask.SkipAABBsKHRMask;
}

// a ray traced inline from any shader (OpTypeRayQueryKHR). it is a local variable, the RayQuery functions take its address
RayQuery :: struct { }

// what a trace found, its shader is not run yet (OpTypeHitObjectEXT). it is a local variable, the HitObject functions take its address
HitObject :: struct { }

// what RayQueryGetCommittedType and RayQueryGetCandidateType return. the values are the ones of spirv
RayQueryCommitted :: enum u32 {
   None;
   Triangle;
   Generated;   // RayQueryGenerateIntersection
}

RayQueryCandidate :: enum u32 {
   Triangle;
   AABB;
}

#run {
   #assert cast(u32) RayQueryCommitted.None      == cast(u32) SpvRayQueryCommittedIntersectionType.RayQueryCommittedIntersectionNoneKHR;
   #assert cast(u32) RayQueryCommitted.Triangle  == cast(u32) SpvRayQueryCommittedIntersectionType.RayQueryCommittedIntersectionTriangleKHR;
   #assert cast(u32) RayQueryCommitted.Generated == cast(u32) SpvRayQueryCommittedIntersectionType.RayQueryCommittedIntersectionGeneratedKHR;
   #assert cast(u32) RayQueryCandidate.Triangle  == cast(u32) SpvRayQueryCandidateIntersectionType.RayQueryCandidateIntersectionTriangleKHR;
   #assert cast(u32) RayQueryCandidate.AABB      == cast(u32) SpvRayQueryCandidateIntersectionType.RayQueryCandidateIntersectionAABBKHR;
}

// built in input variables (gl_WorkGroupID, gl_LaunchIDEXT...).
// they are only declared in the entry point if the shader uses them, and using one in a stage that doesnt have it is an error.
BuiltinVariable :: struct {
   name:          string;
   typeName:      string;
   builtIn:       SpvBuiltIn;
   stages:        ShaderStages;
   storageClass:  SpvStorageClass; // Input, or Output if the shader writes it (fragdepth)
}

// a bit for each ShaderType
ShaderStages :: enum_flags u32 {
   Task;
   Mesh;
   Fragment;
   Compute;
   Rgen;
   Rchit;
   Rmiss;
   Rahit;
   Rint;
   Rcall;
}

ALL_SHADER_STAGES :: ShaderStages.Task | .Mesh | .Fragment | .Compute | .Rgen | .Rchit | .Rmiss | .Rahit | .Rint | .Rcall;
RAY_TRACING_STAGES :: ShaderStages.Rgen | .Rchit | .Rmiss | .Rahit | .Rint | .Rcall;

// the types are what spirv requires. for the indices spirv only requires a 32 bit integer, they are s32 like in glsl.
BUILTIN_VARIABLES :: BuiltinVariable.[
   .{ "workgroupid",          "u32x3",    .WorkgroupId,              .Task | .Mesh | .Compute, .Input },
   .{ "localinvocationid",    "u32x3",    .LocalInvocationId,        .Task | .Mesh | .Compute, .Input },
   .{ "globalinvocationid",   "u32x3",    .GlobalInvocationId,       .Task | .Mesh | .Compute, .Input },
   .{ "localinvocationindex", "u32",      .LocalInvocationIndex,     .Task | .Mesh | .Compute, .Input },
   .{ "numworkgroups",        "u32x3",    .NumWorkgroups,            .Task | .Mesh | .Compute, .Input },
   .{ "launchid",             "u32x3",    .LaunchIdKHR,              RAY_TRACING_STAGES, .Input },
   .{ "launchsize",           "u32x3",    .LaunchSizeKHR,            RAY_TRACING_STAGES, .Input },
   .{ "worldrayorigin",       "f32x3",    .WorldRayOriginKHR,        .Rchit | .Rmiss | .Rahit | .Rint, .Input },
   .{ "worldraydirection",    "f32x3",    .WorldRayDirectionKHR,     .Rchit | .Rmiss | .Rahit | .Rint, .Input },
   .{ "objectrayorigin",      "f32x3",    .ObjectRayOriginKHR,       .Rchit | .Rahit | .Rint, .Input },
   .{ "objectraydirection",   "f32x3",    .ObjectRayDirectionKHR,    .Rchit | .Rahit | .Rint, .Input },
   .{ "raytmin",              "f32",      .RayTminKHR,               .Rchit | .Rmiss | .Rahit | .Rint, .Input },
   .{ "raytmax",              "f32",      .RayTmaxKHR,               .Rchit | .Rmiss | .Rahit | .Rint, .Input },
   .{ "incomingrayflags",     "RayFlags", .IncomingRayFlagsKHR,      .Rchit | .Rmiss | .Rahit | .Rint, .Input },
   .{ "hitkind",              "u32",      .HitKindKHR,               .Rchit | .Rahit, .Input },
   .{ "instancecustomindex",  "s32",      .InstanceCustomIndexKHR,   .Rchit | .Rahit | .Rint, .Input },
   .{ "instanceid",           "s32",      .InstanceId,               .Rchit | .Rahit | .Rint, .Input },
   .{ "geometryindex",        "s32",      .RayGeometryIndexKHR,      .Rchit | .Rahit | .Rint, .Input },
   .{ "primitiveid",          "s32",      .PrimitiveId,              .Rchit | .Rahit | .Rint | .Fragment, .Input }, // in a fragment shader it is what the mesh shader wrote (meshprimitives)
   .{ "objecttoworld",        "f32x3x4",  .ObjectToWorldKHR,         .Rchit | .Rahit | .Rint, .Input },
   .{ "worldtoobject",        "f32x3x4",  .WorldToObjectKHR,         .Rchit | .Rahit | .Rint, .Input },
   .{ "fragcoord",            "f32x4",    .FragCoord,                .Fragment, .Input },
   .{ "frontfacing",          "bool",     .FrontFacing,              .Fragment, .Input },
   .{ "sampleid",             "s32",      .SampleId,                 .Fragment, .Input }, // SampleRateShading
   .{ "helperinvocation",     "bool",     .HelperInvocation,         .Fragment, .Input },
   .{ "subgroupsize",         "u32",      .SubgroupSize,             ALL_SHADER_STAGES, .Input },
   .{ "subgroupinvocationid", "u32",      .SubgroupLocalInvocationId, ALL_SHADER_STAGES, .Input },
   .{ "numsubgroups",         "u32",      .NumSubgroups,             .Task | .Mesh | .Compute, .Input },
   .{ "subgroupid",           "u32",      .SubgroupId,               .Task | .Mesh | .Compute, .Input },
   .{ "barycoord",              "f32x3",  .BaryCoordKHR,             .Fragment,   .Input  },
   .{ "barycoordnoperspective", "f32x3",  .BaryCoordNoPerspKHR,      .Fragment,   .Input  },
   .{ "samplemaskin",           "u32",    .SampleMask,               .Fragment,   .Input  }, // a bit for each sample (up to 32). in spirv it is an array of one u32
   .{ "fragdepth",              "f32",    .FragDepth,                .Fragment,   .Output },
   .{ "samplemask",             "u32",    .SampleMask,               .Fragment,   .Output },
];

#insert #run -> string {
   builder: String_Builder;
   for BUILTIN_VARIABLES  print_to_builder(*builder, "%: %; @%\n", it.name, it.typeName, INTRINSIC_NOTE_NAME);
   return builder_to_string(*builder);
};

// the math intrinsics and the subgroup intrinsics. see MATH_INTRINSICS and SUBGROUP_INTRINSICS
// the bodies of the math intrinsics are the cpu implementations (see cpu.jai). the subgroup ones only exist on the gpu
#insert #run -> string {
   builder: String_Builder;

   DeclareOverloads :: (builder: *String_Builder, name: string, signatures: [] MathIntrinsicSignature, cpu: bool) {
      for signature: signatures {
         for type: signature.types {
            header, returnType := ExpandSignature(signature.signature, type);

            // the Math module has this overload, it is the intrinsic (see MATH_MODULE_INTRINSICS)
            if (IsMathModuleOverload(name, type)) continue;

            body := ifx cpu then MathIntrinsicCpuBody(name, header) else tprint("r: %; return r;", returnType);
            print_to_builder(builder, "% :: % { % } @%\n", name, header, body, INTRINSIC_NOTE_NAME);
         }
      }
   }

   for MATH_INTRINSICS      DeclareOverloads(*builder, it.name, it.signatures, true);
   for SUBGROUP_INTRINSICS  DeclareOverloads(*builder, it.name, it.signatures, false);

   return builder_to_string(*builder);
};

// T is the type, C is the component type of T (f32 for f32x3), M is the vector type of the matrix T (f32x3 for mat3),
// U, S and F are T with u32, s32 and f32 components (u32x3 for f32x3)
ExpandSignature :: (signature: string, type: string) -> header: string, returnType: string {
   component := type;
   shape := "";
   if (find_index_from_left(type, "x") != -1) {
      component = slice(type, 0, find_index_from_left(type, "x"));
      shape = slice(type, component.count, type.count - component.count);
   }

   vector := type;
   if (begins_with(type, "mat")) vector = tprint("f32x%", slice(type, 3, 1));

   header := replace(replace(replace(signature, "T", type), "C", component), "M", vector);
   header = replace(replace(replace(header, "U", tprint("u32%", shape)), "S", tprint("s32%", shape)), "F", tprint("f32%", shape));
   returnType := slice(header, find_index_from_right(header, "-> ") + 3, header.count);
   return header, returnType;
}

//
// the math intrinsics have the names of hlsl. each is a GLSL.std.450 instruction or a spirv instruction.
// the overloads are declared from the signatures. in a signature T is replaced by each of the types, C by the component type of T and M by the vector type of the matrix T.
// U, S and F are T with u32, s32 and f32 components.
//
MathIntrinsicSignature :: struct {
   signature:  string;
   types:      [] string;
}

MathIntrinsic :: struct {
   name:       string;
   signatures: [] MathIntrinsicSignature;

   // GLSL.std.450 instructions by the kind of the components of the result. Bad if there is none for that kind.
   floatOp:    GLSLstd450;
   signedOp:   GLSLstd450;
   unsignedOp: GLSLstd450;

   coreOp:     SpvOp;   // a spirv instruction instead (if it is not Nop)
   broadcast:  bool;    // the scalar arguments are made vectors of the result type (clamp(v, 0, 1))
}

//
// the Math module of jai has the f32 overload of these, with the same meaning. declaring it here too would make a call ambiguous in a program that imports both,
// so the overload of Math is the intrinsic: a call to it is generated as the intrinsic (see IsIntrinsicProcedure). a shader that uses them has to import Math.
//
MATH_MODULE_INTRINSICS :: string.["sin", "cos", "tan", "asin", "acos", "atan", "atan2", "sqrt", "pow", "exp", "log", "abs", "floor", "ceil", "saturate", "lerp", "isnan", "isinf"];

IsMathModuleOverload :: (name: string, type: string) -> bool {
   return type == "f32" && array_find(MATH_MODULE_INTRINSICS, name);
}

// the integer overloads are only 32 bit. with 64 bit ones too min(x, 3) is ambiguous for jai (x: s32 can be s64 too, as the literal can be s32).
FLOATS            :: string.["f32", "f32x2", "f32x3", "f32x4"];
FLOAT_VECTORS     :: string.["f32x2", "f32x3", "f32x4"];
SIGNED_INTEGERS   :: string.["s32", "s32x2", "s32x3", "s32x4"];
INTEGER_VECTORS   :: string.["s32x2", "s32x3", "s32x4", "u32x2", "u32x3", "u32x4"];
INTEGERS          :: string.["s32", "s32x2", "s32x3", "s32x4", "u32", "u32x2", "u32x3", "u32x4"];
UNSIGNED_INTEGERS :: string.["u32", "u32x2", "u32x3", "u32x4"];
MATRICES          :: string.["mat2", "mat3", "mat4"];

UNARY_FLOAT    :: MathIntrinsicSignature.[.{ "(x: T) -> T", FLOATS }];
BINARY_FLOAT   :: MathIntrinsicSignature.[.{ "(x: T, y: T) -> T", FLOATS }];

MATH_INTRINSICS :: MathIntrinsic.[
   .{ "sin",         UNARY_FLOAT, .Sin,         .Bad,    .Bad,    .Nop, false },
   .{ "cos",         UNARY_FLOAT, .Cos,         .Bad,    .Bad,    .Nop, false },
   .{ "tan",         UNARY_FLOAT, .Tan,         .Bad,    .Bad,    .Nop, false },
   .{ "asin",        UNARY_FLOAT, .Asin,        .Bad,    .Bad,    .Nop, false },
   .{ "acos",        UNARY_FLOAT, .Acos,        .Bad,    .Bad,    .Nop, false },
   .{ "atan",        UNARY_FLOAT, .Atan,        .Bad,    .Bad,    .Nop, false },
   .{ "atan2",       .[.{ "(y: T, x: T) -> T", FLOATS }], .Atan2, .Bad, .Bad, .Nop, false },
   .{ "sqrt",        UNARY_FLOAT, .Sqrt,        .Bad,    .Bad,    .Nop, false },
   .{ "inversesqrt", UNARY_FLOAT, .InverseSqrt, .Bad,    .Bad,    .Nop, false },
   .{ "pow",         BINARY_FLOAT, .Pow,        .Bad,    .Bad,    .Nop, false },
   .{ "exp",         UNARY_FLOAT, .Exp,         .Bad,    .Bad,    .Nop, false },
   .{ "exp2",        UNARY_FLOAT, .Exp2,        .Bad,    .Bad,    .Nop, false },
   .{ "log",         UNARY_FLOAT, .Log,         .Bad,    .Bad,    .Nop, false },
   .{ "log2",        UNARY_FLOAT, .Log2,        .Bad,    .Bad,    .Nop, false },
   .{ "abs",         .[.{ "(x: T) -> T", FLOATS }, .{ "(x: T) -> T", SIGNED_INTEGERS }], .FAbs,  .SAbs,  .Bad, .Nop, false },
   .{ "sign",        .[.{ "(x: T) -> T", FLOATS }, .{ "(x: T) -> T", SIGNED_INTEGERS }], .FSign, .SSign, .Bad, .Nop, false },
   .{ "floor",       UNARY_FLOAT, .Floor,       .Bad,    .Bad,    .Nop, false },
   .{ "ceil",        UNARY_FLOAT, .Ceil,        .Bad,    .Bad,    .Nop, false },
   .{ "round",       UNARY_FLOAT, .RoundEven,   .Bad,    .Bad,    .Nop, false }, // hlsl rounds halfway cases to even
   .{ "trunc",       UNARY_FLOAT, .Trunc,       .Bad,    .Bad,    .Nop, false },
   .{ "frac",        UNARY_FLOAT, .Fract,       .Bad,    .Bad,    .Nop, false },
   .{ "min",         .[.{ "(x: T, y: T) -> T", FLOATS }, .{ "(x: T, y: T) -> T", INTEGERS }], .FMin, .SMin, .UMin, .Nop, false },
   .{ "max",         .[.{ "(x: T, y: T) -> T", FLOATS }, .{ "(x: T, y: T) -> T", INTEGERS }], .FMax, .SMax, .UMax, .Nop, false },
   .{ "clamp",       .[.{ "(x: T, minValue: T, maxValue: T) -> T", FLOATS }, .{ "(x: T, minValue: T, maxValue: T) -> T", INTEGERS },
                       .{ "(x: T, minValue: C, maxValue: C) -> T", FLOAT_VECTORS }, .{ "(x: T, minValue: C, maxValue: C) -> T", INTEGER_VECTORS }], .FClamp, .SClamp, .UClamp, .Nop, true },
   .{ "saturate",    UNARY_FLOAT, .FClamp,      .Bad,    .Bad,    .Nop, true }, // clamp(x, 0, 1)
   .{ "lerp",        .[.{ "(a: T, b: T, t: T) -> T", FLOATS }, .{ "(a: T, b: T, t: C) -> T", FLOAT_VECTORS }], .FMix, .Bad, .Bad, .Nop, true },
   .{ "step",        .[.{ "(edge: T, x: T) -> T", FLOATS }, .{ "(edge: C, x: T) -> T", FLOAT_VECTORS }], .Step, .Bad, .Bad, .Nop, true },
   .{ "smoothstep",  .[.{ "(edge0: T, edge1: T, x: T) -> T", FLOATS }, .{ "(edge0: C, edge1: C, x: T) -> T", FLOAT_VECTORS }], .SmoothStep, .Bad, .Bad, .Nop, true },
   .{ "dot",         .[.{ "(a: T, b: T) -> C", FLOAT_VECTORS }], .Bad,       .Bad, .Bad, .Dot, false },
   .{ "cross",       .[.{ "(a: T, b: T) -> T", .["f32x3"] }],    .Cross,     .Bad, .Bad, .Nop, false },
   .{ "length",      .[.{ "(x: T) -> C", FLOAT_VECTORS }],       .Length,    .Bad, .Bad, .Nop, false },
   .{ "distance",    .[.{ "(a: T, b: T) -> C", FLOAT_VECTORS }], .Distance,  .Bad, .Bad, .Nop, false },
   .{ "normalize",   .[.{ "(x: T) -> T", FLOAT_VECTORS }],       .Normalize, .Bad, .Bad, .Nop, false },
   .{ "reflect",     .[.{ "(incident: T, normal: T) -> T", FLOAT_VECTORS }], .Reflect, .Bad, .Bad, .Nop, false },
   .{ "refract",     .[.{ "(incident: T, normal: T, eta: C) -> T", FLOAT_VECTORS }], .Refract, .Bad, .Bad, .Nop, false },
   .{ "transpose",   .[.{ "(m: T) -> T", MATRICES }],            .Bad,           .Bad, .Bad, .Transpose, false },
   .{ "determinant", .[.{ "(m: T) -> f32", MATRICES }],          .Determinant,   .Bad, .Bad, .Nop, false },
   .{ "inverse",     .[.{ "(m: T) -> T", MATRICES }],            .MatrixInverse, .Bad, .Bad, .Nop, false },
   // matrix times matrix, matrix times column vector, row vector times matrix
   .{ "mul",         .[.{ "(a: T, b: T) -> T", MATRICES }, .{ "(m: T, v: M) -> M", MATRICES }, .{ "(v: M, m: T) -> M", MATRICES }], .Bad, .Bad, .Bad, .MatrixTimesMatrix, false },
   // derivatives, fragment shaders only
   .{ "ddx",         UNARY_FLOAT, .Bad,         .Bad,    .Bad,    .DPdx,   false },
   .{ "ddy",         UNARY_FLOAT, .Bad,         .Bad,    .Bad,    .DPdy,   false },
   .{ "fwidth",      UNARY_FLOAT, .Bad,         .Bad,    .Bad,    .Fwidth, false },

   // a float is nan or infinity. scalars only, there are no bool vectors
   .{ "isnan",       .[.{ "(x: T) -> bool", .["f32"] }], .Bad, .Bad, .Bad, .IsNan, false },
   .{ "isinf",       .[.{ "(x: T) -> bool", .["f32"] }], .Bad, .Bad, .Bad, .IsInf, false },

   // bitcasts: the same bits as another type
   .{ "asuint",       .[.{ "(x: T) -> U", FLOATS }, .{ "(x: T) -> U", SIGNED_INTEGERS }],            .Bad, .Bad, .Bad, .Bitcast, false },
   .{ "asint",        .[.{ "(x: T) -> S", FLOATS }, .{ "(x: T) -> S", UNSIGNED_INTEGERS }],          .Bad, .Bad, .Bad, .Bitcast, false },
   .{ "asfloat",      .[.{ "(x: T) -> F", SIGNED_INTEGERS }, .{ "(x: T) -> F", UNSIGNED_INTEGERS }], .Bad, .Bad, .Bad, .Bitcast, false },

   // the bits of an integer. firstbithigh and firstbitlow are -1 if no bit is set
   .{ "countbits",    .[.{ "(x: T) -> T", INTEGERS }], .Bad, .Bad,      .Bad,      .BitCount,   false },
   .{ "reversebits",  .[.{ "(x: T) -> T", INTEGERS }], .Bad, .Bad,      .Bad,      .BitReverse, false },
   .{ "firstbithigh", .[.{ "(x: T) -> T", INTEGERS }], .Bad, .FindSMsb, .FindUMsb, .Nop,        false },
   .{ "firstbitlow",  .[.{ "(x: T) -> T", INTEGERS }], .Bad, .FindILsb, .FindILsb, .Nop,        false },

   // packing: two or four small floats in a u32 (half floats, or normalized to 8 or 16 bits)
   .{ "packhalf2x16",    .[.{ "(v: f32x2) -> u32", .["f32x2"] }], .Bad,             .Bad, .PackHalf2x16,  .Nop, false },
   .{ "unpackhalf2x16",  .[.{ "(x: u32) -> f32x2", .["u32"] }],   .UnpackHalf2x16,  .Bad, .Bad,           .Nop, false },
   .{ "packunorm4x8",    .[.{ "(v: f32x4) -> u32", .["f32x4"] }], .Bad,             .Bad, .PackUnorm4x8,  .Nop, false },
   .{ "unpackunorm4x8",  .[.{ "(x: u32) -> f32x4", .["u32"] }],   .UnpackUnorm4x8,  .Bad, .Bad,           .Nop, false },
   .{ "packsnorm4x8",    .[.{ "(v: f32x4) -> u32", .["f32x4"] }], .Bad,             .Bad, .PackSnorm4x8,  .Nop, false },
   .{ "unpacksnorm4x8",  .[.{ "(x: u32) -> f32x4", .["u32"] }],   .UnpackSnorm4x8,  .Bad, .Bad,           .Nop, false },
   .{ "packunorm2x16",   .[.{ "(v: f32x2) -> u32", .["f32x2"] }], .Bad,             .Bad, .PackUnorm2x16, .Nop, false },
   .{ "unpackunorm2x16", .[.{ "(x: u32) -> f32x2", .["u32"] }],   .UnpackUnorm2x16, .Bad, .Bad,           .Nop, false },
   .{ "packsnorm2x16",   .[.{ "(v: f32x2) -> u32", .["f32x2"] }], .Bad,             .Bad, .PackSnorm2x16, .Nop, false },
   .{ "unpacksnorm2x16", .[.{ "(x: u32) -> f32x2", .["u32"] }],   .UnpackSnorm2x16, .Bad, .Bad,           .Nop, false },
];

//
// the subgroup operations (OpGroupNonUniform*). the overloads are declared from the signatures like the math intrinsics.
// the instruction is op, or if op is Nop the one for the kind of the components of the first argument (Nop if there is none for that kind).
// the arithmetic ones and the ballot bit counts take a group operation (Reduce, InclusiveScan, ExclusiveScan) after the scope.
//
SubgroupIntrinsic :: struct {
   name:          string;
   signatures:    [] MathIntrinsicSignature;
   capability:    SpvCapability;

   op:            SpvOp;
   floatOp:       SpvOp;
   signedOp:      SpvOp;
   unsignedOp:    SpvOp;
   boolOp:        SpvOp;

   operation:     SpvGroupOperation; // NO_GROUP_OPERATION if the instruction doesnt take one
}

NO_GROUP_OPERATION :: SpvGroupOperation.Max;

SUBGROUP_NUMBERS :: string.["f32", "f32x2", "f32x3", "f32x4", "s32", "s32x2", "s32x3", "s32x4", "u32", "u32x2", "u32x3", "u32x4"];
SUBGROUP_BITS    :: string.["s32", "s32x2", "s32x3", "s32x4", "u32", "u32x2", "u32x3", "u32x4", "bool"];
SUBGROUP_VALUES  :: string.["f32", "f32x2", "f32x3", "f32x4", "s32", "s32x2", "s32x3", "s32x4", "u32", "u32x2", "u32x3", "u32x4", "bool"];

SUBGROUP_REDUCE    :: MathIntrinsicSignature.[.{ "(value: T) -> T", SUBGROUP_NUMBERS }];
SUBGROUP_BITWISE   :: MathIntrinsicSignature.[.{ "(value: T) -> T", SUBGROUP_BITS }];
SUBGROUP_BALLOT_U32 :: MathIntrinsicSignature.[.{ "(mask: u32x4) -> u32", .["u32x4"] }];

SUBGROUP_INTRINSICS :: SubgroupIntrinsic.[
   .{ "SubgroupElect",          .[.{ "() -> bool", .["bool"] }],                    .GroupNonUniform,     .GroupNonUniformElect, .Nop, .Nop, .Nop, .Nop, NO_GROUP_OPERATION },

   // vote
   .{ "SubgroupAll",            .[.{ "(value: bool) -> bool", .["bool"] }],         .GroupNonUniformVote, .GroupNonUniformAll,      .Nop, .Nop, .Nop, .Nop, NO_GROUP_OPERATION },
   .{ "SubgroupAny",            .[.{ "(value: bool) -> bool", .["bool"] }],         .GroupNonUniformVote, .GroupNonUniformAny,      .Nop, .Nop, .Nop, .Nop, NO_GROUP_OPERATION },
   .{ "SubgroupAllEqual",       .[.{ "(value: T) -> bool", SUBGROUP_VALUES }],      .GroupNonUniformVote, .GroupNonUniformAllEqual, .Nop, .Nop, .Nop, .Nop, NO_GROUP_OPERATION },

   // ballot. a ballot has a bit for each invocation of the subgroup (the ones whose value is true)
   .{ "SubgroupBroadcast",               .[.{ "(value: T, id: u32) -> T", SUBGROUP_VALUES }],              .GroupNonUniformBallot, .GroupNonUniformBroadcast,        .Nop, .Nop, .Nop, .Nop, NO_GROUP_OPERATION },
   .{ "SubgroupBroadcastFirst",          .[.{ "(value: T) -> T", SUBGROUP_VALUES }],                       .GroupNonUniformBallot, .GroupNonUniformBroadcastFirst,   .Nop, .Nop, .Nop, .Nop, NO_GROUP_OPERATION },
   .{ "SubgroupBallot",                  .[.{ "(value: bool) -> u32x4", .["bool"] }],                      .GroupNonUniformBallot, .GroupNonUniformBallot,           .Nop, .Nop, .Nop, .Nop, NO_GROUP_OPERATION },
   .{ "SubgroupInverseBallot",           .[.{ "(mask: u32x4) -> bool", .["u32x4"] }],                      .GroupNonUniformBallot, .GroupNonUniformInverseBallot,    .Nop, .Nop, .Nop, .Nop, NO_GROUP_OPERATION },
   .{ "SubgroupBallotBitExtract",        .[.{ "(mask: u32x4, index: u32) -> bool", .["u32x4"] }],          .GroupNonUniformBallot, .GroupNonUniformBallotBitExtract, .Nop, .Nop, .Nop, .Nop, NO_GROUP_OPERATION },
   .{ "SubgroupBallotBitCount",          SUBGROUP_BALLOT_U32, .GroupNonUniformBallot, .GroupNonUniformBallotBitCount, .Nop, .Nop, .Nop, .Nop, .Reduce },
   .{ "SubgroupBallotInclusiveBitCount", SUBGROUP_BALLOT_U32, .GroupNonUniformBallot, .GroupNonUniformBallotBitCount, .Nop, .Nop, .Nop, .Nop, .InclusiveScan },
   .{ "SubgroupBallotExclusiveBitCount", SUBGROUP_BALLOT_U32, .GroupNonUniformBallot, .GroupNonUniformBallotBitCount, .Nop, .Nop, .Nop, .Nop, .ExclusiveScan },
   .{ "SubgroupBallotFindLSB",           SUBGROUP_BALLOT_U32, .GroupNonUniformBallot, .GroupNonUniformBallotFindLSB,  .Nop, .Nop, .Nop, .Nop, NO_GROUP_OPERATION },
   .{ "SubgroupBallotFindMSB",           SUBGROUP_BALLOT_U32, .GroupNonUniformBallot, .GroupNonUniformBallotFindMSB,  .Nop, .Nop, .Nop, .Nop, NO_GROUP_OPERATION },

   // arithmetic. the reduction of the values of the subgroup, the inclusive scan (the invocations up to this one) and the exclusive scan (the ones before this one)
   .{ "SubgroupAdd",          SUBGROUP_REDUCE,  .GroupNonUniformArithmetic, .Nop, .GroupNonUniformFAdd, .GroupNonUniformIAdd,       .GroupNonUniformIAdd,       .Nop,                       .Reduce },
   .{ "SubgroupMul",          SUBGROUP_REDUCE,  .GroupNonUniformArithmetic, .Nop, .GroupNonUniformFMul, .GroupNonUniformIMul,       .GroupNonUniformIMul,       .Nop,                       .Reduce },
   .{ "SubgroupMin",          SUBGROUP_REDUCE,  .GroupNonUniformArithmetic, .Nop, .GroupNonUniformFMin, .GroupNonUniformSMin,       .GroupNonUniformUMin,       .Nop,                       .Reduce },
   .{ "SubgroupMax",          SUBGROUP_REDUCE,  .GroupNonUniformArithmetic, .Nop, .GroupNonUniformFMax, .GroupNonUniformSMax,       .GroupNonUniformUMax,       .Nop,                       .Reduce },
   .{ "SubgroupAnd",          SUBGROUP_BITWISE, .GroupNonUniformArithmetic, .Nop, .Nop,                 .GroupNonUniformBitwiseAnd, .GroupNonUniformBitwiseAnd, .GroupNonUniformLogicalAnd, .Reduce },
   .{ "SubgroupOr",           SUBGROUP_BITWISE, .GroupNonUniformArithmetic, .Nop, .Nop,                 .GroupNonUniformBitwiseOr,  .GroupNonUniformBitwiseOr,  .GroupNonUniformLogicalOr,  .Reduce },
   .{ "SubgroupXor",          SUBGROUP_BITWISE, .GroupNonUniformArithmetic, .Nop, .Nop,                 .GroupNonUniformBitwiseXor, .GroupNonUniformBitwiseXor, .GroupNonUniformLogicalXor, .Reduce },
   .{ "SubgroupInclusiveAdd", SUBGROUP_REDUCE,  .GroupNonUniformArithmetic, .Nop, .GroupNonUniformFAdd, .GroupNonUniformIAdd,       .GroupNonUniformIAdd,       .Nop,                       .InclusiveScan },
   .{ "SubgroupInclusiveMul", SUBGROUP_REDUCE,  .GroupNonUniformArithmetic, .Nop, .GroupNonUniformFMul, .GroupNonUniformIMul,       .GroupNonUniformIMul,       .Nop,                       .InclusiveScan },
   .{ "SubgroupInclusiveMin", SUBGROUP_REDUCE,  .GroupNonUniformArithmetic, .Nop, .GroupNonUniformFMin, .GroupNonUniformSMin,       .GroupNonUniformUMin,       .Nop,                       .InclusiveScan },
   .{ "SubgroupInclusiveMax", SUBGROUP_REDUCE,  .GroupNonUniformArithmetic, .Nop, .GroupNonUniformFMax, .GroupNonUniformSMax,       .GroupNonUniformUMax,       .Nop,                       .InclusiveScan },
   .{ "SubgroupInclusiveAnd", SUBGROUP_BITWISE, .GroupNonUniformArithmetic, .Nop, .Nop,                 .GroupNonUniformBitwiseAnd, .GroupNonUniformBitwiseAnd, .GroupNonUniformLogicalAnd, .InclusiveScan },
   .{ "SubgroupInclusiveOr",  SUBGROUP_BITWISE, .GroupNonUniformArithmetic, .Nop, .Nop,                 .GroupNonUniformBitwiseOr,  .GroupNonUniformBitwiseOr,  .GroupNonUniformLogicalOr,  .InclusiveScan },
   .{ "SubgroupInclusiveXor", SUBGROUP_BITWISE, .GroupNonUniformArithmetic, .Nop, .Nop,                 .GroupNonUniformBitwiseXor, .GroupNonUniformBitwiseXor, .GroupNonUniformLogicalXor, .InclusiveScan },
   .{ "SubgroupExclusiveAdd", SUBGROUP_REDUCE,  .GroupNonUniformArithmetic, .Nop, .GroupNonUniformFAdd, .GroupNonUniformIAdd,       .GroupNonUniformIAdd,       .Nop,                       .ExclusiveScan },
   .{ "SubgroupExclusiveMul", SUBGROUP_REDUCE,  .GroupNonUniformArithmetic, .Nop, .GroupNonUniformFMul, .GroupNonUniformIMul,       .GroupNonUniformIMul,       .Nop,                       .ExclusiveScan },
   .{ "SubgroupExclusiveMin", SUBGROUP_REDUCE,  .GroupNonUniformArithmetic, .Nop, .GroupNonUniformFMin, .GroupNonUniformSMin,       .GroupNonUniformUMin,       .Nop,                       .ExclusiveScan },
   .{ "SubgroupExclusiveMax", SUBGROUP_REDUCE,  .GroupNonUniformArithmetic, .Nop, .GroupNonUniformFMax, .GroupNonUniformSMax,       .GroupNonUniformUMax,       .Nop,                       .ExclusiveScan },
   .{ "SubgroupExclusiveAnd", SUBGROUP_BITWISE, .GroupNonUniformArithmetic, .Nop, .Nop,                 .GroupNonUniformBitwiseAnd, .GroupNonUniformBitwiseAnd, .GroupNonUniformLogicalAnd, .ExclusiveScan },
   .{ "SubgroupExclusiveOr",  SUBGROUP_BITWISE, .GroupNonUniformArithmetic, .Nop, .Nop,                 .GroupNonUniformBitwiseOr,  .GroupNonUniformBitwiseOr,  .GroupNonUniformLogicalOr,  .ExclusiveScan },
   .{ "SubgroupExclusiveXor", SUBGROUP_BITWISE, .GroupNonUniformArithmetic, .Nop, .Nop,                 .GroupNonUniformBitwiseXor, .GroupNonUniformBitwiseXor, .GroupNonUniformLogicalXor, .ExclusiveScan },

   // shuffle: the value of another invocation. ShuffleXor: the invocation is this one xor mask. ShuffleUp/Down: this one minus/plus delta
   .{ "SubgroupShuffle",      .[.{ "(value: T, id: u32) -> T", SUBGROUP_VALUES }],    .GroupNonUniformShuffle,         .GroupNonUniformShuffle,     .Nop, .Nop, .Nop, .Nop, NO_GROUP_OPERATION },
   .{ "SubgroupShuffleXor",   .[.{ "(value: T, mask: u32) -> T", SUBGROUP_VALUES }],  .GroupNonUniformShuffle,         .GroupNonUniformShuffleXor,  .Nop, .Nop, .Nop, .Nop, NO_GROUP_OPERATION },
   .{ "SubgroupShuffleUp",    .[.{ "(value: T, delta: u32) -> T", SUBGROUP_VALUES }], .GroupNonUniformShuffleRelative, .GroupNonUniformShuffleUp,   .Nop, .Nop, .Nop, .Nop, NO_GROUP_OPERATION },
   .{ "SubgroupShuffleDown",  .[.{ "(value: T, delta: u32) -> T", SUBGROUP_VALUES }], .GroupNonUniformShuffleRelative, .GroupNonUniformShuffleDown, .Nop, .Nop, .Nop, .Nop, NO_GROUP_OPERATION },
];

//
// the functions of a ray query. a ray query traces from any shader, RayQueryInitialize starts it. the first parameter is the address of the query.
// the ones about an intersection are about the committed one (the closest hit that was confirmed) or the candidate one (the hit Proceed stopped at)
//
RayQueryIntersection :: enum u8 {
   None;       // the instruction is not about an intersection
   Committed;
   Candidate;
   Argument;   // the committed parameter says which one (it must be a constant)
}

RayQueryIntrinsic :: struct {
   name:          string;
   signature:     string;
   op:            SpvOp;
   intersection:  RayQueryIntersection;
}

RAY_QUERY_INTRINSICS :: RayQueryIntrinsic.[
   .{ "RayQueryInitialize",                         "(q: *RayQuery, tlas: u64, rayFlags: RayFlags, cullMask: u32, origin: f32x3, tMin: f32, direction: f32x3, tMax: f32)", .RayQueryInitializeKHR, .None },
   .{ "RayQueryProceed",                            "(q: *RayQuery) -> bool",                      .RayQueryProceedKHR,                               .None      },
   .{ "RayQueryTerminate",                          "(q: *RayQuery)",                              .RayQueryTerminateKHR,                             .None      },
   .{ "RayQueryConfirmIntersection",                "(q: *RayQuery)",                              .RayQueryConfirmIntersectionKHR,                   .None      },
   .{ "RayQueryGenerateIntersection",               "(q: *RayQuery, t: f32)",                      .RayQueryGenerateIntersectionKHR,                  .None      },
   .{ "RayQueryGetCommittedType",                   "(q: *RayQuery) -> RayQueryCommitted",         .RayQueryGetIntersectionTypeKHR,                   .Committed },
   .{ "RayQueryGetCandidateType",                   "(q: *RayQuery) -> RayQueryCandidate",         .RayQueryGetIntersectionTypeKHR,                   .Candidate },
   .{ "RayQueryGetIntersectionT",                   "(q: *RayQuery, committed: bool) -> f32",      .RayQueryGetIntersectionTKHR,                      .Argument  },
   .{ "RayQueryGetIntersectionBarycentrics",        "(q: *RayQuery, committed: bool) -> f32x2",    .RayQueryGetIntersectionBarycentricsKHR,           .Argument  },
   .{ "RayQueryGetIntersectionInstanceCustomIndex", "(q: *RayQuery, committed: bool) -> s32",      .RayQueryGetIntersectionInstanceCustomIndexKHR,    .Argument  },
   .{ "RayQueryGetIntersectionInstanceId",          "(q: *RayQuery, committed: bool) -> s32",      .RayQueryGetIntersectionInstanceIdKHR,             .Argument  },
   .{ "RayQueryGetIntersectionGeometryIndex",       "(q: *RayQuery, committed: bool) -> s32",      .RayQueryGetIntersectionGeometryIndexKHR,          .Argument  },
   .{ "RayQueryGetIntersectionPrimitiveIndex",      "(q: *RayQuery, committed: bool) -> s32",      .RayQueryGetIntersectionPrimitiveIndexKHR,         .Argument  },
   .{ "RayQueryGetIntersectionFrontFace",           "(q: *RayQuery, committed: bool) -> bool",     .RayQueryGetIntersectionFrontFaceKHR,              .Argument  },
   .{ "RayQueryGetIntersectionObjectRayOrigin",     "(q: *RayQuery, committed: bool) -> f32x3",    .RayQueryGetIntersectionObjectRayOriginKHR,        .Argument  },
   .{ "RayQueryGetIntersectionObjectRayDirection",  "(q: *RayQuery, committed: bool) -> f32x3",    .RayQueryGetIntersectionObjectRayDirectionKHR,     .Argument  },
   .{ "RayQueryGetIntersectionObjectToWorld",       "(q: *RayQuery, committed: bool) -> f32x3x4",  .RayQueryGetIntersectionObjectToWorldKHR,          .Argument  },
   .{ "RayQueryGetIntersectionWorldToObject",       "(q: *RayQuery, committed: bool) -> f32x3x4",  .RayQueryGetIntersectionWorldToObjectKHR,          .Argument  },
   .{ "RayQueryGetRayTMin",                         "(q: *RayQuery) -> f32",                       .RayQueryGetRayTMinKHR,                            .None      },
   .{ "RayQueryGetRayFlags",                        "(q: *RayQuery) -> RayFlags",                  .RayQueryGetRayFlagsKHR,                           .None      },
   .{ "RayQueryGetWorldRayOrigin",                  "(q: *RayQuery) -> f32x3",                     .RayQueryGetWorldRayOriginKHR,                     .None      },
   .{ "RayQueryGetWorldRayDirection",               "(q: *RayQuery) -> f32x3",                     .RayQueryGetWorldRayDirectionKHR,                  .None      },
];

#insert #run -> string {
   builder: String_Builder;
   for RAY_QUERY_INTRINSICS {
      returnIndex := find_index_from_right(it.signature, "-> ");
      if (returnIndex == -1) {
         print_to_builder(*builder, "% :: % { } @%\n", it.name, it.signature, INTRINSIC_NOTE_NAME);
      } else {
         returnType := slice(it.signature, returnIndex + 3, it.signature.count - returnIndex - 3);
         print_to_builder(*builder, "% :: % { r: %; return r; } @%\n", it.name, it.signature, returnType, INTRINSIC_NOTE_NAME);
      }
   }
   return builder_to_string(*builder);
};

//
// the functions of a hit object (SPV_EXT_shader_invocation_reorder).
// a hit object is what a trace found (a hit, a miss or nothing), without running the hit or miss shader. the shader can be run later, after the invocations are reordered by ReorderThread.
// the first parameter is the address of the hit object (ReorderThread with a hint doesnt take one). the overloads are the optional operands: the hint and its bits, the hit kind.
// payload is the address of a @payload variable, attributes is the address of a @hitobjectattribute variable.
//
HitObjectIntrinsic :: struct {
   name:       string;
   signature:  string;
   op:         SpvOp;
}

HIT_OBJECT_INTRINSICS :: HitObjectIntrinsic.[
   // a trace that records what it found in the hit object, the hit or miss shader is not run
   .{ "HitObjectTraceRay",                         "(h: *HitObject, tlas: u64, rayFlags: RayFlags, cullMask: u32, sbtOffset: u32, sbtStride: u32, missIndex: u32, rayOrigin: f32x3, rayTMin: f32, rayDirection: f32x3, rayTMax: f32, payload: *$T)", .HitObjectTraceRayEXT },

   // HitObjectTraceRay, then ReorderThread and HitObjectExecuteShader in one. only in rgen shaders
   .{ "HitObjectTraceReorderExecute",              "(h: *HitObject, tlas: u64, rayFlags: RayFlags, cullMask: u32, sbtOffset: u32, sbtStride: u32, missIndex: u32, rayOrigin: f32x3, rayTMin: f32, rayDirection: f32x3, rayTMax: f32, payload: *$T)", .HitObjectTraceReorderExecuteEXT },
   .{ "HitObjectTraceReorderExecute",              "(h: *HitObject, tlas: u64, rayFlags: RayFlags, cullMask: u32, sbtOffset: u32, sbtStride: u32, missIndex: u32, rayOrigin: f32x3, rayTMin: f32, rayDirection: f32x3, rayTMax: f32, payload: *$T, hint: u32, bits: u32)", .HitObjectTraceReorderExecuteEXT },

   .{ "HitObjectRecordFromQuery",                  "(h: *HitObject, q: *RayQuery, sbtRecordIndex: u32, attributes: *$T)",                                                    .HitObjectRecordFromQueryEXT                     },
   .{ "HitObjectRecordFromQuery",                  "(h: *HitObject, q: *RayQuery, sbtRecordIndex: u32, attributes: *$T, hitKind: u32)",                                      .HitObjectRecordFromQueryEXT                     },
   .{ "HitObjectRecordMiss",                       "(h: *HitObject, rayFlags: RayFlags, missIndex: u32, rayOrigin: f32x3, rayTMin: f32, rayDirection: f32x3, rayTMax: f32)", .HitObjectRecordMissEXT                         },
   .{ "HitObjectRecordEmpty",                      "(h: *HitObject)",                                                                                                        .HitObjectRecordEmptyEXT                        },
   .{ "HitObjectExecuteShader",                    "(h: *HitObject, payload: *$T)",                                                                                          .HitObjectExecuteShaderEXT                      },
   .{ "HitObjectReorderExecuteShader",             "(h: *HitObject, payload: *$T)",                                                                                          .HitObjectReorderExecuteShaderEXT               },
   .{ "HitObjectReorderExecuteShader",             "(h: *HitObject, payload: *$T, hint: u32, bits: u32)",                                                                    .HitObjectReorderExecuteShaderEXT               },
   .{ "HitObjectGetAttributes",                    "(h: *HitObject, attributes: *$T)",                                                                                       .HitObjectGetAttributesEXT                      },
   .{ "HitObjectSetShaderBindingTableRecordIndex", "(h: *HitObject, sbtRecordIndex: u32)",                                                                                   .HitObjectSetShaderBindingTableRecordIndexEXT   },
   .{ "HitObjectIsEmpty",                          "(h: *HitObject) -> bool",                                                                                                .HitObjectIsEmptyEXT                            },
   .{ "HitObjectIsHit",                            "(h: *HitObject) -> bool",                                                                                                .HitObjectIsHitEXT                              },
   .{ "HitObjectIsMiss",                           "(h: *HitObject) -> bool",                                                                                                .HitObjectIsMissEXT                             },
   .{ "HitObjectGetRayTMin",                       "(h: *HitObject) -> f32",                                                                                                 .HitObjectGetRayTMinEXT                         },
   .{ "HitObjectGetRayTMax",                       "(h: *HitObject) -> f32",                                                                                                 .HitObjectGetRayTMaxEXT                         },
   .{ "HitObjectGetRayFlags",                      "(h: *HitObject) -> RayFlags",                                                                                            .HitObjectGetRayFlagsEXT                        },
   .{ "HitObjectGetWorldRayOrigin",                "(h: *HitObject) -> f32x3",                                                                                               .HitObjectGetWorldRayOriginEXT                  },
   .{ "HitObjectGetWorldRayDirection",             "(h: *HitObject) -> f32x3",                                                                                               .HitObjectGetWorldRayDirectionEXT               },
   .{ "HitObjectGetObjectRayOrigin",               "(h: *HitObject) -> f32x3",                                                                                               .HitObjectGetObjectRayOriginEXT                 },
   .{ "HitObjectGetObjectRayDirection",            "(h: *HitObject) -> f32x3",                                                                                               .HitObjectGetObjectRayDirectionEXT              },
   .{ "HitObjectGetObjectToWorld",                 "(h: *HitObject) -> f32x3x4",                                                                                             .HitObjectGetObjectToWorldEXT                   },
   .{ "HitObjectGetWorldToObject",                 "(h: *HitObject) -> f32x3x4",                                                                                             .HitObjectGetWorldToObjectEXT                   },
   .{ "HitObjectGetInstanceCustomIndex",           "(h: *HitObject) -> s32",                                                                                                 .HitObjectGetInstanceCustomIndexEXT             },
   .{ "HitObjectGetInstanceId",                    "(h: *HitObject) -> s32",                                                                                                 .HitObjectGetInstanceIdEXT                      },
   .{ "HitObjectGetGeometryIndex",                 "(h: *HitObject) -> s32",                                                                                                 .HitObjectGetGeometryIndexEXT                   },
   .{ "HitObjectGetPrimitiveIndex",                "(h: *HitObject) -> s32",                                                                                                 .HitObjectGetPrimitiveIndexEXT                  },
   .{ "HitObjectGetHitKind",                       "(h: *HitObject) -> u32",                                                                                                 .HitObjectGetHitKindEXT                         },
   .{ "HitObjectGetShaderBindingTableRecordIndex", "(h: *HitObject) -> u32",                                                                                                 .HitObjectGetShaderBindingTableRecordIndexEXT   },
   .{ "HitObjectGetShaderRecordBufferHandle",      "(h: *HitObject) -> u32x2",                                                                                               .HitObjectGetShaderRecordBufferHandleEXT        },

   // the invocations are reordered by the hint (its lowest bits bits are used) and/or by the hit object, so the ones that run the same shader are together. only in rgen shaders
   .{ "ReorderThread",                             "(hint: u32, bits: u32)",                                                                                                 .ReorderThreadWithHintEXT                       },
   .{ "ReorderThread",                             "(h: *HitObject)",                                                                                                        .ReorderThreadWithHitObjectEXT                  },
   .{ "ReorderThread",                             "(h: *HitObject, hint: u32, bits: u32)",                                                                                  .ReorderThreadWithHitObjectEXT                  },
];

#insert #run -> string {
   builder: String_Builder;
   for HIT_OBJECT_INTRINSICS {
      returnIndex := find_index_from_right(it.signature, "-> ");
      if (returnIndex == -1) {
         print_to_builder(*builder, "% :: % { } @%\n", it.name, it.signature, INTRINSIC_NOTE_NAME);
      } else {
         returnType := slice(it.signature, returnIndex + 3, it.signature.count - returnIndex - 3);
         print_to_builder(*builder, "% :: % { r: %; return r; } @%\n", it.name, it.signature, returnType, INTRINSIC_NOTE_NAME);
      }
   }
   return builder_to_string(*builder);
};

// the invocation doesnt write its outputs, but it keeps running as a helper invocation so the derivatives of the others stay valid (like discard in hlsl)
#insert #run sprint("% :: () { } @%", DISCARD_FUNCTION_NAME, INTRINSIC_NOTE_NAME);

// waits for all the invocations of the workgroup, and makes the writes to workgroup memory before it visible to them
#insert #run sprint("% :: () { } @%", BARRIER_FUNCTION_NAME, INTRINSIC_NOTE_NAME);

// waits for all the invocations of the subgroup, and makes the writes to memory before it visible to them
#insert #run sprint("% :: () { } @%", SUBGROUP_BARRIER_FUNCTION_NAME, INTRINSIC_NOTE_NAME);

// any hit shaders: the hit is ignored / the ray stops here. both end the shader
#insert #run sprint("% :: () { } @%", IGNORE_INTERSECTION_FUNCTION_NAME, INTRINSIC_NOTE_NAME);
#insert #run sprint("% :: () { } @%", TERMINATE_RAY_FUNCTION_NAME, INTRINSIC_NOTE_NAME);

// intersection shaders: reports a hit at hitT (what the hit attribute variable has is given to the hit shaders). returns true if the hit is accepted
#insert #run sprint("% :: (hitT: f32, hitKind: u32) -> bool { r: bool; return r; } @%", REPORT_INTERSECTION_FUNCTION_NAME, INTRINSIC_NOTE_NAME);

// prints like jai's print: % is the next argument, %1 %2... an argument by its position, \% is a % sign. the format must be a constant string.
// it is DebugPrintf of NonSemantic.DebugPrintf, the validation layers print it. the printf specifier of an argument comes from its type. on the cpu it is print.
#insert #run sprint("% :: (format: string, args: .. Any) { print(format, ..args); } @%", DEBUG_PRINT_FUNCTION_NAME, INTRINSIC_NOTE_NAME);

// runs the callable shader at sbtIndex of the shader binding table. data is the address of a @callabledata variable, the callable shader gets it as its @callabledatain variable
#insert #run sprint("% :: (sbtIndex: u32, data: *$T) { } @%", EXECUTE_CALLABLE_FUNCTION_NAME, INTRINSIC_NOTE_NAME);

// atomics on a pointer to buffer memory or to a workgroup variable. they return the value that was there before. the bodies are the cpu implementations (see cpu.jai)
#insert #run -> string {
   builder: String_Builder;

   TYPES :: string.["s32", "u32", "s64", "u64"];
   FUNCTIONS :: string.[ATOMIC_ADD_FUNCTION_NAME, ATOMIC_MIN_FUNCTION_NAME, ATOMIC_MAX_FUNCTION_NAME, ATOMIC_AND_FUNCTION_NAME, ATOMIC_OR_FUNCTION_NAME, ATOMIC_XOR_FUNCTION_NAME, ATOMIC_EXCHANGE_FUNCTION_NAME];

   for type: TYPES {
      for name: FUNCTIONS {
         print_to_builder(*builder, "% :: (pointer: *%, value: %) -> % { % } @%\n", name, type, type, type, AtomicCpuBody(name), INTRINSIC_NOTE_NAME);
      }

      // stores value if the value at pointer is comparator
      print_to_builder(*builder, "% :: (pointer: *%, comparator: %, value: %) -> % { % } @%\n", ATOMIC_COMPARE_EXCHANGE_FUNCTION_NAME, type, type, type, type, AtomicCpuBody(ATOMIC_COMPARE_EXCHANGE_FUNCTION_NAME), INTRINSIC_NOTE_NAME);
   }

   return builder_to_string(*builder);
};

// ^^^^^^ intrinsics ^^^^^^^^^

// the stage a shader is compiled for. the order is the order of ShaderStages
ShaderType :: enum {
   Task;
   Mesh;
   Fragment;
   Compute;
   Rgen;
   Rchit;
   Rmiss;
   Rahit;   // any hit
   Rint;    // intersection
   Rcall;   // callable
}

// the primitives a mesh shader outputs
PrimitiveTopology :: enum {
   Points;
   Lines;
   Triangles;
}

#scope_module

// the note of the intrinsic procedures and of the variables of this module (images, meshvertices, workgroupid...).
// the compiler finds the variables by their name and this note, so the variables of the program that have the same names are not taken for them (see ProcessMessage).
INTRINSIC_NOTE_NAME :: "intrinsic";

MESH_VERTICES_NAME                        :: "meshvertices";
MESH_PRIMITIVES_NAME                      :: "meshprimitives";
MESH_TRIANGLES_NAME                       :: "meshtriangles";
SET_MESH_OUTPUTS_NAME                     :: "SetMeshOutputs";
EMIT_MESH_TASKS_NAME                      :: "EmitMeshTasks";
MESH_PIPELINE_PUSH_DATA_VARIABLE_NAME     :: "__mesh_push_data__";   // this is not gonna be used by the user.
                                                                     // so i picked a name hoping that it is not gonna clash with other variables
RTX_PIPELINE_PUSH_DATA_VARIABLE_NAME      :: "__rtx_push_data__";
IMAGE_HEAP_VARIABLE_NAME                  :: "images";
SAMPLER_HEAP_VARIABLE_NAME                :: "samplers";
TEXTURE_FLOAT_2D_FUNCTION_NAME            :: "texture";
TEXTURE_FLOAT_3D_FUNCTION_NAME            :: "texture3d";
TEXTURE_INT_2D_FUNCTION_NAME              :: "texturei";
TEXTURE_FLOAT_2D_LOD_FUNCTION_NAME        :: "texturelod";
IMAGE_WRITE_FUNCTION_NAME                 :: "ImageWrite";
TEXTURE_BIAS_FUNCTION_NAME                :: "texturebias";
TEXTURE_GRAD_FUNCTION_NAME                :: "texturegrad";
TEXTURE_GATHER_FUNCTION_NAME              :: "texturegather";
TEXTURE_CMP_FUNCTION_NAME                 :: "texturecmp";
TEXTURE_CMP_LOD_FUNCTION_NAME             :: "texturecmplod";
TEXEL_FETCH_FUNCTION_NAME                 :: "texelfetch";
TEXEL_FETCH_INT_FUNCTION_NAME             :: "texelfetchi";
TEXTURE_SIZE_FUNCTION_NAME                :: "texturesize";
TEXTURE_LEVELS_FUNCTION_NAME              :: "texturelevels";
TEXTURE_LOD_3D_FUNCTION_NAME              :: "texturelod3d";
TEXTURE_BIAS_3D_FUNCTION_NAME             :: "texturebias3d";
TEXTURE_GRAD_3D_FUNCTION_NAME             :: "texturegrad3d";
TEXEL_FETCH_3D_FUNCTION_NAME              :: "texelfetch3d";
TEXTURE_SIZE_3D_FUNCTION_NAME             :: "texturesize3d";
TEXTURE_LEVELS_3D_FUNCTION_NAME           :: "texturelevels3d";
TEXTURE_CUBE_FUNCTION_NAME                :: "texturecube";
TEXTURE_LOD_CUBE_FUNCTION_NAME            :: "texturelodcube";
TEXTURE_BIAS_CUBE_FUNCTION_NAME           :: "texturebiascube";
TEXTURE_GRAD_CUBE_FUNCTION_NAME           :: "texturegradcube";
TEXTURE_GATHER_CUBE_FUNCTION_NAME         :: "texturegathercube";
TEXTURE_CMP_CUBE_FUNCTION_NAME            :: "texturecmpcube";
TEXTURE_CMP_LOD_CUBE_FUNCTION_NAME        :: "texturecmplodcube";
TEXTURE_SIZE_CUBE_FUNCTION_NAME           :: "texturesizecube";
TEXTURE_LEVELS_CUBE_FUNCTION_NAME         :: "texturelevelscube";
TEXTURE_ARRAY_FUNCTION_NAME               :: "texturearray";
TEXTURE_LOD_ARRAY_FUNCTION_NAME           :: "texturelodarray";
TEXTURE_BIAS_ARRAY_FUNCTION_NAME          :: "texturebiasarray";
TEXTURE_GRAD_ARRAY_FUNCTION_NAME          :: "texturegradarray";
TEXTURE_GATHER_ARRAY_FUNCTION_NAME        :: "texturegatherarray";
TEXTURE_CMP_ARRAY_FUNCTION_NAME           :: "texturecmparray";
TEXTURE_CMP_LOD_ARRAY_FUNCTION_NAME       :: "texturecmplodarray";
TEXEL_FETCH_ARRAY_FUNCTION_NAME           :: "texelfetcharray";
TEXTURE_SIZE_ARRAY_FUNCTION_NAME          :: "texturesizearray";
TEXTURE_LEVELS_ARRAY_FUNCTION_NAME        :: "texturelevelsarray";
IMAGE_READ_FUNCTION_NAME                  :: "ImageRead";
IMAGE_SIZE_FUNCTION_NAME                  :: "ImageSize";
COMPUTE_PIPELINE_PUSH_DATA_VARIABLE_NAME  :: "__compute_push_data__";
TRACE_RAY_FUNCTION_NAME                   :: "TraceRay";
TLAS_PARAMETER_NAME                       :: "tlas";   // see GenerateTlasFromAddress
BARRIER_FUNCTION_NAME                     :: "Barrier";                  // OpControlBarrier, like barrier() in glsl
SUBGROUP_BARRIER_FUNCTION_NAME            :: "SubgroupBarrier";          // OpControlBarrier with subgroup scope, like subgroupBarrier() in glsl
IGNORE_INTERSECTION_FUNCTION_NAME         :: "IgnoreIntersection";       // OpIgnoreIntersectionKHR, any hit shaders
TERMINATE_RAY_FUNCTION_NAME               :: "TerminateRay";             // OpTerminateRayKHR, any hit shaders
REPORT_INTERSECTION_FUNCTION_NAME         :: "ReportIntersection";       // OpReportIntersectionKHR, intersection shaders
EXECUTE_CALLABLE_FUNCTION_NAME            :: "ExecuteCallable";          // OpExecuteCallableKHR
DEBUG_PRINT_FUNCTION_NAME                 :: "DebugPrint";               // OpExtInst DebugPrintf of NonSemantic.DebugPrintf
DISCARD_FUNCTION_NAME                     :: "discard";                  // OpDemoteToHelperInvocation, like discard in hlsl
ATOMIC_ADD_FUNCTION_NAME                  :: "AtomicAdd";
ATOMIC_MIN_FUNCTION_NAME                  :: "AtomicMin";
ATOMIC_MAX_FUNCTION_NAME                  :: "AtomicMax";
ATOMIC_AND_FUNCTION_NAME                  :: "AtomicAnd";
ATOMIC_OR_FUNCTION_NAME                   :: "AtomicOr";
ATOMIC_XOR_FUNCTION_NAME                  :: "AtomicXor";
ATOMIC_EXCHANGE_FUNCTION_NAME             :: "AtomicExchange";
ATOMIC_COMPARE_EXCHANGE_FUNCTION_NAME     :: "AtomicCompareExchange";

// qualifiers
FUNCTION_QUALIFIER                        :: "function";
PHYSICAL_STORAGE_BUFFER_QUALIFIER         :: "physical";
RAY_PAYLOAD_QUALIFIER                     :: "payload";
INCOMING_RAY_PAYLOAD_QUALIFIER            :: "payloadin"; // IncomingRayPayloadKHR
WORKGROUP_QUALIFIER                       :: "workgroup"; // Workgroup storage class, shared by the invocations of a workgroup
TASK_PAYLOAD_QUALIFIER                    :: "taskpayload"; // TaskPayloadWorkgroupEXT, what a task shader gives to the mesh shaders it launches. the same note in both, it is read only in the mesh shader
HIT_ATTRIBUTE_QUALIFIER                   :: "hitattribute";   // HitAttributeKHR. the barycentrics of a triangle hit, or what an intersection shader reports
CALLABLE_DATA_QUALIFIER                   :: "callabledata";   // CallableDataKHR. the data ExecuteCallable gives to the callable shader
INCOMING_CALLABLE_DATA_QUALIFIER          :: "callabledatain"; // IncomingCallableDataKHR. the data of a callable shader
HIT_OBJECT_ATTRIBUTE_QUALIFIER            :: "hitobjectattribute"; // HitObjectAttributeEXT. the hit attributes of a hit object (HitObjectRecordFromQuery, HitObjectGetAttributes)

MeshPipelinePushData :: struct {
   taskData:      *void;
   meshData:      *void;
   fragmentData:  *void;
}

RtxPipelinePushData :: struct {
   rgenData:   *void;
   rchitData:  *void;
   rmissData:  *void;
   rahitData:  *void;
   rintData:   *void;
   rcallData:  *void;
}

ComputePipelinePushData :: struct {
   computeData: *void;
}

#insert #run sprint("%: MeshPipelinePushData; @%", MESH_PIPELINE_PUSH_DATA_VARIABLE_NAME, INTRINSIC_NOTE_NAME);
#insert #run sprint("%: RtxPipelinePushData; @%", RTX_PIPELINE_PUSH_DATA_VARIABLE_NAME, INTRINSIC_NOTE_NAME);
#insert #run sprint("%: ComputePipelinePushData; @%", COMPUTE_PIPELINE_PUSH_DATA_VARIABLE_NAME, INTRINSIC_NOTE_NAME);

__Sampler__ :: struct { } // OpTypeSampler
__Image__ :: struct { } // base type for what OpTypeImage returns. i dont use this.
                        // this is here to make the jai compiler happy. so it typechecks and stuff.
                        // i use TypeInfoImage.
                        //       - apila, 03/05/26
__TLAS__ :: struct { } // OpTypeAccelerationStructureKHR

