#import "Basic";
#import "Compiler";
#import "Math";
#import "String";
#import "Hash_Table";
#import "Queue";
#import "Hash";

MeshOutVertex :: struct {
   position: Float3;
   color: Float4;
}
MeshOutPrimitive :: struct { }

MESH_VERTICES_NAME   :: "meshVertices";
MESH_TRIANGLES_NAME  :: "meshTriangles";
// vvvvvv intrinsics vvvvvvvv
Int32    :: s32; // idk. maybe not the way to do it
Int32x2  :: struct {};
Int32x3  :: struct {};
Int32x4  :: struct {};

Int64    :: s64; // idk. maybe not the way to do it
Int64x2  :: struct {};
Int64x3  :: struct {};
Int64x4  :: struct {};

Float    :: float; // idk. maybe not the way to do it
Float2   :: struct {};
Float3   :: struct {};
Float4   :: struct {};

Float2x2 :: struct {};
Float3x3 :: struct {};
Float4x4 :: struct {};

MeshPerVertex :: struct {
   position:   Float4;
   pointSize:  Float;
}

#insert #run sprint("%: [] MeshPerVertex;", MESH_VERTICES_NAME); // gl_MeshVerticesEXT
#insert #run sprint("%: [] Int32x3;", MESH_TRIANGLES_NAME); // gl_PrimitiveTriangleIndicesEXT
// ^^^^^^ intrinsics ^^^^^^^^^


FragmentData :: struct { }
MeshData :: struct { }

MeshShader :: (mOutVertex: *[] MeshOutVertex, mOutPrimitive: *[] MeshOutPrimitive, data: *MeshData) {
   a := 10;
   a = a + a;
} @1_1_1 @40_20 @triangles

FragmentShader :: (mOutVertex: MeshOutVertex, mOutPrimitive: MeshOutPrimitive, data: *FragmentData) -> Float4 {
   anan123: int = 10;
   return .{};
}

// identifier is anything that can be given an ssa id.
Identifier :: struct {
   type: enum {
      IntLiteral;
      FloatLiteral;
      Function;
      _Type;
      Void;
      Variable;
      BuiltinThingies;
   };

   using value: union {
      intLiteral:       struct {
                           value:      int;
                           bitSize:    int;
                        };
      floatLiteral:     float;
      function:         *Code_Procedure_Header;
      _type:            struct {
                           type:       Type;

                           // if type is pointer additional information is here
                           pointer:    struct {
                                          storageClass:  StorageClass;
                                          untyped:       bool;
                                          // TODO:
                                          // here i also need to store the what the pointer points to as an Identifier
                                          // and should use it in the comparison in IdentifierCompare function.
                                          // otherwise if i have pointer to pointers program will not work.
                                          // and in the places where i used tip.pointer_to, i should use the Identifier stored here instead.
                                          //       - apila, 12/04/26
                                       };
                        };
      // _void: // Void doesnt have a value
      variable:         *Code_Declaration;
      builtinThingies:  enum {
                           MeshVerticesEXTOutVariable;
                           PushDataVariable;
                           PrimitiveTriangleIndicesEXTOutVariable;
                           SamplerHeapVariable;
                           ImageHeapVariable;
                        };
   };
}

StorageClass :: enum {
   Function;
   PhysicalStorageBuffer;
   Output;
   PushConstant;
   UniformConstant;
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

IdentifierHash :: (using identifier: Identifier) -> u32 {
   if #complete type == {
      case .IntLiteral; return get_hash(intLiteral.value);
      case .FloatLiteral; return get_hash(floatLiteral);
      case .Function; return get_hash(function);
      case ._Type;
         ti := cast(*Type_Info) _type.type;
         if (ti.type == .POINTER) {
            if (_type.pointer.untyped) {
               return cast,trunc(u32) fnv1a_hash(xx _type.pointer.storageClass);
            }
         }

         return cast,trunc(u32) fnv1a_hash(xx *_type.type, size_of(Type));
      case .Void; return 69; // does the hash matter here?
      case .Variable; return get_hash(variable.name);
      case .BuiltinThingies; return get_hash(builtinThingies);
   }

   assert(false, "type: %", type);
}

