#import "Basic";
#import "Compiler";
#import "Math";
#import "String";
#import "Hash_Table";

MeshOutVertex :: struct {
   position: Vector3;
   color: Vector4;
}
MeshOutPrimitive :: struct { }
Intrinsics :: struct {
   // builtin types
   using types: struct {
      Int32    :: struct {};
      Int32x2  :: struct {};
      Int32x3  :: struct {};
      Int32x4  :: struct {};

      Float    :: struct {};
      Float2   :: struct {};
      Float3   :: struct {};
      Float4   :: struct {};

      Float2x2 :: struct {};
      Float3x3 :: struct {};
      Float4x4 :: struct {};
   };
}
FragmentData :: struct { }
MeshData :: struct { }

MeshShader :: (using intrinsics: Intrinsics, mOutVertex: *[] MeshOutVertex, mOutPrimitive: *[] MeshOutPrimitive, data: *MeshData) {

} @1_1_1 @40_20 @triangles

FragmentShader :: (using intrinsics: Intrinsics, mOutVertex: MeshOutVertex, mOutPrimitive: MeshOutPrimitive, data: *FragmentData) -> Intrinsics.Float4 {
   anan123: int = 10;
   return .{};
}

main :: () {
}

#run {
   CompileToSpirv(code_of(MeshShader), .Mesh);
}

ShaderType :: enum {
   Task;
   Mesh;
   Fragment;
   Compute;
}

CompilationData :: struct {
   workgroupSize:       [3] int = .[1, 1, 1];
   intConstants:        Table(int, struct {});
   maxVertices:         int;
   maxPrimitives:       int;
   primitiveTopology:   string;
   identifierToSSAId:   Table(string, int);
   ssaIota:             int;
   structs:             Table(Type, struct {}, HashType);

   HashType :: (t: Type) -> u32 {
      #import "Hash";
      return cast,trunc(u32) fnv1a_hash(xx *t, size_of(Type));
   }
}

// not correct since MeshOutVertex and MeshOutPrimitive are user defined and different for each shader procedure
MeshShaderType :: #type (using intrinsics: Intrinsics, mOutVertex: *[] MeshOutVertex, mOutPrimitive: *[] MeshOutPrimitive, data: *MeshData) -> ();

