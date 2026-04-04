#import "Basic";
#import "Compiler";
#import "Math";
#import "String";
#import "Hash_Table";
#import "Queue";

MeshOutVertex :: struct {
   position: Intrinsics.Float3;
   color: Intrinsics.Float4;
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

// == must be defined on T
ArrayEquals :: (a: [] $T, b: [] T) -> bool {
   if a.count != b.count return false;
   for a {
      if it != b[it_index] return false;
   }

   return true;
}

CompilationData :: struct {
   workgroupSize:                         [3] int = .[1, 1, 1];
   intConstants:                          Table(int, struct {});
   maxVertices:                           int;
   maxPrimitives:                         int;
   primitiveTopology:                     string;
   identifierToSSAId:                     Table(string, int);
   ssaIota:                               int;
   structs:                               Table(Type, struct {}, HashType);
   functions:                             Table(*Code_Procedure_Header, struct {}); // this data is collected when generating instructions and then written into the Types block of spirv
   functionFrontier:                      Queue(*Code_Procedure_Body);
   locationsConsumedByPerVertexMeshOut:   int;


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

   HashType :: (t: Type) -> u32 {
      #import "Hash";
      return cast,trunc(u32) fnv1a_hash(xx *t, size_of(Type));
   }
}

// in depth first order
CalculateLocationsConsumed :: (T: Type) -> int {
   Helper :: (type: Type, accumulator: *int) {
      if type == {
         case Intrinsics.Int32    ; accumulator.* += 1; return;
         case Intrinsics.Int32x2  ; accumulator.* += 1; return;
         case Intrinsics.Int32x3  ; accumulator.* += 1; return;
         case Intrinsics.Int32x4  ; accumulator.* += 1; return;
         case Intrinsics.Float    ; accumulator.* += 1; return;
         case Intrinsics.Float2   ; accumulator.* += 1; return;
         case Intrinsics.Float3   ; accumulator.* += 1; return;
         case Intrinsics.Float4   ; accumulator.* += 1; return;
         case Intrinsics.Float2x2 ; accumulator.* += 2; return;
         case Intrinsics.Float3x3 ; accumulator.* += 3; return;
         case Intrinsics.Float4x4 ; accumulator.* += 4; return;
      }

      ti := cast(*Type_Info) type;
      if (ti.type == .STRUCT) {
         tis := cast(*Type_Info_Struct) ti;
         for tis.members {
            Helper(get_type(it.type), accumulator);
         }

         return;
      }

      // if i reached here then it means there is a member with a weird type
      assert(false, "type: %\n", type);
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

            data.locationsConsumedByPerVertexMeshOut = CalculateLocationsConsumed(userStruct);
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


   functions := GenerateFunctions(*data, body);

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
                              GetSSAId(*data, header.name),
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
                              GetSSAId(*data, header.name),
                              GetSSAId(*data, GetInt32ConstIdentifier(*data, data.workgroupSize[0])),
                              GetSSAId(*data, GetInt32ConstIdentifier(*data, data.workgroupSize[1])),
                              GetSSAId(*data, GetInt32ConstIdentifier(*data, data.workgroupSize[2]))
         );
         print_to_builder(*b, "OpExecutionMode \%% OutputVertices %\n",
                              GetSSAId(*data, header.name),
                              data.maxVertices
         );
         print_to_builder(*b, "OpExecutionMode \%% OutputPrimitivesEXT %\n",
                              GetSSAId(*data, header.name),
                              data.maxPrimitives
         );
         print_to_builder(*b, "OpExecutionMode \%% %\n",
                              GetSSAId(*data, header.name),
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
         print_to_builder(*b, "OpDecorate \%% Location 0\n",
                              GetSSAId(*data, "meshVertexOut")
         );
         print_to_builder(*b, "OpDecorate \%% Location %\n",
                              GetSSAId(*data, "meshPrimitiveOut"),
                              data.locationsConsumedByPerVertexMeshOut,
         );
         print_to_builder(*b, "OpDecorate \%% PerPrimitiveEXT\n",
                              GetSSAId(*data, "meshPrimitiveOut")
         );

         // print_to_builder(*b, "OpDecorate \%% Block\n",
         //                      GetSSAId(*data, "PushData")
         // );
         // print_to_builder(*b, "OpMemberDecorate \%% 0 Offset 0\n", // task data pointer
         //                      GetSSAId(*data, "PushData")
         // );
         // print_to_builder(*b, "OpMemberDecorate \%% 1 Offset 8\n", // mesh data pointer
         //                      GetSSAId(*data, "PushData")
         // );
         // print_to_builder(*b, "OpMemberDecorate \%% 2 Offset 16\n", // fragment data pointer
         //                      GetSSAId(*data, "PushData")
         // );
         find_or_add(*data.structs, PushData);

         print_to_builder(*b, "OpDecorate \%% BuiltIn PrimitiveTriangleIndicesEXT\n",
                              GetSSAId(*data, "primitiveTriangleIndicesEXT")
         );

         // struct annotate infos
         print_to_builder(*b, "\n; struct annotate infos\n");
         for _, s: data.structs {
            annotateInfo := GetAnnotateInfoFromStruct(s);
            structIdentifier := GetIdentifierFromType(s);
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
         print_to_builder(*b, "\%% = OpTypeFunction \%%\n",
                              GetSSAId(*data, GetEmptyFunctionIdentifier()),
                              GetSSAId(*data, "void")
         );
         print_to_builder(*b, "\%% = OpTypeInt 32\n",
                              GetSSAId(*data, GetIdentifierFromType(Intrinsics.Int32))
         );
         print_to_builder(*b, "\%% = OpTypeVector \%% 2\n",
                              GetSSAId(*data, GetIdentifierFromType(Intrinsics.Int32x2)),
                              GetSSAId(*data, GetIdentifierFromType(Intrinsics.Int32))
         );
         print_to_builder(*b, "\%% = OpTypeVector \%% 3\n",
                              GetSSAId(*data, GetIdentifierFromType(Intrinsics.Int32x3)),
                              GetSSAId(*data, GetIdentifierFromType(Intrinsics.Int32))
         );
         print_to_builder(*b, "\%% = OpTypeVector \%% 4\n",
                              GetSSAId(*data, GetIdentifierFromType(Intrinsics.Int32x4)),
                              GetSSAId(*data, GetIdentifierFromType(Intrinsics.Int32))
         );
         print_to_builder(*b, "\%% = OpTypeFloat 32\n",
                              GetSSAId(*data, GetIdentifierFromType(Intrinsics.Float))
         );
         print_to_builder(*b, "\%% = OpTypeVector \%% 2\n",
                              GetSSAId(*data, GetIdentifierFromType(Intrinsics.Float2)),
                              GetSSAId(*data, GetIdentifierFromType(Intrinsics.Float))
         );
         print_to_builder(*b, "\%% = OpTypeVector \%% 3\n",
                              GetSSAId(*data, GetIdentifierFromType(Intrinsics.Float3)),
                              GetSSAId(*data, GetIdentifierFromType(Intrinsics.Float))
         );
         print_to_builder(*b, "\%% = OpTypeVector \%% 4\n",
                              GetSSAId(*data, GetIdentifierFromType(Intrinsics.Float4)),
                              GetSSAId(*data, GetIdentifierFromType(Intrinsics.Float))
         );
         print_to_builder(*b, "\%% = OpTypeMatrix \%% 2\n",
                              GetSSAId(*data, GetIdentifierFromType(Intrinsics.Float2x2)),
                              GetSSAId(*data, GetIdentifierFromType(Intrinsics.Float2))
         );
         print_to_builder(*b, "\%% = OpTypeMatrix \%% 3\n",
                              GetSSAId(*data, GetIdentifierFromType(Intrinsics.Float3x3)),
                              GetSSAId(*data, GetIdentifierFromType(Intrinsics.Float3))
         );
         print_to_builder(*b, "\%% = OpTypeMatrix \%% 4\n",
                              GetSSAId(*data, GetIdentifierFromType(Intrinsics.Float4x4)),
                              GetSSAId(*data, GetIdentifierFromType(Intrinsics.Float4))
         );

         // int constants
         print_to_builder(*b, "\n; int constants\n");
         for _, constant: data.intConstants {
            print_to_builder(*b, "\%% = OpConstant \%% %\n",
                                 GetSSAId(*data, GetInt32ConstIdentifier(*data, constant)),
                                 GetSSAId(*data, GetIdentifierFromType(Intrinsics.Int32)),
                                 constant
            );
         }


         // functions
         print_to_builder(*b, "\n; functions\n");
         print_to_builder(*b, "%", functions);
      }
   }

   print("%", builder_to_string(*b));

   return .{};
}

GenerateFunctions :: (data: *CompilationData, body: *Code_Procedure_Body) -> string {
   b: String_Builder;

   // entry function is handled seperately because its parameters define the general shader interface
   // so it actually has no parameters. other functions behave more normally
   {
      // entry function is always void?
      header := body.header;
      block := body.block;
      print_to_builder(*b, "\%% = OpFunction \%% None \%%\n",
                           GetSSAId(data, header.name),
                           GetSSAId(data, "void"),
                           GetSSAId(data, GetEmptyFunctionIdentifier())
      );

      //
      // not adding this function type to CompilationData.functions since entry function is handled seperately
      //    - apila, 04/04/26
      //

      GenerateInstructions(data, block, *b);
      print_to_builder(*b, "OpReturn\n");
      print_to_builder(*b, "OpFunctionEnd\n");
   }

   while data.functionFrontier.count > 0 {
      ok, current := Dequeue(*data.functionFrontier);
      assert(ok);

      header := current.header;
      block := current.block;

      find_or_add(*data.functions, header);

      returnTypeIdentifier := GetReturnTypeIdentifier(header);
      functionTypeIdentifier := GetFunctionTypeIdentifier(header);
      print_to_builder(*b, "\%% = OpFunction \%% None \%%\n",
                           GetSSAId(data, header.name),
                           GetSSAId(data, returnTypeIdentifier),
                           GetSSAId(data, functionTypeIdentifier)
      );

      GenerateInstructions(data, block, *b);

      if (header.returns.count == 0) {
         print_to_builder(*b, "OpReturn\n");
      }

      print_to_builder(*b, "OpFunctionEnd\n");
   }

   return builder_to_string(*b);
}

// traverse AST and output the generated spirv to "b".
// returns ssaId if the "node" is something that has an id, if not then output is ignored.
GenerateInstructions :: (data: *CompilationData, node: *Code_Node, b: *String_Builder) -> ssaId: int {
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
         assert(false, "code node kind: %. not valid.", node.kind);

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
         assert(false, "code node kind: %. idk what to do with this", node.kind);

      case .DIRECTIVE_RUN               ;
         assert(false, "do the #run outside the shader procedure to let jai compiler #run it. this compiler doesnt have #run");

      case .DIRECTIVE_POKE_NAME         ;
         assert(false, "idk what this directive is");

      case .DIRECTIVE_IMPORT            ;
         return 0; // i think i should skip? idk maybe

      case .TYPE_QUERY                  ;
         // size_of, type_info
         assert(false, "read the comment above. i need a way to get the value somehow not the code nodes");

      case .DEFER                       ;
         assert(false, "idk how to implement");

      case .USING                       ;
         // should i ignore?
         return 0;

      case .DIRECTIVE_INSERT            ;
         assert(false, "read the comment above");

      case .DIRECTIVE_PROCEDURE_NAME    ;
         assert(false, "read the comment above");

      case .DIRECTIVE_EXISTS            ;
         assert(false, "read the comment above");

      case .DIRECTIVE_OVERLAY           ;
         assert(false, "i guess i should never see this. the parsing of structs is done through Type_Info, not through code nodes");

      // idk if this implementation is correct or do i need to do some other stuff.
      // right now it behaves as if there is no block
      case .BLOCK                       ;
         cb := cast(*Code_Block)node;
         for cb.statements {
            GenerateInstructions(data, it, b);
         }
         return 0;

      case .LITERAL                     ;
      case .IDENT                       ;
      case .UNARY_OPERATOR              ;
      case .BINARY_OPERATOR             ;
         cbo := cast(*Code_Binary_Operator)node;

         if cbo.operator_type == {
            case #char "+"; {
               assert(cbo.left.type == cbo.right.type);

               leftId := GenerateInstructions(data, cbo.left, b);
               rightId := GenerateInstructions(data, cbo.right, b);

               resultSSAId := GetNextSSAId(data);

               type := get_type(cbo.left.type);
               identifier := GetIdentifierFromType(type);
               if type == {
                  case Intrinsics.Float;  #through;
                  case Intrinsics.Float2; #through;
                  case Intrinsics.Float3; #through;
                  case Intrinsics.Float4;
                     print_to_builder(b, "\%% = OpFAdd \%% \%% \%%\n",
                                          resultSSAId,
                                          GetSSAId(data, identifier),
                                          leftId,
                                          rightId
                     );

                  case Intrinsics.Int32;   #through;
                  case Intrinsics.Int32x2; #through;
                  case Intrinsics.Int32x3; #through;
                  case Intrinsics.Int32x4;
                     print_to_builder(b, "\%% = OpIAdd \%% \%% \%%\n",
                                          resultSSAId,
                                          GetSSAId(data, identifier),
                                          leftId,
                                          rightId
                     );
               }

               return resultSSAId;
            }

         }
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

   assert(false, "node.kind: %, didnt return!", node.kind);
   return -69;
}

