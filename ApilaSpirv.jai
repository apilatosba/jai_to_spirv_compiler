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


#module_parameters (SPIRV_BUILDER_TYPE := SpirvBuilderType.Byte) () {
   SpirvBuilderType :: enum {
      Byte;
      String;
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

// vvvvvv intrinsics vvvvvvvv
// bool :: bool;
bool2 :: struct { x: bool; y: bool; };
bool3 :: struct { x: bool; y: bool; z: bool; };
bool4 :: struct { x: bool; y: bool; z: bool; w: bool; };

// u8   :: u8;
u8x2 :: struct { x: u8; y: u8; };
u8x3 :: struct { x: u8; y: u8; z: u8; };
u8x4 :: struct { x: u8; y: u8; z: u8; w: u8; };

// s32    :: s32;
s32x2 :: struct { x: s32; y: s32; };
s32x3 :: struct { x: s32; y: s32; z: s32; };
s32x4 :: struct { x: s32; y: s32; z: s32; w: s32; };

// u32    :: u32;
u32x2 :: struct { x: u32; y: u32; };
u32x3 :: struct { x: u32; y: u32; z: u32; };
u32x4 :: struct { x: u32; y: u32; z: u32; w: u32; };

// s64    :: s64;
s64x2 :: struct { x: s64; y: s64; };
s64x3 :: struct { x: s64; y: s64; z: s64; };
s64x4 :: struct { x: s64; y: s64; z: s64; w: s64; };

// u64    :: u64;
u64x2 :: struct { x: u64; y: u64; };
u64x3 :: struct { x: u64; y: u64; z: u64; };
u64x4 :: struct { x: u64; y: u64; z: u64; w: u64; };

f32   :: float;
f32x2 :: struct { x: f32; y: f32; };
f32x3 :: struct { x: f32; y: f32; z: f32; };
f32x4 :: struct { x: f32; y: f32; z: f32; w: f32; };

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

mat2 :: f32x2x2;
mat3 :: f32x3x3;
mat4 :: f32x4x4;

MeshPerVertex :: struct {
   position:   f32x4;
   pointSize:  f32;
}

operator *  :: (m: mat4, v: f32x4)  -> f32x4 { return .{}; };
operator *  :: (m: mat3, v: f32x3)  -> f32x3 { return .{}; };
operator *  :: (a: mat4, b: mat4)   -> mat4  { return .{}; }; // this is not valid jai operation unfortunately :(  - apila, 14/05/26
operator *  :: (v: f32x3, s: f32)   -> f32x3 { return .{}; }
operator *  :: (a: f32x3, b: f32x3) -> f32x3 { return .{}; }
operator *  :: (a: f32x2, b: f32x2) -> f32x2 { return .{}; }
operator *  :: (s: f32, v: f32x3)   -> f32x3 { return .{}; }
operator -  :: (v: f32x3, s: f32)   -> f32x3 { return .{}; }
operator -  :: (a: f32x3, b: f32x3) -> f32x3 { return .{}; }
operator -  :: (a: f32x3)           -> f32x3 { return .{}; }
operator -  :: (s: f32, v: f32x3)   -> f32x3 { return .{}; }
operator /  :: (a: f32x3, b: f32x3) -> f32x3 { return .{}; }
operator /  :: (v: f32x3, s: f32)   -> f32x3 { return .{}; }
operator +  :: (v: f32x3, s: f32)   -> f32x3 { return .{}; }
operator +  :: (v: f32x2, s: f32)   -> f32x2 { return .{}; }
operator +  :: (a: f32x3, b: f32x3) -> f32x3 { return .{}; }
operator +  :: (a: f32x2, b: f32x2) -> f32x2 { return .{}; }

#insert #run sprint("%: [] MeshPerVertex;", MESH_VERTICES_NAME); // gl_MeshVerticesEXT
#insert #run sprint("%: [] s32x3;", MESH_TRIANGLES_NAME); // gl_PrimitiveTriangleIndicesEXT
#insert #run sprint("% :: (vertexCount: u32, primitiveCount: u32) {} @%", SET_MESH_OUTPUTS_NAME, INTRINSIC_FUNCTION_NOTE_NAME); // SetMeshOutputsEXT
#insert #run sprint("%: [] __Image__;", IMAGE_HEAP_VARIABLE_NAME);
#insert #run sprint("%: [] __Sampler__;", SAMPLER_HEAP_VARIABLE_NAME);

// each texture variant corresponds to sampling of one single OpTypeImage.
#insert #run sprint("% :: (image: __Image__, sampler: __Sampler__, uv: f32x2)            -> f32x4 { return .{}; } @%", TEXTURE_FLOAT_2D_FUNCTION_NAME, INTRINSIC_FUNCTION_NOTE_NAME);
#insert #run sprint("% :: (image: __Image__, sampler: __Sampler__, uv: f32x2, lod: f32)  -> f32x4 { return .{}; } @%", TEXTURE_FLOAT_2D_LOD_FUNCTION_NAME, INTRINSIC_FUNCTION_NOTE_NAME);
#insert #run sprint("% :: (image: __Image__, sampler: __Sampler__, uv: f32x2)            -> s32x4 { return .{}; } @%", TEXTURE_INT_2D_FUNCTION_NAME, INTRINSIC_FUNCTION_NOTE_NAME);

#insert #run sprint("%: u32x3;", WORKGROUP_ID_VARIABLE_NAME);
#insert #run sprint("%: u32x3;", LOCAL_INVOCATION_ID_VARIABLE_NAME);

#insert #run sprint("% :: (x: f32,   y: f32)   -> f32   { return   0; } @%", POW_FUNCTION_NAME, INTRINSIC_FUNCTION_NOTE_NAME);
#insert #run sprint("% :: (x: f32x2, y: f32x2) -> f32x2 { return .{}; } @%", POW_FUNCTION_NAME, INTRINSIC_FUNCTION_NOTE_NAME);
#insert #run sprint("% :: (x: f32x3, y: f32x3) -> f32x3 { return .{}; } @%", POW_FUNCTION_NAME, INTRINSIC_FUNCTION_NOTE_NAME);
#insert #run sprint("% :: (x: f32x4, y: f32x4) -> f32x4 { return .{}; } @%", POW_FUNCTION_NAME, INTRINSIC_FUNCTION_NOTE_NAME);

#insert #run sprint("% :: (a: mat4, b: mat4) -> mat4 { return DEFAULT_MAT4; } @%", MUL_FUNCTION_NAME, INTRINSIC_FUNCTION_NOTE_NAME);

#insert #run sprint("% :: (value: f32, min: f32, max: f32) -> f32 { return 0; } @%", CLAMP_FUNCTION_NAME, INTRINSIC_FUNCTION_NOTE_NAME);

#insert #run sprint("% :: (v: f32x3) -> f32x3 { return .{}; } @%", DDX_FUNCTION_NAME, INTRINSIC_FUNCTION_NOTE_NAME);
#insert #run sprint("% :: (v: f32x2) -> f32x2 { return .{}; } @%", DDX_FUNCTION_NAME, INTRINSIC_FUNCTION_NOTE_NAME);

#insert #run sprint("% :: (v: f32x3) -> f32x3 { return .{}; } @%", DDY_FUNCTION_NAME, INTRINSIC_FUNCTION_NOTE_NAME);
#insert #run sprint("% :: (v: f32x2) -> f32x2 { return .{}; } @%", DDY_FUNCTION_NAME, INTRINSIC_FUNCTION_NOTE_NAME);

#insert #run sprint("% :: (m: mat4) -> mat4 { return DEFAULT_MAT4; } @%", INVERSE_FUNCTION_NAME, INTRINSIC_FUNCTION_NOTE_NAME);

#insert #run sprint("% :: (a: f32,   b: f32)   -> f32   { return   0; } @%", MAX_FUNCTION_NAME, INTRINSIC_FUNCTION_NOTE_NAME);
#insert #run sprint("% :: (a: f32x3, b: f32x3) -> f32x3 { return .{}; } @%", MAX_FUNCTION_NAME, INTRINSIC_FUNCTION_NOTE_NAME);

#insert #run sprint("% :: (a: f32x3, b: f32x3) -> f32 { return 0; } @%", DOT_FUNCTION_NAME, INTRINSIC_FUNCTION_NOTE_NAME);

#insert #run sprint("% :: (a: f32x3) -> f32x3 { return .{}; } @%", NORMALIZE_FUNCTION_NAME, INTRINSIC_FUNCTION_NOTE_NAME);

#insert #run sprint("% :: (a: f32x3, b: f32x3) -> f32x3 { return .{}; } @%", CROSS_FUNCTION_NAME, INTRINSIC_FUNCTION_NOTE_NAME);

#insert #run sprint("% :: (a: f32x3, b: f32x3) -> f32x3 { return .{}; } @%", REFLECT_FUNCTION_NAME, INTRINSIC_FUNCTION_NOTE_NAME);

#insert #run sprint("% :: (a: f32x3, b: f32x3, t: f32x3) -> f32x3 { return .{}; } @%", LERP_FUNCTION_NAME, INTRINSIC_FUNCTION_NOTE_NAME);

#insert #run sprint("% :: (a: f32x3) -> f32 { return 0; } @%", LENGTH_FUNCTION_NAME, INTRINSIC_FUNCTION_NOTE_NAME);

#insert #run sprint("% :: (y: f32, x: f32) -> f32 { return 0; } @%", ATAN2_FUNCTION_NAME, INTRINSIC_FUNCTION_NOTE_NAME);

#insert #run sprint("% :: (x: f32) -> f32 { return 0; } @%", ASIN_FUNCTION_NAME, INTRINSIC_FUNCTION_NOTE_NAME);
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

         for mt.declarations {
            if (it.expression.flags & .IS_CONSTANT) {
               TableAdd(*globalConstantDeclarations, it.expression, .{});
            }
         }
      }

      // i rely on .COMPLETE message being reported only once per workspace. the code below should get executed only once.    - apila, 23/05/26
      case .COMPLETE; {
         mc := cast(*Message_Complete) message;
         if (mc.error_code != .NONE) return;

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

DEFAULT_MAT4: mat4 : .[.{}, .{}, .{}, .{}];

// when i start to compile shaders in parallel, i need to synchronize access to this table      - apila, 23/05/26
entryPoints:                  Table(*Code_Procedure_Header, struct {});
functionDependencyTable:      Table(*Code_Procedure_Header, [..] *Code_Procedure_Header); // list of functions that a function calls
globalConstantDeclarations:   Table(*Code_Declaration, struct {});
userFunctionArguments:        Table(*Code_Declaration, struct {}); // this contains arguments to user defined functions. this doesn't include the arguments to the entry point.     - apila, 09/06/26

MESH_SHADER_NOTE_NAME      :: "mesh";
FRAGMENT_SHADER_NOTE_NAME  :: "fragment";

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
   if (typeNote == MESH_SHADER_NOTE_NAME) {
      shaderType = .Mesh;
   } else if (typeNote == FRAGMENT_SHADER_NOTE_NAME) {
      shaderType = .Fragment;
   } else {
      assert(false, "not yet implemented");
   }

   if shaderType == {
      case .Mesh; {
         assert(notes.count == 4, "[1] = x_y_z workgroup size, [2] = a_b max vertices and max primitives, [3] = [points, lines, triangles] primitive topology");

         // [1]
         {
            dimensions := split(notes[1], "_");
            assert(dimensions.count <= 3, "dimensions: %, max count is three", dimensions);

            for dimensions {
               value, ok := string_to_int(it);
               assert(ok, "it: %, couldnt be parsed to int!", it);

               workgroupSize[it_index] = xx value;
            }
         }

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

            // https://github.com/KhronosGroup/GLSL/blob/main/extensions/ext/GLSL_EXT_mesh_shader.txt
            // you need to implement gl_PrimitivePointIndicesEXT gl_PrimitiveLineIndicesEXT similar to you implemented triangles
            // prolly new entries in Identifier.builtinThingies and stuff like that
            //          - apila, 12/04/26
            assert(primitiveTopology == "triangles");

            topology = ToPrimitiveTopology(primitiveTopology);
         }
      }

      case .Fragment; {
         assert(notes.count == 1, "fragment shader must take no additional notes");
      }

      case; assert(false, "not yet implemented! type: %", shaderType);
   }

   return shaderType, workgroupSize, maxVertices, maxPrimitives, topology;
}


// this function doesnt validate the notes
// mesh shader:
//    @mesh @x_y_z @maxV_maxP @topology
// fragment shader:
//    @fragment
IsProcedureShaderEntryPoint :: (header: *Code_Procedure_Header) -> bool {
   if (header.notes.count < 1) return false;

   return header.notes[0].text == MESH_SHADER_NOTE_NAME ||
          header.notes[0].text == FRAGMENT_SHADER_NOTE_NAME;
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

SSAId :: #type,distinct u32;

BuilderType :: #run -> Type {
   if #complete SPIRV_BUILDER_TYPE == {
      case .Byte; return [..] u32; // list of words. one word is 4 bytes
      case .String; return String_Builder;
   }
}

MESH_VERTICES_NAME                  :: "meshvertices";
MESH_TRIANGLES_NAME                 :: "meshtriangles";
SET_MESH_OUTPUTS_NAME               :: "SetMeshOutputs";
PUSH_DATA_VARIABLE_NAME             :: "__push_data__";  // this is not gonna be used by the user.
                                                         // so i picked a name hoping that it is not gonna clash with other variables
IMAGE_HEAP_VARIABLE_NAME            :: "images";
SAMPLER_HEAP_VARIABLE_NAME          :: "samplers";
TEXTURE_FLOAT_2D_FUNCTION_NAME      :: "texture";
TEXTURE_FLOAT_3D_FUNCTION_NAME      :: "texture3d";
TEXTURE_INT_2D_FUNCTION_NAME        :: "texturei";
TEXTURE_FLOAT_2D_LOD_FUNCTION_NAME  :: "texturelod";
WORKGROUP_ID_VARIABLE_NAME          :: "workgroupid";
LOCAL_INVOCATION_ID_VARIABLE_NAME   :: "localinvocationid";
POW_FUNCTION_NAME                   :: "pow";
MUL_FUNCTION_NAME                   :: "mul"; // check comments above matrix type definitions
CLAMP_FUNCTION_NAME                 :: "clamp";
DDX_FUNCTION_NAME                   :: "ddx"; // OpDPdx
DDY_FUNCTION_NAME                   :: "ddy"; // OpDPdy
INVERSE_FUNCTION_NAME               :: "inverse";
MAX_FUNCTION_NAME                   :: "max";
DOT_FUNCTION_NAME                   :: "dot";
NORMALIZE_FUNCTION_NAME             :: "normalize";
CROSS_FUNCTION_NAME                 :: "cross";
REFLECT_FUNCTION_NAME               :: "reflect";
LERP_FUNCTION_NAME                  :: "lerp"; // FMix;
LENGTH_FUNCTION_NAME                :: "length";
ATAN2_FUNCTION_NAME                 :: "atan2";
ASIN_FUNCTION_NAME                  :: "asin";

// qualifiers
FUNCTION_QUALIFIER                  :: "function";
PHYSICAL_STORAGE_BUFFER_QUALIFIER   :: "physical";

PushData :: struct {
   taskData:      *void;
   meshData:      *void;
   fragmentData:  *void;
}

#insert #run sprint("%: PushData;", PUSH_DATA_VARIABLE_NAME);

__Sampler__ :: struct { } // OpTypeSampler
__Image__ :: struct { } // base type for what OpTypeImage returns. i dont use this.
                        // this is here to make the jai compiler happy. so it typechecks and stuff.
                        // i use TypeInfoImage.
                        //       - apila, 03/05/26

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

// identifier is anything that can be given an ssa id.
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
                                       //
                                       // the declaration is the default. but there some variables that their declaration is above the scope of the shader
                                       // for example intrinsics that i predefined, meshvertices, meshtriangles and such.
                                       // when i use code_of it doesnt behave the way i want. i think it generates competely new tree instead of referencing to the one generated
                                       // by the compiler during the compilation. so for that reason i use the name of these variables and this is fine since they are
                                       // treated as a keyword anyways.
                                       // and you shouldnt mix using name or using declaration for a single variable. either use name or the declaration. not both at the same time
                                       //          - apila, 18/04/26
                                       //
                                       // BUG
                                       // useName approach is faulty. instead i should use the declaration pointer but the way jai works right now it is not possible to my knowledge.
                                       // the problem is for example consider this scenario:
                                       // user has a named module in which they declared a variable meshvertices. if they try to access this using the named module:
                                       // UserModule.meshvertices then i wrongly think that this is the meshvertices from this module. declaration pointer would have solved this problem.
                                       //          - apila, 05/05/26
                                       //
                                       // i dont need useName anymore since i switched to a metaprogram. i can just get the *Code_Node and store them safely.
                                       // tho while getting it i still need to determine which variable is which somehow but when it comes to Identifier i dont need useName.
                                       //          - apila, 29/05/26
                                       //
                                       declaration:   *Code_Declaration;
                                       useName:       bool;
                                       name:          string;
                                    };
      compositeLiteral:             struct {
                                       type:       *Type_Info;
                                       arguments:  [] *Identifier;
                                    };
      boolLiteral:                  bool;
      constantSizeOf:               *Type_Info;
   };
}

HashType :: (type: *Type_Info) -> u32 {
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

   if (type.type == .ARRAY) {
      tia := cast(*Type_Info_Array) type;

      if (tia.array_type == .FIXED) {
         hash: u32 = 17;
         hash = hash * 31 + HashType(tia.element_type);
         hash = hash * 31 + get_hash(tia.array_count);

         return hash;
      }
   }

   // my types doesnt clash with those. so it is enough to use jai pointers (they are deduplicated)
   return cast,trunc(u32) fnv1a_hash(xx type, size_of(type_of(type)));
}

