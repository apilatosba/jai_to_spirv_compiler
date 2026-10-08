#import "Basic";
#import "Compiler";
#import "Math";
#import "String";
#import "Hash_Table";
#import "Queue";
#import "Hash";
#import "File";
#import "SpirvTools";
#import "SpirvHeaders";


#module_parameters (SPIRV_BUILDER_TYPE := SpirvBuilderType.Byte, DESCRIPTOR_STRIDE_MODE := DescriptorStrideMode.Byte) () {
   SpirvBuilderType :: enum {
      Byte;
      String;
   }

   DescriptorStrideMode :: enum {
      Byte;
      DescriptorSize;
   }
};

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

operator *  :: (m: mat4, v: f32x4)  -> f32x4 { return .{}; };
operator *  :: (m: mat3, v: f32x3)  -> f32x3 { return .{}; };
operator *  :: (m: f32x3x4, v: f32x4) -> f32x3 { return .{}; };
operator *  :: (a: mat4, b: mat4)   -> mat4  { return .{}; }; // this is not valid jai operation unfortunately :(  - apila, 14/05/26

// arithmetic on vectors. these only exist so that jai typechecks the shader, the backend generates the instructions from the operator node itself.
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
         print_to_builder(*builder, "operator % :: (a: %, b: %) -> % { return .{}; }\n", op, v.name, v.name,   v.name);
         print_to_builder(*builder, "operator % :: (a: %, b: %) -> % { return .{}; }\n", op, v.name, v.scalar, v.name);
         print_to_builder(*builder, "operator % :: (a: %, b: %) -> % { return .{}; }\n", op, v.scalar, v.name, v.name);
      }

      if (v.isSigned) print_to_builder(*builder, "operator - :: (a: %) -> % { return .{}; }\n", v.name, v.name);
   }

   return builder_to_string(*builder);
};

#insert #run sprint("%: [] MeshPerVertex;", MESH_VERTICES_NAME); // gl_MeshVerticesEXT
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
   for MESH_PRIMITIVE_INDICES  print_to_builder(*builder, "%: [] %;\n", it.name, it.typeName);
   return builder_to_string(*builder);
};
#insert #run sprint("%: [] __Image__;", IMAGE_HEAP_VARIABLE_NAME);
#insert #run sprint("%: [] __TLAS__;", TLAS_HEAP_VARIABLE_NAME);
#insert #run sprint("%: [] __Sampler__;", SAMPLER_HEAP_VARIABLE_NAME);

#insert #run sprint("% :: (vertexCount: u32, primitiveCount: u32) {} @%", SET_MESH_OUTPUTS_NAME, INTRINSIC_FUNCTION_NOTE_NAME); // SetMeshOutputsEXT

// each texture variant corresponds to sampling of one single OpTypeImage.
#insert #run sprint("% :: (image: __Image__, sampler: __Sampler__, uv: f32x2)            -> f32x4 { return .{}; } @%", TEXTURE_FLOAT_2D_FUNCTION_NAME, INTRINSIC_FUNCTION_NOTE_NAME);
#insert #run sprint("% :: (image: __Image__, sampler: __Sampler__, uv: f32x2, lod: f32)  -> f32x4 { return .{}; } @%", TEXTURE_FLOAT_2D_LOD_FUNCTION_NAME, INTRINSIC_FUNCTION_NOTE_NAME);
#insert #run sprint("% :: (image: __Image__, sampler: __Sampler__, uv: f32x2)            -> s32x4 { return .{}; } @%", TEXTURE_INT_2D_FUNCTION_NAME, INTRINSIC_FUNCTION_NOTE_NAME);

// overloads determine the type of some stuff.
// type of texel determines the sampled type of OpTypeImage.
#insert #run sprint("% :: (image: __Image__, coordinate: s32x2, texel: f32x4) { } @%", IMAGE_WRITE_FUNCTION_NAME, INTRINSIC_FUNCTION_NOTE_NAME);

// sampling variants. bias and the depth compare without a lod only exist in fragment shaders (the lod is implicit). the component of gather must be a constant.
#insert #run sprint("% :: (image: __Image__, sampler: __Sampler__, uv: f32x2, bias: f32)                   -> f32x4 { return .{}; } @%", TEXTURE_BIAS_FUNCTION_NAME, INTRINSIC_FUNCTION_NOTE_NAME);
#insert #run sprint("% :: (image: __Image__, sampler: __Sampler__, uv: f32x2, ddx: f32x2, ddy: f32x2)      -> f32x4 { return .{}; } @%", TEXTURE_GRAD_FUNCTION_NAME, INTRINSIC_FUNCTION_NOTE_NAME);
#insert #run sprint("% :: (image: __Image__, sampler: __Sampler__, uv: f32x2, component: s32)              -> f32x4 { return .{}; } @%", TEXTURE_GATHER_FUNCTION_NAME, INTRINSIC_FUNCTION_NOTE_NAME);
#insert #run sprint("% :: (image: __Image__, sampler: __Sampler__, uv: f32x2, reference: f32)              -> f32   { return 0;   } @%", TEXTURE_CMP_FUNCTION_NAME, INTRINSIC_FUNCTION_NOTE_NAME);
#insert #run sprint("% :: (image: __Image__, sampler: __Sampler__, uv: f32x2, reference: f32, lod: f32)    -> f32   { return 0;   } @%", TEXTURE_CMP_LOD_FUNCTION_NAME, INTRINSIC_FUNCTION_NOTE_NAME);

// sampled images without a sampler
#insert #run sprint("% :: (image: __Image__, coordinate: s32x2, lod: s32) -> f32x4 { return .{}; } @%", TEXEL_FETCH_FUNCTION_NAME, INTRINSIC_FUNCTION_NOTE_NAME);
#insert #run sprint("% :: (image: __Image__, coordinate: s32x2, lod: s32) -> s32x4 { return .{}; } @%", TEXEL_FETCH_INT_FUNCTION_NAME, INTRINSIC_FUNCTION_NOTE_NAME);
#insert #run sprint("% :: (image: __Image__, lod: s32) -> s32x2 { return .{}; } @%", TEXTURE_SIZE_FUNCTION_NAME, INTRINSIC_FUNCTION_NOTE_NAME);
#insert #run sprint("% :: (image: __Image__) -> s32 { return 0; } @%", TEXTURE_LEVELS_FUNCTION_NAME, INTRINSIC_FUNCTION_NOTE_NAME);

// storage images (like ImageWrite)
#insert #run sprint("% :: (image: __Image__, coordinate: s32x2) -> f32x4 { return .{}; } @%", IMAGE_READ_FUNCTION_NAME, INTRINSIC_FUNCTION_NOTE_NAME);
#insert #run sprint("% :: (image: __Image__) -> s32x2 { return .{}; } @%", IMAGE_SIZE_FUNCTION_NAME, INTRINSIC_FUNCTION_NOTE_NAME);

// built in input variables (gl_WorkGroupID, gl_LaunchIDEXT...).
// they are only declared in the entry point if the shader uses them, and using one in a stage that doesnt have it is an error.
BuiltinVariable :: struct {
   name:          string;
   typeName:      string;
   builtIn:       SpvBuiltIn;
   stages:        ShaderStages;
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
}

// the types are what spirv requires. for the indices spirv only requires a 32 bit integer, they are s32 like in glsl.
BUILTIN_VARIABLES :: BuiltinVariable.[
   .{ "workgroupid",          "u32x3",    .WorkgroupId,              .Task | .Mesh | .Compute },
   .{ "localinvocationid",    "u32x3",    .LocalInvocationId,        .Task | .Mesh | .Compute },
   .{ "globalinvocationid",   "u32x3",    .GlobalInvocationId,       .Task | .Mesh | .Compute },
   .{ "localinvocationindex", "u32",      .LocalInvocationIndex,     .Task | .Mesh | .Compute },
   .{ "numworkgroups",        "u32x3",    .NumWorkgroups,            .Task | .Mesh | .Compute },
   .{ "launchid",             "u32x3",    .LaunchIdKHR,              .Rgen | .Rchit | .Rmiss  },
   .{ "launchsize",           "u32x3",    .LaunchSizeKHR,            .Rgen | .Rchit | .Rmiss  },
   .{ "worldrayorigin",       "f32x3",    .WorldRayOriginKHR,        .Rchit | .Rmiss          },
   .{ "worldraydirection",    "f32x3",    .WorldRayDirectionKHR,     .Rchit | .Rmiss          },
   .{ "objectrayorigin",      "f32x3",    .ObjectRayOriginKHR,       .Rchit                   },
   .{ "objectraydirection",   "f32x3",    .ObjectRayDirectionKHR,    .Rchit                   },
   .{ "raytmin",              "f32",      .RayTminKHR,               .Rchit | .Rmiss          },
   .{ "raytmax",              "f32",      .RayTmaxKHR,               .Rchit | .Rmiss          },
   .{ "incomingrayflags",     "u32",      .IncomingRayFlagsKHR,      .Rchit | .Rmiss          },
   .{ "hitkind",              "u32",      .HitKindKHR,               .Rchit                   },
   .{ "instancecustomindex",  "s32",      .InstanceCustomIndexKHR,   .Rchit                   },
   .{ "instanceid",           "s32",      .InstanceId,               .Rchit                   },
   .{ "geometryindex",        "s32",      .RayGeometryIndexKHR,      .Rchit                   },
   .{ "primitiveid",          "s32",      .PrimitiveId,              .Rchit                   },
   .{ "objecttoworld",        "f32x3x4",  .ObjectToWorldKHR,         .Rchit                   },
   .{ "worldtoobject",        "f32x3x4",  .WorldToObjectKHR,         .Rchit                   },
   .{ "fragcoord",            "f32x4",    .FragCoord,                .Fragment                },
   .{ "frontfacing",          "bool",     .FrontFacing,              .Fragment                },
   .{ "sampleid",             "s32",      .SampleId,                 .Fragment                }, // SampleRateShading
   .{ "helperinvocation",     "bool",     .HelperInvocation,         .Fragment                },
];

#insert #run -> string {
   builder: String_Builder;
   for BUILTIN_VARIABLES  print_to_builder(*builder, "%: %;\n", it.name, it.typeName);
   return builder_to_string(*builder);
};

// the math intrinsics (hlsl names). see MATH_INTRINSICS
#insert #run -> string {
   builder: String_Builder;

   for MATH_INTRINSICS {
      for signature: it.signatures {
         for type: signature.types {
            // T is the type, C is the component type of T (f32 for f32x3), M is the vector type of the matrix T (f32x3 for mat3)
            component := type;
            if (find_index_from_left(type, "x") != -1) component = slice(type, 0, find_index_from_left(type, "x"));

            vector := type;
            if (begins_with(type, "mat")) vector = tprint("f32x%", slice(type, 3, 1));

            header := replace(replace(replace(signature.signature, "T", type), "C", component), "M", vector);
            returnType := slice(header, find_index_from_right(header, "-> ") + 3, header.count);
            print_to_builder(*builder, "% :: % { r: %; return r; } @%\n", it.name, header, returnType, INTRINSIC_FUNCTION_NOTE_NAME);
         }
      }
   }

   return builder_to_string(*builder);
};

// maybe rayFlags should be an enum. tho i never dealt with enums so im skipping it for now.
// payload is the address of the payload variable.
//          - apila, 07/09/26
#insert #run sprint("% :: (tlas: __TLAS__, rayFlags: u32, cullMask: u32, sbtOffset: u32, sbtStride: u32, missIndex: u32, rayOrigin: f32x3, rayTMin: f32, rayDirection: f32x3, rayTMax: f32, payload: *$T) { } @%", TRACE_RAY_FUNCTION_NAME, INTRINSIC_FUNCTION_NOTE_NAME);

//
// the math intrinsics have the names of hlsl. each is a GLSL.std.450 instruction or a spirv instruction.
// the overloads are declared from the signatures. in a signature T is replaced by each of the types, C by the component type of T and M by the vector type of the matrix T.
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

// the integer overloads are only 32 bit. with 64 bit ones too min(x, 3) is ambiguous for jai (x: s32 can be s64 too, as the literal can be s32).
FLOATS            :: string.["f32", "f32x2", "f32x3", "f32x4"];
FLOAT_VECTORS     :: string.["f32x2", "f32x3", "f32x4"];
SIGNED_INTEGERS   :: string.["s32", "s32x2", "s32x3", "s32x4"];
INTEGER_VECTORS   :: string.["s32x2", "s32x3", "s32x4", "u32x2", "u32x3", "u32x4"];
INTEGERS          :: string.["s32", "s32x2", "s32x3", "s32x4", "u32", "u32x2", "u32x3", "u32x4"];
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
];

GetMathIntrinsic :: (name: string) -> *MathIntrinsic {
   for * MATH_INTRINSICS  if (it.name == name) return it;
   return null;
}

GenerateMathIntrinsic :: (data: *CompilationData, intrinsic: *MathIntrinsic, cpc: *Code_Procedure_Call, header: *Code_Procedure_Header, general: *BuilderType, function: *BuilderType, currentFunction: *Code_Procedure_Header, spirvType: **Type_Info) -> SSAId {
   procedureType := cast(*Type_Info_Procedure) header.type;
   assert(procedureType.return_types.count == 1);
   resultType := procedureType.return_types[0];
   resultInfo, resultIsNumeric := GetNumericInfo(resultType);

   arguments: [..] SSAId;
   arguments.allocator = temp;
   argumentTypes: [..] *Type_Info;
   argumentTypes.allocator = temp;

   for cpc.arguments_sorted {
      argumentType := header.arguments[it_index].type;
      argumentSSAId := GenerateInstructions(data, it, general, function, currentFunction, .{ spirvShouldHaveBeenType = argumentType });

      // clamp(v, 0, 1) is clamp(v, .{0, 0, 0}, .{1, 1, 1})
      argumentInfo, argumentIsNumeric := GetNumericInfo(argumentType);
      if (intrinsic.broadcast && resultIsNumeric && argumentIsNumeric && argumentInfo.components == 1 && resultInfo.components > 1) {
         argumentSSAId = Broadcast(data, function, argumentSSAId, resultType);
         argumentType = resultType;
      }

      array_add(*arguments, argumentSSAId);
      array_add(*argumentTypes, argumentType);
   }

   // saturate(x) is clamp(x, 0, 1)
   if (intrinsic.name == "saturate") {
      zero := GetSSAId(data, .{ type = .FloatLiteral, floatLiteral = 0 });
      one := GetSSAId(data, .{ type = .FloatLiteral, floatLiteral = 1 });
      if (resultInfo.components > 1) {
         zero = Broadcast(data, function, zero, resultType);
         one = Broadcast(data, function, one, resultType);
      }
      array_add(*arguments, zero, one);
   }

   resultSSAId := GetNextSSAId(data);
   resultTypeSSAId := GetSSAId(data, .{ type = ._Type, _type = resultType });
   operands: [..] Any;
   operands.allocator = temp;

   if (intrinsic.coreOp != .Nop) {
      op := intrinsic.coreOp;

      // mul is one of three instructions depending on what is multiplied
      if (op == .MatrixTimesMatrix) {
         leftIsMatrix := IsMatrixType(argumentTypes[0]);
         rightIsMatrix := IsMatrixType(argumentTypes[1]);
         if (leftIsMatrix && !rightIsMatrix) op = .MatrixTimesVector;
         if (!leftIsMatrix && rightIsMatrix) op = .VectorTimesMatrix;
      }

      if (op == .DPdx || op == .DPdy || op == .Fwidth) {
         assert(data.shaderType == .Fragment, "% only exists in fragment shaders. loc: %", intrinsic.name, GetLocationString(cpc));
      }

      array_add(*operands, resultTypeSSAId, resultSSAId);
      for arguments  array_add(*operands, ac(it));
      WriteSingleInstructionIfReachable(function, *data.isBlockReachable, op, .. operands);
   } else {
      // the kind of the components decides the instruction. for the ones that return a scalar of vectors (length...) it is the argument
      // matrices are of floats
      kindType := ifx resultIsNumeric then resultType else argumentTypes[0];
      kindInfo, kindIsNumeric := GetNumericInfo(kindType);
      if (!kindIsNumeric && IsMatrixType(kindType)) kindInfo.kind = .Float;

      op: GLSLstd450;
      if kindInfo.kind == {
         case .Float;      op = intrinsic.floatOp;
         case .Signed;     op = intrinsic.signedOp;
         case .Unsigned;   op = intrinsic.unsignedOp;
      }
      assert(op != .Bad, "% doesnt take %. loc: %", intrinsic.name, TypeName(kindType), GetLocationString(cpc));

      array_add(*operands, resultTypeSSAId, resultSSAId, data.glslStd450, op);
      for arguments  array_add(*operands, ac(it));
      WriteSingleInstructionIfReachable(function, *data.isBlockReachable, .ExtInst, .. operands);
   }

   spirvType.* = resultType;
   return resultSSAId;
}

// a vector whose components are the scalar
Broadcast :: (data: *CompilationData, b: *BuilderType, scalarSSAId: SSAId, vectorType: *Type_Info) -> SSAId {
   info := GetNumericInfo(vectorType);

   resultSSAId := GetNextSSAId(data);
   operands: [..] Any;
   operands.allocator = temp;
   array_add(*operands, GetSSAId(data, .{ type = ._Type, _type = vectorType }), resultSSAId);
   for 1..info.components  array_add(*operands, scalarSSAId);
   WriteSingleInstructionIfReachable(b, *data.isBlockReachable, .CompositeConstruct, .. operands);

   return resultSSAId;
}

// the invocation doesnt write its outputs, but it keeps running as a helper invocation so the derivatives of the others stay valid (like discard in hlsl)
#insert #run sprint("% :: () { } @%", DISCARD_FUNCTION_NAME, INTRINSIC_FUNCTION_NOTE_NAME);

// texturebias, texturegrad, texturegather, texturecmp, texturecmplod, texelfetch, texelfetchi, texturesize, texturelevels, ImageRead, ImageSize. all 2D.
GenerateTextureFunction :: (data: *CompilationData, name: string, cpc: *Code_Procedure_Call, header: *Code_Procedure_Header, general: *BuilderType, function: *BuilderType, currentFunction: *Code_Procedure_Header, spirvType: **Type_Info) -> SSAId {
   arguments := cpc.arguments_sorted;
   resultType := (cast(*Type_Info_Procedure) header.type).return_types[0];
   resultTypeSSAId := GetSSAId(data, .{ type = ._Type, _type = resultType });
   resultSSAId := GetNextSSAId(data);
   spirvType.* = resultType;

   Argument :: (index: int) -> SSAId #expand {
      return GenerateInstructions(`data, `arguments[index], `general, `function, `currentFunction, .{ spirvShouldHaveBeenType = `header.arguments[index].type });
   }

   isDepth   := name == TEXTURE_CMP_FUNCTION_NAME || name == TEXTURE_CMP_LOD_FUNCTION_NAME;
   isStorage := name == IMAGE_READ_FUNCTION_NAME || name == IMAGE_SIZE_FUNCTION_NAME;
   isInteger := name == TEXEL_FETCH_INT_FUNCTION_NAME;
   usesSampler := header.arguments.count > 1 && CompareType(header.arguments[1].type, type_info(__Sampler__));

   if (name == TEXTURE_BIAS_FUNCTION_NAME || name == TEXTURE_CMP_FUNCTION_NAME) {
      assert(data.shaderType == .Fragment, "% only exists in fragment shaders (the lod is implicit). loc: %", name, GetLocationString(cpc));
   }

   // the type of the image is what it is used as. the sampled type is the type of the components of what is read from it.
   imageType := New(TypeInfoImage);
   imageType.* = .{
      sampledType       = ifx isInteger then cast(*Type_Info) s32 else cast(*Type_Info) f32,
      dimensionality    = ._2D,
      depth             = xx isDepth,
      arrayed           = 0,
      ms                = 0,
      sampled           = ifx isStorage then 2 else 1,
      imageFormat       = .Unknown,
   };

   imageSSAId := GenerateInstructions(data, arguments[0], general, function, currentFunction, .{ accessChainBaseArrayElementTypeIfImageHeap = imageType });

   if (usesSampler) {
      sampledImageType := New(TypeInfoSampledImage);
      sampledImageType.image = imageType;

      samplerSSAId := GenerateInstructions(data, arguments[1], general, function, currentFunction);
      sampledImageSSAId := GetNextSSAId(data);
      WriteSingleInstructionIfReachable(function, *data.isBlockReachable, .SampledImage, GetSSAId(data, .{ type = ._Type, _type = sampledImageType }), sampledImageSSAId, imageSSAId, samplerSSAId);

      uvSSAId := Argument(2);

      if name == {
         case TEXTURE_BIAS_FUNCTION_NAME;
            WriteSingleInstructionIfReachable(function, *data.isBlockReachable, .ImageSampleImplicitLod, resultTypeSSAId, resultSSAId, sampledImageSSAId, uvSSAId, SpvImageOperandsMask.BiasMask, Argument(3));

         case TEXTURE_GRAD_FUNCTION_NAME;
            WriteSingleInstructionIfReachable(function, *data.isBlockReachable, .ImageSampleExplicitLod, resultTypeSSAId, resultSSAId, sampledImageSSAId, uvSSAId, SpvImageOperandsMask.GradMask, Argument(3), Argument(4));

         case TEXTURE_GATHER_FUNCTION_NAME;
            component: Identifier;
            componentSSAId := GenerateInstructions(data, arguments[3], general, function, currentFunction, .{ spirvShouldHaveBeenType = header.arguments[3].type }, identifierOut = *component);
            assert(component.type == .IntLiteral, "the component of % must be a constant. loc: %", name, GetLocationString(arguments[3]));
            WriteSingleInstructionIfReachable(function, *data.isBlockReachable, .ImageGather, resultTypeSSAId, resultSSAId, sampledImageSSAId, uvSSAId, componentSSAId);

         case TEXTURE_CMP_FUNCTION_NAME;
            WriteSingleInstructionIfReachable(function, *data.isBlockReachable, .ImageSampleDrefImplicitLod, resultTypeSSAId, resultSSAId, sampledImageSSAId, uvSSAId, Argument(3));

         case TEXTURE_CMP_LOD_FUNCTION_NAME;
            WriteSingleInstructionIfReachable(function, *data.isBlockReachable, .ImageSampleDrefExplicitLod, resultTypeSSAId, resultSSAId, sampledImageSSAId, uvSSAId, Argument(3), SpvImageOperandsMask.LodMask, Argument(4));

         case; assert(false, "unreachable");
      }

      return resultSSAId;
   }

   if name == {
      case TEXEL_FETCH_FUNCTION_NAME; #through;
      case TEXEL_FETCH_INT_FUNCTION_NAME;
         WriteSingleInstructionIfReachable(function, *data.isBlockReachable, .ImageFetch, resultTypeSSAId, resultSSAId, imageSSAId, Argument(1), SpvImageOperandsMask.LodMask, Argument(2));

      case TEXTURE_SIZE_FUNCTION_NAME;
         data.usesImageQuery = true;
         WriteSingleInstructionIfReachable(function, *data.isBlockReachable, .ImageQuerySizeLod, resultTypeSSAId, resultSSAId, imageSSAId, Argument(1));

      case TEXTURE_LEVELS_FUNCTION_NAME;
         data.usesImageQuery = true;
         WriteSingleInstructionIfReachable(function, *data.isBlockReachable, .ImageQueryLevels, resultTypeSSAId, resultSSAId, imageSSAId);

      case IMAGE_READ_FUNCTION_NAME;
         data.usesImageReadWithoutFormat = true;
         WriteSingleInstructionIfReachable(function, *data.isBlockReachable, .ImageRead, resultTypeSSAId, resultSSAId, imageSSAId, Argument(1));

      case IMAGE_SIZE_FUNCTION_NAME;
         data.usesImageQuery = true;
         WriteSingleInstructionIfReachable(function, *data.isBlockReachable, .ImageQuerySize, resultTypeSSAId, resultSSAId, imageSSAId);

      case; assert(false, "unreachable");
   }

   return resultSSAId;
}

// waits for all the invocations of the workgroup, and makes the writes to workgroup memory before it visible to them
#insert #run sprint("% :: () { } @%", BARRIER_FUNCTION_NAME, INTRINSIC_FUNCTION_NOTE_NAME);

// atomics on a pointer to buffer memory or to a workgroup variable. they return the value that was there before.
#insert #run -> string {
   builder: String_Builder;

   TYPES :: string.["s32", "u32", "s64", "u64"];
   FUNCTIONS :: string.[ATOMIC_ADD_FUNCTION_NAME, ATOMIC_MIN_FUNCTION_NAME, ATOMIC_MAX_FUNCTION_NAME, ATOMIC_AND_FUNCTION_NAME, ATOMIC_OR_FUNCTION_NAME, ATOMIC_XOR_FUNCTION_NAME, ATOMIC_EXCHANGE_FUNCTION_NAME];

   for type: TYPES {
      for name: FUNCTIONS {
         print_to_builder(*builder, "% :: (pointer: *%, value: %) -> % { return 0; } @%\n", name, type, type, type, INTRINSIC_FUNCTION_NOTE_NAME);
      }

      // stores value if the value at pointer is comparator
      print_to_builder(*builder, "% :: (pointer: *%, comparator: %, value: %) -> % { return 0; } @%\n", ATOMIC_COMPARE_EXCHANGE_FUNCTION_NAME, type, type, type, type, INTRINSIC_FUNCTION_NOTE_NAME);
   }

   return builder_to_string(*builder);
};
// ^^^^^^ intrinsics ^^^^^^^^^

ProcessMessage :: (message: *Message) {
   if message.kind == {
      case .TYPECHECKED; {
         mt := cast(*Message_Typechecked) message;
         for mt.procedure_headers {
            if (IsProcedureShaderEntryPoint(it.expression)) {
               TableAdd(*entryPoints, it.expression, .{});
               CreateFunctionDependencyEntryIfNotExists(*functionDependencyTable, it.expression);
            } else {
               // instead of adding every function here like this, do, i think, traverse the entry points
               // and look for procedure calls and only recurse to them and only add them.
               //       - apila, 09/06/26
               for it.expression.arguments {
                  TableAdd(*userFunctionArguments, it, .{});
               }
            }
         }

         for mt.structs {
            if (it.expression.defined_type != null) TableAddIfNotExists(*structDefinitions, it.expression.defined_type, it.expression);
         }

         for mt.declarations {
            if (it.expression.flags & .IS_CONSTANT) {
               TableAdd(*globalConstantDeclarations, it.expression, .{});
            }

            // the following doesnt work:
            //    if (starts_with(it.expression.enclosing_load.enclosing_import.module_name, MODULE_NAME));
            // because the variables are "#insert #run ..." so the "module_name" is an empty string.
            // jai thinks it comes from a string, not from the module it is written in.
            // for that reason i think detecting variables via a note is a better approach than detecting by its name.
            //          - apila, 19/09/26

            if it.expression.name == {
               case MESH_VERTICES_NAME; {
                  assert(meshVerticesVariableIdentifier.type == .Invalid);
                  meshVerticesVariableIdentifier = .{ type = .Variable, variable = .{ declaration = it.expression } };
               }


               case IMAGE_HEAP_VARIABLE_NAME; {
                  assert(imageHeapVariableIdentifier.type == .Invalid);
                  imageHeapVariableIdentifier = .{ type = .Variable, variable = .{ declaration = it.expression } };
               }

               case TLAS_HEAP_VARIABLE_NAME; {
                  assert(tlasHeapVariableIdentifier.type == .Invalid);
                  tlasHeapVariableIdentifier = .{ type = .Variable, variable = .{ declaration = it.expression } };
               }

               case SAMPLER_HEAP_VARIABLE_NAME; {
                  assert(samplerHeapVariableIdentifier.type == .Invalid);
                  samplerHeapVariableIdentifier = .{ type = .Variable, variable = .{ declaration = it.expression } };
               }

               case MESH_PIPELINE_PUSH_DATA_VARIABLE_NAME; {
                  assert(meshPipelinePushDataVariableIdentifier.type == .Invalid);
                  meshPipelinePushDataVariableIdentifier = .{ type = .Variable, variable = .{ declaration = it.expression } };
               }

               case RTX_PIPELINE_PUSH_DATA_VARIABLE_NAME; {
                  assert(rtxPipelinePushDataVariableIdentifier.type == .Invalid);
                  rtxPipelinePushDataVariableIdentifier = .{ type = .Variable, variable = .{ declaration = it.expression } };
               }

               case COMPUTE_PIPELINE_PUSH_DATA_VARIABLE_NAME; {
                  assert(computePipelinePushDataVariableIdentifier.type == .Invalid);
                  computePipelinePushDataVariableIdentifier = .{ type = .Variable, variable = .{ declaration = it.expression } };
               }
            }

            for indices, indicesIndex: MESH_PRIMITIVE_INDICES {
               if (it.expression.name != indices.name) continue;

               assert(meshPrimitiveIndicesIdentifiers[indicesIndex].type == .Invalid);
               meshPrimitiveIndicesIdentifiers[indicesIndex] = .{ type = .Variable, variable = .{ declaration = it.expression } };
            }

            for builtin, builtinIndex: BUILTIN_VARIABLES {
               if (it.expression.name != builtin.name) continue;

               assert(builtinVariableIdentifiers[builtinIndex].type == .Invalid);
               builtinVariableIdentifiers[builtinIndex] = .{ type = .Variable, variable = .{ declaration = it.expression } };
            }
         }
      }

      // i rely on .COMPLETE message being reported only once per workspace. the code below should get executed only once.    - apila, 23/05/26
      case .COMPLETE; {
         mc := cast(*Message_Complete) message;
         if (mc.error_code != .NONE) return;

         {
            assert(meshVerticesVariableIdentifier.type            != .Invalid);
            for meshPrimitiveIndicesIdentifiers  assert(it.type != .Invalid, "%", MESH_PRIMITIVE_INDICES[it_index].name);
            assert(imageHeapVariableIdentifier.type               != .Invalid);
            assert(tlasHeapVariableIdentifier.type                != .Invalid);
            assert(samplerHeapVariableIdentifier.type             != .Invalid);
            assert(meshPipelinePushDataVariableIdentifier.type    != .Invalid);
            assert(rtxPipelinePushDataVariableIdentifier.type     != .Invalid);
            assert(computePipelinePushDataVariableIdentifier.type != .Invalid);
            for builtinVariableIdentifiers  assert(it.type != .Invalid, "%", BUILTIN_VARIABLES[it_index].name);
         }

         for _, header: entryPoints {
            // top tier formatting right there
                                            shaderType, workgroupSize, maxVertices, maxPrimitives, topology := GetParametersFromNotes(header.notes);
            spirv := CompileToSpirv(header, shaderType, workgroupSize, maxVertices, maxPrimitives, topology);

            buildOptions := GetBuildOptions(message.workspace);
            fileName := sprint("%.spv", header.name);
            outputPath := path_join(buildOptions.buildFolder, fileName);
            write_entire_file(outputPath, spirv.data, spirv.count);
         }
      }
   }
}

// prolly i need a lock or something when make the compiler run in parallel         - apila, 10/06/26
workspaceToBuildOptions: Table(Workspace, BuildOptions);
BuildOptions :: struct {
   buildFolder: string = ".";
}

GetBuildOptions :: (w: Workspace) -> BuildOptions {
   options, newlyAdded := find_or_add(*workspaceToBuildOptions, w);
   if (newlyAdded) {
      options.* = .{};
   }

   return options.*;
}

SetBuildOptions :: (options: BuildOptions, w: Workspace) {
   table_set(*workspaceToBuildOptions, w, options);
}

#scope_module

// [] type == struct { count: int, data: *type };
// count is the first member, data is the second.
// the WriteTypeOrVariableOrConstant and DoDotsAndArraySubscripts must agree on this
//       - apila, 23/09/26
ARRAY_VIEW_COUNT_FIELD_INDEX  :: 0;
ARRAY_VIEW_DATA_FIELD_INDEX   :: 1;

meshVerticesVariableIdentifier:           Identifier;
meshPrimitiveIndicesIdentifiers:          [MESH_PRIMITIVE_INDICES.count] Identifier;
imageHeapVariableIdentifier:              Identifier;
tlasHeapVariableIdentifier:               Identifier;
samplerHeapVariableIdentifier:            Identifier;
meshPipelinePushDataVariableIdentifier:   Identifier;
rtxPipelinePushDataVariableIdentifier:    Identifier;
computePipelinePushDataVariableIdentifier:  Identifier;
builtinVariableIdentifiers:               [BUILTIN_VARIABLES.count] Identifier;

MODULE_NAME :: #run GetModuleName();

GetFolderName :: (path: string) -> string {
   return path_filename(trim_right(path_strip_filename(path), "/\\"));
}

GetModuleName :: () -> string {
   fileName := path_filename(#file);
   if (fileName == "module.jai") {
      return GetFolderName(#filepath);
   } else {
      return path_strip_extension(fileName);
   }
}


// when i start to compile shaders in parallel, i need to synchronize access to this table      - apila, 23/05/26
entryPoints:                  Table(*Code_Procedure_Header, struct {});
functionDependencyTable:      Table(*Code_Procedure_Header, [..] *Code_Procedure_Header); // list of functions that a function calls
globalConstantDeclarations:   Table(*Code_Declaration, struct {});
userFunctionArguments:        Table(*Code_Declaration, struct {}); // this contains arguments to user defined functions. this doesn't include the arguments to the entry point.     - apila, 09/06/26
structDefinitions:            Table(*Type_Info_Struct, *Code_Struct); // needed for the default values of struct members.

// fixed arrays in Function storage class must not have the ArrayStride decoration, but arrays in buffers (PhysicalStorageBuffer) must have it.
// so like TypeInfoDecorationlessCopyOfStruct, local arrays use a copy of the array type, which is registered here. (key: the copy, value: the array it is a copy of)
// the copy is still a Type_Info_Array so the code that handles arrays doesnt need to know about it, only CompareType and HashType do.
decorationlessArrays:         Table(*Type_Info_Array, *Type_Info_Array);

MESH_SHADER_NOTE_NAME      :: "mesh";
FRAGMENT_SHADER_NOTE_NAME  :: "fragment";
RGEN_SHADER_NOTE_NAME      :: "rgen";
RCHIT_SHADER_NOTE_NAME     :: "rchit";
RMISS_SHADER_NOTE_NAME     :: "rmiss";
COMPUTE_SHADER_NOTE_NAME   :: "compute";

// this is not required for anything. but i have it to debug faster. so that i can check the note to see if it is intrinsic and thats it
//          - apila, 07/06/26
INTRINSIC_FUNCTION_NOTE_NAME :: "intrinsic";

AggregateUsedFunctions :: (entryPoint: *Code_Procedure_Header, functionDependencyTable: Table(*Code_Procedure_Header, [..] *Code_Procedure_Header), compiledFunctions: Table(*Code_Procedure_Header, BuilderType)) -> BuilderType {
   EnqueueIfNotSeen :: (item: *Code_Procedure_Header) #expand {
      contains := table_contains(*`seen, item);
      if (contains) return;

      Enqueue(*`frontier, item);
      TableAdd(*`seen, item, .{});
   }

   result: BuilderType;
   frontier: Queue(*Code_Procedure_Header);
   seen: Table(*Code_Procedure_Header, struct {});

   found, firstLevelDependencies := table_find(*functionDependencyTable, entryPoint);
   assert(found);

   for firstLevelDependencies {
      EnqueueIfNotSeen(it);
   }

   while true {
      isDequeued, dependency := Dequeue(*frontier);
      if (!isDequeued) break;

      dependencySpirv := table_find_pointer(*compiledFunctions, dependency);
      assert(dependencySpirv != null);

      AppendBuffers(*result, dependencySpirv);

      found, dependeciesOfTheDependency := table_find(*functionDependencyTable, dependency);
      assert(found);

      for dependeciesOfTheDependency {
         EnqueueIfNotSeen(it);
      }
   }

   return result;
}

// how_to/250_how_parameters_are_passed.jai
IsSmallArgument :: (type: *Type_Info) -> bool {
   return type.runtime_size <= 8 && type.type != .STRUCT;
}

GetParametersFromNotes :: (notes: [] *Code_Note) -> ShaderType, workgroupSize: [3] u32, maxVertices: u32, maxPrimitives: u32, PrimitiveTopology {
   notesAsString := NewArray(notes.count, string);

   for notes {
      notesAsString[it_index] = it.text;
   }

          a, b, c, d, e := GetParametersFromNotes(notesAsString);
   return a, b, c, d, e;
}

// does validation of notes
GetParametersFromNotes :: (notes: [] string) -> ShaderType, workgroupSize: [3] u32, maxVertices: u32, maxPrimitives: u32, PrimitiveTopology {
   shaderType: ShaderType;
   workgroupSize: [3] u32;
   maxVertices: u32;
   maxPrimitives: u32;
   topology: PrimitiveTopology;

   // shader type
   assert(notes.count >= 1, "no notes on entry point!");
   typeNote := notes[0];
   if typeNote == {
      case MESH_SHADER_NOTE_NAME;      shaderType = .Mesh;
      case FRAGMENT_SHADER_NOTE_NAME;  shaderType = .Fragment;
      case RGEN_SHADER_NOTE_NAME;      shaderType = .Rgen;
      case RCHIT_SHADER_NOTE_NAME;     shaderType = .Rchit;
      case RMISS_SHADER_NOTE_NAME;     shaderType = .Rmiss;
      case COMPUTE_SHADER_NOTE_NAME;   shaderType = .Compute;
      case; assert(false, "not yet implemented! note: %", typeNote);
   }

   if shaderType == {
      case .Mesh; {
         assert(notes.count == 4, "[1] = x_y_z workgroup size, [2] = a_b max vertices and max primitives, [3] = [points, lines, triangles] primitive topology");

         // [1]
         workgroupSize = ParseWorkgroupSize(notes[1]);

         // [2]
         {
            maxVerticesAndPrimitivesNote := notes[2];
            maxVerticesAndPrimitives := split(maxVerticesAndPrimitivesNote, "_");
            assert(maxVerticesAndPrimitives.count == 2, "maxVerticesAndPrimitives: %", maxVerticesAndPrimitives);

            ok: bool;
            maxVerticesS64:, ok = string_to_int(maxVerticesAndPrimitives[0]);
            assert(ok, "maxVerticesAndPrimitives[0]: %", maxVerticesAndPrimitives[0]);

            maxPrimitivesS64:, ok = string_to_int(maxVerticesAndPrimitives[1]);
            assert(ok, "maxVerticesAndPrimitives[1]: %", maxVerticesAndPrimitives[1]);

            maxVertices = xx maxVerticesS64;
            maxPrimitives = xx maxPrimitivesS64;
         }

         // [3]
         {
            primitiveTopology := notes[3];
            PRIMITIVE_TOPOLOGIES := string.["points", "lines", "triangles"];
            found := array_find(PRIMITIVE_TOPOLOGIES, primitiveTopology);
            assert(found, "primitiveTopology: %, valid values: %", primitiveTopology, PRIMITIVE_TOPOLOGIES);

            topology = ToPrimitiveTopology(primitiveTopology);
         }
      }

      case .Fragment; {
         assert(notes.count == 1, "fragment shader must take no additional notes");
      }

      case .Rgen; {
         assert(notes.count == 1, "rgen shader must take no additional notes");
      }

      case .Rchit; {
         assert(notes.count == 1, "rchit shader must take no additional notes");
      }

      case .Rmiss; {
         assert(notes.count == 1, "rmiss shader must take no additional notes");
      }

      // @compute @x_y_z
      case .Compute; {
         assert(notes.count == 2, "[1] = x_y_z workgroup size");
         workgroupSize = ParseWorkgroupSize(notes[1]);
      }

      case; assert(false, "not yet implemented! type: %", shaderType);
   }

   return shaderType, workgroupSize, maxVertices, maxPrimitives, topology;
}


// x_y_z. if you omit y and/or z they are 1
ParseWorkgroupSize :: (note: string) -> [3] u32 {
   workgroupSize: [3] u32 = .[1, 1, 1];

   dimensions := split(note, "_");
   assert(dimensions.count >= 1 && dimensions.count <= 3, "dimensions: %, the workgroup size is x_y_z, y and z can be omitted", dimensions);

   for dimensions {
      value, ok := string_to_int(it);
      assert(ok && value > 0, "it: %, couldnt be parsed to a positive int!", it);

      workgroupSize[it_index] = xx value;
   }

   return workgroupSize;
}

// this function doesnt validate the notes
// mesh shader:
//    @mesh @x_y_z @maxV_maxP @topology
// fragment shader:
//    @fragment
IsProcedureShaderEntryPoint :: (header: *Code_Procedure_Header) -> bool {
   if (header.notes.count < 1) return false;

   return header.notes[0].text == MESH_SHADER_NOTE_NAME        ||
          header.notes[0].text == FRAGMENT_SHADER_NOTE_NAME    ||
          header.notes[0].text == RGEN_SHADER_NOTE_NAME        ||
          header.notes[0].text == RCHIT_SHADER_NOTE_NAME       ||
          header.notes[0].text == RMISS_SHADER_NOTE_NAME       ||
          header.notes[0].text == COMPUTE_SHADER_NOTE_NAME;
}

// TODO
// can you use OpConstantSampler to inline the samplers?
// this eliminates the need of sampler heap for most use cases
//    - apila, 02/05/26

// a lot of bullshit happening because i cant create a type and get a handle to it in the metaprogram

//
// there are two approaches to storage classes:
//    - have qualifiers that decorates the pointer type
//    - do a prepass to infer the storage class of a pointer
//
// first option allows a single pass compiler and perhaps simpler to implement because you force the user to provide the storage class.
// second option hides this stuff and does it implicitly but the user still needs to know about storage classes because a function pointer
// cant point to a physical storage buffer and vice versa.
//
// idk what approach to take. both seems fine to me.
//
// i feel like i think it is better for me to let the user tell me what the storage class is
// since the user has more knowledge about the structs he defines. multi level pointers can be solved with giving
// multiple qualifiers. to make this approach bearable there should be defaults. for example a pointer in a struct is physical storage buffer
// if you want it local then you must decorate it manually. i think this design make sense. both from the perspective of the spirv generator and from the persepctive of
// the user. spirv generator expects the pointer type to include the storage class (which is provided by the qualifiers or defaults). from user perspective it makes it obvious
// what he is doing.
//
// also with the qualifier approach i still can do just a little tiny bit of inferring. if declaration and assignment is a single statement then i can be nice and
// infer it directly from what it is assigned to.
//       - apila, 25/04/26
//

//
// it is prolly a good idea to align the vectors to 16 bytes for simd instructions
// the structs in spirv i generate follows the offsets generated by jai strictly (so that your cpu and gpu code matches)
// by making them also offsetted to 16 bytes on cpu it is guranteed that they match and struct is suitable for simd instructions
// idk much about how hardware does simd stuff but im told that if there are aligned then it works better Clueless surely
//
// make the alignment of f32x4 to be 16, f32x3 to be idk, f32x2 i think 8 is good 16 unnecessary Clueless. need to do research a lil bit
//
// when it comes to determining the alignment of a struct in the metaprogram (you know you cant use alignof) the function VeryBadImplementedAlignOfBecauseIDontKnowHowToUseTheProperOneInAMetaprogramWhereTypeIsNotConstantSecondTake
// works a lil bit but if #align is used it wont work. so maybe im thinking as a bad but whatever solution is that maybe duplicate the #align with @align
// use the same data and in that function i can read from @align. this is a terrible solution.now the user needs to make sure that there is @align and #align
// in his struct and also they should match. all this just because i couldnt figure out how to get the alignment of a non constant type. yikes
// or now i think about it maybe dont even have such implementation since it is not the way. the proper way is that the jai compiler tells me what the alignment is
// otherwise i cant make sure if the alignmnets match. maybe jai compiler does some "optimizations" and sets the alignment in a certain way. for that i have to query
// this data from the jai compiler. as far as i know there is no way to get it given the Type.
//
//          - apila, 27/04/26
//
// jblow said on discord that he will move the alignment field to Type_Info_Struct. so the problem above is no more.
//          - apila, 29/04/26
//
// it is there now, alignof uses Type_Info_Struct.alignment.
//

SSAId :: #type,distinct u32;

BuilderType :: #run -> Type {
   if #complete SPIRV_BUILDER_TYPE == {
      case .Byte; return [..] u32; // list of words. one word is 4 bytes
      case .String; return String_Builder;
   }
}

MESH_VERTICES_NAME                        :: "meshvertices";
MESH_TRIANGLES_NAME                       :: "meshtriangles";
SET_MESH_OUTPUTS_NAME                     :: "SetMeshOutputs";
MESH_PIPELINE_PUSH_DATA_VARIABLE_NAME     :: "__mesh_push_data__";   // this is not gonna be used by the user.
                                                                     // so i picked a name hoping that it is not gonna clash with other variables
RTX_PIPELINE_PUSH_DATA_VARIABLE_NAME      :: "__rtx_push_data__";
IMAGE_HEAP_VARIABLE_NAME                  :: "images";   // these two are resource heaps but they return different type.
TLAS_HEAP_VARIABLE_NAME                   :: "tlases";   // i couldve made it so there is only one resource heap that returns *void (or a generic resource handle) but idk.
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
IMAGE_READ_FUNCTION_NAME                  :: "ImageRead";
IMAGE_SIZE_FUNCTION_NAME                  :: "ImageSize";
COMPUTE_PIPELINE_PUSH_DATA_VARIABLE_NAME  :: "__compute_push_data__";
TRACE_RAY_FUNCTION_NAME                   :: "TraceRay";
BARRIER_FUNCTION_NAME                     :: "Barrier";                  // OpControlBarrier, like barrier() in glsl
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

MeshPipelinePushData :: struct {
   taskData:      *void;
   meshData:      *void;
   fragmentData:  *void;
}

RtxPipelinePushData :: struct {
   rgenData:   *void;
   rchitData:  *void;
   rmissData:  *void;
}

ComputePipelinePushData :: struct {
   computeData: *void;
}

#insert #run sprint("%: MeshPipelinePushData;", MESH_PIPELINE_PUSH_DATA_VARIABLE_NAME);
#insert #run sprint("%: RtxPipelinePushData;", RTX_PIPELINE_PUSH_DATA_VARIABLE_NAME);
#insert #run sprint("%: ComputePipelinePushData;", COMPUTE_PIPELINE_PUSH_DATA_VARIABLE_NAME);

__Sampler__ :: struct { } // OpTypeSampler
__Image__ :: struct { } // base type for what OpTypeImage returns. i dont use this.
                        // this is here to make the jai compiler happy. so it typechecks and stuff.
                        // i use TypeInfoImage.
                        //       - apila, 03/05/26
__TLAS__ :: struct { } // OpTypeAccelerationStructureKHR

//
// a pointer in the gpu program.
// i should use this everywhere instead of Type_Info_Pointer
// in a similar way to jai compiler i think i need to keep a table of types that i created (only pointers or types that contain pointers, an array of pointers for example)
// and i should add the type to the table if it doesnt exists already. if i do that then i can just the pointer comparison for any type.
// i dont need to create type infos for other types since jai type suffices i think maybe not for the arrays. or a struct containing a pointer?
// i mean i can just use the type info struct in Preload.jai but i still need to create the type and add it to the table i think
//
// but i dont like this approach. it is gonna complicate things. i am looking for a way to be able to determine the storage class of a pointer type from where it is declared
// but still there is this poblem that what the identifier of the type should be. i can go one way but not the other way. i can determine the spirv type from the jai type and where it is declared
// but i cant determine the ssa id of it. so i think i still need something like this.
//             - apila, 21/04/26
//
TypeInfoPointer :: struct {
   using #as info: Type_Info;
   info.type = TYPE_INFO_POINTER_TAG;
   info.runtime_size = 8;

   pointerTo:     *Type_Info;
   storageClass:  SpvStorageClass;
}

TypeInfoSampledImage :: struct {
   using #as info: Type_Info;
   info.type = TYPE_INFO_SAMPLED_IMAGE_TAG;
   info.runtime_size = 0;

   image: *TypeInfoImage;
}

TypeInfoImage :: struct {
   using #as info: Type_Info;
   info.type = TYPE_INFO_IMAGE_TAG;
   info.runtime_size = 0;  // result of OpConstantSizeOfEXT OpTypeImage
                           // same as VkPhysicalDeviceDescriptorHeapPropertiesEXT.imageDescriptorSize

   sampledType:      *Type_Info;
   dimensionality:   SpvDim;
   depth:            int;
   arrayed:          int;
   ms:               int;
   sampled:          int;
   imageFormat:      SpvImageFormat;
}

// this is different than normal array: [] T.
// it doesnt point to anything. if you use it at the end of a struct it extends the struct
// maybe i should have a keyword for this. something like this:
//    MyStruct :: struct {
//       a: float;
//       b: float;
//       datas: f32x4; @extend
//    }
// now datas becomes a runtime array.
// but i dont think this works because in the shader jai wont allow you to use subscript operator.
// maybe for that reason i think of two solutions:
//    - create a struct to wrap up the runtime array.
//       datas: Extend(f32x4);
//    - declare the extended variable as an array view.
//       datas: [] f32x4; @extend
//
// the second one seems nicer in my opinion.
//       - apila, 03/05/26
TypeInfoRuntimeArray :: struct {
   using #as info: Type_Info;
   info.type = TYPE_INFO_RUNTIME_ARRAY_TAG;
   info.runtime_size = 0; // not known at compile time

   elementType: *Type_Info;
}

// man i hate spirv. if a struct is used in PhysicalStorageBuffer storage class, it must have offset decorations
// if it is used in Function storage class it must not have offset decorations. so you have to create two copies of the same struct.
// this is not the only one. stupid fucking language man. and we have to work with this, no other option, bruh moment.
//       - apila, 07/06/26
TypeInfoDecorationlessCopyOfStruct :: struct {
   using #as info: Type_Info;
   info.type = TYPE_INFO_DECORATIONLESS_COPY_OF_STRUCT_TAG;

   copyOf: *Type_Info_Struct;
}

// extending Type_Info_Tag
TYPE_INFO_POINTER_TAG                        :: 669;
TYPE_INFO_SAMPLED_IMAGE_TAG                  :: 670;
TYPE_INFO_IMAGE_TAG                          :: 671;
TYPE_INFO_RUNTIME_ARRAY_TAG                  :: 672;
TYPE_INFO_DECORATIONLESS_COPY_OF_STRUCT_TAG  :: 673;

InternalVariableKind :: enum {
   ResourceHeap;
}

// Identifier is anything that can be given an SSA id, including compiler-only
// variables that have no corresponding Jai declaration.
Identifier :: struct {
   type: enum {
      Invalid;
      IntLiteral;
      FloatLiteral;
      Function;
      _Type;
      Void;
      Variable;
      CompositeLiteral;
      BoolLiteral;
      ConstantSizeOf;
      InternalVariable;
      NullConstant;   // OpConstantNull. zero value of nullConstant type.
      Float64Literal;
   };

   using value: union {
      // store Type_Info_Integer + value instead?
      //    - apila, 06/05/26
      intLiteral:                   struct {
                                       unsigned:   bool;
                                       value:      union {
                                                      _s64: s64;
                                                      _u64: u64;
                                                   };
                                       bitSize:    int;
                                    };
      floatLiteral:                 float;
      function:                     *Code_Procedure_Header;
      _type:                        *Type_Info;
      // _void: // Void doesnt have a value
      variable:                     struct {
                                       declaration: *Code_Declaration;
                                    };
      compositeLiteral:             struct {
                                       type:       *Type_Info;
                                       arguments:  [] *Identifier;
                                    };
      boolLiteral:                  bool;
      constantSizeOf:               *Type_Info;
      internalVariable:             InternalVariableKind;
      nullConstant:                 *Type_Info;
      float64Literal:               float64;
   };
}

HashType :: (type_: *Type_Info) -> u32 {
   // must agree with CompareType, which compares an enum as its integer type
   type := UnwindEnum(type_);

   // since an array of pointers is not supported and the notes on the struct members are enough
   // the only thing that remains is TypeInfoPointer. so i dont need to check if a type contains pointer.
   // because thats the only type i create. i also create fixed arrays so i think they need to be handled seperately too :(. if only there was a way to create types
   // and get a handle to them in a metaprogram :(.
   if (type.type == TYPE_INFO_POINTER_TAG) {
      tip := cast(*TypeInfoPointer) type;

      hash: u32 = 17;
      hash = hash * 31 + HashType(tip.pointerTo);
      hash = hash * 31 + get_hash(tip.storageClass);

      return hash;
   }

   if (type.type == TYPE_INFO_SAMPLED_IMAGE_TAG) {
      tisi := cast(*TypeInfoSampledImage) type;
      return HashType(tisi.image);
   }

   if (type.type == TYPE_INFO_IMAGE_TAG) {
      tim := cast(*TypeInfoImage) type;

      hash: u32 = 17;
      hash = hash * 31 + HashType(tim.sampledType);
      hash = hash * 31 + get_hash(tim.dimensionality);
      hash = hash * 31 + get_hash(tim.depth);
      hash = hash * 31 + get_hash(tim.arrayed);
      hash = hash * 31 + get_hash(tim.ms);
      hash = hash * 31 + get_hash(tim.sampled);
      hash = hash * 31 + get_hash(tim.imageFormat);

      return hash;
   }

   if (type.type == TYPE_INFO_RUNTIME_ARRAY_TAG) {
      tira := cast(*TypeInfoRuntimeArray) type;
      return HashType(tira.elementType);
   }

   // must agree with CompareType which compares the arguments and the returns. (the spirv types of functions are created for each function, see GetFunctionSpirvType)
   if (type.type == .PROCEDURE) {
      tip := cast(*Type_Info_Procedure) type;

      hash: u32 = 23;
      for tip.argument_types  hash = hash * 31 + HashType(it);
      for tip.return_types    hash = hash * 37 + HashType(it);

      return hash;
   }

   // must agree with CompareType which compares the struct it is a copy of. (every declaration creates its own TypeInfoDecorationlessCopyOfStruct)
   if (type.type == TYPE_INFO_DECORATIONLESS_COPY_OF_STRUCT_TAG) {
      tidcos := cast(*TypeInfoDecorationlessCopyOfStruct) type;
      return HashType(tidcos.copyOf) * 31 + TYPE_INFO_DECORATIONLESS_COPY_OF_STRUCT_TAG;
   }

   if (type.type == .ARRAY) {
      tia := cast(*Type_Info_Array) type;

      if (tia.array_type == .FIXED) {
         hash: u32 = 17;
         hash = hash * 31 + HashType(tia.element_type);
         hash = hash * 31 + get_hash(tia.array_count);
         hash = hash * 31 + cast(u32) IsDecorationlessArray(tia);

         return hash;
      }
   }

   // my types doesnt clash with those. so it is enough to use jai pointers (they are deduplicated)
   return cast,trunc(u32) fnv1a_hash(xx type, size_of(type_of(type)));
}

// cant do "==" anymore even if the types are jai types because they come from different workspaces.
CompareType :: (a_: *Type_Info, b_: *Type_Info) -> bool {
   a := UnwindEnum(UnwindVariantsUpToDistinct(a_));
   b := UnwindEnum(UnwindVariantsUpToDistinct(b_));

   if (a.type != b.type || a.runtime_size != b.runtime_size) return false;

   type := a.type;

   if type == {
      case .INTEGER;
         tiiA := cast(*Type_Info_Integer) a;
         tiiB := cast(*Type_Info_Integer) b;

         return tiiA.signed == tiiB.signed;

      case .FLOAT;
         return true;

      case .BOOL;
         return true;

      case .STRING;
         assert(false, "idk about this since this also contains a pointer");
         return false;

      case .POINTER;
         assert(false);
         return false;

      case TYPE_INFO_POINTER_TAG;
         tipA := cast(*TypeInfoPointer) a;
         tipB := cast(*TypeInfoPointer) b;

         return tipA.storageClass == tipB.storageClass && CompareType(tipA.pointerTo, tipB.pointerTo);

      case TYPE_INFO_IMAGE_TAG;
         timA := cast(*TypeInfoImage) a;
         timB := cast(*TypeInfoImage) b;

         return   CompareType(timA.sampledType, timB.sampledType) &&
                  timA.dimensionality  == timB.dimensionality     &&
                  timA.depth           == timB.depth              &&
                  timA.arrayed         == timB.arrayed            &&
                  timA.ms              == timB.ms                 &&
                  timA.sampled         == timB.sampled            &&
                  timA.imageFormat     == timB.imageFormat;

      case TYPE_INFO_RUNTIME_ARRAY_TAG;
         tiraA := cast(*TypeInfoRuntimeArray) a;
         tiraB := cast(*TypeInfoRuntimeArray) b;

         return CompareType(tiraA.elementType, tiraB.elementType);

      case TYPE_INFO_SAMPLED_IMAGE_TAG;
         tisiA := cast(*TypeInfoSampledImage) a;
         tisiB := cast(*TypeInfoSampledImage) b;

         return CompareType(tisiA.image, tisiB.image);

      case .PROCEDURE;
         tipA := cast(*Type_Info_Procedure) a;
         tipB := cast(*Type_Info_Procedure) b;

         if (tipA.argument_types.count != tipB.argument_types.count) return false;
         if (tipA.return_types.count != tipB.return_types.count) return false;

         for tipA.argument_types {
            if (!CompareType(it, tipB.argument_types[it_index])) return false;
         }

         for tipA.return_types {
            if (!CompareType(it, tipB.return_types[it_index])) return false;
         }

         return true;

      case .VOID;
         return true;

      case TYPE_INFO_DECORATIONLESS_COPY_OF_STRUCT_TAG;
         tidcosA := cast(*TypeInfoDecorationlessCopyOfStruct) a;
         tidcosB := cast(*TypeInfoDecorationlessCopyOfStruct) b;
         return CompareType(tidcosA.copyOf, tidcosB.copyOf);

      // this implementation is kaputt. but it works a little bit
      case .STRUCT;
         // actually the notes on the types also determine the type of struct
         // if you need structs with different storage class pointers then you need to create a new struct.
         tisA := cast(*Type_Info_Struct) a;
         tisB := cast(*Type_Info_Struct) b;
         return tisA.name == tisB.name;

      case .ARRAY;
         tiaA := cast(*Type_Info_Array) a;
         tiaB := cast(*Type_Info_Array) b;

         if (tiaA.array_type != tiaB.array_type) return false;

         arrayType := tiaA.array_type;
         assert(arrayType != .RESIZABLE);

         if arrayType == {
            case .FIXED;
               if (IsDecorationlessArray(tiaA) != IsDecorationlessArray(tiaB)) return false;
               return tiaA.array_count == tiaB.array_count && CompareType(tiaA.element_type, tiaB.element_type);
            case .VIEW;
               return CompareType(tiaA.element_type, tiaB.element_type);
            case; assert(false); return false;
         }

      case .VARIANT;
         // this implementation kaputt but it works. a little bit
         tivA := cast(*Type_Info_Variant) a;
         tivB := cast(*Type_Info_Variant) b;

         unwindedA := UnwindVariantsUpToDistinct(tivA);
         unwindedB := UnwindVariantsUpToDistinct(tivB);

         stillBothVariant := unwindedA.type == .VARIANT && unwindedB.type == .VARIANT;
         if (stillBothVariant) {
            variantA := cast(*Type_Info_Variant) unwindedA;
            variantB := cast(*Type_Info_Variant) unwindedB;

            return variantA.name == variantB.name;
         }

         return CompareType(unwindedA, unwindedB);

      case; assert(false, "type: %", type); return false;
   }
}

ShaderType :: enum {
   Task;
   Mesh;
   Fragment;
   Compute;
   Rgen;
   Rchit;
   Rmiss;
}

// == must be defined on T
ArrayEquals :: (a: [] $T, b: [] T) -> bool {
   if a.count != b.count return false;
   for a {
      if it != b[it_index] return false;
   }
   return true;
}

IdentifierHash :: (using identifier: Identifier) -> u32 {
   if #complete type == {
      case .Invalid; assert(false); return 69;
      case .IntLiteral;
         if (intLiteral.unsigned) {
            return get_hash(intLiteral.value._u64);
         } else {
            return get_hash(intLiteral.value._s64);
         }

      case .FloatLiteral; return get_hash(floatLiteral);
      case .Float64Literal; return get_hash(float64Literal) * 31 + 64;
      case .Function; return get_hash(function);
      case ._Type; return HashType(_type);
      case .Void; return 69; // does the hash matter here?
      case .Variable;
            return get_hash(variable.declaration);
      case .CompositeLiteral;
         hash: u32 = 17;
         hash = hash * 31 + get_hash(compositeLiteral.type);

         for compositeLiteral.arguments {
            hash = hash * 31 + IdentifierHash(it.*);
         }

         return hash;
      case .BoolLiteral; return get_hash(boolLiteral);
      case .ConstantSizeOf; return HashType(constantSizeOf);
      case .NullConstant; return HashType(nullConstant) * 31 + 7;
      case .InternalVariable;
         if (internalVariable == .ResourceHeap) return 0x5248_4541;
         assert(false, "internalVariable: %", internalVariable);
         return 0;
   }

   assert(false, "type: %", type);
}

IdentifierCompare :: (a: Identifier, b: Identifier) -> bool {
   if (a.type != b.type) return false;

   type := a.type;
   if #complete type == {
      case .Invalid; assert(false); return false;
      case .IntLiteral;
         if (a.intLiteral.bitSize != b.intLiteral.bitSize) return false;
         if (a.intLiteral.unsigned != b.intLiteral.unsigned) return false;

         unsigned := a.intLiteral.unsigned; // or b.intLiteral.unsigned they have the same value at this point
         if (unsigned) {
            if (a.intLiteral.value._u64 != b.intLiteral.value._u64) return false;
         } else {
            if (a.intLiteral.value._s64 != b.intLiteral.value._s64) return false;
         }

         return true;
      case .FloatLiteral; return a.floatLiteral == b.floatLiteral;
      case .Float64Literal; return a.float64Literal == b.float64Literal;
      case .Function; return a.function == b.function; // if they point to the same code node
      case ._Type;
         return CompareType(a._type, b._type);

      case .Void; return true;
      case .Variable;
         return a.variable.declaration == b.variable.declaration; // two variables are equal if they have the same declaration
      case .CompositeLiteral;
         if (a.compositeLiteral.type != b.compositeLiteral.type) return false;
         if (a.compositeLiteral.arguments.count != b.compositeLiteral.arguments.count) return false;

         argumentCount := a.compositeLiteral.arguments.count; // or b.compositeLiteral.arguments.count, they are equal at this point
         for 0..argumentCount - 1 {
            identifierA := a.compositeLiteral.arguments[it].*;
            identifierB := b.compositeLiteral.arguments[it].*;

            if(!IdentifierCompare(identifierA, identifierB)) return false;
         }

         return true;
      case .BoolLiteral;
         return a.boolLiteral == b.boolLiteral;

      case .ConstantSizeOf;
         //
         // it is not explicitly stated in the spirv docs but implicitly there, is that,
         // the size of an OpTypeImage is same no matter what the parameters are.
         // here size means the value returned by OpConstantSizeOfEXT.
         // this corresponds to VkPhysicalDeviceDescriptorHeapPropertiesEXT.imageDescriptorSize in vulkan.
         //       - apila, 03/05/26
         //

         // could have done it so that for all the image types i return true.
         // probably better. idk.
         return CompareType(a.constantSizeOf, b.constantSizeOf);
      case .InternalVariable; return a.internalVariable == b.internalVariable;
      case .NullConstant; return CompareType(a.nullConstant, b.nullConstant);
   }

   assert(false, "type: %", type);
}

// now unused but could be of use if i change how i store types. maybe possibly Clueless
DoesTypeContainPointer :: (type: *Type_Info) -> bool {
   if type.type == {
      case .INTEGER;
         return false;
      case .FLOAT;
         return false;
      case .BOOL;
         return false;
      case .STRING;
         return true;
      case .POINTER;
         return true;

      case TYPE_INFO_POINTER_TAG;
         return true;

      case TYPE_INFO_IMAGE_TAG;
         return false;

      case TYPE_INFO_RUNTIME_ARRAY_TAG;
         return false;

      case TYPE_INFO_SAMPLED_IMAGE_TAG;
         return false;

      case .PROCEDURE;
         tip := cast(*Type_Info_Procedure) type;

         for tip.return_types {
            if (DoesTypeContainPointer(it)) {
               return true;
            }
         }

         for tip.argument_types {
            if (DoesTypeContainPointer(it)) {
               return true;
            }
         }

         return false;

      case .VOID;
         return false;
      case .STRUCT;
         tis := cast(*Type_Info_Struct) type;
         for GetStructMembers(tis) {
            if (DoesTypeContainPointer(it.type)) {
               return true;
            }
         }

         return false;

      case .ARRAY;
         tia := cast(*Type_Info_Array) type;
         assert(tia.array_type == .FIXED, "tia.array_type: %", tia.array_type);

         return DoesTypeContainPointer(tia.element_type);
      case .OVERLOAD_SET;
         assert(false, "OVERLOAD_SET");
      case .ANY;
         assert(false, "ANY");
      case .ENUM;
         return false;
      case .POLYMORPHIC_VARIABLE;
         assert(false, "POLYMORPHIC_VARIABLE");
      case .TYPE;
         assert(false, "TYPE");
      case .CODE;
         assert(false, "CODE");
      case .UNTYPED_LITERAL;
         assert(false, "UNTYPED_LITERAL");
      case .UNTYPED_ENUM;
         assert(false, "UNTYPED_ENUM");
      case .VARIANT;
         assert(false, "VARIANT");
   }

   assert(false);
   return false;
}

IdentifierWriteStatus :: enum {
   BeingProcessed;
   Written;
}

PrimitiveTopology :: enum {
   Points;
   Lines;
   Triangles;
}

// data for compiling one single entry point (single spirv module).
CompilationData :: struct {
   workgroupSize:                            [3] u32;
   maxVertices:                              int;
   maxPrimitives:                            int;
   primitiveTopology:                        PrimitiveTopology;
   identifierToSSAId:                        Table(Identifier, SSAId, IdentifierHash, IdentifierCompare);
   ssaIota:                                  SSAId;

   locationsConsumedByPerVertexUserStruct:   int;
   meshVertexOutVariableIdentifier:          Identifier;
   meshPrimitiveOutVariableIdentifier:       Identifier;
   writtenIdentifiers:                       Table(Identifier, IdentifierWriteStatus, IdentifierHash, IdentifierCompare);
   forwardDeclaredPointers:                  [..] Identifier; // pointer types that got an OpTypeForwardPointer.
   pendingPointers:                          [..] Identifier; // forward declared pointer types whose OpTypePointer is written once their pointee is written.
   shaderDataPointerVariableIdentifier:      Identifier;
   codeNodeTypes:                            Table(*Code_Node, *Type_Info);
   forLoopNodes:                             Table(*Code_For, ForLoopNodes); // nodes created by the backend for for loops. see GetForLoopNodes
   fragmentVertexInVariableIdentifier:       Identifier;
   fragmentPrimitiveInVariableIdentifier:    Identifier;
   fragmentOutputIdentifiers:                [] Identifier;
   shaderType:                               ShaderType;
   entryFunction:                            *Code_Procedure_Header;
   extraTypeDependencies:                    Table(Identifier, [..] Identifier, IdentifierHash, IdentifierCompare);
   loopStack:                                [..] *LoopData; // the loops we are in, the innermost last
   generalBuilder:                           *BuilderType;   // the "general" builder of the function being generated, where its OpVariables go. for code that doesnt have it at hand (access chains)
   multipleReturnValues:                     Table(*Code_Procedure_Call, SSAId); // the struct returned by a call of a procedure with more than one return value
   proceduresBeingTyped:                     [..] *Code_Procedure_Header; // see the .PROCEDURE_HEADER case of DetermineCodeNodeTypes
   usingStack:                               [..] *Code_Node;  // the expressions of the using statements in scope while typing, the innermost last. see GetUsingAccess
   usingAccesses:                            Table(*Code_Ident, *Code_Binary_Operator); // an identifier that is a member reached through using is generated as this access (base.member)
   pointerIterators:                         Table(*Code_Declaration, *Code_For); // the it of a for * loop. it is the address of the element, see the .FOR case of DetermineCodeNodeTypes
   interfaceVariableIdentifiers:             [..] Identifier; // other global variables the entry point uses (workgroup variables)
   usesInt64Atomics:                         bool;
   usesDemote:                               bool;
   usesImageQuery:                           bool;
   usesImageReadWithoutFormat:               bool;
   pendingExitVariableSSAId:                 SSAId;          // see GenerateLoopExit. 0 if the function doesnt have it yet
   isBlockReachable:                         bool = true;   // this is a flag that keep tracks if a block terminating instruction has been seen in the block we are compiling.
                                                            // this flag is reset every time we start a new block.
                                                            // if you want to parallelize the compiler then you should store this per thread in a tls (thats easy with ApilaDispatch).
                                                            //    - apila, 09/05/26
   glslStd450:                               SSAId;
   resourceHeapIdentifier:                   Identifier = .{ type = .InternalVariable, internalVariable = .ResourceHeap };
   macroExpansionCalls:                      [..] *Code_Procedure_Call;
   macroReturns:                             [..] MacroReturnData; // for macros that return from somewhere other than their last statement. see the macro case of .PROCEDURE_CALL
   rayPayloadVariableIdentifiers:            [..] Identifier;
   incomingRayPayloadVariableIdentifier:     Identifier;
   deferStack:                               [..] *Code_Defer;  // defers of the scopes we are in, the innermost last. see the .DEFER case of GenerateInstructions
   macroDeferBases:                          [..] int;          // for each macro expansion we are in, the count of deferStack when the expansion started
   declaredVariables:                        Table(*Code_Declaration, struct {}); // variables whose OpVariable is written. a deferred block is generated at every exit of its scope, its variables are declared once.

   HashStringArray :: (x: [] string) -> u32 {
      #import "Hash";
      return get_hash(x);
   }

   CompareStringArray :: (a: [] string, b: [] string) -> bool {
      if a.count != b.count return false;
      for a {
         if it != b[it_index] return false;
      }

      return true;
   }
}

LoopData :: struct {
   headerLabelSSAId:       SSAId;
   conditionLabelSSAId:    SSAId;
   bodyLabelSSAId:         SSAId;
   continueLabelSSAId:     SSAId;
   mergeLabelSSAId:        SSAId;
   deferBase:              int;   // count of CompilationData.deferStack when the body of the loop started. break and continue run the defers above it
   iteratorDeclaration:    *Code_Declaration; // for loops. break it; and continue it; refer to the loop by its iterator
   isMacro:                bool;  // the loop a macro with an early return is put in. it is not a loop for break and continue
   crossingExitCodes:      [..] s32; // the exits from inside this loop to a loop outside of it, see GenerateLoopExit
}

// local size is provided via notes like so: @x_y_z
// if you omit y and/or z (or even x) they default to 1
//
// the function must be provided using code_of otherwise jai doesnt compile the body of the function
// and body_or_null is always null even if i wait in a loop until it is not null anymore
CompileToSpirv :: (header: *Code_Procedure_Header, type: ShaderType, workgroupSize: [3] u32 = .[1, 1, 1], maxVertices: u32 = 0, maxPrimitives: u32 = 0, primitiveTopology: PrimitiveTopology = .Triangles) -> [] u8 #compile_time {
   // parameter validation
   if (type == .Mesh) {
      assert(maxVertices > 0, "max vertices must be greater than zero.");
      assert(maxPrimitives > 0, "max primitives must be greater than zero.");
   }

   body := header.body_or_null;
   assert(body != null, "body_or_null is null! idk how to solve this, maybe loop until it is not null anymore. if you passed the function directly that wont work. pass using code_of");
   block := body.block;
   functionName := header.name;

   data: CompilationData;
   data.shaderType = type;
   data.entryFunction = header;
   data.workgroupSize = workgroupSize;
   data.maxVertices = maxVertices;
   data.maxPrimitives = maxPrimitives;
   data.primitiveTopology = primitiveTopology;
   data.glslStd450 = GetNextSSAId(*data);

   // arguments
   if type == {
      case .Mesh; {
         index := 0;

         // first argument: [] MeshOutVertex. MeshOutVertex is user defined struct
         {
            defer index += 1;

            assert(header.arguments.count > index, "not enough arguments");
            assert(header.arguments[index].type.type == .ARRAY, "first argument wrong");
            array := cast(*Type_Info_Array) header.arguments[index].type;

            data.meshVertexOutVariableIdentifier = .{ type = .Variable, variable.declaration = header.arguments[index] };
            data.locationsConsumedByPerVertexUserStruct = CalculateLocationsConsumed(array.element_type);
         }

         // second argument: mOutPrimitive: *[] MeshOutPrimitive. MeshOutPrimitive is user defined struct
         {
            defer index += 1;

            assert(header.arguments.count > index, "not enough arguments");
            assert(header.arguments[index].type.type == .ARRAY, "second argument wrong");
            array := cast(*Type_Info_Array) header.arguments[index].type;

            data.meshPrimitiveOutVariableIdentifier = .{ type = .Variable, variable.declaration = header.arguments[index] };
         }

         // third argument: *MeshData. MeshData is user defined struct
         {
            defer index += 1;

            assert(header.arguments.count > index, "not enoufh arguments");
            assert(header.arguments[index].type.type == .POINTER, "third argument wrong");
            pointer := cast(*Type_Info_Pointer) header.arguments[index].type;

            data.shaderDataPointerVariableIdentifier = .{ type = .Variable, variable.declaration = header.arguments[index] };
         }
      }

      case .Fragment;
         index := 0;

         // first argument: mOutVertex: MeshOutVertex
         {
            defer index += 1;

            assert(header.arguments.count > index, "not enough arguments");
            assert(header.arguments[index].type.type == .STRUCT, "first argument wrong");
            tis := cast(*Type_Info_Struct) header.arguments[index].type;

            data.fragmentVertexInVariableIdentifier = .{ type = .Variable, variable.declaration = header.arguments[index] };
            data.locationsConsumedByPerVertexUserStruct = CalculateLocationsConsumed(tis);
         }

         // second argument: mOutPrimitive: MeshOutPrimitive
         {
            defer index += 1;

            assert(header.arguments.count > index, "not enough arguments");
            assert(header.arguments[index].type.type == .STRUCT, "second argumnet wrong");
            tis := cast(*Type_Info_Struct) header.arguments[index];

            data.fragmentPrimitiveInVariableIdentifier = .{ type = .Variable, variable.declaration = header.arguments[index] };
         }

         // third argument: data: *FragmentData
         {
            defer index += 1;

            assert(header.arguments.count > index, "not enough arguments");
            assert(header.arguments[index].type.type == .POINTER, "third argument wrong");
            tip := cast(*Type_Info_Pointer) header.arguments[index].type;

            data.shaderDataPointerVariableIdentifier = .{ type = .Variable, variable.declaration = header.arguments[index] };
         }

      case .Rgen; {
         index := 0;

         // first argument: data: *RgenData
         {
            defer index += 1;

            assert(header.arguments.count > index, "not enough arguments");
            assert(header.arguments[index].type.type == .POINTER, "first argument wrong");
            tip := cast(*Type_Info_Pointer) header.arguments[index].type;
            data.shaderDataPointerVariableIdentifier = .{ type = .Variable, variable.declaration = header.arguments[index] };
         }
      }

      case .Rchit; {
         index := 0;

         // first argument: data: *RchitData
         {
            defer index += 1;

            assert(header.arguments.count > index, "not enough arguments");
            assert(header.arguments[index].type.type == .POINTER, "first argument wrong");
            tip := cast(*Type_Info_Pointer) header.arguments[index].type;
            data.shaderDataPointerVariableIdentifier = .{ type = .Variable, variable.declaration = header.arguments[index] };
         }
      }

      case .Rmiss; {
         index := 0;

         // first argument: data: *RmissData
         {
            defer index += 1;

            assert(header.arguments.count > index, "not enough arguments");
            assert(header.arguments[index].type.type == .POINTER, "first argument wrong");
            tip := cast(*Type_Info_Pointer) header.arguments[index].type;
            data.shaderDataPointerVariableIdentifier = .{ type = .Variable, variable.declaration = header.arguments[index] };
         }
      }

      // data: *ComputeData
      case .Compute; {
         assert(header.arguments.count == 1, "a compute shader takes one argument: data: *ComputeData");
         assert(header.arguments[0].type.type == .POINTER, "the argument of a compute shader must be a pointer");
         data.shaderDataPointerVariableIdentifier = .{ type = .Variable, variable.declaration = header.arguments[0] };
      }

      case; assert(false, "not implemented yet. type: %", type);
   }

   // returns
   if type == {
      case .Mesh; assert(header.returns.count == 0, "mesh shader must return nothing");
      case .Fragment;
         data.fragmentOutputIdentifiers = NewArray(header.returns.count, Identifier);
         for header.returns {
            _, isNumeric := GetNumericInfo(it.type);
            assert(isNumeric || IsMatrixType(it.type), "returning stuff other than intrinsics not implemented yet! you tried to return: %", it.type.*);

            data.fragmentOutputIdentifiers[it_index] = .{ type = .Variable, variable.declaration = it };
         }

      case .Rgen; {
         assert(header.returns.count == 0, "rgen shader must return nothing");
      }

      case .Rchit; {
         assert(header.returns.count == 0, "rchit shader must return nothing");
      }

      case .Rmiss; {
         assert(header.returns.count == 0, "rmiss shader must return nothing");
      }

      case .Compute; {
         assert(header.returns.count == 0, "compute shader must return nothing");
      }

      case; assert(false, "not implemented yet. type: %", type);
   }

   DetermineCodeNodeTypes(*data, body.block);
   functionsBuilder: BuilderType;
   GenerateFunctions(*data, body, *functionsBuilder);

   b: BuilderType;
   #if SPIRV_BUILDER_TYPE == .Byte {
      MAGIC_NUMBER: u32 : 0x07230203;
      array_add(*b, MAGIC_NUMBER);
      array_add(*b, (1 << 16) | (6 << 8)); // version 1.6
      array_add(*b, xx SpvSourceLanguage.ApilaJai);

      //
      // there are two approaches to determining the ssa id bound:
      //    - dont write now. write it after you are done generating everything
      //    - after you traverse the syntax tree before calling WriteTypeOrVariableOrConstant
      //       call another function that generates ssa ids for all dependencies recursively, so that way you make sure all the ssa ids are generated
      //
      // this problem arises becuase i lazily discover the dependencies of types in the WriteTypeOrVariableOrConstant function during i output stuff
      // i think the second approach is the proper one because you are sure ids are stabilized before you started outputting which i think should be the case
      // and a better design. and this also helps some other stages prolly (right now i do reordering for that reason, reordering wouldnt be necessary with this design).
      // but im going with the post patch approach because it is easier to implement for now. if i need the ids to be fully generated for some other reason then i will change it but for now it is okay Clueless.
      //
      //                - apila, 06/05/26
      //
      array_add(*b, SSA_ID_BOUND_PLACEHOLDER);
      array_add(*b, 0);
   }

   if type == {
      case .Mesh;
      case .Fragment;
      case .Rgen;
      case .Rchit;
      case .Rmiss;
      case .Compute;
      case; assert(false, "not yet implemented! following code is not written for this type in mind yet. type: %", type);
   }

   // capabilities
   {
      WriteSingleInstruction(*b, .Capability, SpvCapability.Int64);
      WriteSingleInstruction(*b, .Capability, SpvCapability.Int8);
      WriteSingleInstruction(*b, .Capability, SpvCapability.UntypedPointersKHR);
      WriteSingleInstruction(*b, .Capability, SpvCapability.DescriptorHeapEXT);
      WriteSingleInstruction(*b, .Capability, SpvCapability.PhysicalStorageBufferAddresses);
      WriteSingleInstruction(*b, .Capability, SpvCapability.StorageImageWriteWithoutFormat);

      if type == {
         case .Mesh; {
            WriteSingleInstruction(*b, .Capability, SpvCapability.MeshShadingEXT);
         }

         case .Fragment; {
            WriteSingleInstruction(*b, .Capability, SpvCapability.MeshShadingEXT);
            WriteSingleInstruction(*b, .Capability, SpvCapability.Shader);
         }

         case .Rchit; #through;
         case .Rmiss; #through;
         case .Rgen; {
            WriteSingleInstruction(*b, .Capability, SpvCapability.RayTracingKHR);
         }

         case .Compute; {
            WriteSingleInstruction(*b, .Capability, SpvCapability.Shader);
         }

         case; assert(false, "should be unreachable because of the if check above.");
      }

      if (data.usesInt64Atomics) WriteSingleInstruction(*b, .Capability, SpvCapability.Int64Atomics);
      if (data.usesDemote)       WriteSingleInstruction(*b, .Capability, SpvCapability.DemoteToHelperInvocation);
      if (data.usesImageQuery)   WriteSingleInstruction(*b, .Capability, SpvCapability.ImageQuery);
      if (data.usesImageReadWithoutFormat) WriteSingleInstruction(*b, .Capability, SpvCapability.StorageImageReadWithoutFormat);

      // the capabilities of the types that are used (int8 is always declared)
      {
         uses: NumericUses;
         visited: VisitedTypes;
         for ssaId, identifier: data.identifierToSSAId {
            if (identifier.type == ._Type) CollectNumericUses(identifier._type, *uses, *visited);
         }

         if (uses.integers16) WriteSingleInstruction(*b, .Capability, SpvCapability.Int16);
         if (uses.floats64)   WriteSingleInstruction(*b, .Capability, SpvCapability.Float64);
      }
      for GetUsedBuiltinVariables(*data) {
         if (BUILTIN_VARIABLES[it].builtIn == .SampleId) WriteSingleInstruction(*b, .Capability, SpvCapability.SampleRateShading);
      }
   }

   // extensions
   {
      WriteSingleInstruction(*b, .Extension, "SPV_EXT_descriptor_heap");
      WriteSingleInstruction(*b, .Extension, "SPV_KHR_untyped_pointers");
      WriteSingleInstruction(*b, .Extension, "SPV_KHR_8bit_storage");
      WriteSingleInstruction(*b, .Extension, "SPV_KHR_physical_storage_buffer");

      if type == {
         case .Fragment; #through;
         case .Mesh; {
            WriteSingleInstruction(*b, .Extension, "SPV_EXT_mesh_shader");
         }

         case .Rmiss; #through;
         case .Rchit; #through;
         case .Rgen; {
            WriteSingleInstruction(*b, .Extension, "SPV_KHR_ray_tracing");
         }
      }
   }

   WriteSingleInstruction(*b, .ExtInstImport, data.glslStd450, "GLSL.std.450");
   WriteSingleInstruction(*b, .MemoryModel, SpvAddressingModel.PhysicalStorageBuffer64, SpvMemoryModel.GLSL450);

   // entry point
   // since spirv 1.4 the interface is all the global variables the entry point uses
   {
      operands: [..] Any;

      executionModel: SpvExecutionModel;
      name: string;
      if type == {
         case .Mesh;       executionModel = .MeshEXT;            name = "ApilaMS";
         case .Fragment;   executionModel = .Fragment;           name = "ApilaFS";
         case .Compute;    executionModel = .GLCompute;          name = "ApilaCS";
         case .Rgen;       executionModel = .RayGenerationKHR;   name = "ApilaRgen";
         case .Rchit;      executionModel = .ClosestHitKHR;      name = "ApilaRchit";
         case .Rmiss;      executionModel = .MissKHR;            name = "ApilaRmiss";
         case; assert(false, "should have been unreachable because of the if check above.");
      }

      array_add(*operands, executionModel);
      array_add(*operands, GetSSAId(*data, .{ type = .Function, function = header }));
      array_add(*operands, name);
      array_add(*operands, GetSSAId(*data, data.resourceHeapIdentifier));
      array_add(*operands, GetSSAId(*data, samplerHeapVariableIdentifier));
      array_add(*operands, GetSSAId(*data, data.shaderDataPointerVariableIdentifier));

      if type == {
         case .Mesh;
            array_add(*operands, GetSSAId(*data, meshPipelinePushDataVariableIdentifier));
            array_add(*operands, GetSSAId(*data, meshVerticesVariableIdentifier));
            array_add(*operands, GetSSAId(*data, meshPrimitiveIndicesIdentifiers[data.primitiveTopology]));
            array_add(*operands, GetSSAId(*data, data.meshVertexOutVariableIdentifier));
            array_add(*operands, GetSSAId(*data, data.meshPrimitiveOutVariableIdentifier));

         case .Fragment;
            array_add(*operands, GetSSAId(*data, meshPipelinePushDataVariableIdentifier));
            array_add(*operands, GetSSAId(*data, data.fragmentVertexInVariableIdentifier));
            array_add(*operands, GetSSAId(*data, data.fragmentPrimitiveInVariableIdentifier));
            for data.fragmentOutputIdentifiers  array_add(*operands, ac(GetSSAId(*data, it)));

         case .Compute;
            array_add(*operands, GetSSAId(*data, computePipelinePushDataVariableIdentifier));

         case .Rgen; #through;
         case .Rchit; #through;
         case .Rmiss;
            array_add(*operands, GetSSAId(*data, rtxPipelinePushDataVariableIdentifier));
            if (type != .Rgen) array_add(*operands, GetSSAId(*data, data.incomingRayPayloadVariableIdentifier));
            for data.rayPayloadVariableIdentifiers  array_add(*operands, ac(GetSSAId(*data, it)));
      }

      for GetUsedBuiltinVariables(*data)        array_add(*operands, ac(GetSSAId(*data, builtinVariableIdentifiers[it])));
      for data.interfaceVariableIdentifiers     array_add(*operands, ac(GetSSAId(*data, it)));

      WriteSingleInstruction(*b, .EntryPoint, .. operands);
   }

   // execution modes
   if type == {
      case .Mesh; {
         WriteSingleInstruction(
            *b,
            .ExecutionModeId,
            GetSSAId(*data, .{ type = .Function, function = header }),
            SpvExecutionMode.LocalSizeId,
            GetSSAId(*data, .{ type = .IntLiteral, intLiteral = .{ unsigned = true, value._u64 = xx data.workgroupSize[0], bitSize = 32 } }),
            GetSSAId(*data, .{ type = .IntLiteral, intLiteral = .{ unsigned = true, value._u64 = xx data.workgroupSize[1], bitSize = 32 } }),
            GetSSAId(*data, .{ type = .IntLiteral, intLiteral = .{ unsigned = true, value._u64 = xx data.workgroupSize[2], bitSize = 32 } })
         );
         WriteSingleInstruction(
            *b,
            .ExecutionMode,
            GetSSAId(*data, .{ type = .Function, function = header }),
            SpvExecutionMode.OutputVertices,
            data.maxVertices
         );
         WriteSingleInstruction(
            *b,
            .ExecutionMode,
            GetSSAId(*data, .{ type = .Function, function = header }),
            SpvExecutionMode.OutputPrimitivesEXT,
            data.maxPrimitives
         );
         WriteSingleInstruction(
            *b,
            .ExecutionMode,
            GetSSAId(*data, .{ type = .Function, function = header }),
            ToSpirvOutputTopology(data.primitiveTopology)
         );
      }

      case .Fragment; {
         WriteSingleInstruction(
            *b,
            .ExecutionMode,
            GetSSAId(*data, .{ type = .Function, function = header }),
            SpvExecutionMode.OriginUpperLeft
         );
      }

      case .Rgen; {
         // nothing i guess Clueless
      }

      case .Rchit; {
         // nothing i guess Clueless
      }

      case .Rmiss; {
         // nothing i guess Clueless
      }

      case .Compute; {
         WriteSingleInstruction(
            *b,
            .ExecutionModeId,
            GetSSAId(*data, .{ type = .Function, function = header }),
            SpvExecutionMode.LocalSizeId,
            GetSSAId(*data, .{ type = .IntLiteral, intLiteral = .{ unsigned = true, value._u64 = xx data.workgroupSize[0], bitSize = 32 } }),
            GetSSAId(*data, .{ type = .IntLiteral, intLiteral = .{ unsigned = true, value._u64 = xx data.workgroupSize[1], bitSize = 32 } }),
            GetSSAId(*data, .{ type = .IntLiteral, intLiteral = .{ unsigned = true, value._u64 = xx data.workgroupSize[2], bitSize = 32 } })
         );
      }

      case; assert(false, "should have been unreachable because of the outer case.");
   }


   // skip debug info



   // annotations (decorations)
   #if SPIRV_BUILDER_TYPE == .String {
      print_to_builder(*b, "\n; annotations (decorations)\n");
   }

   if (type == .Mesh) {
      WriteSingleInstruction(
         *b,
         .Decorate,
         GetSSAId(*data, .{ type = ._Type, _type = cast(*Type_Info) MeshPerVertex }),
         SpvDecoration.Block
      );
      WriteSingleInstruction(
         *b,
         .MemberDecorate,
         GetSSAId(*data, .{ type = ._Type, _type = cast(*Type_Info) MeshPerVertex }),
         0,
         SpvDecoration.BuiltIn,
         SpvBuiltIn.Position
      );
      WriteSingleInstruction(
         *b,
         .MemberDecorate,
         GetSSAId(*data, .{ type = ._Type, _type = cast(*Type_Info) MeshPerVertex }),
         1,
         SpvDecoration.BuiltIn,
         SpvBuiltIn.PointSize
      );
   }

   //
   // i say location 0, and location 1. but idk if this is correct. for example glsl disallows this if meshVertexOut is a struct with more than one member
   // saying that there is an overlap. slang generates a location decoration for each member of the struct seperately.
   // i wrote the spirv assembly then assembled it and it worked. so idk. also spirv-val didnt complain about anything. so im gonn keep this for now
   // but i feel like this is wrong.
   // also in the specs there is no mention of this. it just says it applies to variables or struct members.
   // this overlap thingy happens if you use matrices as well. but there is no documentation for this so idk how to handle it other than reverse engineer and find out which sucks
   //
   // update: https://docs.vulkan.org/spec/latest/chapters/interfaces.html#interfaces-iointerfaces-limits
   // you can use 128 bit per location. one location has four components you can assign members to components
   // each component 32 bit.
   // so i cant say meshPrimitiveOut has location 1. i need to calculate its location from MeshVertexOut struct.
   // look for an implementation in glslangValidator, they must have something similar.
   //
   if type == {
      case .Mesh; {
         WriteSingleInstruction(
            *b,
            .Decorate,
            GetSSAId(*data, data.meshVertexOutVariableIdentifier),
            SpvDecoration.Location,
            0
         );
         WriteSingleInstruction(
            *b,
            .Decorate,
            GetSSAId(*data, data.meshPrimitiveOutVariableIdentifier),
            SpvDecoration.Location,
            data.locationsConsumedByPerVertexUserStruct
         );
         WriteSingleInstruction(
            *b,
            .Decorate,
            GetSSAId(*data, data.meshPrimitiveOutVariableIdentifier),
            SpvDecoration.PerPrimitiveEXT
         );
      }

      case .Fragment; {
         WriteSingleInstruction(
            *b,
            .Decorate,
            GetSSAId(*data, data.fragmentVertexInVariableIdentifier),
            SpvDecoration.Location,
            0
         );
         WriteSingleInstruction(
            *b,
            .Decorate,
            GetSSAId(*data, data.fragmentPrimitiveInVariableIdentifier),
            SpvDecoration.Location,
            data.locationsConsumedByPerVertexUserStruct
         );
         WriteSingleInstruction(
            *b,
            .Decorate,
            GetSSAId(*data, data.fragmentPrimitiveInVariableIdentifier),
            SpvDecoration.PerPrimitiveEXT
         );
      }

      case .Rgen; {
         // nothing i guess. there is no Location stuff in rgen.
      }

      case .Rchit; {
         // nothing i guess. there is no Location stuff in rgen.
      }

      case .Rmiss; {
         // nothing i guess. there is no Location stuff in rgen.
      }

      case .Compute; {
         // no inputs or outputs
      }

      case; assert(false, "should have been unreachable because of the outer case.");
   }

   // print_to_builder(*b, "OpDecorate \%% Block\n",
   //                      GetSSAId(*data, .{ type = ._Type, _type = cast(*Type_Info) PushData })
   // );
   // print_to_builder(*b, "OpMemberDecorate \%% 0 Offset 0\n", // task data pointer
   //                      GetSSAId(*data, .{ type = ._Type, _type = cast(*Type_Info) PushData })
   // );
   // print_to_builder(*b, "OpMemberDecorate \%% 1 Offset 8\n", // mesh data pointer
   //                      GetSSAId(*data, .{ type = ._Type, _type = cast(*Type_Info) PushData })
   // );
   // print_to_builder(*b, "OpMemberDecorate \%% 2 Offset 16\n", // fragment data pointer
   //                      GetSSAId(*data, .{ type = ._Type, _type = cast(*Type_Info) PushData })
   // );
   GetSSAId(*data, .{ type = ._Type, _type = cast(*Type_Info) MeshPipelinePushData });

   if (type == .Mesh) {
      WriteSingleInstruction(
         *b,
         .Decorate,
         GetSSAId(*data, meshPrimitiveIndicesIdentifiers[data.primitiveTopology]),
         SpvDecoration.BuiltIn,
         MESH_PRIMITIVE_INDICES[data.primitiveTopology].builtIn
      );
   }

   for GetUsedBuiltinVariables(*data) {
      WriteSingleInstruction(
         *b,
         .Decorate,
         GetSSAId(*data, builtinVariableIdentifiers[it]),
         SpvDecoration.BuiltIn,
         BUILTIN_VARIABLES[it].builtIn
      );

      // integer inputs of fragment shaders are not interpolated
      builtinType := builtinVariableIdentifiers[it].variable.declaration.type;
      if (type == .Fragment && IsIntScalarOrVector(builtinType)) {
         WriteSingleInstruction(*b, .Decorate, GetSSAId(*data, builtinVariableIdentifiers[it]), SpvDecoration.Flat);
      }
   }

   // This is the sole ResourceHeapEXT interface variable. images and tlases
   // remain separate source-level pseudo-arrays that select the loaded type.
   WriteSingleInstruction(
      *b,
      .Decorate,
      GetSSAId(*data, data.resourceHeapIdentifier),
      SpvDecoration.BuiltIn,
      SpvBuiltIn.ResourceHeapEXT
   );
   WriteSingleInstruction(
      *b,
      .Decorate,
      GetSSAId(*data, samplerHeapVariableIdentifier),
      SpvDecoration.BuiltIn,
      SpvBuiltIn.SamplerHeapEXT
   );

   // not necessary but voila. Restrict is already the default. if you wanted to alias you would have to type it here.
   // it is restrict becasue __push_data__.meshData is basically a dead pointer, never used (except to initialize shader data pointer).
   WriteSingleInstruction(
      *b,
      .Decorate,
      GetSSAId(*data, data.shaderDataPointerVariableIdentifier),
      SpvDecoration.RestrictPointer
   );

   if (type == .Fragment) {
      for data.fragmentOutputIdentifiers {
         WriteSingleInstruction(
            *b,
            .Decorate,
            GetSSAId(*data, it),
            SpvDecoration.Location,
            it_index
         );
      }
   }

   // need to copy because GetSSAId might modify identifierToSSAId while iterating over it      - apila, 09/09/26
   // runtime arrays
   runtimeArrays: [..] Identifier;
   for ssaId, identifier: data.identifierToSSAId {
      if (identifier.type != ._Type) continue;

      type := identifier._type;
      if (type.type != TYPE_INFO_RUNTIME_ARRAY_TAG) continue;

      array_add(*runtimeArrays, identifier);
   }

   for identifier: runtimeArrays {
      WriteRuntimeArrayStrideDecoration(*data, *b, identifier);
   }


   // Types, variables and constants
   //
   // the reason i need a seperate array is that WriteTypeOrVariableOrConstant might modify CompilationData.identifierToSSAId
   // i can avoid this and can make sure that all the identifiers are already added into CompilationData.identifierToSSAId before calling
   // WriteTypeOrVariableOrConstant but there is no need. WriteTypeOrVariableOrConstant is recursive so it suffices to iterate over what has been seen so far
   //             - apila, 13/04/26
   //
   typesConstantsVariables: [..] Identifier;
   for ssaId, identifier: data.identifierToSSAId {
      array_add(*typesConstantsVariables, identifier);
   }

   typesConstantsVariablesBuilder: BuilderType;

   #if SPIRV_BUILDER_TYPE == .String {
      print_to_builder(*b, "\n; Types, variables and constants\n");
   }

   for typesConstantsVariables {
      WriteTypeOrVariableOrConstant(*data, *typesConstantsVariablesBuilder, it);
   }


   // struct annotate infos
   #if SPIRV_BUILDER_TYPE == .String {
      print_to_builder(*b, "\n; struct annotate infos\n");
   }

   // fixed arrays used in buffers. local ones are decorationless copies (see decorationlessArrays)
   for ssaId, identifier: data.identifierToSSAId {
      if (identifier.type != ._Type) continue;
      if (identifier._type.type != .ARRAY) continue;

      tia := cast(*Type_Info_Array) identifier._type;
      if (tia.array_type != .FIXED || IsDecorationlessArray(tia) || IsMatrixType(tia)) continue;

      // jai lays out arrays with a stride of size_of(element)
      // using ssaId instead of GetSSAId because this loop iterates over identifierToSSAId, which GetSSAId may modify.
      WriteSingleInstruction(*b, .Decorate, ssaId, SpvDecoration.ArrayStride, tia.element_type.runtime_size);
   }

   structsToAnnotate: [..] Identifier;
   for ssaId, identifier: data.identifierToSSAId {
      if (identifier.type != ._Type) continue;
      ti := cast(*Type_Info) identifier._type;
      if (!(ti.type == .STRUCT || (ti.type == .ARRAY && ti.(*Type_Info_Array).array_type == .VIEW))) continue;

      if (CompareType(identifier._type, cast(*Type_Info) MeshPerVertex))  continue; // builtin struct handled seperately
      if (IsMatrixType(identifier._type))                                 continue;
      _, isNumeric := GetNumericInfo(identifier._type);
      if (isNumeric)                                                      continue;
      if (CompareType(identifier._type, cast(*Type_Info) __Image__))      continue;
      if (CompareType(identifier._type, cast(*Type_Info) __Sampler__))    continue;
      if (CompareType(identifier._type, cast(*Type_Info) __TLAS__))       continue;

      array_add(*structsToAnnotate, identifier);
   }

   for identifier: structsToAnnotate {
      // can be either Type_Info_Struct or Type_Info_Array with array type .VIEW;

      type := identifier._type;
      if type.type == {
         case .STRUCT; {
            annotateInfo := GetAnnotateInfoFromStruct(type);
            tis := type.(*Type_Info_Struct);

            // Stage input/output structs are interface types, not buffer
            // layout types.  In particular, Offset (and the other member
            // layout decorations) are invalid on an Input interface
            // variable.  The same user struct can still be used as a
            // physical-storage/push-constant struct elsewhere, so decide
            // this from the entry-point arguments rather than from the
            // struct type alone.
            isInterfaceStruct := false;
            if data.shaderType == .Fragment {
               isInterfaceStruct =
                  CompareType(type, data.fragmentVertexInVariableIdentifier.variable.declaration.type) ||
                  CompareType(type, data.fragmentPrimitiveInVariableIdentifier.variable.declaration.type);
            } else if data.shaderType == .Mesh {
               vertexType := GetArrayElementType(data.meshVertexOutVariableIdentifier.variable.declaration);
               primitiveType := GetArrayElementType(data.meshPrimitiveOutVariableIdentifier.variable.declaration);
               isInterfaceStruct = CompareType(type, vertexType) || CompareType(type, primitiveType);
            }

            // idk about the Block decoration.
            // i think it is not needed for any struct other than push constant block.
            // there is a problem that you cannot nest structs if both of them are decorated with Block.
            // i forgor why i introduced TypeInfoDecorationlessCopyOfStruct, is it because of Offset or Block? if it is because of Block
            // then i think it is not needed too.
            //       - apila, 24/09/26

            if (CompareType(type, type_info(RtxPipelinePushData)) || CompareType(type, type_info(MeshPipelinePushData)) || CompareType(type, type_info(ComputePipelinePushData))) {
               WriteSingleInstruction(
                  *b,
                  .Decorate,
                  GetSSAId(*data, identifier),
                  SpvDecoration.Block
               );
            }

            if (isInterfaceStruct) continue;

            for GetStructMembers(tis) {
               WriteSingleInstruction(
                  *b,
                  .MemberDecorate,
                  GetSSAId(*data, identifier),
                  it_index,
                  SpvDecoration.Offset,
                  it.offset_in_bytes
               );

               if (IsMatrixType(it.type)) {
                  WriteSingleInstruction(
                     *b,
                     .MemberDecorate,
                     GetSSAId(*data, identifier),
                     it_index,
                     SpvDecoration.ColMajor
                  );

                  vectorType := GetMatrixVector(it.type);
                  vectorSize := GetVectorSize(vectorType);

                  WriteSingleInstruction(
                     *b,
                     .MemberDecorate,
                     GetSSAId(*data, identifier),
                     it_index,
                     SpvDecoration.MatrixStride,
                     vectorSize
                  );
               }
            }
         }

         case .ARRAY; {
            tia := type.(*Type_Info_Array);
            assert(tia.array_type == .VIEW);

            // struct { count: int; data: *type };

            WriteSingleInstruction(
               *b,
               .MemberDecorate,
               GetSSAId(*data, identifier),
               ARRAY_VIEW_COUNT_FIELD_INDEX,
               SpvDecoration.Offset,
               type_info(Array_View_64).members[ARRAY_VIEW_COUNT_FIELD_INDEX].offset_in_bytes
            );

            WriteSingleInstruction(
               *b,
               .MemberDecorate,
               GetSSAId(*data, identifier),
               ARRAY_VIEW_DATA_FIELD_INDEX,
               SpvDecoration.Offset,
               type_info(Array_View_64).members[ARRAY_VIEW_DATA_FIELD_INDEX].offset_in_bytes
            );
         }

         case; assert(false, "unreachable");
      }
   }

   AppendAndStealBuffers(*b, *typesConstantsVariablesBuilder);


   // functions
   #if SPIRV_BUILDER_TYPE == .String {
      print_to_builder(*b, "\n; functions\n");
   }

   AppendAndStealBuffers(*b, *functionsBuilder);

   #if SPIRV_BUILDER_TYPE == {
      case .String;
         spirvasm := builder_to_string(*b);
         spirvContext := spvContextCreate(.SPV_ENV_VULKAN_1_4);
         defer spvContextDestroy(spirvContext);

         spirvOut: spv_binary;
         spirvDiagnostics: spv_diagnostic;
         spirvResult := spvTextToBinary(spirvContext, spirvasm.data, xx spirvasm.count, *spirvOut, *spirvDiagnostics);
         assert(spirvResult == .SUCCESS, "result: %", spirvResult);

         WORD_LENGTH :: size_of(type_of(spirvOut.code.*));
         assert(WORD_LENGTH == 4, "WORD_LENGTH: %", WORD_LENGTH);

         return .{
            data = xx spirvOut.code,
            count = xx spirvOut.wordCount * WORD_LENGTH
         };

      case .Byte;
         assert(b[3] == SSA_ID_BOUND_PLACEHOLDER);
         b[3] = xx (data.ssaIota + 1); // +1 because bound is not inclusive

         return .{
            data = xx b.data,
            count = b.count * size_of(type_of(b[69])),
         };

      case; assert(false, "not yet implemented! type: %", SPIRV_BUILDER_TYPE);
   }
}

// in depth first order
CalculateLocationsConsumed :: (T: *Type_Info) -> int {
   Helper :: (type: *Type_Info, accumulator: *int) {
      info, isNumeric := GetNumericInfo(type);
      if (isNumeric && info.kind != .Bool) {
         // 64 bit vectors with more than two components consume two locations
         accumulator.* += ifx info.bitSize == 64 && info.components > 2 then 2 else 1;
         return;
      }

      #if false {}
      else if (CompareType(type, cast(*Type_Info) f32x2x2)) { accumulator.* += 2; return; }
      else if (CompareType(type, cast(*Type_Info) f32x3x3)) { accumulator.* += 3; return; }
      else if (CompareType(type, cast(*Type_Info) f32x4x4)) { accumulator.* += 4; return; }
      else if (CompareType(type, cast(*Type_Info) f32x3x4)) { accumulator.* += 4; return; }

      ti := cast(*Type_Info) type;
      if (ti.type == .STRUCT) {
         tis := cast(*Type_Info_Struct) ti;
         for GetStructMembers(tis) {
            Helper(it.type, accumulator);
         }

         return;
      }

      // each element of an array consumes its own locations
      if (ti.type == .ARRAY && (cast(*Type_Info_Array) ti).array_type == .FIXED) {
         tia := cast(*Type_Info_Array) ti;
         elementLocations := 0;
         Helper(tia.element_type, *elementLocations);
         accumulator.* += elementLocations * tia.array_count;
         return;
      }

      // if i reached here then it means there is a member with a weird type
      assert(false, "if it is bool then it is not allowed. you need to pass an int or something. type: %\n", type.*);
   }

   result := 0;
   Helper(T, *result);
   return result;
}

//
// create a function AssignLocationsAndComponents :: (T: Type) where T is a struct.
// each location has 4 32bits, and each 32bits is also called a component. one location has 4 components.
// you should assign each struct member recursively (in depth first order) to a location and a component
// only numeric types are allowed (int or float). matrices are treated as if it was an array.
// 32bit vectors must be entirely in a single location. for example a vec4 has to be in a single location
// you can pack a float and a vec3 in a single location tho.
// 64bit vectors (eg. dvec4) then goes into two locations. one 64bit takes two components
// https://vulkan.lunarg.com/doc/view/1.4.313.0/windows/antora/guide/latest/location_component_interface.html
//
// implementation detail i am thinking of is have a cursor that starts at location 0, component 0, and increments as it traverses through
// the members of a struct in depth first order.
//
// idk the component thingy doesnt work properly even in glsl. better avoid it. maybe a driver bug. am just gonna use locations.
// also PerPrimitiveEXT decoration, specs says, can be applied to struct members but it doesnt work.
// so im gonna have two out variables and entire variable is gonna be decorated with PerPrimitiveEXT, the other variable will be per vertex by default.
// my experiments show that if you dont mix the perprimitve thing and per vertex things in the same location then it is fine you can use components
// but when you use them in the same location even if there is no component overlap it misbehaves.
// i couldnt figure out how the usage is with the struct members so im gonna just apply this to variables and calculate the next available location for the next varaible
// but i want to figure that one out. probably in the future if i have time.
// the docs are conflicting too. it says PerPrimitiveEXT can only be applied to a varaible then it says it can be applied to either a variable or a struct member https://github.khronos.org/SPIRV-Registry/extensions/EXT/SPV_EXT_mesh_shader.html
//
//             - apila, 04/04/26
//

SSA_ID_BOUND_PLACEHOLDER: u32 : 69_420_31;

// returns true if an entry is created, false if already exists
CreateFunctionDependencyEntryIfNotExists :: (table: *Table, entry: *Code_Procedure_Header) -> bool {
   pointer, newlyAdded := find_or_add(table, entry);
   if (newlyAdded) {
      // just putting .[] didn't work (neither .{}). compiler bug? idk.
      value: [..] *Code_Procedure_Header;
      pointer.* = value;
   }

   return newlyAdded;
}

// returns true if added, false if already exists
AddFunctionDependency :: (table: *Table, dependant: *Code_Procedure_Header, dependency: *Code_Procedure_Header) -> bool {
   pointer := find_or_add(table, dependant);
   newlyAdded := array_add_if_unique(pointer, dependency);
   return newlyAdded;
}

AddTypeDependency :: (table: *Table, dependant: Identifier, dependency: Identifier) {
   pointer := find_or_add(table, dependant);
   newlyAdded := array_add_if_unique(pointer, dependency, IdentifierCompare);
   assert(newlyAdded);
}

WriteRuntimeArrayStrideDecoration :: (data: *CompilationData, b: *BuilderType, identifier: Identifier) {
   assert(identifier.type == ._Type);
   tira := cast(*TypeInfoRuntimeArray) identifier._type;

   #if DESCRIPTOR_STRIDE_MODE == .Byte {
      assert(CompareType(tira.elementType, cast(*Type_Info) u8), "element type: %", tira.elementType.*);
      WriteSingleInstruction(b, .Decorate, GetSSAId(data, identifier), SpvDecoration.ArrayStride, 1);
   } else #if DESCRIPTOR_STRIDE_MODE == .DescriptorSize {
      strideIdentifier: Identifier = .{ type = .ConstantSizeOf, constantSizeOf = tira.elementType };
      AddTypeDependency(*data.extraTypeDependencies, identifier, strideIdentifier);
      WriteSingleInstruction(b, .DecorateId, GetSSAId(data, identifier), SpvDecoration.ArrayStrideIdEXT, GetSSAId(data, strideIdentifier));
   } else {
      #assert(false, "not implemented!");
   }
}

AddFixedArray :: (typeName: string, size: int, elementTypeName: string) {
   codeString := sprint("% :: [%] %;", typeName, size, elementTypeName);
   add_build_string(codeString, -1);
}

AppendBuffers :: (builder: *BuilderType, appendFrom: *BuilderType) {
   #if SPIRV_BUILDER_TYPE == .String {
      s := builder_to_string(appendFrom, do_reset = false);
      append(builder, s);
   } else #if SPIRV_BUILDER_TYPE == .Byte {
      array_add(builder, .. stealFrom.*);
   } else {
      #assert(false, "not implemented yet! type: %", SPIRV_BUILDER_TYPE);
   }
}

AppendAndStealBuffers :: (builder: *BuilderType, stealFrom: *BuilderType) {
   #if SPIRV_BUILDER_TYPE == .String {
      append_and_steal_buffers(builder, stealFrom);
   } else #if SPIRV_BUILDER_TYPE == .Byte {
      array_add(builder, .. stealFrom.*);
      array_reset(stealFrom);
   } else {
      #assert(false, "not implemented yet! type: %", SPIRV_BUILDER_TYPE);
   }
}

IsBranchInstruction :: inline (op: SpvOp) -> bool {
   if op == {
      case .BranchConditional; return true;
      case .Branch;            return true;
      case .Switch;            return true;
      case; return false;
   }
}

IsFunctionTerminationInstruction :: inline (op: SpvOp) -> bool {
   if op == {
      case .Return;              return true;
      case .ReturnValue;         return true;
      case .Kill;                return true;
      case .Unreachable;         return true;
      case .TerminateInvocation; return true;
      case; return false;
   }
}

IsBlockTerminationInstruction :: inline (op: SpvOp) -> bool {
   return IsBranchInstruction(op) || IsFunctionTerminationInstruction(op);
}

WriteSingleInstructionIfReachable :: (b: *BuilderType, blockReachableFlag: *bool, op: SpvOp, operands: ..Any) {
   if (op == .Label) blockReachableFlag.* = true;
   if (!blockReachableFlag.*) return;

   defer if (IsBlockTerminationInstruction(op)) {
      blockReachableFlag.* = false;
   }

   WriteSingleInstruction(b, op, .. operands);
}

// i think it is fine to do == on *Type_Info here since all the types come from metaprogram workspace Clueless    - apila, 23/05/26
WriteSingleInstruction :: (b: *BuilderType, op: SpvOp, operands: ..Any) {
   #if SPIRV_BUILDER_TYPE == .String {
      if op == {
         case .Capability; {
            assert(operands.count == 1);
            assert(operands[0].type == cast(*Type_Info) SpvCapability);

            capability := operands[0].value_pointer.(*SpvCapability).*;

            capabilityString := SpvCapabilityToString(capability);
            print_to_builder(b, "OpCapability %\n", capabilityString);
         }

         case .Extension; {
            assert(operands.count == 1);
            assert(operands[0].type == cast(*Type_Info) string);

            extension := operands[0].value_pointer.(*string).*;

            print_to_builder(b, "OpExtension \"%\"\n", extension);
         }

         case .ExtInstImport; {
            assert(operands.count == 2);
            assert(operands[0].type == cast(*Type_Info) SSAId);
            assert(operands[1].type == cast(*Type_Info) string);

            result := operands[0].value_pointer.(*SSAId).*;
            import := operands[1].value_pointer.(*string).*;

            print_to_builder(b, "\%% = OpExtInstImport \"%\"\n", result, import);
         }

         case .MemoryModel; {
            assert(operands.count == 2);
            assert(operands[0].type == cast(*Type_Info) SpvAddressingModel);
            assert(operands[1].type == cast(*Type_Info) SpvMemoryModel);

            addressingModel := operands[0].value_pointer.(*SpvAddressingModel).*;
            memoryModel     := operands[1].value_pointer.(*SpvMemoryModel).*;

            addressingModelString := SpvAddressingModelToString(addressingModel);
            memoryModelString := SpvMemoryModelToString(memoryModel);

            print_to_builder(b, "OpMemoryModel % %\n", addressingModelString, memoryModelString);
         }

         case .EntryPoint; {
            assert(operands.count >= 3);
            assert(operands[0].type == cast(*Type_Info) SpvExecutionModel);
            assert(operands[1].type == cast(*Type_Info) SSAId);
            assert(operands[2].type == cast(*Type_Info) string);

            executionModel := operands[0].value_pointer.(*SpvExecutionModel).*;
            entryPoint     := operands[1].value_pointer.(*SSAId).*;
            name           := operands[2].value_pointer.(*string).*;

            executionModelString := SpvExecutionModelToString(executionModel);

            print_to_builder(b, "OpEntryPoint % \%% \"%\"", executionModelString, entryPoint, name);

            for 3..operands.count - 1 {
               assert(operands[it].type == cast(*Type_Info) SSAId);

               operand := operands[it].value_pointer.(*SSAId).*;
               print_to_builder(b, " \%%", operand);
            }

            print_to_builder(b, "\n");
         }

         case .ExecutionModeId; {
            assert(operands.count >= 2);
            assert(operands[0].type == cast(*Type_Info) SSAId);
            assert(operands[1].type == cast(*Type_Info) SpvExecutionMode);

            entryPoint    := operands[0].value_pointer.(*SSAId).*;
            executionMode := operands[1].value_pointer.(*SpvExecutionMode).*;

            executionModeString := SpvExecutionModeToString(executionMode);

            print_to_builder(b, "OpExecutionModeId \%% %", entryPoint, executionModeString);

            for 2..operands.count - 1 {
               assert(operands[it].type == cast(*Type_Info) SSAId);

               operand := operands[it].value_pointer.(*SSAId).*;
               print_to_builder(b, " \%%", operand);
            }

            print_to_builder(b, "\n");
         }

         case .ExecutionMode; {
            assert(operands.count >= 2);
            assert(operands[0].type == cast(*Type_Info) SSAId);
            assert(operands[1].type == cast(*Type_Info) SpvExecutionMode);

            entryPoint    := operands[0].value_pointer.(*SSAId).*;
            executionMode := operands[1].value_pointer.(*SpvExecutionMode).*;

            executionModeString := SpvExecutionModeToString(executionMode);

            print_to_builder(b, "OpExecutionMode \%% %", entryPoint, executionModeString);

            for 2..operands.count - 1 {
               assert(operands[it].type == cast(*Type_Info) int);

               operand := operands[it].value_pointer.(*int).*;
               print_to_builder(b, " %", operand);
            }

            print_to_builder(b, "\n");
         }

         case .Decorate; {
            assert(operands.count >= 2);
            assert(operands[0].type == cast(*Type_Info) SSAId);
            assert(operands[1].type == cast(*Type_Info) SpvDecoration);

            target     := operands[0].value_pointer.(*SSAId).*;
            decoration := operands[1].value_pointer.(*SpvDecoration).*;

            decorationString := SpvDecorationToString(decoration);

            print_to_builder(b, "OpDecorate \%% %", target, decorationString);

            for 2..operands.count - 1 {
               assert(operands[it].type == cast(*Type_Info) int || operands[it].type == cast(*Type_Info) SpvBuiltIn);

               if (operands[it].type == cast(*Type_Info) int) {
                  operand := operands[it].value_pointer.(*int).*;
                  print_to_builder(b, " %", operand);
               } else if (operands[it].type == cast(*Type_Info) SpvBuiltIn) {
                  operand := operands[it].value_pointer.(*SpvBuiltIn).*;
                  operandString := SpvBuiltInToString(operand);
                  print_to_builder(b, " %", operandString);
               }
            }

            print_to_builder(b, "\n");
         }

         case .MemberDecorate; {
            assert(operands.count >= 3);
            assert(operands[0].type == cast(*Type_Info) SSAId);
            assert(operands[1].type == cast(*Type_Info) int);
            assert(operands[2].type == cast(*Type_Info) SpvDecoration);

            structType := operands[0].value_pointer.(*SSAId).*;
            member     := operands[1].value_pointer.(*int).*;
            decoration := operands[2].value_pointer.(*SpvDecoration).*;

            decorationString := SpvDecorationToString(decoration);

            print_to_builder(b, "OpMemberDecorate \%% % %", structType, member, decorationString);

            for 3..operands.count - 1 {
               assert(operands[it].type == cast(*Type_Info) SpvBuiltIn || operands[it].type == cast(*Type_Info) int);

               if (operands[it].type == cast(*Type_Info) SpvBuiltIn) {
                  builtin := operands[it].value_pointer.(*SpvBuiltIn).*;
                  builtinString := SpvBuiltInToString(builtin);
                  print_to_builder(b, " %", builtinString);
               } else if (operands[it].type == cast(*Type_Info) int) {
                  operand := operands[it].value_pointer.(*int).*;
                  print_to_builder(b, " %", operand);
               }
            }

            print_to_builder(b, "\n");
         }

         case .DecorateId; {
            assert(operands.count >= 3);
            assert(operands[0].type == cast(*Type_Info) SSAId);
            assert(operands[1].type == cast(*Type_Info) SpvDecoration);

            target     := operands[0].value_pointer.(*SSAId).*;
            decoration := operands[1].value_pointer.(*SpvDecoration).*;

            decorationString := SpvDecorationToString(decoration);

            print_to_builder(b, "OpDecorateId \%% %", target, decorationString);

            for 2..operands.count - 1 {
               assert(operands[it].type == cast(*Type_Info) SSAId);

               ssaId := operands[it].value_pointer.(*SSAId).*;
               print_to_builder(b, " \%%", ssaId);
            }

            print_to_builder(b, "\n");
         }

         case .Constant; {
            assert(operands.count == 3);
            assert(operands[0].type == cast(*Type_Info) SSAId);
            assert(operands[1].type == cast(*Type_Info) SSAId);
            assert(operands[2].type.type == .INTEGER || operands[2].type.type == .FLOAT);

            resultType := operands[0].value_pointer.(*SSAId).*;
            result     := operands[1].value_pointer.(*SSAId).*;
            value      := operands[2];

            print_to_builder(b, "\%% = OpConstant \%% %\n", result, resultType, value);
         }

         case .TypeInt; {
            assert(operands.count == 3);
            assert(operands[0].type == cast(*Type_Info) SSAId);
            assert(operands[1].type == cast(*Type_Info) int);
            assert(operands[2].type == cast(*Type_Info) int);

            result     := operands[0].value_pointer.(*SSAId).*;
            width      := operands[1].value_pointer.(*int).*;
            signedness := operands[2].value_pointer.(*int).*;

            print_to_builder(b, "\%% = OpTypeInt % %\n", result, width, signedness);
         }

         case .TypeFloat; {
            assert(operands.count == 2 || operands.count == 3);
            assert(operands[0].type == cast(*Type_Info) SSAId);
            assert(operands[1].type == cast(*Type_Info) int);

            result     := operands[0].value_pointer.(*SSAId).*;
            width      := operands[1].value_pointer.(*int).*;

            print_to_builder(b, "\%% = OpTypeFloat %", result, width);

            if (operands.count == 3) {
               assert(operands[2].type == cast(*Type_Info) SpvFPEncoding);

               encoding := operands[1].value_pointer.(*SpvFPEncoding).*;
               encodingString := SpvFPEncodingToString(encoding);
               print_to_builder(b, " %", encodingString);
            }

            print_to_builder(b, "\n");
         }

         case .TypeVector; {
            assert(operands.count == 3);
            assert(operands[0].type == cast(*Type_Info) SSAId);
            assert(operands[1].type == cast(*Type_Info) SSAId);
            assert(operands[2].type == cast(*Type_Info) int);

            result         := operands[0].value_pointer.(*SSAId).*;
            componentType  := operands[1].value_pointer.(*SSAId).*;
            componentCount := operands[2].value_pointer.(*int).*;

            print_to_builder(b, "\%% = OpTypeVector \%% %\n", result, componentType, componentCount);
         }

         case .TypeMatrix; {
            assert(operands.count == 3);
            assert(operands[0].type == cast(*Type_Info) SSAId);
            assert(operands[1].type == cast(*Type_Info) SSAId);
            assert(operands[2].type == cast(*Type_Info) int);

            result      := operands[0].value_pointer.(*SSAId).*;
            columnType  := operands[1].value_pointer.(*SSAId).*;
            columnCount := operands[2].value_pointer.(*int).*;

            print_to_builder(b, "\%% = OpTypeMatrix \%% %\n", result, columnType, columnCount);
         }

         case .TypeBool; {
            assert(operands.count == 1);
            assert(operands[0].type == cast(*Type_Info) SSAId);

            result := operands[0].value_pointer.(*SSAId).*;

            print_to_builder(b, "\%% = OpTypeBool\n", result);
         }

         case .TypeStruct; {
            // spirv specs: "It is valid for the structure to have no members"
            assert(operands.count >= 1);
            assert(operands[0].type == cast(*Type_Info) SSAId);

            result := operands[0].value_pointer.(*SSAId).*;

            print_to_builder(b, "\%% = OpTypeStruct", result);

            for 1..operands.count - 1 {
               assert(operands[it].type == cast(*Type_Info) SSAId);

               memberType := operands[it].value_pointer.(*SSAId).*;
               print_to_builder(b, " \%%", memberType);
            }

            print_to_builder(b, "\n");
         }

         case .TypeSampledImage; {
            assert(operands.count == 2);
            assert(operands[0].type == cast(*Type_Info) SSAId);
            assert(operands[1].type == cast(*Type_Info) SSAId);

            result    := operands[0].value_pointer.(*SSAId).*;
            imageType := operands[1].value_pointer.(*SSAId).*;

            print_to_builder(b, "\%% = OpTypeSampledImage \%%\n", result, imageType);
         }

         case .TypeSampler; {
            assert(operands.count == 1);
            assert(operands[0].type == cast(*Type_Info) SSAId);

            result := operands[0].value_pointer.(*SSAId).*;

            print_to_builder(b, "\%% = OpTypeSampler\n", result);
         }

         case .TypeImage; {
            assert(operands.count == 8 || operands.count == 9);
            assert(operands[0].type == cast(*Type_Info) SSAId);
            assert(operands[1].type == cast(*Type_Info) SSAId);
            assert(operands[2].type == cast(*Type_Info) SpvDim);
            assert(operands[3].type == cast(*Type_Info) int);
            assert(operands[4].type == cast(*Type_Info) int);
            assert(operands[5].type == cast(*Type_Info) int);
            assert(operands[6].type == cast(*Type_Info) int);
            assert(operands[7].type == cast(*Type_Info) SpvImageFormat);

            result      := operands[0].value_pointer.(*SSAId).*;
            sampledType := operands[1].value_pointer.(*SSAId).*;
            dim         := operands[2].value_pointer.(*SpvDim).*;
            depth       := operands[3].value_pointer.(*int).*;
            arrayed     := operands[4].value_pointer.(*int).*;
            ms          := operands[5].value_pointer.(*int).*;
            sampled     := operands[6].value_pointer.(*int).*;
            imageFormat := operands[7].value_pointer.(*SpvImageFormat).*;

            dimString := SpvDimToString(dim);
            imageFormatString := SpvImageFormatToString(imageFormat);

            print_to_builder(b, "\%% = OpTypeImage \%% % % % % % %", result, sampledType, dimString, depth, arrayed, ms, sampled, imageFormatString);

            if (operands.count == 9) {
               assert(operands[8].type == cast(*Type_Info) SpvAccessQualifier);

               accessQualifier := operands[8].value_pointer.(*SpvAccessQualifier).*;
               accessQualifierString := SpvAccessQualifierToString(accessQualifier);
               print_to_builder(b, " %", accessQualifierString);
            }

            print_to_builder(b, "\n");
         }

         case .TypeRuntimeArray; {
            assert(operands.count == 2);
            assert(operands[0].type == cast(*Type_Info) SSAId);
            assert(operands[1].type == cast(*Type_Info) SSAId);

            result      := operands[0].value_pointer.(*SSAId).*;
            elementType := operands[1].value_pointer.(*SSAId).*;

            print_to_builder(b, "\%% = OpTypeRuntimeArray \%%\n", result, elementType);
         }

         case .TypeUntypedPointerKHR; {
            assert(operands.count == 2);
            assert(operands[0].type == cast(*Type_Info) SSAId);
            assert(operands[1].type == cast(*Type_Info) SpvStorageClass);

            result       := operands[0].value_pointer.(*SSAId).*;
            storageClass := operands[1].value_pointer.(*SpvStorageClass).*;

            storageClassString := SpvStorageClassToString(storageClass);

            print_to_builder(b, "\%% = OpTypeUntypedPointerKHR %\n", result, storageClassString);
         }

         case .TypePointer; {
            assert(operands.count == 3);
            assert(operands[0].type == cast(*Type_Info) SSAId);
            assert(operands[1].type == cast(*Type_Info) SpvStorageClass);
            assert(operands[2].type == cast(*Type_Info) SSAId);

            result       := operands[0].value_pointer.(*SSAId).*;
            storageClass := operands[1].value_pointer.(*SpvStorageClass).*;
            type         := operands[2].value_pointer.(*SSAId).*;

            storageClassString := SpvStorageClassToString(storageClass);

            print_to_builder(b, "\%% = OpTypePointer % \%%\n", result, storageClassString, type);
         }

         case .TypeForwardPointer; {
            assert(operands.count == 2);
            assert(operands[0].type == cast(*Type_Info) SSAId);
            assert(operands[1].type == cast(*Type_Info) SpvStorageClass);

            pointerType  := operands[0].value_pointer.(*SSAId).*;
            storageClass := operands[1].value_pointer.(*SpvStorageClass).*;

            print_to_builder(b, "OpTypeForwardPointer \%% %\n", pointerType, SpvStorageClassToString(storageClass));
         }

         case .TypeFunction; {
            assert(operands.count >= 2);
            assert(operands[0].type == cast(*Type_Info) SSAId);
            assert(operands[1].type == cast(*Type_Info) SSAId);

            result     := operands[0].value_pointer.(*SSAId).*;
            returnType := operands[1].value_pointer.(*SSAId).*;

            print_to_builder(b, "\%% = OpTypeFunction \%%", result, returnType);

            for 2..operands.count - 1 {
               assert(operands[it].type == cast(*Type_Info) SSAId);

               parameterType := operands[it].value_pointer.(*SSAId).*;
               print_to_builder(b, " \%%", parameterType);
            }

            print_to_builder(b, "\n");
         }

         case .TypeArray; {
            assert(operands.count == 3);
            assert(operands[0].type == cast(*Type_Info) SSAId);
            assert(operands[1].type == cast(*Type_Info) SSAId);
            assert(operands[2].type == cast(*Type_Info) SSAId);

            result      := operands[0].value_pointer.(*SSAId).*;
            elementType := operands[1].value_pointer.(*SSAId).*;
            length      := operands[2].value_pointer.(*SSAId).*;

            print_to_builder(b, "\%% = OpTypeArray \%% \%%\n", result, elementType, length);
         }

         case .TypeVoid; {
            assert(operands.count == 1);
            assert(operands[0].type == cast(*Type_Info) SSAId);

            result := operands[0].value_pointer.(*SSAId).*;

            print_to_builder(b, "\%% = OpTypeVoid\n", result);
         }

         case .Variable; {
            assert(operands.count == 3 || operands.count == 4);
            assert(operands[0].type == cast(*Type_Info) SSAId);
            assert(operands[1].type == cast(*Type_Info) SSAId);
            assert(operands[2].type == cast(*Type_Info) SpvStorageClass);

            resultType   := operands[0].value_pointer.(*SSAId).*;
            result       := operands[1].value_pointer.(*SSAId).*;
            storageClass := operands[2].value_pointer.(*SpvStorageClass).*;

            storageClassString := SpvStorageClassToString(storageClass);

            print_to_builder(b, "\%% = OpVariable \%% %", result, resultType, storageClassString);

            if (operands.count == 4) {
               assert(operands[3].type == cast(*Type_Info) SSAId);

               initializer := operands[3].value_pointer.(*SSAId).*;
               print_to_builder(b, " \%%", initializer);
            }

            print_to_builder(b, "\n");
         }

         case .UntypedVariableKHR; {
            assert(operands.count >= 3 || operands.count <= 5);
            assert(operands[0].type == cast(*Type_Info) SSAId);
            assert(operands[1].type == cast(*Type_Info) SSAId);
            assert(operands[2].type == cast(*Type_Info) SpvStorageClass);

            resultType   := operands[0].value_pointer.(*SSAId).*;
            result       := operands[1].value_pointer.(*SSAId).*;
            storageClass := operands[2].value_pointer.(*SpvStorageClass).*;

            storageClassString := SpvStorageClassToString(storageClass);

            print_to_builder(b, "\%% = OpUntypedVariableKHR \%% %", result, resultType, storageClassString);

            if (operands.count > 3) {
               assert(operands[3].type == cast(*Type_Info) SSAId);

               dataType := operands[3].value_pointer.(*SSAId).*;
               print_to_builder(b, " \%%", dataType);

               if (operands.count > 4) {
                  assert(operands[4].type == cast(*Type_Info) SSAId);

                  initializer := operands[4].value_pointer.(*SSAId).*;
                  print_to_builder(b, " \%%", initializer);
               }
            }

            print_to_builder(b, "\n");
         }

         case .ConstantComposite; {
            assert(operands.count >= 3);
            assert(operands[0].type == cast(*Type_Info) SSAId);
            assert(operands[1].type == cast(*Type_Info) SSAId);

            resultType := operands[0].value_pointer.(*SSAId).*;
            result     := operands[1].value_pointer.(*SSAId).*;

            print_to_builder(b, "\%% = OpConstantComposite \%%", result, resultType);

            for 2..operands.count - 1 {
               assert(operands[it].type == cast(*Type_Info) SSAId);

               constituent := operands[it].value_pointer.(*SSAId).*;
               print_to_builder(b, " \%%", constituent);
            }

            print_to_builder(b, "\n");
         }

         case .ConstantTrue; {
            assert(operands.count == 2);
            assert(operands[0].type == cast(*Type_Info) SSAId);
            assert(operands[1].type == cast(*Type_Info) SSAId);

            resultType := operands[0].value_pointer.(*SSAId).*;
            result     := operands[1].value_pointer.(*SSAId).*;

            print_to_builder(b, "\%% = OpConstantTrue \%%\n", result, resultType);
         }

         case .ConstantFalse; {
            assert(operands.count == 2);
            assert(operands[0].type == cast(*Type_Info) SSAId);
            assert(operands[1].type == cast(*Type_Info) SSAId);

            resultType := operands[0].value_pointer.(*SSAId).*;
            result     := operands[1].value_pointer.(*SSAId).*;

            print_to_builder(b, "\%% = OpConstantFalse \%%\n", result, resultType);
         }

         case .ConstantNull; {
            assert(operands.count == 2);
            assert(operands[0].type == cast(*Type_Info) SSAId);
            assert(operands[1].type == cast(*Type_Info) SSAId);

            resultType := operands[0].value_pointer.(*SSAId).*;
            result     := operands[1].value_pointer.(*SSAId).*;

            print_to_builder(b, "\%% = OpConstantNull \%%\n", result, resultType);
         }

         case .ConstantSizeOfEXT; {
            assert(operands.count == 3);
            assert(operands[0].type == cast(*Type_Info) SSAId);
            assert(operands[1].type == cast(*Type_Info) SSAId);
            assert(operands[2].type == cast(*Type_Info) SSAId);

            resultType := operands[0].value_pointer.(*SSAId).*;
            result     := operands[1].value_pointer.(*SSAId).*;
            type       := operands[2].value_pointer.(*SSAId).*;

            print_to_builder(b, "\%% = OpConstantSizeOfEXT \%% \%%\n", result, resultType, type);
         }

         case .DPdy; {
            assert(operands.count == 3);
            assert(operands[0].type == cast(*Type_Info) SSAId);
            assert(operands[1].type == cast(*Type_Info) SSAId);
            assert(operands[2].type == cast(*Type_Info) SSAId);

            resultType := operands[0].value_pointer.(*SSAId).*;
            result     := operands[1].value_pointer.(*SSAId).*;
            p          := operands[2].value_pointer.(*SSAId).*;

            print_to_builder(b, "\%% = OpDPdy \%% \%%\n", result, resultType, p);
         }

         case .DPdx; {
            assert(operands.count == 3);
            assert(operands[0].type == cast(*Type_Info) SSAId);
            assert(operands[1].type == cast(*Type_Info) SSAId);
            assert(operands[2].type == cast(*Type_Info) SSAId);

            resultType := operands[0].value_pointer.(*SSAId).*;
            result     := operands[1].value_pointer.(*SSAId).*;
            p          := operands[2].value_pointer.(*SSAId).*;

            print_to_builder(b, "\%% = OpDPdx \%% \%%\n", result, resultType, p);
         }

         case .Fwidth; #through;
         case .Transpose; {
            assert(operands.count == 3);
            for operands  assert(it.type == cast(*Type_Info) SSAId);
            print_to_builder(b, "\%% = Op% \%% \%%\n", operands[1].value_pointer.(*SSAId).*, op, operands[0].value_pointer.(*SSAId).*, operands[2].value_pointer.(*SSAId).*);
         }

         case .VectorTimesMatrix; {
            assert(operands.count == 4);
            for operands  assert(it.type == cast(*Type_Info) SSAId);
            print_to_builder(b, "\%% = OpVectorTimesMatrix \%% \%% \%%\n", operands[1].value_pointer.(*SSAId).*, operands[0].value_pointer.(*SSAId).*, operands[2].value_pointer.(*SSAId).*, operands[3].value_pointer.(*SSAId).*);
         }

         case .Function; {
            assert(operands.count == 4);
            assert(operands[0].type == cast(*Type_Info) SSAId);
            assert(operands[1].type == cast(*Type_Info) SSAId);
            assert(operands[2].type == cast(*Type_Info) SpvFunctionControlMask);
            assert(operands[3].type == cast(*Type_Info) SSAId);

            resultType      := operands[0].value_pointer.(*SSAId).*;
            result          := operands[1].value_pointer.(*SSAId).*;
            functionControl := operands[2].value_pointer.(*SpvFunctionControlMask).*;
            functionType    := operands[3].value_pointer.(*SSAId).*;

            functionControlString := SpvFunctionControlMaskToString(functionControl);

            print_to_builder(b, "\%% = OpFunction \%% % \%%\n", result, resultType, functionControlString, functionType);
         }

         case .Label; {
            assert(operands.count == 1);
            assert(operands[0].type == cast(*Type_Info) SSAId);

            result := operands[0].value_pointer.(*SSAId).*;

            print_to_builder(b, "\%% = OpLabel\n", result);
         }

         case .Return; {
            assert(operands.count == 0);
            print_to_builder(b, "OpReturn\n");
         }

         case .FunctionEnd; {
            assert(operands.count == 0);
            print_to_builder(b, "OpFunctionEnd\n");
         }

         case .CompositeConstruct; {
            assert(operands.count >= 3);
            assert(operands[0].type == cast(*Type_Info) SSAId);
            assert(operands[1].type == cast(*Type_Info) SSAId);

            resultType := operands[0].value_pointer.(*SSAId).*;
            result     := operands[1].value_pointer.(*SSAId).*;

            print_to_builder(b, "\%% = OpCompositeConstruct \%%", result, resultType);

            for 2..operands.count - 1 {
               assert(operands[it].type == cast(*Type_Info) SSAId);

               constituent := operands[it].value_pointer.(*SSAId).*;
               print_to_builder(b, " \%%", constituent);
            }

            print_to_builder(b, "\n");
         }

         case .Store; {
            assert(operands.count >= 2);
            assert(operands[0].type == cast(*Type_Info) SSAId);
            assert(operands[1].type == cast(*Type_Info) SSAId);

            pointer := operands[0].value_pointer.(*SSAId).*;
            object  := operands[1].value_pointer.(*SSAId).*;

            print_to_builder(b, "OpStore \%% \%%", pointer, object);

            for 2..operands.count - 1 {
               assert(false, "not yet implemented! try the byte builder instead.");
            }

            print_to_builder(b, "\n");
         }

         case .SetMeshOutputsEXT; {
            assert(operands.count == 2);
            assert(operands[0].type == cast(*Type_Info) SSAId);
            assert(operands[1].type == cast(*Type_Info) SSAId);

            vertexCount    := operands[0].value_pointer.(*SSAId).*;
            primitiveCount := operands[1].value_pointer.(*SSAId).*;

            print_to_builder(b, "OpSetMeshOutputsEXT \%% \%%\n", vertexCount, primitiveCount);
         }

         case .ReturnValue; {
            assert(operands.count == 1);
            assert(operands[0].type == cast(*Type_Info) SSAId);

            value := operands[0].value_pointer.(*SSAId).*;

            print_to_builder(b, "OpReturnValue \%%\n", value);
         }

         case .SampledImage; {
            assert(operands.count == 4);
            assert(operands[0].type == cast(*Type_Info) SSAId);
            assert(operands[1].type == cast(*Type_Info) SSAId);
            assert(operands[2].type == cast(*Type_Info) SSAId);
            assert(operands[3].type == cast(*Type_Info) SSAId);

            resultType := operands[0].value_pointer.(*SSAId).*;
            result     := operands[1].value_pointer.(*SSAId).*;
            image      := operands[2].value_pointer.(*SSAId).*;
            sampler    := operands[3].value_pointer.(*SSAId).*;

            print_to_builder(b, "\%% = OpSampledImage \%% \%% \%%\n", result, resultType, image, sampler);
         }

         case .ImageSampleImplicitLod; {
            assert(operands.count >= 4);
            assert(operands[0].type == cast(*Type_Info) SSAId);
            assert(operands[1].type == cast(*Type_Info) SSAId);
            assert(operands[2].type == cast(*Type_Info) SSAId);
            assert(operands[3].type == cast(*Type_Info) SSAId);

            resultType   := operands[0].value_pointer.(*SSAId).*;
            result       := operands[1].value_pointer.(*SSAId).*;
            sampledImage := operands[2].value_pointer.(*SSAId).*;
            coordinate   := operands[3].value_pointer.(*SSAId).*;

            print_to_builder(b, "\%% = OpImageSampleImplicitLod \%% \%% \%%", result, resultType, sampledImage, coordinate);

            if (operands.count > 4) {
               assert(false, "not yet implemented! maybe try byte builder instead.");
               assert(operands[4].type == cast(*Type_Info) SpvImageOperandsMask);

               for 5..operands.count - 1 {

               }
            }

            print_to_builder(b, "\n");
         }

         case .SelectionMerge; {
            assert(operands.count == 2);
            assert(operands[0].type == cast(*Type_Info) SSAId);
            assert(operands[1].type == cast(*Type_Info) SpvSelectionControlMask);

            mergeBlock       := operands[0].value_pointer.(*SSAId).*;
            selectionControl := operands[1].value_pointer.(*SpvSelectionControlMask).*;

            assert(selectionControl == SpvSelectionControlMask.MaskNone, "not yet implemented! maybe try byte builder.");
            print_to_builder(b, "OpSelectionMerge \%% None\n", mergeBlock);
         }

         case .BranchConditional; {
            assert(operands.count == 3 || operands.count == 5);
            assert(operands[0].type == cast(*Type_Info) SSAId);
            assert(operands[1].type == cast(*Type_Info) SSAId);
            assert(operands[2].type == cast(*Type_Info) SSAId);

            condition  := operands[0].value_pointer.(*SSAId).*;
            trueLabel  := operands[1].value_pointer.(*SSAId).*;
            falseLabel := operands[2].value_pointer.(*SSAId).*;

            print_to_builder(b, "OpBranchConditional \%% \%% \%%", condition, trueLabel, falseLabel);

            if (operands.count == 5) {
               assert(operands[3].type == cast(*Type_Info) int);
               assert(operands[4].type == cast(*Type_Info) int);

               trueWeight  := operands[3].value_pointer.(*int).*;
               falseWeight := operands[4].value_pointer.(*int).*;

               print_to_builder(b, " % %", trueWeight, falseWeight);
            }

            print_to_builder(b, "\n");
         }

         case .Branch; {
            assert(operands.count == 1);
            assert(operands[0].type == cast(*Type_Info) SSAId);

            targetLabel := operands[0].value_pointer.(*SSAId).*;

            print_to_builder(b, "\%% = OpLabel\n", targetLabel);
         }

         case .Bitcast; {
            assert(operands.count == 3);
            assert(operands[0].type == cast(*Type_Info) SSAId);
            assert(operands[1].type == cast(*Type_Info) SSAId);
            assert(operands[2].type == cast(*Type_Info) SSAId);

            resultType := operands[0].value_pointer.(*SSAId).*;
            result     := operands[1].value_pointer.(*SSAId).*;
            operand    := operands[2].value_pointer.(*SSAId).*;

            print_to_builder(b, "\%% = OpBitcast \%% \%%\n", result, resultType, operand);
         }

         case .ConvertUToF; {
            assert(operands.count == 3);
            assert(operands[0].type == cast(*Type_Info) SSAId);
            assert(operands[1].type == cast(*Type_Info) SSAId);
            assert(operands[2].type == cast(*Type_Info) SSAId);

            resultType := operands[0].value_pointer.(*SSAId).*;
            result     := operands[1].value_pointer.(*SSAId).*;
            operand    := operands[2].value_pointer.(*SSAId).*;

            print_to_builder(b, "\%% = OpConvertUToF \%% \%%\n", result, resultType, operand);
         }

         case .Load; {
            assert(operands.count >= 3);
            assert(operands[0].type == cast(*Type_Info) SSAId);
            assert(operands[1].type == cast(*Type_Info) SSAId);
            assert(operands[2].type == cast(*Type_Info) SSAId);

            resultType := operands[0].value_pointer.(*SSAId).*;
            result     := operands[1].value_pointer.(*SSAId).*;
            pointer    := operands[2].value_pointer.(*SSAId).*;

            print_to_builder(b, "\%% = OpLoad \%% \%%", result, resultType, pointer);

            if (operands.count > 3) {
               assert(operands[3].type == cast(*Type_Info) SpvMemoryAccessMask);

               memoryOperand := operands[3].value_pointer.(*SpvMemoryAccessMask).*;

               assert(memoryOperand == .AlignedMask, "not yet implemented! try byte builder instead.");
               align := operands[4].value_pointer.(*int).*;

               print_to_builder(b, " Aligned %", align);
            }

            print_to_builder(b, "\n");
         }

         case .UntypedAccessChainKHR; {
            assert(operands.count >= 5);
            assert(operands[0].type == cast(*Type_Info) SSAId);
            assert(operands[1].type == cast(*Type_Info) SSAId);
            assert(operands[2].type == cast(*Type_Info) SSAId);
            assert(operands[3].type == cast(*Type_Info) SSAId);

            resultType := operands[0].value_pointer.(*SSAId).*;
            result     := operands[1].value_pointer.(*SSAId).*;
            baseType   := operands[2].value_pointer.(*SSAId).*;
            base       := operands[3].value_pointer.(*SSAId).*;

            print_to_builder(b, "\%% = OpUntypedAccessChainKHR \%% \%% \%%", result, resultType, baseType, base);

            for 4..operands.count - 1 {
               assert(operands[it].type == cast(*Type_Info) SSAId);

               index := operands[it].value_pointer.(*SSAId).*;
               print_to_builder(b, " \%%", index);
            }

            print_to_builder(b, "\n");
         }

         case .AccessChain; {
            assert(operands.count >= 4);
            assert(operands[0].type == cast(*Type_Info) SSAId);
            assert(operands[1].type == cast(*Type_Info) SSAId);
            assert(operands[2].type == cast(*Type_Info) SSAId);

            resultType := operands[0].value_pointer.(*SSAId).*;
            result     := operands[1].value_pointer.(*SSAId).*;
            base       := operands[2].value_pointer.(*SSAId).*;

            print_to_builder(b, "\%% = OpAccessChain \%% \%%", result, resultType, base);

            for 3..operands.count - 1 {
               assert(operands[it].type == cast(*Type_Info) SSAId);

               index := operands[it].value_pointer.(*SSAId).*;
               print_to_builder(b, " \%%", index);
            }

            print_to_builder(b, "\n");
         }

         case .CompositeExtract; {
            assert(operands.count >= 4, "count: %, %", operands.count, operands);
            assert(operands[0].type == cast(*Type_Info) SSAId);
            assert(operands[1].type == cast(*Type_Info) SSAId);
            assert(operands[2].type == cast(*Type_Info) SSAId);

            resultType := operands[0].value_pointer.(*SSAId).*;
            result     := operands[1].value_pointer.(*SSAId).*;
            composite  := operands[2].value_pointer.(*SSAId).*;

            print_to_builder(b, "\%% = OpCompositeExtract \%% \%%", result, resultType, composite);

            for 3..operands.count - 1 {
               assert(operands[it].type == cast(*Type_Info) int);

               index := operands[it].value_pointer.(*int).*;
               print_to_builder(b, " %", index);
            }

            print_to_builder(b, "\n");
         }

         case .FAdd; {
            assert(operands.count == 4);
            assert(operands[0].type == cast(*Type_Info) SSAId);
            assert(operands[1].type == cast(*Type_Info) SSAId);
            assert(operands[2].type == cast(*Type_Info) SSAId);
            assert(operands[3].type == cast(*Type_Info) SSAId);

            resultType := operands[0].value_pointer.(*SSAId).*;
            result     := operands[1].value_pointer.(*SSAId).*;
            operand1   := operands[2].value_pointer.(*SSAId).*;
            operand2   := operands[3].value_pointer.(*SSAId).*;

            print_to_builder(b, "\%% = OpFAdd \%% \%% \%%\n", result, resultType, operand1, operand2);
         }

         case .FSub; {
            assert(operands.count == 4);
            assert(operands[0].type == cast(*Type_Info) SSAId);
            assert(operands[1].type == cast(*Type_Info) SSAId);
            assert(operands[2].type == cast(*Type_Info) SSAId);
            assert(operands[3].type == cast(*Type_Info) SSAId);

            resultType := operands[0].value_pointer.(*SSAId).*;
            result     := operands[1].value_pointer.(*SSAId).*;
            operand1   := operands[2].value_pointer.(*SSAId).*;
            operand2   := operands[3].value_pointer.(*SSAId).*;

            print_to_builder(b, "\%% = OpFSub \%% \%% \%%\n", result, resultType, operand1, operand2);
         }

         case .IAdd; {
            assert(operands.count == 4);
            assert(operands[0].type == cast(*Type_Info) SSAId);
            assert(operands[1].type == cast(*Type_Info) SSAId);
            assert(operands[2].type == cast(*Type_Info) SSAId);
            assert(operands[3].type == cast(*Type_Info) SSAId);

            resultType := operands[0].value_pointer.(*SSAId).*;
            result     := operands[1].value_pointer.(*SSAId).*;
            operand1   := operands[2].value_pointer.(*SSAId).*;
            operand2   := operands[3].value_pointer.(*SSAId).*;

            print_to_builder(b, "\%% = OpIAdd \%% \%% \%%\n", result, resultType, operand1, operand2);
         }

         case .ISub; {
            assert(operands.count == 4);
            assert(operands[0].type == cast(*Type_Info) SSAId);
            assert(operands[1].type == cast(*Type_Info) SSAId);
            assert(operands[2].type == cast(*Type_Info) SSAId);
            assert(operands[3].type == cast(*Type_Info) SSAId);

            resultType := operands[0].value_pointer.(*SSAId).*;
            result     := operands[1].value_pointer.(*SSAId).*;
            operand1   := operands[2].value_pointer.(*SSAId).*;
            operand2   := operands[3].value_pointer.(*SSAId).*;

            print_to_builder(b, "\%% = OpISub \%% \%% \%%\n", result, resultType, operand1, operand2);
         }

         case .IMul; {
            assert(operands.count == 4);
            assert(operands[0].type == cast(*Type_Info) SSAId);
            assert(operands[1].type == cast(*Type_Info) SSAId);
            assert(operands[2].type == cast(*Type_Info) SSAId);
            assert(operands[3].type == cast(*Type_Info) SSAId);

            resultType := operands[0].value_pointer.(*SSAId).*;
            result     := operands[1].value_pointer.(*SSAId).*;
            operand1   := operands[2].value_pointer.(*SSAId).*;
            operand2   := operands[3].value_pointer.(*SSAId).*;

            print_to_builder(b, "\%% = OpIMul \%% \%% \%%\n", result, resultType, operand1, operand2);
         }

         case .FDiv; {
            assert(operands.count == 4);
            assert(operands[0].type == cast(*Type_Info) SSAId);
            assert(operands[1].type == cast(*Type_Info) SSAId);
            assert(operands[2].type == cast(*Type_Info) SSAId);
            assert(operands[3].type == cast(*Type_Info) SSAId);

            resultType := operands[0].value_pointer.(*SSAId).*;
            result     := operands[1].value_pointer.(*SSAId).*;
            operand1   := operands[2].value_pointer.(*SSAId).*;
            operand2   := operands[3].value_pointer.(*SSAId).*;

            print_to_builder(b, "\%% = OpFDiv \%% \%% \%%\n", result, resultType, operand1, operand2);
         }

         case .FMul; {
            assert(operands.count == 4);
            assert(operands[0].type == cast(*Type_Info) SSAId);
            assert(operands[1].type == cast(*Type_Info) SSAId);
            assert(operands[2].type == cast(*Type_Info) SSAId);
            assert(operands[3].type == cast(*Type_Info) SSAId);

            resultType := operands[0].value_pointer.(*SSAId).*;
            result     := operands[1].value_pointer.(*SSAId).*;
            operand1   := operands[2].value_pointer.(*SSAId).*;
            operand2   := operands[3].value_pointer.(*SSAId).*;

            print_to_builder(b, "\%% = OpFMul \%% \%% \%%\n", result, resultType, operand1, operand2);
         }

         case .SLessThan; {
            assert(operands.count == 4);
            assert(operands[0].type == cast(*Type_Info) SSAId);
            assert(operands[1].type == cast(*Type_Info) SSAId);
            assert(operands[2].type == cast(*Type_Info) SSAId);
            assert(operands[3].type == cast(*Type_Info) SSAId);

            resultType := operands[0].value_pointer.(*SSAId).*;
            result     := operands[1].value_pointer.(*SSAId).*;
            operand1   := operands[2].value_pointer.(*SSAId).*;
            operand2   := operands[3].value_pointer.(*SSAId).*;

            print_to_builder(b, "\%% = OpSLessThan \%% \%% \%%\n", result, resultType, operand1, operand2);
         }

         case .ULessThan; {
            assert(operands.count == 4);
            assert(operands[0].type == cast(*Type_Info) SSAId);
            assert(operands[1].type == cast(*Type_Info) SSAId);
            assert(operands[2].type == cast(*Type_Info) SSAId);
            assert(operands[3].type == cast(*Type_Info) SSAId);

            resultType := operands[0].value_pointer.(*SSAId).*;
            result     := operands[1].value_pointer.(*SSAId).*;
            operand1   := operands[2].value_pointer.(*SSAId).*;
            operand2   := operands[3].value_pointer.(*SSAId).*;

            print_to_builder(b, "\%% = OpULessThan \%% \%% \%%\n", result, resultType, operand1, operand2);
         }

         case .FConvert; #through;
         case .SConvert; {
            assert(operands.count == 3);
            assert(operands[0].type == cast(*Type_Info) SSAId);
            assert(operands[1].type == cast(*Type_Info) SSAId);
            assert(operands[2].type == cast(*Type_Info) SSAId);

            resultType := operands[0].value_pointer.(*SSAId).*;
            result     := operands[1].value_pointer.(*SSAId).*;
            operand    := operands[2].value_pointer.(*SSAId).*;

            print_to_builder(b, "\%% = Op% \%% \%%\n", result, op, resultType, operand);
         }

         case .UConvert; {
            assert(operands.count == 3);
            assert(operands[0].type == cast(*Type_Info) SSAId);
            assert(operands[1].type == cast(*Type_Info) SSAId);
            assert(operands[2].type == cast(*Type_Info) SSAId);

            resultType := operands[0].value_pointer.(*SSAId).*;
            result     := operands[1].value_pointer.(*SSAId).*;
            operand    := operands[2].value_pointer.(*SSAId).*;

            print_to_builder(b, "\%% = OpUConvert \%% \%%\n", result, resultType, operand);
         }

         case .DemoteToHelperInvocation; {
            assert(operands.count == 0);
            print_to_builder(b, "OpDemoteToHelperInvocation\n");
         }

         // result type, result, then ids and image operand masks
         case .ImageGather; #through;
         case .ImageSampleDrefImplicitLod; #through;
         case .ImageSampleDrefExplicitLod; #through;
         case .ImageFetch; #through;
         case .ImageRead; #through;
         case .ImageQuerySizeLod; #through;
         case .ImageQueryLevels; #through;
         case .ImageQuerySize; {
            print_to_builder(b, "\%% = Op% \%%", operands[1].value_pointer.(*SSAId).*, op, operands[0].value_pointer.(*SSAId).*);
            for 2..operands.count - 1 {
               if (operands[it].type == cast(*Type_Info) SpvImageOperandsMask) print_to_builder(b, " %", cast(u32) operands[it].value_pointer.(*SpvImageOperandsMask).*);
               else print_to_builder(b, " \%%", operands[it].value_pointer.(*SSAId).*);
            }
            print_to_builder(b, "\n");
         }

         case .ControlBarrier; {
            assert(operands.count == 3);
            for operands  assert(it.type == cast(*Type_Info) SSAId);
            print_to_builder(b, "OpControlBarrier \%% \%% \%%\n", operands[0].value_pointer.(*SSAId).*, operands[1].value_pointer.(*SSAId).*, operands[2].value_pointer.(*SSAId).*);
         }

         // result type, result, then the operands, all ids
         case .AtomicIAdd; #through;
         case .AtomicSMin; #through;
         case .AtomicUMin; #through;
         case .AtomicSMax; #through;
         case .AtomicUMax; #through;
         case .AtomicAnd; #through;
         case .AtomicOr; #through;
         case .AtomicXor; #through;
         case .AtomicExchange; #through;
         case .AtomicCompareExchange; {
            assert(operands.count >= 3);
            for operands  assert(it.type == cast(*Type_Info) SSAId);

            print_to_builder(b, "\%% = Op% \%%", operands[1].value_pointer.(*SSAId).*, op, operands[0].value_pointer.(*SSAId).*);
            for 2..operands.count - 1  print_to_builder(b, " \%%", operands[it].value_pointer.(*SSAId).*);
            print_to_builder(b, "\n");
         }

         // selector, default, then pairs of (literal, label). a literal is u32 or u64 depending on the width of the selector.
         case .Switch; {
            assert(operands.count >= 2 && operands.count % 2 == 0);
            assert(operands[0].type == cast(*Type_Info) SSAId);
            assert(operands[1].type == cast(*Type_Info) SSAId);

            selector     := operands[0].value_pointer.(*SSAId).*;
            defaultLabel := operands[1].value_pointer.(*SSAId).*;

            print_to_builder(b, "OpSwitch \%% \%%", selector, defaultLabel);

            for i: 0..(operands.count - 2) / 2 - 1 {
               literal := operands[2 + i * 2];
               label   := operands[2 + i * 2 + 1];
               assert(literal.type == cast(*Type_Info) u32 || literal.type == cast(*Type_Info) u64);
               assert(label.type == cast(*Type_Info) SSAId);

               print_to_builder(b, " % \%%", literal, label.value_pointer.(*SSAId).*);
            }

            print_to_builder(b, "\n");
         }

         case .Select; {
            assert(operands.count == 5);
            assert(operands[0].type == cast(*Type_Info) SSAId);
            assert(operands[1].type == cast(*Type_Info) SSAId);
            assert(operands[2].type == cast(*Type_Info) SSAId);
            assert(operands[3].type == cast(*Type_Info) SSAId);
            assert(operands[4].type == cast(*Type_Info) SSAId);

            resultType := operands[0].value_pointer.(*SSAId).*;
            result     := operands[1].value_pointer.(*SSAId).*;
            condition  := operands[2].value_pointer.(*SSAId).*;
            object1    := operands[3].value_pointer.(*SSAId).*;
            object2    := operands[4].value_pointer.(*SSAId).*;

            print_to_builder(b, "\%% = OpSelect \%% \%% \%% \%%\n", result, resultType, condition, object1, object2);
         }

         case .LoopMerge; {
            assert(operands.count >= 3);
            assert(operands[0].type == cast(*Type_Info) SSAId);
            assert(operands[1].type == cast(*Type_Info) SSAId);
            assert(operands[2].type == cast(*Type_Info) SpvLoopControlMask);

            mergeBlock     := operands[0].value_pointer.(*SSAId).*;
            continueTarget := operands[1].value_pointer.(*SSAId).*;
            loopControl    := operands[2].value_pointer.(*SpvLoopControlMask).*;

            assert(loopControl == .MaskNone, "try byte builder instead!");
            print_to_builder(b, "OpLoopMerge \%% \%% None", mergeBlock, continueTarget);

            for 3..operands.count - 1 {
               assert(operands[it].type == cast(*Type_Info) int); // all parameters are u32

               parameter := operands[it].value_pointer.(*int).*;
               print_to_builder(b, " %", parameter);
            }

            print_to_builder(b, "\n");
         }

         case .ConvertPtrToU; {
            assert(operands.count == 3);
            assert(operands[0].type == cast(*Type_Info) SSAId);
            assert(operands[1].type == cast(*Type_Info) SSAId);
            assert(operands[2].type == cast(*Type_Info) SSAId);

            resultType := operands[0].value_pointer.(*SSAId).*;
            result     := operands[1].value_pointer.(*SSAId).*;
            pointer    := operands[2].value_pointer.(*SSAId).*;

            print_to_builder(b, "\%% = OpConvertPtrToU \%% \%%\n", result, resultType, pointer);
         }

         case .ConvertUToPtr; {
            assert(operands.count == 3);
            assert(operands[0].type == cast(*Type_Info) SSAId);
            assert(operands[1].type == cast(*Type_Info) SSAId);
            assert(operands[2].type == cast(*Type_Info) SSAId);

            resultType := operands[0].value_pointer.(*SSAId).*;
            result     := operands[1].value_pointer.(*SSAId).*;
            value      := operands[2].value_pointer.(*SSAId).*;

            print_to_builder(b, "\%% = OpConvertUToPtr \%% \%%\n", result, resultType, value);
         }

         case .MatrixTimesMatrix; {
            assert(operands.count == 4);
            assert(operands[0].type == cast(*Type_Info) SSAId);
            assert(operands[1].type == cast(*Type_Info) SSAId);
            assert(operands[2].type == cast(*Type_Info) SSAId);
            assert(operands[3].type == cast(*Type_Info) SSAId);

            resultType := operands[0].value_pointer.(*SSAId).*;
            result     := operands[1].value_pointer.(*SSAId).*;
            left       := operands[2].value_pointer.(*SSAId).*;
            right      := operands[3].value_pointer.(*SSAId).*;

            print_to_builder(b, "\%% = OpMatrixTimesMatrix \%% \%% \%%\n", result, resultType, left, right);
         }

         case .MatrixTimesVector; {
            assert(operands.count == 4);
            assert(operands[0].type == cast(*Type_Info) SSAId);
            assert(operands[1].type == cast(*Type_Info) SSAId);
            assert(operands[2].type == cast(*Type_Info) SSAId);
            assert(operands[3].type == cast(*Type_Info) SSAId);

            resultType := operands[0].value_pointer.(*SSAId).*;
            result     := operands[1].value_pointer.(*SSAId).*;
            matrix     := operands[2].value_pointer.(*SSAId).*;
            vector     := operands[3].value_pointer.(*SSAId).*;

            print_to_builder(b, "\%% = OpMatrixTimesVector \%% \%% \%%\n", result, resultType, matrix, vector);
         }

         case .Dot; {
            assert(operands.count == 4);
            assert(operands[0].type == cast(*Type_Info) SSAId);
            assert(operands[1].type == cast(*Type_Info) SSAId);
            assert(operands[2].type == cast(*Type_Info) SSAId);
            assert(operands[3].type == cast(*Type_Info) SSAId);

            resultType := operands[0].value_pointer.(*SSAId).*;
            result     := operands[1].value_pointer.(*SSAId).*;
            vector1    := operands[2].value_pointer.(*SSAId).*;
            vector2    := operands[3].value_pointer.(*SSAId).*;

            print_to_builder(b, "\%% = OpDot \%% \%% \%%\n", result, resultType, vector1, vector2);
         }

         case .FunctionCall; {
            assert(operands.count >= 3);
            assert(operands[0].type == cast(*Type_Info) SSAId);
            assert(operands[1].type == cast(*Type_Info) SSAId);
            assert(operands[2].type == cast(*Type_Info) SSAId);

            resultType := operands[0].value_pointer.(*SSAId).*;
            result     := operands[1].value_pointer.(*SSAId).*;
            function   := operands[2].value_pointer.(*SSAId).*;

            print_to_builder(b, "\%% = OpFunctionCall \%% \%%", result, resultType, function);

            for 3..operands.count - 1 {
               assert(operands[it].type == cast(*Type_Info) SSAId);

               argument := operands[it].value_pointer.(*SSAId).*;
               print_to_builder(b, " \%%", argument);
            }

            print_to_builder(b, "\n");
         }

         case .FunctionParameter; {
            assert(operands.count == 2);
            assert(operands[0].type == cast(*Type_Info) SSAId);
            assert(operands[1].type == cast(*Type_Info) SSAId);

            resultType := operands[0].value_pointer.(*SSAId).*;
            result     := operands[1].value_pointer.(*SSAId).*;

            print_to_builder(b, "\%% = OpFunctionParameter \%% \%%\n", result, resultType);
         }

         case .FNegate; {
            assert(operands.count == 3);
            assert(operands[0].type == cast(*Type_Info) SSAId);
            assert(operands[1].type == cast(*Type_Info) SSAId);
            assert(operands[2].type == cast(*Type_Info) SSAId);

            resultType := operands[0].value_pointer.(*SSAId).*;
            result     := operands[1].value_pointer.(*SSAId).*;
            operand    := operands[2].value_pointer.(*SSAId).*;

            print_to_builder(b, "\%% = OpFNegate \%% \%%\n", result, resultType, operand);
         }

         case .SNegate; {
            assert(operands.count == 3);
            assert(operands[0].type == cast(*Type_Info) SSAId);
            assert(operands[1].type == cast(*Type_Info) SSAId);
            assert(operands[2].type == cast(*Type_Info) SSAId);

            resultType := operands[0].value_pointer.(*SSAId).*;
            result     := operands[1].value_pointer.(*SSAId).*;
            operand    := operands[2].value_pointer.(*SSAId).*;

            print_to_builder(b, "\%% = OpSNegate \%% \%%\n", result, resultType, operand);
         }

         case .CopyLogical; {
            assert(operands.count == 3);
            assert(operands[0].type == cast(*Type_Info) SSAId);
            assert(operands[1].type == cast(*Type_Info) SSAId);
            assert(operands[2].type == cast(*Type_Info) SSAId);

            resultType := operands[0].value_pointer.(*SSAId).*;
            result     := operands[1].value_pointer.(*SSAId).*;
            operand    := operands[2].value_pointer.(*SSAId).*;

            print_to_builder(b, "\%% = OpCopyLogical \%% \%%\n", result, resultType, operand);
         }

         case .ExtInst; {
            assert(operands.count >= 4);
            assert(operands[0].type == cast(*Type_Info) SSAId);
            assert(operands[1].type == cast(*Type_Info) SSAId);
            assert(operands[2].type == cast(*Type_Info) SSAId);
            assert(operands[3].type == cast(*Type_Info) GLSLstd450); // if you add more extended instruction sets then or (||) them here. right now only GLSLstd450

            resultType  := operands[0].value_pointer.(*SSAId).*;
            result      := operands[1].value_pointer.(*SSAId).*;
            set         := operands[2].value_pointer.(*SSAId).*;
            instruction := operands[3].value_pointer.(*GLSLstd450).*;

            print_to_builder(b, "\%% = OpExtInst \%% \%% %", result, resultType, set, instruction);

            for 4..operands.count - 1 {
               assert(operands[it].type == cast(*Type_Info) SSAId);

               operand := operands[it].value_pointer.(*SSAId).*;
               print_to_builder(b, " \%%", operand);
            }

            print_to_builder(b, "\n");
         }

         case .TraceRayKHR; {
            assert(operands.count == 11);
            assert(operands[0].type == cast(*Type_Info) SSAId);
            assert(operands[1].type == cast(*Type_Info) SSAId);
            assert(operands[2].type == cast(*Type_Info) SSAId);
            assert(operands[3].type == cast(*Type_Info) SSAId);
            assert(operands[4].type == cast(*Type_Info) SSAId);
            assert(operands[5].type == cast(*Type_Info) SSAId);
            assert(operands[6].type == cast(*Type_Info) SSAId);
            assert(operands[7].type == cast(*Type_Info) SSAId);
            assert(operands[8].type == cast(*Type_Info) SSAId);
            assert(operands[9].type == cast(*Type_Info) SSAId);
            assert(operands[10].type == cast(*Type_Info) SSAId);

            tlas           := operands[0].value_pointer.(*SSAId).*;
            rayFlags       := operands[1].value_pointer.(*SSAId).*;
            cullMask       := operands[2].value_pointer.(*SSAId).*;
            sbtOffset      := operands[3].value_pointer.(*SSAId).*;
            sbtStride      := operands[4].value_pointer.(*SSAId).*;
            missIndex      := operands[5].value_pointer.(*SSAId).*;
            rayOrigin      := operands[6].value_pointer.(*SSAId).*;
            rayTMin        := operands[7].value_pointer.(*SSAId).*;
            rayDirection   := operands[8].value_pointer.(*SSAId).*;
            rayTMax        := operands[9].value_pointer.(*SSAId).*;
            payload        := operands[10].value_pointer.(*SSAId).*;

            print_to_builder(b, "OpTraceRayKHR \%% \%% \%% \%% \%% \%% \%% \%% \%% \%% \%%\n", tlas, rayFlags, cullMask, sbtOffset, sbtStride, missIndex, rayOrigin, rayTMin, rayDirection, rayTMax, payload);
         }

         case .SDiv; #through;
         case .UDiv; #through;
         case .SRem; #through;
         case .UMod; #through;
         case .FRem; #through;
         case .BitwiseAnd; #through;
         case .BitwiseOr; #through;
         case .BitwiseXor; #through;
         case .ShiftLeftLogical; #through;
         case .ShiftRightLogical; #through;
         case .ShiftRightArithmetic; #through;
         case .SGreaterThan; #through;
         case .SLessThanEqual; #through;
         case .SGreaterThanEqual; #through;
         case .UGreaterThan; #through;
         case .ULessThanEqual; #through;
         case .UGreaterThanEqual; #through;
         case .IEqual; #through;
         case .INotEqual; #through;
         case .FOrdLessThan; #through;
         case .FOrdGreaterThan; #through;
         case .FOrdLessThanEqual; #through;
         case .FOrdGreaterThanEqual; #through;
         case .FOrdEqual; #through;
         case .FUnordNotEqual; #through;
         case .LogicalEqual; #through;
         case .LogicalNotEqual; #through;
         case .LogicalAnd; #through;
         case .VectorTimesScalar; #through;
         case .LogicalOr; {
            assert(operands.count == 4);
            assert(operands[0].type == cast(*Type_Info) SSAId);
            assert(operands[1].type == cast(*Type_Info) SSAId);
            assert(operands[2].type == cast(*Type_Info) SSAId);
            assert(operands[3].type == cast(*Type_Info) SSAId);

            resultType := operands[0].value_pointer.(*SSAId).*;
            result     := operands[1].value_pointer.(*SSAId).*;
            operand1   := operands[2].value_pointer.(*SSAId).*;
            operand2   := operands[3].value_pointer.(*SSAId).*;

            print_to_builder(b, "\%% = Op% \%% \%% \%%\n", result, op, resultType, operand1, operand2);
         }

         case .LogicalNot; #through;
         case .Not; #through;
         case .ConvertFToS; #through;
         case .ConvertFToU; #through;
         case .ConvertSToF; {
            assert(operands.count == 3);
            assert(operands[0].type == cast(*Type_Info) SSAId);
            assert(operands[1].type == cast(*Type_Info) SSAId);
            assert(operands[2].type == cast(*Type_Info) SSAId);

            resultType := operands[0].value_pointer.(*SSAId).*;
            result     := operands[1].value_pointer.(*SSAId).*;
            operand    := operands[2].value_pointer.(*SSAId).*;

            print_to_builder(b, "\%% = Op% \%% \%%\n", result, op, resultType, operand);
         }

         case; assert(false, "not yet implemented! op: %", op);
      }
   } else #if SPIRV_BUILDER_TYPE == .Byte {
      if op == {
         case .Capability; {
            assert(operands.count == 1);
            assert(operands[0].type == cast(*Type_Info) SpvCapability);

            capability := operands[0].value_pointer.(*SpvCapability).*;
            array_add(b, OpWordCount(op, operands.count), cast(u32) capability);
         }

         case .Extension; {
            assert(operands.count == 1);
            assert(operands[0].type == cast(*Type_Info) string);

            extension := operands[0].value_pointer.(*string).*;

            buffer := ToSpirvString(extension);
            operandCount := buffer.count;

            array_add(b, OpWordCount(op, operandCount));
            array_add(b, .. buffer);
         }

         case .ExtInstImport; {
            assert(operands.count == 2);
            assert(operands[0].type == cast(*Type_Info) SSAId);
            assert(operands[1].type == cast(*Type_Info) string);

            result := operands[0].value_pointer.(*SSAId).*;
            import := operands[1].value_pointer.(*string).*;

            buffer := ToSpirvString(import);

            operandCount := operands.count - 1 + buffer.count; // -1 for double coounting the first word of "import"

            array_add(b, OpWordCount(op, operandCount), cast(u32) result);
            array_add(b, .. buffer);
         }

         case .MemoryModel; {
            assert(operands.count == 2);
            assert(operands[0].type == cast(*Type_Info) SpvAddressingModel);
            assert(operands[1].type == cast(*Type_Info) SpvMemoryModel);

            addressingModel := operands[0].value_pointer.(*SpvAddressingModel).*;
            memoryModel     := operands[1].value_pointer.(*SpvMemoryModel).*;

            array_add(b, OpWordCount(op, operands.count), cast(u32) addressingModel, cast(u32) memoryModel);
         }

         case .EntryPoint; {
            assert(operands.count >= 3);
            assert(operands[0].type == cast(*Type_Info) SpvExecutionModel);
            assert(operands[1].type == cast(*Type_Info) SSAId);
            assert(operands[2].type == cast(*Type_Info) string);

            executionModel := operands[0].value_pointer.(*SpvExecutionModel).*;
            entryPoint     := operands[1].value_pointer.(*SSAId).*;
            name           := operands[2].value_pointer.(*string).*;

            buffer := ToSpirvString(name);

            operandCount := operands.count - 1 + buffer.count; // -1 for double coounting the first word of "name"

            array_add(b, OpWordCount(op, operandCount), cast(u32) executionModel, cast(u32) entryPoint);
            array_add(b, .. buffer);

            for 3..operands.count - 1 {
               assert(operands[it].type == cast(*Type_Info) SSAId);

               operand := operands[it].value_pointer.(*SSAId).*;
               array_add(b, xx operand);
            }
         }

         case .ExecutionModeId; {
            assert(operands.count >= 2);
            assert(operands[0].type == cast(*Type_Info) SSAId);
            assert(operands[1].type == cast(*Type_Info) SpvExecutionMode);

            entryPoint    := operands[0].value_pointer.(*SSAId).*;
            executionMode := operands[1].value_pointer.(*SpvExecutionMode).*;

            array_add(b, OpWordCount(op, operands.count), cast(u32) entryPoint, cast(u32) executionMode);

            for 2..operands.count - 1 {
               assert(operands[it].type == cast(*Type_Info) SSAId);

               operand := operands[it].value_pointer.(*SSAId).*;
               array_add(b, xx operand);
            }
         }

         case .ExecutionMode; {
            assert(operands.count >= 2);
            assert(operands[0].type == cast(*Type_Info) SSAId);
            assert(operands[1].type == cast(*Type_Info) SpvExecutionMode);

            entryPoint    := operands[0].value_pointer.(*SSAId).*;
            executionMode := operands[1].value_pointer.(*SpvExecutionMode).*;

            array_add(b, OpWordCount(op, operands.count), cast(u32) entryPoint, cast(u32) executionMode);

            for 2..operands.count - 1 {
               assert(operands[it].type == cast(*Type_Info) int);

               operand := operands[it].value_pointer.(*int).*;
               array_add(b, xx operand);
            }
         }

         case .Decorate; {
            assert(operands.count >= 2);
            assert(operands[0].type == cast(*Type_Info) SSAId);
            assert(operands[1].type == cast(*Type_Info) SpvDecoration);

            target     := operands[0].value_pointer.(*SSAId).*;
            decoration := operands[1].value_pointer.(*SpvDecoration).*;

            array_add(b, OpWordCount(op, operands.count), cast(u32) target, cast(u32) decoration);

            for 2..operands.count - 1 {
               assert(operands[it].type == cast(*Type_Info) int || operands[it].type == cast(*Type_Info) SpvBuiltIn);

               if (operands[it].type == cast(*Type_Info) int) {
                  operand := operands[it].value_pointer.(*int).*;
                  array_add(b, xx operand);
               } else if (operands[it].type == cast(*Type_Info) SpvBuiltIn) {
                  operand := operands[it].value_pointer.(*SpvBuiltIn).*;
                  array_add(b, xx operand);
               }
            }
         }

         case .MemberDecorate; {
            assert(operands.count >= 3);
            assert(operands[0].type == cast(*Type_Info) SSAId);
            assert(operands[1].type == cast(*Type_Info) int);
            assert(operands[2].type == cast(*Type_Info) SpvDecoration);

            structType := operands[0].value_pointer.(*SSAId).*;
            member     := operands[1].value_pointer.(*int).*;
            decoration := operands[2].value_pointer.(*SpvDecoration).*;

            array_add(b, OpWordCount(op, operands.count), cast(u32) structType, cast(u32) member, cast(u32) decoration);

            for 3..operands.count - 1 {
               assert(operands[it].type == cast(*Type_Info) SpvBuiltIn || operands[it].type == cast(*Type_Info) int);

               if (operands[it].type == cast(*Type_Info) SpvBuiltIn) {
                  builtin := operands[it].value_pointer.(*SpvBuiltIn).*;
                  array_add(b, xx builtin);
               } else if (operands[it].type == cast(*Type_Info) int) {
                  operand := operands[it].value_pointer.(*int).*;
                  array_add(b, xx operand);
               }
            }
         }

         case .DecorateId; {
            assert(operands.count >= 3);
            assert(operands[0].type == cast(*Type_Info) SSAId);
            assert(operands[1].type == cast(*Type_Info) SpvDecoration);

            target     := operands[0].value_pointer.(*SSAId).*;
            decoration := operands[1].value_pointer.(*SpvDecoration).*;

            array_add(b, OpWordCount(op, operands.count), cast(u32) target, cast(u32) decoration);

            for 2..operands.count - 1 {
               assert(operands[it].type == cast(*Type_Info) SSAId);

               ssaId := operands[it].value_pointer.(*SSAId).*;
               array_add(b, xx ssaId);
            }
         }

         case .Constant; {
            assert(operands.count == 3);
            assert(operands[0].type == cast(*Type_Info) SSAId);
            assert(operands[1].type == cast(*Type_Info) SSAId);
            assert(operands[2].type.type == .INTEGER || operands[2].type.type == .FLOAT);
            assert(operands[2].type.runtime_size == 4 || operands[2].type.runtime_size == 8, "not yet implemented! size: %", operands[2].type.runtime_size);

            resultType := operands[0].value_pointer.(*SSAId).*;
            result     := operands[1].value_pointer.(*SSAId).*;
            value      := operands[2];

            operandCount := operands.count + ifx value.type.runtime_size > 4 then 1 else 0;
            array_add(b, OpWordCount(op, operandCount), cast(u32) resultType, cast(u32) result);

            // for 16 or 8 bits i need to sign extend or just extend to 32 bits
            if (value.type.runtime_size == 4) {
               array_add(b, value.value_pointer.(*u32).*);
            } else if (value.type.runtime_size == 8) {
               array_add(b, xx (value.value_pointer.(*u64).* & 0xFFFFFFFF));
               array_add(b, xx (value.value_pointer.(*u64).* >> 32));
            } else {
               assert(false);
            }
         }

         case .TypeInt; {
            assert(operands.count == 3);
            assert(operands[0].type == cast(*Type_Info) SSAId);
            assert(operands[1].type == cast(*Type_Info) int);
            assert(operands[2].type == cast(*Type_Info) int);

            result     := operands[0].value_pointer.(*SSAId).*;
            width      := operands[1].value_pointer.(*int).*;
            signedness := operands[2].value_pointer.(*int).*;

            array_add(b, OpWordCount(op, operands.count), cast(u32) result, cast(u32) width, cast(u32) signedness);
         }

         case .TypeFloat; {
            assert(operands.count == 2 || operands.count == 3);
            assert(operands[0].type == cast(*Type_Info) SSAId);
            assert(operands[1].type == cast(*Type_Info) int);

            result     := operands[0].value_pointer.(*SSAId).*;
            width      := operands[1].value_pointer.(*int).*;

            array_add(b, OpWordCount(op, operands.count), cast(u32) result, cast(u32) width);

            if (operands.count == 3) {
               assert(operands[2].type == cast(*Type_Info) SpvFPEncoding);

               encoding := operands[1].value_pointer.(*SpvFPEncoding).*;
               array_add(b, xx encoding);
            }
         }

         case .TypeVector; {
            assert(operands.count == 3);
            assert(operands[0].type == cast(*Type_Info) SSAId);
            assert(operands[1].type == cast(*Type_Info) SSAId);
            assert(operands[2].type == cast(*Type_Info) int);

            result         := operands[0].value_pointer.(*SSAId).*;
            componentType  := operands[1].value_pointer.(*SSAId).*;
            componentCount := operands[2].value_pointer.(*int).*;

            array_add(b, OpWordCount(op, operands.count), cast(u32) result, cast(u32) componentType, cast(u32) componentCount);
         }

         case .TypeMatrix; {
            assert(operands.count == 3);
            assert(operands[0].type == cast(*Type_Info) SSAId);
            assert(operands[1].type == cast(*Type_Info) SSAId);
            assert(operands[2].type == cast(*Type_Info) int);

            result      := operands[0].value_pointer.(*SSAId).*;
            columnType  := operands[1].value_pointer.(*SSAId).*;
            columnCount := operands[2].value_pointer.(*int).*;

            array_add(b, OpWordCount(op, operands.count), cast(u32) result, cast(u32) columnType, cast(u32) columnCount);
         }

         case .TypeBool; {
            assert(operands.count == 1);
            assert(operands[0].type == cast(*Type_Info) SSAId);

            result := operands[0].value_pointer.(*SSAId).*;

            array_add(b, OpWordCount(op, operands.count), cast(u32) result);
         }

         case .TypeStruct; {
            // spirv specs: "It is valid for the structure to have no members"
            assert(operands.count >= 1);
            assert(operands[0].type == cast(*Type_Info) SSAId);

            result := operands[0].value_pointer.(*SSAId).*;

            array_add(b, OpWordCount(op, operands.count), cast(u32) result);

            for 1..operands.count - 1 {
               assert(operands[it].type == cast(*Type_Info) SSAId);

               memberType := operands[it].value_pointer.(*SSAId).*;
               array_add(b, xx memberType);
            }
         }

         case .TypeSampledImage; {
            assert(operands.count == 2);
            assert(operands[0].type == cast(*Type_Info) SSAId);
            assert(operands[1].type == cast(*Type_Info) SSAId);

            result    := operands[0].value_pointer.(*SSAId).*;
            imageType := operands[1].value_pointer.(*SSAId).*;

            array_add(b, OpWordCount(op, operands.count), cast(u32) result, cast(u32) imageType);
         }

         case .TypeSampler; {
            assert(operands.count == 1);
            assert(operands[0].type == cast(*Type_Info) SSAId);

            result := operands[0].value_pointer.(*SSAId).*;

            array_add(b, OpWordCount(op, operands.count), cast(u32) result);
         }

         case .TypeImage; {
            assert(operands.count == 8 || operands.count == 9);
            assert(operands[0].type == cast(*Type_Info) SSAId);
            assert(operands[1].type == cast(*Type_Info) SSAId);
            assert(operands[2].type == cast(*Type_Info) SpvDim);
            assert(operands[3].type == cast(*Type_Info) int);
            assert(operands[4].type == cast(*Type_Info) int);
            assert(operands[5].type == cast(*Type_Info) int);
            assert(operands[6].type == cast(*Type_Info) int);
            assert(operands[7].type == cast(*Type_Info) SpvImageFormat);

            result      := operands[0].value_pointer.(*SSAId).*;
            sampledType := operands[1].value_pointer.(*SSAId).*;
            dim         := operands[2].value_pointer.(*SpvDim).*;
            depth       := operands[3].value_pointer.(*int).*;
            arrayed     := operands[4].value_pointer.(*int).*;
            ms          := operands[5].value_pointer.(*int).*;
            sampled     := operands[6].value_pointer.(*int).*;
            imageFormat := operands[7].value_pointer.(*SpvImageFormat).*;

            array_add(b, OpWordCount(op, operands.count), cast(u32) result, cast(u32) sampledType, cast(u32) dim, cast(u32) depth, cast(u32) arrayed, cast(u32) ms, cast(u32) sampled, cast(u32) imageFormat);

            if (operands.count == 9) {
               assert(operands[8].type == cast(*Type_Info) SpvAccessQualifier);

               accessQualifier := operands[8].value_pointer.(*SpvAccessQualifier).*;
               array_add(b, xx accessQualifier);
            }
         }

         case .TypeRuntimeArray; {
            assert(operands.count == 2);
            assert(operands[0].type == cast(*Type_Info) SSAId);
            assert(operands[1].type == cast(*Type_Info) SSAId);

            result      := operands[0].value_pointer.(*SSAId).*;
            elementType := operands[1].value_pointer.(*SSAId).*;

            array_add(b, OpWordCount(op, operands.count), cast(u32) result, cast(u32) elementType);
         }

         case .TypeUntypedPointerKHR; {
            assert(operands.count == 2);
            assert(operands[0].type == cast(*Type_Info) SSAId);
            assert(operands[1].type == cast(*Type_Info) SpvStorageClass);

            result       := operands[0].value_pointer.(*SSAId).*;
            storageClass := operands[1].value_pointer.(*SpvStorageClass).*;

            array_add(b, OpWordCount(op, operands.count), cast(u32) result, cast(u32) storageClass);
         }

         case .TypePointer; {
            assert(operands.count == 3);
            assert(operands[0].type == cast(*Type_Info) SSAId);
            assert(operands[1].type == cast(*Type_Info) SpvStorageClass);
            assert(operands[2].type == cast(*Type_Info) SSAId);

            result       := operands[0].value_pointer.(*SSAId).*;
            storageClass := operands[1].value_pointer.(*SpvStorageClass).*;
            type         := operands[2].value_pointer.(*SSAId).*;

            array_add(b, OpWordCount(op, operands.count), cast(u32) result, cast(u32) storageClass, cast(u32) type);
         }

         case .TypeForwardPointer; {
            assert(operands.count == 2);
            assert(operands[0].type == cast(*Type_Info) SSAId);
            assert(operands[1].type == cast(*Type_Info) SpvStorageClass);

            pointerType  := operands[0].value_pointer.(*SSAId).*;
            storageClass := operands[1].value_pointer.(*SpvStorageClass).*;

            array_add(b, OpWordCount(op, operands.count), cast(u32) pointerType, cast(u32) storageClass);
         }

         case .TypeFunction; {
            assert(operands.count >= 2);
            assert(operands[0].type == cast(*Type_Info) SSAId);
            assert(operands[1].type == cast(*Type_Info) SSAId);

            result     := operands[0].value_pointer.(*SSAId).*;
            returnType := operands[1].value_pointer.(*SSAId).*;

            array_add(b, OpWordCount(op, operands.count), cast(u32) result, cast(u32) returnType);

            for 2..operands.count - 1 {
               assert(operands[it].type == cast(*Type_Info) SSAId);

               parameterType := operands[it].value_pointer.(*SSAId).*;
               array_add(b, xx parameterType);
            }
         }

         case .TypeArray; {
            assert(operands.count == 3);
            assert(operands[0].type == cast(*Type_Info) SSAId);
            assert(operands[1].type == cast(*Type_Info) SSAId);
            assert(operands[2].type == cast(*Type_Info) SSAId);

            result      := operands[0].value_pointer.(*SSAId).*;
            elementType := operands[1].value_pointer.(*SSAId).*;
            length      := operands[2].value_pointer.(*SSAId).*;

            array_add(b, OpWordCount(op, operands.count), cast(u32) result, cast(u32) elementType, cast(u32) length);
         }

         case .TypeVoid; {
            assert(operands.count == 1);
            assert(operands[0].type == cast(*Type_Info) SSAId);

            result := operands[0].value_pointer.(*SSAId).*;

            array_add(b, OpWordCount(op, operands.count), cast(u32) result);
         }

         case .Variable; {
            assert(operands.count == 3 || operands.count == 4);
            assert(operands[0].type == cast(*Type_Info) SSAId);
            assert(operands[1].type == cast(*Type_Info) SSAId);
            assert(operands[2].type == cast(*Type_Info) SpvStorageClass);

            resultType   := operands[0].value_pointer.(*SSAId).*;
            result       := operands[1].value_pointer.(*SSAId).*;
            storageClass := operands[2].value_pointer.(*SpvStorageClass).*;

            array_add(b, OpWordCount(op, operands.count), cast(u32) resultType, cast(u32) result, cast(u32) storageClass);

            if (operands.count == 4) {
               assert(operands[3].type == cast(*Type_Info) SSAId);

               initializer := operands[3].value_pointer.(*SSAId).*;
               array_add(b, xx initializer);
            }
         }

         case .UntypedVariableKHR; {
            assert(operands.count >= 3 || operands.count <= 5);
            assert(operands[0].type == cast(*Type_Info) SSAId);
            assert(operands[1].type == cast(*Type_Info) SSAId);
            assert(operands[2].type == cast(*Type_Info) SpvStorageClass);

            resultType   := operands[0].value_pointer.(*SSAId).*;
            result       := operands[1].value_pointer.(*SSAId).*;
            storageClass := operands[2].value_pointer.(*SpvStorageClass).*;

            array_add(b, OpWordCount(op, operands.count), cast(u32) resultType, cast(u32) result, cast(u32) storageClass);

            if (operands.count > 3) {
               assert(operands[3].type == cast(*Type_Info) SSAId);

               dataType := operands[3].value_pointer.(*SSAId).*;
               array_add(b, xx dataType);

               if (operands.count > 4) {
                  assert(operands[4].type == cast(*Type_Info) SSAId);

                  initializer := operands[4].value_pointer.(*SSAId).*;
                  array_add(b, xx initializer);
               }
            }
         }

         case .ConstantComposite; {
            assert(operands.count >= 3, "count: %", operands.count);
            assert(operands[0].type == cast(*Type_Info) SSAId);
            assert(operands[1].type == cast(*Type_Info) SSAId);

            resultType := operands[0].value_pointer.(*SSAId).*;
            result     := operands[1].value_pointer.(*SSAId).*;

            array_add(b, OpWordCount(op, operands.count), cast(u32) resultType, cast(u32) result);

            for 2..operands.count - 1 {
               assert(operands[it].type == cast(*Type_Info) SSAId);

               constituent := operands[it].value_pointer.(*SSAId).*;
               array_add(b, xx constituent);
            }
         }

         case .ConstantTrue; {
            assert(operands.count == 2);
            assert(operands[0].type == cast(*Type_Info) SSAId);
            assert(operands[1].type == cast(*Type_Info) SSAId);

            resultType := operands[0].value_pointer.(*SSAId).*;
            result     := operands[1].value_pointer.(*SSAId).*;

            array_add(b, OpWordCount(op, operands.count), cast(u32) resultType, cast(u32) result);
         }

         case .ConstantFalse; #through;
         case .ConstantNull; {
            assert(operands.count == 2);
            assert(operands[0].type == cast(*Type_Info) SSAId);
            assert(operands[1].type == cast(*Type_Info) SSAId);

            resultType := operands[0].value_pointer.(*SSAId).*;
            result     := operands[1].value_pointer.(*SSAId).*;

            array_add(b, OpWordCount(op, operands.count), cast(u32) resultType, cast(u32) result);
         }

         case .ConstantSizeOfEXT; {
            assert(operands.count == 3);
            assert(operands[0].type == cast(*Type_Info) SSAId);
            assert(operands[1].type == cast(*Type_Info) SSAId);
            assert(operands[2].type == cast(*Type_Info) SSAId);

            resultType := operands[0].value_pointer.(*SSAId).*;
            result     := operands[1].value_pointer.(*SSAId).*;
            type       := operands[2].value_pointer.(*SSAId).*;

            array_add(b, OpWordCount(op, operands.count), cast(u32) resultType, cast(u32) result, cast(u32) type);
         }

         case .Fwidth; #through;
         case .Transpose; #through;
         case .DPdy; #through;
         case .DPdx; {
            assert(operands.count == 3);
            assert(operands[0].type == cast(*Type_Info) SSAId);
            assert(operands[1].type == cast(*Type_Info) SSAId);
            assert(operands[2].type == cast(*Type_Info) SSAId);

            resultType := operands[0].value_pointer.(*SSAId).*;
            result     := operands[1].value_pointer.(*SSAId).*;
            p          := operands[2].value_pointer.(*SSAId).*;

            array_add(b, OpWordCount(op, operands.count), cast(u32) resultType, cast(u32) result, cast(u32) p);
         }

         case .Function; {
            assert(operands.count == 4);
            assert(operands[0].type == cast(*Type_Info) SSAId);
            assert(operands[1].type == cast(*Type_Info) SSAId);
            assert(operands[2].type == cast(*Type_Info) SpvFunctionControlMask);
            assert(operands[3].type == cast(*Type_Info) SSAId);

            resultType      := operands[0].value_pointer.(*SSAId).*;
            result          := operands[1].value_pointer.(*SSAId).*;
            functionControl := operands[2].value_pointer.(*SpvFunctionControlMask).*;
            functionType    := operands[3].value_pointer.(*SSAId).*;

            array_add(b, OpWordCount(op, operands.count), cast(u32) resultType, cast(u32) result, cast(u32) functionControl, cast(u32) functionType);
         }

         case .Label; {
            assert(operands.count == 1);
            assert(operands[0].type == cast(*Type_Info) SSAId);

            result := operands[0].value_pointer.(*SSAId).*;

            array_add(b, OpWordCount(op, operands.count), cast(u32) result);
         }

         case .Return; {
            assert(operands.count == 0);
            array_add(b, OpWordCount(op, operands.count));
         }

         case .FunctionEnd; {
            assert(operands.count == 0);
            array_add(b, OpWordCount(op, operands.count));
         }

         case .CompositeConstruct; {
            assert(operands.count >= 3);
            assert(operands[0].type == cast(*Type_Info) SSAId);
            assert(operands[1].type == cast(*Type_Info) SSAId);

            resultType := operands[0].value_pointer.(*SSAId).*;
            result     := operands[1].value_pointer.(*SSAId).*;

            array_add(b, OpWordCount(op, operands.count), cast(u32) resultType, cast(u32) result);

            for 2..operands.count - 1 {
               assert(operands[it].type == cast(*Type_Info) SSAId);

               constituent := operands[it].value_pointer.(*SSAId).*;
               array_add(b, xx constituent);
            }
         }

         case .Store; {
            assert(operands.count >= 2);
            assert(operands[0].type == cast(*Type_Info) SSAId);
            assert(operands[1].type == cast(*Type_Info) SSAId);

            pointer := operands[0].value_pointer.(*SSAId).*;
            object  := operands[1].value_pointer.(*SSAId).*;

            array_add(b, OpWordCount(op, operands.count), cast(u32) pointer, cast(u32) object);

            if (operands.count > 2) {
               assert(operands[2].type == cast(*Type_Info) SpvMemoryAccessMask);

               mask := operands[2].value_pointer.(*SpvMemoryAccessMask).*;
               array_add(b, xx mask);

               // only Aligned has extra arguments and it should be u32
               if (operands.count > 3) {
                  assert(operands.count == 4); // no more operands
                  assert(mask & .AlignedMask != 0);
                  assert(operands[3].type == cast(*Type_Info) int);

                  operand := operands[3].value_pointer.(*int).*;
                  array_add(b, xx operand);
               }
            }
         }

         case .SetMeshOutputsEXT; {
            assert(operands.count == 2);
            assert(operands[0].type == cast(*Type_Info) SSAId);
            assert(operands[1].type == cast(*Type_Info) SSAId);

            vertexCount    := operands[0].value_pointer.(*SSAId).*;
            primitiveCount := operands[1].value_pointer.(*SSAId).*;

            array_add(b, OpWordCount(op, operands.count), cast(u32) vertexCount, cast(u32) primitiveCount);
         }

         case .ReturnValue; {
            assert(operands.count == 1);
            assert(operands[0].type == cast(*Type_Info) SSAId);

            value := operands[0].value_pointer.(*SSAId).*;

            array_add(b, OpWordCount(op, operands.count), cast(u32) value);
         }

         case .SampledImage; {
            assert(operands.count == 4);
            assert(operands[0].type == cast(*Type_Info) SSAId);
            assert(operands[1].type == cast(*Type_Info) SSAId);
            assert(operands[2].type == cast(*Type_Info) SSAId);
            assert(operands[3].type == cast(*Type_Info) SSAId);

            resultType := operands[0].value_pointer.(*SSAId).*;
            result     := operands[1].value_pointer.(*SSAId).*;
            image      := operands[2].value_pointer.(*SSAId).*;
            sampler    := operands[3].value_pointer.(*SSAId).*;

            array_add(b, OpWordCount(op, operands.count), cast(u32) resultType, cast(u32) result, cast(u32) image, cast(u32) sampler);
         }

         case .ImageSampleImplicitLod; {
            assert(operands.count >= 4);
            assert(operands[0].type == cast(*Type_Info) SSAId);
            assert(operands[1].type == cast(*Type_Info) SSAId);
            assert(operands[2].type == cast(*Type_Info) SSAId);
            assert(operands[3].type == cast(*Type_Info) SSAId);

            resultType   := operands[0].value_pointer.(*SSAId).*;
            result       := operands[1].value_pointer.(*SSAId).*;
            sampledImage := operands[2].value_pointer.(*SSAId).*;
            coordinate   := operands[3].value_pointer.(*SSAId).*;

            array_add(b, OpWordCount(op, operands.count), cast(u32) resultType, cast(u32) result, cast(u32) sampledImage, cast(u32) coordinate);

            if (operands.count > 4) {
               assert(operands[4].type == cast(*Type_Info) SpvImageOperandsMask);

               mask := operands[4].value_pointer.(*SpvImageOperandsMask).*;
               array_add(b, xx mask);

               // specs mandates that parameters to memory operands are all 32 bit whether it is float or integer
               // it has to be 32 bit.
               for 5..operands.count - 1 {
                  // an id (Bias)
                  if (operands[it].type == cast(*Type_Info) SSAId) {
                     array_add(b, cast(u32) operands[it].value_pointer.(*SSAId).*);
                     continue;
                  }

                  assert(operands[it].type.type == .INTEGER || operands[it].type.type == .FLOAT);

                  assert(operands[it].type.runtime_size == 4 || operands[it].type.runtime_size == 8, "not yet implemented! you need to do signed/unsigned extend. and if you were to do that then also handle endianess so it also works with big endian.");

                  // if your machine is big endian this wont work.
                  operand := operands[it].value_pointer.(*u32).*;
                  array_add(b, operand);
               }
            }
         }

         case .ImageSampleExplicitLod; {
            assert(operands.count >= 6);
            assert(operands[0].type == cast(*Type_Info) SSAId);
            assert(operands[1].type == cast(*Type_Info) SSAId);
            assert(operands[2].type == cast(*Type_Info) SSAId);
            assert(operands[3].type == cast(*Type_Info) SSAId);
            assert(operands[4].type == cast(*Type_Info) SpvImageOperandsMask);
            assert(operands[5].type == cast(*Type_Info) SSAId);

            resultType   := operands[0].value_pointer.(*SSAId).*;
            result       := operands[1].value_pointer.(*SSAId).*;
            sampledImage := operands[2].value_pointer.(*SSAId).*;
            coordinate   := operands[3].value_pointer.(*SSAId).*;
            mask         := operands[4].value_pointer.(*SpvImageOperandsMask).*;
            imageOperand := operands[5].value_pointer.(*SSAId).*;

            array_add(b, OpWordCount(op, operands.count), cast(u32) resultType, cast(u32) result, cast(u32) sampledImage, cast(u32) coordinate, cast(u32) mask, cast(u32) imageOperand);

            for 6..operands.count - 1 {
               assert(operands[it].type == cast(*Type_Info) SSAId);

               operand := operands[it].value_pointer.(*SSAId).*;
               array_add(b, xx operand);
            }
         }

         case .SelectionMerge; {
            assert(operands.count == 2);
            assert(operands[0].type == cast(*Type_Info) SSAId);
            assert(operands[1].type == cast(*Type_Info) SpvSelectionControlMask);

            mergeBlock       := operands[0].value_pointer.(*SSAId).*;
            selectionControl := operands[1].value_pointer.(*SpvSelectionControlMask).*;

            array_add(b, OpWordCount(op, operands.count), cast(u32) mergeBlock, cast(u32) selectionControl);
         }

         case .BranchConditional; {
            assert(operands.count == 3 || operands.count == 5);
            assert(operands[0].type == cast(*Type_Info) SSAId);
            assert(operands[1].type == cast(*Type_Info) SSAId);
            assert(operands[2].type == cast(*Type_Info) SSAId);

            condition  := operands[0].value_pointer.(*SSAId).*;
            trueLabel  := operands[1].value_pointer.(*SSAId).*;
            falseLabel := operands[2].value_pointer.(*SSAId).*;

            array_add(b, OpWordCount(op, operands.count), cast(u32) condition, cast(u32) trueLabel, cast(u32) falseLabel);

            if (operands.count == 5) {
               assert(operands[3].type == cast(*Type_Info) int);
               assert(operands[4].type == cast(*Type_Info) int);

               trueWeight  := operands[3].value_pointer.(*int).*;
               falseWeight := operands[4].value_pointer.(*int).*;

               array_add(b, cast(u32) trueWeight, cast(u32) falseWeight);
            }
         }

         case .Branch; {
            assert(operands.count == 1);
            assert(operands[0].type == cast(*Type_Info) SSAId);

            targetLabel := operands[0].value_pointer.(*SSAId).*;

            array_add(b, OpWordCount(op, operands.count), cast(u32) targetLabel);
         }

         case .Bitcast; {
            assert(operands.count == 3);
            assert(operands[0].type == cast(*Type_Info) SSAId);
            assert(operands[1].type == cast(*Type_Info) SSAId);
            assert(operands[2].type == cast(*Type_Info) SSAId);

            resultType := operands[0].value_pointer.(*SSAId).*;
            result     := operands[1].value_pointer.(*SSAId).*;
            operand    := operands[2].value_pointer.(*SSAId).*;

            array_add(b, OpWordCount(op, operands.count), cast(u32) resultType, cast(u32) result, cast(u32) operand);
         }

         case .ConvertUToF; {
            assert(operands.count == 3);
            assert(operands[0].type == cast(*Type_Info) SSAId);
            assert(operands[1].type == cast(*Type_Info) SSAId);
            assert(operands[2].type == cast(*Type_Info) SSAId);

            resultType := operands[0].value_pointer.(*SSAId).*;
            result     := operands[1].value_pointer.(*SSAId).*;
            operand    := operands[2].value_pointer.(*SSAId).*;

            array_add(b, OpWordCount(op, operands.count), cast(u32) resultType, cast(u32) result, cast(u32) operand);
         }

         case .Load; {
            assert(operands.count >= 3);
            assert(operands[0].type == cast(*Type_Info) SSAId);
            assert(operands[1].type == cast(*Type_Info) SSAId);
            assert(operands[2].type == cast(*Type_Info) SSAId);

            resultType := operands[0].value_pointer.(*SSAId).*;
            result     := operands[1].value_pointer.(*SSAId).*;
            pointer    := operands[2].value_pointer.(*SSAId).*;

            array_add(b, OpWordCount(op, operands.count), cast(u32) resultType, cast(u32) result, cast(u32) pointer);

            if (operands.count > 3) {
               assert(operands[3].type == cast(*Type_Info) SpvMemoryAccessMask);

               mask := operands[3].value_pointer.(*SpvMemoryAccessMask).*;
               array_add(b, xx mask);

               // only Aligned has extra arguments and it should be u32
               if (operands.count > 4) {
                  assert(operands.count == 5); // no more operands
                  assert(mask & .AlignedMask != 0);
                  assert(operands[4].type == cast(*Type_Info) int);

                  operand := operands[4].value_pointer.(*int).*;
                  array_add(b, xx operand);
               }
            }
         }

         case .UntypedAccessChainKHR; {
            assert(operands.count >= 5);
            assert(operands[0].type == cast(*Type_Info) SSAId);
            assert(operands[1].type == cast(*Type_Info) SSAId);
            assert(operands[2].type == cast(*Type_Info) SSAId);
            assert(operands[3].type == cast(*Type_Info) SSAId);

            resultType := operands[0].value_pointer.(*SSAId).*;
            result     := operands[1].value_pointer.(*SSAId).*;
            baseType   := operands[2].value_pointer.(*SSAId).*;
            base       := operands[3].value_pointer.(*SSAId).*;

            array_add(b, OpWordCount(op, operands.count), cast(u32) resultType, cast(u32) result, cast(u32) baseType, cast(u32) base);

            for 4..operands.count - 1 {
               assert(operands[it].type == cast(*Type_Info) SSAId);

               index := operands[it].value_pointer.(*SSAId).*;
               array_add(b, xx index);
            }
         }

         case .AccessChain; {
            assert(operands.count >= 4, "count: %, %", operands.count, operands);
            assert(operands[0].type == cast(*Type_Info) SSAId);
            assert(operands[1].type == cast(*Type_Info) SSAId);
            assert(operands[2].type == cast(*Type_Info) SSAId);

            resultType := operands[0].value_pointer.(*SSAId).*;
            result     := operands[1].value_pointer.(*SSAId).*;
            base       := operands[2].value_pointer.(*SSAId).*;

            array_add(b, OpWordCount(op, operands.count), cast(u32) resultType, cast(u32) result, cast(u32) base);

            for 3..operands.count - 1 {
               assert(operands[it].type == cast(*Type_Info) SSAId);

               index := operands[it].value_pointer.(*SSAId).*;
               array_add(b, xx index);
            }
         }

         case .CompositeExtract; {
            assert(operands.count >= 4, "count: %, %", operands.count, operands);
            assert(operands[0].type == cast(*Type_Info) SSAId);
            assert(operands[1].type == cast(*Type_Info) SSAId);
            assert(operands[2].type == cast(*Type_Info) SSAId);

            resultType := operands[0].value_pointer.(*SSAId).*;
            result     := operands[1].value_pointer.(*SSAId).*;
            composite  := operands[2].value_pointer.(*SSAId).*;

            array_add(b, OpWordCount(op, operands.count), cast(u32) resultType, cast(u32) result, cast(u32) composite);

            for 3..operands.count - 1 {
               assert(operands[it].type == cast(*Type_Info) int);

               index := operands[it].value_pointer.(*int).*;
               array_add(b, xx index);
            }
         }

         case .FDiv; #through;
         case .FMul; #through;
         case .FAdd; #through;
         case .FSub; #through;
         case .IAdd; #through;
         case .ISub; #through;
         case .IMul; {
            assert(operands.count == 4);
            assert(operands[0].type == cast(*Type_Info) SSAId);
            assert(operands[1].type == cast(*Type_Info) SSAId);
            assert(operands[2].type == cast(*Type_Info) SSAId);
            assert(operands[3].type == cast(*Type_Info) SSAId);

            resultType := operands[0].value_pointer.(*SSAId).*;
            result     := operands[1].value_pointer.(*SSAId).*;
            operand1   := operands[2].value_pointer.(*SSAId).*;
            operand2   := operands[3].value_pointer.(*SSAId).*;

            array_add(b, OpWordCount(op, operands.count), cast(u32) resultType, cast(u32) result, cast(u32) operand1, cast(u32) operand2);
         }

         case .SLessThan; {
            assert(operands.count == 4);
            assert(operands[0].type == cast(*Type_Info) SSAId);
            assert(operands[1].type == cast(*Type_Info) SSAId);
            assert(operands[2].type == cast(*Type_Info) SSAId);
            assert(operands[3].type == cast(*Type_Info) SSAId);

            resultType := operands[0].value_pointer.(*SSAId).*;
            result     := operands[1].value_pointer.(*SSAId).*;
            operand1   := operands[2].value_pointer.(*SSAId).*;
            operand2   := operands[3].value_pointer.(*SSAId).*;

            array_add(b, OpWordCount(op, operands.count), cast(u32) resultType, cast(u32) result, cast(u32) operand1, cast(u32) operand2);
         }

         case .ULessThan; {
            assert(operands.count == 4);
            assert(operands[0].type == cast(*Type_Info) SSAId);
            assert(operands[1].type == cast(*Type_Info) SSAId);
            assert(operands[2].type == cast(*Type_Info) SSAId);
            assert(operands[3].type == cast(*Type_Info) SSAId);

            resultType := operands[0].value_pointer.(*SSAId).*;
            result     := operands[1].value_pointer.(*SSAId).*;
            operand1   := operands[2].value_pointer.(*SSAId).*;
            operand2   := operands[3].value_pointer.(*SSAId).*;

            array_add(b, OpWordCount(op, operands.count), cast(u32) resultType, cast(u32) result, cast(u32) operand1, cast(u32) operand2);
         }

         case .FConvert; #through;
         case .SConvert; {
            assert(operands.count == 3);
            assert(operands[0].type == cast(*Type_Info) SSAId);
            assert(operands[1].type == cast(*Type_Info) SSAId);
            assert(operands[2].type == cast(*Type_Info) SSAId);

            resultType := operands[0].value_pointer.(*SSAId).*;
            result     := operands[1].value_pointer.(*SSAId).*;
            operand    := operands[2].value_pointer.(*SSAId).*;

            array_add(b, OpWordCount(op, operands.count), cast(u32) resultType, cast(u32) result, cast(u32) operand);
         }

         case .UConvert; {
            assert(operands.count == 3);
            assert(operands[0].type == cast(*Type_Info) SSAId);
            assert(operands[1].type == cast(*Type_Info) SSAId);
            assert(operands[2].type == cast(*Type_Info) SSAId);

            resultType := operands[0].value_pointer.(*SSAId).*;
            result     := operands[1].value_pointer.(*SSAId).*;
            operand    := operands[2].value_pointer.(*SSAId).*;

            array_add(b, OpWordCount(op, operands.count), cast(u32) resultType, cast(u32) result, cast(u32) operand);
         }

         case .ConvertSToF; {
            assert(operands.count == 3);
            assert(operands[0].type == cast(*Type_Info) SSAId);
            assert(operands[1].type == cast(*Type_Info) SSAId);
            assert(operands[2].type == cast(*Type_Info) SSAId);

            resultType := operands[0].value_pointer.(*SSAId).*;
            result     := operands[1].value_pointer.(*SSAId).*;
            operand    := operands[2].value_pointer.(*SSAId).*;

            array_add(b, OpWordCount(op, operands.count), cast(u32) resultType, cast(u32) result, cast(u32) operand);
         }

         // ids, and the image operands mask before the image operands
         case .ImageGather; #through;
         case .ImageSampleDrefImplicitLod; #through;
         case .ImageSampleDrefExplicitLod; #through;
         case .ImageFetch; #through;
         case .ImageRead; #through;
         case .ImageQuerySizeLod; #through;
         case .ImageQueryLevels; #through;
         case .ImageQuerySize; {
            array_add(b, OpWordCount(op, operands.count));
            for operands {
               if (it.type == cast(*Type_Info) SpvImageOperandsMask) {
                  array_add(b, cast(u32) it.value_pointer.(*SpvImageOperandsMask).*);
               } else {
                  assert(it.type == cast(*Type_Info) SSAId);
                  array_add(b, cast(u32) it.value_pointer.(*SSAId).*);
               }
            }
         }

         // all the operands are ids
         case .DemoteToHelperInvocation; #through;
         case .ControlBarrier; #through;
         case .AtomicIAdd; #through;
         case .AtomicSMin; #through;
         case .AtomicUMin; #through;
         case .AtomicSMax; #through;
         case .AtomicUMax; #through;
         case .AtomicAnd; #through;
         case .AtomicOr; #through;
         case .AtomicXor; #through;
         case .AtomicExchange; #through;
         case .AtomicCompareExchange; {
            array_add(b, OpWordCount(op, operands.count));
            for operands {
               assert(it.type == cast(*Type_Info) SSAId);
               array_add(b, cast(u32) it.value_pointer.(*SSAId).*);
            }
         }

         // selector, default, then pairs of (literal, label). a literal is u32 or u64 depending on the width of the selector.
         case .Switch; {
            assert(operands.count >= 2 && operands.count % 2 == 0);
            assert(operands[0].type == cast(*Type_Info) SSAId);
            assert(operands[1].type == cast(*Type_Info) SSAId);

            selector     := operands[0].value_pointer.(*SSAId).*;
            defaultLabel := operands[1].value_pointer.(*SSAId).*;

            wordCount := 2;
            for i: 0..(operands.count - 2) / 2 - 1 {
               literal := operands[2 + i * 2];
               assert(literal.type == cast(*Type_Info) u32 || literal.type == cast(*Type_Info) u64);
               wordCount += ifx literal.type == cast(*Type_Info) u64 then 3 else 2;
            }

            array_add(b, OpWordCount(op, wordCount), cast(u32) selector, cast(u32) defaultLabel);

            for i: 0..(operands.count - 2) / 2 - 1 {
               literal := operands[2 + i * 2];
               label   := operands[2 + i * 2 + 1];
               assert(label.type == cast(*Type_Info) SSAId);

               if (literal.type == cast(*Type_Info) u64) {
                  value := literal.value_pointer.(*u64).*;
                  array_add(b, cast(u32) (value & 0xFFFFFFFF), cast(u32) (value >> 32));
               } else {
                  array_add(b, literal.value_pointer.(*u32).*);
               }

               array_add(b, cast(u32) label.value_pointer.(*SSAId).*);
            }
         }

         case .Select; {
            assert(operands.count == 5);
            assert(operands[0].type == cast(*Type_Info) SSAId);
            assert(operands[1].type == cast(*Type_Info) SSAId);
            assert(operands[2].type == cast(*Type_Info) SSAId);
            assert(operands[3].type == cast(*Type_Info) SSAId);
            assert(operands[4].type == cast(*Type_Info) SSAId);

            resultType := operands[0].value_pointer.(*SSAId).*;
            result     := operands[1].value_pointer.(*SSAId).*;
            condition  := operands[2].value_pointer.(*SSAId).*;
            object1    := operands[3].value_pointer.(*SSAId).*;
            object2    := operands[4].value_pointer.(*SSAId).*;

            array_add(b, OpWordCount(op, operands.count), cast(u32) resultType, cast(u32) result, cast(u32) condition, cast(u32) object1, cast(u32) object2);
         }

         case .LoopMerge; {
            assert(operands.count >= 3);
            assert(operands[0].type == cast(*Type_Info) SSAId);
            assert(operands[1].type == cast(*Type_Info) SSAId);
            assert(operands[2].type == cast(*Type_Info) SpvLoopControlMask);

            mergeBlock     := operands[0].value_pointer.(*SSAId).*;
            continueTarget := operands[1].value_pointer.(*SSAId).*;
            loopControl    := operands[2].value_pointer.(*SpvLoopControlMask).*;

            array_add(b, OpWordCount(op, operands.count), cast(u32) mergeBlock, cast(u32) continueTarget, cast(u32) loopControl);

            for 3..operands.count - 1 {
               assert(operands[it].type == cast(*Type_Info) int); // all parameters are u32

               parameter := operands[it].value_pointer.(*int).*;
               array_add(b, cast(u32) parameter);
            }
         }

         case .ConvertPtrToU; {
            assert(operands.count == 3);
            assert(operands[0].type == cast(*Type_Info) SSAId);
            assert(operands[1].type == cast(*Type_Info) SSAId);
            assert(operands[2].type == cast(*Type_Info) SSAId);

            resultType := operands[0].value_pointer.(*SSAId).*;
            result     := operands[1].value_pointer.(*SSAId).*;
            pointer    := operands[2].value_pointer.(*SSAId).*;

            array_add(b, OpWordCount(op, operands.count), cast(u32) resultType, cast(u32) result, cast(u32) pointer);
         }

         case .ConvertUToPtr; {
            assert(operands.count == 3);
            assert(operands[0].type == cast(*Type_Info) SSAId);
            assert(operands[1].type == cast(*Type_Info) SSAId);
            assert(operands[2].type == cast(*Type_Info) SSAId);

            resultType := operands[0].value_pointer.(*SSAId).*;
            result     := operands[1].value_pointer.(*SSAId).*;
            value      := operands[2].value_pointer.(*SSAId).*;

            array_add(b, OpWordCount(op, operands.count), cast(u32) resultType, cast(u32) result, cast(u32) value);
         }

         case .VectorTimesMatrix; #through;
         case .MatrixTimesMatrix; {
            assert(operands.count == 4);
            assert(operands[0].type == cast(*Type_Info) SSAId);
            assert(operands[1].type == cast(*Type_Info) SSAId);
            assert(operands[2].type == cast(*Type_Info) SSAId);
            assert(operands[3].type == cast(*Type_Info) SSAId);

            resultType := operands[0].value_pointer.(*SSAId).*;
            result     := operands[1].value_pointer.(*SSAId).*;
            left       := operands[2].value_pointer.(*SSAId).*;
            right      := operands[3].value_pointer.(*SSAId).*;

            array_add(b, OpWordCount(op, operands.count), cast(u32) resultType, cast(u32) result, cast(u32) left, cast(u32) right);
         }

         case .MatrixTimesVector; {
            assert(operands.count == 4);
            assert(operands[0].type == cast(*Type_Info) SSAId);
            assert(operands[1].type == cast(*Type_Info) SSAId);
            assert(operands[2].type == cast(*Type_Info) SSAId);
            assert(operands[3].type == cast(*Type_Info) SSAId);

            resultType := operands[0].value_pointer.(*SSAId).*;
            result     := operands[1].value_pointer.(*SSAId).*;
            matrix     := operands[2].value_pointer.(*SSAId).*;
            vector     := operands[3].value_pointer.(*SSAId).*;

            array_add(b, OpWordCount(op, operands.count), cast(u32) resultType, cast(u32) result, cast(u32) matrix, cast(u32) vector);
         }

         case .Dot; {
            assert(operands.count == 4);
            assert(operands[0].type == cast(*Type_Info) SSAId);
            assert(operands[1].type == cast(*Type_Info) SSAId);
            assert(operands[2].type == cast(*Type_Info) SSAId);
            assert(operands[3].type == cast(*Type_Info) SSAId);

            resultType := operands[0].value_pointer.(*SSAId).*;
            result     := operands[1].value_pointer.(*SSAId).*;
            vector1    := operands[2].value_pointer.(*SSAId).*;
            vector2    := operands[3].value_pointer.(*SSAId).*;

            array_add(b, OpWordCount(op, operands.count), cast(u32) resultType, cast(u32) result, cast(u32) vector1, cast(u32) vector2);
         }

         case .FunctionCall; {
            assert(operands.count >= 3);
            assert(operands[0].type == cast(*Type_Info) SSAId);
            assert(operands[1].type == cast(*Type_Info) SSAId);
            assert(operands[2].type == cast(*Type_Info) SSAId);

            resultType := operands[0].value_pointer.(*SSAId).*;
            result     := operands[1].value_pointer.(*SSAId).*;
            function   := operands[2].value_pointer.(*SSAId).*;

            array_add(b, OpWordCount(op, operands.count), cast(u32) resultType, cast(u32) result, cast(u32) function);

            for 3..operands.count - 1 {
               assert(operands[it].type == cast(*Type_Info) SSAId);

               argument := operands[it].value_pointer.(*SSAId).*;
               array_add(b, xx argument);
            }
         }

         case .FunctionParameter; {
            assert(operands.count == 2);
            assert(operands[0].type == cast(*Type_Info) SSAId);
            assert(operands[1].type == cast(*Type_Info) SSAId);

            resultType := operands[0].value_pointer.(*SSAId).*;
            result     := operands[1].value_pointer.(*SSAId).*;

            array_add(b, OpWordCount(op, operands.count), cast(u32) resultType, cast(u32) result);
         }

         case .FNegate; {
            assert(operands.count == 3);
            assert(operands[0].type == cast(*Type_Info) SSAId);
            assert(operands[1].type == cast(*Type_Info) SSAId);
            assert(operands[2].type == cast(*Type_Info) SSAId);

            resultType := operands[0].value_pointer.(*SSAId).*;
            result     := operands[1].value_pointer.(*SSAId).*;
            operand    := operands[2].value_pointer.(*SSAId).*;

            array_add(b, OpWordCount(op, operands.count), cast(u32) resultType, cast(u32) result, cast(u32) operand);
         }

         case .SNegate; {
            assert(operands.count == 3);
            assert(operands[0].type == cast(*Type_Info) SSAId);
            assert(operands[1].type == cast(*Type_Info) SSAId);
            assert(operands[2].type == cast(*Type_Info) SSAId);

            resultType := operands[0].value_pointer.(*SSAId).*;
            result     := operands[1].value_pointer.(*SSAId).*;
            operand    := operands[2].value_pointer.(*SSAId).*;

            array_add(b, OpWordCount(op, operands.count), cast(u32) resultType, cast(u32) result, cast(u32) operand);
         }

         case .CopyLogical; {
            assert(operands.count == 3);
            assert(operands[0].type == cast(*Type_Info) SSAId);
            assert(operands[1].type == cast(*Type_Info) SSAId);
            assert(operands[2].type == cast(*Type_Info) SSAId);

            resultType := operands[0].value_pointer.(*SSAId).*;
            result     := operands[1].value_pointer.(*SSAId).*;
            operand    := operands[2].value_pointer.(*SSAId).*;

            array_add(b, OpWordCount(op, operands.count), cast(u32) resultType, cast(u32) result, cast(u32) operand);
         }

         case .ExtInst; {
            assert(operands.count >= 4);
            assert(operands[0].type == cast(*Type_Info) SSAId);
            assert(operands[1].type == cast(*Type_Info) SSAId);
            assert(operands[2].type == cast(*Type_Info) SSAId);
            assert(operands[3].type == cast(*Type_Info) GLSLstd450); // if you add more extended instruction sets then or (||) them here. right now only GLSLstd450

            resultType  := operands[0].value_pointer.(*SSAId).*;
            result      := operands[1].value_pointer.(*SSAId).*;
            set         := operands[2].value_pointer.(*SSAId).*;
            instruction := operands[3].value_pointer.(*GLSLstd450).*;

            array_add(b, OpWordCount(op, operands.count), cast(u32) resultType, cast(u32) result, cast(u32) set, cast(u32) instruction);

            for 4..operands.count - 1 {
               assert(operands[it].type == cast(*Type_Info) SSAId);

               operand := operands[it].value_pointer.(*SSAId).*;
               array_add(b, xx operand);
            }
         }

         case .TraceRayKHR; {
            assert(operands.count == 11);
            assert(operands[0].type == cast(*Type_Info) SSAId);
            assert(operands[1].type == cast(*Type_Info) SSAId);
            assert(operands[2].type == cast(*Type_Info) SSAId);
            assert(operands[3].type == cast(*Type_Info) SSAId);
            assert(operands[4].type == cast(*Type_Info) SSAId);
            assert(operands[5].type == cast(*Type_Info) SSAId);
            assert(operands[6].type == cast(*Type_Info) SSAId);
            assert(operands[7].type == cast(*Type_Info) SSAId);
            assert(operands[8].type == cast(*Type_Info) SSAId);
            assert(operands[9].type == cast(*Type_Info) SSAId);
            assert(operands[10].type == cast(*Type_Info) SSAId);

            tlas           := operands[0].value_pointer.(*SSAId).*;
            rayFlags       := operands[1].value_pointer.(*SSAId).*;
            cullMask       := operands[2].value_pointer.(*SSAId).*;
            sbtOffset      := operands[3].value_pointer.(*SSAId).*;
            sbtStride      := operands[4].value_pointer.(*SSAId).*;
            missIndex      := operands[5].value_pointer.(*SSAId).*;
            rayOrigin      := operands[6].value_pointer.(*SSAId).*;
            rayTMin        := operands[7].value_pointer.(*SSAId).*;
            rayDirection   := operands[8].value_pointer.(*SSAId).*;
            rayTMax        := operands[9].value_pointer.(*SSAId).*;
            payload        := operands[10].value_pointer.(*SSAId).*;

            array_add(b, OpWordCount(op, operands.count), cast(u32) tlas, cast(u32) rayFlags, cast(u32) cullMask, cast(u32) sbtOffset, cast(u32) sbtStride, cast(u32) missIndex, cast(u32) rayOrigin, cast(u32) rayTMin, cast(u32) rayDirection, cast(u32) rayTMax, cast(u32) payload);
         }

         case .TypeAccelerationStructureKHR; {
            assert(operands.count == 1);
            assert(operands[0].type == cast(*Type_Info) SSAId);

            result := operands[0].value_pointer.(*SSAId).*;

            array_add(b, OpWordCount(op, operands.count), cast(u32) result);
         }

         case .ImageWrite; {
            assert(operands.count >= 3);
            assert(operands[0].type == cast(*Type_Info) SSAId);
            assert(operands[1].type == cast(*Type_Info) SSAId);
            assert(operands[2].type == cast(*Type_Info) SSAId);

            image       := operands[0].value_pointer.(*SSAId).*;
            coordinate  := operands[1].value_pointer.(*SSAId).*;
            texel       := operands[2].value_pointer.(*SSAId).*;

            array_add(b, OpWordCount(op, operands.count), cast(u32) image, cast(u32) coordinate, cast(u32) texel);

            for 3..operands.count - 1 {
               assert(operands[it].type == cast(*Type_Info) SSAId);

               operand := operands[it].value_pointer.(*SSAId).*;
               array_add(b, xx operand);
            }
         }

         case .SDiv; #through;
         case .UDiv; #through;
         case .SRem; #through;
         case .UMod; #through;
         case .FRem; #through;
         case .BitwiseAnd; #through;
         case .BitwiseOr; #through;
         case .BitwiseXor; #through;
         case .ShiftLeftLogical; #through;
         case .ShiftRightLogical; #through;
         case .ShiftRightArithmetic; #through;
         case .SGreaterThan; #through;
         case .SLessThanEqual; #through;
         case .SGreaterThanEqual; #through;
         case .UGreaterThan; #through;
         case .ULessThanEqual; #through;
         case .UGreaterThanEqual; #through;
         case .IEqual; #through;
         case .INotEqual; #through;
         case .FOrdLessThan; #through;
         case .FOrdGreaterThan; #through;
         case .FOrdLessThanEqual; #through;
         case .FOrdGreaterThanEqual; #through;
         case .FOrdEqual; #through;
         case .FUnordNotEqual; #through;
         case .LogicalEqual; #through;
         case .LogicalNotEqual; #through;
         case .LogicalAnd; #through;
         case .VectorTimesScalar; #through;
         case .LogicalOr; {
            assert(operands.count == 4);
            assert(operands[0].type == cast(*Type_Info) SSAId);
            assert(operands[1].type == cast(*Type_Info) SSAId);
            assert(operands[2].type == cast(*Type_Info) SSAId);
            assert(operands[3].type == cast(*Type_Info) SSAId);

            resultType := operands[0].value_pointer.(*SSAId).*;
            result     := operands[1].value_pointer.(*SSAId).*;
            operand1   := operands[2].value_pointer.(*SSAId).*;
            operand2   := operands[3].value_pointer.(*SSAId).*;

            array_add(b, OpWordCount(op, operands.count), cast(u32) resultType, cast(u32) result, cast(u32) operand1, cast(u32) operand2);
         }

         case .LogicalNot; #through;
         case .Not; #through;
         case .ConvertFToS; #through;
         case .ConvertFToU; {
            assert(operands.count == 3);
            assert(operands[0].type == cast(*Type_Info) SSAId);
            assert(operands[1].type == cast(*Type_Info) SSAId);
            assert(operands[2].type == cast(*Type_Info) SSAId);

            resultType := operands[0].value_pointer.(*SSAId).*;
            result     := operands[1].value_pointer.(*SSAId).*;
            operand    := operands[2].value_pointer.(*SSAId).*;

            array_add(b, OpWordCount(op, operands.count), cast(u32) resultType, cast(u32) result, cast(u32) operand);
         }

         case; assert(false, "not yet implemented! op: %", op);
      }
   } else {
      #assert(false, "not implemented yet! type: %", SPIRV_BUILDER_TYPE);
   }
}

ToSpirvString :: (s: string) -> [] u32 #expand {
   // zero padded
   buffer := NewArray((s.count + 1 + 3) / 4, u32); // + 1 for the null terminator
   memcpy(buffer.data, s.data, s.count);
   return buffer;
}

SpvFunctionControlMaskToString :: (value: SpvFunctionControlMask) -> string {
   if value == {
      case .MaskNone;            return "None";
      case .InlineMask;          return "Inline";
      case .DontInlineMask;      return "DontInline";
      case .PureMask;            return "Pure";
      case .ConstMask;           return "Const";
      case .OptNoneEXTMask;      return "OptNoneEXT";
      case; assert(false, "not implemented"); return "";
   }
}

OpWordCount :: (op: SpvOp, operandsCount: int) -> u32 #expand {
   // higher 16 bits = word count
   // lower 16 bits  = op
   return cast(u32) ((operandsCount + 1) << 16) | cast(u32) op; // + 1 for this word
}

// this function is called for every identifier that exists in the shader program
// this function writes to "Types, variables and constants" block, so if an identifier doesnt go in that block this function should ignore and skip that identifier instead of asserting.
// i first thought that i should call this functions only on identifiers that goes into the "Types, variables and constants" block, but it is easier to let pass every identifier to this function
// and this function just skips if an identifier doesnt go to the "Types, variables and constants" block instead of asserting false.
//          - apila, 13/04/26
WriteUntypedUniformConstantVariable :: (data: *CompilationData, b: *BuilderType, identifier: Identifier) {
   voidStarUC := New(TypeInfoPointer);
   voidStarUC.pointerTo = cast(*Type_Info) void;
   voidStarUC.storageClass = .UniformConstant;

   typeIdentifier: Identifier = .{ type = ._Type, _type = voidStarUC };
   WriteTypeOrVariableOrConstant(data, b, typeIdentifier);

   WriteSingleInstruction(
      b,
      .UntypedVariableKHR,
      GetSSAId(data, typeIdentifier),
      GetSSAId(data, identifier),
      SpvStorageClass.UniformConstant
   );
}

WriteTypeOrVariableOrConstant :: (data: *CompilationData, b: *BuilderType, identifier: Identifier) {
   currentStatus := table_find_pointer(*data.writtenIdentifiers, identifier);
   if (currentStatus != null) {
      if (false) {
      } else if (currentStatus.* == .BeingProcessed) {
         // a pointer type that is waiting for its pointee to be written, and the pointee (indirectly) uses the pointer. for example:
         //    Node :: struct { next: *Node; }
         // when *Node is written first. it is forward declared here, the OpTypePointer is written by the outer call once Node is done.
         isPointer := identifier.type == ._Type && identifier._type.type == TYPE_INFO_POINTER_TAG;
         if (isPointer) {
            for data.forwardDeclaredPointers  if (IdentifierCompare(it, identifier)) return;

            tip := cast(*TypeInfoPointer) identifier._type;
            assert(tip.storageClass == .PhysicalStorageBuffer, "only PhysicalStorageBuffer pointers can be forward declared. storageClass: %", tip.storageClass);

            WriteSingleInstruction(
               b,
               .TypeForwardPointer,
               GetSSAId(data, identifier),
               tip.storageClass
            );

            array_add(*data.forwardDeclaredPointers, identifier);
            return;
         }

         assert(false, "identifier: %. recursion detected. a type depends on itself.", identifier);
      } else if (currentStatus.* == .Written) {
         return;
      }
   }

   status, newlyAdded := find_or_add(*data.writtenIdentifiers, identifier);
   assert(newlyAdded);
   status.* = .BeingProcessed;

   defer {
      status = table_find_pointer(*data.writtenIdentifiers, identifier);
      assert(status != null);
      status.* = .Written;

      // write the OpTypePointer of forward declared pointers whose pointee is now written
      for data.pendingPointers {
         tip := cast(*TypeInfoPointer) it._type;
         pointerToIdentifier: Identifier = .{ type = ._Type, _type = tip.pointerTo };
         pointerToStatus := table_find_pointer(*data.writtenIdentifiers, pointerToIdentifier);
         if (pointerToStatus == null || pointerToStatus.* != .Written) continue;

         WriteSingleInstruction(
            b,
            .TypePointer,
            GetSSAId(data, it),
            tip.storageClass,
            GetSSAId(data, pointerToIdentifier)
         );

         remove it;
      }
   }

   dependencies := table_find_pointer(*data.extraTypeDependencies, identifier);
   if (dependencies != null) {
      for dependencies.* {
         WriteTypeOrVariableOrConstant(data, b, it);
         remove it;
      }
   }

   if #complete identifier.type == {
      case .Invalid; assert(false);
      case .InternalVariable; {
         assert(identifier.internalVariable == .ResourceHeap);
         WriteUntypedUniformConstantVariable(data, b, identifier);
      }
      case .IntLiteral;
         intLiteralType: Type;
         #if (false) {
         } else if (identifier.intLiteral.bitSize == 8) {
            intLiteralType = ifx identifier.intLiteral.unsigned then u8 else s8;
         } else if (identifier.intLiteral.bitSize == 16) {
            intLiteralType = ifx identifier.intLiteral.unsigned then u16 else s16;
         } else if (identifier.intLiteral.bitSize == 32) {
            if (identifier.intLiteral.unsigned) {
               intLiteralType = u32;
            } else {
               intLiteralType = s32;
            }
         } else if (identifier.intLiteral.bitSize == 64) {
            if (identifier.intLiteral.unsigned) {
               intLiteralType = u64;
            } else {
               intLiteralType = s64;
            }
         } else {
            assert(false, "identifier.intLiteral.bitSize: %, not implemented yet!", identifier.intLiteral.bitSize);
         }

         intIdentifier: Identifier = .{ type = ._Type, _type = cast(*Type_Info) intLiteralType };
         WriteTypeOrVariableOrConstant(data, b, intIdentifier);

         operands: [..] Any;
         array_add(*operands, GetSSAId(data, intIdentifier));
         array_add(*operands, GetSSAId(data, identifier));

         // literals narrower than 32 bits still take a whole word. for unsigned types the high bits must be zero, for signed types they are the sign extension.
         if (identifier.intLiteral.unsigned) {
            if (identifier.intLiteral.bitSize == 8) {
               array_add(*operands, cast(u32) (identifier.intLiteral.value._u64 & 0xFF));
            } else if (identifier.intLiteral.bitSize == 16) {
               array_add(*operands, cast(u32) (identifier.intLiteral.value._u64 & 0xFFFF));
            } else if (identifier.intLiteral.bitSize == 32) {
               array_add(*operands, cast(u32) identifier.intLiteral.value._u64);
            } else if (identifier.intLiteral.bitSize == 64) {
               array_add(*operands, cast(u64) identifier.intLiteral.value._u64);
            } else {
               assert(false);
            }
         } else {
            if (identifier.intLiteral.bitSize == 8) {
               array_add(*operands, cast(s32) cast,trunc(s8) identifier.intLiteral.value._s64);
            } else if (identifier.intLiteral.bitSize == 16) {
               array_add(*operands, cast(s32) cast,trunc(s16) identifier.intLiteral.value._s64);
            } else if (identifier.intLiteral.bitSize == 32) {
               array_add(*operands, cast(s32) identifier.intLiteral.value._s64);
            } else if (identifier.intLiteral.bitSize == 64) {
               array_add(*operands, cast(s64) identifier.intLiteral.value._s64);
            } else {
               assert(false);
            }
         }

         WriteSingleInstruction(
            b,
            .Constant,
            .. operands
         );

      case .FloatLiteral;
         floatIdentifier: Identifier = .{ type = ._Type, _type = cast(*Type_Info) f32 };
         WriteTypeOrVariableOrConstant(data, b, floatIdentifier);

         WriteSingleInstruction(
            b,
            .Constant,
            GetSSAId(data, floatIdentifier),
            GetSSAId(data, identifier),
            identifier.floatLiteral
         );

      case .Float64Literal;
         floatIdentifier: Identifier = .{ type = ._Type, _type = cast(*Type_Info) f64 };
         WriteTypeOrVariableOrConstant(data, b, floatIdentifier);

         WriteSingleInstruction(
            b,
            .Constant,
            GetSSAId(data, floatIdentifier),
            GetSSAId(data, identifier),
            identifier.float64Literal
         );

      case .Function;
         return;

      case ._Type;
         type := identifier._type;

         // intrinsics
         numericInfo, isNumeric := GetNumericInfo(type);
         if (isNumeric) {
            if (numericInfo.components > 1) {
               elementIdentifier: Identifier = .{ type = ._Type, _type = GetNumericType(numericInfo.kind, numericInfo.bitSize, 1) };
               WriteTypeOrVariableOrConstant(data, b, elementIdentifier);

               WriteSingleInstruction(
                  b,
                  .TypeVector,
                  GetSSAId(data, identifier),
                  GetSSAId(data, elementIdentifier),
                  numericInfo.components
               );
               return;
            }

            if numericInfo.kind == {
               case .Bool;
                  WriteSingleInstruction(
                     b,
                     .TypeBool,
                     GetSSAId(data, identifier)
                  );
               case .Signed; #through;
               case .Unsigned;
                  WriteSingleInstruction(
                     b,
                     .TypeInt,
                     GetSSAId(data, identifier),
                     numericInfo.bitSize,
                     ifx numericInfo.kind == .Signed then 1 else 0
                  );
               case .Float;
                  WriteSingleInstruction(
                     b,
                     .TypeFloat,
                     GetSSAId(data, identifier),
                     numericInfo.bitSize
                  );
            }
            return;
         }

         if (CompareType(type, cast(*Type_Info) f32x2x2)) {
            float2Identifier: Identifier = .{ type = ._Type, _type = cast(*Type_Info) f32x2 };
            WriteTypeOrVariableOrConstant(data, b, float2Identifier);

            WriteSingleInstruction(
               b,
               .TypeMatrix,
               GetSSAId(data, identifier),
               GetSSAId(data, float2Identifier),
               2
            );
            return;
         }

         if (CompareType(type, cast(*Type_Info) f32x3x3)) {
            float3Identifier: Identifier = .{ type = ._Type, _type = cast(*Type_Info) f32x3 };
            WriteTypeOrVariableOrConstant(data, b, float3Identifier);

            WriteSingleInstruction(
               b,
               .TypeMatrix,
               GetSSAId(data, identifier),
               GetSSAId(data, float3Identifier),
               3
            );
            return;
         }

         if (CompareType(type, cast(*Type_Info) f32x4x4)) {
            float4Identifier: Identifier = .{ type = ._Type, _type = cast(*Type_Info) f32x4 };
            WriteTypeOrVariableOrConstant(data, b, float4Identifier);

            WriteSingleInstruction(
               b,
               .TypeMatrix,
               GetSSAId(data, identifier),
               GetSSAId(data, float4Identifier),
               4
            );
            return;
         }

         if (CompareType(type, cast(*Type_Info) f32x3x4)) {
            float3Identifier: Identifier = .{ type = ._Type, _type = cast(*Type_Info) f32x3 };
            WriteTypeOrVariableOrConstant(data, b, float3Identifier);

            WriteSingleInstruction(
               b,
               .TypeMatrix,
               GetSSAId(data, identifier),
               GetSSAId(data, float3Identifier),
               4
            );
            return;
         }

         // do i need this seperately?
         // doesnt the general .STRUCT case below already do the same?
         //       - apila, 07/09/26
         if (CompareType(type, cast(*Type_Info) MeshPipelinePushData)) {
            tip := New(TypeInfoPointer);
            tip.pointerTo = cast(*Type_Info) void;
            tip.storageClass = .PhysicalStorageBuffer;
            voidStar: Identifier = .{ type = ._Type, _type = tip };
            WriteTypeOrVariableOrConstant(data, b, voidStar);

            WriteSingleInstruction(
               b,
               .TypeStruct,
               GetSSAId(data, identifier),
               GetSSAId(data, voidStar), // task
               GetSSAId(data, voidStar), // mesh
               GetSSAId(data, voidStar)  // fragment
            );
            return;
         }

         if (CompareType(type, cast(*Type_Info) TypeInfoSampledImage)) {
            tisi := cast(*TypeInfoSampledImage) type;

            imageIdentifier: Identifier = .{ type = ._Type, _type = tisi.image };
            WriteTypeOrVariableOrConstant(data, b, imageIdentifier);

            WriteSingleInstruction(
               b,
               .TypeSampledImage,
               GetSSAId(data, identifier),
               GetSSAId(data, imageIdentifier)
            );
            return;
         }

         if (CompareType(type, cast(*Type_Info) __Sampler__)) {
            WriteSingleInstruction(
               b,
               .TypeSampler,
               GetSSAId(data, identifier)
            );
            return;
         }

         if (CompareType(type, cast(*Type_Info) __TLAS__)) {
            WriteSingleInstruction(
               b,
               .TypeAccelerationStructureKHR,
               GetSSAId(data, identifier)
            );
            return;
         }

         ti := cast(*Type_Info) type;

         assert(ti.type != .POINTER);

         if (ti.type == TYPE_INFO_IMAGE_TAG) {
            tii := cast(*TypeInfoImage) ti;

            sampledTypeIdentifier: Identifier = .{ type = ._Type, _type = tii.sampledType };
            WriteTypeOrVariableOrConstant(data, b, sampledTypeIdentifier);

            WriteSingleInstruction(
               b,
               .TypeImage,
               GetSSAId(data, identifier),
               GetSSAId(data, sampledTypeIdentifier),
               tii.dimensionality,
               tii.depth,
               tii.arrayed,
               tii.ms,
               tii.sampled,
               tii.imageFormat
            );

            return;
         } else if (ti.type == TYPE_INFO_RUNTIME_ARRAY_TAG) {
            tira := cast(*TypeInfoRuntimeArray) ti;

            elementTypeIdentifier: Identifier = .{ type = ._Type, _type = tira.elementType };
            WriteTypeOrVariableOrConstant(data, b, elementTypeIdentifier);

            WriteSingleInstruction(
               b,
               .TypeRuntimeArray,
               GetSSAId(data, identifier),
               GetSSAId(data, elementTypeIdentifier)
            );

            return;
         } else if (ti.type == TYPE_INFO_SAMPLED_IMAGE_TAG) {
            tisi := cast(*TypeInfoSampledImage) ti;

            imageIdentifier: Identifier = .{ type = ._Type, _type = tisi.image };
            WriteTypeOrVariableOrConstant(data, b, imageIdentifier);

            WriteSingleInstruction(
               b,
               .TypeSampledImage,
               GetSSAId(data, identifier),
               GetSSAId(data, imageIdentifier)
            );

            return;
         } else if (ti.type == TYPE_INFO_POINTER_TAG) {
            tip := cast(*TypeInfoPointer) ti;

            if (CompareType(tip.pointerTo, cast(*Type_Info) void)) {
               // VUID-StandaloneSpirv-OpTypeUntypedPointerKHR-11417
               // The Storage Class of OpTypeUntypedPointerKHR must be Image, UniformConstant,Workgroup, StorageBuffer, Uniform, PushConstant, or PhysicalStorageBuffer
               assert(tip.storageClass == .Image || tip.storageClass == .UniformConstant || tip.storageClass == .Workgroup ||
                     tip.storageClass == .StorageBuffer || tip.storageClass == .Uniform || tip.storageClass == .PushConstant ||
                     tip.storageClass == .PhysicalStorageBuffer,
                     "storageClass: %, type: %", tip.storageClass, type
               );

               WriteSingleInstruction(
                  b,
                  .TypeUntypedPointerKHR,
                  GetSSAId(data, identifier),
                  tip.storageClass
               );
            } else {
               pointerToIdentifier: Identifier = .{ type = ._Type, _type = tip.pointerTo };

               // a struct that (indirectly) points to itself. for example:
               //    Node :: struct { next: *Node; }
               // the struct is still being written so the pointer is forward declared and its OpTypePointer is written once the struct is done.
               pointerToStatus := table_find_pointer(*data.writtenIdentifiers, pointerToIdentifier);
               if (pointerToStatus != null && pointerToStatus.* == .BeingProcessed) {
                  assert(tip.storageClass == .PhysicalStorageBuffer, "only PhysicalStorageBuffer pointers can be forward declared. storageClass: %", tip.storageClass);

                  WriteSingleInstruction(
                     b,
                     .TypeForwardPointer,
                     GetSSAId(data, identifier),
                     tip.storageClass
                  );

                  array_add(*data.forwardDeclaredPointers, identifier);
                  array_add(*data.pendingPointers, identifier);
                  return;
               }

               WriteTypeOrVariableOrConstant(data, b, pointerToIdentifier);

               WriteSingleInstruction(
                  b,
                  .TypePointer,
                  GetSSAId(data, identifier),
                  tip.storageClass,
                  GetSSAId(data, pointerToIdentifier)
               );
            }

            return;
         }

         if (ti.type == .STRUCT || ti.type == TYPE_INFO_DECORATIONLESS_COPY_OF_STRUCT_TAG) {
            tis: *Type_Info_Struct;
            if (ti.type == .STRUCT) {
               tis = cast(*Type_Info_Struct) ti;
            } else if (ti.type == TYPE_INFO_DECORATIONLESS_COPY_OF_STRUCT_TAG) {
               tidcos := cast(*TypeInfoDecorationlessCopyOfStruct) ti;
               tis = tidcos.copyOf;
            } else {
               assert(false);
            }

            operands: [..] Any;
            array_add(*operands, GetSSAId(data, identifier));

            for GetStructMembers(tis) {
               memberType := ConvertJaiTypeIfNecessary(it.type, it.notes);
               if (ti.type == TYPE_INFO_DECORATIONLESS_COPY_OF_STRUCT_TAG) memberType = GetFunctionStorageClassType(memberType);

               memberTypeIdentifier: Identifier = .{ type = ._Type, _type = memberType };
               WriteTypeOrVariableOrConstant(data, b, memberTypeIdentifier);

               array_add(*operands, ac(GetSSAId(data, memberTypeIdentifier)));
            }

            #if SPIRV_BUILDER_TYPE == .String {
               print_to_builder(b, "; %\n", tis.name);
            }

            WriteSingleInstruction(
               b,
               .TypeStruct,
               .. operands
            );

            return;
         }

         // TODO
         // i guess this part is incomplete. it doesnt work with new storage class types.
         // in that regard i think GetReturnTypeIdentifier needs more information than just the Type_Info.
         //    - apila, 29/04/26
         if (ti.type == .PROCEDURE) {
            tip := cast(*Type_Info_Procedure) ti;

            returnTypeIdentifier := GetReturnTypeIdentifier(tip);
            WriteTypeOrVariableOrConstant(data, b, returnTypeIdentifier);

            operands: [..] Any;
            array_add(*operands, GetSSAId(data, identifier));
            array_add(*operands, GetSSAId(data, returnTypeIdentifier));

            for tip.argument_types {
               assert(it.type != .POINTER, "function takes a pointer. not implemented yet!");

               argumentType := it;
               argumentTypeIdentifier: Identifier = .{ type = ._Type, _type = argumentType };
               WriteTypeOrVariableOrConstant(data, b, argumentTypeIdentifier);

               array_add(*operands, ac(GetSSAId(data, argumentTypeIdentifier)));
            }

            WriteSingleInstruction(
               b,
               .TypeFunction,
               .. operands
            );

            return;
         }

         if (ti.type == .ARRAY) {
            tia := cast(*Type_Info_Array) ti;
            if tia.array_type == {
               case .FIXED; {
                  elementType := tia.element_type;
                  assert(tia.element_type.type != .POINTER, "tia.element_type.type: %. known limitation: cant use pointers inside array. wrap them in a struct for now", tia.element_type.type);
                  elementTypeIdentifier: Identifier = .{ type = ._Type, _type = elementType };
                  WriteTypeOrVariableOrConstant(data, b, elementTypeIdentifier);

                  arraySizeIdentifier: Identifier = .{ type = .IntLiteral, intLiteral = .{ unsigned = true, value._u64 = xx tia.array_count, bitSize = 32 } };
                  WriteTypeOrVariableOrConstant(data, b, arraySizeIdentifier);

                  WriteSingleInstruction(
                     b,
                     .TypeArray,
                     GetSSAId(data, identifier),
                     GetSSAId(data, elementTypeIdentifier),
                     GetSSAId(data, arraySizeIdentifier)
                  );
               }

               case .VIEW; {
                  // struct { count: int, data: *type };

                  elementType := tia.element_type;
                  assert(tia.element_type.type != .POINTER && tia.element_type.type != .ARRAY, "tia.element_type.type: %. known limitation: cant use pointers inside array. i think i need to just idk update DetermineCodeNodeTypes().", tia.element_type.type);
                  elementTypeIdentifier: Identifier = .{ type = ._Type, _type = elementType };
                  WriteTypeOrVariableOrConstant(data, b, elementTypeIdentifier);

                  countMemberTypeIdentifier: Identifier = .{ type = ._Type, _type = type_info(int) };

                  // hardcoding PhysicalStorageBuffer just like that because im a good programmer
                  dataMemberTypeIdentifier := GetPointerTypeIdentifier(elementType, .PhysicalStorageBuffer);

                  WriteTypeOrVariableOrConstant(data, b, countMemberTypeIdentifier);
                  WriteTypeOrVariableOrConstant(data, b, dataMemberTypeIdentifier);

                  WriteSingleInstruction(
                     b,
                     .TypeStruct,
                     GetSSAId(data, identifier),
                     GetSSAId(data, countMemberTypeIdentifier),
                     GetSSAId(data, dataMemberTypeIdentifier)
                  );
               }

               case .RESIZABLE; {
                  assert(false, "pls dont use resizable. thanks.");
               }

               case; {
                  assert(false, "unreachable Clueless");
               }
            }

            return;
         }

         assert(false, "not yet implemented! if it is a variant then idk. type: %!\n", type.*);

      case .Void;
         WriteSingleInstruction(
            b,
            .TypeVoid,
            GetSSAId(data, .{ type = .Void })
         );

      case .Variable;
         if (IdentifierCompare(identifier, data.meshVertexOutVariableIdentifier) || // [] MeshVertexOut
               IdentifierCompare(identifier, data.meshPrimitiveOutVariableIdentifier) || // [] MeshPrimitiveOut
               IdentifierCompare(identifier, meshVerticesVariableIdentifier) ||
               GetMeshPrimitiveIndicesIndex(identifier) != -1
            ) {

            storageClass: SpvStorageClass = .Output;
            typeIdentifier := GetVariableTypeIdentifier(data, identifier);
            pointerIdentifier := GetPointerTypeIdentifier(typeIdentifier, storageClass);
            WriteTypeOrVariableOrConstant(data, b, typeIdentifier);
            WriteTypeOrVariableOrConstant(data, b, pointerIdentifier);

            #if SPIRV_BUILDER_TYPE == .String {
               print_to_builder(b, "; %\n", name);
            }

            WriteSingleInstruction(
               b,
               .Variable,
               GetSSAId(data, pointerIdentifier),
               GetSSAId(data, identifier),
               storageClass,
            );
         } else if(IdentifierCompare(identifier, data.fragmentVertexInVariableIdentifier) ||
                   IdentifierCompare(identifier, data.fragmentPrimitiveInVariableIdentifier)) {
            storageClass := SpvStorageClass.Input;
            typeIdentifier := GetVariableTypeIdentifier(data, identifier);
            pointerIdentifier := GetPointerTypeIdentifier(typeIdentifier, storageClass);
            WriteTypeOrVariableOrConstant(data, b, pointerIdentifier);

            #if SPIRV_BUILDER_TYPE == .String {
               print_to_builder(b, "; %\n", name);
            }

            WriteSingleInstruction(
               b,
               .Variable,
               GetSSAId(data, pointerIdentifier),
               GetSSAId(data, identifier),
               storageClass,
            );
         } else if(IdentifierCompare(identifier, data.shaderDataPointerVariableIdentifier)) {
            type := identifier.variable.declaration.type;
            assert(type.type == .POINTER);

            tip := cast(*Type_Info_Pointer) type;

            variableType := New(TypeInfoPointer);
            variableType.pointerTo = tip.pointer_to;
            variableType.storageClass = .PhysicalStorageBuffer;

            variableTypeIdentifier: Identifier = .{ type = ._Type, _type = variableType };
            WriteTypeOrVariableOrConstant(data, b, variableTypeIdentifier);

            pointerIdentifier := GetPointerTypeIdentifier(variableType, .Private);
            WriteTypeOrVariableOrConstant(data, b, pointerIdentifier);

            WriteSingleInstruction(
               b,
               .Variable,
               GetSSAId(data, pointerIdentifier),
               GetSSAId(data, identifier),
               SpvStorageClass.Private
            );
         } else if(IdentifierCompare(identifier, data.incomingRayPayloadVariableIdentifier)) {
            storageClass := SpvStorageClass.IncomingRayPayloadKHR;
            returnTypeIdentifier := GetPointerTypeIdentifier(identifier.variable.declaration.type, storageClass);
            WriteTypeOrVariableOrConstant(data, b, returnTypeIdentifier);

            #if SPIRV_BUILDER_TYPE == .String {
               print_to_builder(b, "; payload [%]\n", it_index);
            }

            WriteSingleInstruction(
               b,
               .Variable,
               GetSSAId(data, returnTypeIdentifier),
               GetSSAId(data, identifier),
               storageClass
            );
         } else if(IdentifierCompare(identifier, meshPipelinePushDataVariableIdentifier)) {
            pointerType := New(TypeInfoPointer);
            pointerType.pointerTo = cast(*Type_Info) MeshPipelinePushData;
            pointerType.storageClass = .PushConstant;

            pointerTypeIdentifier: Identifier = .{ type = ._Type, _type = pointerType };
            WriteTypeOrVariableOrConstant(data, b, pointerTypeIdentifier);

            #if SPIRV_BUILDER_TYPE == .String {
               print_to_builder(b, "; push data variable\n");
            }

            WriteSingleInstruction(
               b,
               .Variable,
               GetSSAId(data, pointerTypeIdentifier),
               GetSSAId(data, identifier),
               SpvStorageClass.PushConstant
            );
         } else if(IdentifierCompare(identifier, rtxPipelinePushDataVariableIdentifier)) {
            pointerType := New(TypeInfoPointer);
            pointerType.pointerTo = cast(*Type_Info) RtxPipelinePushData;
            pointerType.storageClass = .PushConstant;

            pointerTypeIdentifier: Identifier = .{ type = ._Type, _type = pointerType };
            WriteTypeOrVariableOrConstant(data, b, pointerTypeIdentifier);

            #if SPIRV_BUILDER_TYPE == .String {
               print_to_builder(b, "; push data variable\n");
            }

            WriteSingleInstruction(
               b,
               .Variable,
               GetSSAId(data, pointerTypeIdentifier),
               GetSSAId(data, identifier),
               SpvStorageClass.PushConstant
            );
         } else if(IdentifierCompare(identifier, computePipelinePushDataVariableIdentifier)) {
            pointerType := New(TypeInfoPointer);
            pointerType.pointerTo = cast(*Type_Info) ComputePipelinePushData;
            pointerType.storageClass = .PushConstant;

            pointerTypeIdentifier: Identifier = .{ type = ._Type, _type = pointerType };
            WriteTypeOrVariableOrConstant(data, b, pointerTypeIdentifier);

            WriteSingleInstruction(
               b,
               .Variable,
               GetSSAId(data, pointerTypeIdentifier),
               GetSSAId(data, identifier),
               SpvStorageClass.PushConstant
            );
         } else if(IdentifierCompare(identifier, samplerHeapVariableIdentifier)) {
            WriteUntypedUniformConstantVariable(data, b, identifier);
         } else if(IdentifierCompare(identifier, imageHeapVariableIdentifier)) {
            WriteUntypedUniformConstantVariable(data, b, identifier);
         } else if(IdentifierCompare(identifier, tlasHeapVariableIdentifier)) {
            WriteUntypedUniformConstantVariable(data, b, identifier);
         } else if(GetBuiltinVariableIndex(identifier) != -1) {
            pointerType := New(TypeInfoPointer);
            pointerType.pointerTo = identifier.variable.declaration.type;
            pointerType.storageClass = .Input;

            typeIdentifier: Identifier = .{ type = ._Type, _type = pointerType };
            WriteTypeOrVariableOrConstant(data, b, typeIdentifier);

            #if SPIRV_BUILDER_TYPE == .String {
               print_to_builder(b, "; % variable\n", BUILTIN_VARIABLES[GetBuiltinVariableIndex(identifier)].name);
            }

            WriteSingleInstruction(
               b,
               .Variable,
               GetSSAId(data, typeIdentifier),
               GetSSAId(data, identifier),
               SpvStorageClass.Input
            );
         } else {
            for data.fragmentOutputIdentifiers {
               if (IdentifierCompare(identifier, it)) {
                  storageClass := SpvStorageClass.Output;
                  returnTypeIdentifier := GetPointerTypeIdentifier(it.variable.declaration.type, storageClass);
                  WriteTypeOrVariableOrConstant(data, b, returnTypeIdentifier);

                  #if SPIRV_BUILDER_TYPE == .String {
                     print_to_builder(b, "; fragment output [%]\n", it_index);
                  }

                  WriteSingleInstruction(
                     b,
                     .Variable,
                     GetSSAId(data, returnTypeIdentifier),
                     GetSSAId(data, identifier),
                     storageClass,
                  );

                  return;
               }
            }

            for data.interfaceVariableIdentifiers {
               if (IdentifierCompare(identifier, it)) {
                  found, variableType := table_find(*data.codeNodeTypes, it.variable.declaration);
                  assert(found);

                  storageClass := GetVariableStorageClass(data, it);
                  pointerTypeIdentifier := GetPointerTypeIdentifier(variableType, storageClass);
                  WriteTypeOrVariableOrConstant(data, b, pointerTypeIdentifier);

                  WriteSingleInstruction(
                     b,
                     .Variable,
                     GetSSAId(data, pointerTypeIdentifier),
                     GetSSAId(data, identifier),
                     storageClass
                  );

                  return;
               }
            }

            for data.rayPayloadVariableIdentifiers {
               if (IdentifierCompare(identifier, it)) {
                  storageClass := SpvStorageClass.RayPayloadKHR;
                  returnTypeIdentifier := GetPointerTypeIdentifier(it.variable.declaration.type, storageClass);
                  WriteTypeOrVariableOrConstant(data, b, returnTypeIdentifier);

                  #if SPIRV_BUILDER_TYPE == .String {
                     print_to_builder(b, "; payload [%]\n", it_index);
                  }

                  WriteSingleInstruction(
                     b,
                     .Variable,
                     GetSSAId(data, returnTypeIdentifier),
                     GetSSAId(data, identifier),
                     storageClass
                  );

                  return;
               }
            }

            // assert(false, "identifier: %. i guess all variables in \"Types, variables and constants\" block is builtin (user cant define a variable that goes in this block, i think)", identifier);
            // print("WARNING    variable: %. skipped!\n", identifier.variable.declaration.*);
            return;
         }

      case .CompositeLiteral; {
         typeIdentifier: Identifier = .{ type = ._Type, _type = identifier.compositeLiteral.type };
         WriteTypeOrVariableOrConstant(data, b, typeIdentifier);

         operands: [..] Any;
         array_add(*operands, GetSSAId(data, typeIdentifier));
         array_add(*operands, GetSSAId(data, identifier));

         for identifier.compositeLiteral.arguments {
            WriteTypeOrVariableOrConstant(data, b, it.*);
            array_add(*operands, ac(GetSSAId(data, it.*)));
         }


         WriteSingleInstruction(
            b,
            .ConstantComposite,
            .. operands
         );
      }

      case .BoolLiteral;
         typeIdentifier: Identifier = .{ type = ._Type, _type = cast(*Type_Info) bool };
         WriteTypeOrVariableOrConstant(data, b, typeIdentifier);

         if (identifier.boolLiteral == true) {
            WriteSingleInstruction(
               b,
               .ConstantTrue,
               GetSSAId(data, typeIdentifier),
               GetSSAId(data, identifier),
            );
         } else {
            WriteSingleInstruction(
               b,
               .ConstantFalse,
               GetSSAId(data, typeIdentifier),
               GetSSAId(data, identifier),
            );
         }

      case .NullConstant;
         typeIdentifier: Identifier = .{ type = ._Type, _type = identifier.nullConstant };
         WriteTypeOrVariableOrConstant(data, b, typeIdentifier);

         WriteSingleInstruction(
            b,
            .ConstantNull,
            GetSSAId(data, typeIdentifier),
            GetSSAId(data, identifier)
         );

      case .ConstantSizeOf;
         intIdentifier: Identifier = .{ type = ._Type, _type = cast(*Type_Info) s32 };
         WriteTypeOrVariableOrConstant(data, b, intIdentifier);

         typeIdentifier: Identifier = .{ type = ._Type, _type = identifier.constantSizeOf };
         WriteTypeOrVariableOrConstant(data, b, typeIdentifier);


         WriteSingleInstruction(
            b,
            .ConstantSizeOfEXT,
            GetSSAId(data, intIdentifier),
            GetSSAId(data, identifier),
            GetSSAId(data, typeIdentifier)
         );
   }
}

// ac: Any copy
ac :: (obj: $T) -> Any #expand {
   copy := New(T);
   copy.* = obj;

   result: Any;
   result.value_pointer = copy;
   result.type = type_info(T);
   return result;
}

// meshData = cast(*MeshData) __push_data__.meshData;
MakeShaderDataPointerAssignmentStatement :: (shaderDataPointerDeclaration: *Code_Declaration, shaderType: ShaderType) -> *Code_Binary_Operator {
   assignment := New(Code_Binary_Operator);
   assignment.operator_type = #char "=";

   assignment.type = cast(*Type_Info) void;

   left := New(Code_Ident);
   left.type = shaderDataPointerDeclaration.type;

   right := New(Code_Cast);
   right.type = shaderDataPointerDeclaration.type;

   assignment.left = left;
   assignment.right = right;

   left.name = shaderDataPointerDeclaration.entry.name;
   left.resolved_declaration = shaderDataPointerDeclaration;

   right.target_type = shaderDataPointerDeclaration.type_inst;

   castedExpressionCode: Code;
   if shaderType == {
      case .Mesh;       castedExpressionCode = code_of(__mesh_push_data__.meshData);
      case .Fragment;   castedExpressionCode = code_of(__mesh_push_data__.fragmentData);
      case .Rgen;       castedExpressionCode = code_of(__rtx_push_data__.rgenData);
      case .Rchit;      castedExpressionCode = code_of(__rtx_push_data__.rchitData);
      case .Rmiss;      castedExpressionCode = code_of(__rtx_push_data__.rmissData);
      case .Compute;    castedExpressionCode = code_of(__compute_push_data__.computeData);
      case; assert(false, "not yet implemented! type: %", shaderType);
   }

   right.expression = compiler_get_nodes(castedExpressionCode);

   // i am being a cheeky bastard here. code_of creates new Code_Nodes. it doesnt refer to the ones that are already created
   // by the compiler during the compilation of this file. and i do variable compare, which is just pointer equality, so
   // pointers must be the same. this is what i "fix". i know i only use the variable declaration so i only fix that.
   // i think a better way to do this would be i think idk. maybe just emit the spirv directly rather than trying to create jai syntax tree.
   //          - apila, 19/09/26
   assert(right.expression.kind == .BINARY_OPERATOR);
   dot := cast(*Code_Binary_Operator) right.expression;
   assert(dot.left.kind == .IDENT);
   ci := cast(*Code_Ident) dot.left;
   if shaderType == {
      case .Mesh; #through;
      case .Fragment;
         ci.resolved_declaration = meshPipelinePushDataVariableIdentifier.variable.declaration;
      case .Rgen; #through;
      case .Rchit; #through;
      case .Rmiss;
         ci.resolved_declaration = rtxPipelinePushDataVariableIdentifier.variable.declaration;
      case .Compute;
         ci.resolved_declaration = computePipelinePushDataVariableIdentifier.variable.declaration;
      case; assert(false, "not yet implemented! type: %", shaderType);
   }

   return assignment;
}

nameof :: ($c: Code, $loc := #caller_location) -> string #expand {
   return #run -> string {
      using _ :: #import "Compiler";
      node := compiler_get_nodes(c);
      assert(node.kind == .IDENT, "Argument to nameof must be identifier", loc=loc);
      return node.(*Code_Ident).name;
   };
}

GetStorageClassFromNote :: (note: string) -> SpvStorageClass {
   if note == {
      case PHYSICAL_STORAGE_BUFFER_QUALIFIER;   return .PhysicalStorageBuffer;
      case FUNCTION_QUALIFIER;                  return .Function;
      case RAY_PAYLOAD_QUALIFIER;               return .RayPayloadKHR;
      case INCOMING_RAY_PAYLOAD_QUALIFIER;      return .IncomingRayPayloadKHR;
   }

   assert(false, "note: %", note);
   return 0;
}

FlattenStorageClasses :: (type: *Type_Info) -> [] SpvStorageClass {
   storageClasses: [..] SpvStorageClass;

   current := type;
   while (current.type == TYPE_INFO_POINTER_TAG) {
      tip := cast(*TypeInfoPointer) current;

      array_add(*storageClasses, tip.storageClass);

      current = tip.pointerTo;
   }

   return storageClasses;
}

// ****int returns int
GetBaseType :: (type: *Type_Info) -> *Type_Info {
   current := type;
   while (current.type == .POINTER) {
      tip := cast(*Type_Info_Pointer) current;
      current = tip.pointer_to;
   }

   return current;
}

GetIndirectionLevelSpirvPointer :: (type: *Type_Info) -> int {
   indirectionLevel := 0;

   current := type;
   while (current.type == TYPE_INFO_POINTER_TAG) {
      tip := cast(*TypeInfoPointer) current;

      indirectionLevel += 1;
      current = tip.pointerTo;
   }

   return indirectionLevel;
}

GetIndirectionLevelJaiPointer :: (type: *Type_Info) -> int {
   indirectionLevel := 0;

   current := type;
   while (current.type == .POINTER) {
      tip := cast(*Type_Info_Pointer) current;

      indirectionLevel += 1;
      current = tip.pointer_to;
   }

   return indirectionLevel;
}

//
// known limitation:
// if an array contains pointers then it wont work. but if you wrap the pointer in a struct and use it that way then it will work
//    - apila, 26/04/26
//
// i realized couple days ago that having pointers to function pointers is not legal in spirv.
// so this whole qualifier nonsense no more. wasted energy. correct approach is to just assume PhysicalStorageBuffer
//          - apila, 09/06/26
//

// structs are not converted since the member notes are sufficient
ConvertJaiTypeIfNecessary :: (type: *Type_Info, notes: [] string) -> *Type_Info {
   assert(type != null);

   if (type.type != .POINTER) {
      return type;
   }

   indirectionLevel := GetIndirectionLevelJaiPointer(type);

   // assertions
   {
      if (notes.count > indirectionLevel) {
         b: String_Builder;

         for notes {
            print_to_builder(*b, "%, ", it);
         }

         print_to_builder(*b, "| indirectionLevel: %, notes.count: %", indirectionLevel, notes.count);
         assert(false, builder_to_string(*b));
      }

      if (notes.count > 0 && notes.count < indirectionLevel) {
         lastStorage := GetStorageClassFromNote(notes[notes.count - 1]);
         assert(lastStorage != .Function);
      }
   }

   newPointers := NewArray(indirectionLevel, TypeInfoPointer);

   current := type;
   for 0..indirectionLevel - 1 {
      assert(current.type == .POINTER, "type: %", current.type);
      tip := cast(*Type_Info_Pointer) current;
      defer current = tip.pointer_to;

      // default is PHYSICAL_STORAGE_BUFFER_QUALIFIER
      note := ifx it < notes.count then notes[it] else PHYSICAL_STORAGE_BUFFER_QUALIFIER;
      storageClass := GetStorageClassFromNote(note);

      newPointers[it].storageClass = storageClass;

      if (it == indirectionLevel - 1) {
         newPointers[indirectionLevel - 1].pointerTo = tip.pointer_to;
      } else {
         newPointers[it].pointerTo = *newPointers[it + 1];
      }
   }

   return *newPointers[0];
}

ConvertJaiTypeIfNecessary :: (type: *Type_Info, declarationNotes: [] *Code_Note) -> *Type_Info {
   notesAsString := NewArray(declarationNotes.count, string);

   for declarationNotes {
      notesAsString[it_index] = it.text;
   }

   return ConvertJaiTypeIfNecessary(type, notesAsString);
}

GetLocationString :: (node: *Code_Node) -> string #expand {
   if (node.location.enclosing_load != null) {
      return sprint("%:%.%-%.%", node.location.enclosing_load.fully_pathed_filename, node.l0, node.c0, node.l1, node.c1);
   } else {
      return sprint("%:%.%-%.%", "no_file", node.l0, node.c0, node.l1, node.c1);
   }
}

// general builder. builder for the whole functions block (the one that comes after "Types, variables and constants")
GenerateFunctions :: (data: *CompilationData, body: *Code_Procedure_Body, b: *BuilderType) {
   EnqueueIfNotVisited :: (item: *Code_Procedure_Header) #expand {
      contains := table_contains(*`visited, item);
      if (contains) return;

      Enqueue(*`frontier, item);
      TableAdd(*`visited, item, .{});
   }

   // entry function is handled seperately because its parameters define the general shader interface
   // so it actually has no parameters. other functions behave more normally
   {
      // entry function is always void?
      header := body.header;
      block := body.block;

      #if SPIRV_BUILDER_TYPE == .String {
         print_to_builder(b, "; main function\n");
      }

      WriteSingleInstruction(
         b,
         .Function,
         GetSSAId(data, .{ type = .Void }),
         GetSSAId(data, .{ type = .Function, function = header }),
         SpvFunctionControlMask.MaskNone,
         GetSSAId(data, .{ type = ._Type, _type = cast(*Type_Info) #type () -> () })
      );

      // idk what to do with the label rn
      WriteSingleInstructionIfReachable(
         b,
         *data.isBlockReachable,
         .Label,
         GetNextSSAId(data)
      );

      //
      // not adding this function type to CompilationData.functions since entry function is handled seperately
      //    - apila, 04/04/26
      //

      functionBuilder: BuilderType;
      data.generalBuilder = b;

      assignment := MakeShaderDataPointerAssignmentStatement(data.shaderDataPointerVariableIdentifier.variable.declaration, data.shaderType);
      DetermineCodeNodeTypes(data, assignment);
      GenerateInstructions(data, assignment, b, *functionBuilder, header);

      GenerateInstructions(data, block, b, *functionBuilder, header);
      AppendAndStealBuffers(b, *functionBuilder);

      WriteSingleInstructionIfReachable(b, *data.isBlockReachable, .Return);
      WriteSingleInstruction(b, .FunctionEnd);
   }

   frontier: Queue(*Code_Procedure_Header);
   visited: Table(*Code_Procedure_Header, struct {});

   found, firstLevelDependencies := table_find(*functionDependencyTable, body.header);
   assert(found);

   for firstLevelDependencies {
      EnqueueIfNotVisited(it);
   }

   while true {
      isDequeued, current := Dequeue(*frontier);
      if (!isDequeued) break;

      header := current;
      assert(current.body_or_null != null);
      block := current.body_or_null.block;

      returnTypeIdentifier := GetReturnTypeIdentifier(xx header.type);
      functionSpirvType := GetFunctionSpirvType(data, header);
      functionTypeIdentifier: Identifier = .{ type = ._Type, _type = functionSpirvType };

      #if SPIRV_BUILDER_TYPE == .String {
         print_to_builder(b, "\n; %\n", header.name);
      }

      WriteSingleInstruction(
         b,
         .Function,
         GetSSAId(data, returnTypeIdentifier),
         GetSSAId(data,  .{ type = .Function, function = header }),
         SpvFunctionControlMask.MaskNone,
         GetSSAId(data, functionTypeIdentifier)
      );

      for header.arguments {
         spirvType := functionSpirvType.argument_types[it_index];
         variableSSAId := GetSSAId(data, .{ type = .Variable, variable.declaration = it });
         WriteSingleInstruction(
            b,
            .FunctionParameter,
            GetSSAId(data, .{ type = ._Type, _type = spirvType }),
            variableSSAId
         );
      }

      WriteSingleInstruction(
         b,
         .Label,
         GetNextSSAId(data)
      );

      // All OpVariable instructions in a function must be in the first block in the function
      // https://registry.khronos.org/SPIR-V/specs/unified1/SPIRV.html#LogicalLayout

      functionBuilder: BuilderType;

      // i need to have this flag per function
      // so i think it should be a parameter to GenerateInstructions rather than being stored in the CompilationData.
      //          - apila, 08/06/26
      data.isBlockReachable = true;
      data.pendingExitVariableSSAId = 0;
      data.generalBuilder = b;
      GenerateInstructions(data, block, b, *functionBuilder, header);
      AppendAndStealBuffers(b, *functionBuilder);

      if (header.returns.count == 0) {
         WriteSingleInstructionIfReachable(b, *data.isBlockReachable, .Return);
      }

      WriteSingleInstruction(b, .FunctionEnd);

      // enqueue next ones
      {
         found, dependeciesOfCurrent := table_find(*functionDependencyTable, current);
         assert(found);

         for dependeciesOfCurrent {
            EnqueueIfNotVisited(it);
         }
      }
   }
}

// i should be using the codeNodeTypes here in this function, in this "for tip.argument_types" block to get the type of "it".
// you know codeNodeTypes shouldnt belong to CompilationData, so when you make it global nd complete seperate pass from the CompileToSpirv
// use it directly here too.
//       - apila, 09/06/26
//
// i just passed the "data" for now Clueless.oO(for now).
//       - apila, 09/06/26
GetFunctionSpirvType :: (data: *CompilationData, header: *Code_Procedure_Header) -> *Type_Info_Procedure {
   assert(header.type.type == .PROCEDURE);
   tip := cast(*Type_Info_Procedure) header.type;

   result := New(Type_Info_Procedure);
   result.runtime_size = tip.runtime_size;
   result.type = tip.type;

   result.argument_types = NewArray(tip.argument_types.count, *Type_Info);
   for header.arguments {
      argumentType := GetNodeType(it);

      if (IsSmallArgument(argumentType)) {
         result.argument_types[it_index] = GetPointerType(argumentType, .Function);
      } else {
         result.argument_types[it_index] = argumentType;
      }
   }

   // the spirv return type: pointers are converted and more than one value is a struct (see GetReturnTypeIdentifier)
   returnTypeIdentifier := GetReturnTypeIdentifier(tip);
   if (returnTypeIdentifier.type != .Void) {
      result.return_types = NewArray(1, *Type_Info);
      result.return_types[0] = returnTypeIdentifier._type;
   }
   result.procedure_flags = tip.procedure_flags;

   return result;
}

GenerateInstructionsData :: struct {
   // i need this mostly for literals. but then i needed it for implicit jai broadcasts. then i also need this for decorationless struct copies and shit.       - apila, 08/06/26
   spirvShouldHaveBeenType:                     *Type_Info;
   isLValue:                                    bool     = false; // maybe i should have two functions GenerateAddress and GenerateExpression instead of single GenerateInstructions function and a lvalue boolean like this. idk man. - apila, 15/04/26
   accessChainBaseArrayElementTypeIfImageHeap:  *TypeInfoImage;
}

// traverse AST and output the generated spirv.
// returns ssaId if the "node" is something that has an id, if not then output is ignored.
// function is to be appended to general.
// the Identifier returned doesnt always make sense if the thing returned doesnt have an identifier. for example result of an addition operation. use ssaId instead
// lValueOut: if additionalData.isLValue is false, the lvalue is returned via this pointer. if additionalData.isLValue is true then it is returned by the function
GenerateInstructions :: (data: *CompilationData, node: *Code_Node, general_: *BuilderType, function: *BuilderType, currentFunction: *Code_Procedure_Header, additionalData: GenerateInstructionsData = .{}, lValueOut: *SSAId = null, spirvType: **Type_Info = null, lValueOutSpirvType: **Type_Info = null, identifierOut: *Identifier = null) -> SSAId {
   general := ifx general_ != null then general_ else data.generalBuilder;
   assert(general != null);

   // i need this because jai does allow upcasting if data is not lost without an explicit cast, but this is not allowed in spirv:
   //    q: u8;
   //    w: s32;
   //    w = q; // this is fine. since all of the values of u8 can fit in s32. but not fine in spirv. in spirv, types has to match
   //
   // and this situation may appear anywhere. in a function call, struct literal, assignment (as above)...
   //                - apila, 06/06/26
   //
   // this return only deals with:
   //    return value of GenerateInstructions.
   //    spirvType out variable.
   // the rest of the out variables, the caller needs to manage.
   //
   // if you pass "ssaIdSpirvType = null", then it means you don't care, and if the caller of GenerateInstructions also doesn't care then it is fine
   // otherwise it is not fine you must care too. this is what the assertion does.
   RETURN :: (ssaId: SSAId, ssaIdSpirvType: *Type_Info) #expand {
      resultSSAId: SSAId;
      resultSpirvType: *Type_Info;

      if (`additionalData.spirvShouldHaveBeenType != null) {
         assert(ssaIdSpirvType != null);
      }

      if (`spirvType != null) {
         assert(ssaIdSpirvType != null);
      }

      if (`additionalData.spirvShouldHaveBeenType != null && !CompareType(`additionalData.spirvShouldHaveBeenType, ssaIdSpirvType)) {
         resultSpirvType = `additionalData.spirvShouldHaveBeenType;
         resultSSAId = ConvertValue(`data, `function, ssaId, ssaIdSpirvType, resultSpirvType, `node);
      } else {
         resultSSAId = ssaId;
         resultSpirvType = ssaIdSpirvType;
      }

      if (`spirvType != null) `spirvType.* = resultSpirvType;
      `return resultSSAId;
   }

   // constant expressions become spirv constants (see EvaluateConstant). the constant is created in the type the caller wants if it is a scalar, so no conversion is needed.
   if (!additionalData.isLValue && (node.kind == .IDENT || node.kind == .UNARY_OPERATOR || node.kind == .BINARY_OPERATOR || node.kind == .CAST || node.kind == .TYPE_QUERY)) {
      value, isConstant := EvaluateConstant(data, node);
      if (isConstant) {
         constantType := additionalData.spirvShouldHaveBeenType;
         identifier, ok := ConstantToIdentifier(value, constantType);
         if (!ok) {
            constantType = GetNodeType(node);
            identifier, ok = ConstantToIdentifier(value, constantType);
         }

         if (ok) {
            if (identifierOut != null) identifierOut.* = identifier;
            RETURN(GetSSAId(data, identifier), constantType);
         }
      }
   }

   //
   // is there a way to trigger jai compiler on some of the code nodes?
   // like for example if there is a #run inside the shader code i want to let jai do the #run and return me the result of it
   // and i will bake that result into the spirv byte code.
   // or #bake what i want from jai is that i want jai to give me the ast of the new function with the baked arguments.
   // are those even possible? idk
   // or polymorphic procedures. is there a way to get the ast of polymorhped procedure?
   // or is there a way to get the result of type_info or is_constant?
   //
   // i think there should be a way to get the values in a metaprogram since they are compile time constants
   // there has to be a point where their values are calculated. the thing is how can i get that value from the compiler
   //
   //             - apila, 02/04/26
   //
   if #complete node.kind == {
      case .UNINITIALIZED;                #through;
      case .CONTEXT;                      #through;
      case .DIRECTIVE_BYTES;              #through;
      case .ASM;                          #through;
      case .DIRECTIVE_BAKE;               #through;
      case .DIRECTIVE_LIBRARY;            #through;
      case .DIRECTIVE_MODIFY;             #through;
      case .EXPRESSION_QUERY;             #through;
      case .PUSH_CONTEXT;                 #through;
      case .DIRECTIVE_PLACE;              #through;
      case .DIRECTIVE_LOCATION;           #through;
      case .DIRECTIVE_MODULE_PARAMETERS;  #through;
      case .DIRECTIVE_SCOPE;              #through;
      case .DIRECTIVE_ADD_CONTEXT;        #through;
      case .DIRECTIVE_CONTEXT_TYPE;
         assert(false, "code node kind: %. not valid.", node.kind);

      case .PROCEDURE_HEADER;          #through;
      case .MAKE_VARARGS;              #through;
      case .DIRECTIVE_THIS;            #through;
      case .DIRECTIVE_LOAD;            #through;
      case .DIRECTIVE_CODE;            #through;
      case .NOTE;                      #through;
      case .DIRECTIVE_COMPILE_TIME;    #through;
      case .PLACEHOLDER;               #through;
      case .DIRECTIVE_WILDCARD;        #through;
      case .RESOLVED_OVERLOAD;
         assert(false, "code node kind: %. idk what to do with this", node.kind);

      case .EXTRACT; {
         ce := cast(*Code_Extract) node;

         // a value of a compound declaration: a, b := F();  or  a, b := x, y;
         if (ce.from != null) {
            if (ce.from.kind == .COMMA_SEPARATED_ARGUMENTS) {
               valueNode := (cast(*Code_Comma_Separated_Arguments) ce.from).arguments[ce.index].node;
               valueSpirvType: *Type_Info;
               valueSSAId := GenerateInstructions(data, valueNode, general, function, currentFunction, .{ spirvShouldHaveBeenType = GetNodeType(node) }, spirvType = *valueSpirvType);
               RETURN(valueSSAId, valueSpirvType);
            }

            assert(ce.from.kind == .PROCEDURE_CALL, "kind: %, loc: %", ce.from.kind, GetLocationString(node));
            found, structSSAId := table_find(*data.multipleReturnValues, cast(*Code_Procedure_Call) ce.from);
            assert(found, "the call is not generated before its values are used. loc: %", GetLocationString(node));

            valueType := GetNodeType(node);
            valueSSAId := EmitCompositeExtract(data, function, .{ type = ._Type, _type = valueType }, structSSAId, .[ce.index]);
            RETURN(valueSSAId, valueType);
         }

         argument := GetMacroExpansionArgument(data, ce.index);
         // An Extract is the compiler's placeholder for a macro argument.
         // Generate the original call argument with its own type first; the
         // expansion site applies its conversion after substitution.
         argumentSpirvType: *Type_Info;
         argumentSSAId := GenerateInstructions(data, argument, general, function, currentFunction, spirvType = *argumentSpirvType);
         assert(argumentSpirvType != null, "macro argument has no SPIR-V type");
         RETURN(argumentSSAId, argumentSpirvType);
      }

      case .DIRECTIVE_RUN;
         assert(false, "do the #run outside the shader procedure to let jai compiler #run it. this compiler doesnt have #run");

      case .DIRECTIVE_POKE_NAME;
         assert(false, "idk what this directive is");

      case .DIRECTIVE_IMPORT;
         return 0; // i think i should skip? idk maybe

      case .TYPE_QUERY;
         // size_of is a constant, it is handled at the start of this function. type_info and initializer_of are not supported (see DetermineCodeNodeTypes)
         assert(false, "unreachable. loc: %", GetLocationString(node));

      //
      // a defer is not generated where it is, it is pushed and its block is generated at every exit of the scope it is in (in reverse order):
      //    - the end of the block (see the .BLOCK case)
      //    - return (all the defers of the function, or of the macro)
      //    - break and continue (the defers inside the loop)
      // in a macro, `defer is for the scope the macro is called from, see GenerateMacroStatement.
      //
      case .DEFER;
         cd := cast(*Code_Defer) node;
         assert(!cd.is_backticked, "`defer is only supported in the top level of a macro (not inside a block in it). loc: %", GetLocationString(node));
         array_add(*data.deferStack, cd);
         return 0;

      // the members are accessed through the expression where they are used (see GetUsingAccess). using x: T; declares x.
      case .USING;
         cu := cast(*Code_Using) node;
         if (cu.expression.kind == .DECLARATION) GenerateInstructions(data, cu.expression, general, function, currentFunction);
         return 0;

      // the compiler gives the code that is inserted. it is not a scope, the declarations in it are in the enclosing scope.
      case .DIRECTIVE_INSERT;
         cdi := cast(*Code_Directive_Insert) node;
         assert(cdi.expansion != null, "the compiler didnt give the expansion of #insert. loc: %", GetLocationString(node));

         // the break and continue in the inserted code are generated as they are, as a break or continue of the loop they are in.
         // a replacement that is something else is not supported. (the expansion has the break, not the replacement)
         IsPlainLoopControl :: (replacement: *Code_Node, controlType: type_of(Code_Loop_Control.control_type)) -> bool {
            if (replacement == null) return true;
            if (replacement.kind != .LOOP_CONTROL) return false;
            clc := cast(*Code_Loop_Control) replacement;
            return clc.control_type == controlType && clc.target_ident == null;
         }
         assert(IsPlainLoopControl(cdi.break_replacement, .BREAK) && IsPlainLoopControl(cdi.continue_replacement, .CONTINUE) && cdi.remove_replacement == null,
                "#insert with break, continue or remove replaced by something other than break or continue is not supported. loc: %", GetLocationString(node));

         if (cdi.expansion.kind == .BLOCK) {
            for (cast(*Code_Block) cdi.expansion).statements  GenerateInstructions(data, it, general, function, currentFunction);
            return 0;
         }

         // an expression
         insertSpirvType: *Type_Info;
         insertSSAId := GenerateInstructions(data, cdi.expansion, general, function, currentFunction, additionalData, lValueOut, *insertSpirvType, lValueOutSpirvType, identifierOut);
         RETURN(insertSSAId, insertSpirvType);

      case .DIRECTIVE_PROCEDURE_NAME;
         assert(false, "read the comment above");

      case .DIRECTIVE_EXISTS;
         assert(false, "read the comment above");

      case .DIRECTIVE_OVERLAY;
         assert(false, "i guess i should never see this. the parsing of structs is done through Type_Info, not through code nodes");

      // a block is a scope, its defers run at its end
      case .BLOCK;
         cb := cast(*Code_Block)node;
         deferBase := data.deferStack.count;

         for cb.statements {
            GenerateInstructions(data, it, general, function, currentFunction);
         }

         GenerateDefers(data, deferBase, general, function, currentFunction);
         data.deferStack.count = deferBase;
         return 0;

      // i think im dumb.
      // i dont need to do any of the int literal bit size additional data thingies.
      // jai already provides it dumbass. Type_Info.runtime_size. for some reason i thought it doesnt work with literals.
      // it does. it even works from int to float. so no need any of the autoCastFromIntToFloat either.
      //    f: f32x4;
      //    f.x = 5;
      //          |
      //         type of this literal is float.
      //
      // so everything works fine. i dont need to do anything except to use data that jai already provides.
      //
      // wrong.
      // this doesnt work with struct literals:
      //    f: f32x4;
      //    f = .{ 1, 2, 3, 4 };
      //
      // all off the 1, 2, 3, 4 gets reported as 64bit integer.
      //
      // yea the above thing is kaputt. what you need to do is:
      // pass the "literal should have been type" and in whatever form jai stored it cast/convert from there to the "literal should have been type"
      // because the form jai reports is not consistent.
      //    - apila, 06/05/26
      case .LITERAL;
         cl := cast(*Code_Literal) node;

         found, type := table_find(*data.codeNodeTypes, node);
         assert(found, "loc: %", GetLocationString(node));

         if cl.value_type == {
            case .NUMBER;
               assert(additionalData.spirvShouldHaveBeenType != null, "loc: %", GetLocationString(node));

               // the values of enums are integer literals of the type of the enum
               type = UnwindEnum(type);
               shouldHaveBeenType := UnwindEnum(additionalData.spirvShouldHaveBeenType);

               // number literals inside untyped struct literals have no type (void). the value is stored as float64 or s64 depending on the flags.
               if (type.type != .INTEGER && type.type != .FLOAT) {
                  type = ifx cl.value_flags & .FLOAT then cast(*Type_Info) float64 else cast(*Type_Info) s64;
               }

               if (type.type == .FLOAT) {
                  // jai doesnt allow casting from float to int so shouldHaveBeenType must also be float
                  assert(shouldHaveBeenType.type == .FLOAT, "type: %, loc: %", shouldHaveBeenType.*, GetLocationString(node));

                  identifier := FloatLiteralIdentifier(cl._float64, shouldHaveBeenType.runtime_size * 8);
                  if (identifierOut != null) identifierOut.* = identifier;
                  RETURN(GetSSAId(data, identifier), shouldHaveBeenType);
               } else if (type.type == .INTEGER) {
                  assert(type.runtime_size == 1 || type.runtime_size == 2 || type.runtime_size == 4 || type.runtime_size == 8, "type.runtime_size: %, not implemented yet!", type.runtime_size);
                  tii := cast(*Type_Info_Integer) type;
                  identifier: Identifier;

                  if (shouldHaveBeenType.type == .INTEGER) {
                     // integer to integer

                     tiiShouldHaveBeen := cast(*Type_Info_Integer) shouldHaveBeenType;
                     BYTE_SIZE :: 8;
                     identifier = .{ type = .IntLiteral, intLiteral = .{ bitSize = shouldHaveBeenType.runtime_size * BYTE_SIZE, unsigned = !tiiShouldHaveBeen.signed } };

                     if (tii.signed) {
                        if (tiiShouldHaveBeen.signed) {
                           // s64 to s64
                           identifier.intLiteral.value._s64 = cl._s64;
                        } else {
                           // s64 to u64
                           identifier.intLiteral.value._u64 = xx cl._s64;
                        }
                     } else {
                        if (tiiShouldHaveBeen.signed) {
                           // u64 to s64
                           identifier.intLiteral.value._s64 = xx cl._u64;
                        } else {
                           // u64 to u64
                           identifier.intLiteral.value._u64 = cl._u64;
                        }
                     }
                  } else if (additionalData.spirvShouldHaveBeenType.type == .FLOAT) {
                     // integer to float

                     value := ifx tii.signed then cast(float64) cl._s64 else cast(float64) cl._u64;
                     identifier = FloatLiteralIdentifier(value, additionalData.spirvShouldHaveBeenType.runtime_size * 8);
                  } else {
                     assert(false, "an integer literal cant be of type %. loc: %", additionalData.spirvShouldHaveBeenType.*, GetLocationString(node));
                  }

                  if (identifierOut != null) identifierOut.* = identifier;
                  RETURN(GetSSAId(data, identifier), additionalData.spirvShouldHaveBeenType);
               } else {
                  assert(false, "type: %, loc: %", type.type, GetLocationString(node));
               }

            // TODO
            // if struct contains pointers and struct literal contains something like null
            // it is not handled and will not work. fix that
            //
            // GetAutoCastAdditionalData prolly needs to take the whole member not just the type of it
            //       - apila, 26/04/26
            case .STRUCT;
               success, type := table_find(*data.codeNodeTypes, node);
               assert(success);
               assert(type.type == .STRUCT, "type: %, loc: %", type.*, GetLocationString(node));

               tis := cast(*Type_Info_Struct) type;
               memberExpressions := GetStructLiteralMemberExpressions(cl, tis);

               isConstant := IsStructLiteralConstant(data, cl);
               if (isConstant) {
                  identifier: Identifier = .{ type = .CompositeLiteral, compositeLiteral = .{ type = type } };
                  identifier.compositeLiteral.arguments = NewArray(memberExpressions.count, *Identifier);

                  for memberExpressions {
                     shouldHaveBeenType := ConvertJaiTypeIfNecessary(GetStructMembers(tis)[it_index].type, GetStructMembers(tis)[it_index].notes);
                     argumentIdentifier: Identifier;

                     if (it == null) {
                        argumentIdentifier = GetDefaultValueIdentifier(data, general, function, currentFunction, shouldHaveBeenType);
                     } else {
                        found, argumentNodeType := table_find(*data.codeNodeTypes, it);
                        assert(found);

                        _ := GenerateInstructions(data, it, general, function, currentFunction, .{ spirvShouldHaveBeenType = shouldHaveBeenType }, identifierOut = *argumentIdentifier);
                        assert(argumentIdentifier.type != .Invalid, "struct: %, index: %, loc: %:%", tis.name, it_index, node.c0, node.l0);
                     }

                     heapCopy := New(Identifier);
                     heapCopy.* = argumentIdentifier;
                     identifier.compositeLiteral.arguments[it_index] = heapCopy;
                  }

                  if (identifierOut != null) identifierOut.* = identifier;
                  RETURN(GetSSAId(data, identifier), type);
               } else {
                  resultSSAId := GetNextSSAId(data);
                  typeIdentifier: Identifier = .{ type = ._Type, _type = type };

                  operands: [..] Any;
                  array_add(*operands, GetSSAId(data, typeIdentifier));
                  array_add(*operands, resultSSAId);

                  for memberExpressions {
                     shouldHaveBeenType := ConvertJaiTypeIfNecessary(GetStructMembers(tis)[it_index].type, GetStructMembers(tis)[it_index].notes);

                     argumentSSAId: SSAId;
                     if (it == null) {
                        argumentSSAId = GetSSAId(data, GetDefaultValueIdentifier(data, general, function, currentFunction, shouldHaveBeenType));
                     } else {
                        found, argumentNodeType := table_find(*data.codeNodeTypes, it);
                        assert(found);

                        argumentSSAId = GenerateInstructions(data, it, general, function, currentFunction, .{ spirvShouldHaveBeenType = shouldHaveBeenType });
                     }

                     array_add(*operands, ac(argumentSSAId));
                  }

                  WriteSingleInstructionIfReachable(
                     function,
                     *data.isBlockReachable,
                     .CompositeConstruct,
                     .. operands
                  );

                  RETURN(resultSSAId, type);
               }

            // s32.[1, 2, 3]. like struct literals it is a constant if all of the elements are constants
            case .ARRAY; {
               arrayType := type;
               if (arrayType.type != .ARRAY && additionalData.spirvShouldHaveBeenType != null) arrayType = GetDecoratedType(additionalData.spirvShouldHaveBeenType);
               assert(arrayType.type == .ARRAY && (cast(*Type_Info_Array) arrayType).array_type == .FIXED, "the type of the array literal is not known. loc: %", GetLocationString(node));

               tia := cast(*Type_Info_Array) arrayType;
               elements := cl.array_literal_info.array_members;
               assert(elements.count == tia.array_count, "loc: %", GetLocationString(node));

               isConstant := true;
               for elements {
                  if (it.kind == .LITERAL && (cast(*Code_Literal) it).value_type == .STRUCT) {
                     if (!IsStructLiteralConstant(data, cast(*Code_Literal) it)) isConstant = false;
                  } else {
                     _, isConstantElement := EvaluateConstant(data, it);
                     if (!isConstantElement) isConstant = false;
                  }
               }

               if (isConstant) {
                  identifier: Identifier = .{ type = .CompositeLiteral, compositeLiteral = .{ type = tia } };
                  identifier.compositeLiteral.arguments = NewArray(elements.count, *Identifier);

                  for elements {
                     element := New(Identifier);
                     _ := GenerateInstructions(data, it, general, function, currentFunction, .{ spirvShouldHaveBeenType = tia.element_type }, identifierOut = element);
                     assert(element.type != .Invalid, "loc: %", GetLocationString(it));
                     identifier.compositeLiteral.arguments[it_index] = element;
                  }

                  if (identifierOut != null) identifierOut.* = identifier;
                  RETURN(GetSSAId(data, identifier), tia);
               }

               resultSSAId := GetNextSSAId(data);
               operands: [..] Any;
               array_add(*operands, GetSSAId(data, .{ type = ._Type, _type = tia }), resultSSAId);
               for elements {
                  elementSSAId := GenerateInstructions(data, it, general, function, currentFunction, .{ spirvShouldHaveBeenType = tia.element_type });
                  array_add(*operands, ac(elementSSAId));
               }

               WriteSingleInstructionIfReachable(function, *data.isBlockReachable, .CompositeConstruct, .. operands);
               RETURN(resultSSAId, tia);
            }

            case .BOOLEAN; {
               identifier: Identifier = .{ type = .BoolLiteral };
               identifier.boolLiteral = cl._u64 != 0;

               if (identifierOut != null) identifierOut.* = identifier;
               RETURN(GetSSAId(data, identifier), type);
            }

            // null. it is the address 0 converted to the pointer type that is wanted.
            case .POINTER; {
               pointerType := type;
               if (additionalData.spirvShouldHaveBeenType != null && additionalData.spirvShouldHaveBeenType.type == TYPE_INFO_POINTER_TAG) pointerType = additionalData.spirvShouldHaveBeenType;
               assert(pointerType.type == TYPE_INFO_POINTER_TAG && (cast(*TypeInfoPointer) pointerType).storageClass == .PhysicalStorageBuffer, "null can only be a PhysicalStorageBuffer pointer. loc: %", GetLocationString(node));

               resultSSAId := GetNextSSAId(data);
               zeroSSAId := GetSSAId(data, .{ type = .IntLiteral, intLiteral = .{ unsigned = true, value._u64 = 0, bitSize = 64 } });
               WriteSingleInstructionIfReachable(function, *data.isBlockReachable, .ConvertUToPtr, GetSSAId(data, .{ type = ._Type, _type = pointerType }), resultSSAId, zeroSSAId);
               RETURN(resultSSAId, pointerType);
            }

            case; assert(false, "cl.value_type: %\n", cl.value_type);
         }

      case .IDENT;
         ci := cast(*Code_Ident) node;

         // a member reached through using
         isUsingAccess, usingAccess := table_find(*data.usingAccesses, ci);
         if (isUsingAccess) {
            accessSpirvType: *Type_Info;
            accessSSAId := GenerateInstructions(data, usingAccess, general, function, currentFunction, additionalData, lValueOut, *accessSpirvType, lValueOutSpirvType, identifierOut);
            RETURN(accessSSAId, accessSpirvType);
         }

         // the it of a for * loop is the address of the element
         isPointerIterator, pointerLoop := table_find(*data.pointerIterators, ci.resolved_declaration);
         if (isPointerIterator) {
            assert(!additionalData.isLValue, "the it of a for * loop cant be assigned. loc: %", GetLocationString(node));
            addressSpirvType: *Type_Info;
            addressSSAId := GenerateInstructions(data, GetForLoopNodes(data, pointerLoop).element, general, function, currentFunction, .{ isLValue = true }, spirvType = *addressSpirvType);
            RETURN(addressSSAId, addressSpirvType);
         }

         // if it is constant global variable like PI then what do i do?
         // i think i should evaluate its value and the identifier type would be either .IntLiteral or .FloatLiteral or .CompositeLiteral or .BoolLiteral.
         // so constant variable doesnt exists at runtime.
         // i guess that would work Clueless.oO(surely thats fine).
         //             - apila, 08/06/26
         declaration := ci.resolved_declaration;
         if (declaration.flags & .IS_CONSTANT) {
            // numbers are handled at the start of this function (see EvaluateConstant). this is for struct literals, which are OpConstantComposite if all of their members are constants,
            // and for constants that this compiler cant evaluate (vector arithmetic for example), their instructions are generated where they are used.
            identifier: Identifier;
            identifierSSAId := GenerateInstructions(data, declaration.expression, general, function, currentFunction, .{ spirvShouldHaveBeenType = declaration.type }, identifierOut = *identifier);

            if (identifierOut != null) identifierOut.* = identifier;
            RETURN(identifierSSAId, declaration.type);
         }

         variableIdentifier := GetVariableIdentifier(ci);
         variableSSAId := GetSSAId(data, variableIdentifier);
         variableName := GetVariableName(variableIdentifier);
         variableStorageClass := GetVariableStorageClass(data, variableIdentifier);

         found, variableType := table_find(*data.codeNodeTypes, node);
         assert(found, "declaration: %, ident: %", GetLocationString(declaration), GetLocationString(ci));

         if (table_contains(*userFunctionArguments, declaration)) {
            if (!IsSmallArgument(variableType)) {
               assert(!additionalData.isLValue, "immutable function parameter cant be lvalue");

               if (identifierOut != null) identifierOut.* = variableIdentifier;
               RETURN(variableSSAId, variableType);
            }
         }

         if (additionalData.isLValue) {
            if (identifierOut != null) identifierOut.* = variableIdentifier;
            RETURN(variableSSAId, GetPointerType(variableType, variableStorageClass));
         }

         variableTypeIdentifier: Identifier = .{ type = ._Type, _type = variableType };
         deferencedSSAId := Load(data, function, variableTypeIdentifier, variableSSAId, variableStorageClass == .PhysicalStorageBuffer);

         if (lValueOutSpirvType != null)  lValueOutSpirvType.* = GetPointerType(variableType, variableStorageClass);
         if (lValueOut != null)           lValueOut.* = variableSSAId;
         RETURN(deferencedSSAId, variableType);

      case .UNARY_OPERATOR;
         cuo := cast(*Code_Unary_Operator) node;
         subexpressionType := GetNodeType(cuo.subexpression);
         cuoType := GetNodeType(cuo);

         resultSSAId := GetNextSSAId(data);
         if cuo.operator_type == {
            case .POINTER_DEREFERENCE; #through;
            case .POSTFIX_DEREFERENCE; {
               assert(subexpressionType.type == TYPE_INFO_POINTER_TAG, "can only derefence a pointer!");

               tip := cast(*TypeInfoPointer) subexpressionType;

               subexpressionSpirvType: *Type_Info;
               subexpressionSSAId := GenerateInstructions(data, cuo.subexpression, general, function, currentFunction, spirvType = *subexpressionSpirvType);
               assert(subexpressionSpirvType != null, "loc: %", GetLocationString(node));

               if (additionalData.isLValue) {
                  RETURN(subexpressionSSAId, subexpressionSpirvType);
               }

               derefencedSSAId := Load(
                  data,
                  function,
                  .{ type = ._Type, _type = cuoType },
                  subexpressionSSAId,
                  tip.storageClass == .PhysicalStorageBuffer,
               );

               if (lValueOutSpirvType != null) lValueOutSpirvType.* = subexpressionSpirvType;
               if (lValueOut != null) lValueOut.* = subexpressionSSAId;
               RETURN(derefencedSSAId, cuoType);
            }

            case #char "*"; {
               assert(!additionalData.isLValue, "cant be lvalue");

               // having a pointer to a pointer thats in Function storage class is illegal in spirv:
               //    a: int;
               //    p := *a;
               // is illegal since the storage class of "a" is Function (assuming it is a local function variable). and i do not verify the usage of this. i probably should tho.
               // man spirv sucks. as far as i know amd instruction set supports flat addressing which eliminates all this worry about storage class bullshit.
               // if hardware can handle it what am i worrying about. we need new spirv extension "Flat Addressing Model". spirv is hiding a capability that hardware natively supports.
               // this issue kinda related: https://github.com/KhronosGroup/Vulkan-Docs/issues/1963
               //
               //       - apila, 29/05/26
               subexpressionLValueSpirvType: *Type_Info;
               subexpressionLValueSSAId := GenerateInstructions(data, cuo.subexpression, general, function, currentFunction, .{ isLValue = true }, spirvType = *subexpressionLValueSpirvType);
               assert(subexpressionLValueSpirvType != null);
               assert(subexpressionLValueSpirvType.type == TYPE_INFO_POINTER_TAG);

               // RayPayloadKHR is allowed because TraceRay takes the address of the payload. it only uses it to know which payload variable to use.
               // Workgroup is allowed for the atomics. (a workgroup pointer cant be stored or passed to a procedure, DoCast checks the storage classes)
               storageClass := subexpressionLValueSpirvType.(*TypeInfoPointer).storageClass;
               assert(storageClass == .PhysicalStorageBuffer || storageClass == .RayPayloadKHR || storageClass == .Workgroup, "taking the address of something in % storage class is not allowed in spirv (for example a local variable). only memory reached through a pointer (PhysicalStorageBuffer) can be addressed. loc: %", storageClass, GetLocationString(node));

               RETURN(subexpressionLValueSSAId, subexpressionLValueSpirvType);
            }

            case #char "-"; {
               subexpressionSSAId := GenerateInstructions(data, cuo.subexpression, general, function, currentFunction);

               info, isNumeric := GetNumericInfo(subexpressionType);

               op: SpvOp;
               #if false {
               } else if (isNumeric && info.kind == .Float) {
                  op = .FNegate;
               } else if (isNumeric && info.kind == .Signed) {
                  op = .SNegate;
               } else {
                  assert(false, "not yet implemented! type: %", subexpressionType.*);
               }

               WriteSingleInstructionIfReachable(
                  function,
                  *data.isBlockReachable,
                  op,
                  GetSSAId(data, .{ type = ._Type, _type = subexpressionType }),
                  resultSSAId,
                  subexpressionSSAId
               );

               RETURN(resultSSAId, subexpressionType);
            }

            // .A, a value of an enum whose type is inferred. the subexpression is the constant.
            case #char "."; {
               valueSpirvType: *Type_Info;
               valueSSAId := GenerateInstructions(data, cuo.subexpression, general, function, currentFunction, .{ spirvShouldHaveBeenType = subexpressionType }, spirvType = *valueSpirvType, identifierOut = identifierOut);
               RETURN(valueSSAId, valueSpirvType);
            }

            case #char "!"; #through;
            case #char "~"; {
               subexpressionSSAId := GenerateInstructions(data, cuo.subexpression, general, function, currentFunction, .{ spirvShouldHaveBeenType = subexpressionType });

               info, isNumeric := GetNumericInfo(subexpressionType);

               op: SpvOp;
               #if false {
               } else if (cuo.operator_type == #char "!" && isNumeric && info.kind == .Bool) {
                  op = .LogicalNot;
               } else if (cuo.operator_type == #char "~" && isNumeric && (info.kind == .Signed || info.kind == .Unsigned)) {
                  op = .Not;
               } else {
                  assert(false, "not yet implemented! operator: %, type: %, loc: %", cuo.operator_type, subexpressionType.*, GetLocationString(node));
               }

               WriteSingleInstructionIfReachable(
                  function,
                  *data.isBlockReachable,
                  op,
                  GetSSAId(data, .{ type = ._Type, _type = subexpressionType }),
                  resultSSAId,
                  subexpressionSSAId
               );

               RETURN(resultSSAId, subexpressionType);
            }

            case; assert(false, "not yet implemented! type: %", cuo.operator_type);
         }

      case .BINARY_OPERATOR;
         cbo := cast(*Code_Binary_Operator) node;

         if cbo.operator_type == {
            case #char "<";            #through;
            case #char ">";            #through;
            case .LESS_OR_EQUAL;       #through;
            case .GREATER_OR_EQUAL;    #through;
            case .IS_EQUAL;            #through;
            case .IS_NOT_EQUAL; {
               found1, rightType := table_find(*data.codeNodeTypes, cbo.right);
               assert(found1);
               found2, leftType := table_find(*data.codeNodeTypes, cbo.left);
               assert(found2);

               // pointers are compared by their addresses
               if (leftType.type == TYPE_INFO_POINTER_TAG && rightType.type == TYPE_INFO_POINTER_TAG) {
                  assert(cbo.operator_type == .IS_EQUAL || cbo.operator_type == .IS_NOT_EQUAL, "pointers can only be compared with == and !=. loc: %", GetLocationString(node));

                  u64TypeSSAId := GetSSAId(data, .{ type = ._Type, _type = cast(*Type_Info) u64 });
                  addresses: [2] SSAId;
                  for operand, operandIndex: (*Code_Node).[cbo.left, cbo.right] {
                     pointerSSAId := GenerateInstructions(data, operand, general, function, currentFunction, .{ spirvShouldHaveBeenType = ifx operandIndex == 0 then leftType else rightType });
                     addresses[operandIndex] = GetNextSSAId(data);
                     WriteSingleInstructionIfReachable(function, *data.isBlockReachable, .ConvertPtrToU, u64TypeSSAId, addresses[operandIndex], pointerSSAId);
                  }

                  boolType := cast(*Type_Info) bool;
                  resultSSAId := GetNextSSAId(data);
                  WriteSingleInstructionIfReachable(function, *data.isBlockReachable, ifx cbo.operator_type == .IS_EQUAL then SpvOp.IEqual else .INotEqual, GetSSAId(data, .{ type = ._Type, _type = boolType }), resultSSAId, addresses[0], addresses[1]);
                  RETURN(resultSSAId, boolType);
               }

               assert(CompareType(leftType, rightType), "not yet implemented! comparing different types. left: %, right: %, loc: %", leftType.*, rightType.*, GetLocationString(node));
               type := leftType;

               resultSSAId := GetNextSSAId(data);

               leftSSAId := GenerateInstructions(data, cbo.left, general, function, currentFunction, .{ spirvShouldHaveBeenType = leftType });
               rightSSAId := GenerateInstructions(data, cbo.right, general, function, currentFunction, .{ spirvShouldHaveBeenType = rightType });

               info, isNumeric := GetNumericInfo(type);
               AssertNotUserOperator(leftType, rightType, cbo);
               assert(isNumeric, "not yet implemented! comparing type: %, loc: %", type.*, GetLocationString(node));

               op := GetComparisonOp(cbo.operator_type, info.kind);
               resultType := GetNumericType(.Bool, 0, info.components);

               WriteSingleInstructionIfReachable(
                  function,
                  *data.isBlockReachable,
                  op,
                  GetSSAId(data, .{ type = ._Type, _type = resultType }),
                  resultSSAId,
                  leftSSAId,
                  rightSSAId
               );

               RETURN(resultSSAId, resultType);
            }

            // jai short circuits && and ||, the right operand is evaluated only if needed. so these cant be a single OpLogicalAnd/OpLogicalOr.
            //    result := left;
            //    if  result  result = right;    // &&
            //    if !result  result = right;    // ||
            case .LOGICAL_AND; #through;
            case .LOGICAL_OR; {
               boolType := cast(*Type_Info) bool;
               boolTypeIdentifier: Identifier = .{ type = ._Type, _type = boolType };

               storageClass := SpvStorageClass.Function;
               resultVariableSSAId := GetNextSSAId(data);
               WriteSingleInstructionIfReachable(
                  general,
                  *data.isBlockReachable,
                  .Variable,
                  GetSSAId(data, .{ type = ._Type, _type = GetPointerType(boolType, storageClass) }),
                  resultVariableSSAId,
                  storageClass
               );

               leftSSAId := GenerateInstructions(data, cbo.left, general, function, currentFunction, .{ spirvShouldHaveBeenType = boolType });
               WriteSingleInstructionIfReachable(function, *data.isBlockReachable, .Store, resultVariableSSAId, leftSSAId);

               rightLabelSSAId := GetNextSSAId(data);
               mergeLabelSSAId := GetNextSSAId(data);

               WriteSingleInstructionIfReachable(function, *data.isBlockReachable, .SelectionMerge, mergeLabelSSAId, SpvSelectionControlMask.MaskNone);
               if (cbo.operator_type == .LOGICAL_AND) {
                  WriteSingleInstructionIfReachable(function, *data.isBlockReachable, .BranchConditional, leftSSAId, rightLabelSSAId, mergeLabelSSAId);
               } else {
                  WriteSingleInstructionIfReachable(function, *data.isBlockReachable, .BranchConditional, leftSSAId, mergeLabelSSAId, rightLabelSSAId);
               }

               WriteSingleInstructionIfReachable(function, *data.isBlockReachable, .Label, rightLabelSSAId);
               rightSSAId := GenerateInstructions(data, cbo.right, general, function, currentFunction, .{ spirvShouldHaveBeenType = boolType });
               WriteSingleInstructionIfReachable(function, *data.isBlockReachable, .Store, resultVariableSSAId, rightSSAId);
               WriteSingleInstructionIfReachable(function, *data.isBlockReachable, .Branch, mergeLabelSSAId);

               WriteSingleInstructionIfReachable(function, *data.isBlockReachable, .Label, mergeLabelSSAId);
               resultSSAId := Load(data, function, boolTypeIdentifier, resultVariableSSAId, false);

               RETURN(resultSSAId, boolType);
            }

            case .ARRAY_SUBSCRIPT;
               DESCRIPTOR_HEAP_BODY :: (elementType: *Type_Info, sourceVariable: Identifier) #expand {
                  assert(`additionalData.isLValue == false, "i am kinda treating this as a intrinsic function call. maybe i should just have idk a function instead of an intrinsic array. idk.");

                  indexSSAId := GenerateInstructions(`data, `cbo.right, `general, `function, `currentFunction, .{ spirvShouldHaveBeenType = type_info(s32) });
                  tira := New(TypeInfoRuntimeArray);
                  tira.elementType = GetDescriptorHeapArrayElementType(elementType);
                  baseTypeIdentifier: Identifier = .{ type = ._Type, _type = tira };
                  heapIdentifier := GetDescriptorHeapIdentifier(`data, sourceVariable);

                  storageClass := SpvStorageClass.UniformConstant;
                  returnTypeIdentifier := GetPointerTypeIdentifier(type_info(void), storageClass);

                  lValueSSAId := GetNextSSAId(`data);

                  WriteSingleInstructionIfReachable(
                     `function,
                     *`data.isBlockReachable,
                     .UntypedAccessChainKHR,
                     GetSSAId(`data, returnTypeIdentifier),
                     lValueSSAId,
                     GetSSAId(`data, baseTypeIdentifier),
                     GetSSAId(`data, heapIdentifier),
                     indexSSAId
                  );

                  dereferencedSSAId := Load(`data, `function, .{ type = ._Type, _type = elementType }, lValueSSAId, false);
                  RETURN(dereferencedSSAId, elementType);
               }

               // checking if the variable is an intrinsic array.
               if (cbo.left.kind == .IDENT) {
                  ci := cast(*Code_Ident) cbo.left;
                  variable := GetVariableIdentifier(ci);
                  if false {
                  } else if (IdentifierCompare(variable, meshVerticesVariableIdentifier)) {
                     // do nothing. DoDotsAndArraySubscripts works for this.
                  } else if (GetMeshPrimitiveIndicesIndex(variable) != -1) {
                     // do nothing. DoDotsAndArraySubscripts works for this.
                  } else if (IdentifierCompare(variable, imageHeapVariableIdentifier)) {
                     assert(additionalData.accessChainBaseArrayElementTypeIfImageHeap != null, "% can only be used as the image argument of a texture or image function (the type of the image is decided by how it is used, so it cant be stored in a variable). loc: %", IMAGE_HEAP_VARIABLE_NAME, GetLocationString(node));
                     DESCRIPTOR_HEAP_BODY(additionalData.accessChainBaseArrayElementTypeIfImageHeap, variable);
                  } else if (IdentifierCompare(variable, tlasHeapVariableIdentifier)) {
                     DESCRIPTOR_HEAP_BODY(type_info(__TLAS__), variable);
                  } else if (IdentifierCompare(variable, samplerHeapVariableIdentifier)) {
                     DESCRIPTOR_HEAP_BODY(type_info(__Sampler__), variable);
                  }
               }

               #through;
            case #char ".";
               // E.A (a value of an enum) or Module.CONSTANT. the right side is the constant.
               if (cbo.operator_type == #char "." && cbo.left.type != null && cbo.left.type.type == .TYPE && cbo.right.kind == .IDENT) {
                  rightDeclaration := (cast(*Code_Ident) cbo.right).resolved_declaration;
                  if (rightDeclaration != null && (rightDeclaration.flags & .IS_CONSTANT)) {
                     valueSpirvType: *Type_Info;
                     valueSSAId := GenerateInstructions(data, cbo.right, general, function, currentFunction, .{ spirvShouldHaveBeenType = GetNodeType(cbo.right) }, spirvType = *valueSpirvType, identifierOut = identifierOut);
                     RETURN(valueSSAId, valueSpirvType);
                  }
               }

               chainSpirvType: *Type_Info;
               chainSSAId := DoDotsAndArraySubscripts(data, function, cbo, currentFunction, additionalData.isLValue, lValueOut, *chainSpirvType, lValueOutSpirvType);
               RETURN(chainSSAId, chainSpirvType);

            case #char "%";         #through;
            case #char "&";         #through;
            case #char "|";         #through;
            case #char "^";         #through;
            case .SHIFT_LEFT;       #through;
            case .SHIFT_RIGHT;      #through;
            case #char "/";         #through;
            case #char "*";         #through;
            case #char "-";         #through;
            case #char "+"; {
               found, leftType := table_find(*data.codeNodeTypes, cbo.left);
               assert(found);
               found2, rightType := table_find(*data.codeNodeTypes, cbo.right);
               assert(found2);

               //
               // in some cases the jai compiler converts the type, sometimes it doesnt.
               // in the following it does report the type of literal as float:
               //    f: f32x4;
               //    f.x = f.y + 4;
               //
               // but in the following it reports as s64:
               //    f: f32x4;
               //    f = .{ -1, -1, 0.5, 1 }
               //
               // so below i say the type of the node itself but i dont think thats always going to turn out to be true.
               // the good thing is that the validator can spot this mistake, so as long as i validate the output im fine.
               // if something doesnt work then i will inspect and fix it, not now.
               //
               //       - apila, 07/05/26
               //

               // not sure about literalShouldHaveBeenTypes here
               AssertNotUserOperator(leftType, rightType, cbo);
               leftType, rightType = GetArithmeticOperandTypes(leftType, rightType, cbo.operator_type);
               leftId := GenerateInstructions(data, cbo.left, general, function, currentFunction, .{ spirvShouldHaveBeenType = leftType });
               rightId := GenerateInstructions(data, cbo.right, general, function, currentFunction, .{ spirvShouldHaveBeenType = rightType });

               binaryArithmeticSpirvType: *Type_Info;
               binaryArithmeticSSAId := DoBinaryArithmetic(data, function, leftType, leftId, rightType, rightId, cbo.operator_type, cbo, spirvType = *binaryArithmeticSpirvType);
               assert(binaryArithmeticSpirvType != null);

               RETURN(binaryArithmeticSSAId, binaryArithmeticSpirvType);
            }

            // c += x;
            // c = c + x;
            case .PLUS_ASSIGN;         #through;
            case .MINUS_ASSIGN;        #through;
            case .TIMES_ASSIGN;        #through;
            case .DIV_ASSIGN;          #through;
            case .MOD_ASSIGN;          #through;
            case .BITWISE_AND_ASSIGN;  #through;
            case .BITWISE_OR_ASSIGN;   #through;
            case .BITWISE_XOR_ASSIGN;  #through;
            case .SHIFT_LEFT_ASSIGN;   #through;
            case .SHIFT_RIGHT_ASSIGN; {
               assert(cbo.left.kind == .IDENT ||
                     (cbo.left.kind == .BINARY_OPERATOR && cbo.left.(*Code_Binary_Operator).operator_type == #char ".") ||
                     (cbo.left.kind == .BINARY_OPERATOR && cbo.left.(*Code_Binary_Operator).operator_type == .ARRAY_SUBSCRIPT) ||
                     (cbo.left.kind == .UNARY_OPERATOR  && cbo.left.(*Code_Unary_Operator).operator_type == .POSTFIX_DEREFERENCE) ||
                     (cbo.left.kind == .UNARY_OPERATOR  && cbo.left.(*Code_Unary_Operator).operator_type == .POINTER_DEREFERENCE),
                     "cbo.left.kind: %", cbo.left.kind
               );

               found, leftType := table_find(*data.codeNodeTypes, cbo.left);
               assert(found);
               found2, rightType := table_find(*data.codeNodeTypes, cbo.right);
               assert(found2);

               operatorType := GetOperatorFromCompoundAssignment(cbo.operator_type);

               // the right side has the type of the left side, except "vector op= scalar" where it is the component type of the vector (it is broadcast)
               _, broadcastRightType := GetArithmeticOperandTypes(leftType, rightType, operatorType);
               rightShouldHaveBeenType := ifx broadcastRightType != rightType then broadcastRightType else leftType;
               rightId := GenerateInstructions(data, cbo.right, general, function, currentFunction, .{ spirvShouldHaveBeenType = rightShouldHaveBeenType });

               leftLValueSSAId: SSAId = U32_MAX;
               leftLValueSpirvType: *Type_Info;
               leftRValueSSAId := GenerateInstructions(data, cbo.left, general, function, currentFunction, lValueOut = *leftLValueSSAId, lValueOutSpirvType = *leftLValueSpirvType);
               assert(leftLValueSSAId != U32_MAX, "lvalue was not set");
               assert(leftLValueSpirvType != null);
               assert(leftLValueSpirvType.type == TYPE_INFO_POINTER_TAG);

               tipLeftLValue := cast(*TypeInfoPointer) leftLValueSpirvType;

               binaryArithmeticSpirvType: *Type_Info;
               binaryArithmeticSSAId := DoBinaryArithmetic(data, function, leftType, leftRValueSSAId, rightShouldHaveBeenType, rightId, operatorType, node, spirvType = *binaryArithmeticSpirvType);
               assert(binaryArithmeticSpirvType != null);

               Store(
                  data,
                  function,
                  leftLValueSSAId,
                  binaryArithmeticSSAId,
                  tipLeftLValue.storageClass == .PhysicalStorageBuffer,
                  binaryArithmeticSpirvType
               );

               RETURN(binaryArithmeticSSAId, null);
            }

            // there is a problem with this. i assume that this is assignment operator. but it is not always one. i mean a little different sometimes.
            // for example consider this:
            //       payload: RgenPayload = .{ visible = true };
            // the right handside should generate a constant struct. it shouldnt emit a OpStore instruction. even if it were to emit OpStore instruction the lvalue calculations below needs to change.
            //             - apila, 09/09/26
            case #char "="; {
               // either a variable or access chain or pointer deference
               assert(cbo.left.kind == .IDENT ||
                     (cbo.left.kind == .BINARY_OPERATOR && cbo.left.(*Code_Binary_Operator).operator_type == #char ".") ||
                     (cbo.left.kind == .BINARY_OPERATOR && cbo.left.(*Code_Binary_Operator).operator_type == .ARRAY_SUBSCRIPT) ||
                     (cbo.left.kind == .UNARY_OPERATOR  && cbo.left.(*Code_Unary_Operator).operator_type == .POSTFIX_DEREFERENCE) ||
                     (cbo.left.kind == .UNARY_OPERATOR  && cbo.left.(*Code_Unary_Operator).operator_type == .POINTER_DEREFERENCE),
                     "cbo.left.kind: %", cbo.left.kind
               );

               found, leftType := table_find(*data.codeNodeTypes, cbo.left);
               assert(found);

               rightId := GenerateInstructions(data, cbo.right, general, function, currentFunction, .{ spirvShouldHaveBeenType = leftType });

               leftIdSpirvType: *Type_Info;
               leftId := GenerateInstructions(data, cbo.left, general, function, currentFunction, .{ isLValue = true }, spirvType = *leftIdSpirvType);
               assert(leftIdSpirvType != null, "loc: %:%", node.l0, node.c0);
               assert(leftIdSpirvType.type == TYPE_INFO_POINTER_TAG);

               tipLeftId := cast(*TypeInfoPointer) leftIdSpirvType;

               Store(
                  data,
                  function,
                  leftId,
                  rightId,
                  tipLeftId.storageClass == .PhysicalStorageBuffer,
                  tipLeftId.pointerTo
               );

               RETURN(rightId, null);
            }

         }
      case .PROCEDURE_BODY;
      case .PROCEDURE_CALL;
         cpc := cast(*Code_Procedure_Call) node;
         procedureExpression := cpc.procedure_expression;
         assert(procedureExpression.kind == .IDENT ||
                procedureExpression.kind == .BINARY_OPERATOR,
                "kind: %", procedureExpression.kind
         );

         header := GetHeaderFromCodeProcedureCall(cpc);

         if (IsMacroProcedure(header)) {
            expansion := cpc.macro_expansion_block;
            assert(expansion != null, "macro call has no expansion: %", header.name);
            array_add(*data.macroExpansionCalls, cpc);
            defer data.macroExpansionCalls.count -= 1;

            returnTypeIdentifier := GetReturnTypeIdentifier(xx header.type);
            returnsValue := returnTypeIdentifier.type != .Void;
            returnType := ifx returnsValue then returnTypeIdentifier._type else null;

            // the expansion is a scope. its defers run when it ends, the `defers when the scope the macro is called from ends.
            array_add(*data.macroDeferBases, data.deferStack.count);
            defer {
               data.deferStack.count = data.macroDeferBases[data.macroDeferBases.count - 1];
               data.macroDeferBases.count -= 1;
            }

            if (!MacroHasEarlyReturn(expansion)) {
               // the only return (if any) is the last statement, so the expansion is just inlined.
               for expansion.statements {
                  if (GenerateMacroStatement(data, it, general, function, currentFunction)) continue;

                  mr := cast(*Code_Return) it;
                  if (!returnsValue) break;

                  // the value is evaluated before the defers run
                  assert(mr.arguments_unsorted.count == 1, "macro return count: %", mr.arguments_unsorted.count);
                  returnSSAId := GenerateInstructions(data, mr.arguments_unsorted[0].expression, general, function, currentFunction, .{ spirvShouldHaveBeenType = returnType });
                  GenerateDefers(data, data.macroDeferBases[data.macroDeferBases.count - 1], general, function, currentFunction);
                  RETURN(returnSSAId, returnType);
               }

               assert(!returnsValue, "macro % must return a value. loc: %", header.name, GetLocationString(node));
               GenerateDefers(data, data.macroDeferBases[data.macroDeferBases.count - 1], general, function, currentFunction);
               RETURN(0, null);
            }

            //
            // the macro returns from inside of something (for example an if). spirv only allows branching out of a construct
            // with break, so the expansion is put in a loop that runs once and return is a break out of it:
            //    result: T;
            //    do {
            //       ...
            //       result = x; break;    // return x;
            //       ...
            //    } while false;
            //    result
            //
            resultVariableType := ifx returnsValue then GetFunctionStorageClassType(returnType) else null;
            resultVariableSSAId: SSAId;
            if (returnsValue) {
               storageClass := SpvStorageClass.Function;
               resultVariableSSAId = GetNextSSAId(data);
               WriteSingleInstructionIfReachable(
                  general,
                  *data.isBlockReachable,
                  .Variable,
                  GetSSAId(data, .{ type = ._Type, _type = GetPointerType(resultVariableType, storageClass) }),
                  resultVariableSSAId,
                  storageClass
               );
            }

            headerLabelSSAId := GetNextSSAId(data);
            bodyLabelSSAId := GetNextSSAId(data);
            continueLabelSSAId := GetNextSSAId(data);
            mergeLabelSSAId := GetNextSSAId(data);

            // break and continue inside the macro body (outside of its own loops) are not for this loop, they skip it. return is the only way to branch to its merge block.
            loopData: LoopData = .{ mergeLabelSSAId = mergeLabelSSAId, continueLabelSSAId = continueLabelSSAId, deferBase = data.deferStack.count, isMacro = true };
            array_add(*data.loopStack, *loopData);

            array_add(*data.macroReturns, .{ resultVariableSSAId = resultVariableSSAId, resultType = resultVariableType, loopIndex = data.loopStack.count - 1 });
            defer data.macroReturns.count -= 1;

            WriteSingleInstructionIfReachable(function, *data.isBlockReachable, .Branch, headerLabelSSAId);
            WriteSingleInstructionIfReachable(function, *data.isBlockReachable, .Label, headerLabelSSAId);
            WriteSingleInstructionIfReachable(function, *data.isBlockReachable, .LoopMerge, mergeLabelSSAId, continueLabelSSAId, SpvLoopControlMask.MaskNone);
            WriteSingleInstructionIfReachable(function, *data.isBlockReachable, .Branch, bodyLabelSSAId);
            WriteSingleInstructionIfReachable(function, *data.isBlockReachable, .Label, bodyLabelSSAId);

            for expansion.statements {
               isReturn := !GenerateMacroStatement(data, it, general, function, currentFunction);
               if (isReturn) GenerateInstructions(data, it, general, function, currentFunction); // see the .RETURN case
            }

            GenerateDefers(data, data.macroDeferBases[data.macroDeferBases.count - 1], general, function, currentFunction);
            WriteSingleInstructionIfReachable(function, *data.isBlockReachable, .Branch, continueLabelSSAId);
            WriteSingleInstructionIfReachable(function, *data.isBlockReachable, .Label, continueLabelSSAId);
            falseSSAId := GetSSAId(data, .{ type = .BoolLiteral, boolLiteral = false });
            WriteSingleInstructionIfReachable(function, *data.isBlockReachable, .BranchConditional, falseSSAId, headerLabelSSAId, mergeLabelSSAId);
            WriteSingleInstructionIfReachable(function, *data.isBlockReachable, .Label, mergeLabelSSAId);
            EndLoop(data, function);

            if (!returnsValue) RETURN(0, null);

            resultSSAId := Load(data, function, .{ type = ._Type, _type = resultVariableType }, resultVariableSSAId, false);
            RETURN(resultSSAId, resultVariableType);
         }

         identifierExpression: *Code_Ident;
         if (procedureExpression.kind == .IDENT) {
            identifierExpression = cast(*Code_Ident) procedureExpression;
         } else if (procedureExpression.kind == .BINARY_OPERATOR) {
            // named module.
            // or possibly it could be a function pointer inside a struct but in spirv function pointers is not allowed.
            // maybe for that reason i should check if the left hand side is a struct.

            cbo := cast(*Code_Binary_Operator) procedureExpression;

            // named module
            if (cbo.left.type.type == .TYPE) {
               assert(cbo.right.kind == .IDENT, "kind: %", cbo.right.kind);

               identifierExpression = xx cbo.right;
            } else {
               assert(false, "type: %", cbo.left.type.type);
            }
         }

         identifierName := identifierExpression.name;
         arguments := cpc.arguments_unsorted;

         //
         // for intrinsic functions i need to get the argument type from the function header, and DetermineCodeNodeTypes only operates on Code_Nodes that are child of the entry point function.
         // the .DECLARATION case of DetermineCodeNodeTypes assumes this (for decorationless copy), so i cant use the same code for operating on Code_Nodes that are outside of the entry point function.
         // this means i cant have weird parameter types to intrinsic functions, which i think is true for all intrinsic functions but i cant gurantee shit. how the type thingy works is very shady but idk.
         // i need more information from compiler to idk. anyways thats why i use the Code_Node type directly of an argument of an intrinsic function, surely will never go wrong Clueless.
         //
         //                            - apila, 08/06/26
         //
         // the above thing about DetermineCodeNodeTypes no longer true. it can be used in any Code_Node (you need to get the context from the metaprogram beforehand tho).
         // so i prolly need to update the code below. surely i will do it in a timely manner Clueless.oO(shirley)
         //
         //                            - apila, 10/06/26
         //
         // sin, cos, clamp, dot, mul... (see MATH_INTRINSICS)
         if (header.notes.count > 0 && header.notes[0].text == INTRINSIC_FUNCTION_NOTE_NAME) {
            mathIntrinsic := GetMathIntrinsic(identifierName);
            if (mathIntrinsic != null) {
               resultSpirvType: *Type_Info;
               resultSSAId := GenerateMathIntrinsic(data, mathIntrinsic, cpc, header, general, function, currentFunction, *resultSpirvType);
               RETURN(resultSSAId, resultSpirvType);
            }
         }

         if identifierName == {
            case SET_MESH_OUTPUTS_NAME; {
               vertexCountExpression := arguments[0].expression;
               primitiveCountExpression := arguments[1].expression;

               // literalShouldHaveBeenType is needed here. meanign that i cant use node.type as literalShouldHaveBeenType. because jai reports literals as s64.
               // it doesnt do the conversion here. in direct assign it does tho.
               //    - apila, 07/05/26
               vertexCountSSAId := GenerateInstructions(data, vertexCountExpression, general, function, currentFunction, .{ spirvShouldHaveBeenType = header.arguments[0].type });
               primitiveCountSSAId := GenerateInstructions(data, primitiveCountExpression, general, function, currentFunction, .{ spirvShouldHaveBeenType = header.arguments[1].type });

               WriteSingleInstructionIfReachable(
                  function,
                  *data.isBlockReachable,
                  .SetMeshOutputsEXT,
                  vertexCountSSAId,
                  primitiveCountSSAId
               );

               return 42000; // doesnt matter since OpSetMeshOutputsEXT doesnt return
            }

            case TEXTURE_FLOAT_2D_FUNCTION_NAME;      #through;
            case TEXTURE_INT_2D_FUNCTION_NAME;        #through;
            case TEXTURE_FLOAT_2D_LOD_FUNCTION_NAME; {
               // the sampled type of the image is the element type of what the function returns. f32x4 -> f32, s32x4 -> s32
               resultType := GetReturnTypeIdentifier(xx header.type)._type;
               sampledType := GetScalarTypeOrVectorElementType(resultType);

               sampledImageType := New(TypeInfoSampledImage);
               sampledImageType.image = New(TypeInfoImage);
               sampledImageType.image.* = .{
                  sampledType       = sampledType,
                  dimensionality    = ._2D,
                  depth             = 0,
                  arrayed           = 0,
                  ms                = 0,
                  sampled           = 1,
                  imageFormat       = .Unknown
               };

               imageSSAId := GenerateInstructions(data, arguments[0].expression, general, function, currentFunction, .{ accessChainBaseArrayElementTypeIfImageHeap = sampledImageType.image });
               samplerSSAId := GenerateInstructions(data, arguments[1].expression, general, function, currentFunction);
               uvSSAId := GenerateInstructions(data, arguments[2].expression, general, function, currentFunction, .{ spirvShouldHaveBeenType = header.arguments[2].type });

               sampledImageSSAId := GetNextSSAId(data);

               WriteSingleInstructionIfReachable(
                  function,
                  *data.isBlockReachable,
                  .SampledImage,
                  GetSSAId(data, .{ type = ._Type, _type = sampledImageType }),
                  sampledImageSSAId,
                  imageSSAId,
                  samplerSSAId
               );

               sampledValueSSAId := GetNextSSAId(data);
               if (identifierName == TEXTURE_FLOAT_2D_FUNCTION_NAME || identifierName == TEXTURE_INT_2D_FUNCTION_NAME) {
                  assert(arguments.count == 3, "arguments.count: %", arguments.count);

                  WriteSingleInstructionIfReachable(
                     function,
                     *data.isBlockReachable,
                     .ImageSampleImplicitLod,
                     GetSSAId(data, .{ type = ._Type, _type = resultType }),
                     sampledValueSSAId,
                     sampledImageSSAId,
                     uvSSAId
                  );
               } else if (identifierName == TEXTURE_FLOAT_2D_LOD_FUNCTION_NAME) {
                  assert(arguments.count == 4, "arguments.count: %", arguments.count);
                  lodSSAId := GenerateInstructions(data, arguments[3].expression, general, function, currentFunction, .{ spirvShouldHaveBeenType = header.arguments[3].type });

                  WriteSingleInstructionIfReachable(
                     function,
                     *data.isBlockReachable,
                     .ImageSampleExplicitLod,
                     GetSSAId(data, .{ type = ._Type, _type = resultType }),
                     sampledValueSSAId,
                     sampledImageSSAId,
                     uvSSAId,
                     SpvImageOperandsMask.LodMask,
                     lodSSAId
                  );
               } else {
                  assert(false, "not yet implemented!");
               }

               RETURN(sampledValueSSAId, resultType);
            }

            case TEXTURE_BIAS_FUNCTION_NAME;    #through;
            case TEXTURE_GRAD_FUNCTION_NAME;    #through;
            case TEXTURE_GATHER_FUNCTION_NAME;  #through;
            case TEXTURE_CMP_FUNCTION_NAME;     #through;
            case TEXTURE_CMP_LOD_FUNCTION_NAME; #through;
            case TEXEL_FETCH_FUNCTION_NAME;     #through;
            case TEXEL_FETCH_INT_FUNCTION_NAME; #through;
            case TEXTURE_SIZE_FUNCTION_NAME;    #through;
            case TEXTURE_LEVELS_FUNCTION_NAME;  #through;
            case IMAGE_READ_FUNCTION_NAME;      #through;
            case IMAGE_SIZE_FUNCTION_NAME; {
               resultSpirvType: *Type_Info;
               resultSSAId := GenerateTextureFunction(data, identifierName, cpc, header, general, function, currentFunction, *resultSpirvType);
               RETURN(resultSSAId, resultSpirvType);
            }

            case IMAGE_WRITE_FUNCTION_NAME; {
               imageNode := arguments[0].expression;

               coordinateNode := arguments[1].expression;
               coordinateType := GetNodeType(header.arguments[1]);

               texelNode := arguments[2].expression;
               texelType := GetNodeType(header.arguments[2]);

               sampledType := GetScalarTypeOrVectorElementType(texelType);

               imageType := New(TypeInfoImage);
               imageType.* = .{
                  sampledType       = sampledType,
                  dimensionality    = ._2D,
                  depth             = 0, // maybe use 2 idk. in texture functions i have seperate overloads for depth i think, but for this idk.    - apila, 11/09/26
                  arrayed           = 0,
                  ms                = 0,
                  sampled           = 2,
                  imageFormat       = .Unknown,
               };

               imageSSAId        := GenerateInstructions(data, imageNode,      general, function, currentFunction, .{ accessChainBaseArrayElementTypeIfImageHeap = imageType });
               coordinateSSAId   := GenerateInstructions(data, coordinateNode, general, function, currentFunction, .{ spirvShouldHaveBeenType = coordinateType });
               texelSSAId        := GenerateInstructions(data, texelNode,      general, function, currentFunction, .{ spirvShouldHaveBeenType = texelType });

               WriteSingleInstructionIfReachable(
                  function,
                  *data.isBlockReachable,
                  .ImageWrite,
                  imageSSAId,
                  coordinateSSAId,
                  texelSSAId
               );

               RETURN(0, null);
            }

            case DISCARD_FUNCTION_NAME; {
               assert(data.shaderType == .Fragment, "% only exists in fragment shaders. loc: %", identifierName, GetLocationString(node));
               data.usesDemote = true;
               WriteSingleInstructionIfReachable(function, *data.isBlockReachable, .DemoteToHelperInvocation);
               RETURN(0, null);
            }

            // OpControlBarrier Workgroup Workgroup AcquireRelease|WorkgroupMemory, like barrier() in glsl
            case BARRIER_FUNCTION_NAME; {
               assert(data.shaderType == .Compute || data.shaderType == .Mesh || data.shaderType == .Task, "% only exists in compute, mesh and task shaders. loc: %", identifierName, GetLocationString(node));

               scopeSSAId := GetSSAId(data, .{ type = .IntLiteral, intLiteral = .{ unsigned = true, value._u64 = xx SpvScope.Workgroup, bitSize = 32 } });
               semantics := SpvMemorySemanticsMask.AcquireReleaseMask | .WorkgroupMemoryMask;
               semanticsSSAId := GetSSAId(data, .{ type = .IntLiteral, intLiteral = .{ unsigned = true, value._u64 = xx semantics, bitSize = 32 } });

               WriteSingleInstructionIfReachable(function, *data.isBlockReachable, .ControlBarrier, scopeSSAId, scopeSSAId, semanticsSSAId);
               RETURN(0, null);
            }

            // the atomics are relaxed. the scope is the device for buffer memory and the workgroup for workgroup variables.
            case ATOMIC_ADD_FUNCTION_NAME;      #through;
            case ATOMIC_MIN_FUNCTION_NAME;      #through;
            case ATOMIC_MAX_FUNCTION_NAME;      #through;
            case ATOMIC_AND_FUNCTION_NAME;      #through;
            case ATOMIC_OR_FUNCTION_NAME;       #through;
            case ATOMIC_XOR_FUNCTION_NAME;      #through;
            case ATOMIC_EXCHANGE_FUNCTION_NAME; #through;
            case ATOMIC_COMPARE_EXCHANGE_FUNCTION_NAME; {
               argumentNodes := cpc.arguments_sorted;

               pointerSpirvType: *Type_Info;
               pointerSSAId := GenerateInstructions(data, argumentNodes[0], general, function, currentFunction, spirvType = *pointerSpirvType);
               assert(pointerSpirvType != null && pointerSpirvType.type == TYPE_INFO_POINTER_TAG, "loc: %", GetLocationString(node));
               tip := cast(*TypeInfoPointer) pointerSpirvType;
               assert(tip.storageClass == .PhysicalStorageBuffer || tip.storageClass == .Workgroup, "atomics are on buffer memory or workgroup variables, not on % memory. loc: %", tip.storageClass, GetLocationString(node));

               valueType := tip.pointerTo;
               info, isNumeric := GetNumericInfo(valueType);
               assert(isNumeric && info.components == 1 && (info.kind == .Signed || info.kind == .Unsigned) && (info.bitSize == 32 || info.bitSize == 64), "type: %, loc: %", TypeName(valueType), GetLocationString(node));
               if (info.bitSize == 64) data.usesInt64Atomics = true;

               scope := ifx tip.storageClass == .Workgroup then SpvScope.Workgroup else SpvScope.Device;
               scopeSSAId := GetSSAId(data, .{ type = .IntLiteral, intLiteral = .{ unsigned = true, value._u64 = xx scope, bitSize = 32 } });
               relaxedSSAId := GetSSAId(data, .{ type = .IntLiteral, intLiteral = .{ unsigned = true, value._u64 = 0, bitSize = 32 } });

               signed := info.kind == .Signed;
               op: SpvOp;
               if identifierName == {
                  case ATOMIC_ADD_FUNCTION_NAME;      op = .AtomicIAdd;
                  case ATOMIC_MIN_FUNCTION_NAME;      op = ifx signed then SpvOp.AtomicSMin else .AtomicUMin;
                  case ATOMIC_MAX_FUNCTION_NAME;      op = ifx signed then SpvOp.AtomicSMax else .AtomicUMax;
                  case ATOMIC_AND_FUNCTION_NAME;      op = .AtomicAnd;
                  case ATOMIC_OR_FUNCTION_NAME;       op = .AtomicOr;
                  case ATOMIC_XOR_FUNCTION_NAME;      op = .AtomicXor;
                  case ATOMIC_EXCHANGE_FUNCTION_NAME; op = .AtomicExchange;
                  case ATOMIC_COMPARE_EXCHANGE_FUNCTION_NAME; op = .AtomicCompareExchange;
               }

               valueTypeSSAId := GetSSAId(data, .{ type = ._Type, _type = valueType });
               resultSSAId := GetNextSSAId(data);

               if (op == .AtomicCompareExchange) {
                  // AtomicCompareExchange(pointer, comparator, value)
                  comparatorSSAId := GenerateInstructions(data, argumentNodes[1], general, function, currentFunction, .{ spirvShouldHaveBeenType = valueType });
                  valueSSAId := GenerateInstructions(data, argumentNodes[2], general, function, currentFunction, .{ spirvShouldHaveBeenType = valueType });
                  WriteSingleInstructionIfReachable(function, *data.isBlockReachable, op, valueTypeSSAId, resultSSAId, pointerSSAId, scopeSSAId, relaxedSSAId, relaxedSSAId, valueSSAId, comparatorSSAId);
               } else {
                  valueSSAId := GenerateInstructions(data, argumentNodes[1], general, function, currentFunction, .{ spirvShouldHaveBeenType = valueType });
                  WriteSingleInstructionIfReachable(function, *data.isBlockReachable, op, valueTypeSSAId, resultSSAId, pointerSSAId, scopeSSAId, relaxedSSAId, valueSSAId);
               }

               RETURN(resultSSAId, valueType);
            }

            case TRACE_RAY_FUNCTION_NAME; {
               // OpTraceRayKHR
               tlasNode := arguments[0].expression;
               tlasType := header.arguments[0].type;
               tlasSSAId := GenerateInstructions(data, tlasNode, general, function, currentFunction, .{ spirvShouldHaveBeenType = tlasType });

               rayFlagsNode := arguments[1].expression;
               rayFlagsType := header.arguments[1].type;
               rayFlagsSSAId := GenerateInstructions(data, rayFlagsNode, general, function, currentFunction, .{ spirvShouldHaveBeenType = rayFlagsType });

               cullMaskNode := arguments[2].expression;
               cullMaskType := header.arguments[2].type;
               cullMaskSSAId := GenerateInstructions(data, cullMaskNode, general, function, currentFunction, .{ spirvShouldHaveBeenType = cullMaskType });

               sbtOffsetNode := arguments[3].expression;
               sbtOffsetType := header.arguments[3].type;
               sbtOffsetSSAId := GenerateInstructions(data, sbtOffsetNode, general, function, currentFunction, .{ spirvShouldHaveBeenType = sbtOffsetType });

               sbtStrideNode := arguments[4].expression;
               sbtStrideType := header.arguments[4].type;
               sbtStrideSSAId := GenerateInstructions(data, sbtStrideNode, general, function, currentFunction, .{ spirvShouldHaveBeenType = sbtStrideType });

               missIndexNode := arguments[5].expression;
               missIndexType := header.arguments[5].type;
               missIndexSSAId := GenerateInstructions(data, missIndexNode, general, function, currentFunction, .{ spirvShouldHaveBeenType = missIndexType });

               rayOriginNode := arguments[6].expression;
               rayOriginType := header.arguments[6].type;
               rayOriginSSAId := GenerateInstructions(data, rayOriginNode, general, function, currentFunction, .{ spirvShouldHaveBeenType = rayOriginType });

               rayTMinNode := arguments[7].expression;
               rayTMinType := header.arguments[7].type;
               rayTMinSSAId := GenerateInstructions(data, rayTMinNode, general, function, currentFunction, .{ spirvShouldHaveBeenType = rayTMinType });

               rayDirectionNode := arguments[8].expression;
               rayDirectionType := header.arguments[8].type;
               rayDirectionSSAId := GenerateInstructions(data, rayDirectionNode, general, function, currentFunction, .{ spirvShouldHaveBeenType = rayDirectionType });

               rayTMaxNode := arguments[9].expression;
               rayTMaxType := header.arguments[9].type;
               rayTMaxSSAId := GenerateInstructions(data, rayTMaxNode, general, function, currentFunction, .{ spirvShouldHaveBeenType = rayTMaxType });

               payloadNode := arguments[10].expression;
               payloadType  := GetNodeType(header.arguments[10]);
               payloadSSAId := GenerateInstructions(data, payloadNode, general, function, currentFunction, .{ spirvShouldHaveBeenType = payloadType });

               WriteSingleInstructionIfReachable(
                  function,
                  *data.isBlockReachable,
                  .TraceRayKHR,
                  tlasSSAId,
                  rayFlagsSSAId,
                  cullMaskSSAId,
                  sbtOffsetSSAId,
                  sbtStrideSSAId,
                  missIndexSSAId,
                  rayOriginSSAId,
                  rayTMinSSAId,
                  rayDirectionSSAId,
                  rayTMaxSSAId,
                  payloadSSAId,
               );

               RETURN(0, null);
            }
         }

         if (header.notes.count > 0) {
            assert(header.notes[0].text != INTRINSIC_FUNCTION_NOTE_NAME, "intrinsic function not yet implemetned! name: %", identifierName);
         }

         // if code reached here then it means this is a user defined function.
         AddFunctionDependency(*functionDependencyTable, currentFunction, header);
         CreateFunctionDependencyEntryIfNotExists(*functionDependencyTable, header);

         found, returnType := table_find(*data.codeNodeTypes, node);
         assert(found);

         returnTypeIdentifier := GetReturnTypeIdentifier(xx header.type);
         resultSSAId := GetNextSSAId(data);

         operands: [..] Any;
         array_add(*operands, GetSSAId(data, returnTypeIdentifier));
         array_add(*operands, resultSSAId);
         array_add(*operands, GetSSAId(data, .{ type = .Function, function = header }));

         // the arguments in the order of the parameters, the compiler puts named arguments in their place and fills in the default values
         assert(cpc.arguments_sorted.count == header.arguments.count, "varargs are not supported. loc: %", GetLocationString(node));
         for argumentNode: cpc.arguments_sorted {
            argumentType := GetNodeType(header.arguments[it_index]);
            argumentSSAId := GenerateInstructions(data, argumentNode, general, function, currentFunction, .{ spirvShouldHaveBeenType = argumentType });

            if (IsSmallArgument(argumentType)) {
               // need to copy

               storageClass := SpvStorageClass.Function;
               spirvType := GetPointerType(argumentType, storageClass);

               parameterVariableSSAId := GetNextSSAId(data);
               WriteSingleInstructionIfReachable(
                  general,
                  *data.isBlockReachable,
                  .Variable,
                  GetSSAId(data, .{ type = ._Type, _type = spirvType }),
                  parameterVariableSSAId,
                  storageClass
               );

               WriteSingleInstructionIfReachable(
                  function,
                  *data.isBlockReachable,
                  .Store,
                  parameterVariableSSAId,
                  argumentSSAId
               );

               argumentSSAId = parameterVariableSSAId;
            }

            array_add(*operands, ac(argumentSSAId));
         }

         WriteSingleInstructionIfReachable(
            function,
            *data.isBlockReachable,
            .FunctionCall,
            .. operands
         );

         if (returnTypeIdentifier.type == .Void) RETURN(resultSSAId, returnType);

         // a procedure with more than one return value returns a struct of them (see GetMultipleReturnType). the values are taken out of it by Code_Extracts.
         // when the call is used as an expression its value is the first value.
         procedureType := cast(*Type_Info_Procedure) header.type;
         if (procedureType.return_types.count > 1) {
            table_set(*data.multipleReturnValues, cpc, resultSSAId);

            firstType := GetMultipleReturnValueType(procedureType, 0);
            firstSSAId := EmitCompositeExtract(data, function, .{ type = ._Type, _type = firstType }, resultSSAId, .[0]);
            RETURN(firstSSAId, firstType);
         }

         RETURN(resultSSAId, returnTypeIdentifier._type);

      case .LOOP_CONTROL;
         clc := cast(*Code_Loop_Control) node;

         if #complete clc.control_type == {
            case .BREAK; #through;
            case .CONTINUE; {
               // the innermost loop, or the loop whose iterator is named (break i;)
               targetIndex := -1;
               for < data.loopStack {
                  if (it.isMacro) continue;
                  if (clc.target_ident == null || it.iteratorDeclaration == clc.target_ident.resolved_declaration) {
                     targetIndex = it_index;
                     break;
                  }
               }
               assert(targetIndex != -1, "% is not inside a loop. loc: %", clc.control_type, GetLocationString(node));

               // the scopes inside the loop are exited
               GenerateDefers(data, data.loopStack[targetIndex].deferBase, general, function, currentFunction);
               GenerateLoopExit(data, targetIndex, clc.control_type == .CONTINUE, general, function);
               return 0;
            }

            case .REMOVE; {
               assert(false, "not yet implemented! please dont use this :)");
            }

            case; assert(false, "not yet implemented! type: %", clc.control_type);
         }

      case .WHILE;
         cw := cast(*Code_While) node;

         found, conditionType := table_find(*data.codeNodeTypes, cw.condition);
         assert(found);

         headerLabelSSAId := GetNextSSAId(data);
         conditionLabelSSAId := GetNextSSAId(data);
         bodyLabelSSAId := GetNextSSAId(data);
         continueLabelSSAId := GetNextSSAId(data);
         mergeLabelSSAId := GetNextSSAId(data);

         // break and continue refer to the innermost loop
         loopData: LoopData = .{
            headerLabelSSAId     = headerLabelSSAId,
            conditionLabelSSAId  = conditionLabelSSAId,
            bodyLabelSSAId       = bodyLabelSSAId,
            continueLabelSSAId   = continueLabelSSAId,
            mergeLabelSSAId      = mergeLabelSSAId,
            deferBase            = data.deferStack.count,
         };
         array_add(*data.loopStack, *loopData);

         WriteSingleInstructionIfReachable(function, *data.isBlockReachable, .Branch, headerLabelSSAId);
         WriteSingleInstructionIfReachable(function, *data.isBlockReachable, .Label, headerLabelSSAId);

         WriteSingleInstructionIfReachable(
            function,
            *data.isBlockReachable,
            .LoopMerge,
            mergeLabelSSAId,
            continueLabelSSAId,
            SpvLoopControlMask.MaskNone
         );

         WriteSingleInstructionIfReachable(function, *data.isBlockReachable, .Branch, conditionLabelSSAId);
         WriteSingleInstructionIfReachable(function, *data.isBlockReachable, .Label, conditionLabelSSAId);

         conditionSSAId := GenerateInstructions(data, cw.condition, general, function, currentFunction, .{ spirvShouldHaveBeenType = conditionType });
         WriteSingleInstructionIfReachable(
            function,
            *data.isBlockReachable,
            .BranchConditional,
            conditionSSAId,
            bodyLabelSSAId,
            mergeLabelSSAId
         );

         WriteSingleInstructionIfReachable(function, *data.isBlockReachable, .Label, bodyLabelSSAId);

         GenerateInstructions(data, cw.block, general, function, currentFunction);
         WriteSingleInstructionIfReachable(function, *data.isBlockReachable, .Branch, continueLabelSSAId);
         WriteSingleInstructionIfReachable(function, *data.isBlockReachable, .Label, continueLabelSSAId);
         WriteSingleInstructionIfReachable(function, *data.isBlockReachable, .Branch, headerLabelSSAId);
         WriteSingleInstructionIfReachable(function, *data.isBlockReachable, .Label, mergeLabelSSAId);
         EndLoop(data, function);

         return 999999;

      case .IF;
         ci := cast(*Code_If) node;

         if (ci.if_flags & .IS_STATIC) {
            // #if doesnt create a scope, so the defers in it are for the enclosing scope
            takenBlock := GetStaticIfTakenBlock(ci);
            if (takenBlock != null) {
               for takenBlock.statements  GenerateInstructions(data, it, general, function, currentFunction);
            }
            return 0;
         }

         if (ci.if_flags & .IS_SWITCH_STATEMENT) {
            GenerateSwitch(data, ci, general, function, currentFunction);
            return 0;
         }

         // only the chosen branch is evaluated:
         //    result: T;
         //    if condition  result = then; else result = else;
         if (ci.if_flags & .IS_IFX) {
            found, resultType := table_find(*data.codeNodeTypes, node);
            assert(found);
            assert(ci.then_block.statements.count == 1 && ci.else_block.statements.count == 1, "loc: %", GetLocationString(node));

            variableType := GetFunctionStorageClassType(resultType);
            storageClass := SpvStorageClass.Function;
            resultVariableSSAId := GetNextSSAId(data);
            WriteSingleInstructionIfReachable(
               general,
               *data.isBlockReachable,
               .Variable,
               GetSSAId(data, .{ type = ._Type, _type = GetPointerType(variableType, storageClass) }),
               resultVariableSSAId,
               storageClass
            );

            conditionSSAId := GenerateInstructions(data, ci.condition, general, function, currentFunction, .{ spirvShouldHaveBeenType = cast(*Type_Info) bool });

            thenLabelSSAId := GetNextSSAId(data);
            elseLabelSSAId := GetNextSSAId(data);
            endLabelSSAId := GetNextSSAId(data);

            WriteSingleInstructionIfReachable(function, *data.isBlockReachable, .SelectionMerge, endLabelSSAId, SpvSelectionControlMask.MaskNone);
            WriteSingleInstructionIfReachable(function, *data.isBlockReachable, .BranchConditional, conditionSSAId, thenLabelSSAId, elseLabelSSAId);

            WriteSingleInstructionIfReachable(function, *data.isBlockReachable, .Label, thenLabelSSAId);
            thenSSAId := GenerateInstructions(data, ci.then_block.statements[0], general, function, currentFunction, .{ spirvShouldHaveBeenType = variableType });
            WriteSingleInstructionIfReachable(function, *data.isBlockReachable, .Store, resultVariableSSAId, thenSSAId);
            WriteSingleInstructionIfReachable(function, *data.isBlockReachable, .Branch, endLabelSSAId);

            WriteSingleInstructionIfReachable(function, *data.isBlockReachable, .Label, elseLabelSSAId);
            elseSSAId := GenerateInstructions(data, ci.else_block.statements[0], general, function, currentFunction, .{ spirvShouldHaveBeenType = variableType });
            WriteSingleInstructionIfReachable(function, *data.isBlockReachable, .Store, resultVariableSSAId, elseSSAId);
            WriteSingleInstructionIfReachable(function, *data.isBlockReachable, .Branch, endLabelSSAId);

            WriteSingleInstructionIfReachable(function, *data.isBlockReachable, .Label, endLabelSSAId);
            resultSSAId := Load(data, function, .{ type = ._Type, _type = variableType }, resultVariableSSAId, false);

            RETURN(resultSSAId, variableType);
         }

         assert(ci.condition != null);
         assert(ci.then_block != null);

         conditionSSAId := GenerateInstructions(data, ci.condition, general, function, currentFunction);

         thenLabelSSAId := GetNextSSAId(data);
         endLabelSSAId := GetNextSSAId(data);
         elseLabelSSAId := ifx ci.else_block == null then endLabelSSAId else GetNextSSAId(data);

         WriteSingleInstructionIfReachable(
            function,
            *data.isBlockReachable,
            .SelectionMerge,
            endLabelSSAId,
            SpvSelectionControlMask.MaskNone
         );

         WriteSingleInstructionIfReachable(
            function,
            *data.isBlockReachable,
            .BranchConditional,
            conditionSSAId,
            thenLabelSSAId,
            elseLabelSSAId
         );

         WriteSingleInstructionIfReachable(
            function,
            *data.isBlockReachable,
            .Label,
            thenLabelSSAId
         );
         GenerateInstructions(data, ci.then_block, general, function, currentFunction);
         WriteSingleInstructionIfReachable(
            function,
            *data.isBlockReachable,
            .Branch,
            endLabelSSAId
         );

         if (ci.else_block != null) {
            WriteSingleInstructionIfReachable(
               function,
               *data.isBlockReachable,
               .Label,
               elseLabelSSAId
            );
            GenerateInstructions(data, ci.else_block, general, function, currentFunction);
            WriteSingleInstructionIfReachable(
               function,
               *data.isBlockReachable,
               .Branch,
               endLabelSSAId
            );
         }

         WriteSingleInstructionIfReachable(
            function,
            *data.isBlockReachable,
            .Label,
            endLabelSSAId
         );

         return 321321; // doesnt matter since if doesnt return. need to update this when i implement ifx.

      case .CASE;

      case .RETURN;
         cr := cast(*Code_Return) node;

         // return from a macro that has an early return. see the macro case of .PROCEDURE_CALL
         if (data.macroReturns.count > 0) {
            macroReturn := data.macroReturns[data.macroReturns.count - 1];

            if (macroReturn.resultVariableSSAId != 0) {
               assert(cr.arguments_unsorted.count == 1, "loc: %", GetLocationString(node));
               valueSSAId := GenerateInstructions(data, cr.arguments_unsorted[0].expression, general, function, currentFunction, .{ spirvShouldHaveBeenType = macroReturn.resultType });
               WriteSingleInstructionIfReachable(function, *data.isBlockReachable, .Store, macroReturn.resultVariableSSAId, valueSSAId);
            }

            // the defers of the macro run after the value is evaluated
            GenerateDefers(data, data.macroDeferBases[data.macroDeferBases.count - 1], general, function, currentFunction);
            GenerateLoopExit(data, macroReturn.loopIndex, false, general, function);
            return 543543;
         }

         if (currentFunction == data.entryFunction) {
            // the return values are evaluated before the defers run
            if data.shaderType == {
               case .Mesh; #through;
               case .Compute; #through;
               case .Rgen; #through;
               case .Rchit; #through;
               case .Rmiss;
                  assert(cr.arguments_unsorted.count == 0, "% shader cant return a value. loc: %", data.shaderType, GetLocationString(node));
                  GenerateDefers(data, 0, general, function, currentFunction);
                  WriteSingleInstructionIfReachable(function, *data.isBlockReachable, .Return);

               case .Fragment;
                  assert(cr.arguments_unsorted.count == data.fragmentOutputIdentifiers.count, "cr.arguments_unsorted.count: %, data.fragmentOutputIdentifiers.count: %", cr.arguments_unsorted.count, data.fragmentOutputIdentifiers.count);

                  for cr.arguments_unsorted {
                     ssaId := GenerateInstructions(data, it.expression, general, function, currentFunction);
                     WriteSingleInstructionIfReachable(
                        function,
                        *data.isBlockReachable,
                        .Store,
                        GetSSAId(data, data.fragmentOutputIdentifiers[it_index]),
                        ssaId
                     );
                  }

                  GenerateDefers(data, 0, general, function, currentFunction);
                  WriteSingleInstructionIfReachable(function, *data.isBlockReachable, .Return);

               case; assert(false, "not yet implemented! type: %", data.shaderType);
            }
         } else {
            returnTypeIdentifier := GetReturnTypeIdentifier(xx currentFunction.type);

            // related to the comment in GetReturnTypeIdentifier
            // assert(returnTypeIdentifier.type == ._Type);

            // if (CompareType(returnTypeIdentifier._type, cast(*Type_Info) void)) {
            if (returnTypeIdentifier.type == .Void) {
               GenerateDefers(data, 0, general, function, currentFunction);
               WriteSingleInstructionIfReachable(function, *data.isBlockReachable, .Return);
            } else if ((cast(*Type_Info_Procedure) currentFunction.type).return_types.count > 1) {
               // the values are put in a struct, see GetMultipleReturnType
               procedureType := cast(*Type_Info_Procedure) currentFunction.type;
               assert(cr.arguments_sorted.count == procedureType.return_types.count, "count: %, loc: %", cr.arguments_sorted.count, GetLocationString(node));

               resultSSAId := GetNextSSAId(data);
               operands: [..] Any;
               array_add(*operands, GetSSAId(data, returnTypeIdentifier), resultSSAId);

               for cr.arguments_sorted {
                  valueSSAId := GenerateInstructions(data, it, general, function, currentFunction, .{ spirvShouldHaveBeenType = GetMultipleReturnValueType(procedureType, it_index) });
                  array_add(*operands, ac(valueSSAId));
               }

               WriteSingleInstructionIfReachable(function, *data.isBlockReachable, .CompositeConstruct, .. operands);
               GenerateDefers(data, 0, general, function, currentFunction);
               WriteSingleInstructionIfReachable(function, *data.isBlockReachable, .ReturnValue, resultSSAId);
            } else {
               assert(cr.arguments_unsorted.count == 1, "count: %", cr.arguments_unsorted.count);

               returnArgumentNode := cr.arguments_unsorted[0].expression;
               returnType := returnTypeIdentifier._type;

               // the value is evaluated before the defers run
               returnArgumentSSAId := GenerateInstructions(data, returnArgumentNode, general, function, currentFunction, .{ spirvShouldHaveBeenType = returnType });
               GenerateDefers(data, 0, general, function, currentFunction);
               WriteSingleInstructionIfReachable(function, *data.isBlockReachable, .ReturnValue, returnArgumentSSAId);
            }
         }

         return 543543; // return doesnt return any ssa id

      //
      // ranges (inclusive):
      //    it := start;            (end for "for <")
      //    while it <= end {       (it >= start for "for <")
      //       ...
      //       continue:  it += 1;     (it -= 1 for "for <")
      //    }
      //
      // arrays:
      //    it_index := 0;          (count - 1 for "for <")
      //    while it_index < count {    (it_index >= 0 for "for <")
      //       it := array[it_index];
      //       ...
      //       continue:  it_index += 1;     (it_index -= 1 for "for <")
      //    }
      //
      case .FOR;
         cf := cast(*Code_For) node;

         // a for_expansion, a macro
         if (cf.macro_expansion_procedure_call != null) {
            GenerateInstructions(data, cf.macro_expansion_procedure_call, general, function, currentFunction);
            return 0;
         }

         nodes := GetForLoopNodes(data, cf);
         isRange := cf.iteration_expression_right != null;
         reverse := (cf.for_flags & .REVERSE) != 0;

         itType := GetNodeType(cf.ident_decl);
         isPointerLoop := (cf.for_flags & .POINTER) != 0;
         itSSAId: SSAId;
         if (!isPointerLoop) itSSAId = GenerateInstructions(data, cf.ident_decl, general, function, currentFunction);
         boolTypeSSAId := GetSSAId(data, .{ type = ._Type, _type = cast(*Type_Info) bool });

         // only for arrays
         indexType: *Type_Info;
         indexSSAId, indexOne, indexZero, indexTypeSSAId: SSAId;
         indexInfo: NumericInfo;
         if (!isRange) {
            indexType = GetNodeType(nodes.indexDeclaration);
            indexSSAId = GenerateInstructions(data, nodes.indexDeclaration, general, function, currentFunction);

            indexIsNumeric: bool;
            indexInfo, indexIsNumeric = GetNumericInfo(indexType);
            assert(indexIsNumeric && (indexInfo.kind == .Signed || indexInfo.kind == .Unsigned), "type: %, loc: %", indexType.*, GetLocationString(node));
            indexOne = GetSSAId(data, .{ type = .IntLiteral, intLiteral = .{ unsigned = indexInfo.kind == .Unsigned, value._s64 = 1, bitSize = indexInfo.bitSize } });
            indexZero = GetSSAId(data, .{ type = .IntLiteral, intLiteral = .{ unsigned = indexInfo.kind == .Unsigned, value._s64 = 0, bitSize = indexInfo.bitSize } });
            indexTypeSSAId = GetSSAId(data, .{ type = ._Type, _type = indexType });
         }

         // range bounds (or the count of the array) are evaluated once, before the loop.
         startSSAId, endSSAId, countSSAId: SSAId;
         itInfo: NumericInfo;
         if (isRange) {
            itIsNumeric: bool;
            itInfo, itIsNumeric = GetNumericInfo(itType);
            assert(itIsNumeric && (itInfo.kind == .Signed || itInfo.kind == .Unsigned), "range must be of integers. type: %, loc: %", itType.*, GetLocationString(node));

            startSSAId = GenerateInstructions(data, cf.iteration_expression, general, function, currentFunction, .{ spirvShouldHaveBeenType = itType });
            endSSAId = GenerateInstructions(data, cf.iteration_expression_right, general, function, currentFunction, .{ spirvShouldHaveBeenType = itType });

            WriteSingleInstructionIfReachable(function, *data.isBlockReachable, .Store, itSSAId, ifx reverse then endSSAId else startSSAId);
         } else {
            tia := cast(*Type_Info_Array) GetNodeType(cf.iteration_expression);
            if (tia.array_type == .FIXED) {
               countSSAId = GetSSAId(data, .{ type = .IntLiteral, intLiteral = .{ unsigned = indexInfo.kind == .Unsigned, value._s64 = tia.array_count, bitSize = indexInfo.bitSize } });
            } else {
               countSSAId = GenerateInstructions(data, nodes.count, general, function, currentFunction, .{ spirvShouldHaveBeenType = indexType });
            }

            if (reverse) {
               lastSSAId := GetNextSSAId(data);
               WriteSingleInstructionIfReachable(function, *data.isBlockReachable, .ISub, indexTypeSSAId, lastSSAId, countSSAId, indexOne);
               WriteSingleInstructionIfReachable(function, *data.isBlockReachable, .Store, indexSSAId, lastSSAId);
            } else {
               WriteSingleInstructionIfReachable(function, *data.isBlockReachable, .Store, indexSSAId, indexZero);
            }
         }

         headerLabelSSAId := GetNextSSAId(data);
         conditionLabelSSAId := GetNextSSAId(data);
         bodyLabelSSAId := GetNextSSAId(data);
         continueLabelSSAId := GetNextSSAId(data);
         mergeLabelSSAId := GetNextSSAId(data);

         loopData: LoopData = .{
            headerLabelSSAId     = headerLabelSSAId,
            conditionLabelSSAId  = conditionLabelSSAId,
            bodyLabelSSAId       = bodyLabelSSAId,
            continueLabelSSAId   = continueLabelSSAId,
            mergeLabelSSAId      = mergeLabelSSAId,
            deferBase            = data.deferStack.count,
            iteratorDeclaration  = cf.ident_decl,
         };
         array_add(*data.loopStack, *loopData);

         WriteSingleInstructionIfReachable(function, *data.isBlockReachable, .Branch, headerLabelSSAId);
         WriteSingleInstructionIfReachable(function, *data.isBlockReachable, .Label, headerLabelSSAId);
         WriteSingleInstructionIfReachable(function, *data.isBlockReachable, .LoopMerge, mergeLabelSSAId, continueLabelSSAId, SpvLoopControlMask.MaskNone);
         WriteSingleInstructionIfReachable(function, *data.isBlockReachable, .Branch, conditionLabelSSAId);

         // condition
         WriteSingleInstructionIfReachable(function, *data.isBlockReachable, .Label, conditionLabelSSAId);
         conditionSSAId := GetNextSSAId(data);
         if (isRange) {
            itValueSSAId := Load(data, function, .{ type = ._Type, _type = itType }, itSSAId, false);
            if (reverse) {
               WriteSingleInstructionIfReachable(function, *data.isBlockReachable, GetComparisonOp(.GREATER_OR_EQUAL, itInfo.kind), boolTypeSSAId, conditionSSAId, itValueSSAId, startSSAId);
            } else {
               WriteSingleInstructionIfReachable(function, *data.isBlockReachable, GetComparisonOp(.LESS_OR_EQUAL, itInfo.kind), boolTypeSSAId, conditionSSAId, itValueSSAId, endSSAId);
            }
         } else {
            indexValueSSAId := Load(data, function, .{ type = ._Type, _type = indexType }, indexSSAId, false);
            if (reverse) {
               WriteSingleInstructionIfReachable(function, *data.isBlockReachable, GetComparisonOp(.GREATER_OR_EQUAL, indexInfo.kind), boolTypeSSAId, conditionSSAId, indexValueSSAId, indexZero);
            } else {
               WriteSingleInstructionIfReachable(function, *data.isBlockReachable, GetComparisonOp(#char "<", indexInfo.kind), boolTypeSSAId, conditionSSAId, indexValueSSAId, countSSAId);
            }
         }
         WriteSingleInstructionIfReachable(function, *data.isBlockReachable, .BranchConditional, conditionSSAId, bodyLabelSSAId, mergeLabelSSAId);

         // body
         WriteSingleInstructionIfReachable(function, *data.isBlockReachable, .Label, bodyLabelSSAId);
         if (!isRange && !isPointerLoop) {
            elementSSAId := GenerateInstructions(data, nodes.element, general, function, currentFunction, .{ spirvShouldHaveBeenType = itType });
            WriteSingleInstructionIfReachable(function, *data.isBlockReachable, .Store, itSSAId, elementSSAId);
         }
         GenerateInstructions(data, cf.block, general, function, currentFunction);
         WriteSingleInstructionIfReachable(function, *data.isBlockReachable, .Branch, continueLabelSSAId);

         // continue
         WriteSingleInstructionIfReachable(function, *data.isBlockReachable, .Label, continueLabelSSAId);
         {
            step := ifx reverse then SpvOp.ISub else SpvOp.IAdd;

            if (!isRange) {
               indexValueSSAId := Load(data, function, .{ type = ._Type, _type = indexType }, indexSSAId, false);
               nextIndexSSAId := GetNextSSAId(data);
               WriteSingleInstructionIfReachable(function, *data.isBlockReachable, step, indexTypeSSAId, nextIndexSSAId, indexValueSSAId, indexOne);
               WriteSingleInstructionIfReachable(function, *data.isBlockReachable, .Store, indexSSAId, nextIndexSSAId);
            } else {
               itOne := GetSSAId(data, .{ type = .IntLiteral, intLiteral = .{ unsigned = itInfo.kind == .Unsigned, value._s64 = 1, bitSize = itInfo.bitSize } });
               itValueSSAId := Load(data, function, .{ type = ._Type, _type = itType }, itSSAId, false);
               nextItSSAId := GetNextSSAId(data);
               WriteSingleInstructionIfReachable(function, *data.isBlockReachable, step, GetSSAId(data, .{ type = ._Type, _type = itType }), nextItSSAId, itValueSSAId, itOne);
               WriteSingleInstructionIfReachable(function, *data.isBlockReachable, .Store, itSSAId, nextItSSAId);
            }
         }
         WriteSingleInstructionIfReachable(function, *data.isBlockReachable, .Branch, headerLabelSSAId);

         WriteSingleInstructionIfReachable(function, *data.isBlockReachable, .Label, mergeLabelSSAId);
         EndLoop(data, function);
         return 0;

      case .TYPE_DEFINITION;
      case .TYPE_INSTANTIATION;
      case .ENUM;
      case .STRUCT;
      case .COMMA_SEPARATED_ARGUMENTS;
      case .DECLARATION;
         cd := cast(*Code_Declaration) node;

         // a local constant (X :: 5, or a macro parameter whose argument is constant) doesnt need a variable.
         // identifiers that refer to it use its value directly. see the .IDENT case
         if (cd.flags & .IS_CONSTANT) return 0;

         variableIdentifier: Identifier = .{ type = .Variable, variable.declaration = cd };
         variableSSAId := GetSSAId(data, variableIdentifier);

         isPayload := IsPayloadVariable(cd);
         isIncomingPayload := IsIncomingPayloadVariable(cd);
         isWorkgroup := IsWorkgroupVariable(cd);

         found, variableType := table_find(*data.codeNodeTypes, node);
         assert(found);

         storageClass := GetVariableStorageClass(data, variableIdentifier);
         variableTypeIdentifier: Identifier = .{ type = ._Type, _type = variableType };
         pointerTypeIdentifier := GetPointerTypeIdentifier(variableType, storageClass);

         // the value is stored where the declaration is, not given as the initializer of OpVariable.
         // the initializer is applied once when the function starts but a declaration inside a loop must be initialized in every iteration.
         if (cd.expression != null) {
            found, expressionType := table_find(*data.codeNodeTypes, cd.expression);
            assert(found);

            // in the declaration apperantly i dont need to explicitly say the literalShouldHaveBeenType because jai does convert in this case.
            // but since i cant rely on it because it looks unstable and unfinished im gonna pass the literalShouldHaveBeenType
            //    - apila, 07/05/26
            expressionSSAId := GenerateInstructions(data, cd.expression, general, function, currentFunction, .{ spirvShouldHaveBeenType = variableType });

            // if you just declared something you cant be storing into PhysicalStorageBuffer therefore i dont need to use the dedicated Store function
            WriteSingleInstructionIfReachable(function, *data.isBlockReachable, .Store, variableSSAId, expressionSSAId);
         } else if (!(cd.flags & .IS_UNINITIALIZED) && !isIncomingPayload && !isWorkgroup) {
            // like jai, a declaration without a value gets the default values of the struct, or zero.
            // (IS_UNINITIALIZED is "---" and also the iterators of for loops. the incoming payload is the input of the shader.
            // a workgroup variable is shared by all the invocations of the workgroup, they would all initialize it.)
            defaultSSAId := GenerateDefaultValue(data, general, function, currentFunction, variableType);
            WriteSingleInstructionIfReachable(function, *data.isBlockReachable, .Store, variableSSAId, defaultSSAId);
         }

         // a declaration can be generated more than once (if it is in a deferred block), it is declared once
         if (table_contains(*data.declaredVariables, cd)) {
         } else if (isPayload) {
            // this variable gets written to "Types, variables and constants" section.
            array_add(*data.rayPayloadVariableIdentifiers, variableIdentifier);
            TableAdd(*data.declaredVariables, cd, .{});
         } else if (isIncomingPayload) {
            // this variable gets written to "Types, variables and constants" section.
            assert(data.incomingRayPayloadVariableIdentifier.type == .Invalid, "only one payloadin variable is allowed");
            data.incomingRayPayloadVariableIdentifier = variableIdentifier;
            TableAdd(*data.declaredVariables, cd, .{});
         } else if (isWorkgroup) {
            // a global variable, it gets written to "Types, variables and constants" section.
            array_add(*data.interfaceVariableIdentifiers, variableIdentifier);
            TableAdd(*data.declaredVariables, cd, .{});
         } else if (data.isBlockReachable) {
            TableAdd(*data.declaredVariables, cd, .{});

            // cant be untyped (VUID-StandaloneSpirv-OpTypeUntypedPointerKHR-11417)
            operands: [..] Any;
            array_add(*operands, GetSSAId(data, pointerTypeIdentifier));
            array_add(*operands, variableSSAId);
            array_add(*operands, storageClass);

            #if SPIRV_BUILDER_TYPE == .String {
               print_to_builder(general, "; %\n", GetVariableName(variableIdentifier));
            }

            WriteSingleInstructionIfReachable(
               general,
               *data.isBlockReachable,
               .Variable,
               .. operands
            );
         }

         if (identifierOut != null) identifierOut.* = variableIdentifier;
         RETURN(variableSSAId, pointerTypeIdentifier._type);
      case .CAST;
         cc := cast(*Code_Cast) node;

         // cast(T) *x is x. see IsCastOfAddressToPointee
         if (IsCastOfAddressToPointee(cc)) {
            valueSpirvType: *Type_Info;
            valueSSAId := GenerateInstructions(data, (cast(*Code_Unary_Operator) cc.expression).subexpression, general, function, currentFunction, additionalData, lValueOut, *valueSpirvType, lValueOutSpirvType, identifierOut);
            RETURN(valueSSAId, valueSpirvType);
         }

         found, castTo := table_find(*data.codeNodeTypes, node);
         assert(found);
         found2, castFrom := table_find(*data.codeNodeTypes, cc.expression);
         assert(found2);

         expressionSSAId := GenerateInstructions(data, cc.expression, general, function, currentFunction);

         resultSpirvType: *Type_Info;
         resultSSAId := DoCast(data, function, castTo, castFrom, expressionSSAId, node, spirvType = *resultSpirvType);
         assert(resultSpirvType != null);

         RETURN(resultSSAId, resultSpirvType);

      case .DIRECTIVE_THROUGH;

      //
      //    a, b := F();      the call is generated, then the declarations. their values are Code_Extracts of the call (see the .EXTRACT case)
      //    a, b := x, y;     the declarations, their values are Code_Extracts of x, y
      //    a, b = b, a;      all the values are generated before they are stored
      //
      case .COMPOUND_DECLARATION;
         ccd := cast(*Code_Compound_Declaration) node;
         source := ccd.declaration_properties.expression;
         targets := ccd.comma_separated_assignment.arguments;

         if (ccd.operator_type == 0) {
            if (source != null && source.kind == .PROCEDURE_CALL) GenerateInstructions(data, source, general, function, currentFunction);

            for targets {
               assert(it.node.kind == .IDENT, "kind: %, loc: %", it.node.kind, GetLocationString(it.node));
               GenerateInstructions(data, (cast(*Code_Ident) it.node).resolved_declaration, general, function, currentFunction);
            }

            return 0;
         }

         assert(ccd.operator_type == #char "=", "% on more than one value is not supported. loc: %", ccd.operator_type, GetLocationString(node));
         assert(source != null);

         values := NewArray(targets.count, SSAId,, temp);
         valueTypes := NewArray(targets.count, *Type_Info,, temp);

         if (source.kind == .PROCEDURE_CALL) {
            header := GetHeaderFromCodeProcedureCall(cast(*Code_Procedure_Call) source);
            procedureType := cast(*Type_Info_Procedure) header.type;
            assert(procedureType.return_types.count >= targets.count, "loc: %", GetLocationString(node));

            GenerateInstructions(data, source, general, function, currentFunction);
            found, structSSAId := table_find(*data.multipleReturnValues, cast(*Code_Procedure_Call) source);
            assert(found);

            for targets {
               valueTypes[it_index] = GetMultipleReturnValueType(procedureType, it_index);
               values[it_index] = EmitCompositeExtract(data, function, .{ type = ._Type, _type = valueTypes[it_index] }, structSSAId, .[it_index]);
            }
         } else {
            assert(source.kind == .COMMA_SEPARATED_ARGUMENTS, "kind: %, loc: %", source.kind, GetLocationString(source));
            csa := cast(*Code_Comma_Separated_Arguments) source;
            assert(csa.arguments.count == targets.count, "loc: %", GetLocationString(node));

            for csa.arguments {
               values[it_index] = GenerateInstructions(data, it.node, general, function, currentFunction, .{ spirvShouldHaveBeenType = GetNodeType(targets[it_index].node) }, spirvType = *valueTypes[it_index]);
            }
         }

         for targets {
            targetSpirvType: *Type_Info;
            targetSSAId := GenerateInstructions(data, it.node, general, function, currentFunction, .{ isLValue = true }, spirvType = *targetSpirvType);
            assert(targetSpirvType != null && targetSpirvType.type == TYPE_INFO_POINTER_TAG, "loc: %", GetLocationString(it.node));
            tip := cast(*TypeInfoPointer) targetSpirvType;

            valueSSAId := ConvertValue(data, function, values[it_index], valueTypes[it_index], tip.pointerTo, it.node);
            Store(data, function, targetSSAId, valueSSAId, tip.storageClass == .PhysicalStorageBuffer, tip.pointerTo);
         }

         return 0;
   }

   assert(false, "didnt return!, node.kind: %, loc: %", node.kind, node.location);
   return 696969;
}

IsPayloadVariable :: (cd: *Code_Declaration) -> bool {
   return cd.notes.count == 1 && cd.notes[0].text == RAY_PAYLOAD_QUALIFIER;
}

IsIncomingPayloadVariable :: (cd: *Code_Declaration) -> bool {
   return cd.notes.count == 1 && cd.notes[0].text == INCOMING_RAY_PAYLOAD_QUALIFIER;
}

IsWorkgroupVariable :: (cd: *Code_Declaration) -> bool {
   return cd.notes.count == 1 && cd.notes[0].text == WORKGROUP_QUALIFIER;
}

GetNodeType :: (node: *Code_Node) -> *Type_Info #expand {
   found, type := table_find(*`data.codeNodeTypes, node);
   assert(found, "loc: %", GetLocationString(node));

   return type;
}

Signedness :: enum {
   Unsigned;
   Signed;
}

//
// following functions would be trivial if vectors were not to be structs. thats so dumb but i dont have anything better. kayu
//       - apila, 06/06/26
//

// index into MESH_PRIMITIVE_INDICES, -1 if the variable is not one of them
GetMeshPrimitiveIndicesIndex :: (variable: Identifier) -> int {
   for meshPrimitiveIndicesIdentifiers  if (IdentifierCompare(it, variable)) return it_index;
   return -1;
}

// index into BUILTIN_VARIABLES, -1 if the variable is not one of them
GetBuiltinVariableIndex :: (variable: Identifier) -> int {
   for builtinVariableIdentifiers  if (IdentifierCompare(it, variable)) return it_index;
   return -1;
}

IsBuiltinVariableAvailable :: (builtin: BuiltinVariable, shaderType: ShaderType) -> bool {
   return ((cast(u32) builtin.stages) & (cast(u32) 1 << cast(u32) shaderType)) != 0;
}

// the builtin variables this shader uses. (GetSSAId was called on them while generating the instructions)
GetUsedBuiltinVariables :: (data: *CompilationData) -> [..] int {
   result: [..] int;
   result.allocator = temp;
   for builtinVariableIdentifiers {
      if (table_contains(*data.identifierToSSAId, it)) array_add(*result, it_index);
   }
   return result;
}

IsMatrixType :: (type: *Type_Info) -> bool {
   return CompareType(type, type_info(mat2)) || CompareType(type, type_info(mat3)) || CompareType(type, type_info(mat4)) || CompareType(type, type_info(f32x3x4));
}

GetMatrixVector :: (type: *Type_Info) -> *Type_Info {
   // matrices are defined as array of arrays.
   assert(type.type == .VARIANT);
   ti := UnwindVariantsAllTheWay(type);
   assert(ti.type == .ARRAY && ti.(*Type_Info_Array).array_type == .FIXED);
   tia := ti.(*Type_Info_Array);
   return tia.element_type;
}

GetVectorSize :: (type: *Type_Info) -> int {
   assert(type.type == .STRUCT);
   tis := cast(*Type_Info_Struct) type;
   return tis.runtime_size;
}

GetVectorComponentCount :: (type: *Type_Info) -> int {
   assert(type.type == .STRUCT);
   tis := cast(*Type_Info_Struct) type;
   return tis.members.count;
}

GetScalarTypeOrVectorElementType :: (type_: *Type_Info) -> *Type_Info {
   type := UnwindEnum(type_);
   if type.type == {
      case .INTEGER; #through;
      case .FLOAT;
         return type;
      case .STRUCT;
         tis := cast(*Type_Info_Struct) type;
         return tis.members[0].type;
      case; assert(false); return null;
   }
}

IsFloatScalarOrVector :: (type: *Type_Info) -> bool {
   if (type.type == .FLOAT) {
      return true;
   } else if (type.type == .STRUCT) {
      tis := cast(*Type_Info_Struct) type;
      member := tis.members[0].type;
      return member.type == .FLOAT;
   } else {
      return false;
   }
}

IsIntScalarOrVector :: (type_: *Type_Info) -> bool {
   type := UnwindEnum(type_);
   if (type.type == .INTEGER) {
      return true;
   } else if (type.type == .STRUCT) {
      tis := cast(*Type_Info_Struct) type;
      member := tis.members[0].type;
      return member.type == .INTEGER;
   } else {
      return false;
   }
}

GetScalarOrVectorIntSignedness :: (type_: *Type_Info) -> Signedness {
   type := UnwindEnum(type_);
   if (type.type == .INTEGER) {
      tii := cast(*Type_Info_Integer) type;
      return ifx tii.signed then .Signed else .Unsigned;
   } else {
      // this assertion is because this is currently how i implemented vectors
      assert(type.type == .STRUCT, "type: %", type.*);
      tis := cast(*Type_Info_Struct) type;
      member := tis.members[0].type;

      assert(member.type == .INTEGER);
      tiiMember := cast(*Type_Info_Integer) member;
      return ifx tiiMember.signed then .Signed else .Unsigned;
   }
}

//
// since vectors are structs (see the comment in DoCast) checking whether a type is one of the builtin scalars or vectors
// used to be a long chain of CompareType calls. these describe every builtin scalar and vector so it can be done with a single lookup.
//
NumericKind :: enum u8 {
   Bool;
   Signed;
   Unsigned;
   Float;
}

NumericInfo :: struct {
   kind:       NumericKind;
   bitSize:    int; // of a single component. 0 for bool since spirv bool has no bit size.
   components: int; // 1 for scalars.
}

NumericTypeEntry :: struct {
   type: Type;
   using info: NumericInfo;
}

NUMERIC_TYPES :: NumericTypeEntry.[
   .{ bool,  .{ .Bool,     0,  1 } },
   .{ bool2, .{ .Bool,     0,  2 } },
   .{ bool3, .{ .Bool,     0,  3 } },
   .{ bool4, .{ .Bool,     0,  4 } },
   .{ u8,    .{ .Unsigned, 8,  1 } },
   .{ u8x2,  .{ .Unsigned, 8,  2 } },
   .{ u8x3,  .{ .Unsigned, 8,  3 } },
   .{ u8x4,  .{ .Unsigned, 8,  4 } },
   .{ s8,    .{ .Signed,   8,  1 } },
   .{ s8x2,  .{ .Signed,   8,  2 } },
   .{ s8x3,  .{ .Signed,   8,  3 } },
   .{ s8x4,  .{ .Signed,   8,  4 } },
   .{ s16,   .{ .Signed,   16, 1 } },
   .{ s16x2, .{ .Signed,   16, 2 } },
   .{ s16x3, .{ .Signed,   16, 3 } },
   .{ s16x4, .{ .Signed,   16, 4 } },
   .{ u16,   .{ .Unsigned, 16, 1 } },
   .{ u16x2, .{ .Unsigned, 16, 2 } },
   .{ u16x3, .{ .Unsigned, 16, 3 } },
   .{ u16x4, .{ .Unsigned, 16, 4 } },
   .{ s32,   .{ .Signed,   32, 1 } },
   .{ s32x2, .{ .Signed,   32, 2 } },
   .{ s32x3, .{ .Signed,   32, 3 } },
   .{ s32x4, .{ .Signed,   32, 4 } },
   .{ u32,   .{ .Unsigned, 32, 1 } },
   .{ u32x2, .{ .Unsigned, 32, 2 } },
   .{ u32x3, .{ .Unsigned, 32, 3 } },
   .{ u32x4, .{ .Unsigned, 32, 4 } },
   .{ s64,   .{ .Signed,   64, 1 } },
   .{ s64x2, .{ .Signed,   64, 2 } },
   .{ s64x3, .{ .Signed,   64, 3 } },
   .{ s64x4, .{ .Signed,   64, 4 } },
   .{ u64,   .{ .Unsigned, 64, 1 } },
   .{ u64x2, .{ .Unsigned, 64, 2 } },
   .{ u64x3, .{ .Unsigned, 64, 3 } },
   .{ u64x4, .{ .Unsigned, 64, 4 } },
   .{ f32,   .{ .Float,    32, 1 } },
   .{ f32x2, .{ .Float,    32, 2 } },
   .{ f32x3, .{ .Float,    32, 3 } },
   .{ f32x4, .{ .Float,    32, 4 } },
   .{ f64,   .{ .Float,    64, 1 } },
   .{ f64x2, .{ .Float,    64, 2 } },
   .{ f64x3, .{ .Float,    64, 3 } },
   .{ f64x4, .{ .Float,    64, 4 } },
];

// returns false if type is not a builtin scalar or vector
GetNumericInfo :: (type: *Type_Info) -> NumericInfo, bool {
   for NUMERIC_TYPES {
      if (CompareType(type, cast(*Type_Info) it.type)) return it.info, true;
   }

   return .{}, false;
}

// returns null if there is no builtin scalar or vector with that shape. (for example there is no s8 or f64)
GetNumericType :: (kind: NumericKind, bitSize: int, components: int) -> *Type_Info {
   for NUMERIC_TYPES {
      if (it.kind == kind && it.bitSize == bitSize && it.components == components) return cast(*Type_Info) it.type;
   }

   return null;
}

GetNumericType :: (info: NumericInfo) -> *Type_Info {
   return GetNumericType(info.kind, info.bitSize, info.components);
}

IsNumericVector :: (type: *Type_Info) -> bool {
   info, ok := GetNumericInfo(type);
   return ok && info.components > 1;
}

// this code (and other codes) would have been a lot cleaner if i were to have proper vector types.
//
// "spirvType" is always castTo. better remove it      - apila, 06/06/26
DoCast :: (data: *CompilationData, b: *BuilderType, castTo: *Type_Info, castFrom: *Type_Info, expressionSSAId: SSAId, node: *Code_Node, spirvType: **Type_Info = null) -> SSAId {
   castToIdentifier: Identifier = .{ type = ._Type, _type = castTo };
   castFromIdentifier: Identifier = .{ type = ._Type, _type = castFrom };

   if (spirvType != null) spirvType.* = castTo;

   // to bool: x != 0, or for pointers x != null. jai also inserts this cast for conditions that are not bool (if flags & .X { })
   castToInfo, castToIsNumeric := GetNumericInfo(castTo);
   if (castToIsNumeric && castToInfo.kind == .Bool) {
      castFromInfo, castFromIsNumeric := GetNumericInfo(castFrom);
      if (castFromIsNumeric && castFromInfo.kind == .Bool) return expressionSSAId;

      resultSSAId := GetNextSSAId(data);

      if (castFrom.type == TYPE_INFO_POINTER_TAG) {
         u64Type := cast(*Type_Info) u64;
         addressSSAId := GetNextSSAId(data);
         WriteSingleInstructionIfReachable(b, *data.isBlockReachable, .ConvertPtrToU, GetSSAId(data, .{ type = ._Type, _type = u64Type }), addressSSAId, expressionSSAId);
         WriteSingleInstructionIfReachable(b, *data.isBlockReachable, .INotEqual, GetSSAId(data, castToIdentifier), resultSSAId, addressSSAId, GetSSAId(data, .{ type = .NullConstant, nullConstant = u64Type }));
         return resultSSAId;
      }

      assert(castFromIsNumeric && castFromInfo.components == castToInfo.components, "cant cast % to %. loc: %", castFrom.*, castTo.*, GetLocationString(node));

      op := ifx castFromInfo.kind == .Float then SpvOp.FUnordNotEqual else SpvOp.INotEqual;
      zeroSSAId := GetSSAId(data, .{ type = .NullConstant, nullConstant = castFrom });
      WriteSingleInstructionIfReachable(b, *data.isBlockReachable, op, GetSSAId(data, castToIdentifier), resultSSAId, expressionSSAId, zeroSSAId);
      return resultSSAId;
   }

   // from bool: ifx x then 1 else 0
   castFromInfo, castFromIsNumeric := GetNumericInfo(castFrom);
   if (castFromIsNumeric && castFromInfo.kind == .Bool) {
      assert(castToIsNumeric && castToInfo.components == 1 && castFromInfo.components == 1, "cant cast % to %. loc: %", castFrom.*, castTo.*, GetLocationString(node));

      one: Identifier;
      if (castToInfo.kind == .Float) {
         one = FloatLiteralIdentifier(1, castToInfo.bitSize);
      } else {
         one = .{ type = .IntLiteral, intLiteral = .{ unsigned = castToInfo.kind == .Unsigned, value._s64 = 1, bitSize = castToInfo.bitSize } };
      }

      resultSSAId := GetNextSSAId(data);
      WriteSingleInstructionIfReachable(b, *data.isBlockReachable, .Select, GetSSAId(data, castToIdentifier), resultSSAId, expressionSSAId, GetSSAId(data, one), GetSSAId(data, .{ type = .NullConstant, nullConstant = castTo }));
      return resultSSAId;
   }

   bothPointer := castTo.type == TYPE_INFO_POINTER_TAG && castFrom.type == TYPE_INFO_POINTER_TAG;
   if (bothPointer) {
      fromStorageClass := (cast(*TypeInfoPointer) castFrom).storageClass;
      toStorageClass := (cast(*TypeInfoPointer) castTo).storageClass;
      assert(fromStorageClass == toStorageClass, "a pointer to % memory cant be a pointer to % memory (for example a pointer to a local variable cant be passed to a procedure or stored). loc: %", fromStorageClass, toStorageClass, GetLocationString(node));

      resultSSAId := GetNextSSAId(data);
      WriteSingleInstructionIfReachable(
         b,
         *data.isBlockReachable,
         .Bitcast,
         GetSSAId(data, castToIdentifier),
         resultSSAId,
         expressionSSAId
      );

      return resultSSAId;
   }

   // then neither pointer
   assert(castTo.type != TYPE_INFO_POINTER_TAG && castFrom.type != TYPE_INFO_POINTER_TAG, "castTo: %, castFrom: %, loc: %", castTo.*, castFrom.*, GetLocationString(node));

   // doing vector or scalar cast for integers (floats not yet implemented)
   // this is a two stage cast:
   //    1. size extend or truncate
   //    2. signedness
   // you have to use OpBitcast for the second stage, and OpXConvert for the first one.
   //
   // sizeCastType = .{ size = castTo.size, signedness = castFrom.signedness };
   //
   // if i had Type_Info_Vector, it would be easy. or if i were to declare the vectors as:
   //    s32x3 :: #type,distinct [3] s32;
   // rather than
   //    s32x3 :: struct { x: s32; y: s32; z: s32; };
   //
   // then it would have been a lot easier, but as you know defining vectors as arrays has its own downsides, so idk man.
   //       - apila, 06/06/26

   fromInfo, fromIsNumeric := GetNumericInfo(castFrom);

   if (fromIsNumeric && fromInfo.kind == .Float) {
      toInfo, toIsNumeric := GetNumericInfo(castTo);

      // float to float (f32 and f64)
      if (toIsNumeric && toInfo.kind == .Float) {
         assert(toInfo.components == fromInfo.components, "castFrom: %, castTo: %, loc: %", TypeName(castFrom), TypeName(castTo), GetLocationString(node));
         if (toInfo.bitSize == fromInfo.bitSize) return expressionSSAId;

         resultSSAId := GetNextSSAId(data);
         WriteSingleInstructionIfReachable(b, *data.isBlockReachable, .FConvert, GetSSAId(data, .{ type = ._Type, _type = castTo }), resultSSAId, expressionSSAId);
         return resultSSAId;
      }

      // float to int
      assert(toIsNumeric && (toInfo.kind == .Signed || toInfo.kind == .Unsigned), "not yet implemented! castFrom: %, castTo: %, loc: %", castFrom.*, castTo.*, GetLocationString(node));
      assert(toInfo.components == fromInfo.components, "castFrom: %, castTo: %, loc: %", castFrom.*, castTo.*, GetLocationString(node));

      resultSSAId := GetNextSSAId(data);
      WriteSingleInstructionIfReachable(
         b,
         *data.isBlockReachable,
         ifx toInfo.kind == .Signed then SpvOp.ConvertFToS else SpvOp.ConvertFToU,
         GetSSAId(data, .{ type = ._Type, _type = castTo }),
         resultSSAId,
         expressionSSAId
      );

      return resultSSAId;
   }

   fromIsInt := fromIsNumeric && (fromInfo.kind == .Signed || fromInfo.kind == .Unsigned);
   assert(fromIsInt, "not yet implemented! castFrom: %, loc: %", castFrom.*, GetLocationString(node));

   if (IsIntScalarOrVector(castTo)) {
      // int to int
      toInfo, toIsNumeric := GetNumericInfo(castTo);
      assert(toIsNumeric, "not yet implemented! castTo: %, loc: %", castTo.*, GetLocationString(node));

      sizeCastType := GetNumericType(fromInfo.kind, toInfo.bitSize, toInfo.components);
      assert(sizeCastType != null, "not yet implemented!");

      sizeCastSSAId: SSAId;
      if (!CompareType(castFrom, sizeCastType)) {
         sizeCastSSAId = GetNextSSAId(data);
         WriteSingleInstructionIfReachable(
            b,
            *data.isBlockReachable,
            ifx fromInfo.kind == .Signed then SpvOp.SConvert else SpvOp.UConvert,
            GetSSAId(data, .{ type = ._Type, _type = sizeCastType }),
            sizeCastSSAId,
            expressionSSAId
         );
      } else {
         sizeCastSSAId = expressionSSAId;
      }

      resultSSAId: SSAId;
      if (toInfo.kind != fromInfo.kind) {
         resultSSAId = GetNextSSAId(data);
         WriteSingleInstructionIfReachable(
            b,
            *data.isBlockReachable,
            .Bitcast,
            GetSSAId(data, .{ type = ._Type, _type = castTo }),
            resultSSAId,
            sizeCastSSAId
         );
      } else {
         resultSSAId = sizeCastSSAId;
      }

      return resultSSAId;
   } else {
      // int to float
      assert(IsFloatScalarOrVector(castTo));

      resultSSAId := GetNextSSAId(data);
      WriteSingleInstructionIfReachable(
         b,
         *data.isBlockReachable,
         ifx fromInfo.kind == .Signed then SpvOp.ConvertSToF else SpvOp.ConvertUToF,
         GetSSAId(data, .{ type = ._Type, _type = castTo }),
         resultSSAId,
         expressionSSAId
      );

      return resultSSAId;
   }
}

//
// the operators on the builtin scalars, vectors and matrices are generated from the operator itself (the operator procedures declared for vectors only exist so that jai typechecks).
// an operator on any other type is an operator procedure the user declared, but the compiler doesnt tell the metaprogram which procedure it chose for the operator
// (Code_Binary_Operator doesnt have it), and choosing it here would mean doing the overload resolution of jai.
//
AssertNotUserOperator :: (leftType: *Type_Info, rightType: *Type_Info, node: *Code_Binary_Operator) {
   IsBuiltin :: (type: *Type_Info) -> bool {
      _, isNumeric := GetNumericInfo(type);
      return isNumeric || IsMatrixType(type) || type.type == TYPE_INFO_POINTER_TAG;
   }

   assert(IsBuiltin(leftType) && IsBuiltin(rightType), "operator % on % and % is an operator procedure. they are not supported because the jai compiler doesnt tell the metaprogram which operator procedure is called. call a procedure instead. loc: %", OperatorToString(node.operator_type), TypeName(leftType), TypeName(rightType), GetLocationString(node));
}

// the compiler passes the object a for loop iterates to for_expansion as cast(T) *object (if the parameter is not a pointer).
// that is the object itself. taking the address is not possible if the object is a local variable.
IsCastOfAddressToPointee :: (cc: *Code_Cast) -> bool {
   if (cc.expression.kind != .UNARY_OPERATOR) return false;
   cuo := cast(*Code_Unary_Operator) cc.expression;
   if (cuo.operator_type != #char "*" || cuo.subexpression.type == null) return false;
   if (cc.type.type == .POINTER) return false;
   return cc.type == cuo.subexpression.type;
}

// for error messages
TypeName :: (type: *Type_Info) -> string {
   if type.type == {
      case TYPE_INFO_DECORATIONLESS_COPY_OF_STRUCT_TAG;  return (cast(*TypeInfoDecorationlessCopyOfStruct) type).copyOf.name;
      case TYPE_INFO_POINTER_TAG;                        return tprint("*% (%)", TypeName((cast(*TypeInfoPointer) type).pointerTo), (cast(*TypeInfoPointer) type).storageClass);
      case TYPE_INFO_RUNTIME_ARRAY_TAG;                  return tprint("[] %", TypeName((cast(*TypeInfoRuntimeArray) type).elementType));
      case TYPE_INFO_IMAGE_TAG;                          return "image";
      case TYPE_INFO_SAMPLED_IMAGE_TAG;                  return "sampled image";
      case .ARRAY;
         tia := cast(*Type_Info_Array) type;
         if (tia.array_type == .FIXED) return tprint("[%] %", tia.array_count, TypeName(tia.element_type));
         return tprint("[] %", TypeName(tia.element_type));

      case .VARIANT;
         return (cast(*Type_Info_Variant) type).name;
   }

   return tprint("%", type);
}

OperatorToString :: (operatorType: Operator_Type) -> string {
   if (cast(int) operatorType < 128) return tprint("%", string.{ 1, cast(*u8) *operatorType });
   return tprint("%", operatorType);
}

// converts a value to the type it should be (implicit conversions of jai, or between a struct and its decorationless copy)
ConvertValue :: (data: *CompilationData, b: *BuilderType, ssaId: SSAId, fromType: *Type_Info, toType: *Type_Info, node: *Code_Node) -> SSAId {
   if (CompareType(fromType, toType)) return ssaId;

   // a struct (or array) and its decorationless copy are logically the same type, OpCopyLogical converts between them in both directions.
   if (IsDecorationlessType(toType) || IsDecorationlessType(fromType)) {
      resultSSAId := GetNextSSAId(data);
      WriteSingleInstructionIfReachable(b, *data.isBlockReachable, .CopyLogical, GetSSAId(data, .{ type = ._Type, _type = toType }), resultSSAId, ssaId);
      return resultSSAId;
   }

   return DoCast(data, b, toType, fromType, ssaId, node);
}

// *, +, -, /, %
// any binary operator that has this spirv signature:
//    <id>          <id>      <id>        <id>
//  Result Type    Result   Operand 1   Operand 2
DoBinaryArithmetic :: (data: *CompilationData, b: *BuilderType, leftType: *Type_Info, leftId: SSAId, rightType: *Type_Info, rightId: SSAId, operatorType: Operator_Type, node: *Code_Node, spirvType: **Type_Info = null) -> SSAId {
   // broadcasting. spirv has no instructions that take a vector and a scalar (except OpVectorTimesScalar), so the scalar is made into a vector:
   //    v + s   ->   v + .{ s, s, s }
   // the scalar must already be of the component type of the vector, see GetArithmeticOperandTypes.
   if (operatorType != .SHIFT_LEFT && operatorType != .SHIFT_RIGHT) {
      leftInfo, leftIsNumeric := GetNumericInfo(leftType);
      rightInfo, rightIsNumeric := GetNumericInfo(rightType);

      if (leftIsNumeric && rightIsNumeric && leftInfo.components != rightInfo.components && (leftInfo.components == 1 || rightInfo.components == 1)) {
         scalarIsLeft := leftInfo.components == 1;
         vectorType := ifx scalarIsLeft then rightType else leftType;
         vectorInfo := ifx scalarIsLeft then rightInfo else leftInfo;
         scalarInfo := ifx scalarIsLeft then leftInfo else rightInfo;
         vectorId := ifx scalarIsLeft then rightId else leftId;
         scalarId := ifx scalarIsLeft then leftId else rightId;

         assert(scalarInfo.kind == vectorInfo.kind && scalarInfo.bitSize == vectorInfo.bitSize, "can only broadcast a scalar of the component type of the vector. left: %, right: %, loc: %", leftType.*, rightType.*, GetLocationString(node));

         if (spirvType != null) spirvType.* = vectorType;

         // multiplication is commutative so the order doesnt matter
         if (vectorInfo.kind == .Float && operatorType == #char "*") {
            resultSSAId := GetNextSSAId(data);
            WriteSingleInstructionIfReachable(b, *data.isBlockReachable, .VectorTimesScalar, GetSSAId(data, .{ type = ._Type, _type = vectorType }), resultSSAId, vectorId, scalarId);
            return resultSSAId;
         }

         broadcastSSAId := GetNextSSAId(data);
         operands: [..] Any;
         operands.allocator = temp;
         array_add(*operands, GetSSAId(data, .{ type = ._Type, _type = vectorType }));
         array_add(*operands, broadcastSSAId);
         for 1..vectorInfo.components  array_add(*operands, scalarId);
         WriteSingleInstructionIfReachable(b, *data.isBlockReachable, .CompositeConstruct, .. operands);

         if (scalarIsLeft) {
            return DoBinaryArithmetic(data, b, vectorType, broadcastSSAId, vectorType, vectorId, operatorType, node, spirvType);
         } else {
            return DoBinaryArithmetic(data, b, vectorType, vectorId, vectorType, broadcastSSAId, operatorType, node, spirvType);
         }
      }
   }

   resultSSAId := GetNextSSAId(data);

   // jai doesnt convert the shift amount to the type of the shifted value (in "x << 2" the 2 is s64), and spirv doesnt require it either.
   // the result has the type of the shifted value.
   if (operatorType == .SHIFT_LEFT || operatorType == .SHIFT_RIGHT) {
      leftInfo, leftIsNumeric := GetNumericInfo(leftType);
      rightInfo, rightIsNumeric := GetNumericInfo(rightType);
      assert(leftIsNumeric  && (leftInfo.kind  == .Signed || leftInfo.kind  == .Unsigned), "can only shift integers. type: %, loc: %", leftType.*, GetLocationString(node));
      assert(rightIsNumeric && (rightInfo.kind == .Signed || rightInfo.kind == .Unsigned), "shift amount must be an integer. type: %, loc: %", rightType.*, GetLocationString(node));
      assert(leftInfo.components == rightInfo.components, "shift amount must have the same number of components as the shifted value. loc: %", GetLocationString(node));

      if (spirvType != null) spirvType.* = leftType;

      WriteSingleInstructionIfReachable(
         b,
         *data.isBlockReachable,
         GetIntegerOpFromOperatorType(operatorType, ifx leftInfo.kind == .Signed then Signedness.Signed else .Unsigned),
         GetSSAId(data, .{ type = ._Type, _type = leftType }),
         resultSSAId,
         leftId,
         rightId
      );

      return resultSSAId;
   }

   if (CompareType(rightType, leftType)) {
      type := leftType;

      if (spirvType != null) spirvType.* = type;

      typeIdentifier: Identifier = .{ type = ._Type, _type = type };
      info, isNumeric := GetNumericInfo(type);

      op: SpvOp;
      #if false {
      } else if (isNumeric && info.kind == .Float) {
         op = GetFloatOpFromOperatorType(operatorType);
      } else if (isNumeric && (info.kind == .Signed || info.kind == .Unsigned)) {
         op = GetIntegerOpFromOperatorType(operatorType, ifx info.kind == .Signed then Signedness.Signed else .Unsigned);
      } else {
         assert(false, "not implemented yet! type: %\n", type.*);
      }

      WriteSingleInstructionIfReachable(
         b,
         *data.isBlockReachable,
         op,
         GetSSAId(data, typeIdentifier),
         resultSSAId,
         leftId,
         rightId
      );
   } else {
      // either need to broadcast from scalar to vector type
      // or if it is multiplication there are specific instructions for the multiplication. i should use them.

      if (operatorType == #char "*") {
         // the vector has a component for each column, the result has a component for each row (it has the type of a column).
         isLeftMatrix := IsMatrixType(leftType);
         rightInfo, isRightVector := GetNumericInfo(rightType);
         isRightVector = isRightVector && rightInfo.kind == .Float && rightInfo.components > 1;

         if (isLeftMatrix && isRightVector) {
            columns := cast(*Type_Info_Array) UnwindVariantsAllTheWay(leftType);
            assert(columns.array_count == rightInfo.components, "the vector must have a component for each column of the matrix. left: %, right: %, loc: %", leftType.*, rightType.*, GetLocationString(node));
            resultType := GetMatrixVector(leftType);

            WriteSingleInstructionIfReachable(
               b,
               *data.isBlockReachable,
               .MatrixTimesVector,
               GetSSAId(data, .{ type = ._Type, _type = resultType }),
               resultSSAId,
               leftId,
               rightId
            );

            if (spirvType != null) spirvType.* = resultType;
         } else {
            assert(false, "not yet implemented! if it is a broadcast i think i will implement it probably sometime surely Clueless. left: %, right: %, loc: %", leftType.*, rightType.*, GetLocationString(node));
         }
      } else {
         assert(false, "not yet implemented! loc: %", GetLocationString(node));
      }
   }

   return resultSSAId;
}

// returns true if added, false otherwise
TableAddIfNotExists :: (table: *Table, key: table.Key_Type, value: table.Value_Type) -> bool {
   entry, newlyAdded := find_or_add(table, key);

   if (newlyAdded) {
      entry.* = value;
   }

   return newlyAdded;
}

// assertion failure if exists
TableAdd :: (table: *Table, key: table.Key_Type, value: table.Value_Type) {
   entry, newlyAdded := find_or_add(table, key);
   assert(newlyAdded);

   entry.* = value;
}

// well there is a conflicting assumption on this function which i can resolve if i had more info from the compiler.
// DetermineCodeNodeTypes assumes that it only operates on nodes that are child of the entry point function (.DECLARATION depends on this).
// yet i still need to compute the types of nodes even if they are not child of the entry point function (for example global constant varaibles like PI or some shared data between cpu and gpu DEFAULT_SAMPLER_IDX, you get the idea).
// my solution would be to allow calling this function on any node, doesnt matter where it is whether it is child of the entry point or not. but for that .DECLARATION needs more information. it needs to know the scope of the declaration
// because of the decorationless struct thingy. so idk how to solve this. if Code_Nodes were to store the parent then i could have solved this issue.
//                - apila, 08/06/26
//
// ok, no more holds the assumption that DetermineCodeNodeTypes can be called only on the child of the entry point. DetermineCodeNodeTypes can be called anywhere. if you need more context to as where the Code_Nodes are you need to collect
// those in the message loop before i even start to compile any shader entry point.
//                - apila, 09/06/26
DetermineCodeNodeTypes :: (data: *CompilationData, node: *Code_Node) -> *Type_Info {
   found, value := table_find(*data.codeNodeTypes, node);
   if (found) return value;

   if node.kind == {
      case .BLOCK;
         cb := cast(*Code_Block) node;
         usingBase := data.usingStack.count;
         for cb.statements {
            DetermineCodeNodeTypes(data, it);
         }
         data.usingStack.count = usingBase;

         TableAdd(*data.codeNodeTypes, node, cast(*Type_Info) void);
         return cast(*Type_Info) void;

      // using x; the members of x are in scope until the end of the block
      case .USING;
         cu := cast(*Code_Using) node;
         base := cu.expression;

         // using x: T; declares x
         if (base.kind == .DECLARATION) {
            declaration := cast(*Code_Declaration) base;
            DetermineCodeNodeTypes(data, declaration);

            ident := New(Code_Ident);
            ident.base = declaration.base;
            ident.kind = .IDENT;
            ident.type = declaration.type;
            ident.name = declaration.name;
            ident.resolved_declaration = declaration;
            base = ident;
         }

         DetermineCodeNodeTypes(data, base);
         array_add(*data.usingStack, base);

         TableAdd(*data.codeNodeTypes, node, cast(*Type_Info) void);
         return cast(*Type_Info) void;

      case .LITERAL;
         cl := cast(*Code_Literal) node;

         // maybe i should determine the type of parent nodes from somewhere else.
         // like for example if it is a declaration then from the decalration notes.
         // maybe for this kind of things i need a seperate entry in the CompilationData.codeNodeTypes
         // that says that i should ignore the type of this node.
         //       - apila, 25/04/26
         // null. a pointer like any other pointer that doesnt say otherwise, PhysicalStorageBuffer
         if (cl.value_type == .POINTER) {
            type := ConvertJaiTypeIfNecessary(node.type, string.[]);
            TableAdd(*data.codeNodeTypes, node, type);
            return type;
         }

         // this is not sufficient.
         // if struct has members of type pointers then to be able to correctly determine the type of the member
         // i need to pass the Type_Info_Struct to the members through DetermineCodeNodeTypes.
         //    - apila, 26/04/26
         if (cl.value_type == .STRUCT) {
            if (node.type.type == .STRUCT) return DetermineStructLiteralTypes(data, cl, xx node.type);

            // untyped and not nested in a struct literal (for example inside an array literal). the type is not known here.
            for cl.struct_literal_info.arguments {
               DetermineCodeNodeTypes(data, it);
            }
         } else if (cl.value_type == .ARRAY) {
            // untyped struct literals in an array literal (f32x2.[.{1, 2}]) get the type of the elements
            elementType: *Type_Info;
            if (node.type.type == .ARRAY) elementType = (cast(*Type_Info_Array) node.type).element_type;

            for cl.array_literal_info.array_members {
               if (elementType != null && elementType.type == .STRUCT && it.kind == .LITERAL && (cast(*Code_Literal) it).value_type == .STRUCT && it.type.type != .STRUCT) {
                  DetermineStructLiteralTypes(data, xx it, xx elementType);
               } else {
                  DetermineCodeNodeTypes(data, it);
               }
            }
         }

         TableAdd(*data.codeNodeTypes, node, node.type);
         return node.type;

      // this case only called if accessing single variable (no access chains)
      // so it must be a variable declared somewhere
      case .IDENT;
         ci := cast(*Code_Ident) node;
         declaration := ci.resolved_declaration;

         // the jai compiler doesnt resolve identifiers inside untyped struct literals (resolved_declaration is null, only the name is there).
         // resolving it by name would mean reimplementing jai's scope rules so instead the user has to write the type.
         assert(declaration != null, "the jai compiler didnt resolve identifier %. this happens when it is used inside an untyped struct literal (.{ ... }), which is not supported. write the type of the literal instead, for example f32x4.{ ... }. loc: %", ci.name, GetLocationString(ci));

         // a member of a struct that is in scope because of using
         memberOf := GetStructOfMemberDeclaration(declaration);
         if (memberOf != null && !(declaration.flags & .IS_CONSTANT)) {
            access := GetUsingAccess(data, ci, memberOf);
            type := DetermineCodeNodeTypes(data, access);
            TableAdd(*data.usingAccesses, ci, access);
            TableAdd(*data.codeNodeTypes, node, type);
            return type;
         }

         builtinIndex := GetBuiltinVariableIndex(.{ type = .Variable, variable.declaration = declaration });
         if (builtinIndex != -1) {
            builtin := BUILTIN_VARIABLES[builtinIndex];
            assert(IsBuiltinVariableAvailable(builtin, data.shaderType), "% is not available in % shaders. loc: %", builtin.name, data.shaderType, GetLocationString(ci));
         }

         declarationType := DetermineCodeNodeTypes(data, declaration);

         //
         // dirty way to do what i want to do.
         // what i want to do:
         // since i now have TypeInfoDecorationlessCopyOfStruct, i need to update the types accordingly.
         // simply i want to get the type from its declaration but .DECLARATION case in this function assumes that declaration is done inside the shader function
         // because this function determines code node types only within the shader functions. so .DECLARATION creates a TypeInfoDecorationlessCopyOfStruct when it sees a struct.
         // but this is not true for builtin types like __Image__. and in the .DECLARATION i don't have a way to know if the declaration is within a function if i were to do something like:
         //       newNodeType := DetermineCodeNodeTypes(data, declaration);
         // so my assumption here is that if the type of declaration is found in data.codeNodeTypes, then it means it is a local declaration and use the type of the declration, otherwise
         // i assume that it is a variable with intrinsic type, so i just used the old code that used to work but im not sure about unwinding. idk man.
         //
         //                                     - apila, 07/06/26
         //

         // found, declarationType := table_find(*data.codeNodeTypes, declaration);
         // newNodeType: *Type_Info;
         // if (found) {
         //    newNodeType = declarationType;
         // } else {
         //    //
         //    // unwinding here because now matrices are #type,distinct.
         //    // and i want to treat them as if they were normal arrays in the code generation.
         //    // but they are distinct types as in a f32x4x4 is not the same as [4] f32x4 if user declares a variable of this type.
         //    // one of them is OpTypeMatrix the other is OpTypeArray.
         //    // and if you consider user defined types (types that are not intrinsic) i think unwinding has no problem with that Clueless.
         //    //
         //    //             - apila, 07/05/26
         //    //
         //    nodeTypeUnwinded := UnwindVariantsUpToDistinct(node.type);
         //    newNodeType = ConvertJaiTypeIfNecessary(nodeTypeUnwinded, declaration.notes);

         //    // im recursing into the expression here if it is constant
         //    if (declaration.flags & .IS_CONSTANT) {
         //       DetermineCodeNodeTypes(data, declaration.expression);
         //    }
         // }

         TableAdd(*data.codeNodeTypes, node, declarationType);
         return declarationType;

      case .BINARY_OPERATOR;
         cbo := cast(*Code_Binary_Operator) node;

         if cbo.operator_type == {
            case .TIMES_ASSIGN;        #through;
            case .DIV_ASSIGN;          #through;
            case .MOD_ASSIGN;          #through;
            case .MINUS_ASSIGN;        #through;
            case .PLUS_ASSIGN;         #through;
            case .BITWISE_AND_ASSIGN;  #through;
            case .BITWISE_OR_ASSIGN;   #through;
            case .BITWISE_XOR_ASSIGN;  #through;
            case .SHIFT_LEFT_ASSIGN;   #through;
            case .SHIFT_RIGHT_ASSIGN;  #through;
            case #char "=";
               _ := DetermineCodeNodeTypes(data, cbo.left);
               rightType := DetermineCodeNodeTypes(data, cbo.right);

               TableAdd(*data.codeNodeTypes, node, rightType);
               return rightType;

            case #char "+"; #through;
            case #char "-"; #through;
            case #char "*"; #through;
            case #char "/"; #through;
            case #char "<"; #through;
            case #char ">"; #through;
            case #char "%"; #through;
            case #char "&"; #through;
            case #char "|"; #through;
            case #char "^"; #through;
            case .SHIFT_LEFT;       #through;
            case .SHIFT_RIGHT;      #through;
            case .LESS_OR_EQUAL;    #through;
            case .GREATER_OR_EQUAL; #through;
            case .IS_EQUAL;         #through;
            case .IS_NOT_EQUAL;     #through;
            case .LOGICAL_AND;      #through;
            case .LOGICAL_OR;
               rightType := DetermineCodeNodeTypes(data, cbo.right);
               leftType := DetermineCodeNodeTypes(data, cbo.left);

               if (rightType.type == TYPE_INFO_POINTER_TAG && leftType.type == TYPE_INFO_POINTER_TAG) {
                  tipRight := cast(*TypeInfoPointer) rightType;
                  tipLeft := cast(*TypeInfoPointer) leftType;

                  assert(tipLeft.storageClass == tipRight.storageClass, "tipLeft.storageClass: %, tipRight.storageClass: %", tipLeft.storageClass, tipRight.storageClass);

                  TableAdd(*data.codeNodeTypes, node, rightType);
                  return rightType;
               }

               if (rightType.type != TYPE_INFO_POINTER_TAG && leftType.type != TYPE_INFO_POINTER_TAG) {
                  TableAdd(*data.codeNodeTypes, node, node.type);
                  return node.type;
               }

               // one of them pointer the other is not
               pointerType := ifx rightType.type == TYPE_INFO_POINTER_TAG then rightType else leftType;
               TableAdd(*data.codeNodeTypes, node, pointerType);
               return pointerType;

            case #char ".";
               // E.A (a value of an enum) or Module.x (named module). the type is the type of the right side.
               if (cbo.left.type != null && cbo.left.type.type == .TYPE) {
                  assert(cbo.right.kind == .IDENT, "kind: %", cbo.right.kind);
                  ci := cast(*Code_Ident) cbo.right;
                  rightType := DetermineCodeNodeTypes(data, ci.resolved_declaration);

                  // normally i dont add the type of the right node to the table since i dont use it when generating instructions.
                  // but this is an exception, i do use it.
                  TableAdd(*data.codeNodeTypes, cbo.right, rightType);

                  TableAdd(*data.codeNodeTypes, node, rightType);
                  return rightType;
               }

               leftType := DetermineCodeNodeTypes(data, cbo.left);

               if leftType.type == {
                  case TYPE_INFO_POINTER_TAG; #through;
                  case TYPE_INFO_DECORATIONLESS_COPY_OF_STRUCT_TAG; #through;
                  case .ARRAY; #through;
                  case .STRUCT; {
                     tis: *Type_Info_Struct;
                     if leftType.type == {
                        case TYPE_INFO_POINTER_TAG; {
                           tip := cast(*TypeInfoPointer) leftType;
                           if (tip.pointerTo.type == TYPE_INFO_DECORATIONLESS_COPY_OF_STRUCT_TAG) {
                              tis = (cast(*TypeInfoDecorationlessCopyOfStruct) tip.pointerTo).copyOf;
                           } else {
                              assert(tip.pointerTo.type == .STRUCT, "type: %, loc: %", TypeName(tip.pointerTo), GetLocationString(node));
                              tis = xx tip.pointerTo;
                           }
                        }

                        case TYPE_INFO_DECORATIONLESS_COPY_OF_STRUCT_TAG; {
                           tidcos := cast(*TypeInfoDecorationlessCopyOfStruct) leftType;
                           tis = tidcos.copyOf;
                        }

                        case .STRUCT; {
                           tis = xx leftType;
                        }

                        // array.data or array.count
                        case .ARRAY; {
                           tia := leftType.(*Type_Info_Array);
                           tis = GetArrayViewTypeInfo(tia.element_type);
                        }

                        case; assert(false);
                     }

                     assert(cbo.right.kind == .IDENT, "cbo.right.kind: %", cbo.right.kind);
                     right := cast(*Code_Ident) cbo.right;

                     path, member := GetMemberPath(tis, right.name);
                     assert(path.count > 0, "% is not a member of %. loc: %", right.name, tis.name, GetLocationString(right));

                     notes := member.notes;
                     newMemberType := ConvertJaiTypeIfNecessary(member.type, notes);
                     pointsToDecorationless := leftType.type == TYPE_INFO_POINTER_TAG && (cast(*TypeInfoPointer) leftType).pointerTo.type == TYPE_INFO_DECORATIONLESS_COPY_OF_STRUCT_TAG;
                     if (leftType.type == TYPE_INFO_DECORATIONLESS_COPY_OF_STRUCT_TAG || pointsToDecorationless) newMemberType = GetFunctionStorageClassType(newMemberType);

                     TableAdd(*data.codeNodeTypes, node, newMemberType);
                     return newMemberType;
                  }

                  case; assert(false, "type: %", leftType.type);
               }

            case .ARRAY_SUBSCRIPT;
               leftType := DetermineCodeNodeTypes(data, cbo.left);
               _ := DetermineCodeNodeTypes(data, cbo.right);

               leftType = UnwindVariantsAllTheWay(leftType);

               if leftType.type == {
                  case .ARRAY; {
                     tia := cast(*Type_Info_Array) leftType;
                     TableAdd(*data.codeNodeTypes, node, tia.element_type);
                     return tia.element_type;
                  }

                  case TYPE_INFO_POINTER_TAG; {
                     tip := cast(*TypeInfoPointer) leftType;
                     TableAdd(*data.codeNodeTypes, node, tip.pointerTo);
                     return tip.pointerTo;
                  }

                  case TYPE_INFO_RUNTIME_ARRAY_TAG; {
                     tira := cast(*TypeInfoRuntimeArray) leftType;
                     TableAdd(*data.codeNodeTypes, node, tira.elementType);
                     return tira.elementType;
                  }

                  case; assert(false, "type: %", leftType.type); return null;
               }


            case; assert(false, "operator: %", cbo.operator_type);
         }

      case .PROCEDURE_HEADER; {
         cph := cast(*Code_Procedure_Header) node;

         // a procedure is being typed while it is being typed: it calls itself (maybe through other procedures)
         for data.proceduresBeingTyped {
            assert(it != cph, "% calls itself (maybe through other procedures). recursion is not allowed in spirv. loc: %", cph.name, GetLocationString(cph));
         }
         array_add(*data.proceduresBeingTyped, cph);
         defer data.proceduresBeingTyped.count -= 1;

         // jai doesnt allow adding notes to the Code_Declaration if it is an argument.
         // thats why i am doing this hack here. i just add the "payload" note to the TraceRay payload.
         //          - apila, 08/09/26
         if(IsTraceRayFunction(cph)) {
            // last argument is the payload
            assert(cph.arguments[cph.arguments.count - 1].type.type == .POINTER);

            notes := NewArray(1, *Code_Note);
            notes[0] = New(Code_Note);
            notes[0].text = RAY_PAYLOAD_QUALIFIER;
            cph.arguments[cph.arguments.count - 1].notes = notes;
         }

         for cph.arguments {
            DetermineCodeNodeTypes(data, it);
         }

         for cph.returns {
            DetermineCodeNodeTypes(data, it);
         }

         assert(cph.body_or_null != null, "loc: %:%", node.location.enclosing_load.fully_pathed_filename, node.location);
         assert(cph.body_or_null.block != null);
         DetermineCodeNodeTypes(data, cph.body_or_null.block);

         TableAdd(*data.codeNodeTypes, node, node.type);
         return node.type;
      }

      case .PROCEDURE_CALL;
         cpc := cast(*Code_Procedure_Call) node;
         assert(cpc.resolved_procedure_expression != null, "loc: %", cpc.location);
         assert(cpc.resolved_procedure_expression.kind == .PROCEDURE_HEADER || // constant function
                cpc.resolved_procedure_expression.kind == .IDENT || // not constant function
                cpc.resolved_procedure_expression.kind == .BINARY_OPERATOR, // namespaces
                "kind: %", cpc.resolved_procedure_expression.kind
         );

         header := GetHeaderFromCodeProcedureCall(cpc);

         if (IsMacroProcedure(header)) {
            expansion := cpc.macro_expansion_block;
            assert(expansion != null, "macro call has no expansion: %", header.name);
            array_add(*data.macroExpansionCalls, cpc);
            defer data.macroExpansionCalls.count -= 1;
            DetermineCodeNodeTypes(data, expansion);

            // the type of the call is the declared return type of the macro, not the type of the expression returned. (return 0 in a macro that returns f32)
            returnTypeIdentifier := GetReturnTypeIdentifier(xx header.type);
            returnType := ifx returnTypeIdentifier.type == .Void then cast(*Type_Info) void else returnTypeIdentifier._type;
            TableAdd(*data.codeNodeTypes, node, returnType);
            return returnType;
         }

         // recurse into the procedure
         DetermineCodeNodeTypes(data, header);

         for cpc.arguments_unsorted {
            DetermineCodeNodeTypes(data, it.expression);
         }

         // the arguments in the order of the parameters, with the default values filled in. these are the ones generated
         for cpc.arguments_sorted {
            DetermineCodeNodeTypes(data, it);
         }

         if (header.returns.count == 0) {
            TableAdd(*data.codeNodeTypes, node, cast(*Type_Info) void);
            return cast(*Type_Info) void;
         }

         // recursed in to header above which then recurses into the arguments and the returns
         // return count here is 1 as asserted above
         found, returnType := table_find(*data.codeNodeTypes, header.returns[0]);
         assert(found);

         TableAdd(*data.codeNodeTypes, node, returnType);
         return returnType;

      case .DECLARATION;
         cd := cast(*Code_Declaration) node;

         // a declaration of a type (S :: struct {}), a procedure or code (the body of a for_expansion) is not a value
         if ((cd.flags & .IS_CONSTANT) && (cd.type.type == .TYPE || cd.type.type == .CODE || cd.type.type == .PROCEDURE)) {
            TableAdd(*data.codeNodeTypes, node, cd.type);
            return cd.type;
         }

         if (cd.expression != null) {
            DetermineCodeNodeTypes(data, cd.expression);
         }

         // some of the intrinsics
         if (false) {
         } else if (cd == meshVerticesVariableIdentifier.variable.declaration) {
            tia := CreateTypeInfoArrayFixedSize(type_info(MeshPerVertex), data.maxVertices);
            TableAdd(*data.codeNodeTypes, node, tia);
            return tia;
         } else if (GetMeshPrimitiveIndicesIndex(.{ type = .Variable, variable.declaration = cd }) != -1) {
            indicesIndex := GetMeshPrimitiveIndicesIndex(.{ type = .Variable, variable.declaration = cd });
            assert(data.shaderType == .Mesh, "% only exists in mesh shaders", cd.name);
            assert(indicesIndex == cast(int) data.primitiveTopology, "% is for % mesh shaders, this one outputs %", cd.name, MESH_PRIMITIVE_INDICES[indicesIndex].topology, data.primitiveTopology);

            tia := CreateTypeInfoArrayFixedSize(GetArrayElementType(cd), data.maxPrimitives);
            TableAdd(*data.codeNodeTypes, node, tia);
            return tia;
         } else if (cd == data.meshVertexOutVariableIdentifier.variable.declaration) {
            elementType := GetArrayElementType(cd);
            tia := CreateTypeInfoArrayFixedSize(elementType, data.maxVertices);
            TableAdd(*data.codeNodeTypes, node, tia);
            return tia;
         } else if (cd == data.meshPrimitiveOutVariableIdentifier.variable.declaration) {
            elementType := GetArrayElementType(cd);
            tia := CreateTypeInfoArrayFixedSize(elementType, data.maxPrimitives);
            TableAdd(*data.codeNodeTypes, node, tia);
            return tia;
         }

         type := ConvertJaiTypeIfNecessary(cd.type, cd.notes);
         storageClass := GetVariableStorageClass(data, .{ type = .Variable, variable.declaration = cd });

         // workgroup variables dont have an explicit layout either (that would need WorkgroupMemoryExplicitLayoutKHR)
         isLocalDeclaration := storageClass == .Function || storageClass == .Workgroup;

         if (storageClass == .Workgroup) {
            assert(data.shaderType == .Compute || data.shaderType == .Mesh || data.shaderType == .Task, "workgroup variables only exist in compute, mesh and task shaders. loc: %", GetLocationString(node));
            assert(cd.expression == null, "a workgroup variable cant be initialized, it is shared by all the invocations of the workgroup. loc: %", GetLocationString(node));
         }

         // i am not sure but this might need to be recursive.
         // that is if a member is also a struct i might need to recurse into it too. idk
         //          - apila, 07/06/26
         //
         // since i dont have a proper vector type, i have to manually check, again.
         //          - apila, 07/06/26
         if (isLocalDeclaration) {
            type = GetFunctionStorageClassType(type);
         }

         TableAdd(*data.codeNodeTypes, node, type);
         return type;

      case .CAST;
         cc := cast(*Code_Cast) node;

         // cast(T) *x is x. see IsCastOfAddressToPointee
         if (IsCastOfAddressToPointee(cc)) {
            type := DetermineCodeNodeTypes(data, (cast(*Code_Unary_Operator) cc.expression).subexpression);
            TableAdd(*data.codeNodeTypes, node, type);
            return type;
         }

         castFrom := DetermineCodeNodeTypes(data, cc.expression);

         // you cant change storage classes with casts
         // so the resulting pointer has the same storage class as the casted pointer
         if (cc.type.type == .POINTER) {
            assert(castFrom.type == TYPE_INFO_POINTER_TAG, "type: %", castFrom.type);
            tipCastFrom := cast(*TypeInfoPointer) castFrom;

            indirectionLevel := GetIndirectionLevelSpirvPointer(tipCastFrom);
            newPointers := NewArray(indirectionLevel, TypeInfoPointer);

            // pointerTo
            for 0..indirectionLevel - 2 {
               current := newPointers[it];
               next := newPointers[it + 1];

               current.pointerTo = *next;
            }
            newPointers[newPointers.count - 1].pointerTo = GetBaseType(cc.type);

            // storage classes
            storageClasses := FlattenStorageClasses(castFrom);
            assert(storageClasses.count == newPointers.count, "storageClasses.count: %, newPointers.count: %", storageClasses.count, newPointers.count);

            for storageClasses {
               newPointers[it_index].storageClass = it;
            }

            TableAdd(*data.codeNodeTypes, node, *newPointers[0]);
            return *newPointers[0];
         }

         TableAdd(*data.codeNodeTypes, node, cc.type);
         return cc.type;

      case .RETURN;
         cr := cast(*Code_Return) node;
         for cr.arguments_unsorted {
            DetermineCodeNodeTypes(data, it.expression);
         }

         for cr.arguments_sorted {
            DetermineCodeNodeTypes(data, it);
         }

         // return statement doesnt have any type
         TableAdd(*data.codeNodeTypes, node, cast(*Type_Info) void);
         return cast(*Type_Info) void;

      case .IF; {
         ci := cast(*Code_If) node;

         if (ci.if_flags & .IS_STATIC) {
            takenBlock := GetStaticIfTakenBlock(ci);
            if (takenBlock != null) DetermineCodeNodeTypes(data, takenBlock);

            TableAdd(*data.codeNodeTypes, node, cast(*Type_Info) void);
            return cast(*Type_Info) void;
         }

         if (ci.if_flags & .IS_SWITCH_STATEMENT) {
            DetermineCodeNodeTypes(data, ci.condition);
            for GetSwitchCases(ci) {
               if (it.condition != null) DetermineCodeNodeTypes(data, it.condition);
               DetermineCodeNodeTypes(data, it.then_block);
            }

            TableAdd(*data.codeNodeTypes, node, cast(*Type_Info) void);
            return cast(*Type_Info) void;
         }

         if (ci.if_flags & .IS_IFX) {
            assert(ci.then_block != null && ci.else_block != null, "ifx without else is not supported. loc: %", GetLocationString(node));
            DetermineCodeNodeTypes(data, ci.condition);
            DetermineCodeNodeTypes(data, ci.then_block);
            DetermineCodeNodeTypes(data, ci.else_block);

            TableAdd(*data.codeNodeTypes, node, ci.type);
            return ci.type;
         }

         if (ci.condition != null) {
            DetermineCodeNodeTypes(data, ci.condition);
         }

         if (ci.then_block != null) {
            DetermineCodeNodeTypes(data, ci.then_block);
         }

         if (ci.else_block != null) {
            DetermineCodeNodeTypes(data, ci.else_block);
         }

         // this prolly needs to change when i support ifx     - apila, 07/05/26
         TableAdd(*data.codeNodeTypes, node, cast(*Type_Info) void);
         return cast(*Type_Info) void;
      }

      case .WHILE; {
         cw := cast(*Code_While) node;

         if (cw.condition) {
            DetermineCodeNodeTypes(data, cw.condition);
         }

         if (cw.block) {
            DetermineCodeNodeTypes(data, cw.block);
         }

         TableAdd(*data.codeNodeTypes, node, cast(*Type_Info) void);
         return cast(*Type_Info) void;
      }

      case .LOOP_CONTROL; {
         clc := cast(*Code_Loop_Control) node;

         TableAdd(*data.codeNodeTypes, node, cast(*Type_Info) void);
         return cast(*Type_Info) void;
      }

      case .UNARY_OPERATOR; {
         cuo := cast(*Code_Unary_Operator) node;
         assert(cuo.subexpression != null);

         subexpressionType := DetermineCodeNodeTypes(data, cuo.subexpression);

         resultType: *Type_Info;
         if cuo.operator_type == {
            case #char "-"; #through;
            case #char "!"; #through;
            case #char "~"; {
               resultType = cuo.type;
            }

            // .A, a value of an enum whose type is inferred
            case #char "."; {
               resultType = subexpressionType;
            }

            case .POINTER_DEREFERENCE; #through;
            case .POSTFIX_DEREFERENCE; {
               assert(subexpressionType.type == TYPE_INFO_POINTER_TAG, "can only derefence a pointer! type: %", subexpressionType.type);

               tip := cast(*TypeInfoPointer) subexpressionType;
               resultType = tip.pointerTo;
            }

            case #char "*"; {
               tip := New(TypeInfoPointer);

               //
               // how can i know the storage class of the subexpression?
               // idk. my brain not working at the moment. but today i learned that having a pointer to something stored in Function storage class is not valid
               // so here im gonna say it is Physical which means pointer stuff only works if the pointer points to somewhere in Physical storage class. this is the restriction of my compiler from now on.
               //
               //          - apila, 29/05/26
               //
               // it is the storage class of the memory the subexpression is in (see GetLValueStorageClass). taking the address of a local variable is still an error, see the .UNARY_OPERATOR case of GenerateInstructions.
               //

               tip.storageClass = GetLValueStorageClass(data, cuo.subexpression);
               tip.pointerTo = subexpressionType;
            }

            case; assert(false, "not yet implemented! type: %", cuo.operator_type);
         }

         TableAdd(*data.codeNodeTypes, node, resultType);
         return resultType;
      }

      case .FOR; {
         cf := cast(*Code_For) node;

         // a for_expansion. the compiler gives its expansion, with the body of the loop inserted
         if (cf.macro_expansion_procedure_call != null) {
            DetermineCodeNodeTypes(data, cf.macro_expansion_procedure_call);
            TableAdd(*data.codeNodeTypes, node, cast(*Type_Info) void);
            return cast(*Type_Info) void;
         }

         DetermineCodeNodeTypes(data, cf.iteration_expression);
         if (cf.iteration_expression_right != null) DetermineCodeNodeTypes(data, cf.iteration_expression_right);

         nodes := GetForLoopNodes(data, cf);
         if (nodes.indexDeclaration != null) DetermineCodeNodeTypes(data, nodes.indexDeclaration);
         if (nodes.element != null) DetermineCodeNodeTypes(data, nodes.element);
         if (nodes.count != null)   DetermineCodeNodeTypes(data, nodes.count);

         //
         // for * array: it is a pointer to the element. it is not a variable, it is the address of array[it_index] (a pointer to a local variable cant be stored in spirv).
         // where it is used it is generated as the address, and it.member as array[it_index].member (see DoDotsAndArraySubscripts).
         //
         if (cf.for_flags & .POINTER) {
            assert(nodes.element != null, "for * over a range. loc: %", GetLocationString(cf));

            pointerType := New(TypeInfoPointer);
            pointerType.pointerTo = GetNodeType(nodes.element);
            pointerType.storageClass = GetLValueStorageClass(data, nodes.element);

            TableAdd(*data.codeNodeTypes, cf.ident_decl, pointerType);
            TableAdd(*data.pointerIterators, cf.ident_decl, cf);
         } else {
            DetermineCodeNodeTypes(data, cf.ident_decl);
         }

         DetermineCodeNodeTypes(data, cf.block);

         TableAdd(*data.codeNodeTypes, node, cast(*Type_Info) void);
         return cast(*Type_Info) void;
      }

      case .EXTRACT; {
         ce := cast(*Code_Extract) node;

         // a value of a compound declaration: a, b := F();  or  a, b := x, y;
         if (ce.from != null) {
            type: *Type_Info;
            if (ce.from.kind == .COMMA_SEPARATED_ARGUMENTS) {
               type = DetermineCodeNodeTypes(data, (cast(*Code_Comma_Separated_Arguments) ce.from).arguments[ce.index].node);
            } else {
               assert(ce.from.kind == .PROCEDURE_CALL, "kind: %, loc: %", ce.from.kind, GetLocationString(node));
               DetermineCodeNodeTypes(data, ce.from);
               header := GetHeaderFromCodeProcedureCall(cast(*Code_Procedure_Call) ce.from);
               type = GetMultipleReturnValueType(cast(*Type_Info_Procedure) header.type, ce.index);
            }

            TableAdd(*data.codeNodeTypes, node, type);
            return type;
         }

         argument := GetMacroExpansionArgument(data, ce.index);
         type := DetermineCodeNodeTypes(data, argument);
         TableAdd(*data.codeNodeTypes, node, type);
         return type;
      }

      // a, b := F();   a, b := x, y;   a, b = b, a;
      case .COMPOUND_DECLARATION; {
         ccd := cast(*Code_Compound_Declaration) node;
         source := ccd.declaration_properties.expression;
         if (source != null) DetermineCodeNodeTypes(data, source);
         for ccd.comma_separated_assignment.arguments  DetermineCodeNodeTypes(data, it.node);

         TableAdd(*data.codeNodeTypes, node, cast(*Type_Info) void);
         return cast(*Type_Info) void;
      }

      case .COMMA_SEPARATED_ARGUMENTS; {
         csa := cast(*Code_Comma_Separated_Arguments) node;
         for csa.arguments  DetermineCodeNodeTypes(data, it.node);

         TableAdd(*data.codeNodeTypes, node, cast(*Type_Info) void);
         return cast(*Type_Info) void;
      }

      case .DIRECTIVE_INSERT; {
         cdi := cast(*Code_Directive_Insert) node;
         assert(cdi.expansion != null, "the compiler didnt give the expansion of #insert. loc: %", GetLocationString(node));
         type := DetermineCodeNodeTypes(data, cdi.expansion);
         TableAdd(*data.codeNodeTypes, node, type);
         return type;
      }

      case .DEFER; {
         cd := cast(*Code_Defer) node;
         DetermineCodeNodeTypes(data, cd.block);
         TableAdd(*data.codeNodeTypes, node, cast(*Type_Info) void);
         return cast(*Type_Info) void;
      }

      // size_of(T). it is a constant, see EvaluateConstant
      case .TYPE_QUERY; {
         ctq := cast(*Code_Type_Query) node;
         assert(ctq.query_kind == .SIZE_OF, "% is not supported in a shader. loc: %", ctq.query_kind, GetLocationString(node));
         TableAdd(*data.codeNodeTypes, node, node.type);
         return node.type;
      }

      case .DIRECTIVE_RUN;
         assert(false, "the jai compiler doesnt give the result of #run to the metaprogram, so it cant be used in a shader. loc: %", GetLocationString(node));

      case; assert(false, "not yet implemented! kind: %", node.kind);
   }

   assert(false, "didnt return! kind: %", node.kind);
   return null;
}

GetArrayViewTypeInfo :: (elementType: *Type_Info) -> *Type_Info_Struct {
   found, result := table_find(*arrayViewTypeInfos, elementType);
   if (found) return result;

   // the only wrong thing here is the type of the data pointer which i fix.
   // it is a copy, the type info of the struct is shared by all the array views.
   base := type_info(struct { count: int; data: *void; });
   result = New(Type_Info_Struct);
   result.* = base.*;
   result.members = array_copy(base.members);

   dataType := New(Type_Info_Pointer);
   dataType.type = .POINTER;
   dataType.runtime_size = 8;
   dataType.pointer_to = elementType;
   result.members[1].type = dataType;

   table_add(*arrayViewTypeInfos, elementType, result);
   return result;
}

arrayViewTypeInfos: Table(*Type_Info, *Type_Info_Struct);

IsTraceRayFunction :: (cph: *Code_Procedure_Header) -> bool {
   return cph.name == TRACE_RAY_FUNCTION_NAME;
}

//
// spirv only allows to break out of (or continue) the innermost loop. to exit a loop from inside a loop that is inside of it (break i; continue i; or a return in a macro),
// the exit is stored in a variable and the inner loops are broken out of one by one. after each loop the variable is checked:
//    pending = exit;   break;          (inner loop)
//    ...
//    // after the inner loop (see EndLoop)
//    switch pending {
//       case exit to a loop outside of this one:   break;
//       case exit to this loop:                    pending = 0; break; (or continue;)
//    }
// the defers of the scopes that are exited must be generated before this.
//
GenerateLoopExit :: (data: *CompilationData, targetIndex: int, isContinue: bool, general: *BuilderType, function: *BuilderType) {
   target := data.loopStack[targetIndex];
   innermost := data.loopStack[data.loopStack.count - 1];

   if (targetIndex == data.loopStack.count - 1) {
      WriteSingleInstructionIfReachable(function, *data.isBlockReachable, .Branch, ifx isContinue then target.continueLabelSSAId else target.mergeLabelSSAId);
      return;
   }

   if (!data.isBlockReachable) return;

   if (data.pendingExitVariableSSAId == 0) {
      // written directly, the variable must exist even if the current block is not reachable. it is zero when the function starts.
      storageClass := SpvStorageClass.Function;
      data.pendingExitVariableSSAId = GetNextSSAId(data);
      WriteSingleInstruction(
         general,
         .Variable,
         GetSSAId(data, .{ type = ._Type, _type = GetPointerType(cast(*Type_Info) s32, storageClass) }),
         data.pendingExitVariableSSAId,
         storageClass,
         GetSSAId(data, .{ type = .IntLiteral, intLiteral = .{ unsigned = false, value._s64 = 0, bitSize = 32 } })
      );
   }

   code := cast(s32) ((targetIndex + 1) * 2 + cast(int) isContinue);
   for targetIndex + 1..data.loopStack.count - 1 {
      loop := data.loopStack[it];
      array_add_if_unique(*loop.crossingExitCodes, code);
   }

   codeSSAId := GetSSAId(data, .{ type = .IntLiteral, intLiteral = .{ unsigned = false, value._s64 = code, bitSize = 32 } });
   WriteSingleInstructionIfReachable(function, *data.isBlockReachable, .Store, data.pendingExitVariableSSAId, codeSSAId);
   WriteSingleInstructionIfReachable(function, *data.isBlockReachable, .Branch, innermost.mergeLabelSSAId);
}

// pops the loop. must be called right after the merge block of the loop is started. continues the exits that go out of the loop (see GenerateLoopExit).
EndLoop :: (data: *CompilationData, function: *BuilderType) {
   loop := pop(*data.loopStack);
   if (loop.crossingExitCodes.count == 0) return;

   assert(data.loopStack.count > 0);
   enclosingIndex := data.loopStack.count - 1;
   enclosing := data.loopStack[enclosingIndex];

   s32TypeSSAId := GetSSAId(data, .{ type = ._Type, _type = cast(*Type_Info) s32 });
   pendingSSAId := GetNextSSAId(data);
   WriteSingleInstructionIfReachable(function, *data.isBlockReachable, .Load, s32TypeSSAId, pendingSSAId, data.pendingExitVariableSSAId);

   mergeLabelSSAId := GetNextSSAId(data);
   labels := NewArray(loop.crossingExitCodes.count, SSAId,, temp);
   for * labels  it.* = GetNextSSAId(data);

   operands: [..] Any;
   operands.allocator = temp;
   array_add(*operands, pendingSSAId, mergeLabelSSAId);
   for loop.crossingExitCodes  array_add(*operands, ac(cast(u32) it), ac(labels[it_index]));

   WriteSingleInstructionIfReachable(function, *data.isBlockReachable, .SelectionMerge, mergeLabelSSAId, SpvSelectionControlMask.MaskNone);
   WriteSingleInstructionIfReachable(function, *data.isBlockReachable, .Switch, .. operands);

   for code: loop.crossingExitCodes {
      WriteSingleInstructionIfReachable(function, *data.isBlockReachable, .Label, labels[it_index]);

      targetIndex := code / 2 - 1;
      isContinue := (code % 2) == 1;

      if (targetIndex == enclosingIndex) {
         zeroSSAId := GetSSAId(data, .{ type = .IntLiteral, intLiteral = .{ unsigned = false, value._s64 = 0, bitSize = 32 } });
         WriteSingleInstructionIfReachable(function, *data.isBlockReachable, .Store, data.pendingExitVariableSSAId, zeroSSAId);
         WriteSingleInstructionIfReachable(function, *data.isBlockReachable, .Branch, ifx isContinue then enclosing.continueLabelSSAId else enclosing.mergeLabelSSAId);
      } else {
         // the exit is for a loop further out. it is in the crossingExitCodes of the enclosing loop too
         WriteSingleInstructionIfReachable(function, *data.isBlockReachable, .Branch, enclosing.mergeLabelSSAId);
      }
   }

   WriteSingleInstructionIfReachable(function, *data.isBlockReachable, .Label, mergeLabelSSAId);
}

// generates the deferred blocks above "downTo" in CompilationData.deferStack, the last one first. they are not popped, the scope that pushed them pops them when it ends.
GenerateDefers :: (data: *CompilationData, downTo: int, general: *BuilderType, function: *BuilderType, currentFunction: *Code_Procedure_Header) {
   for < i: downTo..data.deferStack.count - 1 {
      GenerateInstructions(data, data.deferStack[i].block, general, function, currentFunction);
   }
}

// a top level statement of a macro expansion. returns false if it is a return, the caller handles it.
GenerateMacroStatement :: (data: *CompilationData, node: *Code_Node, general: *BuilderType, function: *BuilderType, currentFunction: *Code_Procedure_Header) -> bool {
   if (node.kind == .RETURN) return false;

   if (node.kind == .DEFER && (cast(*Code_Defer) node).is_backticked) {
      // it goes under the defers of the macro so it runs after them, when the scope the macro is called from ends
      base := *data.macroDeferBases[data.macroDeferBases.count - 1];
      array_insert_at(*data.deferStack, cast(*Code_Defer) node, base.*);
      base.* += 1;
      return true;
   }

   GenerateInstructions(data, node, general, function, currentFunction);
   return true;
}

IsMacroProcedure :: (header: *Code_Procedure_Header) -> bool {
   return (header.procedure_flags & .MACRO) != 0;
}

MacroReturnData :: struct {
   resultVariableSSAId:    SSAId;      // 0 if the macro doesnt return a value
   resultType:             *Type_Info; // type of the result variable
   loopIndex:              int;        // the loop the expansion is in (CompilationData.loopStack). a return is a break out of it
}

// true if the macro returns from somewhere other than its last top-level statement, for example from inside an if.
MacroHasEarlyReturn :: (expansion: *Code_Block) -> bool {
   ContainsReturn :: (node: *Code_Node) -> bool {
      if (node == null) return false;

      if node.kind == {
         case .RETURN;  return true;
         case .BLOCK;
            for (cast(*Code_Block) node).statements  if ContainsReturn(it) return true;
         case .IF;
            ci := cast(*Code_If) node;
            if (ci.if_flags & .IS_STATIC) return ContainsReturn(GetStaticIfTakenBlock(ci));
            return ContainsReturn(ci.then_block) || ContainsReturn(ci.else_block);
         case .CASE;    return ContainsReturn((cast(*Code_Case) node).then_block);
         case .WHILE;   return ContainsReturn((cast(*Code_While) node).block);
         case .FOR;     return ContainsReturn((cast(*Code_For) node).block);
      }

      return false;
   }

   for expansion.statements {
      isLast := it_index == expansion.statements.count - 1;
      if (isLast && it.kind == .RETURN) continue;
      if (ContainsReturn(it)) return true;
   }

   return false;
}

GetMacroExpansionReturn :: (expansion: *Code_Block) -> *Code_Return {
   result: *Code_Return = null;

   for expansion.statements {
      if (it.kind != .RETURN) continue;

      assert(result == null, "a macro expansion may only have one top-level return");
      result = cast(*Code_Return) it;
   }

   return result;
}

GetMacroExpansionArgument :: (data: *CompilationData, index: s64) -> *Code_Node {
   assert(data.macroExpansionCalls.count > 0, "Code_Extract appeared outside a macro expansion");
   assert(index >= 0);

   // the index is the index of the parameter, so it indexes the arguments in the order of the parameters (named arguments and defaults are already placed by the compiler).
   call := data.macroExpansionCalls[data.macroExpansionCalls.count - 1];
   assert(index < call.arguments_sorted.count, "macro argument index: %, count: %", index, call.arguments_sorted.count);
   return call.arguments_sorted[index];
}

UnwindVariantsUpToDistinct :: #bake_arguments UnwindVariants(ignoreDistinct = false);
UnwindVariantsAllTheWay :: #bake_arguments UnwindVariants(ignoreDistinct = true);

//
// the jai compiler doesnt fold constants. N :: 4 * 2; is given to the metaprogram as the binary operator, not as 8.
// spirv constants must be literals (OpSpecConstantOp could do some of it but not everything), so constant expressions are evaluated here.
// only what is needed for numbers is implemented: literals, constants, values of enums, unary and binary operators, casts and size_of.
// anything else is not a constant as far as this compiler is concerned and its instructions are generated as usual.
//
ConstantValue :: struct {
   kind: enum u8 {
      Int;
      Float;
      Bool;
   };

   bits:     u64;     // Int. sign extended to 64 bits if the type is signed
   _float64: float64; // Float
   _bool:    bool;    // Bool
}

// returns false if the node is not a constant (or it is a constant this function doesnt know how to evaluate)
EvaluateConstant :: (data: *CompilationData, node: *Code_Node) -> ConstantValue, bool {
   INT   :: (bits: u64)     -> ConstantValue #expand { return .{ kind = .Int,   bits = bits }; }
   FLOAT :: (f: float64)    -> ConstantValue #expand { return .{ kind = .Float, _float64 = f }; }
   BOOL  :: (b: bool)       -> ConstantValue #expand { return .{ kind = .Bool,  _bool = b }; }

   if (node == null) return .{}, false;

   if node.kind == {
      case .LITERAL;
         cl := cast(*Code_Literal) node;
         if (cl.value_type == .BOOLEAN) return BOOL(cl._u64 != 0), true;
         if (cl.value_type != .NUMBER) return .{}, false;

         // like the .LITERAL case of GenerateInstructions, the type decides how the value is stored. number literals inside untyped struct literals have no type, then the flags do.
         type := UnwindEnum(node.type);
         isFloat := ifx type.type == .FLOAT || type.type == .INTEGER then type.type == .FLOAT else (cl.value_flags & .FLOAT) != 0;
         if (isFloat) return FLOAT(cl._float64), true;
         return INT(cl._u64), true;

      case .IDENT;
         declaration := (cast(*Code_Ident) node).resolved_declaration;
         if (declaration == null || !(declaration.flags & .IS_CONSTANT) || declaration.expression == null) return .{}, false;

         value, isConstant := EvaluateConstant(data, declaration.expression);
         if (!isConstant) return .{}, false;
         return ConvertConstant(value, declaration.type), true;

      case .TYPE_QUERY;
         ctq := cast(*Code_Type_Query) node;
         if (ctq.query_kind != .SIZE_OF) return .{}, false;
         assert(ctq.type_to_query != null && ctq.type_to_query.result != null, "loc: %", GetLocationString(node));
         return INT(xx ctq.type_to_query.result.runtime_size), true;

      case .CAST;
         cc := cast(*Code_Cast) node;
         value, isConstant := EvaluateConstant(data, cc.expression);
         if (!isConstant) return .{}, false;

         // float to int truncates. other conversions are done by ConvertConstant
         target := UnwindEnum(node.type);
         if (value.kind == .Float && target.type == .INTEGER) {
            tii := cast(*Type_Info_Integer) target;
            if (tii.signed) value = INT(cast,no_check(u64) cast,no_check(s64) value._float64);
            else            value = INT(cast,no_check(u64) value._float64);
         } else if (value.kind == .Bool && target.type == .INTEGER) {
            value = INT(xx value._bool);
         } else if (value.kind == .Bool && target.type == .FLOAT) {
            value = FLOAT(ifx value._bool then 1.0 else 0.0);
         } else if (value.kind == .Int && target.type == .BOOL) {
            value = BOOL(value.bits != 0);
         } else if (value.kind == .Float && target.type == .BOOL) {
            value = BOOL(value._float64 != 0);
         }

         return ConvertConstant(value, node.type), true;

      case .UNARY_OPERATOR;
         cuo := cast(*Code_Unary_Operator) node;
         value, isConstant := EvaluateConstant(data, cuo.subexpression);
         if (!isConstant) return .{}, false;

         if cuo.operator_type == {
            case #char "."; return value, true; // .A, a value of an enum
            case #char "-";
               if (value.kind == .Int)   return ConvertConstant(INT(xx -cast,no_check(s64) value.bits), node.type), true;
               if (value.kind == .Float) return FLOAT(-value._float64), true;
            case #char "~";
               if (value.kind == .Int)   return ConvertConstant(INT(~value.bits), node.type), true;
            case #char "!";
               if (value.kind == .Bool)  return BOOL(!value._bool), true;
         }

         return .{}, false;

      case .BINARY_OPERATOR;
         cbo := cast(*Code_Binary_Operator) node;

         // E.A or Module.CONSTANT, or the count of a fixed array
         if (cbo.operator_type == #char ".") {
            leftType := cbo.left.type;
            if (leftType != null && leftType.type == .ARRAY && (cast(*Type_Info_Array) leftType).array_type == .FIXED && cbo.right.kind == .IDENT && (cast(*Code_Ident) cbo.right).name == "count") {
               return INT(xx (cast(*Type_Info_Array) leftType).array_count), true;
            }

            // a constant declared in a struct, through the type (S.N) or through a value (s.N)
            rightIsConstant := cbo.right.kind == .IDENT && (cast(*Code_Ident) cbo.right).resolved_declaration != null && ((cast(*Code_Ident) cbo.right).resolved_declaration.flags & .IS_CONSTANT);
            if ((leftType == null || leftType.type != .TYPE) && !rightIsConstant) return .{}, false;
            value, isConstant := EvaluateConstant(data, cbo.right);
            return value, isConstant;
         }

         left, leftIsConstant := EvaluateConstant(data, cbo.left);
         if (!leftIsConstant) return .{}, false;
         right, rightIsConstant := EvaluateConstant(data, cbo.right);
         if (!rightIsConstant) return .{}, false;

         // a literal like the 2 in "x * 2" is an Int even if x is a float
         leftType := UnwindEnum(cbo.left.type);
         if (left.kind == .Int && right.kind == .Float)  left = FLOAT(ToFloat64(left, leftType));
         if (right.kind == .Int && left.kind == .Float)  right = FLOAT(ToFloat64(right, UnwindEnum(cbo.right.type)));
         if (left.kind != right.kind) return .{}, false;

         if (left.kind == .Bool) {
            if cbo.operator_type == {
               case .LOGICAL_AND;   return BOOL(left._bool && right._bool), true;
               case .LOGICAL_OR;    return BOOL(left._bool || right._bool), true;
               case .IS_EQUAL;      return BOOL(left._bool == right._bool), true;
               case .IS_NOT_EQUAL;  return BOOL(left._bool != right._bool), true;
            }
            return .{}, false;
         }

         if (left.kind == .Float) {
            a := left._float64;
            b := right._float64;
            if cbo.operator_type == {
               case #char "+";         return FLOAT(a + b), true;
               case #char "-";         return FLOAT(a - b), true;
               case #char "*";         return FLOAT(a * b), true;
               case #char "/";         return FLOAT(a / b), true;
               case #char "<";         return BOOL(a < b), true;
               case #char ">";         return BOOL(a > b), true;
               case .LESS_OR_EQUAL;    return BOOL(a <= b), true;
               case .GREATER_OR_EQUAL; return BOOL(a >= b), true;
               case .IS_EQUAL;         return BOOL(a == b), true;
               case .IS_NOT_EQUAL;     return BOOL(a != b), true;
            }
            return .{}, false;
         }

         // integers. the signedness of the operands decides how division, remainder, shifting right and comparisons work.
         signed := true;
         if (leftType.type == .INTEGER) signed = (cast(*Type_Info_Integer) leftType).signed;

         a := left.bits;
         b := right.bits;
         sa := cast,no_check(s64) a;
         sb := cast,no_check(s64) b;

         result: ConstantValue;
         if cbo.operator_type == {
            case #char "+"; result = INT(a + b);
            case #char "-"; result = INT(a - b);
            case #char "*"; result = INT(a * b);
            case #char "/";
               if (b == 0) return .{}, false;
               result = INT(ifx signed then cast,no_check(u64) (sa / sb) else a / b);
            case #char "%";
               if (b == 0) return .{}, false;
               result = INT(ifx signed then cast,no_check(u64) (sa % sb) else a % b);
            case #char "&";         result = INT(a & b);
            case #char "|";         result = INT(a | b);
            case #char "^";         result = INT(a ^ b);
            case .SHIFT_LEFT;       result = INT(a << b);
            case .SHIFT_RIGHT;      result = INT(ifx signed then cast,no_check(u64) (sa >> b) else a >> b);
            case #char "<";         return BOOL(ifx signed then sa < sb  else a < b), true;
            case #char ">";         return BOOL(ifx signed then sa > sb  else a > b), true;
            case .LESS_OR_EQUAL;    return BOOL(ifx signed then sa <= sb else a <= b), true;
            case .GREATER_OR_EQUAL; return BOOL(ifx signed then sa >= sb else a >= b), true;
            case .IS_EQUAL;         return BOOL(a == b), true;
            case .IS_NOT_EQUAL;     return BOOL(a != b), true;
            case;                   return .{}, false;
         }

         return ConvertConstant(result, node.type), true;

      case .DIRECTIVE_RUN;
         assert(false, "the jai compiler doesnt give the result of #run to the metaprogram, so it cant be used in a shader. loc: %", GetLocationString(node));
   }

   return .{}, false;
}

ToFloat64 :: (value: ConstantValue, type: *Type_Info) -> float64 {
   assert(value.kind == .Int);
   if (type != null && type.type == .INTEGER && !(cast(*Type_Info_Integer) type).signed) return cast(float64) value.bits;
   return cast(float64) cast,no_check(s64) value.bits;
}

// wraps an integer to the size of the type (and sign extends it if it is signed), an integer becomes a float if the type is float.
ConvertConstant :: (value: ConstantValue, type_: *Type_Info) -> ConstantValue {
   if (type_ == null) return value;
   type := UnwindEnum(type_);

   if (value.kind == .Int && type.type == .FLOAT) {
      return .{ kind = .Float, _float64 = ToFloat64(value, null) };
   }

   if (value.kind == .Int && type.type == .INTEGER && type.runtime_size < 8) {
      bitSize := type.runtime_size * 8;
      mask := (cast(u64) 1 << bitSize) - 1;
      bits := value.bits & mask;

      if ((cast(*Type_Info_Integer) type).signed && (bits & (cast(u64) 1 << (bitSize - 1)))) {
         bits |= ~mask;
      }

      return .{ kind = .Int, bits = bits };
   }

   return value;
}

// the identifier of the constant in spirv. returns false if it cant be a constant of that type (for example if the type is not a scalar)
ConstantToIdentifier :: (value: ConstantValue, type_: *Type_Info) -> Identifier, bool {
   if (type_ == null) return .{}, false;
   type := UnwindEnum(type_);
   info, isNumeric := GetNumericInfo(type);
   if (!isNumeric || info.components != 1) return .{}, false;

   if info.kind == {
      case .Bool;
         if (value.kind != .Bool) return .{}, false;
         return .{ type = .BoolLiteral, boolLiteral = value._bool }, true;

      case .Float;
         if (value.kind == .Bool) return .{}, false;
         f := ifx value.kind == .Float then value._float64 else ToFloat64(value, null);
         return FloatLiteralIdentifier(f, info.bitSize), true;

      case .Signed; #through;
      case .Unsigned;
         if (value.kind != .Int) return .{}, false;
         converted := ConvertConstant(value, type);

         identifier: Identifier = .{ type = .IntLiteral, intLiteral = .{ unsigned = info.kind == .Unsigned, bitSize = info.bitSize } };
         identifier.intLiteral.value._u64 = converted.bits;
         return identifier, true;
   }

   return .{}, false;
}

NumericUses :: struct {
   integers16: bool;
   floats64:   bool;
}

// the scalar types a type has in it (the members of structs, the elements of arrays, what pointers point to...)
VisitedTypes :: Table(*Type_Info, bool);

CollectNumericUses :: (type: *Type_Info, uses: *NumericUses, visited: *VisitedTypes) {
   if (type == null || table_contains(visited, type)) return;
   table_add(visited, type, true);

   info, isNumeric := GetNumericInfo(type);
   if (isNumeric) {
      if ((info.kind == .Signed || info.kind == .Unsigned) && info.bitSize == 16) uses.integers16 = true;
      if (info.kind == .Float && info.bitSize == 64) uses.floats64 = true;
      return;
   }

   if type.type == {
      case .STRUCT;
         for GetStructMembers(cast(*Type_Info_Struct) type)  CollectNumericUses(ConvertJaiTypeIfNecessary(it.type, it.notes), uses, visited);
      case TYPE_INFO_DECORATIONLESS_COPY_OF_STRUCT_TAG;
         CollectNumericUses((cast(*TypeInfoDecorationlessCopyOfStruct) type).copyOf, uses, visited);
      case .ARRAY;
         CollectNumericUses((cast(*Type_Info_Array) type).element_type, uses, visited);
      case .VARIANT;
         CollectNumericUses(UnwindVariantsAllTheWay(type), uses, visited);
      case .POINTER;
         CollectNumericUses((cast(*Type_Info_Pointer) type).pointer_to, uses, visited);
      case TYPE_INFO_POINTER_TAG;
         CollectNumericUses((cast(*TypeInfoPointer) type).pointerTo, uses, visited);
      case TYPE_INFO_RUNTIME_ARRAY_TAG;
         CollectNumericUses((cast(*TypeInfoRuntimeArray) type).elementType, uses, visited);
      case .PROCEDURE;
         tip := cast(*Type_Info_Procedure) type;
         for tip.argument_types  CollectNumericUses(it, uses, visited);
         for tip.return_types    CollectNumericUses(it, uses, visited);
   }
}

// a float constant of 32 or 64 bits
FloatLiteralIdentifier :: (value: float64, bitSize: int) -> Identifier {
   if (bitSize == 64) return .{ type = .Float64Literal, float64Literal = value };
   assert(bitSize == 32, "bitSize: %", bitSize);
   return .{ type = .FloatLiteral, floatLiteral = cast(float32) value };
}

// an enum is its integer type in spirv. the values of the enum are constants of that type.
UnwindEnum :: (type: *Type_Info) -> *Type_Info {
   if (type.type == .ENUM) return (cast(*Type_Info_Enum) type).internal_type;
   return type;
}

UnwindVariants :: (type: *Type_Info, ignoreDistinct: bool) -> *Type_Info {
   current := type;
   while (current.type == .VARIANT) {
      tiv := cast(*Type_Info_Variant) current;

      if (!ignoreDistinct && tiv.variant_flags & .DISTINCT) {
         break;
      }

      current = tiv.variant_of;
   }

   return current;
}

GetHeaderFromCodeProcedureCall :: (cpc: *Code_Procedure_Call) -> *Code_Procedure_Header {
   GetHeaderFromCodeIdent :: (ci: *Code_Ident) -> *Code_Procedure_Header #expand {
      assert(ci.resolved_declaration.type_inst.type_valued_expression.kind == .PROCEDURE_HEADER, "kind: %", ci.resolved_declaration.type_inst.type_valued_expression);
      return xx ci.resolved_declaration.type_inst.type_valued_expression;
   }

   header: *Code_Procedure_Header;
   if (cpc.resolved_procedure_expression.kind == .IDENT) {
      ci := cast(*Code_Ident) cpc.resolved_procedure_expression;
      header = GetHeaderFromCodeIdent(ci);
   } else if (cpc.resolved_procedure_expression.kind == .PROCEDURE_HEADER) {
      header = cast(*Code_Procedure_Header) cpc.resolved_procedure_expression;
   } else if (cpc.resolved_procedure_expression.kind == .BINARY_OPERATOR) {
      cbo := cast(*Code_Binary_Operator) cpc.resolved_procedure_expression;

      assert(cbo.right.kind == .IDENT, "type: %", cbo.right.type);
      ci := cast(*Code_Ident) cbo.right;

      header = GetHeaderFromCodeIdent(ci);
   } else {
      assert(false);
   }

   return header;
}

// when jblow does the thing in the below comment i need to add #align to vector and matrix types.
//       - apila, 09/06/26

// jblow said on discord that he will move the alignment field from Code_Struct to Type_Info_Struct. so i can properly implement this function
// alignment of a type in the target program.
//
// for structs the compiler computes the alignment (taking #align into account) but in this version Type_Info_Struct.alignment is -1 for the types a
// metaprogram sees. Code_Struct.alignment is filled in though, so it is read from the definition of the struct (see structDefinitions).
alignof :: (type: *Type_Info) -> s64 {
   if type.type == {
      case .INTEGER;    #through;
      case .FLOAT;      #through;
      case .BOOL;       #through;
      case .POINTER;
         return type.runtime_size;

      case .ENUM;
         return (cast(*Type_Info_Enum) type).internal_type.runtime_size;

      case .STRUCT;
         tis := cast(*Type_Info_Struct) type;
         if (tis.alignment >= 1) return tis.alignment;

         // the builtin vectors are also used through the Type_Info of the metaprogram (for example GetNumericType) which is not in structDefinitions.
         // they are structs of scalars without #align so their alignment is the size of a component.
         info, isNumeric := GetNumericInfo(type);
         if (isNumeric) return GetScalarTypeOrVectorElementType(type).runtime_size;

         found, cs := table_find(*structDefinitions, tis);
         assert(found, "the definition of struct % is not known, so its alignment is not known", tis.name);
         assert(cs.alignment >= 1, "the compiler didnt provide the alignment of struct %", tis.name);
         return cs.alignment;

      case .ARRAY;
         tia := cast(*Type_Info_Array) type;
         if tia.array_type == {
            case .FIXED;   return alignof(tia.element_type);
            case .VIEW;    return 8; // struct { count: s64; data: *T; }
            case;          assert(false, "array type: %", tia.array_type); return 0;
         }

      case .VARIANT;
         return alignof(UnwindVariantsAllTheWay(type));

      // the types this compiler creates
      case TYPE_INFO_POINTER_TAG;
         return type.runtime_size;

      case TYPE_INFO_DECORATIONLESS_COPY_OF_STRUCT_TAG;
         return alignof((cast(*TypeInfoDecorationlessCopyOfStruct) type).copyOf);

      case TYPE_INFO_RUNTIME_ARRAY_TAG;
         return alignof((cast(*TypeInfoRuntimeArray) type).elementType);
   }

   assert(false, "type: %", type.type);
   return 0;
}

// use this if the storage class might be PhysicalStorageBuffer.
// if you are sure that it can't be PhysicalStorageBuffer, you can directly use WriteSingleInstructionIfReachable.
// type: spirv type of the thing you store
Store :: (data: *CompilationData, b: *BuilderType, storeTo: SSAId, storeWhat: SSAId, storingToPhysicalStorageBuffer: bool, type: *Type_Info) {
   operands: [..] Any;
   array_add(*operands, storeTo);
   array_add(*operands, storeWhat);

   if (storingToPhysicalStorageBuffer) {
      array_add(*operands, SpvMemoryAccessMask.AlignedMask, alignof(type));
   }

   WriteSingleInstructionIfReachable(
      b,
      *data.isBlockReachable,
      .Store,
      .. operands
   );
}

// maybe only do Aligned only if you are loading from a physical storage buffer.
// tho this requires one additional argument to be passed
Load :: (data: *CompilationData, b: *BuilderType, typeIdentifier: Identifier, loadFrom: SSAId, loadingFromPhysicalStorageBuffer: bool) -> SSAId {
   dereferencedSSAId := GetNextSSAId(data);

   operands: [..] Any;
   array_add(*operands, GetSSAId(data, typeIdentifier));
   array_add(*operands, dereferencedSSAId);
   array_add(*operands, loadFrom);

   if (loadingFromPhysicalStorageBuffer) {
      array_add(*operands, SpvMemoryAccessMask.AlignedMask, alignof(typeIdentifier._type));
   }

   WriteSingleInstructionIfReachable(
      b,
      *data.isBlockReachable,
      .Load,
      .. operands
   );

   return dereferencedSSAId;
}

// this function is used to determine whether i should use OpConstantComposite or OpCompositeConstruct
// so i think it is still fine even if this function returns false all the time
//       - apila, 18/04/26
// a for loop is generated using the existing code for subscripts and member access, so these nodes are created for it:
//    for array  ->  index: s64; while index < array.count { it = array[index]; ... index += 1; }
ForLoopNodes :: struct {
   indexDeclaration:  *Code_Declaration; // it_index, or a declaration created by the backend if the loop doesnt have one. null for ranges (they dont have it_index)
   element:           *Code_Node;        // array[index], null for ranges
   count:             *Code_Node;        // array.count for array views, null for ranges and fixed arrays
}

GetForLoopNodes :: (data: *CompilationData, cf: *Code_For) -> ForLoopNodes {
   found, nodes := table_find(*data.forLoopNodes, cf);
   if (found) return nodes;

   NewNode :: ($T: Type, kind: Code_Node.Kind, type: *Type_Info) -> *T #expand {
      result := New(T);
      result.base = `cf.base; // for the location
      result.kind = kind;
      result.type = type;
      return result;
   }

   isRange := cf.iteration_expression_right != null;

   if (!isRange) {
      nodes.indexDeclaration = cf.index_decl;
      if (nodes.indexDeclaration == null) {
         nodes.indexDeclaration = NewNode(Code_Declaration, .DECLARATION, cast(*Type_Info) s64);
         nodes.indexDeclaration.name = "it_index";
      }

      arrayType := cf.iteration_expression.type;
      assert(arrayType.type == .ARRAY, "can only iterate over arrays and ranges. type: %, loc: %", arrayType.*, GetLocationString(cf));
      tia := cast(*Type_Info_Array) arrayType;
      assert(tia.array_type == .FIXED || tia.array_type == .VIEW, "array type: %, loc: %", tia.array_type, GetLocationString(cf));

      index := NewNode(Code_Ident, .IDENT, nodes.indexDeclaration.type);
      index.name = nodes.indexDeclaration.name;
      index.resolved_declaration = nodes.indexDeclaration;

      element := NewNode(Code_Binary_Operator, .BINARY_OPERATOR, tia.element_type);
      element.operator_type = .ARRAY_SUBSCRIPT;
      element.left = cf.iteration_expression;
      element.right = index;
      nodes.element = element;

      if (tia.array_type == .VIEW) {
         countIdent := NewNode(Code_Ident, .IDENT, cast(*Type_Info) s64);
         countIdent.name = "count";

         count := NewNode(Code_Binary_Operator, .BINARY_OPERATOR, cast(*Type_Info) s64);
         count.operator_type = #char ".";
         count.left = cf.iteration_expression;
         count.right = countIdent;
         nodes.count = count;
      }
   }

   TableAdd(*data.forLoopNodes, cf, nodes);
   return nodes;
}

// the value a declaration without an initializer gets: the default values of the members of a struct (recursively), zero for everything else.
// type can be a decorationless copy of a struct or an array, the result is then converted with OpCopyLogical.
GenerateDefaultValue :: (data: *CompilationData, general: *BuilderType, function: *BuilderType, currentFunction: *Code_Procedure_Header, type: *Type_Info) -> SSAId {
   // zero can be created directly in the decorationless type
   if (!HasDefaultValues(GetDecoratedType(type))) return GetSSAId(data, .{ type = .NullConstant, nullConstant = type });

   jaiType := GetDecoratedType(type);

   identifier := GetDefaultValueIdentifier(data, general, function, currentFunction, jaiType);
   ssaId := GetSSAId(data, identifier);

   if (type != jaiType) {
      convertedSSAId := GetNextSSAId(data);
      WriteSingleInstructionIfReachable(function, *data.isBlockReachable, .CopyLogical, GetSSAId(data, .{ type = ._Type, _type = type }), convertedSSAId, ssaId);
      return convertedSSAId;
   }

   return ssaId;
}

// returns a constant
GetDefaultValueIdentifier :: (data: *CompilationData, general: *BuilderType, function: *BuilderType, currentFunction: *Code_Procedure_Header, type: *Type_Info) -> Identifier {
   if (!HasDefaultValues(type)) return .{ type = .NullConstant, nullConstant = type };

   identifier: Identifier = .{ type = .CompositeLiteral, compositeLiteral = .{ type = type } };

   if (type.type == .ARRAY) {
      tia := cast(*Type_Info_Array) type;
      assert(tia.array_type == .FIXED);

      element := New(Identifier);
      element.* = GetDefaultValueIdentifier(data, general, function, currentFunction, tia.element_type);

      identifier.compositeLiteral.arguments = NewArray(tia.array_count, *Identifier);
      for * identifier.compositeLiteral.arguments  it.* = element;
      return identifier;
   }

   assert(type.type == .STRUCT);
   tis := cast(*Type_Info_Struct) type;
   identifier.compositeLiteral.arguments = NewArray(GetStructMembers(tis).count, *Identifier);

   for GetStructMembers(tis) {
      memberType := ConvertJaiTypeIfNecessary(it.type, it.notes);
      member := New(Identifier);

      defaultValue := GetStructMemberDefaultValue(tis, it_index);
      if (defaultValue != null) {
         DetermineCodeNodeTypes(data, defaultValue);
         _ := GenerateInstructions(data, defaultValue, general, function, currentFunction, .{ spirvShouldHaveBeenType = memberType }, identifierOut = member);
         assert(member.type != .Invalid, "the default value of %.% is not a constant. loc: %", tis.name, it.name, GetLocationString(defaultValue));
      } else {
         member.* = GetDefaultValueIdentifier(data, general, function, currentFunction, memberType);
      }

      identifier.compositeLiteral.arguments[it_index] = member;
   }

   return identifier;
}

// true if zero is not the default value of the type. that is it is a struct (or an array of structs) that has a member with a default value.
HasDefaultValues :: (type: *Type_Info) -> bool {
   if (type.type == .ARRAY) {
      tia := cast(*Type_Info_Array) type;
      return tia.array_type == .FIXED && HasDefaultValues(tia.element_type);
   }

   if (type.type != .STRUCT || IsNumericVector(type)) return false;

   tis := cast(*Type_Info_Struct) type;
   for GetStructMembers(tis) {
      if (GetStructMemberDefaultValue(tis, it_index) != null) return true;
      if (HasDefaultValues(it.type)) return true;
   }

   return false;
}

IsDecorationlessArray :: (type: *Type_Info) -> bool {
   return type.type == .ARRAY && table_contains(*decorationlessArrays, cast(*Type_Info_Array) type);
}

IsDecorationlessType :: (type: *Type_Info) -> bool {
   return type.type == TYPE_INFO_DECORATIONLESS_COPY_OF_STRUCT_TAG || IsDecorationlessArray(type);
}

// returns the type a decorationless type is a copy of
GetDecoratedType :: (type: *Type_Info) -> *Type_Info {
   if (type.type == TYPE_INFO_DECORATIONLESS_COPY_OF_STRUCT_TAG) return (cast(*TypeInfoDecorationlessCopyOfStruct) type).copyOf;

   if (type.type == .ARRAY) {
      found, original := table_find(*decorationlessArrays, cast(*Type_Info_Array) type);
      if (found) return original;
   }

   return type;
}

// structs in Function storage class must not have offset decorations, so they use a decorationless copy of the struct.
// (vectors are structs too but they become OpTypeVector so they dont need it)
// this is recursive: the members of a decorationless copy are decorationless too (see WriteTypeOrVariableOrConstant), and so are the elements of arrays.
GetFunctionStorageClassType :: (type: *Type_Info) -> *Type_Info {
   if (type.type == .ARRAY) {
      tia := cast(*Type_Info_Array) type;
      if (tia.array_type != .FIXED) return type;

      if (IsDecorationlessArray(tia)) return type;

      newType := New(Type_Info_Array);
      newType.* = tia.*;
      newType.element_type = GetFunctionStorageClassType(tia.element_type);
      TableAdd(*decorationlessArrays, newType, tia);
      return newType;
   }

   if (type.type != .STRUCT || IsNumericVector(type)) return type;

   newType := New(TypeInfoDecorationlessCopyOfStruct);
   newType.runtime_size = type.runtime_size;
   newType.copyOf = xx type;
   return newType;
}

// the block of a static if (#if) that the compiler took. null if no block is taken.
// the other blocks are not typechecked by the compiler so they must be ignored.
GetStaticIfTakenBlock :: (ci: *Code_If) -> *Code_Block {
   assert((ci.if_flags & .IS_STATIC) != 0);

   if (ci.if_flags & .IS_SWITCH_STATEMENT) {
      if (ci.static_if_accepted_case == null) return null;
      return ci.static_if_accepted_case.then_block;
   }

   if (ci.static_if_flags & .EVALUATED_AS_TRUE) return ci.then_block;
   return ci.else_block;
}

// the cases of a switch statement (if x == { case ...; }). the compiler puts them in the then block.
GetSwitchCases :: (ci: *Code_If) -> [] *Code_Case {
   assert((ci.if_flags & .IS_SWITCH_STATEMENT) != 0);

   result := NewArray(ci.then_block.statements.count, *Code_Case);
   for ci.then_block.statements {
      assert(it.kind == .CASE, "kind: %, loc: %", it.kind, GetLocationString(it));
      result[it_index] = cast(*Code_Case) it;
   }

   return result;
}

//
// switch statements:
//    if x == {
//       case 1; ...
//       case 2; ... #through;
//       case;   ...
//    }
// become an OpSwitch. #through is the fallthrough of OpSwitch. the cases are written in the order of the source, so a case falls through to the case written after it.
// a case without a condition is the default. without one the default is the merge block, nothing is executed.
//
// OpSwitch only takes integers. jai requires the conditions of the cases to be constants, so for integers (and enums) they are the literals of OpSwitch.
// for floats and bools the index of the case that matches is selected first (no branching is needed since the conditions are constants), then it is switched on:
//    index := -1;
//    index = ifx x == c2 then 2 else index;   (from the last case to the first, so the first case that matches wins)
//    index = ifx x == c1 then 1 else index;
//    switch index ...
//
GenerateSwitch :: (data: *CompilationData, ci: *Code_If, general: *BuilderType, function: *BuilderType, currentFunction: *Code_Procedure_Header) {
   cases := GetSwitchCases(ci);

   selectorType := GetNodeType(ci.condition);
   selectorInfo, selectorIsNumeric := GetNumericInfo(selectorType);
   assert(selectorIsNumeric && selectorInfo.components == 1, "can only switch on integers, floats, bools and enums. type: %, loc: %", selectorType.*, GetLocationString(ci));

   selectorSSAId := GenerateInstructions(data, ci.condition, general, function, currentFunction, .{ spirvShouldHaveBeenType = selectorType });

   labels := NewArray(cases.count, SSAId);
   for * labels  it.* = GetNextSSAId(data);
   mergeLabelSSAId := GetNextSSAId(data);

   defaultLabelSSAId := mergeLabelSSAId;
   for cases  if (it.condition == null) defaultLabelSSAId = labels[it_index];

   operands: [..] Any;
   operands.allocator = temp;

   isInteger := selectorInfo.kind == .Signed || selectorInfo.kind == .Unsigned;
   if (isInteger) {
      array_add(*operands, selectorSSAId, defaultLabelSSAId);

      for cases {
         if (it.condition == null) continue;

         literal: Identifier;
         _ := GenerateInstructions(data, it.condition, general, function, currentFunction, .{ spirvShouldHaveBeenType = selectorType }, identifierOut = *literal);
         assert(literal.type == .IntLiteral, "the condition of a case must be a constant. loc: %", GetLocationString(it.condition));

         // the literals have the width of the selector
         if (selectorInfo.bitSize == 64) {
            array_add(*operands, ac(literal.intLiteral.value._u64));
         } else {
            mask: u64 = ifx selectorInfo.bitSize == 8 then cast(u64) 0xFF else 0xFFFF_FFFF;
            array_add(*operands, ac(cast(u32) (literal.intLiteral.value._u64 & mask)));
         }
         array_add(*operands, ac(labels[it_index]));
      }
   } else {
      indexType := cast(*Type_Info) s32;
      indexTypeSSAId := GetSSAId(data, .{ type = ._Type, _type = indexType });
      boolTypeSSAId := GetSSAId(data, .{ type = ._Type, _type = cast(*Type_Info) bool });
      equalOp := GetComparisonOp(.IS_EQUAL, selectorInfo.kind);

      indexSSAId := GetSSAId(data, .{ type = .IntLiteral, intLiteral = .{ unsigned = false, value._s64 = -1, bitSize = 32 } });

      for < cases {
         if (it.condition == null) continue;

         caseSSAId := GenerateInstructions(data, it.condition, general, function, currentFunction, .{ spirvShouldHaveBeenType = selectorType });

         matchesSSAId := GetNextSSAId(data);
         WriteSingleInstructionIfReachable(function, *data.isBlockReachable, equalOp, boolTypeSSAId, matchesSSAId, selectorSSAId, caseSSAId);

         caseIndexSSAId := GetSSAId(data, .{ type = .IntLiteral, intLiteral = .{ unsigned = false, value._s64 = it_index, bitSize = 32 } });
         nextIndexSSAId := GetNextSSAId(data);
         WriteSingleInstructionIfReachable(function, *data.isBlockReachable, .Select, indexTypeSSAId, nextIndexSSAId, matchesSSAId, caseIndexSSAId, indexSSAId);
         indexSSAId = nextIndexSSAId;
      }

      array_add(*operands, indexSSAId, defaultLabelSSAId);

      for cases {
         if (it.condition == null) continue;
         array_add(*operands, ac(cast(u32) it_index), ac(labels[it_index]));
      }
   }

   WriteSingleInstructionIfReachable(function, *data.isBlockReachable, .SelectionMerge, mergeLabelSSAId, SpvSelectionControlMask.MaskNone);
   WriteSingleInstructionIfReachable(function, *data.isBlockReachable, .Switch, .. operands);

   for cases {
      WriteSingleInstructionIfReachable(function, *data.isBlockReachable, .Label, labels[it_index]);
      GenerateInstructions(data, it.then_block, general, function, currentFunction);

      if (it.marked_as_fallthrough) {
         assert(it_index + 1 < cases.count, "the last case cant fall through. loc: %", GetLocationString(it));
         WriteSingleInstructionIfReachable(function, *data.isBlockReachable, .Branch, labels[it_index + 1]);
      } else {
         WriteSingleInstructionIfReachable(function, *data.isBlockReachable, .Branch, mergeLabelSSAId);
      }
   }

   WriteSingleInstructionIfReachable(function, *data.isBlockReachable, .Label, mergeLabelSSAId);
}

// returns, for each member of the struct, the expression that initializes it in the struct literal:
//    the positional argument, or the named argument (.{ member = x }), or the default value of the member from the struct definition.
// null means the member gets the default value of its type (see GetDefaultValueIdentifier).
//
// named arguments are given by the compiler as "member = x" binary operators.
GetStructLiteralMemberExpressions :: (literal: *Code_Literal, tis: *Type_Info_Struct) -> [] *Code_Node {
   assert(literal.value_type == .STRUCT);

   result := NewArray(GetStructMembers(tis).count, *Code_Node);
   given := NewArray(GetStructMembers(tis).count, bool);

   for literal.struct_literal_info.arguments {
      if (it.kind == .BINARY_OPERATOR && it.(*Code_Binary_Operator).operator_type == #char "=") {
         cbo := cast(*Code_Binary_Operator) it;
         assert(cbo.left.kind == .IDENT, "loc: %", GetLocationString(it));
         name := cbo.left.(*Code_Ident).name;

         memberIndex := -1;
         for member: GetStructMembers(tis) {
            if (member.name == name) {
               memberIndex = it_index;
               break;
            }
         }
         assert(memberIndex != -1, "struct % has no member named %. loc: %", tis.name, name, GetLocationString(it));

         result[memberIndex] = cbo.right;
         given[memberIndex] = true;
      } else {
         assert(it_index < GetStructMembers(tis).count, "too many arguments. loc: %", GetLocationString(it));
         result[it_index] = it;
         given[it_index] = true;
      }
   }

   for * result {
      if (!given[it_index]) it.* = GetStructMemberDefaultValue(tis, it_index);
   }

   return result;
}

// untyped struct literals nested in a struct literal (.{ member = .{ 1, 2 } }) dont have their type set by the compiler (it is UNTYPED_LITERAL)
// so their type is passed down from the type of the member they initialize.
DetermineStructLiteralTypes :: (data: *CompilationData, literal: *Code_Literal, tis: *Type_Info_Struct) -> *Type_Info {
   found, value := table_find(*data.codeNodeTypes, literal);
   if (found) return value;

   for GetStructLiteralMemberExpressions(literal, tis) {
      if (it == null) continue;

      memberType := GetStructMembers(tis)[it_index].type;
      if (it.kind == .LITERAL && it.(*Code_Literal).value_type == .STRUCT && it.type.type != .STRUCT && memberType.type == .STRUCT) {
         DetermineStructLiteralTypes(data, xx it, xx memberType);
      } else {
         DetermineCodeNodeTypes(data, it);
      }
   }

   TableAdd(*data.codeNodeTypes, literal, tis);
   return tis;
}

// returns null if the member doesnt have a default value (or if it is "---") which means zero initialized.
GetStructMemberDefaultValue :: (tis: *Type_Info_Struct, memberIndex: int) -> *Code_Node {
   found, cs := table_find(*structDefinitions, tis);
   if (!found) return null;

   name := GetStructMembers(tis)[memberIndex].name;
   for cs.block.statements {
      if (it.kind != .DECLARATION) continue;

      cd := cast(*Code_Declaration) it;
      if (cd.name != name) continue;

      if (cd.expression == null) return null;
      if (cd.flags & .IS_UNINITIALIZED) return null;
      return cd.expression;
   }

   return null;
}

IsStructLiteralConstant :: (data: *CompilationData, literal: *Code_Literal) -> bool {
   // assume result is true and set to false if not constant
   Helper :: (data: *CompilationData, literal: *Code_Literal, result: *bool) {
      if literal.value_type == {
         case .ARRAY; #through;
         case .STRUCT;
            array: [] *Code_Node;
            if (literal.value_type == .STRUCT) {
               found, type := table_find(*data.codeNodeTypes, literal);
               assert(found && type.type == .STRUCT, "loc: %", GetLocationString(literal));
               array = GetStructLiteralMemberExpressions(literal, xx type);
            } else {
               array = literal.array_literal_info.array_members;
            }

            for array {
               if (it == null) continue; // zero initialized member, OpConstantNull


               // i am being lazy here and saying if it is not literal then gg
               // but thats not true. it could be a constant variable.
               //
               // is there a better way to check if a code node has a compile time constant value?
               //          - apila, 18/04/26
               if (it.kind != .LITERAL) {
                  // constant numbers (N, N * 2, .A, size_of(T)...)
                  _, isConstant := EvaluateConstant(data, it);
                  if (isConstant) continue;

                  result.* = false;
                  return;
               }

               cl := cast(*Code_Literal) it;
               Helper(data, cl, result);
            }

         case .NUMBER; return;
         case .BOOLEAN; return;
         case .STRING; return;

         case .POINTER;
            result.* = false;
            return;

         case .TYPE_INFO;
            result.* = false;
            return;
      }
   }

   assert(literal.value_type == .STRUCT, "type: %", literal.value_type);
   result := true;
   Helper(data, literal, *result);

   return result;
}

GetVariableIdentifier :: (ci: *Code_Ident) -> Identifier {
   return .{ type = .Variable, variable.declaration = ci.resolved_declaration };
}

GetDescriptorHeapIdentifier :: (data: *CompilationData, sourceVariable: Identifier) -> Identifier {
   assert(sourceVariable.type == .Variable);

   if (IdentifierCompare(sourceVariable, imageHeapVariableIdentifier) ||
       IdentifierCompare(sourceVariable, tlasHeapVariableIdentifier)) {
      return data.resourceHeapIdentifier;
   }

   assert(IdentifierCompare(sourceVariable, samplerHeapVariableIdentifier));
   return samplerHeapVariableIdentifier;
}

GetDescriptorHeapArrayElementType :: (descriptorType: *Type_Info) -> *Type_Info {
   #if DESCRIPTOR_STRIDE_MODE == .Byte {
      return type_info(u8);
   } else #if DESCRIPTOR_STRIDE_MODE == .DescriptorSize {
      return descriptorType;
   } else {
      #assert(false, "not implemented!");
   }
}

// this function returns the storage class of the variable. not where the storage class of where it points to if it is a pointer
GetVariableStorageClass :: (data: *CompilationData, variable: Identifier) -> SpvStorageClass {
   assert(variable.type == .Variable, "type: %", variable.type);

   if (GetBuiltinVariableIndex(variable) != -1) {
      return .Input;
   }

   declaration := variable.variable;

   if (IdentifierCompare(variable, meshVerticesVariableIdentifier)) {
      return .Output;
   }

   if (GetMeshPrimitiveIndicesIndex(variable) != -1) {
      return .Output;
   }

   if (IdentifierCompare(variable, meshPipelinePushDataVariableIdentifier)) {
      return .PushConstant;
   }

   if (IdentifierCompare(variable, rtxPipelinePushDataVariableIdentifier)) {
      return .PushConstant;
   }

   if (IdentifierCompare(variable, imageHeapVariableIdentifier)) {
      return .UniformConstant;
   }

   if (IdentifierCompare(variable, samplerHeapVariableIdentifier)) {
      return .UniformConstant;
   }

   if (IdentifierCompare(variable, tlasHeapVariableIdentifier)) {
      return .UniformConstant;
   }

   if (IdentifierCompare(variable, computePipelinePushDataVariableIdentifier)) {
      return .PushConstant;
   }

   if (IdentifierCompare(variable, data.meshVertexOutVariableIdentifier)) {
      return .Output;
   }

   if (IdentifierCompare(variable, data.meshPrimitiveOutVariableIdentifier)) {
      return .Output;
   }

   if (IdentifierCompare(variable, data.shaderDataPointerVariableIdentifier)) {
      return .Private;
   }

   if (IdentifierCompare(variable, data.fragmentVertexInVariableIdentifier)) {
      return .Input;
   }

   if (IdentifierCompare(variable, data.fragmentPrimitiveInVariableIdentifier)) {
      return .Input;
   }

   if (IsPayloadVariable(declaration.declaration)) {
      return .RayPayloadKHR;
   }

   if (IsIncomingPayloadVariable(declaration.declaration)) {
      return .IncomingRayPayloadKHR;
   }

   if (IsWorkgroupVariable(declaration.declaration)) {
      return .Workgroup;
   }

   for data.fragmentOutputIdentifiers {
      if (IdentifierCompare(variable, it)) {
         return .Output;
      }
   }

   isGlobalConstant := table_contains(*globalConstantDeclarations, declaration.declaration);
   if (isGlobalConstant) {
      // they dont really exists.
      // idk. maybe probably this is true for any constant? not just global scope.
      return .Max;
   }

   // user declared variables are always in a function.
   //
   // the note above is true since i do not allow global variables yet. idk what to do when i do allow global variables. maybe qualifiers may come in handy
   //    - apila, 29/05/26
   //
   // i only allow global variables if it is a constant or if it is some allowed stuff like ray payload (which is checked above).
   //       - apila, 11/09/26
   return .Function;
}

GetVariableName :: (variable: Identifier) -> string {
   assert(variable.type == .Variable);
   return variable.variable.declaration.name;
}

// these are the arrays of the mesh shader outputs. they are not in a buffer so they must not have ArrayStride. (see decorationlessArrays)
CreateTypeInfoArrayFixedSize :: (elementType: *Type_Info, arrayCount: int) -> *Type_Info_Array #expand {
   typeInfo := New(Type_Info_Array);
   typeInfo.type = .ARRAY;
   typeInfo.element_type = elementType;
   typeInfo.array_type = .FIXED;
   typeInfo.array_count = arrayCount;

   TableAdd(*decorationlessArrays, typeInfo, typeInfo);
   return typeInfo;
}

GetArrayElementType :: (declaration: *Code_Declaration) -> *Type_Info #expand {
   assert(declaration.type.type == .ARRAY, "type: %", declaration.type.type);
   tip := cast(*Type_Info_Array) declaration.type;
   return tip.element_type;
}

// i need this function because some of the variables, their jai types doesnt match the spirv i want to generate.
// for example meshvertices is declared as an array view but is a fixed size array.
GetVariableTypeIdentifier :: (data: *CompilationData, variable: Identifier) -> Identifier {
   assert(variable.type == .Variable, "variable.type: %", variable.type);

   declaration := variable.variable.declaration;

   if (IdentifierCompare(variable, meshVerticesVariableIdentifier)) {
      elementType := cast(*Type_Info) MeshPerVertex;

      typeInfo := CreateTypeInfoArrayFixedSize(elementType, data.maxVertices);
      return .{ type = ._Type, _type = typeInfo };
   }

   if (GetMeshPrimitiveIndicesIndex(variable) != -1) {
      typeInfo := CreateTypeInfoArrayFixedSize(GetArrayElementType(declaration), data.maxPrimitives);
      return .{ type = ._Type, _type = typeInfo };
   }

   if (IdentifierCompare(variable, data.meshVertexOutVariableIdentifier)) {
      elementType := GetArrayElementType(declaration);
      typeInfo := CreateTypeInfoArrayFixedSize(elementType, data.maxVertices);
      return .{ type = ._Type, _type = typeInfo };
   }

   if (IdentifierCompare(variable, data.meshPrimitiveOutVariableIdentifier)) {
      elementType := GetArrayElementType(declaration);
      typeInfo := CreateTypeInfoArrayFixedSize(elementType, data.maxPrimitives);
      return .{ type = ._Type, _type = typeInfo };
   }

   return .{ type = ._Type, _type = declaration.type };
}

GetPointerTypeIdentifier :: (typeIdentifier: Identifier, storageClass: SpvStorageClass) -> Identifier {
   assert(typeIdentifier.type == ._Type, "type: %", typeIdentifier.type);
   return GetPointerTypeIdentifier(typeIdentifier._type, storageClass);
}

// used to get the result type of OpVariable from jai declared type
GetPointerTypeIdentifier :: (type: *Type_Info, storageClass: SpvStorageClass) -> Identifier {
   pointerTypeInfo := GetPointerType(type, storageClass);
   return .{ type = ._Type, _type = pointerTypeInfo };
}

// used to get the result type of OpVariable from jai declared type
GetPointerType :: (type: *Type_Info, storageClass: SpvStorageClass) -> *Type_Info {
   pointerTypeInfo := New(TypeInfoPointer);
   pointerTypeInfo.pointerTo = type;
   pointerTypeInfo.storageClass = storageClass;

   return pointerTypeInfo;
}

// returns the operations
FlattenAccessTree :: (cbo: *Code_Binary_Operator) -> [] *Code_Binary_Operator {
   // treat "accesses" as a capture variable
   Helper :: (current: *Code_Binary_Operator, accesses: *[..] *Code_Binary_Operator) {
      assert(current.operator_type == #char "." || // member access and pointer access
            current.operator_type == .ARRAY_SUBSCRIPT,
            "operator: %", current.operator_type
      );

      if (current.left.kind == .BINARY_OPERATOR) {
         Helper(xx current.left, accesses);
      }

      array_add(accesses, current);
   }

   accesses: [..] *Code_Binary_Operator;
   Helper(cbo, *accesses);
   return accesses;
}

// it is not always [0].left because of named modules
GetBaseNodeInAccessChain :: (accesses: [] *Code_Binary_Operator) -> *Code_Node {
   for accesses {
      // could have used CompilationData.codeNodeTypes for consistency but meh.
      if (it.left.type.type == .TYPE) continue;

      if (it_index == 0) {
         return xx accesses[0].left;
      }

      return xx accesses[it_index - 1].right;
   }

   assert(false, "no base found. start of the chain: %:%", accesses[0].l0, accesses[0].c0);
   return null;
}

DoProcedureCallBase :: (baseNode: *Code_Procedure_Call) #expand {
   assert(baseNode.kind == .PROCEDURE_CALL);

   data := `data;
   outSpirvType: *Type_Info;
   `currentBaseSSAId.* = GenerateInstructions(`data, baseNode, null, `b, `currentFunction, spirvType = *outSpirvType);
   assert(outSpirvType != null);
   `currentBaseSpirvType.* = outSpirvType;
}

DoMemberAccess :: (tis: *Type_Info_Struct, right: *Code_Node, indices: *[..] SSAId, literalIndices: *[..] int, isBaseSpirvPointer: bool) #expand {
   assert(right.kind == .IDENT, "if you are accessing a struct indexer it is not yet implemented! right.kind: %, struct name: %, loc: %", right.kind, tis.name, right.location);
   ci := cast(*Code_Ident) right;

   // a member of a member that is marked with using is accessed through it, so there can be more than one index
   path := GetMemberPath(tis, ci.name);
   assert(path.count > 0, "not a member of struct! struct: %, member: %", tis.name, ci.name);

   for memberIndex: path {
      if (isBaseSpirvPointer) {
         memberIndexIdentifier: Identifier = .{ type = .IntLiteral, intLiteral = .{ unsigned = false, value._s64 = memberIndex, bitSize = 32 } };
         memberIndexSSAId := GetSSAId(`data, memberIndexIdentifier);
         array_add(indices, memberIndexSSAId);
      } else {
         array_add(literalIndices, memberIndex);
      }
   }
}

// the indices to a member. a member can be in a member that is marked with using (Inner :: struct { a: s32; } Outer :: struct { using inner: Inner; }, outer.a is outer.inner.a).
// empty if there is no such member.
GetMemberPath :: (tis: *Type_Info_Struct, memberName: string) -> [] int, Type_Info_Struct_Member {
   members := GetStructMembers(tis);

   for members {
      if (it.name == memberName) {
         path := NewArray(1, int);
         path[0] = it_index;
         return path, it;
      }
   }

   for members {
      if (!(it.flags & .USING)) continue;
      assert(it.type.type == .STRUCT, "using % in % is not a struct. only using on struct members is supported (a pointer would need to be loaded). loc: %", it.name, tis.name, tis.name);

      innerPath, member := GetMemberPath(cast(*Type_Info_Struct) it.type, memberName);
      if (innerPath.count == 0) continue;

      path := NewArray(innerPath.count + 1, int);
      path[0] = it_index;
      memcpy(path.data + 1, innerPath.data, innerPath.count * size_of(int));
      return path, member;
   }

   return .[], .{};
}

// the types the operands of an arithmetic operator are generated as.
// in "vector op scalar" (or "scalar op vector") the scalar is generated as the component type of the vector, so that a literal like the 2 in "v * 2"
// becomes a constant of the right type, and then it can be broadcast. see DoBinaryArithmetic.
GetArithmeticOperandTypes :: (leftType: *Type_Info, rightType: *Type_Info, operatorType: Operator_Type) -> left: *Type_Info, right: *Type_Info {
   if (operatorType == .SHIFT_LEFT || operatorType == .SHIFT_RIGHT) return leftType, rightType;

   leftInfo, leftIsNumeric := GetNumericInfo(leftType);
   rightInfo, rightIsNumeric := GetNumericInfo(rightType);
   if (!leftIsNumeric || !rightIsNumeric) return leftType, rightType;

   if (leftInfo.components > 1 && rightInfo.components == 1)  return leftType, GetNumericType(leftInfo.kind, leftInfo.bitSize, 1);
   if (leftInfo.components == 1 && rightInfo.components > 1)  return GetNumericType(rightInfo.kind, rightInfo.bitSize, 1), rightType;

   return leftType, rightType;
}

// p[x] is *(p + x * size_of(element)).
// "addressOfPointer" is the address where p is stored (a variable or a struct member). returns the address of the element.
IndexPointer :: (data: *CompilationData, b: *BuilderType, addressOfPointer: SSAId, addressOfPointerType: *TypeInfoPointer, indexNode: *Code_Node, currentFunction: *Code_Procedure_Header) -> SSAId {
   assert(addressOfPointerType.pointerTo.type == TYPE_INFO_POINTER_TAG);
   pointerType := cast(*TypeInfoPointer) addressOfPointerType.pointerTo;
   assert(pointerType.storageClass == .PhysicalStorageBuffer, "can only index PhysicalStorageBuffer pointers. storageClass: %", pointerType.storageClass);

   pointerSSAId := Load(data, b, .{ type = ._Type, _type = pointerType }, addressOfPointer, addressOfPointerType.storageClass == .PhysicalStorageBuffer);

   // since i set spirvShouldHaveBeenType it is now guranteed that the returned ssa id will be casted to that type no matter what.
   indexSSAId := GenerateInstructions(data, indexNode, null, b, currentFunction, .{ spirvShouldHaveBeenType = cast(*Type_Info) u64 });
   u64TypeSSAId := GetSSAId(data, .{ type = ._Type, _type = cast(*Type_Info) u64 });

   // jai lays out arrays with a stride of size_of(element)
   strideSSAId := GetSSAId(data, .{ type = .IntLiteral, intLiteral = .{ unsigned = true, value._u64 = xx pointerType.pointerTo.runtime_size, bitSize = 64 } });
   offsetSSAId := GetNextSSAId(data);
   WriteSingleInstructionIfReachable(b, *data.isBlockReachable, .IMul, u64TypeSSAId, offsetSSAId, indexSSAId, strideSSAId);

   pointerAsU64SSAId := GetNextSSAId(data);
   WriteSingleInstructionIfReachable(b, *data.isBlockReachable, .ConvertPtrToU, u64TypeSSAId, pointerAsU64SSAId, pointerSSAId);

   elementAddressAsU64SSAId := GetNextSSAId(data);
   WriteSingleInstructionIfReachable(b, *data.isBlockReachable, .IAdd, u64TypeSSAId, elementAddressAsU64SSAId, pointerAsU64SSAId, offsetSSAId);

   elementAddressSSAId := GetNextSSAId(data);
   WriteSingleInstructionIfReachable(b, *data.isBlockReachable, .ConvertUToPtr, GetSSAId(data, .{ type = ._Type, _type = pointerType }), elementAddressSSAId, elementAddressAsU64SSAId);

   return elementAddressSSAId;
}

DoDotsAndArraySubscripts :: (data: *CompilationData, b: *BuilderType, cbo: *Code_Binary_Operator, currentFunction: *Code_Procedure_Header, isLValue: bool, lValueOut: *SSAId = null, spirvType: **Type_Info = null, lValueOutSpirvType: **Type_Info = null) -> SSAId {
   DoAccessChainOrCompositeExtract :: (data: *CompilationData,
                                       b: *BuilderType,
                                       jaiReturnType: *Type_Info,
                                       baseSSAId: SSAId,
                                       indices: *[..] SSAId,
                                       literalIndices: *[..] int,
                                       currentBaseSpirvType: *Type_Info) -> SSAId, spirvType: *Type_Info #expand {
      if (currentBaseSpirvType.type == TYPE_INFO_POINTER_TAG) {
         returnTypeIdentifier := GetPointerTypeIdentifier(jaiReturnType, currentBaseSpirvType.(*TypeInfoPointer).storageClass);
         pointerSSAId := EmitAccessChain(data, b, returnTypeIdentifier, baseSSAId, indices.*);
         array_reset(indices);
         return pointerSSAId, xx returnTypeIdentifier._type;
      } else {
         returnTypeIdentifier: Identifier = .{ type = ._Type, _type = jaiReturnType };
         resultSSAId := EmitCompositeExtract(data, b, returnTypeIdentifier, baseSSAId, literalIndices.*);
         array_reset(literalIndices);
         return resultSSAId, xx returnTypeIdentifier._type;
      }
   }

   // treat indices, currentBaseSSAId as capture variables.
   Helper :: (data: *CompilationData, b: *BuilderType, cbo: *Code_Binary_Operator, currentBaseSpirvType: **Type_Info, currentBaseSSAId: *SSAId, indices: *[..] SSAId, literalIndices: *[..] int, lastAccessOperation: **Code_Binary_Operator, currentFunction: *Code_Procedure_Header) {
      leftType := GetNodeType(cbo.left);
      leftType = UnwindVariantsAllTheWay(leftType);

      // it.x in a for * loop is array[it_index].x
      if (cbo.left.kind == .IDENT) {
         isPointerIterator, pointerLoop := table_find(*data.pointerIterators, (cast(*Code_Ident) cbo.left).resolved_declaration);
         if (isPointerIterator) {
            element := cast(*Code_Binary_Operator) GetForLoopNodes(data, pointerLoop).element;
            Helper(data, b, element, currentBaseSpirvType, currentBaseSSAId, indices, literalIndices, lastAccessOperation, currentFunction);

            elementType := (cast(*TypeInfoPointer) leftType).pointerTo;
            assert(cbo.operator_type == #char ".", "indexing the it of a for * loop is not supported. loc: %", GetLocationString(cbo));
            elementStruct := elementType;
            if (elementStruct.type == TYPE_INFO_DECORATIONLESS_COPY_OF_STRUCT_TAG) elementStruct = (cast(*TypeInfoDecorationlessCopyOfStruct) elementStruct).copyOf;
            assert(elementStruct.type == .STRUCT, "loc: %", GetLocationString(cbo));
            DoMemberAccess(cast(*Type_Info_Struct) elementStruct, cbo.right, indices, literalIndices, currentBaseSpirvType.*.type == TYPE_INFO_POINTER_TAG);

            lastAccessOperation.* = cbo;
            return;
         }
      }

      if cbo.left.kind == {
         case .BINARY_OPERATOR; {
            cboLeft := cast(*Code_Binary_Operator) cbo.left;
            assert(cboLeft.operator_type == #char "." || // member access and pointer access
                   cboLeft.operator_type == .ARRAY_SUBSCRIPT,
               "operator: %", cboLeft.operator_type
            );

            Helper(data, b, cboLeft, currentBaseSpirvType, currentBaseSSAId, indices, literalIndices, lastAccessOperation, currentFunction);
         }

         // reached to the base
         case .IDENT; {
            baseNode: *Code_Node;
            if (leftType.type == .TYPE) {
               // named module
               baseNode = cbo.right;
            } else {
               baseNode = cbo.left;
            }

            if baseNode.kind == {
               case .IDENT; {
                  baseType := GetNodeType(baseNode);
                  ciBase := cast(*Code_Ident) baseNode;

                  // a member reached through using is an access itself (see GetUsingAccess)
                  isUsingAccess, usingAccess := table_find(*data.usingAccesses, ciBase);
                  if (isUsingAccess) {
                     Helper(data, b, usingAccess, currentBaseSpirvType, currentBaseSSAId, indices, literalIndices, lastAccessOperation, currentFunction);
                  } else if (ciBase.resolved_declaration.flags & .IS_CONSTANT) {
                     // a constant (a lookup table TABLE :: s32.[...]) doesnt exist in memory. it is put in a variable so it can be indexed
                     currentBaseSSAId.*, currentBaseSpirvType.* = MaterializeValue(data, b, baseNode, currentFunction);
                  } else {
                     baseIdentifier := GetVariableIdentifier(ciBase);
                     currentBaseSSAId.* = GetSSAId(data, baseIdentifier);

                     baseSpirvType := New(TypeInfoPointer);
                     baseSpirvType.storageClass = GetVariableStorageClass(data, baseIdentifier);
                     baseSpirvType.pointerTo = baseType;
                     currentBaseSpirvType.* = baseSpirvType;
                  }
               }

               case .PROCEDURE_CALL; {
                  DoProcedureCallBase(xx baseNode);
               }

               case; assert(false);
            }
         }

         // reached to the base
         case .PROCEDURE_CALL; {
            DoProcedureCallBase(xx cbo.left);
         }

         // p.*.x, the pointer is the base
         case .UNARY_OPERATOR; {
            cuo := cast(*Code_Unary_Operator) cbo.left;
            if (cuo.operator_type == .POSTFIX_DEREFERENCE || cuo.operator_type == .POINTER_DEREFERENCE) {
               pointerSpirvType: *Type_Info;
               currentBaseSSAId.* = GenerateInstructions(data, cuo.subexpression, null, b, currentFunction, spirvType = *pointerSpirvType);
               assert(pointerSpirvType != null && pointerSpirvType.type == TYPE_INFO_POINTER_TAG, "loc: %", GetLocationString(cuo));
               currentBaseSpirvType.* = pointerSpirvType;
            } else {
               currentBaseSSAId.*, currentBaseSpirvType.* = MaterializeValue(data, b, cbo.left, currentFunction);
            }
         }

         // any other expression (a literal, a cast, ifx...). its value is put in a variable
         case; {
            currentBaseSSAId.*, currentBaseSpirvType.* = MaterializeValue(data, b, cbo.left, currentFunction);
         }
      }

      if leftType.type == {
         case TYPE_INFO_DECORATIONLESS_COPY_OF_STRUCT_TAG; {
            tidcos := cast(*TypeInfoDecorationlessCopyOfStruct) leftType;
            DoMemberAccess(tidcos.copyOf, cbo.right, indices, literalIndices, currentBaseSpirvType.*.type == TYPE_INFO_POINTER_TAG);
         }

         case .STRUCT; {
            tis := cast(*Type_Info_Struct) leftType;
            DoMemberAccess(tis, cbo.right, indices, literalIndices, currentBaseSpirvType.*.type == TYPE_INFO_POINTER_TAG);
         }

         case .ARRAY; {
            tia := cast(*Type_Info_Array) leftType;

            if tia.array_type == {
               case .FIXED; {
                  if (currentBaseSpirvType.*.type == TYPE_INFO_POINTER_TAG) {
                     indexSSAId := GenerateInstructions(data, cbo.right, null, b, currentFunction, .{ spirvShouldHaveBeenType = cast(*Type_Info) s32 });
                     array_add(indices, indexSSAId);
                  } else {
                     // only literals allowed
                     assert(cbo.right.kind == .LITERAL);

                     // here i am cheating a lil bit. i actually dont need the ssa id i need to integer value.
                     // so i am just using the existing function. maybe i should have just created a function and call it in the .LITERAL case of GenerateInstructions
                     // as well as here.
                     //       - apila, 29/05/26
                     literalIdentifier: Identifier;
                     _ := GenerateInstructions(data, cbo.right, null, b, currentFunction, .{ spirvShouldHaveBeenType = cast(*Type_Info) s32 }, identifierOut = *literalIdentifier);
                     assert(literalIdentifier.type == .IntLiteral);

                     index := literalIdentifier.intLiteral.value._s64;
                     array_add(literalIndices, index);
                  }
               }

               case .VIEW; {
                  if cbo.operator_type == {
                     case .ARRAY_SUBSCRIPT; {
                        // array view is a syntactic sugar for Array_View_64.
                        //    array[x]
                        //    (array.data + x).*
                        // i dont use Array_View_64. what i mean is when i see an array view in WriteTypeOrVariableOrConstant() i create a struct for it using the element type
                        // the struct layout is the same tho. first member is count, the second is data pointer (but typed). i colud have done it so that data pointer is of type *u8 always
                        // but then i need to DoCast() idk. idk maybe. idk man.
                        //          - apila, 23/09/26
                        assert(currentBaseSpirvType.*.type == TYPE_INFO_POINTER_TAG, "i put this assertion because i forgot the what the other case is for. unlucky");

                        dataIndexIdentifier: Identifier = .{ type = .IntLiteral, intLiteral = .{ unsigned = false, value._s64 = ARRAY_VIEW_DATA_FIELD_INDEX, bitSize = 32 } };
                        dataIndexSSAId := GetSSAId(data, dataIndexIdentifier);
                        array_add(indices, dataIndexSSAId);

                        dataType := New(TypeInfoPointer);
                        dataType.storageClass = .PhysicalStorageBuffer; // Clueeeee
                        dataType.pointerTo = tia.element_type;
                        pointerSSAId, _pointerSpirvType := DoAccessChainOrCompositeExtract(data, b, dataType, currentBaseSSAId.*, indices, literalIndices, currentBaseSpirvType.*);
                        assert(_pointerSpirvType.type == TYPE_INFO_POINTER_TAG);
                        pointerSpirvType := _pointerSpirvType.(*TypeInfoPointer);

                        // pointerSSAId is the address of the data field
                        currentBaseSSAId.* = IndexPointer(data, b, pointerSSAId, pointerSpirvType, cbo.right, currentFunction);
                        currentBaseSpirvType.* = pointerSpirvType.pointerTo;
                     }

                     case #char "."; {
                        // this is just member access
                        // array.data or array.count

                        tis := GetArrayViewTypeInfo(tia.element_type);
                        DoMemberAccess(tis, cbo.right, indices, literalIndices, currentBaseSpirvType.*.type == TYPE_INFO_POINTER_TAG);
                     }

                     case; assert(false);
                  }
               }

               case .RESIZABLE; {
                  assert(false, "not supported");
               }

               case; assert(false, "should have been unreachable. array type: %", tia.array_type);
            }
         }

         case TYPE_INFO_POINTER_TAG; {
            tip := cast(*TypeInfoPointer) leftType;

            // c style:
            // a.b.c.p->x
            // (*a.b.c.p).x
            //
            // p[x]
            // *(p + x)

            pointerSpirvType: *TypeInfoPointer;
            pointerSSAId: SSAId;
            if (indices.count > 0 || literalIndices.count > 0) {
               _pointerSpirvType: *Type_Info;
               pointerSSAId, _pointerSpirvType = DoAccessChainOrCompositeExtract(data, b, leftType, currentBaseSSAId.*, indices, literalIndices, currentBaseSpirvType.*);

               assert(_pointerSpirvType.type == TYPE_INFO_POINTER_TAG);
               pointerSpirvType = xx _pointerSpirvType;
            } else {
               pointerSSAId = currentBaseSSAId.*;

               assert(currentBaseSpirvType.*.type == TYPE_INFO_POINTER_TAG);
               pointerSpirvType = xx currentBaseSpirvType.*;
            }

            loadFromSpirvType: *TypeInfoPointer;
            loadFromSpirvType = pointerSpirvType;

            // pointerSSAId is the address where the pointer is stored
            if cbo.operator_type == {
               case #char "."; {
                  loadedTypeIdentifier: Identifier = .{ type = ._Type, _type = loadFromSpirvType.pointerTo };
                  currentBaseSSAId.* = Load(data, b, loadedTypeIdentifier, pointerSSAId, loadFromSpirvType.storageClass == .PhysicalStorageBuffer);
               }

               case .ARRAY_SUBSCRIPT; {
                  currentBaseSSAId.* = IndexPointer(data, b, pointerSSAId, loadFromSpirvType, cbo.right, currentFunction);
               }

               case; assert(false);
            }

            currentBaseSpirvType.* = loadFromSpirvType.pointerTo;

            if (cbo.operator_type == #char ".") {
               assert(tip.pointerTo.type == .STRUCT, "type: %", tip.pointerTo.type);
               tis := cast(*Type_Info_Struct) tip.pointerTo;
               DoMemberAccess(tis, cbo.right, indices, literalIndices, currentBaseSpirvType.*.type == TYPE_INFO_POINTER_TAG);
            }
         }

         case; assert(false);
      }

      // when all Helper functions exit lastAccessOperation will point to the last Code_Binary_Operator
      // because of the order of traversel
      lastAccessOperation.* = cbo;
   }

   currentBaseSpirvType: *Type_Info;
   currentBaseSSAId: SSAId;
   indices: [..] SSAId;
   literalIndices: [..] int;
   lastAccessOperation: *Code_Binary_Operator;
   Helper(data, b, cbo, *currentBaseSpirvType, *currentBaseSSAId, *indices, *literalIndices, *lastAccessOperation, currentFunction);
   assert(currentBaseSpirvType != null);
   assert(currentBaseSSAId != 0);
   assert(lastAccessOperation != null);

   lastAccessOperationJaiType := GetNodeType(lastAccessOperation);
   jaiReturnType := lastAccessOperationJaiType;

   // left overs
   lastAccessChainResultSpirvType: *Type_Info;
   lastAccessChainResultSSAId: SSAId;
   if (indices.count > 0 || literalIndices.count > 0) {
      // indexes were left over. last operation cant be pointer indexing
      leftType := GetNodeType(lastAccessOperation.left);
      assert(!(lastAccessOperation.operator_type == .ARRAY_SUBSCRIPT && leftType.type == TYPE_INFO_POINTER_TAG));

      lastAccessChainResultSSAId, lastAccessChainResultSpirvType = DoAccessChainOrCompositeExtract(data, b, jaiReturnType, currentBaseSSAId, *indices, *literalIndices, currentBaseSpirvType);
   } else {
      // no indices were left over. meaning that the last operation was a pointer indexing or an array view
      // ...p[index]
      leftType := GetNodeType(lastAccessOperation.left);
      assert(lastAccessOperation.operator_type == .ARRAY_SUBSCRIPT, "loc: %", GetLocationString(lastAccessOperation));
      assert((leftType.type == TYPE_INFO_POINTER_TAG) ||
             (leftType.type == .ARRAY && leftType.(*Type_Info_Array).array_type == .VIEW)
      );

      lastAccessChainResultSSAId = currentBaseSSAId;
      lastAccessChainResultSpirvType = currentBaseSpirvType;
   }

   if (isLValue) {
      assert(currentBaseSpirvType.type == TYPE_INFO_POINTER_TAG, "not an lvalue");

      if (spirvType != null) spirvType.* = lastAccessChainResultSpirvType;
      return lastAccessChainResultSSAId;
   }

   // OpCompositeExtract case.
   // you get the rvalue without the OpLoad.
   // it also means it cant be an lvalue
   //       - apila, 06/06/26
   if (currentBaseSpirvType.type != TYPE_INFO_POINTER_TAG) {
      assert(!isLValue);

      if (spirvType != null) spirvType.* = lastAccessChainResultSpirvType;
      return lastAccessChainResultSSAId;
   }

   if (lValueOutSpirvType != null) lValueOutSpirvType.* = lastAccessChainResultSpirvType;
   if (lValueOut != null) lValueOut.* = lastAccessChainResultSSAId;

   assert(lastAccessChainResultSpirvType.type == TYPE_INFO_POINTER_TAG, "type: %, loc: %", lastAccessChainResultSpirvType.*, GetLocationString(lastAccessOperation));
   tip := cast(*TypeInfoPointer) lastAccessChainResultSpirvType;

   loadedTypeIdentifier: Identifier = .{ type = ._Type, _type = tip.pointerTo };
   dereferencedSSAId := Load(data, b, loadedTypeIdentifier, lastAccessChainResultSSAId, tip.storageClass == .PhysicalStorageBuffer);

   if (spirvType != null) spirvType.* = loadedTypeIdentifier._type;
   return dereferencedSSAId;
}

// the storage class of the memory an lvalue (a variable, a member, an element...) is in
GetLValueStorageClass :: (data: *CompilationData, node: *Code_Node) -> SpvStorageClass {
   if node.kind == {
      case .IDENT;
         ci := cast(*Code_Ident) node;
         isUsingAccess, usingAccess := table_find(*data.usingAccesses, ci);
         if (isUsingAccess) return GetLValueStorageClass(data, usingAccess);
         return GetVariableStorageClass(data, .{ type = .Variable, variable.declaration = ci.resolved_declaration });

      case .BINARY_OPERATOR;
         cbo := cast(*Code_Binary_Operator) node;
         leftType := UnwindVariantsAllTheWay(GetNodeType(cbo.left));

         // through a pointer, or the elements of an array view (they are pointed to by the data member)
         if (leftType.type == TYPE_INFO_POINTER_TAG) return (cast(*TypeInfoPointer) leftType).storageClass;
         if (leftType.type == .ARRAY && (cast(*Type_Info_Array) leftType).array_type == .VIEW && cbo.operator_type == .ARRAY_SUBSCRIPT) return .PhysicalStorageBuffer;

         return GetLValueStorageClass(data, cbo.left);

      case .UNARY_OPERATOR;
         cuo := cast(*Code_Unary_Operator) node;
         subexpressionType := GetNodeType(cuo.subexpression);
         if ((cuo.operator_type == .POSTFIX_DEREFERENCE || cuo.operator_type == .POINTER_DEREFERENCE) && subexpressionType.type == TYPE_INFO_POINTER_TAG) {
            return (cast(*TypeInfoPointer) subexpressionType).storageClass;
         }
   }

   assert(false, "not an lvalue. loc: %", GetLocationString(node));
   return .Function;
}

// puts the value of an expression in a new Function variable, for accessing its members or elements (a value can only be indexed by constants with OpCompositeExtract).
// returns the variable and its type (a pointer)
MaterializeValue :: (data: *CompilationData, b: *BuilderType, node: *Code_Node, currentFunction: *Code_Procedure_Header) -> SSAId, *Type_Info {
   valueType := GetFunctionStorageClassType(GetNodeType(node));
   valueSSAId := GenerateInstructions(data, node, null, b, currentFunction, .{ spirvShouldHaveBeenType = valueType });

   storageClass := SpvStorageClass.Function;
   pointerType := GetPointerType(valueType, storageClass);
   variableSSAId := GetNextSSAId(data);
   WriteSingleInstruction(data.generalBuilder, .Variable, GetSSAId(data, .{ type = ._Type, _type = pointerType }), variableSSAId, storageClass);
   WriteSingleInstructionIfReachable(b, *data.isBlockReachable, .Store, variableSSAId, valueSSAId);

   return variableSSAId, pointerType;
}

EmitCompositeExtract :: (data: *CompilationData, b: *BuilderType, returnTypeIdentifier: Identifier, baseSSAId: SSAId, indices: [] int) -> SSAId {
   resultSSAId := GetNextSSAId(data);
   operands: [..] Any;

   array_add(*operands, GetSSAId(data, returnTypeIdentifier));
   array_add(*operands, resultSSAId);
   array_add(*operands, baseSSAId);

   for indices {
      array_add(*operands, ac(it));
   }

   WriteSingleInstructionIfReachable(b, *data.isBlockReachable, .CompositeExtract, .. operands);
   return resultSSAId;
}

EmitAccessChain :: (data: *CompilationData, b: *BuilderType, returnTypeIdentifier: Identifier, baseSSAId: SSAId, indices: [] SSAId) -> SSAId {
   resultSSAId := GetNextSSAId(data);

   operands: [..] Any;
   array_add(*operands, GetSSAId(data, returnTypeIdentifier));
   array_add(*operands, resultSSAId);
   array_add(*operands, baseSSAId);

   for indices {
      array_add(*operands, ac(it));
   }

   WriteSingleInstructionIfReachable(b, *data.isBlockReachable, .AccessChain, .. operands);
   return resultSSAId;
}

ArrayReverse :: (array: [] $T) {
   if (array.count <= 1) return;

   for 0..array.count / 2 - 1 {
      indexFromStart := it;
      indexFromEnd := array.count - 1 - indexFromStart;

      swap(*array[indexFromStart], *array[indexFromEnd]);
   }
}

// the struct a declaration is a member of. null if it is not a member of a struct
GetStructOfMemberDeclaration :: (declaration: *Code_Declaration) -> *Type_Info_Struct {
   if (memberDeclarationStructs.count == 0) {
      for cs, tis: structDefinitions {
         for cs.block.statements {
            if (it.kind == .DECLARATION) table_set(*memberDeclarationStructs, cast(*Code_Declaration) it, tis);
         }
      }
   }

   found, tis := table_find(*memberDeclarationStructs, declaration);
   return ifx found then tis else null;
}

memberDeclarationStructs: Table(*Code_Declaration, *Type_Info_Struct);

//
// using x; brings the members of x in scope. the compiler resolves an identifier to the declaration of the member, but it doesnt say through which using.
// the innermost using in scope whose struct has the member is the one (two usings that have the same member are an error in jai).
// the identifier is then generated as x.member.
// using on parameters is not supported, the compiler doesnt mark the parameters that are using.
//
GetUsingAccess :: (data: *CompilationData, ident: *Code_Ident, memberOf: *Type_Info_Struct) -> *Code_Binary_Operator {
   for < base: data.usingStack {
      baseType := GetNodeType(base);
      if (baseType.type == TYPE_INFO_POINTER_TAG) baseType = (cast(*TypeInfoPointer) baseType).pointerTo;
      if (baseType.type == TYPE_INFO_DECORATIONLESS_COPY_OF_STRUCT_TAG) baseType = (cast(*TypeInfoDecorationlessCopyOfStruct) baseType).copyOf;
      if (baseType.type != .STRUCT) continue;

      path, member := GetMemberPath(cast(*Type_Info_Struct) baseType, ident.name);
      if (path.count == 0) continue;

      right := New(Code_Ident);
      right.* = ident.*;

      access := New(Code_Binary_Operator);
      access.base = ident.base;
      access.kind = .BINARY_OPERATOR;
      access.type = ident.type;
      access.operator_type = #char ".";
      access.left = base;
      access.right = right;
      return access;
   }

   assert(false, "% is a member of % that is in scope because of using, but it is not a using statement in the shader. using on parameters is not supported because the jai compiler doesnt mark the parameters that are using. loc: %", ident.name, memberOf.name, GetLocationString(ident));
   return null;
}

// the members of a struct that are in memory (the constants declared in a struct are members too).
// the index of a member in the spirv struct is its index in this array.
GetStructMembers :: (tis: *Type_Info_Struct) -> [] Type_Info_Struct_Member {
   found, members := table_find(*structMembers, tis);
   if (found) return members;

   result: [..] Type_Info_Struct_Member;
   for tis.members {
      if (it.flags & .CONSTANT) continue;
      array_add(*result, it);
   }

   table_add(*structMembers, tis, result);
   return result;
}

structMembers: Table(*Type_Info_Struct, [] Type_Info_Struct_Member);

MEMBER_DOESNT_EXIST :: -1;
GetMemberIndex :: (tis: *Type_Info_Struct, memberName: string) -> int {
   for GetStructMembers(tis) {
      if (it.name == memberName) return it_index;
   }

   return MEMBER_DOESNT_EXIST;
}

GetFloatOpFromOperatorType :: (type: Operator_Type) -> SpvOp {
   if type == {
      case #char "+"; return .FAdd;
      case #char "-"; return .FSub;
      case #char "/"; return .FDiv;
      case #char "*"; return .FMul;
      case #char "%"; return .FRem; // jai's % truncates like C, so FRem (sign of the left operand) not FMod.
      case; assert(false, "type: %", type); return 0;
   }
}

GetIntegerOpFromOperatorType :: (type: Operator_Type, signedness: Signedness) -> SpvOp {
   signed := signedness == .Signed;

   if type == {
      case #char "+";            return .IAdd;
      case #char "-";            return .ISub;
      case #char "*";            return .IMul;
      case #char "/";            return ifx signed then SpvOp.SDiv else SpvOp.UDiv;
      case #char "%";            return ifx signed then SpvOp.SRem else SpvOp.UMod;
      case #char "&";            return .BitwiseAnd;
      case #char "|";            return .BitwiseOr;
      case #char "^";            return .BitwiseXor;
      case .SHIFT_LEFT;          return .ShiftLeftLogical;
      case .SHIFT_RIGHT;         return ifx signed then SpvOp.ShiftRightArithmetic else SpvOp.ShiftRightLogical;
      case; assert(false, "type: %", type); return 0;
   }
}

// returns the binary operator a compound assignment applies. for example .MINUS_ASSIGN -> #char "-"
GetOperatorFromCompoundAssignment :: (type: Operator_Type) -> Operator_Type {
   if type == {
      case .PLUS_ASSIGN;         return #char "+";
      case .MINUS_ASSIGN;        return #char "-";
      case .TIMES_ASSIGN;        return #char "*";
      case .DIV_ASSIGN;          return #char "/";
      case .MOD_ASSIGN;          return #char "%";
      case .BITWISE_AND_ASSIGN;  return #char "&";
      case .BITWISE_OR_ASSIGN;   return #char "|";
      case .BITWISE_XOR_ASSIGN;  return #char "^";
      case .SHIFT_LEFT_ASSIGN;   return .SHIFT_LEFT;
      case .SHIFT_RIGHT_ASSIGN;  return .SHIFT_RIGHT;
      case; assert(false, "not yet implemented! type: %", type); return 0;
   }
}

// comparison operators
GetComparisonOp :: (type: Operator_Type, kind: NumericKind) -> SpvOp {
   if kind == {
      case .Signed;
         if type == {
            case #char "<";            return .SLessThan;
            case #char ">";            return .SGreaterThan;
            case .LESS_OR_EQUAL;       return .SLessThanEqual;
            case .GREATER_OR_EQUAL;    return .SGreaterThanEqual;
            case .IS_EQUAL;            return .IEqual;
            case .IS_NOT_EQUAL;        return .INotEqual;
         }
      case .Unsigned;
         if type == {
            case #char "<";            return .ULessThan;
            case #char ">";            return .UGreaterThan;
            case .LESS_OR_EQUAL;       return .ULessThanEqual;
            case .GREATER_OR_EQUAL;    return .UGreaterThanEqual;
            case .IS_EQUAL;            return .IEqual;
            case .IS_NOT_EQUAL;        return .INotEqual;
         }
      case .Float;
         // ordered comparisons are false if either operand is NaN, except != which is true. same as c.
         if type == {
            case #char "<";            return .FOrdLessThan;
            case #char ">";            return .FOrdGreaterThan;
            case .LESS_OR_EQUAL;       return .FOrdLessThanEqual;
            case .GREATER_OR_EQUAL;    return .FOrdGreaterThanEqual;
            case .IS_EQUAL;            return .FOrdEqual;
            case .IS_NOT_EQUAL;        return .FUnordNotEqual;
         }
      case .Bool;
         if type == {
            case .IS_EQUAL;            return .LogicalEqual;
            case .IS_NOT_EQUAL;        return .LogicalNotEqual;
         }
   }

   assert(false, "not yet implemented! operator: %, kind: %", type, kind);
   return 0;
}

StructAnnotateMemberInfo :: struct {
   memberIndex:   int;
   offset:        int;
}

StructAnnotateInfo :: struct {
   memberInfos: [] StructAnnotateMemberInfo;
}

GetAnnotateInfoFromStruct :: (ti: *Type_Info) -> StructAnnotateInfo {
   if (ti.type != .STRUCT) assert(false, sprint("ti.type: %, type is not struct", ti.type));

   tis := cast(*Type_Info_Struct) ti;

   memberInfos := NewArray(GetStructMembers(tis).count, StructAnnotateMemberInfo);

   for GetStructMembers(tis) {
      memberInfos[it_index] = .{
         memberIndex = it_index,
         offset = it.offset_in_bytes,
      };
   }

   return .{
      memberInfos
   };
}

// this function is kaputt since when i implemented storage classes.
// this should take the notes also into account
//    - apila, 26/05/26
// i need this function since "void" is kinda special
GetReturnTypeIdentifier :: (tip: *Type_Info_Procedure) -> Identifier {
   assert(tip.type == .PROCEDURE); // if passed via cast from *Type_Info

   // i need to get rid of .Void and use ._Type and void builtin
   if (tip.return_types.count == 0) {
      return .{ type = .Void };
   }

   if (tip.return_types.count > 1) {
      return .{ type = ._Type, _type = GetMultipleReturnType(tip) };
   }

   // a returned pointer is a PhysicalStorageBuffer pointer like any other pointer that doesnt say otherwise
   returnType := ConvertJaiTypeIfNecessary(tip.return_types[0], string.[]);
   return .{ type = ._Type, _type = returnType };
}

//
// spirv functions return a single value. a procedure that returns more than one value returns a struct of them:
//    F :: () -> s32, f32   becomes   F :: () -> struct { r0: s32; r1: f32; }
// it is a value in the function, so it is a decorationless struct (see TypeInfoDecorationlessCopyOfStruct).
// the procedure types are deduplicated by the compiler so the struct is created once for each list of return types.
//
multipleReturnTypes: Table(*void, *Type_Info); // key: return_types.data of the procedure type

GetMultipleReturnType :: (tip: *Type_Info_Procedure) -> *Type_Info {
   assert(tip.return_types.count > 1);

   found, result := table_find(*multipleReturnTypes, tip.return_types.data);
   if (found) return result;

   tis := New(Type_Info_Struct);
   tis.type = .STRUCT;
   tis.name = sprint("__returns_%__", multipleReturnTypes.count);
   tis.members = NewArray(tip.return_types.count, Type_Info_Struct_Member);

   for tip.return_types {
      tis.members[it_index].name = sprint("r%", it_index);
      tis.members[it_index].type = it;
      tis.runtime_size += it.runtime_size;
   }

   copy := New(TypeInfoDecorationlessCopyOfStruct);
   copy.runtime_size = tis.runtime_size;
   copy.copyOf = tis;

   TableAdd(*multipleReturnTypes, tip.return_types.data, copy);
   return copy;
}

// the type of the member of the struct returned by a procedure with more than one return value (see GetMultipleReturnType)
GetMultipleReturnValueType :: (tip: *Type_Info_Procedure, index: int) -> *Type_Info {
   return GetFunctionStorageClassType(ConvertJaiTypeIfNecessary(tip.return_types[index], string.[]));
}

GetNextSSAId :: (using data: *CompilationData) -> SSAId {
   ssaIota += 1;
   return ssaIota;
}

GetSSAId :: (using data: *CompilationData, identifier: Identifier) -> SSAId {
   value, newlyAdded := find_or_add(*identifierToSSAId, identifier);
   if (!newlyAdded) {
      return value.*;
   }

   value.* = GetNextSSAId(data);
   return value.*;
}

ToSpirvOutputTopology :: (topology: PrimitiveTopology) -> SpvExecutionMode {
   if topology == {
      case .Points;    return .OutputPoints;
      case .Lines;     return .OutputLinesEXT;
      case .Triangles; return .OutputTrianglesEXT;
      case; assert(false, "invalid topology! topology: %", topology); return 0;
   }
}

ToPrimitiveTopology :: (topology: string) -> PrimitiveTopology {
   #if (false) {
   } else if (topology == "points") {
      return .Points;
   } else if (topology == "lines") {
      return .Lines;
   } else if (topology == "triangles") {
      return .Triangles;
   } else {
      assert(false, "invalid topology: %", topology);
      return 0;
   }
}
