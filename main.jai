#import "Basic";
#import "Compiler";
#import "Math";
#import "String";
#import "Hash_Table";
#import "Queue";
#import "Hash";
#import "File";

MeshOutVertex :: struct {
   uv: Float2;
}
MeshOutPrimitive :: struct { }

MESH_VERTICES_NAME      :: "meshvertices";
MESH_TRIANGLES_NAME     :: "meshtriangles";
SET_MESH_OUTPUTS_NAME   :: "SetMeshOutputs";
// vvvvvv intrinsics vvvvvvvv
Int32    :: s32; // idk. maybe not the way to do it
Int32x2  :: struct {};
Int32x3  :: struct {};
Int32x4  :: struct {};

UInt32    :: u32; // idk. maybe not the way to do it
UInt32x2  :: struct {};
UInt32x3  :: struct {};
UInt32x4  :: struct {};

Int64    :: s64; // idk. maybe not the way to do it
Int64x2  :: struct {};
Int64x3  :: struct {};
Int64x4  :: struct {};

UInt64    :: u64; // idk. maybe not the way to do it
UInt64x2  :: struct {};
UInt64x3  :: struct {};
UInt64x4  :: struct {};

Float    :: float; // idk. maybe not the way to do it
Float2   :: struct { x: Float; y: Float; };
Float3   :: struct {};
Float4   :: struct { x: Float; y: Float; z: Float; w: Float; };

Float2x2 :: struct {};
Float3x3 :: struct {};
Float4x4 :: struct {};

MeshPerVertex :: struct {
   position:   Float4;
   pointSize:  Float;
}

#insert #run sprint("%: [] MeshPerVertex;", MESH_VERTICES_NAME); // gl_MeshVerticesEXT
#insert #run sprint("%: [] Int32x3;", MESH_TRIANGLES_NAME); // gl_PrimitiveTriangleIndicesEXT
#insert #run sprint("%: (vertexCount: UInt32, primitiveCount: UInt32) -> ();", SET_MESH_OUTPUTS_NAME); // SetMeshOutputsEXT
// ^^^^^^ intrinsics ^^^^^^^^^


FragmentData :: struct { }
MeshData :: struct {
   offset: float;
}

MeshShader :: (mOutVertex: [] MeshOutVertex, mOutPrimitive: [] MeshOutPrimitive, data: *MeshData) {
   SetMeshOutputs(4, 2);

   meshvertices[0].position = .{ -1, -1, 0.5, 1 };
   meshvertices[1].position = .{  1, -1, 0.5, 1 };
   meshvertices[2].position = .{  1,  1, 0.5, 1 };
   meshvertices[3].position = .{ -1,  1, 0.5, 1 };

   mOutVertex[0].uv = .{ 0, 0 };
   mOutVertex[1].uv = .{ 1, 0 };
   mOutVertex[2].uv = .{ 1, 1 };
   mOutVertex[3].uv = .{ 0, 1 };

   a: float = 10;
   a = a + a;
   a = a - 9;
   b: int;
} @1_1_1 @40_20 @triangles

FragmentShader :: (mOutVertex: MeshOutVertex, mOutPrimitive: MeshOutPrimitive, data: *FragmentData) -> Float4 {
   anan123: int = 10;
   return .{};
}

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
      BuiltinThingies;
      CompositeLiteral;
   };

   using value: union {
      intLiteral:       struct {
                           unsigned:   bool;
                           value:      union {
                                          _s64: s64;
                                          _u64: u64;
                                       };
                           bitSize:    int;
                        };
      floatLiteral:     float;
      function:         *Code_Procedure_Header;
      _type:            struct {
                           type:       *Type_Info;

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
                                          //
                                          // im not sure about this. you know the type situation. this doesnt work well
                                          //       - apila, 15/04/26
                                          //
                                          // idk if i should keep untyped or should use *void instead. because at first i planned to make almost every pointer an untyped pointer
                                          // even if it is declared with a type but it turns out that there are a lot of limitations to this. and maybe i should keep it because
                                          // in push data block it is typed but still i register untyped. but that maybe doesnt matter much because it means that instead of setting
                                          // this field to false i would just set type to *void
                                          //          - apila, 16/04/26
                                          //
                                       };
                        };
      // _void: // Void doesnt have a value
      variable:         struct {
                           //
                           // the declaration is the default. but there some variables that their declaration is above the scope of the shader
                           // for example intrinsics that i predefined, meshvertices, meshtriangles and such.
                           // when i use code_of it doesnt behave the way i want. i think it generates competely new tree instead of referencing to the one generated
                           // by the compiler during the compilation. so for that reason i use the name of these variables and this is fine since they are
                           // treated as a keyword anyways.
                           // and you shouldnt mix using name or using declaration for a single variable. either use name or the declaration. not both at the same time
                           //          - apila, 18/04/26
                           //
                           declaration:   *Code_Declaration;
                           useName:       bool;
                           name:          string;
                        };
      builtinThingies:  enum {
                           PushDataVariable;
                           SamplerHeapVariable;
                           ImageHeapVariable;
                        };
      compositeLiteral: struct {
                           type:       *Type_Info;
                           arguments:  [] *Identifier;
                        };
   };
}

StorageClass :: enum {
   Function;
   PhysicalStorageBuffer;
   Output;
   PushConstant;
   UniformConstant;
   Image;
   Workgroup;
   StorageBuffer;
   Uniform;
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
      case .Invalid; assert(false); return 69;
      case .IntLiteral;
         if (intLiteral.unsigned) {
            return get_hash(intLiteral.value._u64);
         } else {
            return get_hash(intLiteral.value._s64);
         }

      case .FloatLiteral; return get_hash(floatLiteral);
      case .Function; return get_hash(function);
      case ._Type;
         ti := cast(*Type_Info) _type.type;
         if (ti.type == .POINTER) {
            if (_type.pointer.untyped) {
               return cast,trunc(u32) fnv1a_hash(xx _type.pointer.storageClass);
            }
         }

         return cast,trunc(u32) fnv1a_hash(xx *_type.type, size_of(type_of(_type.type)));
      case .Void; return 69; // does the hash matter here?
      case .Variable;
         if (variable.useName) {
            return get_hash(variable.name);
         } else {
            return get_hash(variable.declaration.name);
         }
      case .BuiltinThingies; return get_hash(builtinThingies);
      case .CompositeLiteral;
         hash: u32 = 17;
         hash = hash * 31 + get_hash(compositeLiteral.type);

         for compositeLiteral.arguments {
            hash = hash * 31 + IdentifierHash(it.*);
         }

         return hash;
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
      case .Variable;
         if (a.variable.useName != b.variable.useName) return false;

         useName := a.variable.useName; // or b.variable.useName. they are the same at this point
         if (useName) {
            return a.variable.name == b.variable.name;
         }

         return a.variable.declaration == b.variable.declaration; // two variables are equal if they have the same declaration
      case .BuiltinThingies; return a.builtinThingies == b.builtinThingies;
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
   }

   assert(false, "type: %", type);
}


IdentifierWriteStatus :: enum {
   BeingProcessed;
   Written;
}