// cant do "==" anymore even if the types are jai types because they come from different workspaces.
CompareType :: (a_: *Type_Info, b_: *Type_Info) -> bool {
   a := UnwindVariantsUpToDistinct(a_);
   b := UnwindVariantsUpToDistinct(b_);

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
               return tiaA.array_count == tiaB.array_count && CompareType(tiaA.element_type, tiaB.element_type);
            case .VIEW;
               return CompareType(tiaA.element_type, tiaB.element_type);
            case; assert(false); return false;
         }

      case .ENUM;
         assert(false, "enums dont exists yet");
         return false;

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
      case .Function; return get_hash(function);
      case ._Type; return HashType(_type);
      case .Void; return 69; // does the hash matter here?
      case .Variable;
         if (variable.useName) {
            return get_hash(variable.name);
         } else {
            return get_hash(variable.declaration.name);
         }
      case .CompositeLiteral;
         hash: u32 = 17;
         hash = hash * 31 + get_hash(compositeLiteral.type);

         for compositeLiteral.arguments {
            hash = hash * 31 + IdentifierHash(it.*);
         }

         return hash;
      case .BoolLiteral; return get_hash(boolLiteral);
      case .ConstantSizeOf; return HashType(constantSizeOf);
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
      case .Function; return a.function == b.function; // if they point to the same code node
      case ._Type;
         return CompareType(a._type, b._type);

      case .Void; return true;
      case .Variable;
         if (a.variable.useName != b.variable.useName) return false;

         useName := a.variable.useName; // or b.variable.useName. they are the same at this point
         if (useName) {
            return a.variable.name == b.variable.name;
         }

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
         for tis.members {
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
   shaderDataPointerVariableIdentifier:      Identifier;
   codeNodeTypes:                            Table(*Code_Node, *Type_Info);
   fragmentVertexInVariableIdentifier:       Identifier;
   fragmentPrimitiveInVariableIdentifier:    Identifier;
   fragmentOutputIdentifiers:                [] Identifier;
   shaderType:                               ShaderType;
   entryFunction:                            *Code_Procedure_Header;
   extraTypeDependencies:                    Table(Identifier, [..] Identifier, IdentifierHash, IdentifierCompare);
   currentLoopData:                          LoopData;
   isBlockReachable:                         bool = true;   // this is a flag that keep tracks if a block terminating instruction has been seen in the block we are compiling.
                                                            // this flag is reset every time we start a new block.
                                                            // if you want to parallelize the compiler then you should store this per thread in a tls (thats easy with ApilaDispatch).
                                                            //    - apila, 09/05/26
   glslStd450:                               SSAId;

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
      assert(primitiveTopology == .Triangles, "not yet implemented!");
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

      case; assert(false, "not implemented yet. type: %", type);
   }

   // returns
   if type == {
      case .Mesh; assert(header.returns.count == 0, "mesh shader must return nothing");
      case .Fragment;
         data.fragmentOutputIdentifiers = NewArray(header.returns.count, Identifier);
         for header.returns {
            #if false {}
            else if (CompareType(it.type, cast(*Type_Info) bool)) {}
            else if (CompareType(it.type, cast(*Type_Info) bool2)) {}
            else if (CompareType(it.type, cast(*Type_Info) bool3)) {}
            else if (CompareType(it.type, cast(*Type_Info) bool4)) {}
            else if (CompareType(it.type, cast(*Type_Info) u8)) {}
            else if (CompareType(it.type, cast(*Type_Info) u8x2)) {}
            else if (CompareType(it.type, cast(*Type_Info) u8x3)) {}
            else if (CompareType(it.type, cast(*Type_Info) u8x4)) {}
            else if (CompareType(it.type, cast(*Type_Info) s32)) {}
            else if (CompareType(it.type, cast(*Type_Info) s32x2)) {}
            else if (CompareType(it.type, cast(*Type_Info) s32x3)) {}
            else if (CompareType(it.type, cast(*Type_Info) s32x4)) {}
            else if (CompareType(it.type, cast(*Type_Info) u32)) {}
            else if (CompareType(it.type, cast(*Type_Info) u32x2)) {}
            else if (CompareType(it.type, cast(*Type_Info) u32x3)) {}
            else if (CompareType(it.type, cast(*Type_Info) u32x4)) {}
            else if (CompareType(it.type, cast(*Type_Info) s64)) {}
            else if (CompareType(it.type, cast(*Type_Info) s64x2)) {}
            else if (CompareType(it.type, cast(*Type_Info) s64x3)) {}
            else if (CompareType(it.type, cast(*Type_Info) s64x4)) {}
            else if (CompareType(it.type, cast(*Type_Info) u64)) {}
            else if (CompareType(it.type, cast(*Type_Info) u64x2)) {}
            else if (CompareType(it.type, cast(*Type_Info) u64x3)) {}
            else if (CompareType(it.type, cast(*Type_Info) u64x4)) {}
            else if (CompareType(it.type, cast(*Type_Info) f32)) {}
            else if (CompareType(it.type, cast(*Type_Info) f32x2)) {}
            else if (CompareType(it.type, cast(*Type_Info) f32x3)) {}
            else if (CompareType(it.type, cast(*Type_Info) f32x4)) {}
            else if (CompareType(it.type, cast(*Type_Info) f32x2x2)) {}
            else if (CompareType(it.type, cast(*Type_Info) f32x3x3)) {}
            else if (CompareType(it.type, cast(*Type_Info) f32x4x4)) {}
            else { assert(false, "returning stuff other than intrinsics not implemented yet! you tried to return: %", it.type.*); }

            data.fragmentOutputIdentifiers[it_index] = .{ type = .Variable, variable.declaration = it };
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
      array_add(*b, 0); // my entry value goes here (not yet registered)

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
      case .Fragment; #through;
      case .Mesh; {
         // capabilities
         {
            WriteSingleInstruction(*b, .Capability, SpvCapability.Int64);
            WriteSingleInstruction(*b, .Capability, SpvCapability.Int8);
            WriteSingleInstruction(*b, .Capability, SpvCapability.MeshShadingEXT);
            WriteSingleInstruction(*b, .Capability, SpvCapability.UntypedPointersKHR);
            WriteSingleInstruction(*b, .Capability, SpvCapability.DescriptorHeapEXT);
            WriteSingleInstruction(*b, .Capability, SpvCapability.PhysicalStorageBufferAddresses);

            if (type == .Fragment) {
               WriteSingleInstruction(*b, .Capability, SpvCapability.Shader);
            }
         }

         // extensions
         WriteSingleInstruction(*b, .Extension, "SPV_EXT_mesh_shader");
         WriteSingleInstruction(*b, .Extension, "SPV_EXT_descriptor_heap");
         WriteSingleInstruction(*b, .Extension, "SPV_KHR_untyped_pointers");
         WriteSingleInstruction(*b, .Extension, "SPV_KHR_8bit_storage");
         WriteSingleInstruction(*b, .Extension, "SPV_KHR_physical_storage_buffer");

         WriteSingleInstruction(*b, .ExtInstImport, data.glslStd450, "GLSL.std.450");
         WriteSingleInstruction(*b, .MemoryModel, SpvAddressingModel.PhysicalStorageBuffer64, SpvMemoryModel.GLSL450);

         // entry point
         if (type == .Mesh) {
            WriteSingleInstruction(
               *b,
               .EntryPoint,
               SpvExecutionModel.MeshEXT,
               GetSSAId(*data, .{ type = .Function, function = header }),
               "ApilaMS",
               GetSSAId(*data, .{ type = .Variable, variable = .{ useName = true, name = MESH_VERTICES_NAME } }),
               GetSSAId(*data, .{ type = .Variable, variable = .{ useName = true, name = PUSH_DATA_VARIABLE_NAME } }),
               GetSSAId(*data, .{ type = .Variable, variable = .{ useName = true, name = MESH_TRIANGLES_NAME } }),
               GetSSAId(*data, data.meshVertexOutVariableIdentifier),
               GetSSAId(*data, data.meshPrimitiveOutVariableIdentifier),
               GetSSAId(*data, .{ type = .Variable, variable = .{ useName = true, name = IMAGE_HEAP_VARIABLE_NAME } }),
               GetSSAId(*data, .{ type = .Variable, variable = .{ useName = true, name = SAMPLER_HEAP_VARIABLE_NAME } }),
               GetSSAId(*data, data.shaderDataPointerVariableIdentifier),
               GetSSAId(*data, .{ type = .Variable, variable = .{ useName = true, name = WORKGROUP_ID_VARIABLE_NAME } }),
               GetSSAId(*data, .{ type = .Variable, variable = .{ useName = true, name = LOCAL_INVOCATION_ID_VARIABLE_NAME } })
            );
         } else if (type == .Fragment) {
            operands: [..] Any;
            array_add(*operands, SpvExecutionModel.Fragment);
            array_add(*operands, GetSSAId(*data, .{ type = .Function, function = header }));
            array_add(*operands, "ApilaFS");
            array_add(*operands, GetSSAId(*data, .{ type = .Variable, variable = .{ useName = true, name = IMAGE_HEAP_VARIABLE_NAME } }));
            array_add(*operands, GetSSAId(*data, .{ type = .Variable, variable = .{ useName = true, name = SAMPLER_HEAP_VARIABLE_NAME } }));
            array_add(*operands, GetSSAId(*data, .{ type = .Variable, variable = .{ useName = true, name = PUSH_DATA_VARIABLE_NAME } }));
            array_add(*operands, GetSSAId(*data, data.fragmentVertexInVariableIdentifier));
            array_add(*operands, GetSSAId(*data, data.fragmentPrimitiveInVariableIdentifier));
            array_add(*operands, GetSSAId(*data, data.shaderDataPointerVariableIdentifier));

            for data.fragmentOutputIdentifiers {
               array_add(*operands, ac(GetSSAId(*data, it)));
            }

            WriteSingleInstruction(
               *b,
               .EntryPoint,
               .. operands
            );
         } else {
            assert(false, "should have been unreachable because of the outer case.");
         }

         // execution modes
         if (type == .Mesh) {
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
         } else if (type == .Fragment) {
            WriteSingleInstruction(
               *b,
               .ExecutionMode,
               GetSSAId(*data, .{ type = .Function, function = header }),
               SpvExecutionMode.OriginUpperLeft
            );
         } else {
            assert(false, "should have been unreachable because of the outer case.");
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
         if (type == .Mesh) {
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
         } else if (type == .Fragment) {
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
         } else {
            assert(false, "should have been unreachable because of the outer case.");
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
         GetSSAId(*data, .{ type = ._Type, _type = cast(*Type_Info) PushData });

         if (type == .Mesh) {
            WriteSingleInstruction(
               *b,
               .Decorate,
               GetSSAId(*data, .{ type = .Variable, variable = .{ useName = true, name = MESH_TRIANGLES_NAME } }),
               SpvDecoration.BuiltIn,
               SpvBuiltIn.PrimitiveTriangleIndicesEXT
            );

            WriteSingleInstruction(
               *b,
               .Decorate,
               GetSSAId(*data, .{ type = .Variable, variable = .{ useName = true, name = WORKGROUP_ID_VARIABLE_NAME } }),
               SpvDecoration.BuiltIn,
               SpvBuiltIn.WorkgroupId
            );

            WriteSingleInstruction(
               *b,
               .Decorate,
               GetSSAId(*data, .{ type = .Variable, variable = .{ useName = true, name = LOCAL_INVOCATION_ID_VARIABLE_NAME } }),
               SpvDecoration.BuiltIn,
               SpvBuiltIn.LocalInvocationId
            );
         }

         WriteSingleInstruction(
            *b,
            .Decorate,
            GetSSAId(*data, .{ type = .Variable, variable = .{ useName = true, name = IMAGE_HEAP_VARIABLE_NAME } }),
            SpvDecoration.BuiltIn,
            SpvBuiltIn.ResourceHeapEXT
         );
         WriteSingleInstruction(
            *b,
            .Decorate,
            GetSSAId(*data, .{ type = .Variable, variable = .{ useName = true, name = SAMPLER_HEAP_VARIABLE_NAME } }),
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

         // runtime arrays
         for ssaId, identifier: data.identifierToSSAId {
            if (identifier.type != ._Type) continue;

            type := identifier._type;
            if (type.type != TYPE_INFO_RUNTIME_ARRAY_TAG) continue;

            tira := cast(*TypeInfoRuntimeArray) type;
            if (tira.elementType.type == TYPE_INFO_IMAGE_TAG ||
                  CompareType(tira.elementType, cast(*Type_Info) __Sampler__)) {
               constantSizeOfIdentifier: Identifier = .{ type = .ConstantSizeOf, constantSizeOf = tira.elementType };

               // specs mandates that: All <id> Extra Operands must appear before Target.
               AddTypeDependency(*data.extraTypeDependencies, identifier, constantSizeOfIdentifier);

               WriteSingleInstruction(
                  *b,
                  .DecorateId,
                  GetSSAId(*data, identifier),
                  SpvDecoration.ArrayStrideIdEXT,
                  GetSSAId(*data, constantSizeOfIdentifier)
               );
            } else {
               assert(false, "not yet implemented! element type: %", tira.elementType.*);
            }
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


         // idk if i need this?
         //    apila, 12/04/26
         //
         // struct annotate infos
         #if SPIRV_BUILDER_TYPE == .String {
            print_to_builder(*b, "\n; struct annotate infos\n");
         }

         for ssaId, identifier: data.identifierToSSAId {
            if (identifier.type != ._Type) continue;
            ti := cast(*Type_Info) identifier._type;
            if (ti.type != .STRUCT) continue;

            if (CompareType(identifier._type, cast(*Type_Info) MeshPerVertex))  continue; // builtin struct handled seperately
            if (CompareType(identifier._type, cast(*Type_Info) bool))           continue;
            if (CompareType(identifier._type, cast(*Type_Info) bool2))          continue;
            if (CompareType(identifier._type, cast(*Type_Info) bool3))          continue;
            if (CompareType(identifier._type, cast(*Type_Info) bool4))          continue;
            if (CompareType(identifier._type, cast(*Type_Info) u8))             continue;
            if (CompareType(identifier._type, cast(*Type_Info) u8x2))           continue;
            if (CompareType(identifier._type, cast(*Type_Info) u8x3))           continue;
            if (CompareType(identifier._type, cast(*Type_Info) u8x4))           continue;
            if (CompareType(identifier._type, cast(*Type_Info) s32))            continue;
            if (CompareType(identifier._type, cast(*Type_Info) s32x2))          continue;
            if (CompareType(identifier._type, cast(*Type_Info) s32x3))          continue;
            if (CompareType(identifier._type, cast(*Type_Info) s32x4))          continue;
            if (CompareType(identifier._type, cast(*Type_Info) u32))            continue;
            if (CompareType(identifier._type, cast(*Type_Info) u32x2))          continue;
            if (CompareType(identifier._type, cast(*Type_Info) u32x3))          continue;
            if (CompareType(identifier._type, cast(*Type_Info) u32x4))          continue;
            if (CompareType(identifier._type, cast(*Type_Info) s64))            continue;
            if (CompareType(identifier._type, cast(*Type_Info) s64x2))          continue;
            if (CompareType(identifier._type, cast(*Type_Info) s64x3))          continue;
            if (CompareType(identifier._type, cast(*Type_Info) s64x4))          continue;
            if (CompareType(identifier._type, cast(*Type_Info) u64))            continue;
            if (CompareType(identifier._type, cast(*Type_Info) u64x2))          continue;
            if (CompareType(identifier._type, cast(*Type_Info) u64x3))          continue;
            if (CompareType(identifier._type, cast(*Type_Info) u64x4))          continue;
            if (CompareType(identifier._type, cast(*Type_Info) f32))            continue;
            if (CompareType(identifier._type, cast(*Type_Info) f32x2))          continue;
            if (CompareType(identifier._type, cast(*Type_Info) f32x3))          continue;
            if (CompareType(identifier._type, cast(*Type_Info) f32x4))          continue;
            if (CompareType(identifier._type, cast(*Type_Info) f32x2x2))        continue;
            if (CompareType(identifier._type, cast(*Type_Info) f32x3x3))        continue;
            if (CompareType(identifier._type, cast(*Type_Info) f32x4x4))        continue;
            if (CompareType(identifier._type, cast(*Type_Info) __Image__))      continue;
            if (CompareType(identifier._type, cast(*Type_Info) __Sampler__))    continue;

            annotateInfo := GetAnnotateInfoFromStruct(identifier._type);
            structIdentifier: Identifier = .{ type = ._Type, _type = identifier._type };
            WriteSingleInstruction(
               *b,
               .Decorate,
               GetSSAId(*data, structIdentifier),
               SpvDecoration.Block
            );

            for annotateInfo.memberInfos {
               WriteSingleInstruction(
                  *b,
                  .MemberDecorate,
                  GetSSAId(*data, structIdentifier),
                  it.memberIndex,
                  SpvDecoration.Offset,
                  it.offset
               );
            }
         }

         AppendAndStealBuffers(*b, *typesConstantsVariablesBuilder);


         // functions
         #if SPIRV_BUILDER_TYPE == .String {
            print_to_builder(*b, "\n; functions\n");
         }

         AppendAndStealBuffers(*b, *functionsBuilder);
      }

      case; assert(false, "not yet implemented! type: %", type);
   }

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
      #if false {}
      else if (CompareType(type, cast(*Type_Info) u8))      { accumulator.* += 1; return; }
      else if (CompareType(type, cast(*Type_Info) u8x2))    { accumulator.* += 1; return; }
      else if (CompareType(type, cast(*Type_Info) u8x3))    { accumulator.* += 1; return; }
      else if (CompareType(type, cast(*Type_Info) u8x4))    { accumulator.* += 1; return; }
      else if (CompareType(type, cast(*Type_Info) s32))     { accumulator.* += 1; return; }
      else if (CompareType(type, cast(*Type_Info) s32x2))   { accumulator.* += 1; return; }
      else if (CompareType(type, cast(*Type_Info) s32x3))   { accumulator.* += 1; return; }
      else if (CompareType(type, cast(*Type_Info) s32x4))   { accumulator.* += 1; return; }
      else if (CompareType(type, cast(*Type_Info) u32))     { accumulator.* += 1; return; }
      else if (CompareType(type, cast(*Type_Info) u32x2))   { accumulator.* += 1; return; }
      else if (CompareType(type, cast(*Type_Info) u32x3))   { accumulator.* += 1; return; }
      else if (CompareType(type, cast(*Type_Info) u32x4))   { accumulator.* += 1; return; }
      else if (CompareType(type, cast(*Type_Info) s64))     { accumulator.* += 1; return; }
      else if (CompareType(type, cast(*Type_Info) s64x2))   { accumulator.* += 1; return; }
      else if (CompareType(type, cast(*Type_Info) s64x3))   { accumulator.* += 2; return; }
      else if (CompareType(type, cast(*Type_Info) s64x4))   { accumulator.* += 2; return; }
      else if (CompareType(type, cast(*Type_Info) u64))     { accumulator.* += 1; return; }
      else if (CompareType(type, cast(*Type_Info) u64x2))   { accumulator.* += 1; return; }
      else if (CompareType(type, cast(*Type_Info) u64x3))   { accumulator.* += 2; return; }
      else if (CompareType(type, cast(*Type_Info) u64x4))   { accumulator.* += 2; return; }
      else if (CompareType(type, cast(*Type_Info) f32))     { accumulator.* += 1; return; }
      else if (CompareType(type, cast(*Type_Info) f32x2))   { accumulator.* += 1; return; }
      else if (CompareType(type, cast(*Type_Info) f32x3))   { accumulator.* += 1; return; }
      else if (CompareType(type, cast(*Type_Info) f32x4))   { accumulator.* += 1; return; }
      else if (CompareType(type, cast(*Type_Info) f32x2x2)) { accumulator.* += 2; return; }
      else if (CompareType(type, cast(*Type_Info) f32x3x3)) { accumulator.* += 3; return; }
      else if (CompareType(type, cast(*Type_Info) f32x4x4)) { accumulator.* += 4; return; }

      ti := cast(*Type_Info) type;
      if (ti.type == .STRUCT) {
         tis := cast(*Type_Info_Struct) ti;
         for tis.members {
            Helper(it.type, accumulator);
         }

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

         case .SConvert; {
            assert(operands.count == 3);
            assert(operands[0].type == cast(*Type_Info) SSAId);
            assert(operands[1].type == cast(*Type_Info) SSAId);
            assert(operands[2].type == cast(*Type_Info) SSAId);

            resultType := operands[0].value_pointer.(*SSAId).*;
            result     := operands[1].value_pointer.(*SSAId).*;
            operand    := operands[2].value_pointer.(*SSAId).*;

            print_to_builder(b, "\%% = OpSConvert \%% \%%\n", result, resultType, operand);
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

         case .ConstantTrue; {
            assert(operands.count == 2);
            assert(operands[0].type == cast(*Type_Info) SSAId);
            assert(operands[1].type == cast(*Type_Info) SSAId);

            resultType := operands[0].value_pointer.(*SSAId).*;
            result     := operands[1].value_pointer.(*SSAId).*;

            array_add(b, OpWordCount(op, operands.count), cast(u32) resultType, cast(u32) result);
         }

         case .ConstantFalse; {
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
WriteTypeOrVariableOrConstant :: (data: *CompilationData, b: *BuilderType, identifier: Identifier) {
   currentStatus := table_find_pointer(*data.writtenIdentifiers, identifier);
   if (currentStatus != null) {
      if (false) {
      } else if (currentStatus.* == .BeingProcessed) {
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
      case .IntLiteral;
         intLiteralType: Type;
         #if (false) {
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

         if (identifier.intLiteral.unsigned) {
            if (identifier.intLiteral.bitSize == 32) {
               array_add(*operands, cast(u32) identifier.intLiteral.value._u64);
            } else if (identifier.intLiteral.bitSize == 64) {
               array_add(*operands, cast(u64) identifier.intLiteral.value._u64);
            } else {
               assert(false);
            }
         } else {
            if (identifier.intLiteral.bitSize == 32) {
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

      case .Function;
         return;

      case ._Type;
         type := identifier._type;

         // intrinsics
         if (CompareType(type, cast(*Type_Info) bool)) {
            WriteSingleInstruction(
               b,
               .TypeBool,
               GetSSAId(data, identifier)
            );
            return;
         }

         if (CompareType(type, cast(*Type_Info) bool2)) {
            boolIdentifier: Identifier = .{ type = ._Type, _type = cast(*Type_Info) bool };
            WriteTypeOrVariableOrConstant(data, b, boolIdentifier);

            WriteSingleInstruction(
               b,
               .TypeVector,
               GetSSAId(data, identifier),
               GetSSAId(data, boolIdentifier),
               2
            );
            return;
         }

         if (CompareType(type, cast(*Type_Info) bool3)) {
            boolIdentifier: Identifier = .{ type = ._Type, _type = cast(*Type_Info) bool };
            WriteTypeOrVariableOrConstant(data, b, boolIdentifier);

            WriteSingleInstruction(
               b,
               .TypeVector,
               GetSSAId(data, identifier),
               GetSSAId(data, boolIdentifier),
               3
            );
            return;
         }

         if (CompareType(type, cast(*Type_Info) bool4)) {
            boolIdentifier: Identifier = .{ type = ._Type, _type = cast(*Type_Info) bool };
            WriteTypeOrVariableOrConstant(data, b, boolIdentifier);

            WriteSingleInstruction(
               b,
               .TypeVector,
               GetSSAId(data, identifier),
               GetSSAId(data, boolIdentifier),
               4
            );
            return;
         }

         if (CompareType(type, cast(*Type_Info) u8)) {
            WriteSingleInstruction(
               b,
               .TypeInt,
               GetSSAId(data, identifier),
               8,
               0
            );
            return;
         }

         if (CompareType(type, cast(*Type_Info) u8x2)) {
            intIdentifier: Identifier = .{ type = ._Type, _type = cast(*Type_Info) u8 };

            WriteSingleInstruction(
               b,
               .TypeVector,
               GetSSAId(data, identifier),
               GetSSAId(data, intIdentifier),
               2
            );
            return;
         }

         if (CompareType(type, cast(*Type_Info) u8x3)) {
            intIdentifier: Identifier = .{ type = ._Type, _type = cast(*Type_Info) u8 };

            WriteSingleInstruction(
               b,
               .TypeVector,
               GetSSAId(data, identifier),
               GetSSAId(data, intIdentifier),
               3
            );
            return;
         }

         if (CompareType(type, cast(*Type_Info) u8x4)) {
            intIdentifier: Identifier = .{ type = ._Type, _type = cast(*Type_Info) u8 };

            WriteSingleInstruction(
               b,
               .TypeVector,
               GetSSAId(data, identifier),
               GetSSAId(data, intIdentifier),
               4
            );
            return;
         }

         if (CompareType(type, cast(*Type_Info) s32)) {
            WriteSingleInstruction(
               b,
               .TypeInt,
               GetSSAId(data, identifier),
               32,
               1
            );
            return;
         }

         if (CompareType(type, cast(*Type_Info) s32x2)) {
            intIdentifier: Identifier = .{ type = ._Type, _type = cast(*Type_Info) s32 };
            WriteTypeOrVariableOrConstant(data, b, intIdentifier);

            WriteSingleInstruction(
               b,
               .TypeVector,
               GetSSAId(data, identifier),
               GetSSAId(data, intIdentifier),
               2
            );
            return;
         }

         if (CompareType(type, cast(*Type_Info) s32x3)) {
            intIdentifier: Identifier = .{ type = ._Type, _type = cast(*Type_Info) s32 };
            WriteTypeOrVariableOrConstant(data, b, intIdentifier);

            WriteSingleInstruction(
               b,
               .TypeVector,
               GetSSAId(data, identifier),
               GetSSAId(data, intIdentifier),
               3
            );
            return;
         }

         if (CompareType(type, cast(*Type_Info) s32x4)) {
            intIdentifier: Identifier = .{ type = ._Type, _type = cast(*Type_Info) s32 };
            WriteTypeOrVariableOrConstant(data, b, intIdentifier);

            WriteSingleInstruction(
               b,
               .TypeVector,
               GetSSAId(data, identifier),
               GetSSAId(data, intIdentifier),
               4
            );
            return;
         }

         if (CompareType(type, cast(*Type_Info) u32)) {
            WriteSingleInstruction(
               b,
               .TypeInt,
               GetSSAId(data, identifier),
               32,
               0
            );
            return;
         }

         if (CompareType(type, cast(*Type_Info) u32x2)) {
            intIdentifier: Identifier = .{ type = ._Type, _type = cast(*Type_Info) u32 };
            WriteTypeOrVariableOrConstant(data, b, intIdentifier);

            WriteSingleInstruction(
               b,
               .TypeVector,
               GetSSAId(data, identifier),
               GetSSAId(data, intIdentifier),
               2
            );
            return;
         }

         if (CompareType(type, cast(*Type_Info) u32x3)) {
            intIdentifier: Identifier = .{ type = ._Type, _type = cast(*Type_Info) u32 };
            WriteTypeOrVariableOrConstant(data, b, intIdentifier);

            WriteSingleInstruction(
               b,
               .TypeVector,
               GetSSAId(data, identifier),
               GetSSAId(data, intIdentifier),
               3
            );
            return;
         }

         if (CompareType(type, cast(*Type_Info) u32x4)) {
            intIdentifier: Identifier = .{ type = ._Type, _type = cast(*Type_Info) u32 };
            WriteTypeOrVariableOrConstant(data, b, intIdentifier);

            WriteSingleInstruction(
               b,
               .TypeVector,
               GetSSAId(data, identifier),
               GetSSAId(data, intIdentifier),
               4
            );
            return;
         }

         if (CompareType(type, cast(*Type_Info) s64)) {
            WriteSingleInstruction(
               b,
               .TypeInt,
               GetSSAId(data, identifier),
               64,
               1
            );
            return;
         }

         if (CompareType(type, cast(*Type_Info) s64x2)) {
            intIdentifier: Identifier = .{ type = ._Type, _type = cast(*Type_Info) s64 };
            WriteTypeOrVariableOrConstant(data, b, intIdentifier);

            WriteSingleInstruction(
               b,
               .TypeVector,
               GetSSAId(data, identifier),
               GetSSAId(data, intIdentifier),
               2
            );
            return;
         }

         if (CompareType(type, cast(*Type_Info) s64x3)) {
            intIdentifier: Identifier = .{ type = ._Type, _type = cast(*Type_Info) s64 };
            WriteTypeOrVariableOrConstant(data, b, intIdentifier);

            WriteSingleInstruction(
               b,
               .TypeVector,
               GetSSAId(data, identifier),
               GetSSAId(data, intIdentifier),
               3
            );
            return;
         }

         if (CompareType(type, cast(*Type_Info) s64x4)) {
            intIdentifier: Identifier = .{ type = ._Type, _type = cast(*Type_Info) s64 };
            WriteTypeOrVariableOrConstant(data, b, intIdentifier);

            WriteSingleInstruction(
               b,
               .TypeVector,
               GetSSAId(data, identifier),
               GetSSAId(data, intIdentifier),
               4
            );
            return;
         }

         if (CompareType(type, cast(*Type_Info) u64)) {
            WriteSingleInstruction(
               b,
               .TypeInt,
               GetSSAId(data, identifier),
               64,
               0
            );
            return;
         }

         if (CompareType(type, cast(*Type_Info) u64x2)) {
            intIdentifier: Identifier = .{ type = ._Type, _type = cast(*Type_Info) u64 };
            WriteTypeOrVariableOrConstant(data, b, intIdentifier);

            WriteSingleInstruction(
               b,
               .TypeVector,
               GetSSAId(data, identifier),
               GetSSAId(data, intIdentifier),
               2
            );
            return;
         }

         if (CompareType(type, cast(*Type_Info) u64x3)) {
            intIdentifier: Identifier = .{ type = ._Type, _type = cast(*Type_Info) u64 };
            WriteTypeOrVariableOrConstant(data, b, intIdentifier);

            WriteSingleInstruction(
               b,
               .TypeVector,
               GetSSAId(data, identifier),
               GetSSAId(data, intIdentifier),
               3
            );
            return;
         }

         if (CompareType(type, cast(*Type_Info) u64x4)) {
            intIdentifier: Identifier = .{ type = ._Type, _type = cast(*Type_Info) u64 };
            WriteTypeOrVariableOrConstant(data, b, intIdentifier);

            WriteSingleInstruction(
               b,
               .TypeVector,
               GetSSAId(data, identifier),
               GetSSAId(data, intIdentifier),
               4
            );
            return;
         }

         if (CompareType(type, cast(*Type_Info) f32)) {
            WriteSingleInstruction(
               b,
               .TypeFloat,
               GetSSAId(data, identifier),
               32
            );
            return;
         }

         if (CompareType(type, cast(*Type_Info) f32x2)) {
            floatIdentifier: Identifier = .{ type = ._Type, _type = cast(*Type_Info) f32 };
            WriteTypeOrVariableOrConstant(data, b, floatIdentifier);

            WriteSingleInstruction(
               b,
               .TypeVector,
               GetSSAId(data, identifier),
               GetSSAId(data, floatIdentifier),
               2
            );
            return;
         }

         if (CompareType(type, cast(*Type_Info) f32x3)) {
            floatIdentifier: Identifier = .{ type = ._Type, _type = cast(*Type_Info) f32 };
            WriteTypeOrVariableOrConstant(data, b, floatIdentifier);

            WriteSingleInstruction(
               b,
               .TypeVector,
               GetSSAId(data, identifier),
               GetSSAId(data, floatIdentifier),
               3
            );
            return;
         }

         if (CompareType(type, cast(*Type_Info) f32x4)) {
            floatIdentifier: Identifier = .{ type = ._Type, _type = cast(*Type_Info) f32 };
            WriteTypeOrVariableOrConstant(data, b, floatIdentifier);

            WriteSingleInstruction(
               b,
               .TypeVector,
               GetSSAId(data, identifier),
               GetSSAId(data, floatIdentifier),
               4
            );
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

         if (CompareType(type, cast(*Type_Info) PushData)) {
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

            for tis.members {
               memberType := ConvertJaiTypeIfNecessary(it.type, it.notes);
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
            assert(tia.array_type == .FIXED, "array type: %. .VIEW is basically a fat pointer, i will support it when i support pointers. .RESIZABLE is i think kaputt, dont use it.", tia.array_type);

            elementType := tia.element_type;
            assert(tia.element_type.type != .POINTER && tia.element_type.type != .ARRAY, "tia.element_type.type: %. known limitation: cant use pointers inside array. wrap them in a struct for now", tia.element_type.type);
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
         name := GetVariableName(identifier);
         if (IdentifierCompare(identifier, data.meshVertexOutVariableIdentifier) || // [] MeshVertexOut
               IdentifierCompare(identifier, data.meshPrimitiveOutVariableIdentifier) || // [] MeshPrimitiveOut
               name == MESH_VERTICES_NAME ||
               name == MESH_TRIANGLES_NAME
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
         } else if(name == PUSH_DATA_VARIABLE_NAME) {
            pointerType := New(TypeInfoPointer);
            pointerType.pointerTo = cast(*Type_Info) PushData;
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
         } else if(name == SAMPLER_HEAP_VARIABLE_NAME) {
            voidStarUC := New(TypeInfoPointer);
            voidStarUC.pointerTo = cast(*Type_Info) void;
            voidStarUC.storageClass = .UniformConstant;

            typeIdentifier: Identifier = .{ type = ._Type, _type = voidStarUC };
            WriteTypeOrVariableOrConstant(data, b, typeIdentifier);

            #if SPIRV_BUILDER_TYPE == .String {
               print_to_builder(b, "; sampler heap variable\n");
            }

            WriteSingleInstruction(
               b,
               .UntypedVariableKHR,
               GetSSAId(data, typeIdentifier),
               GetSSAId(data, identifier),
               SpvStorageClass.UniformConstant
            );
         } else if(name == IMAGE_HEAP_VARIABLE_NAME) {
            voidStarUC := New(TypeInfoPointer);
            voidStarUC.pointerTo = cast(*Type_Info) void;
            voidStarUC.storageClass = .UniformConstant;

            typeIdentifier: Identifier = .{ type = ._Type, _type = voidStarUC };
            WriteTypeOrVariableOrConstant(data, b, typeIdentifier);

            #if SPIRV_BUILDER_TYPE == .String {
               print_to_builder(b, "; image heap variable\n");
            }

            WriteSingleInstruction(
               b,
               .UntypedVariableKHR,
               GetSSAId(data, typeIdentifier),
               GetSSAId(data, identifier),
               SpvStorageClass.UniformConstant
            );
         } else if(name == WORKGROUP_ID_VARIABLE_NAME) {
            pointerType := New(TypeInfoPointer);
            pointerType.pointerTo = cast(*Type_Info) u32x3;
            pointerType.storageClass = .Input;

            typeIdentifier: Identifier = .{ type = ._Type, _type = pointerType };
            WriteTypeOrVariableOrConstant(data, b, typeIdentifier);

            #if SPIRV_BUILDER_TYPE == .String {
               print_to_builder(b, "; workgroup id variable\n");
            }

            WriteSingleInstruction(
               b,
               .Variable,
               GetSSAId(data, typeIdentifier),
               GetSSAId(data, identifier),
               SpvStorageClass.Input
            );
         } else if(name == LOCAL_INVOCATION_ID_VARIABLE_NAME) {
            pointerType := New(TypeInfoPointer);
            pointerType.pointerTo = cast(*Type_Info) u32x3;
            pointerType.storageClass = .Input;

            typeIdentifier: Identifier = .{ type = ._Type, _type = pointerType };
            WriteTypeOrVariableOrConstant(data, b, typeIdentifier);

            #if SPIRV_BUILDER_TYPE == .String {
               print_to_builder(b, "; local invocation id variable\n");
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
      case .Mesh;       castedExpressionCode = code_of(__push_data__.meshData);
      case .Fragment;   castedExpressionCode = code_of(__push_data__.fragmentData);
      case; assert(false, "not yet implemented! type: %", shaderType);
   }

   right.expression = compiler_get_nodes(castedExpressionCode);
   return assignment;
}

GetStorageClassFromNote :: (note: string) -> SpvStorageClass {
   if (false) {}
   else if (note == PHYSICAL_STORAGE_BUFFER_QUALIFIER)   return .PhysicalStorageBuffer;
   else if (note == FUNCTION_QUALIFIER)                  return .Function;

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
   return sprint("%:%.%-%.%", node.location.enclosing_load.fully_pathed_filename, node.l0, node.c0, node.l1, node.c1);
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

   result.return_types = tip.return_types;
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
GenerateInstructions :: (data: *CompilationData, node: *Code_Node, general: *BuilderType, function: *BuilderType, currentFunction: *Code_Procedure_Header, additionalData: GenerateInstructionsData = .{}, lValueOut: *SSAId = null, spirvType: **Type_Info = null, lValueOutSpirvType: **Type_Info = null, identifierOut: *Identifier = null) -> SSAId {
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
         if (`additionalData.spirvShouldHaveBeenType.type == TYPE_INFO_DECORATIONLESS_COPY_OF_STRUCT_TAG) {
            resultSSAId = GetNextSSAId(`data);
            WriteSingleInstructionIfReachable(
               `function,
               *`data.isBlockReachable,
               .CopyLogical,
               GetSSAId(`data, .{ type = ._Type, _type = `additionalData.spirvShouldHaveBeenType }),
               resultSSAId,
               ssaId
            );
         } else {
            resultSSAId = DoCast(`data, `function, `additionalData.spirvShouldHaveBeenType, ssaIdSpirvType, ssaId, `node, spirvType = *resultSpirvType);
         }
      } else {
         resultSSAId = ssaId;
         resultSpirvType = ssaIdSpirvType;
      }

      if (`spirvType != null) `spirvType.* = resultSpirvType;
      `return resultSSAId;
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
      case .EXTRACT;                   #through;
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

      case .DIRECTIVE_RUN;
         assert(false, "do the #run outside the shader procedure to let jai compiler #run it. this compiler doesnt have #run");

      case .DIRECTIVE_POKE_NAME;
         assert(false, "idk what this directive is");

      case .DIRECTIVE_IMPORT;
         return 0; // i think i should skip? idk maybe

      case .TYPE_QUERY;
         // size_of, type_info
         assert(false, "read the comment above. i need a way to get the value somehow not the code nodes");

      case .DEFER;
         assert(false, "idk how to implement");

      case .USING;
         // should i ignore?
         return 0;

      case .DIRECTIVE_INSERT;
         assert(false, "read the comment above");

      case .DIRECTIVE_PROCEDURE_NAME;
         assert(false, "read the comment above");

      case .DIRECTIVE_EXISTS;
         assert(false, "read the comment above");

      case .DIRECTIVE_OVERLAY;
         assert(false, "i guess i should never see this. the parsing of structs is done through Type_Info, not through code nodes");

      // idk if this implementation is correct or do i need to do some other stuff.
      // right now it behaves as if there is no block
      case .BLOCK;
         cb := cast(*Code_Block)node;
         for cb.statements {
            GenerateInstructions(data, it, general, function, currentFunction);
         }
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

               if (type.type == .FLOAT) {
                  // jai doesnt allow casting from float to int so shouldHaveBeenType must also be float
                  assert(additionalData.spirvShouldHaveBeenType.type == .FLOAT, "type: %, loc: %", additionalData.spirvShouldHaveBeenType.*, GetLocationString(node));

                  identifier: Identifier = .{ type = .FloatLiteral, floatLiteral = xx cl._float64 };
                  if (identifierOut != null) identifierOut.* = identifier;
                  RETURN(GetSSAId(data, identifier), cast(*Type_Info) float);
               } else if (type.type == .INTEGER) {
                  assert(type.runtime_size == 4 || type.runtime_size == 8, "type.runtime_size: %, not implemented yet!", type.runtime_size);
                  tii := cast(*Type_Info_Integer) type;
                  identifier: Identifier;

                  if (additionalData.spirvShouldHaveBeenType.type == .INTEGER) {
                     // integer to integer

                     tiiShouldHaveBeen := cast(*Type_Info_Integer) additionalData.spirvShouldHaveBeenType;
                     BYTE_SIZE :: 8;
                     identifier = .{ type = .IntLiteral, intLiteral = .{ bitSize = additionalData.spirvShouldHaveBeenType.runtime_size * BYTE_SIZE, unsigned = !tiiShouldHaveBeen.signed } };

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

                     tifShouldHaveBeen := cast(*Type_Info_Float) additionalData.spirvShouldHaveBeenType;
                     identifier = .{ type = .FloatLiteral };

                     if (tii.signed) {
                        identifier.floatLiteral = xx cl._s64;
                     } else {
                        identifier.floatLiteral = xx cl._u64;
                     }
                  } else {
                     assert(false);
                  }

                  if (identifierOut != null) identifierOut.* = identifier;
                  RETURN(GetSSAId(data, identifier), additionalData.spirvShouldHaveBeenType);
               } else {
                  assert(false, "type: %", type.type);
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
               assert(type.type == .STRUCT, "type: %, loc: %:%", type.*, node.location.enclosing_load.fully_pathed_filename, node.location);

               tis := cast(*Type_Info_Struct) type;
               structLiteralInfo := cl.values.struct_literal_info;

               isConstant := IsStructLiteralConstant(cl);
               if (isConstant) {
                  identifier: Identifier = .{ type = .CompositeLiteral, compositeLiteral = .{ type = type } };
                  identifier.compositeLiteral.arguments = NewArray(structLiteralInfo.arguments.count, *Identifier);

                  for structLiteralInfo.arguments {
                     found, argumentNodeType := table_find(*data.codeNodeTypes, it);
                     assert(found);

                     shouldHaveBeenType := ConvertJaiTypeIfNecessary(tis.members[it_index].type, tis.members[it_index].notes);
                     argumentIdentifier: Identifier;
                     _ := GenerateInstructions(data, it, general, function, currentFunction, .{ spirvShouldHaveBeenType = shouldHaveBeenType }, identifierOut = *argumentIdentifier);
                     assert(argumentIdentifier.type != .Invalid, "struct: %, index: %, loc: %:%", tis.name, it_index, node.c0, node.l0);

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

                  for structLiteralInfo.arguments {
                     found, argumentNodeType := table_find(*data.codeNodeTypes, it);
                     assert(found);

                     shouldHaveBeenType := ConvertJaiTypeIfNecessary(tis.members[it_index].type, tis.members[it_index].notes);
                     argumentSSAId := GenerateInstructions(data, it, general, function, currentFunction, .{ spirvShouldHaveBeenType = shouldHaveBeenType });

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

            case .BOOLEAN; {
               identifier: Identifier = .{ type = .BoolLiteral };
               identifier.boolLiteral = cl._u64 != 0;

               if (identifierOut != null) identifierOut.* = identifier;
               RETURN(GetSSAId(data, identifier), type);
            }

            case; assert(false, "cl.value_type: %\n", cl.value_type);
         }

      case .IDENT;
         ci := cast(*Code_Ident) node;

         // if it is constant global variable like PI then what do i do?
         // i think i should evaluate its value and the identifier type would be either .IntLiteral or .FloatLiteral or .CompositeLiteral or .BoolLiteral.
         // so constant variable doesnt exists at runtime.
         // i guess that would work Clueless.oO(surely thats fine).
         //             - apila, 08/06/26
         declaration := ci.resolved_declaration;
         if (declaration.flags & .IS_CONSTANT) {
            identifier: Identifier;
            identifierSSAId := GenerateInstructions(data, declaration.expression, general, function, currentFunction, .{ spirvShouldHaveBeenType = declaration.type }, identifierOut = *identifier);
            assert(identifier.type != .Invalid); // if it is constant then it can't be .Invalid

            if (identifierOut != null) identifierOut.* = identifier;
            RETURN(identifierSSAId, declaration.type);
         }

         variableIdentifier := GetVariableIdentifier(ci);
         variableSSAId := GetSSAId(data, variableIdentifier);
         variableName := GetVariableName(variableIdentifier);
         variableStorageClass := GetVariableStorageClass(data, variableIdentifier);

         found, variableType := table_find(*data.codeNodeTypes, node);
         assert(found);

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

               RETURN(subexpressionLValueSSAId, subexpressionLValueSpirvType);
            }

            case #char "-"; {
               subexpressionSSAId := GenerateInstructions(data, cuo.subexpression, general, function, currentFunction);

               op: SpvOp;
               #if false {
               } else if (CompareType(subexpressionType, cast(*Type_Info) f32)   ||
                          CompareType(subexpressionType, cast(*Type_Info) f32x2) ||
                          CompareType(subexpressionType, cast(*Type_Info) f32x3) ||
                          CompareType(subexpressionType, cast(*Type_Info) f32x4)) {
                  op = .FNegate;
               } else if (CompareType(subexpressionType, cast(*Type_Info) s8)    ||
                          CompareType(subexpressionType, cast(*Type_Info) s32)   ||
                          CompareType(subexpressionType, cast(*Type_Info) s32x2) ||
                          CompareType(subexpressionType, cast(*Type_Info) s32x3) ||
                          CompareType(subexpressionType, cast(*Type_Info) s32x4) ||
                          CompareType(subexpressionType, cast(*Type_Info) s64)   ||
                          CompareType(subexpressionType, cast(*Type_Info) s64x2) ||
                          CompareType(subexpressionType, cast(*Type_Info) s64x3) ||
                          CompareType(subexpressionType, cast(*Type_Info) s64x4)) {
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

            case; assert(false, "not yet implemented! type: %", cuo.operator_type);
         }

      case .BINARY_OPERATOR;
         cbo := cast(*Code_Binary_Operator) node;

         if cbo.operator_type == {
            case #char "<"; {
               found1, rightType := table_find(*data.codeNodeTypes, cbo.right);
               assert(found1);
               found2, leftType := table_find(*data.codeNodeTypes, cbo.left);
               assert(found2);

               assert(CompareType(leftType, rightType), "not yet implemented!");
               type := leftType;

               resultSSAId := GetNextSSAId(data);

               leftSSAId := GenerateInstructions(data, cbo.left, general, function, currentFunction, .{ spirvShouldHaveBeenType = leftType });
               rightSSAId := GenerateInstructions(data, cbo.right, general, function, currentFunction, .{ spirvShouldHaveBeenType = rightType });

               resultType: *Type_Info;
               op: SpvOp;
               #if false {
               } else if (CompareType(type, cast(*Type_Info) s32)   ||
                          CompareType(type, cast(*Type_Info) s32x2) ||
                          CompareType(type, cast(*Type_Info) s32x3) ||
                          CompareType(type, cast(*Type_Info) s32x4) ||
                          CompareType(type, cast(*Type_Info) s64)   ||
                          CompareType(type, cast(*Type_Info) s64x2) ||
                          CompareType(type, cast(*Type_Info) s64x3) ||
                          CompareType(type, cast(*Type_Info) s64x4)) {
                  #if (false) {}
                  else if (CompareType(type, cast(*Type_Info) s32))   resultType = cast(*Type_Info) bool;
                  else if (CompareType(type, cast(*Type_Info) s32x2)) resultType = cast(*Type_Info) bool2;
                  else if (CompareType(type, cast(*Type_Info) s32x3)) resultType = cast(*Type_Info) bool3;
                  else if (CompareType(type, cast(*Type_Info) s32x4)) resultType = cast(*Type_Info) bool4;
                  else if (CompareType(type, cast(*Type_Info) s64))   resultType = cast(*Type_Info) bool;
                  else if (CompareType(type, cast(*Type_Info) s64x2)) resultType = cast(*Type_Info) bool2;
                  else if (CompareType(type, cast(*Type_Info) s64x3)) resultType = cast(*Type_Info) bool3;
                  else if (CompareType(type, cast(*Type_Info) s64x4)) resultType = cast(*Type_Info) bool4;

                  op = .SLessThan;
               } else if (CompareType(type, cast(*Type_Info) u8)    ||
                          CompareType(type, cast(*Type_Info) u8x2)  ||
                          CompareType(type, cast(*Type_Info) u8x3)  ||
                          CompareType(type, cast(*Type_Info) u8x4)  ||
                          CompareType(type, cast(*Type_Info) u32)   ||
                          CompareType(type, cast(*Type_Info) u32x2) ||
                          CompareType(type, cast(*Type_Info) u32x3) ||
                          CompareType(type, cast(*Type_Info) u32x4) ||
                          CompareType(type, cast(*Type_Info) u64)   ||
                          CompareType(type, cast(*Type_Info) u64x2) ||
                          CompareType(type, cast(*Type_Info) u64x3) ||
                          CompareType(type, cast(*Type_Info) u64x4)) {
                  #if (false) {}
                  else if (CompareType(type, cast(*Type_Info) u8))    resultType = cast(*Type_Info) bool;
                  else if (CompareType(type, cast(*Type_Info) u8x2))  resultType = cast(*Type_Info) bool2;
                  else if (CompareType(type, cast(*Type_Info) u8x3))  resultType = cast(*Type_Info) bool3;
                  else if (CompareType(type, cast(*Type_Info) u8x4))  resultType = cast(*Type_Info) bool4;
                  else if (CompareType(type, cast(*Type_Info) u32))   resultType = cast(*Type_Info) bool;
                  else if (CompareType(type, cast(*Type_Info) u32x2)) resultType = cast(*Type_Info) bool2;
                  else if (CompareType(type, cast(*Type_Info) u32x3)) resultType = cast(*Type_Info) bool3;
                  else if (CompareType(type, cast(*Type_Info) u32x4)) resultType = cast(*Type_Info) bool4;
                  else if (CompareType(type, cast(*Type_Info) u64))   resultType = cast(*Type_Info) bool;
                  else if (CompareType(type, cast(*Type_Info) u64x2)) resultType = cast(*Type_Info) bool2;
                  else if (CompareType(type, cast(*Type_Info) u64x3)) resultType = cast(*Type_Info) bool3;
                  else if (CompareType(type, cast(*Type_Info) u64x4)) resultType = cast(*Type_Info) bool4;

                  op = .ULessThan;
               } else {
                  assert(false, "not yet implemented! loc: %", node.location);
               }

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

            case .ARRAY_SUBSCRIPT; #through;
            case #char ".";
               chainSpirvType: *Type_Info;
               chainSSAId := DoDotsAndArraySubscripts2(data, function, cbo, currentFunction, additionalData.accessChainBaseArrayElementTypeIfImageHeap, additionalData.isLValue, lValueOut, *chainSpirvType, lValueOutSpirvType);
               RETURN(chainSSAId, chainSpirvType);

            case #char "/"; #through;
            case #char "*"; #through;
            case #char "-"; #through;
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
               leftId := GenerateInstructions(data, cbo.left, general, function, currentFunction, .{ spirvShouldHaveBeenType = leftType });
               rightId := GenerateInstructions(data, cbo.right, general, function, currentFunction, .{ spirvShouldHaveBeenType = rightType });

               binaryArithmeticSpirvType: *Type_Info;
               binaryArithmeticSSAId := DoBinaryArithmetic(data, function, leftType, leftId, rightType, rightId, cbo.operator_type, cbo, spirvType = *binaryArithmeticSpirvType);
               assert(binaryArithmeticSpirvType != null);

               RETURN(binaryArithmeticSSAId, binaryArithmeticSpirvType);
            }

            // c += x;
            // c = c + x;
            case .TIMES_ASSIGN; #through;
            case .PLUS_ASSIGN; {
               assert(cbo.left.kind == .IDENT ||
                     (cbo.left.kind == .BINARY_OPERATOR && cbo.left.(*Code_Binary_Operator).operator_type == #char ".") ||
                     (cbo.left.kind == .BINARY_OPERATOR && cbo.left.(*Code_Binary_Operator).operator_type == .ARRAY_SUBSCRIPT),
                     "cbo.left.kind: %", cbo.left.kind
               );

               found, leftType := table_find(*data.codeNodeTypes, cbo.left);
               assert(found);
               found2, rightType := table_find(*data.codeNodeTypes, cbo.right);
               assert(found2);

               rightId := GenerateInstructions(data, cbo.right, general, function, currentFunction, .{ spirvShouldHaveBeenType = leftType });

               leftLValueSSAId: SSAId = U32_MAX;
               leftLValueSpirvType: *Type_Info;
               leftRValueSSAId := GenerateInstructions(data, cbo.left, general, function, currentFunction, lValueOut = *leftLValueSSAId, lValueOutSpirvType = *leftLValueSpirvType);
               assert(leftLValueSSAId != U32_MAX, "lvalue was not set");
               assert(leftLValueSpirvType != null);
               assert(leftLValueSpirvType.type == TYPE_INFO_POINTER_TAG);

               tipLeftLValue := cast(*TypeInfoPointer) leftLValueSpirvType;

               operatorType: Operator_Type;
               if cbo.operator_type == {
                  case .TIMES_ASSIGN;  operatorType = #char "*";
                  case .PLUS_ASSIGN;   operatorType = #char "+";
                  case; assert(false, "not yet implemented! type: %", cbo.operator_type);
               }

               binaryArithmeticSpirvType: *Type_Info;
               binaryArithmeticSSAId := DoBinaryArithmetic(data, function, leftType, leftRValueSSAId, rightType, rightId, operatorType, node, spirvType = *binaryArithmeticSpirvType);
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

            case TEXTURE_FLOAT_2D_FUNCTION_NAME; #through;
            case TEXTURE_FLOAT_2D_LOD_FUNCTION_NAME; {
               sampledImageType := New(TypeInfoSampledImage);
               sampledImageType.image = New(TypeInfoImage);
               sampledImageType.image.* = .{
                  sampledType       = cast(*Type_Info) f32,
                  dimensionality    = ._2D,
                  depth             = 0,
                  arrayed           = 0,
                  ms                = 0,
                  sampled           = 1,
                  imageFormat       = .Unknown
               };

               imageSSAId := GenerateInstructions(data, arguments[0].expression, general, function, currentFunction, .{ accessChainBaseArrayElementTypeIfImageHeap = sampledImageType.image });
               samplerSSAId := GenerateInstructions(data, arguments[1].expression, general, function, currentFunction);
               uvSSAId := GenerateInstructions(data, arguments[2].expression, general, function, currentFunction);

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
               if (identifierName == TEXTURE_FLOAT_2D_FUNCTION_NAME) {
                  assert(arguments.count == 3, "arguments.count: %", arguments.count);

                  WriteSingleInstructionIfReachable(
                     function,
                     *data.isBlockReachable,
                     .ImageSampleImplicitLod,
                     GetSSAId(data, .{ type = ._Type, _type = cast(*Type_Info) f32x4 }),
                     sampledValueSSAId,
                     sampledImageSSAId,
                     uvSSAId
                  );
               } else if (identifierName == TEXTURE_FLOAT_2D_LOD_FUNCTION_NAME) {
                  assert(arguments.count == 4, "arguments.count: %", arguments.count);
                  lodSSAId := GenerateInstructions(data, arguments[3].expression, general, function, currentFunction);

                  WriteSingleInstructionIfReachable(
                     function,
                     *data.isBlockReachable,
                     .ImageSampleExplicitLod,
                     GetSSAId(data, .{ type = ._Type, _type = cast(*Type_Info) f32x4 }),
                     sampledValueSSAId,
                     sampledImageSSAId,
                     uvSSAId,
                     SpvImageOperandsMask.LodMask,
                     lodSSAId
                  );
               } else {
                  assert(false, "not yet implemented!");
               }

               RETURN(sampledValueSSAId, cast(*Type_Info) f32x4);
            }

            case MUL_FUNCTION_NAME; {
               // i use mul only for matrix x matrix multiplications
               // for the others i use the * operator. the reason is jai doesnt let me use the * operator for matrix types
               //       - apila, 14/05/26

               leftMatrixNode := arguments[0].expression;
               rightMatrixNode := arguments[1].expression;

               leftMatrixSSAId := GenerateInstructions(data, leftMatrixNode, general, function, currentFunction);
               rightMatrixSSAId := GenerateInstructions(data, rightMatrixNode, general, function, currentFunction);

               found, leftMatrixType := table_find(*data.codeNodeTypes, leftMatrixNode);
               assert(found);
               found2, rightMatrixType := table_find(*data.codeNodeTypes, rightMatrixNode);
               assert(found2);

               assert(CompareType(leftMatrixType, rightMatrixType), "try to use '*' instead");
               matrixType := leftMatrixType;

               resultSSAId := GetNextSSAId(data);
               WriteSingleInstructionIfReachable(
                  function,
                  *data.isBlockReachable,
                  .MatrixTimesMatrix,
                  GetSSAId(data, .{ type = ._Type, _type = matrixType }),
                  resultSSAId,
                  leftMatrixSSAId,
                  rightMatrixSSAId
               );

               RETURN(resultSSAId, matrixType);
            }

            case NORMALIZE_FUNCTION_NAME; {
               argumentNode := arguments[0].expression;
               argumentSSAId := GenerateInstructions(data, argumentNode, general, function, currentFunction);

               found, argumentType := table_find(*data.codeNodeTypes, argumentNode);
               assert(found);

               resultSSAId := GetNextSSAId(data);
               WriteSingleInstructionIfReachable(
                  function,
                  *data.isBlockReachable,
                  .ExtInst,
                  GetSSAId(data, .{ type = ._Type, _type = argumentType }), // also the return type
                  resultSSAId,
                  data.glslStd450,
                  GLSLstd450.Normalize,
                  argumentSSAId
               );

               RETURN(resultSSAId, argumentType);
            }

            case REFLECT_FUNCTION_NAME; {
               incidentNode := arguments[0].expression;
               normalNode := arguments[1].expression;

               incidentSSAId := GenerateInstructions(data, incidentNode, general, function, currentFunction);
               normalSSAId := GenerateInstructions(data, normalNode, general, function, currentFunction);

               found, incidentType := table_find(*data.codeNodeTypes, incidentNode);
               assert(found);
               found2, normalType := table_find(*data.codeNodeTypes, normalNode);
               assert(found2);

               assert(CompareType(incidentType, normalType));
               vectorType := incidentType; // type of each argument and the result type

               resultSSAId := GetNextSSAId(data);
               WriteSingleInstructionIfReachable(
                  function,
                  *data.isBlockReachable,
                  .ExtInst,
                  GetSSAId(data, .{ type = ._Type, _type = vectorType }),
                  resultSSAId,
                  data.glslStd450,
                  GLSLstd450.Reflect,
                  incidentSSAId,
                  normalSSAId
               );

               RETURN(resultSSAId, vectorType);
            }

            case LERP_FUNCTION_NAME; {
               aNode := arguments[0].expression;
               bNode := arguments[1].expression;
               tNode := arguments[2].expression;

               // aType == bType == tType == resultType
               type := header.arguments[0].type;

               aSSAId := GenerateInstructions(data, aNode, general, function, currentFunction, .{ spirvShouldHaveBeenType = type });
               bSSAId := GenerateInstructions(data, bNode, general, function, currentFunction, .{ spirvShouldHaveBeenType = type });
               tSSAId := GenerateInstructions(data, tNode, general, function, currentFunction, .{ spirvShouldHaveBeenType = type });

               resultSSAId := GetNextSSAId(data);
               WriteSingleInstructionIfReachable(
                  function,
                  *data.isBlockReachable,
                  .ExtInst,
                  GetSSAId(data, .{ type = ._Type, _type = type }),
                  resultSSAId,
                  data.glslStd450,
                  GLSLstd450.FMix,
                  aSSAId,
                  bSSAId,
                  tSSAId
               );

               RETURN(resultSSAId, type);
            }

            case LENGTH_FUNCTION_NAME; {
               argumentNode := arguments[0].expression;
               argumentType := GetNodeType(argumentNode);

               elementType := GetScalarTypeOrVectorElementType(argumentType);

               argumentSSAId := GenerateInstructions(data, argumentNode, general, function, currentFunction);

               resultSSAId := GetNextSSAId(data);
               WriteSingleInstructionIfReachable(
                  function,
                  *data.isBlockReachable,
                  .ExtInst,
                  GetSSAId(data, .{ type = ._Type, _type = elementType }),
                  resultSSAId,
                  data.glslStd450,
                  GLSLstd450.Length,
                  argumentSSAId
               );

               RETURN(resultSSAId, elementType);
            }

            case MAX_FUNCTION_NAME; {
               // max(x, y);
               xNode := arguments[0].expression;
               yNode := arguments[1].expression;

               // xType == yType == resultType
               argumentType := header.arguments[0].type;
               elementType := GetScalarTypeOrVectorElementType(argumentType);

               op: GLSLstd450;
               if elementType.type == {
                  case .INTEGER;
                     tii := cast(*Type_Info_Integer) elementType;
                     op = ifx tii.signed then .SMax else .UMax;
                  case .FLOAT;
                     op = .FMax; // maybe NMax?
                  case; assert(false);
               }

               xSSAId := GenerateInstructions(data, xNode, general, function, currentFunction, .{ spirvShouldHaveBeenType = argumentType });
               ySSAId := GenerateInstructions(data, yNode, general, function, currentFunction, .{ spirvShouldHaveBeenType = argumentType });

               resultSSAId := GetNextSSAId(data);
               WriteSingleInstructionIfReachable(
                  function,
                  *data.isBlockReachable,
                  .ExtInst,
                  GetSSAId(data, .{ type = ._Type, _type = argumentType }),
                  resultSSAId,
                  data.glslStd450,
                  op,
                  xSSAId,
                  ySSAId
               );

               RETURN(resultSSAId, argumentType);
            }

            case DOT_FUNCTION_NAME; {
               vector1Node := arguments[0].expression;
               vector2Node := arguments[1].expression;

               vector1Type := GetNodeType(vector1Node);
               vector2Type := GetNodeType(vector2Node);

               assert(CompareType(vector1Type, vector2Type));
               vectorType := vector1Type;

               componentType := GetScalarTypeOrVectorElementType(vectorType);

               vector1SSAId := GenerateInstructions(data, vector1Node, general, function, currentFunction);
               vector2SSAId := GenerateInstructions(data, vector2Node, general, function, currentFunction);

               resultSSAId := GetNextSSAId(data);
               WriteSingleInstructionIfReachable(
                  function,
                  *data.isBlockReachable,
                  .Dot,
                  GetSSAId(data, .{ type = ._Type, _type = componentType }),
                  resultSSAId,
                  vector1SSAId,
                  vector2SSAId
               );

               RETURN(resultSSAId, componentType);
            }

            case INVERSE_FUNCTION_NAME; {
               matrixNode := arguments[0].expression;
               matrixType := GetNodeType(matrixNode);

               matrixSSAId := GenerateInstructions(data, matrixNode, general, function, currentFunction);

               resultSSAId := GetNextSSAId(data);
               WriteSingleInstructionIfReachable(
                  function,
                  *data.isBlockReachable,
                  .ExtInst,
                  GetSSAId(data, .{ type = ._Type, _type = matrixType }),
                  resultSSAId,
                  data.glslStd450,
                  GLSLstd450.MatrixInverse,
                  matrixSSAId
               );

               RETURN(resultSSAId, matrixType);
            }

            case DDY_FUNCTION_NAME; #through;
            case DDX_FUNCTION_NAME; {
               // ddx(p)
               // in the spec it says component width must be 32 bit.
               pNode := arguments[0].expression;
               pType := header.arguments[0].type;

               pSSAId := GenerateInstructions(data, pNode, general, function, currentFunction, .{ spirvShouldHaveBeenType = pType });

               op: SpvOp;
               if identifierName == {
                  case DDY_FUNCTION_NAME; op = .DPdy;
                  case DDX_FUNCTION_NAME; op = .DPdx;
                  case; assert(false, "not yet implemented!");
               }

               resultSSAId := GetNextSSAId(data);
               WriteSingleInstructionIfReachable(
                  function,
                  *data.isBlockReachable,
                  op,
                  GetSSAId(data, .{ type = ._Type, _type = pType }),
                  resultSSAId,
                  pSSAId
               );

               RETURN(resultSSAId, pType);
            }

            case CROSS_FUNCTION_NAME; {
               // cross(x, y)
               xNode := arguments[0].expression;
               yNode := arguments[1].expression;

               // xType == yType == resultType == (f32x3 or f64x3 or f__x3)
               type := GetNodeType(xNode);

               xSSAId := GenerateInstructions(data, xNode, general, function, currentFunction, .{ spirvShouldHaveBeenType = type });
               ySSAId := GenerateInstructions(data, yNode, general, function, currentFunction, .{ spirvShouldHaveBeenType = type });

               resultSSAId := GetNextSSAId(data);
               WriteSingleInstructionIfReachable(
                  function,
                  *data.isBlockReachable,
                  .ExtInst,
                  GetSSAId(data, .{ type = ._Type, _type = type }),
                  resultSSAId,
                  data.glslStd450,
                  GLSLstd450.Cross,
                  xSSAId,
                  ySSAId
               );

               RETURN(resultSSAId, type);
            }

            case POW_FUNCTION_NAME; {
               // pow(x ,y)
               xNode := arguments[0].expression;
               yNode := arguments[1].expression;

               // xType == yType == resultType == (f32x_ or f16x_)
               type := header.arguments[0].type;

               xSSAId := GenerateInstructions(data, xNode, general, function, currentFunction, .{ spirvShouldHaveBeenType = type });
               ySSAId := GenerateInstructions(data, yNode, general, function, currentFunction, .{ spirvShouldHaveBeenType = type });

               resultSSAId := GetNextSSAId(data);
               WriteSingleInstructionIfReachable(
                  function,
                  *data.isBlockReachable,
                  .ExtInst,
                  GetSSAId(data, .{ type = ._Type, _type = type }),
                  resultSSAId,
                  data.glslStd450,
                  GLSLstd450.Pow,
                  xSSAId,
                  ySSAId
               );

               RETURN(resultSSAId, type);
            }

            case CLAMP_FUNCTION_NAME; {
               // clamp(x, minValue, maxValue)
               xNode := arguments[0].expression;
               minValueNode := arguments[1].expression;
               maxValueNode := arguments[2].expression;

               // xType == minValueType == maxValueType == resultType
               type := header.arguments[0].type;

               componentType := GetScalarTypeOrVectorElementType(type);
               op: GLSLstd450;
               if componentType.type == {
                  case .INTEGER;
                     tii := cast(*Type_Info_Integer) componentType;
                     op = ifx tii.signed then .SClamp else .UClamp;
                  case .FLOAT;
                     op = .FClamp;
                  case; assert(false);
               }

               xSSAId := GenerateInstructions(data, xNode, general, function, currentFunction, .{ spirvShouldHaveBeenType = type });
               minValueSSAId := GenerateInstructions(data, minValueNode, general, function, currentFunction, .{ spirvShouldHaveBeenType = type });
               maxValueSSAId := GenerateInstructions(data, maxValueNode, general, function, currentFunction, .{ spirvShouldHaveBeenType = type });

               resultSSAId := GetNextSSAId(data);
               WriteSingleInstructionIfReachable(
                  function,
                  *data.isBlockReachable,
                  .ExtInst,
                  GetSSAId(data, .{ type = ._Type, _type = type }),
                  resultSSAId,
                  data.glslStd450,
                  op,
                  xSSAId,
                  minValueSSAId,
                  maxValueSSAId
               );

               RETURN(resultSSAId, type);
            }

            case ATAN2_FUNCTION_NAME; {
               // atan2(y, x)
               yNode := arguments[0].expression;
               xNode := arguments[1].expression;

               // yType == xType == resultType
               type := header.arguments[0].type;

               ySSAId := GenerateInstructions(data, yNode, general, function, currentFunction, .{ spirvShouldHaveBeenType = type });
               xSSAId := GenerateInstructions(data, xNode, general, function, currentFunction, .{ spirvShouldHaveBeenType = type });

               resultSSAId := GetNextSSAId(data);
               WriteSingleInstructionIfReachable(
                  function,
                  *data.isBlockReachable,
                  .ExtInst,
                  GetSSAId(data, .{ type = ._Type, _type = type }),
                  resultSSAId,
                  data.glslStd450,
                  GLSLstd450.Atan2,
                  ySSAId,
                  xSSAId
               );

               RETURN(resultSSAId, type);
            }

            case ASIN_FUNCTION_NAME; {
               // asin(x)
               xNode := arguments[0].expression;

               // xType == resultType
               type := header.arguments[0].type;
               xSSAId := GenerateInstructions(data, xNode, general, function, currentFunction, .{ spirvShouldHaveBeenType = type });

               resultSSAId := GetNextSSAId(data);
               WriteSingleInstructionIfReachable(
                  function,
                  *data.isBlockReachable,
                  .ExtInst,
                  GetSSAId(data, .{ type = ._Type, _type = type }),
                  resultSSAId,
                  data.glslStd450,
                  GLSLstd450.Asin,
                  xSSAId
               );

               RETURN(resultSSAId, type);
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

         returnTypeIdentifier: Identifier = .{ type = ._Type, _type = returnType };
         resultSSAId := GetNextSSAId(data);

         operands: [..] Any;
         array_add(*operands, GetSSAId(data, returnTypeIdentifier));
         array_add(*operands, resultSSAId);
         array_add(*operands, GetSSAId(data, .{ type = .Function, function = header }));

         for cpc.arguments_unsorted {
            argumentType := GetNodeType(header.arguments[it_index]);
            argumentSSAId := GenerateInstructions(data, it.expression, general, function, currentFunction, .{ spirvShouldHaveBeenType = argumentType });

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

         RETURN(resultSSAId, returnType);

      case .LOOP_CONTROL;
         clc := cast(*Code_Loop_Control) node;

         if #complete clc.control_type == {
            case .BREAK; {
               assert(clc.target_ident == null, "not yet implemented! i think this means `break loop_variable;`.");

               WriteSingleInstructionIfReachable(
                  function,
                  *data.isBlockReachable,
                  .Branch,
                  data.currentLoopData.mergeLabelSSAId
               );

               return 99999999;
            }

            case .CONTINUE; {
               assert(clc.target_ident == null, "not yet implemented! i guess this means `continue loop_variable;`. this is very rarely used anyways");

               WriteSingleInstructionIfReachable(
                  function,
                  *data.isBlockReachable,
                  .Branch,
                  data.currentLoopData.continueLabelSSAId
               );

               return 9999998;
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

         data.currentLoopData = .{
            headerLabelSSAId     = headerLabelSSAId,
            conditionLabelSSAId  = conditionLabelSSAId,
            bodyLabelSSAId       = bodyLabelSSAId,
            continueLabelSSAId   = continueLabelSSAId,
            mergeLabelSSAId      = mergeLabelSSAId,
         };

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

         return 999999;

      case .IF;
         ci := cast(*Code_If) node;
         assert(!(ci.if_flags & .IS_SWITCH_STATEMENT), "not yet implemented!");
         assert(!(ci.if_flags & .IS_IFX), "not yet implemented!");
         assert(!(ci.if_flags & .IS_STATIC), "not yet implemented!");

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

         if (currentFunction == data.entryFunction) {
            if data.shaderType == {
               case .Mesh;
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

                  WriteSingleInstructionIfReachable(function, *data.isBlockReachable, .Return);

               case; assert(false, "not yet implemented! type: %", data.shaderType);
            }
         } else {
            returnTypeIdentifier := GetReturnTypeIdentifier(xx currentFunction.type);

            // related to the comment in GetReturnTypeIdentifier
            // assert(returnTypeIdentifier.type == ._Type);

            // if (CompareType(returnTypeIdentifier._type, cast(*Type_Info) void)) {
            if (returnTypeIdentifier.type == .Void) {
               WriteSingleInstructionIfReachable(function, *data.isBlockReachable, .Return);
            } else {
               assert(cr.arguments_unsorted.count == 1, "count: %", cr.arguments_unsorted.count);

               returnArgumentNode := cr.arguments_unsorted[0].expression;
               returnType := returnTypeIdentifier._type;

               returnArgumentSSAId := GenerateInstructions(data, returnArgumentNode, general, function, currentFunction, .{ spirvShouldHaveBeenType = returnType });
               WriteSingleInstructionIfReachable(function, *data.isBlockReachable, .ReturnValue, returnArgumentSSAId);
            }
         }

         return 543543; // return doesnt return any ssa id

      case .FOR;
      case .TYPE_DEFINITION;
      case .TYPE_INSTANTIATION;
      case .ENUM;
      case .STRUCT;
      case .COMMA_SEPARATED_ARGUMENTS;
      case .DECLARATION;
         cd := cast(*Code_Declaration) node;
         variableIdentifier: Identifier = .{ type = .Variable, variable.declaration = cd };
         variableSSAId := GetSSAId(data, variableIdentifier);

         found, variableType := table_find(*data.codeNodeTypes, node);
         assert(found);

         storageClass := SpvStorageClass.Function;
         variableTypeIdentifier: Identifier = .{ type = ._Type, _type = variableType };
         pointerTypeIdentifier := GetPointerTypeIdentifier(variableType, storageClass);

         useInitializer := false;
         expressionSSAId: SSAId;

         if (cd.expression != null) {
            found, expressionType := table_find(*data.codeNodeTypes, cd.expression);
            assert(found);

            // in the declaration apperantly i dont need to explicitly say the literalShouldHaveBeenType because jai does convert in this case.
            // but since i cant rely on it because it looks unstable and unfinished im gonna pass the literalShouldHaveBeenType
            //    - apila, 07/05/26
            expressionIdentifier: Identifier;
            expressionSSAId = GenerateInstructions(data, cd.expression, general, function, currentFunction, .{ spirvShouldHaveBeenType = variableType }, identifierOut = *expressionIdentifier);

            // here what im checking is if the expression is constant. and in case if it is constant its identifier is returned so it can't be invalid
            // hacky stinky solution.
            //          - apila, 08/06/26
            if (cd.expression.kind == .LITERAL && expressionIdentifier.type != .Invalid) {
               useInitializer = true;
            } else {
               // if you just declared something you cant be storing into PhysicalStorageBuffer therefore i dont need to use the dedicated Store function
               WriteSingleInstructionIfReachable(
                  function,
                  *data.isBlockReachable,
                  .Store,
                  variableSSAId,
                  expressionSSAId
               );
            }
         }

         // cant be untyped (VUID-StandaloneSpirv-OpTypeUntypedPointerKHR-11417)
         operands: [..] Any;
         array_add(*operands, GetSSAId(data, pointerTypeIdentifier));
         array_add(*operands, variableSSAId);
         array_add(*operands, storageClass);

         if (useInitializer) {
            array_add(*operands, expressionSSAId);
         }

         #if SPIRV_BUILDER_TYPE == .String {
            print_to_builder(general, "; %\n", GetVariableName(variableIdentifier));
         }

         WriteSingleInstructionIfReachable(
            general,
            *data.isBlockReachable,
            .Variable,
            .. operands
         );

         if (identifierOut != null) identifierOut.* = variableIdentifier;
         RETURN(variableSSAId, pointerTypeIdentifier._type);
      case .CAST;
         cc := cast(*Code_Cast) node;
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
      case .COMPOUND_DECLARATION;
   }

   assert(false, "didnt return!, node.kind: %, loc: %", node.kind, node.location);
   return 696969;
}

GetNodeType :: (node: *Code_Node) -> *Type_Info #expand {
   found, type := table_find(*`data.codeNodeTypes, node);
   assert(found);

   return type;
}

Signedness :: enum {
   Unsigned;
   Signed;
}

//
// following functions would be trivial if i vectors were not structs. thats so dumb but i dont have anything better. kayu
//       - apila, 06/06/26
//

GetVectorComponentCount :: (type: *Type_Info) -> int {
   assert(type.type == .STRUCT);
   tis := cast(*Type_Info_Struct) type;
   return tis.members.count;
}

GetScalarTypeOrVectorElementType :: (type: *Type_Info) -> *Type_Info {
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

IsIntScalarOrVector :: (type: *Type_Info) -> bool {
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

GetScalarOrVectorIntSignedness :: (type: *Type_Info) -> Signedness {
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

// this code (and other codes) would have been a lot cleaner if i were to have proper vector types.
//
// "spirvType" is always castTo. better remove it      - apila, 06/06/26
DoCast :: (data: *CompilationData, b: *BuilderType, castTo: *Type_Info, castFrom: *Type_Info, expressionSSAId: SSAId, node: *Code_Node, spirvType: **Type_Info = null) -> SSAId {
   castToIdentifier: Identifier = .{ type = ._Type, _type = castTo };
   castFromIdentifier: Identifier = .{ type = ._Type, _type = castFrom };

   if (spirvType != null) spirvType.* = castTo;

   bothPointer := castTo.type == TYPE_INFO_POINTER_TAG && castFrom.type == TYPE_INFO_POINTER_TAG;
   if (bothPointer) {
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
   assert(castTo.type != TYPE_INFO_POINTER_TAG && castFrom.type != TYPE_INFO_POINTER_TAG);

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

   #if false {
   } else if (CompareType(castFrom, cast(*Type_Info) s32)   ||
              CompareType(castFrom, cast(*Type_Info) s32x2) ||
              CompareType(castFrom, cast(*Type_Info) s32x3) ||
              CompareType(castFrom, cast(*Type_Info) s32x4) ||
              CompareType(castFrom, cast(*Type_Info) s64)   ||
              CompareType(castFrom, cast(*Type_Info) s64x2) ||
              CompareType(castFrom, cast(*Type_Info) s64x3) ||
              CompareType(castFrom, cast(*Type_Info) s64x4)) {
      if (IsIntScalarOrVector(castTo)) {
         // signed int to int

         sizeCastType: *Type_Info;
         castToSignedness := GetScalarOrVectorIntSignedness(castTo);
         if (castToSignedness == .Signed) {
            sizeCastType = castTo;
         }  else {
            #if false {}
            else if (CompareType(castTo, cast(*Type_Info) u32))    sizeCastType = cast(*Type_Info) s32;
            else if (CompareType(castTo, cast(*Type_Info) u32x2))  sizeCastType = cast(*Type_Info) s32x2;
            else if (CompareType(castTo, cast(*Type_Info) u32x3))  sizeCastType = cast(*Type_Info) s32x3;
            else if (CompareType(castTo, cast(*Type_Info) u32x4))  sizeCastType = cast(*Type_Info) s32x4;
            else if (CompareType(castTo, cast(*Type_Info) u64))    sizeCastType = cast(*Type_Info) s64;
            else if (CompareType(castTo, cast(*Type_Info) u64x2))  sizeCastType = cast(*Type_Info) s64x2;
            else if (CompareType(castTo, cast(*Type_Info) u64x3))  sizeCastType = cast(*Type_Info) s64x3;
            else if (CompareType(castTo, cast(*Type_Info) u64x4))  sizeCastType = cast(*Type_Info) s64x4;
            else assert(false, "not yet implemented!");
         }

         sizeCastSSAId: SSAId;
         if (!CompareType(castFrom, sizeCastType)) {
            sizeCastSSAId = GetNextSSAId(data);
            WriteSingleInstructionIfReachable(
               b,
               *data.isBlockReachable,
               .SConvert,
               GetSSAId(data, .{ type = ._Type, _type = sizeCastType }),
               sizeCastSSAId,
               expressionSSAId
            );
         } else {
            sizeCastSSAId = expressionSSAId;
         }

         resultSSAId: SSAId;
         if (castToSignedness != .Signed) {
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
         // signed int to float
         assert(IsFloatScalarOrVector(castTo));

         resultSSAId := GetNextSSAId(data);
         WriteSingleInstructionIfReachable(
            b,
            *data.isBlockReachable,
            .ConvertSToF,
            GetSSAId(data, .{ type = ._Type, _type = castTo }),
            resultSSAId,
            expressionSSAId
         );

         return resultSSAId;
      }
   } else if (CompareType(castFrom, cast(*Type_Info) u8)    ||
              CompareType(castFrom, cast(*Type_Info) u8x2)  ||
              CompareType(castFrom, cast(*Type_Info) u8x3)  ||
              CompareType(castFrom, cast(*Type_Info) u8x4)  ||
              CompareType(castFrom, cast(*Type_Info) u32)   ||
              CompareType(castFrom, cast(*Type_Info) u32x2) ||
              CompareType(castFrom, cast(*Type_Info) u32x3) ||
              CompareType(castFrom, cast(*Type_Info) u32x4) ||
              CompareType(castFrom, cast(*Type_Info) u64)   ||
              CompareType(castFrom, cast(*Type_Info) u64x2) ||
              CompareType(castFrom, cast(*Type_Info) u64x3) ||
              CompareType(castFrom, cast(*Type_Info) u64x4)) {
      if (IsIntScalarOrVector(castTo)) {
         // unsigned int to int

         castToSignedness := GetScalarOrVectorIntSignedness(castTo);
         sizeCastType: *Type_Info;
         if (castToSignedness == .Unsigned) {
            sizeCastType = castTo;
         }  else {
            #if false {}
            else if (CompareType(castTo, cast(*Type_Info) s32))    sizeCastType = cast(*Type_Info) u32;
            else if (CompareType(castTo, cast(*Type_Info) s32x2))  sizeCastType = cast(*Type_Info) u32x2;
            else if (CompareType(castTo, cast(*Type_Info) s32x3))  sizeCastType = cast(*Type_Info) u32x3;
            else if (CompareType(castTo, cast(*Type_Info) s32x4))  sizeCastType = cast(*Type_Info) u32x4;
            else if (CompareType(castTo, cast(*Type_Info) s64))    sizeCastType = cast(*Type_Info) u64;
            else if (CompareType(castTo, cast(*Type_Info) s64x2))  sizeCastType = cast(*Type_Info) u64x2;
            else if (CompareType(castTo, cast(*Type_Info) s64x3))  sizeCastType = cast(*Type_Info) u64x3;
            else if (CompareType(castTo, cast(*Type_Info) s64x4))  sizeCastType = cast(*Type_Info) u64x4;
            else assert(false, "not yet implemented!");
         }

         sizeCastSSAId: SSAId;
         if (!CompareType(castFrom, sizeCastType)) {
            sizeCastSSAId = GetNextSSAId(data);
            WriteSingleInstructionIfReachable(
               b,
               *data.isBlockReachable,
               .UConvert,
               GetSSAId(data, .{ type = ._Type, _type = sizeCastType }),
               sizeCastSSAId,
               expressionSSAId
            );
         } else {
            sizeCastSSAId = expressionSSAId;
         }

         resultSSAId: SSAId;
         if (castToSignedness != .Unsigned) {
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
         // unsigned int to float
         assert(IsFloatScalarOrVector(castTo));

         resultSSAId := GetNextSSAId(data);
         WriteSingleInstructionIfReachable(
            b,
            *data.isBlockReachable,
            .ConvertUToF,
            GetSSAId(data, .{ type = ._Type, _type = castTo }),
            resultSSAId,
            expressionSSAId
         );

         return resultSSAId;
      }
   } else {
      assert(false, "not yet implemented! castFrom: %, loc: %", castFrom.*, GetLocationString(node));
      return 0;
   }
}

// *, +, -, /, %
// any binary operator that has this spirv signature:
//    <id>          <id>      <id>        <id>
//  Result Type    Result   Operand 1   Operand 2
DoBinaryArithmetic :: (data: *CompilationData, b: *BuilderType, leftType: *Type_Info, leftId: SSAId, rightType: *Type_Info, rightId: SSAId, operatorType: Operator_Type, node: *Code_Node, spirvType: **Type_Info = null) -> SSAId {
   resultSSAId := GetNextSSAId(data);

   if (CompareType(rightType, leftType)) {
      type := leftType;

      if (spirvType != null) spirvType.* = type;

      typeIdentifier: Identifier = .{ type = ._Type, _type = type };
      if (CompareType(type, cast(*Type_Info) f32)   ||
          CompareType(type, cast(*Type_Info) f32x2) ||
          CompareType(type, cast(*Type_Info) f32x3) ||
          CompareType(type, cast(*Type_Info) f32x4)) {
         op := GetFloatOpFromOperatorType(operatorType);
         WriteSingleInstructionIfReachable(
            b,
            *data.isBlockReachable,
            op,
            GetSSAId(data, typeIdentifier),
            resultSSAId,
            leftId,
            rightId
         );
      } else if (CompareType(type, cast(*Type_Info) u8)    ||
                 CompareType(type, cast(*Type_Info) u8x2)  ||
                 CompareType(type, cast(*Type_Info) u8x3)  ||
                 CompareType(type, cast(*Type_Info) u8x4)  ||
                 CompareType(type, cast(*Type_Info) s32)   ||
                 CompareType(type, cast(*Type_Info) s32x2) ||
                 CompareType(type, cast(*Type_Info) s32x3) ||
                 CompareType(type, cast(*Type_Info) s32x4) ||
                 CompareType(type, cast(*Type_Info) u32)   ||
                 CompareType(type, cast(*Type_Info) u32x2) ||
                 CompareType(type, cast(*Type_Info) u32x3) ||
                 CompareType(type, cast(*Type_Info) u32x4) ||
                 CompareType(type, cast(*Type_Info) s64)   ||
                 CompareType(type, cast(*Type_Info) s64x2) ||
                 CompareType(type, cast(*Type_Info) s64x3) ||
                 CompareType(type, cast(*Type_Info) s64x4) ||
                 CompareType(type, cast(*Type_Info) u64)   ||
                 CompareType(type, cast(*Type_Info) u64x2) ||
                 CompareType(type, cast(*Type_Info) u64x3) ||
                 CompareType(type, cast(*Type_Info) u64x4)) {
         op := GetIntegerOpFromOperatorType(operatorType);
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
         assert(false, "not implemented yet! type: %\n", type.*);
      }
   } else {
      // either need to broadcast from scalar to vector type
      // or if it is multiplication there are specific instructions for the multiplication. i should use them.

      if (operatorType == #char "*") {
         isLeftMatrix := CompareType(leftType, cast(*Type_Info) mat2) ||
                         CompareType(leftType, cast(*Type_Info) mat3) ||
                         CompareType(leftType, cast(*Type_Info) mat4);
         isRightVector := CompareType(rightType, cast(*Type_Info) f32x2) ||
                          CompareType(rightType, cast(*Type_Info) f32x3) ||
                          CompareType(rightType, cast(*Type_Info) f32x4);

         if (isLeftMatrix && isRightVector) {
            WriteSingleInstructionIfReachable(
               b,
               *data.isBlockReachable,
               .MatrixTimesVector,
               GetSSAId(data, .{ type = ._Type, _type = rightType }),
               resultSSAId,
               leftId,
               rightId
            );

            if (spirvType != null) spirvType.* = rightType;
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
         for cb.statements {
            DetermineCodeNodeTypes(data, it);
         }

         TableAdd(*data.codeNodeTypes, node, cast(*Type_Info) void);
         return cast(*Type_Info) void;

      case .LITERAL;
         cl := cast(*Code_Literal) node;

         // maybe i should determine the type of parent nodes from somewhere else.
         // like for example if it is a declaration then from the decalration notes.
         // maybe for this kind of things i need a seperate entry in the CompilationData.codeNodeTypes
         // that says that i should ignore the type of this node.
         //       - apila, 25/04/26
         assert(cl.value_type != .POINTER, "is it something other than null?");

         // this is not sufficient.
         // if struct has members of type pointers then to be able to correctly determine the type of the member
         // i need to pass the Type_Info_Struct to the members through DetermineCodeNodeTypes.
         //    - apila, 26/04/26
         if (cl.value_type == .STRUCT) {
            for cl.struct_literal_info.arguments {
               DetermineCodeNodeTypes(data, it);
            }
         } else if (cl.value_type == .ARRAY) {
            for cl.array_literal_info.array_members {
               DetermineCodeNodeTypes(data, it);
            }
         }

         TableAdd(*data.codeNodeTypes, node, node.type);
         return node.type;

      // this case only called if accessing single variable (no access chains)
      // so it must be a variable declared somewhere
      case .IDENT;
         ci := cast(*Code_Ident) node;
         declaration := ci.resolved_declaration;
         assert(declaration != null, "ident loc: %", ci.location);

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
            case .TIMES_ASSIGN; #through;
            case .DIV_ASSIGN;   #through;
            case .MOD_ASSIGN;   #through;
            case .MINUS_ASSIGN; #through;
            case .PLUS_ASSIGN;  #through;
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
            case #char "%";
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
               leftType := DetermineCodeNodeTypes(data, cbo.left);

               tis: *Type_Info_Struct;
               if leftType.type == {
                  case TYPE_INFO_DECORATIONLESS_COPY_OF_STRUCT_TAG;
                     tidcos := cast(*TypeInfoDecorationlessCopyOfStruct) leftType;
                     tis = tidcos.copyOf;
                  case .STRUCT;
                     tis = cast(*Type_Info_Struct) leftType;

                  case TYPE_INFO_POINTER_TAG;
                     tip := cast(*TypeInfoPointer) leftType;
                     assert(tip.pointerTo.type == .STRUCT, "type: %", tip.pointerTo.type);

                     tis = xx tip.pointerTo;

                  // left hand side is a named module
                  case .TYPE;
                     // type equal to type of right side
                     assert(cbo.right.kind == .IDENT, "kind: %", cbo.right.kind);
                     ci := cast(*Code_Ident) cbo.right;
                     rightType := DetermineCodeNodeTypes(data, ci.resolved_declaration);

                     // normally i dont add the type of the right node to the table since i dont use it when generating instructions.
                     // but this is an exception, i do use it.
                     TableAdd(*data.codeNodeTypes, cbo.right, rightType);

                     TableAdd(*data.codeNodeTypes, node, rightType);
                     return rightType;

                  case; assert(false, "type: %", leftType.type);
               }

               assert(cbo.right.kind == .IDENT, "cbo.right.kind: %", cbo.right.kind);
               right := cast(*Code_Ident) cbo.right;

               memberIndex := GetMemberIndex(tis, right.name);
               assert(memberIndex != MEMBER_DOESNT_EXIST);

               member := tis.members[memberIndex];
               notes := member.notes;
               newMemberType := ConvertJaiTypeIfNecessary(member.type, notes);

               TableAdd(*data.codeNodeTypes, node, newMemberType);
               return newMemberType;

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

                  case; assert(false, "type: %", leftType.type); return null;
               }


            case; assert(false, "operator: %", cbo.operator_type);
         }

      case .PROCEDURE_HEADER; {
         cph := cast(*Code_Procedure_Header) node;

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

      // TODO
      // recurse DetermineCodeNodeTypes into the called function
      //
      // idk. maybe recurse into the header which then recurses into the block.
      // recurse only if it is constant. that is if it is not ident. or maybe you can assert that if it is ident then it has to be
      // intrinsic function
      //       - apila, 26/04/26
      case .PROCEDURE_CALL;
         cpc := cast(*Code_Procedure_Call) node;
         assert(cpc.resolved_procedure_expression != null, "loc: %", cpc.location);
         assert(cpc.resolved_procedure_expression.kind == .PROCEDURE_HEADER || // constant function
                cpc.resolved_procedure_expression.kind == .IDENT || // not constant function (intrinsics go here)
                cpc.resolved_procedure_expression.kind == .BINARY_OPERATOR, // namespaces
                "kind: %", cpc.resolved_procedure_expression.kind
         );

         header := GetHeaderFromCodeProcedureCall(cpc);
         assert(header.returns.count <= 1, "multiple returns not yet implemented! count: %", header.returns.count);

         // recurse into the procedure
         DetermineCodeNodeTypes(data, header);

         for cpc.arguments_unsorted {
            DetermineCodeNodeTypes(data, it.expression);
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
         if (cd.expression != null) {
            DetermineCodeNodeTypes(data, cd.expression);
         }

         type := ConvertJaiTypeIfNecessary(cd.type, cd.notes);

         isGlobalConstant := table_contains(*globalConstantDeclarations, cd);
         isLocalDeclaration := !isGlobalConstant;

         // i am not sure but this might need to be recursive.
         // that is if a member is also a struct i might need to recurse into it too. idk
         //          - apila, 07/06/26
         //
         // since i dont have a proper vector type, i have to manually check, again.
         //          - apila, 07/06/26
         if (  isLocalDeclaration                           &&
               type.type == .STRUCT                         &&
               !CompareType(type, cast(*Type_Info) bool2)   &&
               !CompareType(type, cast(*Type_Info) bool3)   &&
               !CompareType(type, cast(*Type_Info) bool4)   &&
               !CompareType(type, cast(*Type_Info) u8x2)    &&
               !CompareType(type, cast(*Type_Info) u8x3)    &&
               !CompareType(type, cast(*Type_Info) u8x4)    &&
               !CompareType(type, cast(*Type_Info) s32x2)   &&
               !CompareType(type, cast(*Type_Info) s32x3)   &&
               !CompareType(type, cast(*Type_Info) s32x4)   &&
               !CompareType(type, cast(*Type_Info) u32x2)   &&
               !CompareType(type, cast(*Type_Info) u32x3)   &&
               !CompareType(type, cast(*Type_Info) u32x4)   &&
               !CompareType(type, cast(*Type_Info) s64x2)   &&
               !CompareType(type, cast(*Type_Info) s64x3)   &&
               !CompareType(type, cast(*Type_Info) s64x4)   &&
               !CompareType(type, cast(*Type_Info) u64x2)   &&
               !CompareType(type, cast(*Type_Info) u64x3)   &&
               !CompareType(type, cast(*Type_Info) u64x4)   &&
               !CompareType(type, cast(*Type_Info) f32x2)   &&
               !CompareType(type, cast(*Type_Info) f32x3)   &&
               !CompareType(type, cast(*Type_Info) f32x4)) {
            newType := New(TypeInfoDecorationlessCopyOfStruct);
            newType.runtime_size = type.runtime_size;
            newType.copyOf = xx type;

            type = newType;
         }

         TableAdd(*data.codeNodeTypes, node, type);
         return type;

      case .CAST;
         cc := cast(*Code_Cast) node;
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

         // return statement doesnt have any type
         TableAdd(*data.codeNodeTypes, node, cast(*Type_Info) void);
         return cast(*Type_Info) void;

      case .IF; {
         ci := cast(*Code_If) node;
         assert(!(ci.if_flags & .IS_SWITCH_STATEMENT), "not yet implemented!");
         assert(!(ci.if_flags & .IS_IFX), "not yet implemented!");
         assert(!(ci.if_flags & .IS_STATIC), "not yet implemented!");

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
            case #char "-"; {
               resultType = cuo.type;
            }

            case .POINTER_DEREFERENCE; #through;
            case .POSTFIX_DEREFERENCE; {
               assert(subexpressionType.type == TYPE_INFO_POINTER_TAG, "can only derefence a pointer!");

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

               tip.storageClass = .PhysicalStorageBuffer;
               tip.pointerTo = subexpressionType;
            }

            case; assert(false, "not yet implemented! type: %", cuo.operator_type);
         }

         TableAdd(*data.codeNodeTypes, node, resultType);
         return resultType;
      }

      case; assert(false, "not yet implemented! kind: %", node.kind);
   }

   assert(false, "didnt return! kind: %", node.kind);
   return null;
}

UnwindVariantsUpToDistinct :: #bake_arguments UnwindVariants(ignoreDistinct = false);
UnwindVariantsAllTheWay :: #bake_arguments UnwindVariants(ignoreDistinct = true);

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
alignof :: ($T: Type) -> s64 #expand {
    return #run -> s64 {
        info := type_info(struct{ p: u8; t: T; });
        return info.members[1].offset_in_bytes;
    };
}

// jblow said on discord that he will move the alignment field from Code_Struct to Type_Info_Struct. so i can properly implement this function
VeryBadImplementedAlignOfBecauseIDontKnowHowToUseTheProperOneInAMetaprogramWhereTypeIsNotConstantSecondTake :: (type: *Type_Info) -> int {
   if type.type == {
      case .INTEGER;
         return type.runtime_size;

      case .FLOAT;
         return type.runtime_size;

      case .BOOL;
         return 4;

      case .STRING;
         assert(false);

      case .POINTER;
         return type.runtime_size;

      case .STRUCT;
         tis := cast(*Type_Info_Struct) type;

         maxAlignment := 0;
         for tis.members {
            memberAlignment := VeryBadImplementedAlignOfBecauseIDontKnowHowToUseTheProperOneInAMetaprogramWhereTypeIsNotConstantSecondTake(it.type);
            maxAlignment = max(maxAlignment, memberAlignment);
         }
         assert(maxAlignment != 0, "name: %", tis.name);

         return maxAlignment;
      case .ARRAY;
         tia := cast(*Type_Info_Array) type;
         return VeryBadImplementedAlignOfBecauseIDontKnowHowToUseTheProperOneInAMetaprogramWhereTypeIsNotConstantSecondTake(tia.element_type);

      case .ENUM;
         tie := cast(*Type_Info_Enum) type;
         return tie.internal_type.runtime_size;

      case TYPE_INFO_POINTER_TAG;
         return type.runtime_size;

      case .VARIANT;
         unwindedType := UnwindVariantsAllTheWay(type);
         return VeryBadImplementedAlignOfBecauseIDontKnowHowToUseTheProperOneInAMetaprogramWhereTypeIsNotConstantSecondTake(unwindedType);

      case; assert(false, "type: %", type.type);
   }

   assert(false, "type: %", type.type);
   return -789;
}

// it writes "(some type)"
VeryBadImplementedAlignOfBecauseIDontKnowHowToUseTheProperOneInAMetaprogramWhereTypeIsNotConstant :: (type: Type) -> int {
   #import "Random";
   #import "File";
   #import "Process";

   rng := random_get();
   outputFileName := sprint("temp%", rng);
   tempFileName := sprint("temp%.jai", rng);

   codeFormat := #string JAI
      #import "Basic";

      alignof :: ($T: Type) -> s64 #expand {
         return #run -> s64 {
            info := type_info(struct{ p: u8; t: T; });
            return info.members[1].offset_in_bytes;
         };
      }

      main :: () {
         result := alignof(%);
         print("\%", result);
      }
   JAI

   code := sprint(codeFormat, type);
   ok := write_entire_file(tempFileName, code);
   assert(ok);

   defer file_delete(tempFileName);

   compileResult := run_command("jai-linux", tempFileName);
   assert(compileResult.type == .EXITED);
   assert(compileResult.exit_code == 0);

   processResult, outputString, errorString, timeoutReached := run_command(outputFileName, capture_and_return_output = true);
   assert(!timeoutReached);
   assert(errorString == "");
   assert(processResult.type == .EXITED);
   assert(processResult.exit_code == 0);

   file_delete(outputFileName);

   result, success := string_to_int(outputString);
   assert(success);

   return result;
}

// use this if the storage class might be PhysicalStorageBuffer.
// if you are sure that it can't be PhysicalStorageBuffer, you can directly use WriteSingleInstructionIfReachable.
// type: spirv type of the thing you store
Store :: (data: *CompilationData, b: *BuilderType, storeTo: SSAId, storeWhat: SSAId, storingToPhysicalStorageBuffer: bool, type: *Type_Info) {
   operands: [..] Any;
   array_add(*operands, storeTo);
   array_add(*operands, storeWhat);

   if (storingToPhysicalStorageBuffer) {
      array_add(*operands, SpvMemoryAccessMask.AlignedMask, VeryBadImplementedAlignOfBecauseIDontKnowHowToUseTheProperOneInAMetaprogramWhereTypeIsNotConstantSecondTake(type));
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
      array_add(*operands, SpvMemoryAccessMask.AlignedMask, VeryBadImplementedAlignOfBecauseIDontKnowHowToUseTheProperOneInAMetaprogramWhereTypeIsNotConstantSecondTake(typeIdentifier._type));
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
IsStructLiteralConstant :: (literal: *Code_Literal) -> bool {
   // assume result is true and set to false if not constant
   Helper :: (literal: *Code_Literal, result: *bool) {
      if literal.value_type == {
         case .ARRAY; #through;
         case .STRUCT;
            array := ifx literal.value_type == .STRUCT then literal.struct_literal_info.arguments else literal.array_literal_info.array_members;
            for array {
               // i am being lazy here and saying if it is not literal then gg
               // but thats not true. it could be a constant variable.
               //
               // is there a better way to check if a code node has a compile time constant value?
               //          - apila, 18/04/26
               if (it.kind != .LITERAL) {
                  result.* = false;
                  return;
               }

               cl := cast(*Code_Literal) it;
               Helper(cl, result);
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
   Helper(literal, *result);

   return result;
}

GetVariableIdentifier :: (ci: *Code_Ident) -> Identifier {
   if (ci.name == MESH_VERTICES_NAME            ||
       ci.name == MESH_TRIANGLES_NAME           ||
       ci.name == PUSH_DATA_VARIABLE_NAME       ||
       ci.name == IMAGE_HEAP_VARIABLE_NAME      ||
       ci.name == SAMPLER_HEAP_VARIABLE_NAME    ||
       ci.name == WORKGROUP_ID_VARIABLE_NAME    ||
       ci.name == LOCAL_INVOCATION_ID_VARIABLE_NAME) {
      return .{ type = .Variable, variable = .{ useName = true, name = ci.name } };
   }

   return .{ type = .Variable, variable.declaration = ci.resolved_declaration };
}

// this function returns the storage class of the variable. not where the storage class of where it points to if it is a pointer
GetVariableStorageClass :: (data: *CompilationData, variable: Identifier) -> SpvStorageClass {
   assert(variable.type == .Variable, "type: %", variable.type);

   declaration := variable.variable;
   name := GetVariableName(variable);

   if (name == MESH_VERTICES_NAME) {
      return .Output;
   }

   if (name == MESH_TRIANGLES_NAME) {
      return .Output;
   }

   if (name == PUSH_DATA_VARIABLE_NAME) {
      return .PushConstant;
   }

   if (name == IMAGE_HEAP_VARIABLE_NAME) {
      return .UniformConstant;
   }

   if (name == SAMPLER_HEAP_VARIABLE_NAME) {
      return .UniformConstant;
   }

   if (name == WORKGROUP_ID_VARIABLE_NAME) {
      return .Input;
   }

   if (name == LOCAL_INVOCATION_ID_VARIABLE_NAME) {
      return .Input;
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

   // user declared variables are always in a function.
   //
   // the note above is true since i do not allow global variables yet. idk what to do when i do allow global variables. maybe qualifiers may come in handy
   //    - apila, 29/05/26
   return .Function;
}

GetVariableName :: (variable: Identifier) -> string {
   assert(variable.type == .Variable);

   if (variable.variable.useName) {
      return variable.variable.name;
   } else {
      return variable.variable.declaration.name;
   }
}

// i need this function because some of the variables, their jai types doesnt match the spirv i want to generate.
// for example meshvertices is declared as an array view but is a fixed size array.
GetVariableTypeIdentifier :: (data: *CompilationData, variable: Identifier) -> Identifier {
   // if an array
   GetElementType :: (declaration: *Code_Declaration) -> *Type_Info #expand {
      assert(declaration.type.type == .ARRAY, "type: %", declaration.type.type);
      tip := cast(*Type_Info_Array) declaration.type;
      return tip.element_type;
   }

   CreateTypeInfoArray :: (elementType: *Type_Info, arrayCount: int) -> *Type_Info_Array #expand {
      typeInfo := New(Type_Info_Array);
      typeInfo.type = .ARRAY;
      typeInfo.element_type = elementType;
      typeInfo.array_type = .FIXED;
      typeInfo.array_count = arrayCount;

      return typeInfo;
   }

   assert(variable.type == .Variable, "variable.type: %", variable.type);

   declaration := variable.variable.declaration;
   name := GetVariableName(variable);

   if (name == MESH_VERTICES_NAME) {
      elementType := cast(*Type_Info) MeshPerVertex;

      typeInfo := CreateTypeInfoArray(elementType, data.maxVertices);
      return .{ type = ._Type, _type = typeInfo };
   }

   if (name == MESH_TRIANGLES_NAME) {
      elementType := cast(*Type_Info) s32x3;

      typeInfo := CreateTypeInfoArray(elementType, data.maxPrimitives);
      return .{ type = ._Type, _type = typeInfo };
   }

   if (IdentifierCompare(variable, data.meshVertexOutVariableIdentifier)) {
      elementType := GetElementType(declaration);
      typeInfo := CreateTypeInfoArray(elementType, data.maxVertices);
      return .{ type = ._Type, _type = typeInfo };
   }

   if (IdentifierCompare(variable, data.meshPrimitiveOutVariableIdentifier)) {
      elementType := GetElementType(declaration);
      typeInfo := CreateTypeInfoArray(elementType, data.maxVertices);
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

DoDotsAndArraySubscripts2 :: (data: *CompilationData, b: *BuilderType, cbo: *Code_Binary_Operator, currentFunction: *Code_Procedure_Header, baseArrayElementTypeIfImageHeap: *TypeInfoImage, isLValue: bool, lValueOut: *SSAId = null, spirvType: **Type_Info = null, lValueOutSpirvType: **Type_Info = null) -> SSAId {
   DoMemberAccess :: (tis: *Type_Info_Struct, right: *Code_Node, indices: *[..] SSAId, literalIndices: *[..] int, isBaseSpirvPointer: bool) #expand {
      assert(right.kind == .IDENT, "if you are accessing a struct indexer it is not yet implemented! right.kind: %, struct name: %, loc: %", right.kind, tis.name, right.location);
      ci := cast(*Code_Ident) right;

      memberIndex := GetMemberIndex(tis, ci.name);
      assert(memberIndex != MEMBER_DOESNT_EXIST, "not a member of struct! struct: %, member: %", tis.name, ci.name);

      if (isBaseSpirvPointer) {
         memberIndexIdentifier: Identifier = .{ type = .IntLiteral, intLiteral = .{ unsigned = false, value._s64 = memberIndex, bitSize = 32 } };
         memberIndexSSAId := GetSSAId(`data, memberIndexIdentifier);
         array_add(indices, memberIndexSSAId);
      } else {
         array_add(literalIndices, memberIndex);
      }
   }

   DoProcedureCallBase :: (baseNode: *Code_Procedure_Call) #expand {
      assert(baseNode.kind == .PROCEDURE_CALL);

      data := `data;
      `currentBaseSSAId.* = GenerateInstructions(`data, baseNode, null, `b, `currentFunction);
      `currentBaseSpirvType.* = GetNodeType(baseNode);
   }

   DoAccessChainOrCompositeExtract :: (data: *CompilationData,
                                       b: *BuilderType,
                                       jaiReturnType: *Type_Info,
                                       baseSSAId: SSAId,
                                       indices: *[..] SSAId,
                                       baseArrayElementTypeIfImageHeap: *Type_Info,
                                       literalIndices: *[..] int,
                                       currentBaseSpirvType: *Type_Info) -> SSAId, spirvType: *Type_Info #expand {
      if (currentBaseSpirvType.type == TYPE_INFO_POINTER_TAG) {
         returnTypeIdentifier := GetPointerTypeIdentifier(jaiReturnType, currentBaseSpirvType.(*TypeInfoPointer).storageClass);
         pointerSSAId := EmitAccessChain(data, b, returnTypeIdentifier, baseSSAId, xx currentBaseSpirvType, indices.*, baseArrayElementTypeIfImageHeap);
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
   Helper :: (data: *CompilationData, b: *BuilderType, cbo: *Code_Binary_Operator, currentFunction: *Code_Procedure_Header, baseArrayElementTypeIfImageHeap: *TypeInfoImage, indices: *[..] SSAId, literalIndices: *[..] int, currentBaseNode: **Code_Node, currentBaseSpirvType: **Type_Info, currentBaseSSAId: *SSAId, lastAccessOperation: **Code_Binary_Operator) {
      leftType := GetNodeType(cbo.left);
      leftType = UnwindVariantsAllTheWay(leftType);

      if cbo.left.kind == {
         case .BINARY_OPERATOR; {
            cboLeft := cast(*Code_Binary_Operator) cbo.left;
            assert(cboLeft.operator_type == #char "." || // member access and pointer access
                   cboLeft.operator_type == .ARRAY_SUBSCRIPT,
               "operator: %", cboLeft.operator_type
            );

            Helper(data, b, cboLeft, currentFunction, baseArrayElementTypeIfImageHeap, indices, literalIndices, currentBaseNode, currentBaseSpirvType, currentBaseSSAId, lastAccessOperation);
         }

         // reached to the base
         case .IDENT; {
            if (leftType.type == .TYPE) {
               // named module
               currentBaseNode.* = cbo.right;
            } else {
               currentBaseNode.* = cbo.left;
            }

            if currentBaseNode.*.kind == {
               case .IDENT; {
                  baseType := GetNodeType(currentBaseNode.*);
                  ciBase := cast(*Code_Ident) currentBaseNode.*;
                  baseIdentifier := GetVariableIdentifier(ciBase);
                  currentBaseSSAId.* = GetSSAId(data, baseIdentifier);

                  baseSpirvType := New(TypeInfoPointer);
                  baseSpirvType.storageClass = GetVariableStorageClass(data, baseIdentifier);
                  baseSpirvType.pointerTo = baseType;
                  currentBaseSpirvType.* = baseSpirvType;
               }

               case .PROCEDURE_CALL; {
                  DoProcedureCallBase(xx currentBaseNode.*);
               }

               case; assert(false);
            }
         }

         // reached to the base
         case .PROCEDURE_CALL; {
            currentBaseNode.* = cbo.left;
            DoProcedureCallBase(xx currentBaseNode.*);
         }

         case; assert(false, "type: %", leftType.*);
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
               assert(baseArrayElementTypeIfImageHeap == null, "at this point it cant be image heap because we have a pointer in the chain but image heap must be the base of the chain, so pointers can not occur.");

               _pointerSpirvType: *Type_Info;
               pointerSSAId, _pointerSpirvType = DoAccessChainOrCompositeExtract(data, b, leftType, currentBaseSSAId.*, indices, baseArrayElementTypeIfImageHeap, literalIndices, currentBaseSpirvType.*);

               assert(_pointerSpirvType.type == TYPE_INFO_POINTER_TAG);
               pointerSpirvType = xx _pointerSpirvType;
            } else {
               pointerSSAId = currentBaseSSAId.*;

               assert(currentBaseSpirvType.*.type == TYPE_INFO_POINTER_TAG);
               pointerSpirvType = xx currentBaseSpirvType.*;
            }

            loadFromSpirvType: *TypeInfoPointer;
            loadFromSpirvType = pointerSpirvType;

            loadFromSSAId: SSAId;
            if cbo.operator_type == {
               case #char "."; {
                  loadFromSSAId = pointerSSAId;
               }

               case .ARRAY_SUBSCRIPT; {
                  // since i set spirvShouldHaveBeenType it is now guranteed that the returned ssa id will be casted to that type no matter what.
                  indexSSAId := GenerateInstructions(data, cbo.right, null, b, currentFunction, .{ spirvShouldHaveBeenType = cast(*Type_Info) u64 });
                  u64TypeSSAId := GetSSAId(data, .{ type = ._Type, _type = cast(*Type_Info) u64 });

                  pointerAsU64SSAId := GetNextSSAId(data);
                  WriteSingleInstructionIfReachable(
                     b,
                     *data.isBlockReachable,
                     .ConvertPtrToU,
                     u64TypeSSAId,
                     pointerAsU64SSAId,
                     pointerSSAId
                  );

                  loadFromAsU64SSAId := GetNextSSAId(data);
                  WriteSingleInstructionIfReachable(
                     b,
                     *data.isBlockReachable,
                     .IAdd,
                     u64TypeSSAId,
                     loadFromAsU64SSAId,
                     pointerAsU64SSAId,
                     indexSSAId
                  );

                  loadFromSSAId = GetNextSSAId(data);
                  WriteSingleInstructionIfReachable(
                     b,
                     *data.isBlockReachable,
                     .ConvertUToPtr,
                     GetSSAId(data, .{ type = ._Type, _type = loadFromSpirvType }),
                     loadFromSSAId,
                     loadFromAsU64SSAId
                  );
               }

               case; assert(false);
            }

            loadedTypeIdentifier: Identifier = .{ type = ._Type, _type = loadFromSpirvType.pointerTo };
            currentBaseSSAId.* = Load(data, b, loadedTypeIdentifier, loadFromSSAId, loadFromSpirvType.storageClass == .PhysicalStorageBuffer);
            currentBaseNode.* = cbo;
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

   indices: [..] SSAId;
   literalIndices: [..] int;
   currentBaseNode: *Code_Node;
   currentBaseSpirvType: *Type_Info;
   currentBaseSSAId: SSAId;
   lastAccessOperation: *Code_Binary_Operator;
   Helper(data, b, cbo, currentFunction, baseArrayElementTypeIfImageHeap, *indices, *literalIndices, *currentBaseNode, *currentBaseSpirvType, *currentBaseSSAId, *lastAccessOperation);
   assert(currentBaseNode != null);
   assert(currentBaseSpirvType != null);
   assert(currentBaseSSAId != 0);
   assert(lastAccessOperation != null);

   lastAccessOperationJaiType := GetNodeType(lastAccessOperation);

   // so if baseNode.kind is PROCEDURE_CALL then it will trigger the else below. not proper way to do but whatever   - apila, 06/06/26

   // if the current base is not a Code_Binary_Operator then it is the true base of the access chain.
   // true base could be a function call or an ident.
   trueBaseName: string;
   if (currentBaseNode.kind == .IDENT) {
      ciBase := cast(*Code_Ident) currentBaseNode;
      baseIdentifier := GetVariableIdentifier(ciBase);
      trueBaseName = GetVariableName(baseIdentifier);
   }

   jaiReturnType: *Type_Info;
   baseVariableData: DoDotsAndArraySubscriptsBaseVariableData;
   if trueBaseName == {
      case IMAGE_HEAP_VARIABLE_NAME; {
         // i am cheating here to get around untyped pointers.
         // there is no proper handling of untyped variables (i dont store which variables are untyped which are not)
         //    - apila, 06/06/26
         jaiReturnType = cast(*Type_Info) void;
         baseVariableData = .ImageHeapVariable;
      }

      case SAMPLER_HEAP_VARIABLE_NAME; {
         jaiReturnType = cast(*Type_Info) void;
         baseVariableData = .SamplerHeapVariable;
      }

      case; {
         jaiReturnType = lastAccessOperationJaiType;
         baseVariableData = .Another;
      }
   }

   // left overs
   lastAccessChainResultSpirvType: *Type_Info;
   lastAccessChainResultSSAId: SSAId;
   if (indices.count > 0 || literalIndices.count > 0) {
      // indexes were left over. last operation cant be pointer indexing
      leftType := GetNodeType(lastAccessOperation.left);
      assert(!(lastAccessOperation.operator_type == .ARRAY_SUBSCRIPT && leftType.type == TYPE_INFO_POINTER_TAG));

      lastAccessChainResultSSAId, lastAccessChainResultSpirvType = DoAccessChainOrCompositeExtract(data, b, jaiReturnType, currentBaseSSAId, *indices, baseArrayElementTypeIfImageHeap, *literalIndices, currentBaseSpirvType);
   } else {
      // no indices were left over. meaning that the last operation was a pointer indexing
      // ...p[index]
      leftType := GetNodeType(lastAccessOperation.left);
      assert(lastAccessOperation.operator_type == .ARRAY_SUBSCRIPT, "loc: %", GetLocationString(lastAccessOperation));
      assert(leftType.type == TYPE_INFO_POINTER_TAG);

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

   loadedTypeIdentifier: Identifier;
   if #complete baseVariableData == {
      case .ImageHeapVariable;
         assert(baseArrayElementTypeIfImageHeap != null, "loc: %", cbo.location);
         loadedTypeIdentifier = .{ type = ._Type, _type = baseArrayElementTypeIfImageHeap };
      case .SamplerHeapVariable;
         loadedTypeIdentifier = .{ type = ._Type, _type = cast(*Type_Info) __Sampler__ };
      case .Another;
         loadedTypeIdentifier = .{ type = ._Type, _type = tip.pointerTo };
   }

   dereferencedSSAId := Load(data, b, loadedTypeIdentifier, lastAccessChainResultSSAId, tip.storageClass == .PhysicalStorageBuffer);

   if (spirvType != null) spirvType.* = loadedTypeIdentifier._type;
   return dereferencedSSAId;
}

DoDotsAndArraySubscriptsBaseVariableData :: enum {
   ImageHeapVariable;
   SamplerHeapVariable;
   Another;
}

//
// i want to make it so that the pointer deferences work.
// OpAccessChain is for member accesses.
// so (in c style) an expression like this:
//
//    a.b->c
//    (*a.b).c
//
// so this expression is equal to two access chains. and notice that the base of the second access chain doesnt have an identifier
// but it is the result of an OpLoad operation.
// so i think how im gonna implement this is that i will have a function that just creates the access chain until it reaches the end or a deference operation
// this function should be able to work with its base being an ssa id.
//

// tree of a.b.c is:
//          .
//        /   \
//       .     c
//     /   \
//    a     b
//
// code := #code a.b.c;
// root := compiler_get_nodes(code);
// root.(*Code_Binary_Operator).left.(*Code_Binary_Operator).right.(*Code_Ident).name // is "b"
// DoDotsAndArraySubscripts :: (data: *CompilationData, b: *BuilderType, cbo: *Code_Binary_Operator, currentFunction: *Code_Procedure_Header, baseArrayElementTypeIfImageHeap: *TypeInfoImage, isLValue: bool, lValueOut: *SSAId, spirvType: **Type_Info = null, lValueOutSpirvType: **Type_Info = null) -> SSAId {
//    DoMemberAccess :: (tis: *Type_Info_Struct, right: *Code_Node, indices: *[..] SSAId, literalIndices: *[..] int, isSpirvPointer: bool) #expand {
//       assert(right.kind == .IDENT, "if you are accessing a struct indexer it is not yet implemented! right.kind: %, struct name: %, loc: %", right.kind, tis.name, right.location);
//       ci := cast(*Code_Ident) right;

//       memberIndex := GetMemberIndex(tis, ci.name);
//       assert(memberIndex != MEMBER_DOESNT_EXIST, "not a member of struct! struct: %, member: %", tis.name, ci.name);

//       if (isSpirvPointer) {
//          memberIndexIdentifier: Identifier = .{ type = .IntLiteral, intLiteral = .{ unsigned = false, value._s64 = memberIndex, bitSize = 32 } };
//          memberIndexSSAId := GetSSAId(data, memberIndexIdentifier);
//          array_add(indices, memberIndexSSAId);
//       } else {
//          array_add(literalIndices, memberIndex);
//       }
//    }

//    DoAccessChainOrCompositeExtract :: (data: *CompilationData,
//                                        b: *BuilderType,
//                                        returnTypeIdentifier: Identifier,
//                                        baseSSAId: SSAId,
//                                        jaiBaseType: *Type_Info,
//                                        indices: *[..] SSAId,
//                                        baseArrayElementTypeIfImageHeap: *Type_Info,
//                                        literalIndices: *[..] int,
//                                        isSpirvPointer: bool) -> SSAId #expand {
//       if (isSpirvPointer) {
//          pointerSSAId := EmitAccessChain(data, b, returnTypeIdentifier, baseSSAId, jaiBaseType, indices.*, baseArrayElementTypeIfImageHeap);
//          array_reset(indices);
//          return pointerSSAId;
//       } else {
//          resultSSAId := EmitCompositeExtract(data, b, returnTypeIdentifier, baseSSAId, literalIndices.*);
//          array_reset(literalIndices);
//          return resultSSAId;
//       }
//    }

//    accesses := FlattenAccessTree(cbo);
//    baseNode := GetBaseNodeInAccessChain(accesses);

//    found, baseNodeType := table_find(*data.codeNodeTypes, baseNode);
//    assert(found);

//    isCurrentBaseSpirvPointer: bool;
//    if baseNode.kind == {
//       case .IDENT;
//          isCurrentBaseSpirvPointer = true;

//       case .PROCEDURE_CALL;
//          isCurrentBaseSpirvPointer = baseNodeType.type == TYPE_INFO_POINTER_TAG;

//       case; assert(false);
//    }

//    baseIdentifier: Identifier;
//    currentBaseSSAId: SSAId;
//    currentStorageClass: SpvStorageClass;
//    if baseNode.kind == {
//       case .IDENT; {
//          baseCi := cast(*Code_Ident) baseNode;
//          baseIdentifier = GetVariableIdentifier(baseCi);
//          currentBaseSSAId = GetSSAId(data, baseIdentifier);
//          currentStorageClass = GetVariableStorageClass(data, baseIdentifier);
//       }

//       case .PROCEDURE_CALL; {
//          baseCpc := cast(*Code_Procedure_Call) baseNode;
//          currentBaseSSAId = GenerateInstructions(data, baseCpc, null, b, currentFunction);

//          if (baseNodeType.type == TYPE_INFO_POINTER_TAG) {
//             tip := cast(*TypeInfoPointer) baseNodeType;
//             currentStorageClass = tip.storageClass;
//          } else {
//             // doing this so that i can catch bugs if i am using the storage class when im not supposed to
//             currentStorageClass = .Max;
//          }
//       }

//       case; assert(false);
//    }

//    indices: [..] SSAId; // this is for OpAccessChain
//    literalIndices: [..] int; // this is for OpCompositeExtract
//    currentBaseType := baseNodeType;

//    for accesses {
//       found, leftType := table_find(*data.codeNodeTypes, it.left);
//       assert(found);

//       // now matrices are variant. so i think maybe i need to unwind them all the way here.
//       //       - apila, 25/05/26
//       leftType = UnwindVariantsAllTheWay(leftType);

//       if leftType.type == {
//          case .STRUCT;
//             tis := cast(*Type_Info_Struct) leftType;
//             DoMemberAccess(tis, it.right, *indices, *literalIndices, isCurrentBaseSpirvPointer);

//          case .ARRAY;
//             // actually it is fine if it is not a pointer but the array index must be integer constant.
//             // assume f() returns a struct { xs: [6] f32; };
//             //    f().xs[4]   // is valid
//             //    a := 4; f().xs[a]; // is not valid
//             //
//             // but who the fuck writes code like this on gpu. noone. so im just gonna skip and say, it must be a pointer. i think i dont lose much.
//             //       - apila, 20/05/26
//             // assert(isCurrentBaseSpirvPointer, "not yet implemneted! loc: %", cbo.location);

//             // in case it is a literal then it should be 32 bit signed i think (thats what glslangValidator generates)
//             // it doesnt need to be 32bit, 64bit also valid but why waste two words for this if one word is enough.

//             ssaId, _ := GenerateInstructions(data, it.right, null, b, currentFunction, .{ literalShouldHaveBeenType = cast(*Type_Info) s32 });

//             if (!isCurrentBaseSpirvPointer) {
//                assert(it.right.kind == .LITERAL);
//             }

//             array_add(*indices, ssaId);

//          case TYPE_INFO_POINTER_TAG;
//             tip := cast(*TypeInfoPointer) leftType;

//             pointerSSAId: SSAId;

//             if (indices.count > 0) {
//                assert(baseArrayElementTypeIfImageHeap == null, "at this point it cant be image heap because we have a pointer in the chain but image heap must be the base of the chain, so pointers can not occur.");

//                returnTypeIdentifier := GetPointerTypeIdentifier(leftType, tip.storageClass);
//                pointerSSAId = DoAccessChainOrCompositeExtract(data, b, returnTypeIdentifier, currentBaseSSAId, currentBaseType, *indices, baseArrayElementTypeIfImageHeap, *literalIndices, isCurrentBaseSpirvPointer);
//             } else {
//                pointerSSAId = currentBaseSSAId;
//             }

//             loadFromSSAId: SSAId;
//             if it.operator_type == {
//                case #char "."; {
//                   loadFromSSAId = pointerSSAId;
//                }

//                case .ARRAY_SUBSCRIPT; {
//                   // not sure about this assertion.   - apila, 14/05/26
//                   assert(tip.storageClass == .PhysicalStorageBuffer);

//                   right := it.right;
//                   uncastedIndexSSAId := GenerateInstructions(data, right, null, b, currentFunction, .{ literalShouldHaveBeenType = cast(*Type_Info) u64 });

//                   // index need to be casted to u64 before doing the OpIAdd.
//                   indexSSAId := uncastedIndexSSAId;
//                   if (right.kind != .LITERAL) {
//                      found, indexType := table_find(*data.codeNodeTypes, right);
//                      assert(found);

//                      if (!CompareType(indexType, cast(*Type_Info) u64)) {
//                         indexSSAId = DoCast(data, b, cast(*Type_Info) u64, indexType, uncastedIndexSSAId);
//                      }
//                   }

//                   u64TypeSSAId := GetSSAId(data, .{ type = ._Type, _type = cast(*Type_Info) u64 });

//                   pointerAsU64SSAId := GetNextSSAId(data);
//                   WriteSingleInstructionIfReachable(
//                      b,
//                      *data.isBlockReachable,
//                      .ConvertPtrToU,
//                      u64TypeSSAId,
//                      pointerAsU64SSAId,
//                      pointerSSAId
//                   );

//                   loadFromAsU64SSAId := GetNextSSAId(data);
//                   WriteSingleInstructionIfReachable(
//                      b,
//                      *data.isBlockReachable,
//                      .IAdd,
//                      u64TypeSSAId,
//                      loadFromAsU64SSAId,
//                      pointerAsU64SSAId,
//                      indexSSAId
//                   );

//                   pointerSpirvType := New(TypeInfoPointer);
//                   pointerSpirvType.pointerTo = tip;
//                   pointerSpirvType.storageClass = .PhysicalStorageBuffer;
//                   loadFromSSAId = GetNextSSAId(data);
//                   WriteSingleInstructionIfReachable(
//                      b,
//                      *data.isBlockReachable,
//                      .ConvertUToPtr,
//                      GetSSAId(data, .{ type = ._Type, _type = pointerSpirvType }),
//                      loadFromSSAId,
//                      loadFromAsU64SSAId
//                   );
//                }

//                case; assert(false);
//             }

//             loadedTypeIdentifier: Identifier = .{ type = ._Type, _type = tip };
//             currentBaseSSAId = Load(data, b, loadedTypeIdentifier, loadFromSSAId, currentStorageClass == .PhysicalStorageBuffer);
//             currentBaseType = tip.pointerTo;
//             isCurrentBaseSpirvPointer = true; // not sure about this

//             // must be set after the Load above i think. idk
//             currentStorageClass = tip.storageClass;

//             if it.operator_type == {
//                case #char "."; {
//                   assert(tip.pointerTo.type == .STRUCT, "type: %", tip.pointerTo.type);
//                   tis := cast(*Type_Info_Struct) tip.pointerTo;
//                   DoMemberAccess(tis, it.right, *indices, *literalIndices, isCurrentBaseSpirvPointer);
//                }

//                case .ARRAY_SUBSCRIPT; {
//                   // :)
//                }

//                case; assert(false);
//             }

//          // named module
//          case .TYPE;
//             // just skip. i could have started the for loop from baseNodeCboIndex
//             continue;

//          case; assert(false, "type: %", leftType.type);
//       }
//    }

//    lastAccessOperation := accesses[accesses.count - 1];
//    found2, accessChainType := table_find(*data.codeNodeTypes, lastAccessOperation);
//    assert(found2);

//    // so if baseNode.kind is PROCEDURE_CALL then it will trigger the else below. not proper way to do but whatever   - apila, 19/05/26
//    baseName: string;
//    if (baseNode.kind == .IDENT) {
//       baseName = GetVariableName(baseIdentifier);
//    }

//    returnTypeIdentifier: Identifier;
//    baseVariableData: DoDotsAndArraySubscriptsBaseVariableData;
//    if (baseName == IMAGE_HEAP_VARIABLE_NAME) {
//       returnTypeIdentifier = GetPointerTypeIdentifier(cast(*Type_Info) void, currentStorageClass);
//       baseVariableData = .ImageHeapVariable;
//    } else if (baseName == SAMPLER_HEAP_VARIABLE_NAME) {
//       returnTypeIdentifier = GetPointerTypeIdentifier(cast(*Type_Info) void, currentStorageClass);
//       baseVariableData = .SamplerHeapVariable;
//    } else {
//       returnTypeIdentifier = GetPointerTypeIdentifier(accessChainType, currentStorageClass);
//       baseVariableData = .Another;
//    }

//    accessChainResultSSAId: SSAId;
//    if (indices.count > 0 || literalIndices.count > 0) {
//       // indexes were left over. last operation cant be pointer indexing
//       found, leftType := table_find(*data.codeNodeTypes, lastAccessOperation.left);
//       assert(found);
//       assert(!(lastAccessOperation.operator_type == .ARRAY_SUBSCRIPT && leftType.type == TYPE_INFO_POINTER_TAG));

//       accessChainResultSSAId = DoAccessChainOrCompositeExtract(data, b, returnTypeIdentifier, currentBaseSSAId, currentBaseType, *indices, baseArrayElementTypeIfImageHeap, *literalIndices, isCurrentBaseSpirvPointer);
//    } else {
//       // no indices were left over. meaning that the last operation was a pointer indexing
//       // ...p[index]
//       found, leftType := table_find(*data.codeNodeTypes, lastAccessOperation.left);
//       assert(found);
//       assert(lastAccessOperation.operator_type == .ARRAY_SUBSCRIPT, "loc: %", lastAccessOperation.location);
//       assert(leftType.type == TYPE_INFO_POINTER_TAG);

//       accessChainResultSSAId = currentBaseSSAId;
//    }

//    if (isLValue) {
//       assert(isCurrentBaseSpirvPointer);

//       if (spirvType != null) spirvType.* = returnTypeIdentifier._type;
//       return accessChainResultSSAId/* , returnTypeIdentifier, baseVariableData */;
//    }

//    if (lValueOutSpirvType != null) lValueOutSpirvType.* = returnTypeIdentifier._type;
//    if (lValueOut != null) lValueOut.* = accessChainResultSSAId;

//    if (returnTypeIdentifier._type.type == TYPE_INFO_POINTER_TAG) {
//       tip := cast(*TypeInfoPointer) returnTypeIdentifier._type;

//       loadedTypeIdentifier: Identifier;
//       if baseVariableData == {
//          case .ImageHeapVariable;
//             assert(baseArrayElementTypeIfImageHeap != null, "loc: %", cbo.location);
//             loadedTypeIdentifier = .{ type = ._Type, _type = baseArrayElementTypeIfImageHeap };
//          case .SamplerHeapVariable;
//             loadedTypeIdentifier = .{ type = ._Type, _type = cast(*Type_Info) __Sampler__ };
//          case .Another;
//             loadedTypeIdentifier = .{ type = ._Type, _type = tip.pointerTo };
//       }

//       dereferencedSSAId := Load(data, b, loadedTypeIdentifier, accessChainResultSSAId, tip.storageClass == .PhysicalStorageBuffer);

//       if (spirvType != null) spirvType.* = loadedTypeIdentifier._type;
//       return dereferencedSSAId;
//    } else {
//       if (spirvType != null) spirvType.* = returnTypeIdentifier._type;
//       return accessChainResultSSAId; // then this is a composite extract
//    }
// }

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

// storageClass: storage class of the pointer returned by OpAccessChain
// returnType: the type of the access chain in jai, not the one returned by OpAccessChain. (there is a single pointer difference)
// returns: the ssa id returned by OpAccessChain
EmitAccessChain :: (data: *CompilationData, b: *BuilderType, returnTypeIdentifier: Identifier, baseSSAId: SSAId, spirvBaseType: *TypeInfoPointer, indices: [] SSAId, baseArrayElementTypeIfImageHeap: *Type_Info) -> SSAId {
   assert(spirvBaseType.type == TYPE_INFO_POINTER_TAG);

   lValueSSAId := GetNextSSAId(data);

   op: SpvOp;
   operands: [..] Any;

   //
   // i dont store if a variable is untyped or not. and there are many restrictions to untyped variables.
   // so i think im gonna keep it to minimal and say that only the types that cant be OpVariable gonna be
   // OpUntypedVariable. dont forget OpTypeUntypedPointerKHR is something else and dont require OpUntypedVariable
   //    - apila, 26/04/26
   //
   // only sampler heap variable and image heap variable are untyped. and i can determine it from the given types.
   // kinda hacky way to determine it but voila.
   //    - apila, 02/05/26
   //
   if (CompareType(spirvBaseType.pointerTo, cast(*Type_Info) type_of(images))) {
      assert(spirvBaseType.pointerTo.type != TYPE_INFO_POINTER_TAG); // required by specs
      assert(baseArrayElementTypeIfImageHeap != null);

      tira := New(TypeInfoRuntimeArray);
      tira.elementType = baseArrayElementTypeIfImageHeap;
      baseTypeIdentifier: Identifier = .{ type = ._Type, _type = tira };

      op = .UntypedAccessChainKHR;
      array_add(*operands, GetSSAId(data, returnTypeIdentifier));
      array_add(*operands, lValueSSAId);
      array_add(*operands, GetSSAId(data, baseTypeIdentifier));
      array_add(*operands, baseSSAId);
   } else if (CompareType(spirvBaseType.pointerTo, cast(*Type_Info) type_of(samplers))) {
      assert(spirvBaseType.pointerTo.type != TYPE_INFO_POINTER_TAG); // required by specs

      assert(spirvBaseType.pointerTo.type == .ARRAY);
      tia := cast(*Type_Info_Array) spirvBaseType.pointerTo;

      tira := New(TypeInfoRuntimeArray);
      tira.elementType = tia.element_type;
      baseTypeIdentifier: Identifier = .{ type = ._Type, _type = tira };

      op = .UntypedAccessChainKHR;
      array_add(*operands, GetSSAId(data, returnTypeIdentifier));
      array_add(*operands, lValueSSAId);
      array_add(*operands, GetSSAId(data, baseTypeIdentifier));
      array_add(*operands, baseSSAId);
   } else {
      op = .AccessChain;
      array_add(*operands, GetSSAId(data, returnTypeIdentifier));
      array_add(*operands, lValueSSAId);
      array_add(*operands, baseSSAId);
   }

   for indices {
      array_add(*operands, ac(it));
   }

   WriteSingleInstructionIfReachable(b, *data.isBlockReachable, op, .. operands);
   return lValueSSAId;
}

ArrayReverse :: (array: [] $T) {
   if (array.count <= 1) return;

   for 0..array.count / 2 - 1 {
      indexFromStart := it;
      indexFromEnd := array.count - 1 - indexFromStart;

      swap(*array[indexFromStart], *array[indexFromEnd]);
   }
}

MEMBER_DOESNT_EXIST :: -1;
GetMemberIndex :: (tis: *Type_Info_Struct, memberName: string) -> int {
   for tis.members {
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
      case; assert(false, "type: %", type); return 0;
   }
}

GetIntegerOpFromOperatorType :: (type: Operator_Type) -> SpvOp {
   if type == {
      case #char "+"; return .IAdd;
      case #char "-"; return .ISub;
      case #char "*"; return .IMul;
      case; assert(false, "type: %", type); return 0;
   }
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

   memberInfos := NewArray(tis.members.count, StructAnnotateMemberInfo);

   for tis.members {
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
   assert(tip.return_types.count <= 1);

   // i need to get rid of .Void and use ._Type and void builtin
   if (tip.return_types.count == 0) {
      return .{ type = .Void };
   }

   // returns count must be one here as asserted above (combined with if case)
   returnType := tip.return_types[0];
   assert(returnType.type != .POINTER, "not implemented yet!");

   return .{ type = ._Type, _type = returnType };
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