// local size is provided via notes like so: @x_y_z
// if you omit y and/or z (or even x) they default to 1
//
// the function must be provided using code_of otherwise jai doesnt compile the body of the function
// and body_or_null is always null even if i wait in a loop until it is not null anymore
CompileToSpirv :: (function: Code, type: ShaderType) -> [] u8 #compile_time {
   root, _ := compiler_get_nodes(function);
   header := cast(*Code_Procedure_Header) root;
   body := header.body_or_null;
   assert(body != null, "body_or_null is null! idk how to solve this, maybe loop until it is not null anymore. if you passed the function directly that wont work. pass using code_of");
   block := body.block;
   functionName := header.name;

   data: CompilationData;

   // arguments
   if type == {
      case .Mesh; {
         // first argument: Intrinsics
         {
            assert(header.arguments.count > 0, "not enough arguments");
            assert(header.arguments[0].type.type == .STRUCT, "first argument must be of type Intrinsics");
            assert(header.arguments[0].type.(*Type_Info_Struct).name == "Intrinsics", "first argument must be of type Intrinsics");
         }

         // second argument: *[] MeshOutVertex. MeshOutVertex is user defined struct
         {
            assert(header.arguments.count > 1, "not enough arguments");
            assert(header.arguments[1].type.type == .POINTER, "second argument wrong");
            pointer := cast(*Type_Info_Pointer) header.arguments[1].type;
            assert(pointer.pointer_to.type == .ARRAY, "second argument wrong");
            array := cast(*Type_Info_Array) pointer.pointer_to;

            userStruct := get_type(array.element_type);
            find_or_add(*data.structs, userStruct);
         }

         // third argument: mOutPrimitive: *[] MeshOutPrimitive. MeshOutPrimitive is user defined struct
         {
            assert(header.arguments.count > 2, "not enough arguments");
            assert(header.arguments[2].type.type == .POINTER, "third argument wrong");
            pointer := cast(*Type_Info_Pointer) header.arguments[2].type;
            assert(pointer.pointer_to.type == .ARRAY, "third argument wrong");
            array := cast(*Type_Info_Array) pointer.pointer_to;

            userStruct := get_type(array.element_type);
            find_or_add(*data.structs, userStruct);
         }

         // fourth argument: *MeshData. MeshData is user defined struct
         {
            assert(header.arguments.count > 3, "not enoufh arguments");
            assert(header.arguments[3].type.type == .POINTER, "fourth argument wrong");
            pointer := cast(*Type_Info_Pointer) header.arguments[3].type;

            userStruct := get_type(pointer.pointer_to);
            find_or_add(*data.structs, userStruct);
         }
      }

      case; assert(false, "not implemented yet");
   }

   // returns
   if type == {
      case .Mesh; assert(header.returns.count == 0, "mesh shader must return nothing");
   }

   // notes
   if (type == .Mesh) {
      assert(header.notes.count == 3, "[0] = x_y_z workgroup size, [1] = a_b max vertices and max primitives, [2] = [points, lines, triangles] primitive topology");

      // [0]
      {
         dimensions := split(header.notes[0].text, "_");
         assert(dimensions.count <= 3, "dimensions: %, max count is three", dimensions);

         for dimensions {
            value, ok := string_to_int(it);
            assert(ok, "it: %, couldnt be parsed to int!", it);

            data.workgroupSize[it_index] = value;
            find_or_add(*data.intConstants, value);
         }
      }

      // [1]
      {
         maxVerticesAndPrimitivesNote := header.notes[1];
         maxVerticesAndPrimitives := split(maxVerticesAndPrimitivesNote.text, "_");
         assert(maxVerticesAndPrimitives.count == 2, "maxVerticesAndPrimitives: %", maxVerticesAndPrimitives);

         ok: bool;
         data.maxVertices, ok = string_to_int(maxVerticesAndPrimitives[0]);
         assert(ok, "maxVerticesAndPrimitives[0]: %", maxVerticesAndPrimitives[0]);

         data.maxPrimitives, ok = string_to_int(maxVerticesAndPrimitives[1]);
         assert(ok, "maxVerticesAndPrimitives[1]: %", maxVerticesAndPrimitives[1]);
      }

      // [2]
      {
         primitiveTopology := header.notes[2].text;
         PRIMITIVE_TOPOLOGIES := string.["points", "lines", "triangles"];
         found := array_find(PRIMITIVE_TOPOLOGIES, primitiveTopology);
         assert(found, "primitiveTopology: %, valid values: %", primitiveTopology, PRIMITIVE_TOPOLOGIES);

         data.primitiveTopology = primitiveTopology;
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
   for block.statements {
      if it.kind == {
         case .UNINITIALIZED               ; #through;
         case .CONTEXT                     ; #through;
         case .DIRECTIVE_BYTES             ; #through;
         case .ASM                         ; #through;
         case .DIRECTIVE_BAKE              ; #through;
         case .DIRECTIVE_LIBRARY           ; #through;
         case .DIRECTIVE_MODIFY            ; #through;
         case .EXPRESSION_QUERY            ; #through;
         case .PUSH_CONTEXT                ; #through;
         case .DIRECTIVE_PLACE             ; #through;
         case .DIRECTIVE_LOCATION          ; #through;
         case .DIRECTIVE_MODULE_PARAMETERS ; #through;
         case .DIRECTIVE_SCOPE             ; #through;
         case .DIRECTIVE_ADD_CONTEXT       ; #through;
         case .DIRECTIVE_CONTEXT_TYPE      ;
            assert(false, "code node kind: %. not valid.", it.kind);

         case .LOOP_CONTROL                ; #through;
         case .PROCEDURE_HEADER            ; #through;
         case .EXTRACT                     ; #through;
         case .MAKE_VARARGS                ; #through;
         case .DIRECTIVE_THIS              ; #through;
         case .DIRECTIVE_LOAD              ; #through;
         case .DIRECTIVE_CODE              ; #through;
         case .NOTE                        ; #through;
         case .DIRECTIVE_COMPILE_TIME      ; #through;
         case .PLACEHOLDER                 ; #through;
         case .DIRECTIVE_WILDCARD          ; #through;
         case .RESOLVED_OVERLOAD           ;
            assert(false, "code node kind: %. idk what to do with this", it.kind);

         case .DIRECTIVE_RUN               ;
            assert(false, "do the #run outside the shader procedure to let jai compiler #run it. this compiler doesnt have #run");

         case .DIRECTIVE_POKE_NAME         ;
            assert(false, "idk what this directive is");

         case .DIRECTIVE_IMPORT            ;
            continue; // i think i should skip? idk maybe

         case .TYPE_QUERY                  ;
            // size_of, type_info
            assert(false, "read the comment above. i need a way to get the value somehow not the code nodes");

         case .DEFER                       ;
            assert(false, "idk how to implement");

         case .USING                       ;
            // should i ignore?
            continue;

         case .DIRECTIVE_INSERT            ;
            assert(false, "read the comment above");

         case .DIRECTIVE_PROCEDURE_NAME    ;
            assert(false, "read the comment above");

         case .DIRECTIVE_EXISTS            ;
            assert(false, "read the comment above");

         case .DIRECTIVE_OVERLAY           ;
            assert(false, "i guess i should never see this. the parsing of structs is done through Type_Info, not through code nodes");

         case .BLOCK                       ;
         
         case .LITERAL                     ;
         case .IDENT                       ;
         case .UNARY_OPERATOR              ;
         case .BINARY_OPERATOR             ;
         case .PROCEDURE_BODY              ;
         case .PROCEDURE_CALL              ;
         case .WHILE                       ;
         case .IF                          ;
         case .CASE                        ;
         case .RETURN                      ;
         case .FOR                         ;
         case .TYPE_DEFINITION             ;
         case .TYPE_INSTANTIATION          ;
         case .ENUM                        ;
         case .STRUCT                      ;
         case .COMMA_SEPARATED_ARGUMENTS   ;
         case .DECLARATION                 ;
         case .CAST                        ;
         case .DIRECTIVE_THROUGH           ;
         case .COMPOUND_DECLARATION        ;

      }
   }



   b: String_Builder;
   if type == {
      case .Mesh; {
         // first part
         print_to_builder(*b, "OpCapability MeshShadingEXT\n");
         print_to_builder(*b, "OpCapability UntypedPointersKHR\n");
         print_to_builder(*b, "OpCapability DescriptorHeapEXT\n");
         print_to_builder(*b, "OpCapability PhysicalStorageBufferAddresses\n");
         print_to_builder(*b, "OpExtension \"SPV_EXT_mesh_shader\"\n");
         print_to_builder(*b, "OpExtension \"SPV_EXT_descriptor_heap\"\n");
         print_to_builder(*b, "OpExtension \"SPV_KHR_untyped_pointers\"\n");
         print_to_builder(*b, "\%% = OpExtInstImport \"GLSL.std.450\"\n", GetNextSSAId(*data));
         print_to_builder(*b, "OpMemoryModel PhysicalStorageBuffer64 GLSL450\n");
         print_to_builder(*b, "OpEntryPoint MeshEXT \%% \"%\" \%% \%% \%% \%% \%% \%% \%%\n",
                              GetSSAId(*data, "ApilaMS"),
                              "ApilaMS",
                              GetSSAId(*data, "meshVerticesEXT"),
                              GetSSAId(*data, "pushData"),
                              GetSSAId(*data, "primitiveTriangleIndicesEXT"),
                              GetSSAId(*data, "meshVertexOut"),
                              GetSSAId(*data, "meshPrimitiveOut"),
                              GetSSAId(*data, "imageHeap"),
                              GetSSAId(*data, "samplerHeap")
         );
         print_to_builder(*b, "OpExecutionModeId \%% LocalSizeId \%% \%% \%%\n",
                              GetSSAId(*data, "ApilaMS"),
                              GetSSAId(*data, sprint("int32_%", data.workgroupSize[0])),
                              GetSSAId(*data, sprint("int32_%", data.workgroupSize[1])),
                              GetSSAId(*data, sprint("int32_%", data.workgroupSize[2]))
         );
         print_to_builder(*b, "OpExecutionMode \%% OutputVertices %\n",
                              GetSSAId(*data, "ApilaMS"),
                              data.maxVertices
         );
         print_to_builder(*b, "OpExecutionMode \%% OutputPrimitivesEXT %\n",
                              GetSSAId(*data, "ApilaMS"),
                              data.maxPrimitives
         );
         print_to_builder(*b, "OpExecutionMode \%% %\n",
                              GetSSAId(*data, "ApilaMS"),
                              ToSpirvOutputTopology(data.primitiveTopology)
         );



         // skip debug info



         // annotations (decorations)
         print_to_builder(*b, "\n; annotations (decorations)\n");
         print_to_builder(*b, "OpDecorate \%% Block\n",
                              GetSSAId(*data, "MeshPerVertex")
         );
         print_to_builder(*b, "OpMemberDecorate \%% 0 BuiltIn Position\n",
                              GetSSAId(*data, "MeshPerVertex")
         );
         print_to_builder(*b, "OpMemberDecorate \%% 1 BuiltIn PointSize\n",
                              GetSSAId(*data, "MeshPerVertex")
         );

         // i say location 0, and location 1. but idk if this is correct. for example glsl disallows this if meshVertexOut is a struct with more than one member
         // saying that there is an overlap. slang generates a location decoration for each member of the struct seperately.
         // i wrote the spirv assembly then assembled it and it worked. so idk. also spirv-val didnt complain about anything. so im gonn keep this for now
         // but i feel like this is wrong.
         // also in the specs there is no mention of this. it just says it applies to variables or struct members.
         // this overlap thingy happens if you use matrices as well. but there is no documentation for this so idk how to handle it other than reverse engineer and find out which sucks
         print_to_builder(*b, "OpDecorate \%% Location 0\n",
                              GetSSAId(*data, "meshVertexOut")
         );
         print_to_builder(*b, "OpDecorate \%% Location 1\n",
                              GetSSAId(*data, "meshPrimitiveOut")
         );
         print_to_builder(*b, "OpDecorate \%% PerPrimitiveEXT\n",
                              GetSSAId(*data, "meshPrimitiveOut")
         );
         print_to_builder(*b, "OpDecorate \%% Block\n",
                              GetSSAId(*data, "PushData")
         );
         print_to_builder(*b, "OpMemberDecorate \%% 0 Offset 0\n", // task data pointer
                              GetSSAId(*data, "PushData")
         );
         print_to_builder(*b, "OpMemberDecorate \%% 1 Offset 8\n", // mesh data pointer
                              GetSSAId(*data, "PushData")
         );
         print_to_builder(*b, "OpMemberDecorate \%% 2 Offset 16\n", // fragment data pointer
                              GetSSAId(*data, "PushData")
         );
         print_to_builder(*b, "OpDecorate \%% BuiltIn PrimitiveTriangleIndicesEXT\n",
                              GetSSAId(*data, "primitiveTriangleIndicesEXT")
         );

         // struct annotate infos
         print_to_builder(*b, "\n; struct annotate infos\n");
         for _, s: data.structs {
            annotateInfo := GetAnnotateInfoFromStruct(s);
            structIdentifier := GetStructIdentifier(s);
            print_to_builder(*b, "OpDecorate \%% Block\n",
                                 GetSSAId(*data, structIdentifier)
            );

            for annotateInfo.memberInfos {
               print_to_builder(*b, "OpMemberDecorate \%% % Offset %\n",
                                    GetSSAId(*data, structIdentifier),
                                    it.memberIndex,
                                    it.offset
               );
            }
         }




         // Types, variables and constants
         print_to_builder(*b, "\n; Types, variables and constants\n");
         print_to_builder(*b, "\%% = OpTypeVoid\n",
                              GetSSAId(*data, "void")
         );
         print_to_builder(*b, "\%% = OpTypeInt 32\n",
                              GetSSAId(*data, "int32")
         );
         print_to_builder(*b, "\%% = OpTypeVector \%% 2\n",
                              GetSSAId(*data, "int32x2"),
                              GetSSAId(*data, "int32")
         );
         print_to_builder(*b, "\%% = OpTypeVector \%% 3\n",
                              GetSSAId(*data, "int32x3"),
                              GetSSAId(*data, "int32")
         );
         print_to_builder(*b, "\%% = OpTypeVector \%% 4\n",
                              GetSSAId(*data, "int32x4"),
                              GetSSAId(*data, "int32")
         );
         print_to_builder(*b, "\%% = OpTypeFloat 32\n",
                              GetSSAId(*data, "float")
         );
         print_to_builder(*b, "\%% = OpTypeVector \%% 2\n",
                              GetSSAId(*data, "float2"),
                              GetSSAId(*data, "float")
         );
         print_to_builder(*b, "\%% = OpTypeVector \%% 3\n",
                              GetSSAId(*data, "float3"),
                              GetSSAId(*data, "float")
         );
         print_to_builder(*b, "\%% = OpTypeVector \%% 4\n",
                              GetSSAId(*data, "float4"),
                              GetSSAId(*data, "float")
         );
         print_to_builder(*b, "\%% = OpTypeMatrix \%% 2\n",
                              GetSSAId(*data, "float2x2"),
                              GetSSAId(*data, "float2")
         );
         print_to_builder(*b, "\%% = OpTypeMatrix \%% 3\n",
                              GetSSAId(*data, "float3x3"),
                              GetSSAId(*data, "float3")
         );
         print_to_builder(*b, "\%% = OpTypeMatrix \%% 4\n",
                              GetSSAId(*data, "float4x4"),
                              GetSSAId(*data, "float4")
         );

         // int constants
         print_to_builder(*b, "\n; int constants\n");
         for _, constant: data.intConstants {
            print_to_builder(*b, "\%% = OpConstant \%% %\n",
                                 GetSSAId(*data, sprint("int32_%", constant)),
                                 GetSSAId(*data, "int32"),
                                 constant
            );
         }


         // functions
         print_to_builder(*b, "\n; functions\n");

      }
   }

   print("%", builder_to_string(*b));

   return .{};
}

StructAnnotateMemberInfo :: struct {
   memberIndex:   int;
   offset:        int;
}

StructAnnotateInfo :: struct {
   memberInfos: [] StructAnnotateMemberInfo;
}

GetAnnotateInfoFromStruct :: (T: Type) -> StructAnnotateInfo {
   ti := cast(*Type_Info)T;
   if (ti.type != .STRUCT) assert(false, sprint("ti.type: %, type is not struct", ti.type));

   tis := cast(*Type_Info_Struct)T;

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

GetStructIdentifier :: (T: Type) -> string {
   ti := cast(*Type_Info)T;
   if (ti.type != .STRUCT) assert(false, sprint("ti.type: %, type is not struct", ti.type));

   tis := cast(*Type_Info_Struct)T;
   return tis.name;
}

MeshPerVertex :: struct {
   position:   Vector4;
   pointSize:  float;
}

GetNextSSAId :: (using data: *CompilationData) -> int {
   ssaIota += 1;
   return ssaIota;
}

// identifier rules:
//    identifier of a struct is its name
//    for int its "int32" or int followed by the bit size
//    for float it is just "float"
//    int vectors are int32x followed by size. "int32x4" is ivec4 in glsl
//    float vectors are float followed by size. "float4" is vec4 in glsl
//    matrices are float2x2, float3x3.
GetSSAId :: (using data: *CompilationData, identifier: string) -> int {
   value, newlyAdded := find_or_add(*identifierToSSAId, identifier);
   if (!newlyAdded) {
      return value.*;
   }

   value.* = GetNextSSAId(data);
   return value.*;
}

ToSpirvOutputTopology :: (topology: string) -> string {
   #if (false) {
   } else if (topology == "points") {
      return "OutputPoints";
   } else if (topology == "lines") {
      return "OutputLinesEXT";
   } else if (topology == "triangles") {
      return "OutputTrianglesEXT";
   } else {
      assert(false, "invalid topology: %", topology);
      return .{};
   }
}