CompilationData :: struct {
   workgroupSize:                         [3] int = .[1, 1, 1];
   maxVertices:                           int;
   maxPrimitives:                         int;
   primitiveTopology:                     string;
   identifierToSSAId:                     Table(Identifier, int, IdentifierHash, IdentifierCompare);
   ssaIota:                               int;

   // TODO
   // instead of having a frontier and a table generate the functions using a depth first traversel
   // similar to how you generate types
   //       - apila, 14/04/26
   functions:                             Table(*Code_Procedure_Header, struct {}); // this data is collected when generating instructions and then written into the Types block of spirv
   functionFrontier:                      Queue(*Code_Procedure_Body);
   locationsConsumedByPerVertexMeshOut:   int;
   meshVertexOutVariableIdentifier:       Identifier;
   meshPrimitiveOutVariableIdentifier:    Identifier;
   writtenIdentifiers:                    Table(Identifier, IdentifierWriteStatus, IdentifierHash, IdentifierCompare);
   meshVertexOutUserStruct:               *Type_Info;
   meshPrimitiveOutUserStruct:            *Type_Info;
   shaderDataPointerVariableIdentifier:   Identifier;


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
         case UInt32   ; accumulator.* += 1; return;
         case UInt32x2 ; accumulator.* += 1; return;
         case UInt32x3 ; accumulator.* += 1; return;
         case UInt32x4 ; accumulator.* += 1; return;
         case Int64    ; accumulator.* += 1; return;
         case Int64x2  ; accumulator.* += 1; return;
         case Int64x3  ; accumulator.* += 2; return;
         case Int64x4  ; accumulator.* += 2; return;
         case UInt64   ; accumulator.* += 1; return;
         case UInt64x2 ; accumulator.* += 1; return;
         case UInt64x3 ; accumulator.* += 2; return;
         case UInt64x4 ; accumulator.* += 2; return;
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

         // first argument: [] MeshOutVertex. MeshOutVertex is user defined struct
         {
            defer index += 1;

            assert(header.arguments.count > index, "not enough arguments");
            assert(header.arguments[index].type.type == .ARRAY, "first argument wrong");
            array := cast(*Type_Info_Array) header.arguments[index].type;

            data.meshVertexOutUserStruct = array.element_type;
            data.meshVertexOutVariableIdentifier = .{ type = .Variable, variable.declaration = header.arguments[index] };
            data.locationsConsumedByPerVertexMeshOut = CalculateLocationsConsumed(get_type(data.meshVertexOutUserStruct));
         }

         // second argument: mOutPrimitive: *[] MeshOutPrimitive. MeshOutPrimitive is user defined struct
         {
            defer index += 1;

            assert(header.arguments.count > index, "not enough arguments");
            assert(header.arguments[index].type.type == .ARRAY, "second argument wrong");
            array := cast(*Type_Info_Array) header.arguments[index].type;

            data.meshPrimitiveOutUserStruct = array.element_type;
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
                              GetSSAId(*data, .{ type = .Variable, variable = .{ useName = true, name = MESH_VERTICES_NAME } }),
                              GetSSAId(*data, .{ type = .BuiltinThingies, builtinThingies = .PushDataVariable }),
                              GetSSAId(*data, .{ type = .Variable, variable = .{ useName = true, name = MESH_TRIANGLES_NAME } }),
                              GetSSAId(*data, data.meshVertexOutVariableIdentifier),
                              GetSSAId(*data, data.meshPrimitiveOutVariableIdentifier),
                              GetSSAId(*data, .{ type = .BuiltinThingies, builtinThingies = .ImageHeapVariable }),
                              GetSSAId(*data, .{ type = .BuiltinThingies, builtinThingies = .SamplerHeapVariable })
         );
         print_to_builder(*b, "OpExecutionModeId \%% LocalSizeId \%% \%% \%%\n",
                              GetSSAId(*data, .{ type = .Function, function = header }),
                              GetSSAId(*data, .{ type = .IntLiteral, intLiteral = .{ unsigned = true, value._u64 = xx data.workgroupSize[0], bitSize = 32 } }),
                              GetSSAId(*data, .{ type = .IntLiteral, intLiteral = .{ unsigned = true, value._u64 = xx data.workgroupSize[1], bitSize = 32 } }),
                              GetSSAId(*data, .{ type = .IntLiteral, intLiteral = .{ unsigned = true, value._u64 = xx data.workgroupSize[2], bitSize = 32 } })
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
                              GetSSAId(*data, .{ type = ._Type, _type = .{ type = cast(*Type_Info) MeshPerVertex } })
         );
         print_to_builder(*b, "OpMemberDecorate \%% 0 BuiltIn Position\n",
                              GetSSAId(*data, .{ type = ._Type, _type = .{ type = cast(*Type_Info) MeshPerVertex } })
         );
         print_to_builder(*b, "OpMemberDecorate \%% 1 BuiltIn PointSize\n",
                              GetSSAId(*data, .{ type = ._Type, _type = .{ type = cast(*Type_Info) MeshPerVertex } })
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
         GetSSAId(*data, .{ type = ._Type, _type = .{ type = cast(*Type_Info) PushData } });

         print_to_builder(*b, "OpDecorate \%% BuiltIn PrimitiveTriangleIndicesEXT\n",
                              GetSSAId(*data, .{ type = .Variable, variable = .{ useName = true, name = MESH_TRIANGLES_NAME } })
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

            if (identifier._type.type == cast(*Type_Info) MeshPerVertex) continue; // builtin struct handled seperately

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

         print_to_builder(*b, "\n; Types, variables and constants\n");
         for typesConstantsVariables {
            WriteTypeOrVariableOrConstant(*data, *b, it);
         }

         // functions
         print_to_builder(*b, "\n; functions\n");
         print_to_builder(*b, "%", functions);
      }
   }

   spirvasm := builder_to_string(*b);
   // print("%", spirvasm);
   write_entire_file("jai.spvasm", spirvasm);

   return .{};
}