IdentifierCompare :: (a: Identifier, b: Identifier) -> bool {
   if (a.type != b.type) return false;

   type := a.type;
   if #complete type == {
      case .IntLiteral; return a.intLiteral.bitSize == b.intLiteral.bitSize && a.intLiteral.value == b.intLiteral.value;
      case .FloatLiteral; return a.floatLiteral == b.floatLiteral;
      case .Function; return a.function == b.function; // if they point to the same code node
      case ._Type;
         tiA := cast(*Type_Info) a._type.type;
         tiB := cast(*Type_Info) b._type.type;

         if (tiA.type == .POINTER && tiB.type == .POINTER) {
            tipA := cast(*Type_Info_Pointer) tiA;
            tipB := cast(*Type_Info_Pointer) tiB;

            if (a._type.pointer.untyped != b._type.pointer.untyped) return false;
            untyped := a._type.pointer.untyped; // at this point a.pointer.untyped and b.pointer.untyped has the same value
            if (untyped) {
               return a._type.pointer.storageClass == b._type.pointer.storageClass;
            } else {
               return a._type.pointer.storageClass == b._type.pointer.storageClass && tipA.pointer_to == tipB.pointer_to;
            }
         } else {
            return a._type.type == b._type.type;
         }

      case .Void; return true;
      case .Variable; return a.variable == b.variable; // two variables are equal if they have the same declaration
      case .BuiltinThingies; return a.builtinThingies == b.builtinThingies;
   }

   assert(false, "type: %", type);
}



