#import "Compiler";
#import "POSIX";
#import "Basic";
#import "Hash_Table";
#import "Hash";
#import "Math";

#run {
   set_build_options_dc(.{ do_output = false });

   code := #code myVariable: int = 10;

   root := compiler_get_nodes(code);
   declaration := cast(*Code_Declaration)root;
   print("%\n", declaration.name);
}
