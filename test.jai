#import "Compiler";
#import "POSIX";
#import "Basic";
#import "Hash_Table";
#import "Hash";
#import "Math";

#run {
   set_build_options_dc(.{ do_output = false });

   code := #code .{ a, b };
   root := compiler_get_nodes(code);
   print("%\n", root.kind);
}