CompilationData :: struct {
   workgroupSize:                         [3] int = .[1, 1, 1];
   maxVertices:                           int;
   maxPrimitives:                         int;
   primitiveTopology:                     string;
   identifierToSSAId:                     Table(Identifier, int, IdentifierHash, IdentifierCompare);
   ssaIota:                               int;
   functions:                             Table(*Code_Procedure_Header, struct {}); // this data is collected when generating instructions and then written into the Types block of spirv
   functionFrontier:                      Queue(*Code_Procedure_Body);
   locationsConsumedByPerVertexMeshOut:   int;
   meshVertexOutVariableIdentifier:       Identifier;
   meshPrimitiveOutVariableIdentifier:    Identifier;


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

// in depth first order
CalculateLocationsConsumed :: (T: Type) -> int {
   Helper :: (type: Type, accumulator: *int) {
      if type == {
         case Int32    ; accumulator.* += 1; return;
         case Int32x2  ; accumulator.* += 1; return;
         case Int32x3  ; accumulator.* += 1; return;
         case Int32x4  ; accumulator.* += 1; return;
         case Int64    ; accumulator.* += 1; return;
         case Int64x2  ; accumulator.* += 1; return;
         case Int64x3  ; accumulator.* += 2; return;
         case Int64x4  ; accumulator.* += 2; return;
         case Float    ; accumulator.* += 1; return;
         case Float2   ; accumulator.* += 1; return;
         case Float3   ; accumulator.* += 1; return;
         case Float4   ; accumulator.* += 1; return;
         case Float2x2 ; accumulator.* += 2; return;
         case Float3x3 ; accumulator.* += 3; return;
         case Float4x4 ; accumulator.* += 4; return;
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
         index := 0;

         // first argument: *[] MeshOutVertex. MeshOutVertex is user defined struct
         {
            defer index += 1;

            assert(header.arguments.count > index, "not enough arguments");
            assert(header.arguments[index].type.type == .POINTER, "first argument wrong");
            pointer := cast(*Type_Info_Pointer) header.arguments[index].type;
            assert(pointer.pointer_to.type == .ARRAY, "first argument wrong");
            array := cast(*Type_Info_Array) pointer.pointer_to;

            userStruct := get_type(array.element_type);
            // GetSSAId(*data, .{ type = ._Type, _type = userStruct });

            data.meshVertexOutVariableIdentifier = .{ type = .Variable, variable = header.arguments[index] };
            data.locationsConsumedByPerVertexMeshOut = CalculateLocationsConsumed(userStruct);
         }

         // second argument: mOutPrimitive: *[] MeshOutPrimitive. MeshOutPrimitive is user defined struct
         {
            defer index += 1;

            assert(header.arguments.count > index, "not enough arguments");
            assert(header.arguments[index].type.type == .POINTER, "second argument wrong");
            pointer := cast(*Type_Info_Pointer) header.arguments[index].type;
            assert(pointer.pointer_to.type == .ARRAY, "second argument wrong");
            array := cast(*Type_Info_Array) pointer.pointer_to;

            userStruct := get_type(array.element_type);
            // GetSSAId(*data, .{ type = ._Type, _type = userStruct });

            data.meshPrimitiveOutVariableIdentifier = .{ type = .Variable, variable = header.arguments[index] };
         }

         // third argument: *MeshData. MeshData is user defined struct
         {
            defer index += 1;

            assert(header.arguments.count > index, "not enoufh arguments");
            assert(header.arguments[index].type.type == .POINTER, "third argument wrong");
            pointer := cast(*Type_Info_Pointer) header.arguments[index].type;

            userStruct := get_type(pointer.pointer_to);
            // GetSSAId(*data, .{ type = ._Type, _type = userStruct });
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

         // https://github.com/KhronosGroup/GLSL/blob/main/extensions/ext/GLSL_EXT_mesh_shader.txt
         // you need to implement gl_PrimitivePointIndicesEXT gl_PrimitiveLineIndicesEXT similar to you implemented triangles
         // prolly new entries in Identifier.builtinThingies and stuff like that
         //          - apila, 12/04/26
         assert(primitiveTopology == "triangles");

         data.primitiveTopology = primitiveTopology;
      }
   }

   // this adds this pointer type to the identifierToSSAId table so it gets outputted in "pointer types" section
   // tho this is not the way to do it. some types/constants depend on each other so i need a frontier anyways
   // so in the future i prolly want to move this in to the frontier
   GetSSAId(*data, .{ type = ._Type, _type = .{ type = *void, pointer = .{ storageClass = .PhysicalStorageBuffer, untyped = true } } });

   functions := GenerateFunctions(*data, body);

   b: String_Builder;
   if type == {
      case .Mesh; {
         // first part
         print_to_builder(*b, "OpCapability Int64\n");
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
                              GetSSAId(*data, .{ type = .Function, function = header }),
                              "ApilaMS",
                              GetSSAId(*data, .{ type = .BuiltinThingies, builtinThingies = .MeshVerticesEXTOutVariable }),
                              GetSSAId(*data, .{ type = .BuiltinThingies, builtinThingies = .PushDataVariable }),
                              GetSSAId(*data, .{ type = .BuiltinThingies, builtinThingies = .PrimitiveTriangleIndicesEXTOutVariable }),
                              GetSSAId(*data, data.meshVertexOutVariableIdentifier),
                              GetSSAId(*data, data.meshPrimitiveOutVariableIdentifier),
                              GetSSAId(*data, .{ type = .BuiltinThingies, builtinThingies = .ImageHeapVariable }),
                              GetSSAId(*data, .{ type = .BuiltinThingies, builtinThingies = .SamplerHeapVariable })
         );
         print_to_builder(*b, "OpExecutionModeId \%% LocalSizeId \%% \%% \%%\n",
                              GetSSAId(*data, .{ type = .Function, function = header }),
                              GetSSAId(*data, .{ type = .IntLiteral, intLiteral = .{ value = data.workgroupSize[0], bitSize = 32 } }),
                              GetSSAId(*data, .{ type = .IntLiteral, intLiteral = .{ value = data.workgroupSize[1], bitSize = 32 } }),
                              GetSSAId(*data, .{ type = .IntLiteral, intLiteral = .{ value = data.workgroupSize[2], bitSize = 32 } })
         );
         print_to_builder(*b, "OpExecutionMode \%% OutputVertices %\n",
                              GetSSAId(*data, .{ type = .Function, function = header }),
                              data.maxVertices
         );
         print_to_builder(*b, "OpExecutionMode \%% OutputPrimitivesEXT %\n",
                              GetSSAId(*data, .{ type = .Function, function = header }),
                              data.maxPrimitives
         );
         print_to_builder(*b, "OpExecutionMode \%% %\n",
                              GetSSAId(*data, .{ type = .Function, function = header }),
                              ToSpirvOutputTopology(data.primitiveTopology)
         );



         // skip debug info



         // annotations (decorations)
         print_to_builder(*b, "\n; annotations (decorations)\n");
         print_to_builder(*b, "OpDecorate \%% Block\n",
                              GetSSAId(*data, .{ type = ._Type, _type = .{ type = MeshPerVertex } })
         );
         print_to_builder(*b, "OpMemberDecorate \%% 0 BuiltIn Position\n",
                              GetSSAId(*data, .{ type = ._Type, _type = .{ type = MeshPerVertex } })
         );
         print_to_builder(*b, "OpMemberDecorate \%% 1 BuiltIn PointSize\n",
                              GetSSAId(*data, .{ type = ._Type, _type = .{ type = MeshPerVertex } })
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
                              GetSSAId(*data, data.meshVertexOutVariableIdentifier)
         );
         print_to_builder(*b, "OpDecorate \%% Location %\n",
                              GetSSAId(*data, data.meshPrimitiveOutVariableIdentifier),
                              data.locationsConsumedByPerVertexMeshOut,
         );
         print_to_builder(*b, "OpDecorate \%% PerPrimitiveEXT\n",
                              GetSSAId(*data, data.meshPrimitiveOutVariableIdentifier)
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
         GetSSAId(*data, .{ type = ._Type, _type = .{ type = PushData } });

         print_to_builder(*b, "OpDecorate \%% BuiltIn PrimitiveTriangleIndicesEXT\n",
                              GetSSAId(*data, .{ type = .BuiltinThingies, builtinThingies = .PrimitiveTriangleIndicesEXTOutVariable })
         );
         print_to_builder(*b, "OpDecorate \%% BuiltIn ResourceHeapEXT\n",
                              GetSSAId(*data, .{ type = .BuiltinThingies, builtinThingies = .ImageHeapVariable })
         );
         print_to_builder(*b, "OpDecorate \%% BuiltIn SamplerHeapEXT\n",
                              GetSSAId(*data, .{ type = .BuiltinThingies, builtinThingies = .SamplerHeapVariable })
         );

         // idk if i need this?
         //    apila, 12/04/26
         //
         // struct annotate infos
         print_to_builder(*b, "\n; struct annotate infos\n");
         for ssaId, identifier: data.identifierToSSAId {
            if (identifier.type != ._Type) continue;
            ti := cast(*Type_Info) identifier._type.type;
            if (ti.type != .STRUCT) continue;

            if (identifier._type.type == MeshPerVertex) continue; // builtin struct handled seperately

            annotateInfo := GetAnnotateInfoFromStruct(identifier._type.type);
            structIdentifier: Identifier = .{ type = ._Type, _type = identifier._type };
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
                              GetSSAId(*data, .{ type = .Void })
         );
         print_to_builder(*b, "\%% = OpTypeFunction \%%\n",
                              GetSSAId(*data, .{ type = ._Type, _type = .{ type = #type () -> () } }),
                              GetSSAId(*data, .{ type = .Void })
         );
         print_to_builder(*b, "\%% = OpTypeInt 32 1\n",
                              GetSSAId(*data, .{ type = ._Type, _type = .{ type = Int32 } })
         );
         print_to_builder(*b, "\%% = OpTypeVector \%% 2\n",
                              GetSSAId(*data, .{ type = ._Type, _type = .{ type = Int32x2 } }),
                              GetSSAId(*data, .{ type = ._Type, _type = .{ type = Int32 } })
         );
         print_to_builder(*b, "\%% = OpTypeVector \%% 3\n",
                              GetSSAId(*data, .{ type = ._Type, _type = .{ type = Int32x3 } }),
                              GetSSAId(*data, .{ type = ._Type, _type = .{ type = Int32 } })
         );
         print_to_builder(*b, "\%% = OpTypeVector \%% 4\n",
                              GetSSAId(*data, .{ type = ._Type, _type = .{ type = Int32x4 } }),
                              GetSSAId(*data, .{ type = ._Type, _type = .{ type = Int32 } })
         );
         print_to_builder(*b, "\%% = OpTypeInt 64 1\n",
                              GetSSAId(*data, .{ type = ._Type, _type = .{ type = Int64 } })
         );
         print_to_builder(*b, "\%% = OpTypeVector \%% 2\n",
                              GetSSAId(*data, .{ type = ._Type, _type = .{ type = Int64x2 } }),
                              GetSSAId(*data, .{ type = ._Type, _type = .{ type = Int64 } })
         );
         print_to_builder(*b, "\%% = OpTypeVector \%% 3\n",
                              GetSSAId(*data, .{ type = ._Type, _type = .{ type = Int64x3 } }),
                              GetSSAId(*data, .{ type = ._Type, _type = .{ type = Int64 } })
         );
         print_to_builder(*b, "\%% = OpTypeVector \%% 4\n",
                              GetSSAId(*data, .{ type = ._Type, _type = .{ type = Int64x4 } }),
                              GetSSAId(*data, .{ type = ._Type, _type = .{ type = Int64 } })
         );
         print_to_builder(*b, "\%% = OpTypeFloat 32\n",
                              GetSSAId(*data, .{ type = ._Type, _type = .{ type = Float } })
         );
         print_to_builder(*b, "\%% = OpTypeVector \%% 2\n",
                              GetSSAId(*data, .{ type = ._Type, _type = .{ type = Float2 } }),
                              GetSSAId(*data, .{ type = ._Type, _type = .{ type = Float } })
         );
         print_to_builder(*b, "\%% = OpTypeVector \%% 3\n",
                              GetSSAId(*data, .{ type = ._Type, _type = .{ type = Float3 } }),
                              GetSSAId(*data, .{ type = ._Type, _type = .{ type = Float } })
         );
         print_to_builder(*b, "\%% = OpTypeVector \%% 4\n",
                              GetSSAId(*data, .{ type = ._Type, _type = .{ type = Float4 } }),
                              GetSSAId(*data, .{ type = ._Type, _type = .{ type = Float } })
         );
         print_to_builder(*b, "\%% = OpTypeMatrix \%% 2\n",
                              GetSSAId(*data, .{ type = ._Type, _type = .{ type = Float2x2 } }),
                              GetSSAId(*data, .{ type = ._Type, _type = .{ type = Float2 } })
         );
         print_to_builder(*b, "\%% = OpTypeMatrix \%% 3\n",
                              GetSSAId(*data, .{ type = ._Type, _type = .{ type = Float3x3 } }),
                              GetSSAId(*data, .{ type = ._Type, _type = .{ type = Float3 } })
         );
         print_to_builder(*b, "\%% = OpTypeMatrix \%% 4\n",
                              GetSSAId(*data, .{ type = ._Type, _type = .{ type = Float4x4 } }),
                              GetSSAId(*data, .{ type = ._Type, _type = .{ type = Float4 } })
         );

         //
         // so this gets processed when i am processing pointers below. meshVertices varaible type.
         // i know i need a better way to handle dependencies but for now deal with it
         //
         // what i am thinking on how to implement identifier dependecies is that each identifier will be a graph node
         // and i will have an edge from A to B if A depends on B. and i will traverse the graph until i find the first node where all its dependencies
         // written already and then write and repeat until all nodes are written. here a node something like this struct { dependencies: [] *Node; i: Identifier; written: bool; };
         //
         GetSSAId(*data, .{ type = ._Type, _type = .{ type = *void, pointer = .{ storageClass = .Output, untyped = true } } });
         GetSSAId(*data, .{ type = ._Type, _type = .{ type = *void, pointer = .{ storageClass = .PushConstant, untyped = true } } });
         GetSSAId(*data, .{ type = ._Type, _type = .{ type = *void, pointer = .{ storageClass = .UniformConstant, untyped = true } } });

         // pointer types
         print_to_builder(*b, "\n; pointer types\n");
         for ssaId, identifier: data.identifierToSSAId {
            if (identifier.type != ._Type) continue;
            ti := cast(*Type_Info) identifier._type.type;
            if (ti.type != .POINTER) continue;
            tip := cast(*Type_Info_Pointer) ti;

            storageClass := ToSpirvStorageClass(identifier._type.pointer.storageClass);

            if (identifier._type.pointer.untyped) {
               print_to_builder(*b, "\%% = OpTypeUntypedPointerKHR %\n",
                                    ssaId,
                                    storageClass
               );
            } else {
               pointerToIdentifier: Identifier; // identifier of the type that the pointer points to
               pointerToIdentifier = .{ type = ._Type, _type = .{ type = get_type(tip.pointer_to), pointer = .{ storageClass = identifier._type.pointer.storageClass } } };
               print_to_builder(*b, "\%% = OpTypePointer % \%%\n",
                                    ssaId,
                                    storageClass,
                                    GetSSAId(*data, pointerToIdentifier)
               );
            }
         }

         // meshVertices
         print_to_builder(*b, "\n; meshVertices\n");
         print_to_builder(*b, "\%% = OpUntypedVariableKHR \%% %\n",
                              GetSSAId(*data, .{ type = .BuiltinThingies, builtinThingies = .MeshVerticesEXTOutVariable }),
                              GetSSAId(*data, .{ type = ._Type, _type = .{ type = *void, pointer = .{ storageClass = .Output, untyped = true } } }),
                              ToSpirvStorageClass(.Output)
         );

         // meshTriangles
         print_to_builder(*b, "\n; meshTriangles\n");
         print_to_builder(*b, "\%% = OpUntypedVariableKHR \%% %\n",
                              GetSSAId(*data, .{ type = .BuiltinThingies, builtinThingies = .PrimitiveTriangleIndicesEXTOutVariable }),
                              GetSSAId(*data, .{ type = ._Type, _type = .{ type = *void, pointer = .{ storageClass = .Output, untyped = true } } }),
                              ToSpirvStorageClass(.Output)
         );

         // mesh vertex out variable (cant be untyped because decorated with Location)
         print_to_builder(*b, "\n; mesh vertex out variable\n");
         meshVertexOutVariableIdentifierType := get_type(data.meshVertexOutVariableIdentifier.variable.type);
         assert(data.meshVertexOutVariableIdentifier.variable.type.type == .POINTER);
         print_to_builder(*b, "\%% = OpVariable \%% %\n",
                              GetSSAId(*data, data.meshVertexOutVariableIdentifier),
                              GetSSAId(*data, .{ type = ._Type, _type = .{ type = meshVertexOutVariableIdentifierType, pointer = .{ storageClass = .Output } } }),
                              ToSpirvStorageClass(.Output)
         );

         // mesh primitive out variable (cant be untyped because decorated with Location)
         print_to_builder(*b, "\n; mesh primitive out variable\n");
         meshPrimitiveOutVariableIdentifierType := get_type(data.meshPrimitiveOutVariableIdentifier.variable.type);
         assert(data.meshPrimitiveOutVariableIdentifier.variable.type.type == .POINTER);
         print_to_builder(*b, "\%% = OpVariable \%% %\n",
                              GetSSAId(*data, data.meshPrimitiveOutVariableIdentifier),
                              GetSSAId(*data, .{ type = ._Type, _type = .{ type = meshPrimitiveOutVariableIdentifierType, pointer = .{ storageClass = .Output } } }),
                              ToSpirvStorageClass(.Output)
         );

         // image and sampler heaps
         print_to_builder(*b, "\n; image and sampler heaps\n");
         print_to_builder(*b, "\%% = OpUntypedVariableKHR \%% %\n",
                              GetSSAId(*data, .{ type = .BuiltinThingies, builtinThingies = .ImageHeapVariable }),
                              GetSSAId(*data, .{ type = ._Type, _type = .{ type = *void, pointer = .{ storageClass = .UniformConstant, untyped = true } } }),
                              ToSpirvStorageClass(.UniformConstant)
         );
         print_to_builder(*b, "\%% = OpUntypedVariableKHR \%% %\n",
                              GetSSAId(*data, .{ type = .BuiltinThingies, builtinThingies = .SamplerHeapVariable }),
                              GetSSAId(*data, .{ type = ._Type, _type = .{ type = *void, pointer = .{ storageClass = .UniformConstant, untyped = true } } }),
                              ToSpirvStorageClass(.UniformConstant)
         );

         // push data variable
         print_to_builder(*b, "\n; push data variable\n");
         print_to_builder(*b, "\%% = OpUntypedVariableKHR \%% %\n",
                              GetSSAId(*data, .{ type = .BuiltinThingies, builtinThingies = .PushDataVariable }),
                              GetSSAId(*data, .{ type = ._Type, _type = .{ type = *void, pointer = .{ storageClass = .PushConstant, untyped = true } } }),
                              ToSpirvStorageClass(.PushConstant)
         );

         // push data struct
         print_to_builder(*b, "\n; push data struct\n");
         print_to_builder(*b, "\%% = OpTypeStruct \%% \%% \%%\n",
                              GetSSAId(*data, .{ type = ._Type, _type = .{ type = PushData } }),
                              GetSSAId(*data, .{ type = ._Type, _type = .{ type = *void, pointer = .{ storageClass = .PhysicalStorageBuffer, untyped = true } } }), // task
                              GetSSAId(*data, .{ type = ._Type, _type = .{ type = *void, pointer = .{ storageClass = .PhysicalStorageBuffer, untyped = true } } }), // mesh
                              GetSSAId(*data, .{ type = ._Type, _type = .{ type = *void, pointer = .{ storageClass = .PhysicalStorageBuffer, untyped = true } } })  // fragment
         );


         // int constants
         print_to_builder(*b, "\n; int constants\n");
         for ssaId, identifier: data.identifierToSSAId {
            if identifier.type == .IntLiteral {
               intLiteralType: Type;
               #if (false) {
               } else if (identifier.intLiteral.bitSize == 32) {
                  intLiteralType = Int32;
               } else if (identifier.intLiteral.bitSize == 64) {
                  intLiteralType = Int64;
               } else {
                  assert(false, "identifier.intLiteral.bitSize: %, not implemented yet!", identifier.intLiteral.bitSize);
               }

               print_to_builder(*b, "\%% = OpConstant \%% %\n",
                                    ssaId,
                                    GetSSAId(*data, .{ type = ._Type, _type = .{ type = intLiteralType } }),
                                    identifier.intLiteral.value
               );
            }
         }

         // float constants
         print_to_builder(*b, "\n; float constants\n");
         for ssaId, identifier: data.identifierToSSAId {
            if identifier.type == .FloatLiteral {
               print_to_builder(*b, "\%% = OpConstant \%% %\n",
                                    ssaId,
                                    GetSSAId(*data, .{ type = ._Type, _type = .{ type = Float } }),
                                    identifier.floatLiteral
               );
            }
         }

         // this is wrong. dependencies are not handled
         //       - apila, 11/04/26
         //
         // struct types
         print_to_builder(*b, "\n; struct types\n");
         for ssaId, identifier: data.identifierToSSAId {
            if (identifier.type != ._Type) continue;
            ti := cast(*Type_Info) identifier._type.type;
            if (ti.type != .STRUCT) continue;

            if identifier._type.type == {
               case Int32    ; continue;
               case Int32x2  ; continue;
               case Int32x3  ; continue;
               case Int32x4  ; continue;
               case Int64    ; continue;
               case Int64x2  ; continue;
               case Int64x3  ; continue;
               case Int64x4  ; continue;
               case Float    ; continue;
               case Float2   ; continue;
               case Float3   ; continue;
               case Float4   ; continue;
               case Float2x2 ; continue;
               case Float3x3 ; continue;
               case Float4x4 ; continue;
               case PushData;  continue;
            }

            print_to_builder(*b, "\%% = OpTypeStruct",
                                 ssaId
            );

            tis := cast(*Type_Info_Struct) ti;
            for tis.members {
               assert(it.type.type != .POINTER, "tis.name: %, it.name: %. user defined struct has a pointer. not implemented yet!", tis.name, it.name);

               memberType := get_type(it.type);
               print_to_builder(*b, " \%%",
                                    GetSSAId(*data, .{ type = ._Type, _type = .{ type = memberType } })
               );
            }

            print_to_builder(*b, "  ; %\n", tis.name);
         }


         // functions
         print_to_builder(*b, "\n; functions\n");
         print_to_builder(*b, "%", functions);
      }
   }

   spirvasm := builder_to_string(*b);
   print("%", spirvasm);
   #import "File";
   write_entire_file("jai.spvasm", spirvasm);

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
      print_to_builder(*b, "; main function\n");
      print_to_builder(*b, "\%% = OpFunction \%% None \%%\n",
                           GetSSAId(data, .{ type = .Function, function = header }),
                           GetSSAId(data, .{ type = .Void }),
                           GetSSAId(data, .{ type = ._Type, _type = .{ type = #type () -> () } })
      );

      // idk what to do with the label rn
      print_to_builder(*b, "\%% = OpLabel\n", GetNextSSAId(data));

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

      assert(header.type.type != .POINTER);
      functionTypeIdentifier: Identifier = .{ type = ._Type, _type = .{ type = get_type(header.type) } };
      print_to_builder(*b, "\n; %\n", header.name);
      print_to_builder(*b, "\%% = OpFunction \%% None \%%\n",
                           GetSSAId(data,  .{ type = .Function, function = header }),
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

GenerateInstructionsData :: struct {
   literal: struct {
      intLiteralBitSize: int = 64;
   };
}

// traverse AST and output the generated spirv to "b".
// returns ssaId if the "node" is something that has an id, if not then output is ignored.
GenerateInstructions :: (data: *CompilationData, node: *Code_Node, b: *String_Builder, additionalData: GenerateInstructionsData = .{}) -> ssaId: int {
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
         cl := cast(*Code_Literal) node;
         if cl.value_type == {
            case .NUMBER;
               if (cl.value_flags & .FLOAT) {
                  identifier: Identifier = .{ type = .FloatLiteral, floatLiteral = xx cl._float64 };
                  return GetSSAId(data, identifier);
               } else {
                  assert(additionalData.literal.intLiteralBitSize == 32 || additionalData.literal.intLiteralBitSize == 64, "additionalData.literal.intLiteralBitSize: %, not implemented yet!", additionalData.literal.intLiteralBitSize);

                  identifier: Identifier = .{ type = .IntLiteral, intLiteral = .{ value = cl._s64, bitSize = additionalData.literal.intLiteralBitSize } };
                  return GetSSAId(data, identifier);
               }

            case; assert(false, "cl.value_type: %\n", cl.value_type);
         }

      // the r-value
      case .IDENT                       ;
         ci := cast(*Code_Ident) node;
         variableSSAId := GetSSAId(data, .{ type = .Variable, variable = ci.resolved_declaration });
         resultSSAId := GetNextSSAId(data);
         assert(ci.resolved_declaration.type.type != .POINTER, "this means the user declared a local pointer, not implemented yet!");

         variableTypeIdentifier: Identifier = .{ type = ._Type, _type = .{ type = get_type(ci.resolved_declaration.type) } };
         print_to_builder(b, "\%% = OpLoad \%% \%%\n",
                              resultSSAId,
                              GetSSAId(data, variableTypeIdentifier),
                              variableSSAId
         );

         return resultSSAId;

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
               assert(cbo.left.type.type != .POINTER, "this means a pointer is being added (only valid with integers) but for now only same types supported so this would mean two pointers are being added. doesnt make sense");

               typeIdentifier: Identifier = .{ type = ._Type, _type = .{ type = type } };
               if type == {
                  case Float;  #through;
                  case Float2; #through;
                  case Float3; #through;
                  case Float4;
                     print_to_builder(b, "\%% = OpFAdd \%% \%% \%%\n",
                                          resultSSAId,
                                          GetSSAId(data, typeIdentifier),
                                          leftId,
                                          rightId
                     );

                  case Int32;   #through;
                  case Int32x2; #through;
                  case Int32x3; #through;
                  case Int32x4; #through;
                  case Int64;   #through;
                  case Int64x2; #through;
                  case Int64x3; #through;
                  case Int64x4;
                     print_to_builder(b, "\%% = OpIAdd \%% \%% \%%\n",
                                          resultSSAId,
                                          GetSSAId(data, typeIdentifier),
                                          leftId,
                                          rightId
                     );

                  case; assert(false, "type: %\n", type);
               }

               return resultSSAId;
            }

            case #char "="; {
               rightId := GenerateInstructions(data, cbo.right, b);

               if cbo.left.kind == {
                  case .IDENT; {
                     leftCi := cast(*Code_Ident) cbo.left;
                     leftId := GetSSAId(data, .{ type = .Variable, variable = leftCi.resolved_declaration } );
                     print_to_builder(b, "OpStore \%% \%%\n",
                                          leftId,
                                          rightId
                     );
                  }

                  case; assert(false, "cbo.left.kind: %", cbo.left.kind);
               }

               return rightId;
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
         cd := cast(*Code_Declaration)node;
         variableSSAId := GetSSAId(data, .{ type = .Variable, variable = cd });
         variableType := get_type(cd.type);

         assert(cd.type.type != .POINTER, "a pointer is declared, not implemented yet! loc: %:%", node.l0, node.c0);

         NO_INITIALIZER :: -1;
         initializerSSAId: int = NO_INITIALIZER;

         if (cd.expression != null) {
            if cd.expression.kind == {
               case .LITERAL; {
                  bitSizeData: GenerateInstructionsData;
                  BYTE_SIZE :: 8;
                  bitSizeData.literal.intLiteralBitSize = cd.type.runtime_size * BYTE_SIZE;
                  initializerSSAId = GenerateInstructions(data, cd.expression, b, bitSizeData);
               }

               case; assert(false, "cd.expression.kind: %, not implemented yet!", cd.expression.kind);
            }
         }

         storageClass := StorageClass.Function;
         print_to_builder(b, "\%% = OpUntypedVariableKHR \%% % \%%",
                              variableSSAId,
                              GetSSAId(data, .{ type = ._Type, _type = .{ type = *void /* doesnt matter what it points to since untyped */, pointer = .{ storageClass = storageClass, untyped = true } } }),
                              ToSpirvStorageClass(storageClass),
                              GetSSAId(data, .{ type = ._Type, _type = .{ type = variableType } })
         );

         if (initializerSSAId == NO_INITIALIZER) {
            print_to_builder(b, "\n");
         } else {
            print_to_builder(b, " \%%\n", initializerSSAId);
         }

         return variableSSAId;
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

// i need this function since "void" is kinda special
GetReturnTypeIdentifier :: (header: *Code_Procedure_Header) -> Identifier {
   assert(header.returns.count <= 1);

   if (header.returns.count == 0) {
      return .{ type = .Void };
   }

   // returns count must be one here as asserted above
   returnType := get_type(header.returns[0].type);
   assert(header.returns[0].type.type != .POINTER, "not implemented yet!");

   return .{ type = ._Type, _type = .{ type = returnType } };
}

GetNextSSAId :: (using data: *CompilationData) -> int {
   ssaIota += 1;
   return ssaIota;
}

GetSSAId :: (using data: *CompilationData, identifier: Identifier) -> int {
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

ToSpirvStorageClass :: (storageClass: StorageClass) -> string {
   if #complete storageClass == {
      case .Function; return "Function";
      case .PhysicalStorageBuffer; return "PhysicalStorageBuffer";
      case .Output; return "Output";
      case .PushConstant; return "PushConstant";
      case .UniformConstant; return "UniformConstant";
   }

   assert(false, "storageClass: %", storageClass);
}