// this function is called for every identifier that exists in the shader program
// this function writes to "Types, variables and constants" block, so if an identifier doesnt go in that block this function should ignore and skip that identifier instead of asserting.
// i first thought that i should call this functions only on identifiers that goes into the "Types, variables and constants" block, but it is easier to let pass every identifier to this function
// and this function just skips if an identifier doesnt go to the "Types, variables and constants" block instead of asserting false.
//          - apila, 13/04/26
WriteTypeOrVariableOrConstant :: (data: *CompilationData, b: *String_Builder, identifier: Identifier) {
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

   if #complete identifier.type == {
      case .Invalid; assert(false);
      case .IntLiteral;
         intLiteralType: Type;
         #if (false) {
         } else if (identifier.intLiteral.bitSize == 32) {
            if (identifier.intLiteral.unsigned) {
               intLiteralType = UInt32;
            } else {
               intLiteralType = Int32;
            }
         } else if (identifier.intLiteral.bitSize == 64) {
            if (identifier.intLiteral.unsigned) {
               intLiteralType = UInt64;
            } else {
               intLiteralType = Int64;
            }
         } else {
            assert(false, "identifier.intLiteral.bitSize: %, not implemented yet!", identifier.intLiteral.bitSize);
         }

         intIdentifier: Identifier = .{ type = ._Type, _type = .{ type = cast(*Type_Info) intLiteralType } };
         WriteTypeOrVariableOrConstant(data, b, intIdentifier);

         print_to_builder(b, "\%% = OpConstant \%%",
                              GetSSAId(data, identifier),
                              GetSSAId(data, intIdentifier),
         );

         if (identifier.intLiteral.unsigned) {
            print_to_builder(b, " %\n",
                                 identifier.intLiteral.value._u64
            );
         } else {
            print_to_builder(b, " %\n",
                                 identifier.intLiteral.value._s64
            );
         }

      case .FloatLiteral;
         floatIdentifier: Identifier = .{ type = ._Type, _type = .{ type = cast(*Type_Info) Float } };
         WriteTypeOrVariableOrConstant(data, b, floatIdentifier);

         print_to_builder(b, "\%% = OpConstant \%% %\n",
                              GetSSAId(data, identifier),
                              GetSSAId(data, floatIdentifier),
                              identifier.floatLiteral
         );
      case .Function;
         return;
         // assert(false, "identifier: %. this is not where you write functions!", identifier);
      case ._Type;
         type := identifier._type.type;

         // intrinsics
         if (type == cast(*Type_Info) Int32) {
               print_to_builder(b, "\%% = OpTypeInt 32 1\n",
                                    GetSSAId(data, identifier)
               );
               return;
         }

         if (type == cast(*Type_Info) Int32x2) {
            intIdentifier: Identifier = .{ type = ._Type, _type = .{ type = cast(*Type_Info) Int32 } };
            WriteTypeOrVariableOrConstant(data, b, intIdentifier);

            print_to_builder(b, "\%% = OpTypeVector \%% 2\n",
                                 GetSSAId(data, identifier),
                                 GetSSAId(data, intIdentifier)
            );
            return;
         }

         if (type == cast(*Type_Info) Int32x3) {
            intIdentifier: Identifier = .{ type = ._Type, _type = .{ type = cast(*Type_Info) Int32 } };
            WriteTypeOrVariableOrConstant(data, b, intIdentifier);
            print_to_builder(b, "\%% = OpTypeVector \%% 3\n",
                                 GetSSAId(data, identifier),
                                 GetSSAId(data, intIdentifier)
            );
            return;
         }

         if (type == cast(*Type_Info) Int32x4) {
            intIdentifier: Identifier = .{ type = ._Type, _type = .{ type = cast(*Type_Info) Int32 } };
            WriteTypeOrVariableOrConstant(data, b, intIdentifier);
            print_to_builder(b, "\%% = OpTypeVector \%% 4\n",
                                 GetSSAId(data, identifier),
                                 GetSSAId(data, intIdentifier)
            );
            return;
         }

         if (type == cast(*Type_Info) UInt32) {
               print_to_builder(b, "\%% = OpTypeInt 32 0\n",
                                    GetSSAId(data, identifier)
               );
               return;
         }

         if (type == cast(*Type_Info) UInt32x2) {
            intIdentifier: Identifier = .{ type = ._Type, _type = .{ type = cast(*Type_Info) UInt32 } };
            WriteTypeOrVariableOrConstant(data, b, intIdentifier);

            print_to_builder(b, "\%% = OpTypeVector \%% 2\n",
                                 GetSSAId(data, identifier),
                                 GetSSAId(data, intIdentifier)
            );
            return;
         }

         if (type == cast(*Type_Info) UInt32x3) {
            intIdentifier: Identifier = .{ type = ._Type, _type = .{ type = cast(*Type_Info) UInt32 } };
            WriteTypeOrVariableOrConstant(data, b, intIdentifier);
            print_to_builder(b, "\%% = OpTypeVector \%% 3\n",
                                 GetSSAId(data, identifier),
                                 GetSSAId(data, intIdentifier)
            );
            return;
         }

         if (type == cast(*Type_Info) UInt32x4) {
            intIdentifier: Identifier = .{ type = ._Type, _type = .{ type = cast(*Type_Info) UInt32 } };
            WriteTypeOrVariableOrConstant(data, b, intIdentifier);
            print_to_builder(b, "\%% = OpTypeVector \%% 4\n",
                                 GetSSAId(data, identifier),
                                 GetSSAId(data, intIdentifier)
            );
            return;
         }

         if (type == cast(*Type_Info) Int64) {
            print_to_builder(b, "\%% = OpTypeInt 64 1\n",
                                 GetSSAId(data, identifier)
            );
            return;
         }

         if (type == cast(*Type_Info) Int64x2) {
            intIdentifier: Identifier = .{ type = ._Type, _type = .{ type = cast(*Type_Info) Int64 } };
            WriteTypeOrVariableOrConstant(data, b, intIdentifier);

            print_to_builder(b, "\%% = OpTypeVector \%% 2\n",
                                 GetSSAId(data, identifier),
                                 GetSSAId(data, intIdentifier)
            );
            return;
         }

         if (type == cast(*Type_Info) Int64x3) {
            intIdentifier: Identifier = .{ type = ._Type, _type = .{ type = cast(*Type_Info) Int64 } };
            WriteTypeOrVariableOrConstant(data, b, intIdentifier);
            print_to_builder(b, "\%% = OpTypeVector \%% 3\n",
                                 GetSSAId(data, identifier),
                                 GetSSAId(data, intIdentifier)
            );
            return;
         }

         if (type == cast(*Type_Info) Int64x4) {
            intIdentifier: Identifier = .{ type = ._Type, _type = .{ type = cast(*Type_Info) Int64 } };
            WriteTypeOrVariableOrConstant(data, b, intIdentifier);
            print_to_builder(b, "\%% = OpTypeVector \%% 4\n",
                                 GetSSAId(data, identifier),
                                 GetSSAId(data, intIdentifier)
            );
            return;
         }

         if (type == cast(*Type_Info) UInt64) {
            print_to_builder(b, "\%% = OpTypeInt 64 0\n",
                                 GetSSAId(data, identifier)
            );
            return;
         }

         if (type == cast(*Type_Info) UInt64x2) {
            intIdentifier: Identifier = .{ type = ._Type, _type = .{ type = cast(*Type_Info) UInt64 } };
            WriteTypeOrVariableOrConstant(data, b, intIdentifier);

            print_to_builder(b, "\%% = OpTypeVector \%% 2\n",
                                 GetSSAId(data, identifier),
                                 GetSSAId(data, intIdentifier)
            );
            return;
         }

         if (type == cast(*Type_Info) UInt64x3) {
            intIdentifier: Identifier = .{ type = ._Type, _type = .{ type = cast(*Type_Info) UInt64 } };
            WriteTypeOrVariableOrConstant(data, b, intIdentifier);
            print_to_builder(b, "\%% = OpTypeVector \%% 3\n",
                                 GetSSAId(data, identifier),
                                 GetSSAId(data, intIdentifier)
            );
            return;
         }

         if (type == cast(*Type_Info) UInt64x4) {
            intIdentifier: Identifier = .{ type = ._Type, _type = .{ type = cast(*Type_Info) UInt64 } };
            WriteTypeOrVariableOrConstant(data, b, intIdentifier);
            print_to_builder(b, "\%% = OpTypeVector \%% 4\n",
                                 GetSSAId(data, identifier),
                                 GetSSAId(data, intIdentifier)
            );
            return;
         }

         if (type == cast(*Type_Info) Float) {
            print_to_builder(b, "\%% = OpTypeFloat 32\n",
                                 GetSSAId(data, identifier)
            );
            return;
         }

         if (type == cast(*Type_Info) Float2) {
            floatIdentifier: Identifier = .{ type = ._Type, _type = .{ type = cast(*Type_Info) Float } };
            WriteTypeOrVariableOrConstant(data, b, floatIdentifier);

            print_to_builder(b, "\%% = OpTypeVector \%% 2\n",
                                 GetSSAId(data, identifier),
                                 GetSSAId(data, floatIdentifier)
            );
            return;
         }

         if (type == cast(*Type_Info) Float3) {
            floatIdentifier: Identifier = .{ type = ._Type, _type = .{ type = cast(*Type_Info) Float } };
            WriteTypeOrVariableOrConstant(data, b, floatIdentifier);
            print_to_builder(b, "\%% = OpTypeVector \%% 3\n",
                                 GetSSAId(data, identifier),
                                 GetSSAId(data, floatIdentifier)
            );
            return;
         }

         if (type == cast(*Type_Info) Float4) {
            floatIdentifier: Identifier = .{ type = ._Type, _type = .{ type = cast(*Type_Info) Float } };
            WriteTypeOrVariableOrConstant(data, b, floatIdentifier);
            print_to_builder(b, "\%% = OpTypeVector \%% 4\n",
                                 GetSSAId(data, identifier),
                                 GetSSAId(data, floatIdentifier)
            );
            return;
         }

         if (type == cast(*Type_Info) Float2x2) {
            float2Identifier: Identifier = .{ type = ._Type, _type = .{ type = cast(*Type_Info) Float2 } };
            WriteTypeOrVariableOrConstant(data, b, float2Identifier);

            print_to_builder(b, "\%% = OpTypeMatrix \%% 2\n",
                                 GetSSAId(data, identifier),
                                 GetSSAId(data, float2Identifier)
            );
            return;
         }

         if (type == cast(*Type_Info) Float3x3) {
            float3Identifier: Identifier = .{ type = ._Type, _type = .{ type = cast(*Type_Info) Float3 } };
            WriteTypeOrVariableOrConstant(data, b, float3Identifier);

            print_to_builder(b, "\%% = OpTypeMatrix \%% 3\n",
                                 GetSSAId(data, identifier),
                                 GetSSAId(data, float3Identifier)
            );
            return;
         }

         if (type == cast(*Type_Info) Float4x4) {
            float4Identifier: Identifier = .{ type = ._Type, _type = .{ type = cast(*Type_Info) Float4 } };
            WriteTypeOrVariableOrConstant(data, b, float4Identifier);

            print_to_builder(b, "\%% = OpTypeMatrix \%% 4\n",
                                 GetSSAId(data, identifier),
                                 GetSSAId(data, float4Identifier)
            );
            return;
         }

         if (type == cast(*Type_Info) PushData) {
            voidStar: Identifier = .{ type = ._Type, _type = .{ type = cast(*Type_Info) *void, pointer = .{ storageClass = .PhysicalStorageBuffer, untyped = true } } };
            WriteTypeOrVariableOrConstant(data, b, voidStar);

            print_to_builder(b, "\%% = OpTypeStruct \%% \%% \%%\n",
                                 GetSSAId(data, identifier),
                                 GetSSAId(data, voidStar), // task
                                 GetSSAId(data, voidStar), // mesh
                                 GetSSAId(data, voidStar)  // fragment
            );
            return;
         }

         ti := cast(*Type_Info) type;
         if (ti.type == .POINTER) {
            tip := cast(*Type_Info_Pointer) ti;
            pointer := identifier._type.pointer;

            storageClass := ToSpirvStorageClass(pointer.storageClass);

            if (pointer.untyped) {
               // VUID-StandaloneSpirv-OpTypeUntypedPointerKHR-11417
               // The Storage Class of OpTypeUntypedPointerKHR must be Image, UniformConstant,Workgroup, StorageBuffer, Uniform, PushConstant, or PhysicalStorageBuffer
               assert(pointer.storageClass == .Image || pointer.storageClass == .UniformConstant || pointer.storageClass == .Workgroup ||
                     pointer.storageClass == .StorageBuffer || pointer.storageClass == .Uniform || pointer.storageClass == .PushConstant ||
                     pointer.storageClass == .PhysicalStorageBuffer,
                     "storageClass: %, type: %", storageClass, type
               );

               print_to_builder(b, "\%% = OpTypeUntypedPointerKHR %\n",
                                    GetSSAId(data, identifier),
                                    storageClass
               );
            } else {
               pointerToIdentifier: Identifier; // identifier of the type that the pointer points to
               pointerToIdentifier = .{ type = ._Type, _type = .{ type = tip.pointer_to, pointer = .{ storageClass = identifier._type.pointer.storageClass } } };
               WriteTypeOrVariableOrConstant(data, b, pointerToIdentifier);

               print_to_builder(b, "\%% = OpTypePointer % \%%\n",
                                    GetSSAId(data, identifier),
                                    storageClass,
                                    GetSSAId(data, pointerToIdentifier)
               );
            }

            return;
         }

         if (ti.type == .STRUCT) {
            tis := cast(*Type_Info_Struct) ti;

            structBuilder: String_Builder;

            print_to_builder(*structBuilder, "\%% = OpTypeStruct",
                                             GetSSAId(data, identifier)
            );

            for tis.members {
               assert(it.type.type != .POINTER, "tis.name: %, it.name: %. user defined struct has a pointer. not implemented yet!", tis.name, it.name);

               memberType := it.type;
               memberTypeIdentifier: Identifier = .{ type = ._Type, _type = .{ type = memberType } };
               WriteTypeOrVariableOrConstant(data, b, memberTypeIdentifier);

               print_to_builder(*structBuilder, " \%%",
                                                GetSSAId(data, memberTypeIdentifier)
               );
            }

            print_to_builder(*structBuilder, "  ; %\n", tis.name);

            append_and_steal_buffers(b, *structBuilder);
            return;
         }

         if (ti.type == .PROCEDURE) {
            tip := cast(*Type_Info_Procedure) ti;

            returnTypeIdentifier := GetReturnTypeIdentifier(tip);
            WriteTypeOrVariableOrConstant(data, b, returnTypeIdentifier);

            functionBuilder: String_Builder;

            print_to_builder(*functionBuilder, "\%% = OpTypeFunction \%%",
                                                GetSSAId(data, identifier),
                                                GetSSAId(data, returnTypeIdentifier)
            );

            for tip.argument_types {
               assert(it.type != .POINTER, "function takes a pointer. not implemented yet!");

               argumentType := it;
               argumentTypeIdentifier: Identifier = .{ type = ._Type, _type = .{ type = argumentType } };
               WriteTypeOrVariableOrConstant(data, b, argumentTypeIdentifier);

               print_to_builder(*functionBuilder, " \%%",
                                                   GetSSAId(data, argumentTypeIdentifier)
               );
            }

            print_to_builder(*functionBuilder, "\n");
            append_and_steal_buffers(b, *functionBuilder);
            return;
         }

         if (ti.type == .ARRAY) {
            tia := cast(*Type_Info_Array) ti;
            assert(tia.array_type == .FIXED, "array type: %. .VIEW is basically a fat pointer, i will support it when i support pointers. .RESIZABLE is i think kaputt, dont use it.", tia.array_type);

            elementType := tia.element_type;
            assert(tia.element_type.type != .POINTER && tia.element_type.type != .ARRAY, "tia.element_type.type: %. idk if an array of pointers", tia.element_type.type);
            elementTypeIdentifier: Identifier = .{ type = ._Type, _type = .{ type = elementType } };
            WriteTypeOrVariableOrConstant(data, b, elementTypeIdentifier);

            arraySizeIdentifier: Identifier = .{ type = .IntLiteral, intLiteral = .{ unsigned = true, value._u64 = xx tia.array_count, bitSize = 32 } };
            WriteTypeOrVariableOrConstant(data, b, arraySizeIdentifier);

            print_to_builder(b, "\%% = OpTypeArray \%% \%%\n",
                                 GetSSAId(data, identifier),
                                 GetSSAId(data, elementTypeIdentifier),
                                 GetSSAId(data, arraySizeIdentifier)
            );

            return;
         }

         // not every type is going to be written, so skipping some is fine. this is for debugging
         print("WARNING    type: %. skipped!\n", type);

      case .Void;
         print_to_builder(b, "\%% = OpTypeVoid\n",
                              GetSSAId(data, .{ type = .Void })
         );

      case .Variable;
         name := GetVariableName(identifier);
         if (IdentifierCompare(identifier, data.meshVertexOutVariableIdentifier) || // [] MeshVertexOut
               IdentifierCompare(identifier, data.meshPrimitiveOutVariableIdentifier) || // [] MeshPrimitiveOut
               name == MESH_VERTICES_NAME ||
               name == MESH_TRIANGLES_NAME
            ) {

            storageClass: StorageClass = .Output;
            typeIdentifier := GetVariableTypeIdentifier(data, identifier);
            pointerIdentifier := GetPointerTypeIdentifier(typeIdentifier, storageClass);
            WriteTypeOrVariableOrConstant(data, b, typeIdentifier);
            WriteTypeOrVariableOrConstant(data, b, pointerIdentifier);

            print_to_builder(b, "\%% = OpVariable \%% %    ; %\n",
                                 GetSSAId(data, identifier),
                                 GetSSAId(data, pointerIdentifier),
                                 ToSpirvStorageClass(storageClass),
                                 name
            );
         } else {
            // assert(false, "identifier: %. i guess all variables in \"Types, variables and constants\" block is builtin (user cant define a variable that goes in this block, i think)", identifier);
            print("WARNING    variable: %. skipped!\n", identifier.variable.declaration.*);
            return;
         }

      case .BuiltinThingies;
         if #complete identifier.builtinThingies == {
            case .PushDataVariable;
               typeIdentifier: Identifier = .{ type = ._Type, _type = .{ type = cast(*Type_Info) *void, pointer = .{ storageClass = .PushConstant, untyped = true } } };
               WriteTypeOrVariableOrConstant(data, b, typeIdentifier);

               pushDataStructIdentifier: Identifier = .{ type = ._Type, _type = .{ type = cast(*Type_Info) PushData } };
               WriteTypeOrVariableOrConstant(data, b, pushDataStructIdentifier);

               print_to_builder(b, "\%% = OpUntypedVariableKHR \%% % \%%   ; push data variable\n",
                                    GetSSAId(data, identifier),
                                    GetSSAId(data, typeIdentifier),
                                    ToSpirvStorageClass(.PushConstant),
                                    GetSSAId(data, pushDataStructIdentifier)
               );

            case .SamplerHeapVariable;
               typeIdentifier: Identifier = .{ type = ._Type, _type = .{ type = cast(*Type_Info) *void, pointer = .{ storageClass = .UniformConstant, untyped = true } } };
               WriteTypeOrVariableOrConstant(data, b, typeIdentifier);

               print_to_builder(b, "\%% = OpUntypedVariableKHR \%% %    ; sampler heap variable\n",
                                    GetSSAId(data, identifier),
                                    GetSSAId(data, typeIdentifier),
                                    ToSpirvStorageClass(.UniformConstant)
               );

            case .ImageHeapVariable;
               typeIdentifier: Identifier = .{ type = ._Type, _type = .{ type = cast(*Type_Info) *void, pointer = .{ storageClass = .UniformConstant, untyped = true } } };
               WriteTypeOrVariableOrConstant(data, b, typeIdentifier);

               print_to_builder(b, "\%% = OpUntypedVariableKHR \%% %    ; image heap variable\n",
                                    GetSSAId(data, identifier),
                                    GetSSAId(data, typeIdentifier),
                                    ToSpirvStorageClass(.UniformConstant)
               );
         }

         case .CompositeLiteral; {
            typeIdentifier: Identifier = .{ type = ._Type, _type = .{ type = identifier.compositeLiteral.type } };
            WriteTypeOrVariableOrConstant(data, b, typeIdentifier);

            literalBuilder: String_Builder;

            print_to_builder(*literalBuilder, "\%% = OpConstantComposite \%%",
                                             GetSSAId(data, identifier),
                                             GetSSAId(data, typeIdentifier)
            );

            for identifier.compositeLiteral.arguments {
               WriteTypeOrVariableOrConstant(data, b, it.*);
               print_to_builder(*literalBuilder, " \%%",
                                                GetSSAId(data, it.*)
               );
            }

            print_to_builder(*literalBuilder, "\n");

            append_and_steal_buffers(b, *literalBuilder);
         }
   }
}

