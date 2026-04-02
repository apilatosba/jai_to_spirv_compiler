#import "Compiler";
#import "POSIX";
#import "Basic";
#import "Hash_Table";
#import "Hash";
#import "Math";

#run {
   set_build_options_dc(.{ do_output = false });

   code := #code a + b;
   root := compiler_get_nodes(code);
   bo := cast(*Code_Binary_Operator) root;
   print("%\n", formatStruct(bo.*, use_long_form_if_more_than_this_many_members=1, use_newlines_if_long_form=true));
}
