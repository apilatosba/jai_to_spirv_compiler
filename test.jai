#import "Compiler";
#import "POSIX";
#import "Basic";
#import "Hash_Table";
#import "Hash";
#import "Math";
#import "Random";
#import "File";

VeryBadImplementedAlignOfBecauseIDontKnowHowToUseTheProperOneInAMetaprogramWhereTypeIsNotConstantSecondTake :: (type: *Type_Info) -> int {
   if type.type == {
      case .INTEGER              ;
         return type.runtime_size;

      case .FLOAT                ;
         return type.runtime_size;

      case .BOOL                 ;
         return 4;

      case .STRING               ;
         assert(false);

      case .POINTER              ;
         return type.runtime_size;

      case .STRUCT               ;
         tis := cast(*Type_Info_Struct) type;

         maxAlignment := 0;
         for tis.members {
            memberAlignment := VeryBadImplementedAlignOfBecauseIDontKnowHowToUseTheProperOneInAMetaprogramWhereTypeIsNotConstantSecondTake(it.type);
            maxAlignment = max(maxAlignment, memberAlignment);
         }
         assert(maxAlignment != 0);

         return maxAlignment;
      case .ARRAY                ;
         tia := cast(*Type_Info_Array) type;
         return VeryBadImplementedAlignOfBecauseIDontKnowHowToUseTheProperOneInAMetaprogramWhereTypeIsNotConstantSecondTake(tia.element_type);

      case .ENUM                 ;
         tie := cast(*Type_Info_Enum) type;
         return tie.internal_type.runtime_size;

      case; assert(false, "type: %", type.type);
   }

   assert(false, "type: %", type.type);
   return -789;
}

alignof :: ($T: Type) -> s64 #expand {
    return #run -> s64 {
        info := type_info(struct{ p: u8; t: T; });
        return info.members[1].offset_in_bytes;
    };
}

My_Struct :: struct {
   a: float #align 8;
}

#run {
   set_build_options_dc(.{ do_output = false });

   // ms: MS;
   // code := code_of(ms.a);
   // root := compiler_get_nodes(code);
   // cbo := cast(*Code_Binary_Operator) root;
   // left := cast(*Code_Ident) cbo.left;
   // ident := cast(*Code_Ident) left.resolved_declaration.type_inst.type_valued_expression;

   tis := cast(*Type_Info_Struct) My_Struct;
   

   print("%\n", tis.members[0].offset_in_bytes);
}