GenerateFunctions :: (data: *CompilationData, body: *Code_Procedure_Body) -> string {
   b: String_Builder; // general builder. builder for the whole functions block (the one that comes after "Types, variables and constants")

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
                           GetSSAId(data, .{ type = ._Type, _type = .{ type = cast(*Type_Info) #type () -> () } })
      );

      // idk what to do with the label rn
      print_to_builder(*b, "\%% = OpLabel\n", GetNextSSAId(data));

      //
      // not adding this function type to CompilationData.functions since entry function is handled seperately
      //    - apila, 04/04/26
      //

      functionBuilder: String_Builder;

      GenerateInstructions(data, block, *b, *functionBuilder);
      append_and_steal_buffers(*b, *functionBuilder);

      print_to_builder(*b, "OpReturn\n");
      print_to_builder(*b, "OpFunctionEnd\n");
   }

   while data.functionFrontier.count > 0 {
      ok, current := Dequeue(*data.functionFrontier);
      assert(ok);

      header := current.header;
      block := current.block;

      find_or_add(*data.functions, header);

      returnTypeIdentifier := GetReturnTypeIdentifier(xx header.type);

      assert(header.type.type != .POINTER);
      functionTypeIdentifier: Identifier = .{ type = ._Type, _type = .{ type = header.type } };
      print_to_builder(*b, "\n; %\n", header.name);
      print_to_builder(*b, "\%% = OpFunction \%% None \%%\n",
                           GetSSAId(data,  .{ type = .Function, function = header }),
                           GetSSAId(data, returnTypeIdentifier),
                           GetSSAId(data, functionTypeIdentifier)
      );

      // All OpVariable instructions in a function must be in the first block in the function
      // https://registry.khronos.org/SPIR-V/specs/unified1/SPIRV.html#LogicalLayout

      functionBuilder: String_Builder;

      GenerateInstructions(data, block, *b, *functionBuilder);
      append_and_steal_buffers(*b, *functionBuilder);

      if (header.returns.count == 0) {
         print_to_builder(*b, "OpReturn\n");
      }

      print_to_builder(*b, "OpFunctionEnd\n");
   }

   return builder_to_string(*b);
}

GenerateInstructionsData :: struct {
   literal:    struct {
                  intLiteralBitSize:            int = 64;
                  intLiteralUnsigned:           bool = false;
                  autoCastFromIntToFloat:       bool = false;
               };
   isLValue:   bool = false; // maybe i should have two functions GenerateAddress and GenerateExpression instead of single GenerateInstructions function and a lvalue boolean like this. idk man. - apila, 15/04/26
}

// traverse AST and output the generated spirv.
// returns ssaId if the "node" is something that has an id, if not then output is ignored.
// function is to be appended to general.
// the Identifier returned doesnt always make sense if the thing returned doesnt have an identifier. for example result of an addition operation. use ssaId instead
GenerateInstructions :: (data: *CompilationData, node: *Code_Node, general: *String_Builder, function: *String_Builder, additionalData: GenerateInstructionsData = .{}) -> ssaId: int, Identifier {
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
         return 0, .{}; // i think i should skip? idk maybe

      case .TYPE_QUERY                  ;
         // size_of, type_info
         assert(false, "read the comment above. i need a way to get the value somehow not the code nodes");

      case .DEFER                       ;
         assert(false, "idk how to implement");

      case .USING                       ;
         // should i ignore?
         return 0, .{};

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
            GenerateInstructions(data, it, general, function);
         }
         return 0, .{};

      case .LITERAL                     ;
         cl := cast(*Code_Literal) node;
         if cl.value_type == {
            case .NUMBER;
               isFloat := cl.value_flags & .FLOAT || additionalData.literal.autoCastFromIntToFloat;

               if (isFloat) {
                  identifier: Identifier = .{ type = .FloatLiteral };
                  if (additionalData.literal.autoCastFromIntToFloat) {
                     identifier.floatLiteral = xx cl._s64;
                  } else {
                     identifier.floatLiteral = xx cl._float64;
                  }

                  return GetSSAId(data, identifier), identifier;
               } else {
                  assert(additionalData.literal.intLiteralBitSize == 32 || additionalData.literal.intLiteralBitSize == 64, "additionalData.literal.intLiteralBitSize: %, not implemented yet!", additionalData.literal.intLiteralBitSize);

                  identifier: Identifier = .{ type = .IntLiteral, intLiteral = .{ bitSize = additionalData.literal.intLiteralBitSize, unsigned = additionalData.literal.intLiteralUnsigned } };
                  if (additionalData.literal.intLiteralUnsigned) {
                     identifier.intLiteral.value._u64 = cl._u64;
                  } else {
                     identifier.intLiteral.value._s64 = cl._s64;
                  }

                  return GetSSAId(data, identifier), identifier;
               }

            case .STRUCT;
               assert(cl.type.type == .STRUCT);
               tis := cast(*Type_Info_Struct) cl.type;
               structLiteralInfo := cl.values.struct_literal_info;

               isConstant := IsStructLiteralConstant(cl);
               if (isConstant) {
                  identifier: Identifier = .{ type = .CompositeLiteral, compositeLiteral = .{ type = cl.type } };
                  identifier.compositeLiteral.arguments = NewArray(structLiteralInfo.arguments.count, *Identifier);

                  for structLiteralInfo.arguments {
                     argumentAdditionalData := GetAutoCastAdditionalData(tis.members[it_index].type, it.type);

                     _, argumentIdentifier := GenerateInstructions(data, it, general, function, argumentAdditionalData);
                     assert(argumentIdentifier.type != .Invalid, "struct: %, index: %, loc: %:%", tis.name, it_index, node.c0, node.l0);

                     heapCopy := New(Identifier);
                     heapCopy.* = argumentIdentifier;
                     identifier.compositeLiteral.arguments[it_index] = heapCopy;
                  }

                  return GetSSAId(data, identifier), identifier;
               } else {
                  resultSSAId := GetNextSSAId(data);
                  typeIdentifier: Identifier = .{ type = ._Type, _type = .{ type = cl.type } };

                  compositeConstructBuilder: String_Builder;
                  print_to_builder(*compositeConstructBuilder, "\%% = OpCompositeConstruct \%%",
                                                               resultSSAId,
                                                               GetSSAId(data, typeIdentifier)
                  );

                  for structLiteralInfo.arguments {
                     argumentAdditionalData := GetAutoCastAdditionalData(tis.members[it_index].type, it.type);

                     // argumentIdentifier doesnt have any value if "it" is not a literal
                     argumentSSAId, argumentIdentifier := GenerateInstructions(data, it, general, function, argumentAdditionalData);

                     print_to_builder(*compositeConstructBuilder, " \%%",
                                                                  argumentSSAId
                     );
                  }

                  print_to_builder(*compositeConstructBuilder, "\n");
                  append_and_steal_buffers(function, *compositeConstructBuilder);

                  return resultSSAId, .{};
               }

            case; assert(false, "cl.value_type: %\n", cl.value_type);
         }

      case .IDENT                       ;
         ci := cast(*Code_Ident) node;
         assert(ci.resolved_declaration.type.type != .POINTER, "this means the user declared a local pointer, not implemented yet!");

         variableIdentifier := GetVariableIdentifier(ci);
         variableSSAId := GetSSAId(data, variableIdentifier);
         variableName := GetVariableName(variableIdentifier);

         if (additionalData.isLValue) {
            return variableSSAId, variableIdentifier;
         }

         deferencedSSAId := GetNextSSAId(data);

         variableTypeIdentifier: Identifier = .{ type = ._Type, _type = .{ type = ci.resolved_declaration.type } };
         print_to_builder(function, "\%% = OpLoad \%% \%%      ; %\n",
                                    deferencedSSAId,
                                    GetSSAId(data, variableTypeIdentifier),
                                    variableSSAId,
                                    variableName
         );

         return deferencedSSAId, .{};

      case .UNARY_OPERATOR              ;
      case .BINARY_OPERATOR             ;
         cbo := cast(*Code_Binary_Operator)node;

         if cbo.operator_type == {
            case #char ".";
               base, indices := GetBaseAndIndices(data, function, cbo);
               assert(base.type == .Variable);

               storageClass := GetVariableStorageClass(data, base);
               baseTypeIdentifier := GetVariableTypeIdentifier(data, base);
               basePointerTypeIdentifier := GetPointerTypeIdentifier(baseTypeIdentifier, storageClass);

               returnType := cbo.type;
               returnTypeIdentifier := GetPointerTypeIdentifier(returnType, storageClass);

               lValueSSAId := GetNextSSAId(data);
               print_to_builder(function, "\%% = OpAccessChain \%% \%%",
                                          lValueSSAId,
                                          GetSSAId(data, returnTypeIdentifier),
                                          GetSSAId(data, base)
               );

               for indices {
                  print_to_builder(function, " \%%",
                                             it
                  );
               }

               print_to_builder(function, "\n");

               if (additionalData.isLValue) {
                  return lValueSSAId, .{};
               }

               dereferencedSSAId := GetNextSSAId(data);
               print_to_builder(function, "\%% = OpLoad \%% \%%\n",
                                          dereferencedSSAId,
                                          GetSSAId(data, baseTypeIdentifier),
                                          lValueSSAId
               );

               return dereferencedSSAId, .{};

            case #char "-"; #through;
            case #char "+"; {
               assert(cbo.left.type == cbo.right.type);

               leftId := GenerateInstructions(data, cbo.left, general, function);
               rightId := GenerateInstructions(data, cbo.right, general, function);

               resultSSAId := GetNextSSAId(data);

               type := cbo.left.type;
               assert(cbo.left.type.type != .POINTER, "this means a pointer is being added (only valid with integers) but for now only same types supported so this would mean two pointers are being added. doesnt make sense");

               typeIdentifier: Identifier = .{ type = ._Type, _type = .{ type = type } };
               if (type == cast(*Type_Info) Float ||
                   type == cast(*Type_Info) Float2 ||
                   type == cast(*Type_Info) Float3 ||
                   type == cast(*Type_Info) Float4) {
                  instruction := GetFloatInstructionNameFromOperatorType(cbo.operator_type);
                  print_to_builder(function, "\%% = % \%% \%% \%%\n",
                                             resultSSAId,
                                             instruction,
                                             GetSSAId(data, typeIdentifier),
                                             leftId,
                                             rightId
                  );
               } else if (type == cast(*Type_Info) Int32 ||
                          type == cast(*Type_Info) Int32x2 ||
                          type == cast(*Type_Info) Int32x3 ||
                          type == cast(*Type_Info) Int32x4 ||
                          type == cast(*Type_Info) UInt32 ||
                          type == cast(*Type_Info) UInt32x2 ||
                          type == cast(*Type_Info) UInt32x3 ||
                          type == cast(*Type_Info) UInt32x4 ||
                          type == cast(*Type_Info) Int64 ||
                          type == cast(*Type_Info) Int64x2 ||
                          type == cast(*Type_Info) Int64x3 ||
                          type == cast(*Type_Info) Int64x4 ||
                          type == cast(*Type_Info) UInt64 ||
                          type == cast(*Type_Info) UInt64x2 ||
                          type == cast(*Type_Info) UInt64x3 ||
                          type == cast(*Type_Info) UInt64x4) {
                  instruction := GetIntegerInstructionNameFromOperatorType(cbo.operator_type);
                  print_to_builder(function, "\%% = % \%% \%% \%%\n",
                                             resultSSAId,
                                             instruction,
                                             GetSSAId(data, typeIdentifier),
                                             leftId,
                                             rightId
                  );
               } else {
                  assert(false, "type: %\n", type);
               }

               return resultSSAId, .{};
            }

            case #char "="; {
               assert(cbo.left.kind == .IDENT ||
                     (cbo.left.kind == .BINARY_OPERATOR && cbo.left.(*Code_Binary_Operator).operator_type == #char "."),
                     "cbo.left.kind: %", cbo.left.kind
               );

               rightId, rightIdentifier := GenerateInstructions(data, cbo.right, general, function);
               leftId, _ := GenerateInstructions(data, cbo.left, general, function, .{ isLValue = true });

               print_to_builder(function, "OpStore \%% \%%\n",
                                          leftId,
                                          rightId
               );

               return rightId, rightIdentifier;
            }

         }
      case .PROCEDURE_BODY              ;
      case .PROCEDURE_CALL              ;
         cpc := cast(*Code_Procedure_Call) node;
         procedureExpression := cpc.procedure_expression;
         assert(procedureExpression.kind == .IDENT);

         identifierExpression := cast(*Code_Ident) procedureExpression;
         identifierName := identifierExpression.name;
         arguments := cpc.arguments_unsorted;

         if (identifierName == SET_MESH_OUTPUTS_NAME) {
            vertexCountExpression := arguments[0].expression;
            primitiveCountExpression := arguments[1].expression;

            vertexCountSSAId := GenerateInstructions(data, vertexCountExpression, general, function, additionalData = .{ literal = .{ intLiteralBitSize = 32, intLiteralUnsigned = true } });
            primitiveCountSSAId := GenerateInstructions(data, primitiveCountExpression, general, function, additionalData = .{ literal = .{ intLiteralBitSize = 32, intLiteralUnsigned = true } });

            print_to_builder(function, "OpSetMeshOutputsEXT \%% \%%\n",
                                       vertexCountSSAId,
                                       primitiveCountSSAId
            );

            return -42000, .{}; // doesnt matter since OpSetMeshOutputsEXT doesnt return
         }

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
         variableIdentifier: Identifier = .{ type = .Variable, variable.declaration = cd };
         variableSSAId := GetSSAId(data, variableIdentifier);

         storageClass := StorageClass.Function;
         variableTypeIdentifier := GetVariableTypeIdentifier(data, variableIdentifier);
         pointerTypeIdentifier := GetPointerTypeIdentifier(variableTypeIdentifier, storageClass);

         assert(cd.type.type != .POINTER, "a pointer is declared, not implemented yet! loc: %:%", node.l0, node.c0);

         NO_INITIALIZER :: -1;
         initializerSSAId: int = NO_INITIALIZER;

         if (cd.expression != null) {
            if cd.expression.kind == {
               case .LITERAL; {
                  bitSizeData: GenerateInstructionsData;
                  BYTE_SIZE :: 8;
                  bitSizeData.literal.intLiteralBitSize = cd.type.runtime_size * BYTE_SIZE;
                  initializerSSAId = GenerateInstructions(data, cd.expression, general, function, bitSizeData);
               }

               case; assert(false, "cd.expression.kind: %, not implemented yet!", cd.expression.kind);
            }
         }

         // cant be untyped (VUID-StandaloneSpirv-OpTypeUntypedPointerKHR-11417)
         print_to_builder(general, "\%% = OpVariable \%% %",
                                    variableSSAId,
                                    GetSSAId(data, pointerTypeIdentifier),
                                    ToSpirvStorageClass(storageClass),
         );

         if (initializerSSAId != NO_INITIALIZER) {
            print_to_builder(general, " \%%", initializerSSAId);
         }

         print_to_builder(general, "      ; %\n", GetVariableName(variableIdentifier));

         return variableSSAId, variableIdentifier;
      case .CAST                        ;
      case .DIRECTIVE_THROUGH           ;
      case .COMPOUND_DECLARATION        ;
   }

   assert(false, "node.kind: %, didnt return!", node.kind);
   return -69, .{};
}