StructAnnotateMemberInfo :: struct {
   memberIndex:   int;
   offset:        int;
}

StructAnnotateInfo :: struct {
   memberInfos: [] StructAnnotateMemberInfo;
}

PushData :: struct {
   taskData:      *void;
   meshData:      *void;
   fragmentData:  *void;
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

MeshPerVertex :: struct {
   position:   Vector4;
   pointSize:  float;
}

// i need this function since "void" is kinda special
GetReturnTypeIdentifier :: (header: *Code_Procedure_Header) -> string {
   assert(header.returns.count <= 1);

   if (header.returns.count == 0) {
      return "void";
   }

   // returns count must be one here as asserted above
   returnType := get_type(header.returns[0].type);
   return GetIdentifierFromType(returnType);
}

GetNextSSAId :: (using data: *CompilationData) -> int {
   ssaIota += 1;
   return ssaIota;
}

GetInt32ConstIdentifier :: (data: *CompilationData, value: int) -> string {
   find_or_add(*data.intConstants, value);
   return sprint("int32_%", value);
}

//
// kinda hack
// i need this because the entry function in jai has lots of paramters but
// they are actually not paratmers but input output global storages, so i can not get
// the identifier name from its signature like i do with other functions
// the entry function is always takes no arguments returns nothing. so i created this function
// so it is consistent with other functions. that is if another function takes no arguments and returns nothing
// their type identifier will match and i will not generate the same type twice which is illegal in spirv, so it is nice.
//
//          - apila, 04/04/26
//
GetEmptyFunctionIdentifier :: () -> string {
   header: Code_Procedure_Header;
   return GetFunctionTypeIdentifier(*header);
}

GetFunctionTypeIdentifier :: (header: *Code_Procedure_Header) -> string {
   LoopBody :: () #expand {
      type := get_type(`it.type);
      typeIdentifier := GetIdentifierFromType(type);
      print_to_builder(*b, "%", typeIdentifier);
   }

   b: String_Builder;
   print_to_builder(*b, "FunctionType");

   for header.returns {
      LoopBody();
   }

   print_to_builder(*b, "_");

   for header.arguments {
      LoopBody();
   }

   return builder_to_string(*b);
}

GetIdentifierFromType :: (type: Type) -> string {
   Helper :: (type: Type, b: *String_Builder) {
      // intrinsics
      if type == {
         case Intrinsics.Int32    ; print_to_builder(b, "int32"); return;
         case Intrinsics.Int32x2  ; print_to_builder(b, "int32x2"); return;
         case Intrinsics.Int32x3  ; print_to_builder(b, "int32x3"); return;
         case Intrinsics.Int32x4  ; print_to_builder(b, "int32x4"); return;
         case Intrinsics.Float    ; print_to_builder(b, "float"); return;
         case Intrinsics.Float2   ; print_to_builder(b, "float2"); return;
         case Intrinsics.Float3   ; print_to_builder(b, "float3"); return;
         case Intrinsics.Float4   ; print_to_builder(b, "float4"); return;
         case Intrinsics.Float2x2 ; print_to_builder(b, "float2x2"); return;
         case Intrinsics.Float3x3 ; print_to_builder(b, "float3x3"); return;
         case Intrinsics.Float4x4 ; print_to_builder(b, "float4x4"); return;
      }

      ti := cast(*Type_Info)type;
      if (ti.type == .STRUCT) {
         tis := cast(*Type_Info_Struct)ti;
         print_to_builder(b, tis.name);
         return;
      }

      if (ti.type == .POINTER) {
         tip := cast(*Type_Info_Pointer)ti;
         print_to_builder(b, "p_");
         innerType := get_type(tip.pointer_to);
         Helper(innerType, b);
         return;
      }

      if (ti.type == .ARRAY) {
         tia := cast(*Type_Info_Array)ti;
         print_to_builder(b, "a_");
         innerType := get_type(tia.element_type);
         Helper(innerType, b);
         return;
      }

      assert(false, "type: %. this type is not supported yet. if it is builtin jai type use Intrinsics instead", type);
   }

   b: String_Builder;
   Helper(type, *b);
   return builder_to_string(*b);
}

// identifier rules:
//    identifier of a struct is its name
//    for int its "int32" or int followed by the bit size
//    for float it is just "float"
//    int vectors are int32x followed by size. "int32x4" is ivec4 in glsl
//    float vectors are float followed by size. "float4" is vec4 in glsl
//    matrices are float2x2, float3x3.
//    function types are FunctionType followed by its signature. for example FunctionTypevoid. first the return value then arguments. the return value is either "void" or a single type
//    identifier of functions is their jai name including entry functions. but the entry point given in OpEntryPoint is not their identifier. it is either ApilaMS, ApilaTS, ApilaFS or ApilaCS
//
// update on the identifier rules:
// forms of identifiers dont matter. as long as it is unique, that is you get a unique identifier for different input config.
// just create functions to get identifiers so it is consistent throughout the program. what the actual identifier is doesnt matter so
// you can forget about the rules above and dont need to worry about them. just make sure you are calling a function to get an identifier
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