GetAutoCastAdditionalData :: (memberType: *Type_Info, literalNodeType: *Type_Info) -> GenerateInstructionsData {
   additionalData: GenerateInstructionsData;

   // wait a minute. i think i dont need to handle the casts manually like this.
   // becasue there is Code_Cast user needs to cast the type manually anyways.
   // unless you go from 64 bit to 32 bit. idk
   //             - apila, 14/04/26
   //
   //
   // doing this autocast thingy only on literals because thats the behaivour of jai
   // and i want to keep the same behaviour. for example following works on jai:
   //
   //    f: float = -1;
   //
   // but the following doesnt work in jai:
   //
   //    i: int = -1;
   //    f: float = i; // this is an error
   //
   // so i am only doing the autocast if the node is a Code_Literal, otherwise additionalData will not be used
   // and additional data is not recursed in GenerateInstructions function
   //       - apila, 18/04/26
   additionalData.literal.autoCastFromIntToFloat = memberType.type == .FLOAT && literalNodeType.type == .INTEGER;

   if (memberType.type == .INTEGER) {
      if (false) {
      } else if (memberType == cast(*Type_Info) Int32) {
         additionalData.literal.intLiteralBitSize = 32;
         additionalData.literal.intLiteralUnsigned = false;
      } else if (memberType == cast(*Type_Info) UInt32) {
         additionalData.literal.intLiteralBitSize = 32;
         additionalData.literal.intLiteralUnsigned = true;
      } else if (memberType == cast(*Type_Info) Int64) {
         additionalData.literal.intLiteralBitSize = 64;
         additionalData.literal.intLiteralUnsigned = false;
      } else if (memberType == cast(*Type_Info) UInt64) {
         additionalData.literal.intLiteralBitSize = 64;
         additionalData.literal.intLiteralUnsigned = true;
      }
   }

   return additionalData;
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
   if (ci.name == MESH_VERTICES_NAME || ci.name == MESH_TRIANGLES_NAME) {
      return .{ type = .Variable, variable = .{ useName = true, name = ci.name } };
   }

   return .{ type = .Variable, variable.declaration = ci.resolved_declaration };
}

GetVariableStorageClass :: (data: *CompilationData, variable: Identifier) -> StorageClass {
   declaration := variable.variable;
   name := declaration.name;

   if (name == MESH_VERTICES_NAME) {
      return .Output;
   }

   if (name == MESH_TRIANGLES_NAME) {
      return .Output;
   }

   if (IdentifierCompare(variable, data.meshVertexOutVariableIdentifier)) {
      return .Output;
   }

   if (IdentifierCompare(variable, data.meshPrimitiveOutVariableIdentifier)) {
      return .Output;
   }

   return .Function;
}

GetVariableName :: (variable: Identifier) -> string {
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
      return .{ type = ._Type, _type = .{ type = typeInfo } };
   }

   if (name == MESH_TRIANGLES_NAME) {
      elementType := cast(*Type_Info) Int32x3;

      typeInfo := CreateTypeInfoArray(elementType, data.maxPrimitives);
      return .{ type = ._Type, _type = .{ type = typeInfo } };
   }

   if (IdentifierCompare(variable, data.meshVertexOutVariableIdentifier)) {
      elementType := GetElementType(declaration);
      typeInfo := CreateTypeInfoArray(elementType, data.maxVertices);
      return .{ type = ._Type, _type = .{ type = typeInfo } };
   }

   if (IdentifierCompare(variable, data.meshPrimitiveOutVariableIdentifier)) {
      elementType := GetElementType(declaration);
      typeInfo := CreateTypeInfoArray(elementType, data.maxVertices);
      return .{ type = ._Type, _type = .{ type = typeInfo } };
   }

   return .{ type = ._Type, _type = .{ type = declaration.type } };
}

GetPointerTypeIdentifier :: (typeIdentifier: Identifier, storageClass: StorageClass) -> Identifier {
   assert(typeIdentifier.type == ._Type, "type: %", typeIdentifier.type);
   return GetPointerTypeIdentifier(typeIdentifier._type.type, storageClass);
}

// used to get the result type of OpVariable from jai declared type
GetPointerTypeIdentifier :: (type: *Type_Info, storageClass: StorageClass) -> Identifier {
   pointerTypeInfo := New(Type_Info_Pointer);
   pointerTypeInfo.type = .POINTER;
   pointerTypeInfo.runtime_size = 8;
   pointerTypeInfo.pointer_to = type;

   return .{ type = ._Type, _type = .{ type = pointerTypeInfo, pointer = .{ storageClass = storageClass } } };
}

//
// this function only works if none of the "."s are deference operations
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
GetBaseAndIndices :: (data: *CompilationData, b: *String_Builder, cbo: *Code_Binary_Operator) -> base: Identifier, ssaIdsOfIndicies: [] int {
   // treat indices, base and baseSeen as if it is they are capture variables
   Helper :: (data: *CompilationData, b: *String_Builder, current: *Code_Node, parent: *Code_Node, indices: *[..] int, base: *Identifier, baseSeen: *bool) {
      if (current.kind == .BINARY_OPERATOR) {
         cbo := cast(*Code_Binary_Operator) current;
         assert(cbo.operator_type == #char "." ||
                  cbo.operator_type == .ARRAY_SUBSCRIPT,
                  "operator: %", cbo.operator_type
         );

         Helper(data, b, cbo.left, current, indices, base, baseSeen);
         Helper(data, b, cbo.right, current, indices, base, baseSeen);
         return;
      }

      // this is the left most node. which means this is the base
      if (!(.*)baseSeen) {
         assert(current.kind == .IDENT, "kind: %", current.kind);
         baseSeen.* = true;

         ci := cast(*Code_Ident) current;
         base.* = GetVariableIdentifier(ci);
         return;
      }

      assert(parent.kind == .BINARY_OPERATOR, "parent.kind: %", parent.kind);
      parentCbo := cast(*Code_Binary_Operator) parent;
      assert(parentCbo.operator_type == #char "." ||
             parentCbo.operator_type == .ARRAY_SUBSCRIPT,
             "operator: %", parentCbo.operator_type
      );

      leftType := parentCbo.left.type;
      if leftType.type == {
         case .STRUCT;
            tis := cast(*Type_Info_Struct) leftType;

            assert(current.kind == .IDENT, "if you are accessing a struct indexer it is not yet implemented! current.kind: %, struct name: %", current.kind, tis.name);
            ci := cast(*Code_Ident) current;

            memberIndex := GetMemberIndex(tis, ci.name);
            assert(memberIndex != MEMBER_DOESNT_EXIST, "not a member of struct! struct: %, member: %", tis.name, ci.name);

            memberIndexIdentifier: Identifier = .{ type = .IntLiteral, intLiteral = .{ unsigned = false, value._s64 = memberIndex, bitSize = 32 } };
            memberIndexSSAId := GetSSAId(data, memberIndexIdentifier);
            array_add(indices, memberIndexSSAId);

         case .ARRAY;
            tia := cast(*Type_Info_Array) leftType;

            // in case it is a literal then it should be 32 bit signed i think (thats what glslangValidator generates)
            additionalData: GenerateInstructionsData = .{
               literal.intLiteralBitSize = 32,
               literal.intLiteralUnsigned = false,
            };

            ssaId, _ := GenerateInstructions(data, current, null, b, additionalData);
            array_add(indices, ssaId);

         case; assert(false, "not yet implemented! type: %", leftType.type);
      }
   }

   indices: [..] int;
   base: Identifier;
   baseSeen := false;
   Helper(data, b, cbo, null, *indices, *base, *baseSeen);

   assert(baseSeen);

   return base, indices;
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

GetFloatInstructionNameFromOperatorType :: (type: Operator_Type) -> string {
   if type == {
      case #char "+"; return "OpFAdd";
      case #char "-"; return "OpFSub";
      case; assert(false, "type: %", type); return "";
   }
}

GetIntegerInstructionNameFromOperatorType :: (type: Operator_Type) -> string {
   if type == {
      case #char "+"; return "OpIAdd";
      case #char "-"; return "OpISub";
      case; assert(false, "type: %", type); return "";
   }
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

// i need this function since "void" is kinda special
GetReturnTypeIdentifier :: (tip: *Type_Info_Procedure) -> Identifier {
   assert(tip.type == .PROCEDURE); // if passed via cast from *Type_Info
   assert(tip.return_types.count <= 1);

   if (tip.return_types.count == 0) {
      return .{ type = .Void };
   }

   // returns count must be one here as asserted above (combined with if case)
   returnType := tip.return_types[0];
   assert(returnType.type != .POINTER, "not implemented yet!");

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
      case .Image; return "Image";
      case .Workgroup; return "Workgroup";
      case .StorageBuffer; return "StorageBuffer";
      case .Uniform; return "Uniform";
   }

   assert(false, "storageClass: %", storageClass);
}
